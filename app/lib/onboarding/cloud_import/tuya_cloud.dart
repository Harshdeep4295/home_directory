// The ONLY code in the app that talks to the internet (CLAUDE.md rule 1). It runs only
// when the user starts "Import from Tuya cloud" and never on the control path.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import '../../core/log.dart';
import '../../core/result.dart';
import '../devices_json_import.dart';

/// Tuya OpenAPI data centres. Ported from tinytuya 1.20.0 Cloud.py setregion().
enum TuyaRegion {
  india('in', 'India', 'openapi.tuyain.com'),
  china('cn', 'China', 'openapi.tuyacn.com'),
  westAmerica('us', 'Western America', 'openapi.tuyaus.com'),
  eastAmerica('us-e', 'Eastern America', 'openapi-ueaz.tuyaus.com'),
  centralEurope('eu', 'Central Europe', 'openapi.tuyaeu.com'),
  westEurope('eu-w', 'Western Europe', 'openapi-weaz.tuyaeu.com'),
  singapore('sg', 'Singapore', 'openapi-sg.iotbing.com');

  const TuyaRegion(this.code, this.label, this.host);
  final String code;
  final String label;
  final String host;
}

class CloudResponse {
  const CloudResponse(this.status, this.body);
  final int status;
  final String body;
}

/// HTTP seam: tests replay recorded responses, the app uses [IoCloudHttp].
abstract interface class CloudHttp {
  Future<CloudResponse> send(
    String method,
    Uri url,
    Map<String, String> headers,
    String? body,
  );
}

class IoCloudHttp implements CloudHttp {
  IoCloudHttp({this.timeout = const Duration(seconds: 15)});
  final Duration timeout;

  @override
  Future<CloudResponse> send(
    String method,
    Uri url,
    Map<String, String> headers,
    String? body,
  ) async {
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      final req = await client.openUrl(method, url).timeout(timeout);
      headers.forEach(req.headers.set);
      if (body != null) req.write(body);
      final res = await req.close().timeout(timeout);
      final text = await res.transform(utf8.decoder).join().timeout(timeout);
      return CloudResponse(res.statusCode, text);
    } finally {
      client.close(force: true);
    }
  }
}

/// A signed request as tinytuya would send it (see [TuyaCloudClient.sign]).
class SignedRequest {
  const SignedRequest(this.method, this.url, this.headers, this.body);
  final String method;
  final Uri url;
  final Map<String, String> headers;
  final String? body;
}

/// Tuya OpenAPI client for the one job we need: list the user's devices with their
/// `local_key`, plus DP mappings. Flow and signing ported from tinytuya 1.20.0 Cloud.py
/// (_tuyaplatform, _gettoken, _get_all_devices, getdevices, getdps, _build_mapping).
class TuyaCloudClient {
  TuyaCloudClient({
    required this.accessId,
    required String accessSecret,
    required this.region,
    CloudHttp? http,
    DateTime Function()? now,
  }) : _secret = accessSecret,
       _http = http ?? IoCloudHttp(),
       _now = now ?? DateTime.now;

  final String accessId;
  final String _secret;
  final TuyaRegion region;
  final CloudHttp _http;
  final DateTime Function() _now;
  String? _token;
  static const _tag = 'cloud';

  /// Builds the signed request. tinytuya Cloud._tuyaplatform (new_sign_algorithm=True):
  ///   payload = client_id + [access_token] + t
  ///           + METHOD + "\n" + sha256hex(body or "") + "\n"
  ///           + "".join("k:v\n" for signed headers) + "\n"
  ///           + "/" + path + ["?" + sorted, un-encoded query]
  ///   sign = HMAC-SHA256(secret, payload).hexdigest().upper()
  /// Headers: client_id, sign, t, sign_method=HMAC-SHA256, mode=cors, [access_token];
  /// a POST also signs Content-type and lists it in Signature-Headers.
  /// tinytuya additionally sends the secret itself as a `secret` header on the token
  /// request; the signature already proves possession, so we do not. VERIFY on first
  /// real import that the token call succeeds without it.
  SignedRequest sign(
    String method,
    String path, {
    Map<String, String>? query,
    String? body,
    String? token,
  }) {
    final t = '${_now().millisecondsSinceEpoch}';
    final sorted = query == null
        ? const <MapEntry<String, String>>[]
        : (query.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));
    final signPath = sorted.isEmpty
        ? path
        : '$path?${sorted.map((e) => '${e.key}=${e.value}').join('&')}';
    final headers = <String, String>{};
    if (method == 'POST') {
      headers['Content-type'] = 'application/json';
      headers['Signature-Headers'] = 'Content-type';
    }
    final signedHeaders = [
      for (final k in (headers['Signature-Headers'] ?? '').split(':'))
        if (headers.containsKey(k)) '$k:${headers[k]}\n',
    ].join();
    final payload =
        '$accessId${token ?? ''}$t'
        '$method\n${sha256.convert(utf8.encode(body ?? ''))}\n'
        '$signedHeaders\n$signPath';
    final sign = Hmac(
      sha256,
      utf8.encode(_secret),
    ).convert(utf8.encode(payload)).toString().toUpperCase();
    headers.addAll({
      'client_id': accessId,
      'sign': sign,
      't': t,
      'sign_method': 'HMAC-SHA256',
      'mode': 'cors',
      'access_token': ?token,
    });
    final url = Uri.parse(
      'https://${region.host}$path',
    ).replace(queryParameters: sorted.isEmpty ? null : Map.fromEntries(sorted));
    return SignedRequest(method, url, headers, body);
  }

  Future<Result<Map<String, Object?>>> _call(
    String path, {
    Map<String, String>? query,
    bool retried = false,
  }) async {
    if (_token == null && path != _tokenPath) {
      final t = await _getToken();
      if (t case Err(:final error)) return Err(error);
    }
    final req = sign(
      'GET',
      path,
      query: path == _tokenPath ? _tokenQuery : query,
      token: path == _tokenPath ? null : _token,
    );
    final CloudResponse res;
    try {
      res = await _http.send(req.method, req.url, req.headers, req.body);
    } on TimeoutException {
      return Err(DeviceError.timeout('Tuya cloud did not answer'));
    } on SocketException catch (e) {
      return Err(DeviceError.offline('No internet: ${e.message}'));
    } on HttpException catch (e) {
      return Err(DeviceError.protocol(e.message));
    }
    // tinytuya: `if "token invalid" in response.text` → renew once and retry.
    if (res.body.contains('token invalid') && !retried) {
      _token = null;
      return _call(path, query: query, retried: true);
    }
    final Object? json;
    try {
      json = jsonDecode(res.body);
    } on FormatException {
      return Err(DeviceError.protocol('HTTP ${res.status}: not JSON'));
    }
    if (json is! Map<String, Object?>) {
      return Err(DeviceError.protocol('unexpected response'));
    }
    if (json['success'] != true) {
      final msg = '${json['msg'] ?? 'request failed'} (code ${json['code']})';
      log.w(_tag, '$path: $msg');
      return Err(
        _authCodes.contains(json['code'])
            ? DeviceError.auth(msg)
            : DeviceError.protocol(msg),
      );
    }
    return Ok(json);
  }

  static const _tokenPath = '/v1.0/token';
  static const _tokenQuery = {'grant_type': '1'};

  /// Tuya OpenAPI error codes for bad credentials / signature / token.
  /// VERIFY against https://developer.tuya.com/en/docs/iot/error-code (1004 sign invalid,
  /// 1010 token invalid, 1011 token expired, 2009 not support? — only the first three used).
  static const _authCodes = {1004, 1010, 1011};

  Future<Result<void>> _getToken() async {
    final r = await _call(_tokenPath);
    switch (r) {
      case Ok(:final value):
        final token = (value['result'] as Map?)?['access_token'];
        if (token is! String) {
          return Err(DeviceError.protocol('no access_token'));
        }
        _token = token;
        return const Ok(null);
      case Err(:final error):
        return Err(error);
    }
  }

  /// Paginated device list. tinytuya _get_all_devices(): without uid →
  /// /v1.0/iot-01/associated-users/devices (result.devices, size=50); with uid →
  /// /v1.3/iot-03/devices (result.list, page_size=75, source_type=tuyaUser). Both page
  /// with last_row_key / has_more.
  Future<Result<List<Map<String, Object?>>>> _allDevices({String? uid}) async {
    final path = uid == null
        ? '/v1.0/iot-01/associated-users/devices'
        : '/v1.3/iot-03/devices';
    final query = uid == null
        ? {'size': '50'}
        : {'page_size': '75', 'source_type': 'tuyaUser', 'source_id': uid};
    final out = <Map<String, Object?>>[];
    for (var page = 0; page < 40; page++) {
      final r = await _call(path, query: query);
      if (r case Err(:final error)) return Err(error);
      final result = (r.valueOrNull!['result'] as Map?) ?? const {};
      final items = result['devices'] ?? result['list'];
      if (items is List) {
        out.addAll(items.whereType<Map<String, Object?>>());
      }
      final next = result['last_row_key'];
      if (next is String) query['last_row_key'] = next;
      if (result['has_more'] != true) break;
    }
    return Ok(out);
  }

  /// tinytuya _update_device_list: add unknown ids, fill empty fields of known ones.
  static void _merge(
    List<Map<String, Object?>> into,
    List<Map<String, Object?>> more,
  ) {
    for (final n in more) {
      final id = n['id'];
      if (id is! String || id.isEmpty) continue;
      final existing = into.where((d) => d['id'] == id).firstOrNull;
      if (existing == null) {
        into.add(Map.of(n));
        continue;
      }
      for (final e in n.entries) {
        final v = existing[e.key];
        if (v == null || v == '' || v == false) existing[e.key] = e.value;
      }
    }
  }

  /// DP id → code, from GET /v1.1/devices/{id}/specifications (tinytuya getdps +
  /// _build_mapping: status then functions, `dp_id` else code, first wins).
  Future<Map<int, String>> _mapping(String deviceId) async {
    final r = await _call('/v1.1/devices/$deviceId/specifications');
    final result = (r.valueOrNull?['result'] as Map?) ?? const {};
    final out = <int, String>{};
    for (final key in const ['status', 'functions']) {
      final list = result[key];
      if (list is! List) continue;
      for (final m in list.whereType<Map<Object?, Object?>>()) {
        final dp = int.tryParse('${m['dp_id']}');
        final code = m['code'];
        if (dp != null && code is String) out.putIfAbsent(dp, () => code);
      }
    }
    return out;
  }

  /// The whole import: token → devices (+ per-user list for local keys) → mappings.
  /// Returns entries in the same shape as a tinytuya devices.json, so the file importer
  /// stores them.
  Future<Result<List<DevicesJsonEntry>>> fetchDevices() async {
    final all = await _allDevices();
    if (all case Err(:final error)) return Err(error);
    final devs = all.valueOrNull!;
    // tinytuya getdevices(): re-fetch per uid "to make sure we have the local key".
    final uids = {
      for (final d in devs)
        if (d['uid'] case final String u when u.isNotEmpty) u,
    };
    for (final uid in uids) {
      final more = await _allDevices(uid: uid);
      if (more case Ok(:final value)) _merge(devs, value);
    }
    final out = <DevicesJsonEntry>[];
    for (final d in devs) {
      final id = d['id'];
      if (id is! String || id.isEmpty) continue;
      out.add(
        DevicesJsonEntry(
          id: id,
          name: (d['name'] as String?)?.trim() ?? id,
          key: (d['local_key'] as String?) ?? '',
          // The cloud's `ip` is the home's public address, not the LAN one; the next
          // scan fills the LAN IP (tinytuya also ignores it).
          mapping: await _mapping(id),
          subDevice: d['sub'] == true || d['gateway_id'] is String,
        ),
      );
    }
    log.i(_tag, '${out.length} devices from Tuya cloud (${region.code})');
    return Ok(out);
  }
}
