import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:offline_home/core/result.dart';
import 'package:offline_home/onboarding/cloud_import/tuya_cloud.dart';

/// Replays recorded (sanitised) Tuya OpenAPI responses keyed by path.
class ReplayHttp implements CloudHttp {
  ReplayHttp(this.routes);
  final Map<String, List<String>> routes;
  final requests = <(String, Uri, Map<String, String>)>[];

  @override
  Future<CloudResponse> send(
    String method,
    Uri url,
    Map<String, String> headers,
    String? body,
  ) async {
    requests.add((method, url, headers));
    final q = routes[url.path];
    if (q == null || q.isEmpty) {
      return const CloudResponse(
        404,
        '{"success":false,"code":1108,"msg":"uri path invalid"}',
      );
    }
    return CloudResponse(200, q.length > 1 ? q.removeAt(0) : q.first);
  }
}

void main() {
  final vec = jsonDecode(
    File('test/onboarding/cloud_import/signing_vectors.json')
        .readAsStringSync(),
  ) as Map<String, dynamic>;
  final t = DateTime.fromMillisecondsSinceEpoch(vec['t'] as int);
  TuyaCloudClient client([CloudHttp? http]) => TuyaCloudClient(
    accessId: vec['access_id'] as String,
    accessSecret: vec['access_secret'] as String,
    region: TuyaRegion.india,
    http: http ?? ReplayHttp({}),
    now: () => t,
  );

  group('signing matches tinytuya 1.20.0 byte for byte', () {
    for (final v in (vec['vectors'] as List).cast<Map<String, dynamic>>()) {
      test(v['name'] as String, () {
        final url = Uri.parse(v['url'] as String);
        final query = url.queryParameters.isEmpty ? null : url.queryParameters;
        final r = client().sign(
          v['method'] as String,
          url.path,
          query: query,
          body: v['body'] as String?,
          token: v['token'] as String?,
        );
        expect(r.headers['sign'], v['sign']);
        expect(r.headers['t'], v['t']);
        expect(r.url.toString(), v['url']);
        expect(r.headers['client_id'], vec['access_id']);
        expect(r.headers['access_token'], v['token']);
        expect(r.headers.containsKey('secret'), isFalse);
      });
    }
  });

  test('fetchDevices: token → list → per-uid keys → mappings', () async {
    final http = ReplayHttp({
      '/v1.0/token': [
        '{"success":true,"t":1790000000200,"result":{"access_token":"tok1","expire_time":7200,"uid":"x"}}',
      ],
      '/v1.0/iot-01/associated-users/devices': [
        '{"success":true,"result":{"has_more":true,"last_row_key":"r1","devices":[{"id":"bfplug00000000000001","name":"Geyser Plug ","uid":"ayuser1","local_key":"","ip":"49.36.1.2","sub":false}]}}',
        '{"success":true,"result":{"has_more":false,"devices":[{"id":"bfsub000000000000002","name":"Sensor","uid":"ayuser1","sub":true}]}}',
      ],
      '/v1.3/iot-03/devices': [
        '{"success":true,"result":{"has_more":false,"list":[{"id":"bfplug00000000000001","local_key":"k3yK3YkeyKEY0001","uid":"ayuser1"},{"id":"bfsub000000000000002","gateway_id":"bfgw"}]}}',
      ],
      '/v1.1/devices/bfplug00000000000001/specifications': [
        '{"success":true,"result":{"category":"cz","functions":[{"code":"switch_1","dp_id":1,"type":"Boolean","values":"{}"},{"code":"countdown_1","dp_id":9,"type":"Integer","values":"{}"}],"status":[{"code":"switch_1","dp_id":1,"type":"Boolean","values":"{}"}]}}',
      ],
    });
    final r = await client(http).fetchDevices();
    final list = r.valueOrNull!;
    expect(list, hasLength(2));
    final plug = list.first;
    expect(plug.name, 'Geyser Plug');
    expect(plug.key, 'k3yK3YkeyKEY0001');
    expect(plug.ip, isNull, reason: 'cloud ip is the public address');
    expect(plug.mapping, {1: 'switch_1', 9: 'countdown_1'});
    expect(list.last.subDevice, isTrue);

    final paths = http.requests.map((e) => e.$2.path).toList();
    expect(paths.first, '/v1.0/token');
    expect(http.requests[2].$2.queryParameters['last_row_key'], 'r1');
    expect(
      http.requests.skip(1).every((e) => e.$3['access_token'] == 'tok1'),
      isTrue,
    );
    expect(
      http.requests.every((e) => e.$2.host == 'openapi.tuyain.com'),
      isTrue,
    );
  });

  test('bad credentials → auth error; token invalid → one renewal', () async {
    final bad = ReplayHttp({
      '/v1.0/token': ['{"success":false,"code":1004,"msg":"sign invalid"}'],
    });
    final r = await client(bad).fetchDevices();
    expect((r as Err).error.kind, DeviceErrorKind.auth);

    final expired = ReplayHttp({
      '/v1.0/token': [
        '{"success":true,"result":{"access_token":"tokA"}}',
        '{"success":true,"result":{"access_token":"tokB"}}',
      ],
      '/v1.0/iot-01/associated-users/devices': [
        '{"success":false,"code":1010,"msg":"token invalid"}',
        '{"success":true,"result":{"has_more":false,"devices":[]}}',
      ],
    });
    final r2 = await client(expired).fetchDevices();
    expect(r2.valueOrNull, isEmpty);
    expect(expired.requests.last.$3['access_token'], 'tokB');
  });

  test('rule 1: only cloud_import reaches the internet', () {
    final offenders = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final path = f.path.replaceAll(r'\', '/');
      if (path.startsWith('lib/onboarding/cloud_import/')) continue;
      final src = f.readAsStringSync();
      if (src.contains('https://') ||
          src.contains('package:http/') ||
          src.contains('cloud_import/') ||
          (src.contains('HttpClient(') &&
              path != 'lib/net/lan_socket_factory.dart')) {
        offenders.add(path);
      }
    }
    // The import screen is the one allowed entry point into cloud_import.
    expect(offenders, ['lib/ui/screens/tuya_cloud_import_screen.dart']);
  });
}
