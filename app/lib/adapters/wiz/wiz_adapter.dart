import 'dart:convert';

import '../../core/models.dart';
import '../../core/result.dart';
import '../../net/lan_socket_factory.dart';
import '../device_adapter.dart';

/// WiZ (Philips Smart Wi-Fi) lights and plugs: UDP JSON on port 38899.
/// Ported from pywizlight 0.6.6 (pywizlight/bulb.py, bulblibrary.py, discovery.py).
/// No native countdown: timers run on the phone tier (PLAN §6).
class WizAdapter extends DeviceAdapter {
  WizAdapter(
    this._sockets, {
    this.timeout = LanSocketFactory.defaultTimeout,
    this.resendAfter = const Duration(milliseconds: 750),
  });

  /// pywizlight/bulb.py: PORT = 38899
  static const port = 38899;

  /// pywizlight/discovery.py: REGISTER_MESSAGE. Broadcast it; every WiZ device replies
  /// with {"result": {"mac": ...}}. register=false so no push session is started.
  static const registerMessage =
      '{"method":"registration","params":{"phoneMac":"AAAAAAAAAAAA",'
      '"register":false,"phoneIp":"1.2.3.4","id":"1"}}';

  /// pywizlight error code for an unsupported method.
  static const methodNotFound = -32601;

  static const _tag = 'wiz';

  final LanSocketFactory _sockets;
  final Duration timeout;

  /// pywizlight resends after FIRST_SEND_INTERVAL = 0.75 s; we send twice within [timeout].
  final Duration resendAfter;

  @override
  Brand get brand => Brand.wiz;

  @override
  Set<String> get protocols => {'wiz'};

  /// Sends one request to ip:port, resending once if the first datagram got no reply.
  Future<Result<Map<String, Object?>>> request(
    String ip,
    String method, {
    Map<String, Object?> params = const {},
    int port = port,
    Duration? timeout,
  }) async {
    final total = timeout ?? this.timeout;
    final payload = utf8.encode(
      jsonEncode({'method': method, 'params': params}),
    );
    final first = total > resendAfter ? resendAfter : total;
    var r = await _sockets.udpRequest(ip, port, payload, timeout: first);
    if (r.errorOrNull?.kind == DeviceErrorKind.timeout && total > first) {
      r = await _sockets.udpRequest(ip, port, payload, timeout: total - first);
    }
    return switch (r) {
      Err(:final error) => Err(error),
      Ok(:final value) => parseReply(method, value.first.text),
    };
  }

  static Result<Map<String, Object?>> parseReply(String method, String text) {
    final Object? json;
    try {
      json = jsonDecode(text);
    } on FormatException {
      return Err(DeviceError.protocol('wiz: invalid JSON'));
    }
    if (json is! Map<String, Object?>) {
      return Err(DeviceError.protocol('wiz: reply is not an object'));
    }
    if (json['error'] case final Map<String, Object?> e) {
      return e['code'] == methodNotFound
          ? Err(DeviceError.unsupported('wiz: $method not supported'))
          : Err(DeviceError.protocol('wiz: $method error ${e['code']}'));
    }
    if (json['method'] != method) {
      return Err(DeviceError.protocol('wiz: reply for ${json['method']}'));
    }
    final result = json['result'];
    return result is Map<String, Object?>
        ? Ok(result)
        : Err(DeviceError.protocol('wiz: no result'));
  }

  Future<Result<Map<String, Object?>>> _send(
    Device d,
    String method, [
    Map<String, Object?> params = const {},
  ]) => request(d.ip, method, params: params, port: d.port ?? port);

  /// Capabilities from the module name, following pywizlight bulblibrary.BulbType.from_data:
  /// the second `_` field contains RGB / TW / SOCKET; anything else is dimmable white.
  static Set<Capability> capabilitiesForModule(String? moduleName) {
    final parts = moduleName?.split('_');
    if (parts == null || parts.length < 2) {
      return {Capability.power, Capability.brightness};
    }
    final id = parts[1];
    if (id.contains('RGB')) {
      return {
        Capability.power,
        Capability.brightness,
        Capability.colorTemp,
        Capability.rgb,
      };
    }
    if (id.contains('TW')) {
      return {Capability.power, Capability.brightness, Capability.colorTemp};
    }
    if (id.contains('SOCKET')) return {Capability.power};
    return {Capability.power, Capability.brightness};
  }

  @override
  Future<Candidate?> probe(ProbeContext ctx) async {
    final r = await request(ctx.ip, 'getPilot', timeout: ctx.timeout);
    final mac = r.valueOrNull?['mac'];
    if (mac is! String) return null;
    return candidateFrom(ctx.ip, mac, await _systemConfig(ctx.ip, ctx.timeout));
  }

  /// Builds a candidate once a device answered (probe or registration broadcast).
  Future<Candidate> candidateFromReply(String ip, String mac) async =>
      candidateFrom(ip, mac, await _systemConfig(ip, timeout));

  Future<Map<String, Object?>?> _systemConfig(String ip, Duration t) async =>
      (await request(ip, 'getSystemConfig', timeout: t)).valueOrNull;

  static Candidate candidateFrom(
    String ip,
    String mac,
    Map<String, Object?>? cfg,
  ) {
    final module = cfg?['moduleName'] as String?;
    final caps = capabilitiesForModule(module);
    return Candidate(
      ip: ip,
      mac: mac.toLowerCase(),
      brand: Brand.wiz,
      protocol: 'wiz',
      deviceId: mac.toLowerCase(),
      name: caps.length == 1 ? 'WiZ plug' : 'WiZ light',
      evidence: [
        'udp 38899 getPilot',
        if (module != null) 'module $module',
        if (cfg?['fwVersion'] case final String fw) 'fw $fw',
      ],
    );
  }

  @override
  Future<Result<DeviceState>> getState(Device d) =>
      guarded(_tag, 'getState', () async {
        final r = await _send(d, 'getPilot');
        return r.map(
          (p) => DeviceState(
            on: p['state'] as bool?,
            brightness: (p['dimming'] as num?)?.toInt(),
            colorTemp: (p['temp'] as num?)?.toInt(),
            at: DateTime.now(),
          ),
        );
      });

  Future<Result<void>> _setPilot(Device d, Map<String, Object?> params) =>
      guarded(_tag, 'setPilot', () async {
        final r = await _send(d, 'setPilot', params);
        return r.map((_) {});
      });

  @override
  Future<Result<void>> setPower(Device d, bool on) =>
      _setPilot(d, {'state': on});

  /// pywizlight PilotBuilder._set_brightness: dimming = max(1, percent).
  @override
  Future<Result<void>> setBrightness(Device d, int pct) async =>
      capabilitiesOf(d).contains(Capability.brightness)
      ? _setPilot(d, {'dimming': pct.clamp(1, 100)})
      : Err(DeviceError.unsupported('brightness'));

  /// pywizlight PilotBuilder._set_colortemp clamps to 1000..10000 K; the device clamps to
  /// its own cctRange. VERIFY per model on hardware.
  @override
  Future<Result<void>> setColorTemp(Device d, int kelvin) async =>
      capabilitiesOf(d).contains(Capability.colorTemp)
      ? _setPilot(d, {'temp': kelvin.clamp(1000, 10000)})
      : Err(DeviceError.unsupported('color temperature'));
}
