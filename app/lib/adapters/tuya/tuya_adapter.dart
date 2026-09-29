import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import '../../core/log.dart';
import '../../core/models.dart';
import '../../core/result.dart';
import '../../net/lan_socket_factory.dart';
import '../../registry/secret_store.dart';
import '../device_adapter.dart';
import 'tuya_codec.dart';

/// Data-point roles and default profiles (PSEUDOCODE §6.3). Defaults are the common
/// Tuya layouts; VERIFY per device with spike/survey.py and override via [Device.dpMap]
/// (devices.json / cloud import derive it from the device's own mapping).
abstract final class TuyaDp {
  static const switch_ = 'switch';
  static const countdown = 'countdown';
  static const mode = 'mode';
  static const brightness = 'brightness';
  static const colorTemp = 'colorTemp';

  /// Raw value range of brightness / colour temperature (stored in the dpMap).
  static const valueMin = 'valueMin';
  static const valueMax = 'valueMax';

  /// tinytuya BulbDevice.DPS_MODE_WHITE.
  static const modeWhite = 'white';

  static const plug = {switch_: 1, countdown: 9};

  /// tinytuya 1.20.0 BulbDevice.DEFAULT_DPSET['B'] (timer = countdown).
  static const bulb = {
    switch_: 20,
    mode: 21,
    brightness: 22,
    colorTemp: 23,
    countdown: 26,
    valueMin: 10,
    valueMax: 1000,
  };

  /// tinytuya BulbDevice.DEFAULT_DPSET['A'].
  static const bulbA = {
    switch_: 1,
    mode: 2,
    brightness: 3,
    colorTemp: 4,
    countdown: 7,
    valueMin: 25,
    valueMax: 255,
  };

  /// tinytuya BulbDevice.DEFAULT_DPSET['C'] (basic dimmable, no mode/timer).
  static const bulbC = {
    switch_: 1,
    brightness: 2,
    colorTemp: 3,
    valueMin: 25,
    valueMax: 255,
  };

  /// Gang [n] (1-based) of a multi-gang switch without a stored mapping: switch_n = n,
  /// countdown_n = 6 + n (PSEUDOCODE §6.3 "countdown_n = 7..10"). VERIFY per model —
  /// imports use the device's own switch_N / countdown_N codes instead.
  static Map<String, int> gang(int n) => {switch_: n, countdown: 6 + n};

  /// Picks a profile from the DPs a device reports. Bulb rules ported from tinytuya
  /// BulbDevice.detect_bulb(): 20+1 → not a bulb; 20+21 → B; 1+2 → A if DP 2 is a
  /// string (mode) else C. Like tinytuya, optional roles are kept only when reported.
  static Map<String, int> detect(Map<String, Object?> dps) {
    final Map<String, int> base;
    if (dps.containsKey('20') && dps.containsKey('1')) {
      return plug;
    } else if (dps.containsKey('20') && dps.containsKey('21')) {
      base = bulb;
    } else if (dps.containsKey('20') && !dps.containsKey('1')) {
      base = bulb;
    } else if (dps.containsKey('1') && dps.containsKey('2')) {
      base = dps['2'] is String ? bulbA : bulbC;
    } else {
      return plug;
    }
    return {
      for (final e in base.entries)
        if (e.key == switch_ ||
            e.key == valueMin ||
            e.key == valueMax ||
            dps.containsKey('${e.value}'))
          e.key: e.value,
    };
  }

  /// Capabilities a dpMap supports.
  static Set<Capability> capabilities(Map<String, int> map) => {
    Capability.power,
    if (map.containsKey(countdown)) Capability.nativeCountdown,
    if (map.containsKey(brightness)) Capability.brightness,
    if (map.containsKey(colorTemp)) Capability.colorTemp,
  };

  /// Colour temperature: Tuya reports 0..valueMax (warm → cold, as tinytuya's
  /// percentage helpers), not Kelvin. VERIFY: linear map onto the app's slider range.
  static const kelvinMin = 2200;
  static const kelvinMax = 6500;
}

/// Tuya LAN devices (Wipro, Syska, Smart Life …), protocol 3.1 / 3.3 / 3.4 / 3.5 over TCP 6668.
/// Ported from tinytuya 1.20.0 (see tuya_codec.dart). 3.4 negotiates a session key
/// first (T7.1), 3.5 does the same over AES-GCM 6699 frames (T7.2).
class TuyaAdapter extends DeviceAdapter {
  TuyaAdapter(
    this._sockets,
    this._secrets, {
    this.timeout = LanSocketFactory.defaultTimeout,
    this.heartbeatEvery = const Duration(seconds: 10),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  /// tinytuya: TCPPORT = 6668
  static const port = 6668;

  /// VERIFY per model: most plugs accept up to 86400 s in their countdown DP.
  static const countdownMax = Duration(seconds: 86400);

  static const _tag = 'tuya';

  final LanSocketFactory _sockets;
  final SecretStore _secrets;
  final Duration timeout;
  final Duration heartbeatEvery;
  final DateTime Function() _now;
  final Map<String, _TuyaConn> _conns = {};

  /// App devices sharing one Tuya connection (multi-gang), by Tuya id.
  final Map<String, Map<String, Device>> _gangs = {};
  final Map<String, StreamController<DeviceState>> _watchers = {};

  @override
  Brand get brand => Brand.tuya;

  @override
  Set<String> get protocols => {'tuya'};

  /// Protocol version from `tuya-3.x`; plain `tuya` (unknown) tries 3.3.
  static String versionOf(Device d) =>
      d.protocol.startsWith('tuya-') ? d.protocol.substring(5) : '3.3';

  Map<String, int> dpMapOf(Device d) =>
      d.dpMap ?? (gangOf(d) > 1 ? TuyaDp.gang(gangOf(d)) : TuyaDp.plug);

  /// The Tuya device id (key, session, devId). Gangs 2..N of a multi-gang switch are
  /// separate app devices `<tuyaId>#<n>` with `meta.tuyaId` set; gang 1 keeps the id.
  static String tuyaIdOf(Device d) => (d.meta['tuyaId'] as String?) ?? d.id;

  static int gangOf(Device d) => (d.meta['gang'] as num?)?.toInt() ?? 1;

  /// App-device id for gang [n] of Tuya device [tuyaId].
  static String gangDeviceId(String tuyaId, int n) =>
      n == 1 ? tuyaId : '$tuyaId#$n';

  @override
  Future<Candidate?> probe(ProbeContext ctx) async {
    // Without the local key all we can tell is that the Tuya port is open. Beacons (UDP
    // 6666/6667) carry the id and version; the Fingerprinter prefers those.
    final r = await _sockets.tcp(ctx.ip, port, timeout: ctx.timeout);
    if (r case Ok(:final value)) {
      value.destroy();
      return Candidate(
        ip: ctx.ip,
        brand: Brand.tuya,
        protocol: 'tuya',
        needsKey: true,
        evidence: const ['tcp 6668 open'],
      );
    }
    return null;
  }

  Future<Result<_TuyaConn>> _conn(Device d) async {
    final tid = tuyaIdOf(d);
    (_gangs[tid] ??= {})[d.id] = d;
    final existing = _conns[tid];
    if (existing != null && existing.isOpen) return Ok(existing);
    final key = await _secrets.get(tid, SecretName.localKey);
    if (key == null) return Err(DeviceError.auth('no local key for $tid'));
    final version = versionOf(d);
    final TuyaCodec codec;
    try {
      codec = TuyaCodec.forVersion(version, key);
    } on ArgumentError catch (e) {
      return Err(DeviceError.unsupported('tuya: ${e.message}'));
    }
    final s = await _sockets.tcp(d.ip, d.port ?? port, timeout: timeout);
    if (s case Err(:final error)) return Err(error);
    final conn = _TuyaConn(
      (s as Ok<Socket>).value,
      codec,
      TuyaPayloads(
        tid,
        device22: d.meta['tuyaDevice22'] == true,
        version: version,
      ),
      timeout: timeout,
      heartbeatEvery: heartbeatEvery,
      now: _now,
      onStatus: (dps) {
        for (final g in (_gangs[tid] ?? {d.id: d}).values) {
          _emitStatus(g, dps);
        }
      },
    );
    if (codec is TuyaSessionCodec) {
      final n = await conn.negotiate();
      if (n case Err(:final error)) {
        conn.close();
        return Err(error);
      }
    }
    return Ok(_conns[tid] = conn);
  }

  /// Queries all DPs, switching to device22 mode if the device asks for it.
  Future<Result<Map<String, Object?>>> queryDps(Device d) =>
      guarded(_tag, 'query', () async {
        final c = await _conn(d);
        if (c case Err(:final error)) return Err(error);
        final conn = (c as Ok<_TuyaConn>).value;
        final map = dpMapOf(d);
        for (var attempt = 0; attempt < 2; attempt++) {
          final (cmd, json) = conn.payloads.dpQuery(_now(), dps: map.values);
          final r = await conn.request(cmd, json);
          if (r case Err(:final error)) return Err(error);
          switch ((r as Ok<TuyaDecoded>).value) {
            case TuyaJson(:final json) when json['dps'] is Map:
              return Ok((json['dps']! as Map).cast<String, Object?>());
            case TuyaDevice22():
              log.i(_tag, '${d.id}: device22 detected, retrying query');
              conn.payloads = TuyaPayloads(
                tuyaIdOf(d),
                device22: true,
                version: conn.payloads.version,
              );
            case final other:
              return Err(DeviceError.protocol('tuya: unexpected reply $other'));
          }
        }
        return Err(DeviceError.protocol('tuya: no DPs after device22 switch'));
      });

  /// True once the adapter learned the device needs device22 queries (persist in meta).
  bool isDevice22(Device d) => _conns[tuyaIdOf(d)]?.payloads.device22 ?? false;

  DeviceState _stateFrom(Device d, Map<String, Object?> dps) {
    final map = d.dpMap ?? (gangOf(d) > 1 ? dpMapOf(d) : TuyaDp.detect(dps));
    final cd = dps['${map[TuyaDp.countdown]}'];
    final max = map[TuyaDp.valueMax];
    final b = dps['${map[TuyaDp.brightness]}'];
    final t = dps['${map[TuyaDp.colorTemp]}'];
    return DeviceState(
      on: dps['${map[TuyaDp.switch_]}'] as bool?,
      countdownLeft: cd is num && cd > 0 ? Duration(seconds: cd.toInt()) : null,
      brightness: b is num && max != null && max > 0
          ? (b * 100 / max).round().clamp(1, 100)
          : null,
      colorTemp: t is num && max != null && max > 0
          ? TuyaDp.kelvinMin +
                ((TuyaDp.kelvinMax - TuyaDp.kelvinMin) * t / max).round()
          : null,
      at: _now(),
    );
  }

  @override
  Future<Result<DeviceState>> getState(Device d) async =>
      (await queryDps(d)).map((dps) => _stateFrom(d, dps));

  Future<Result<void>> setDps(Device d, Map<int, Object?> dps) =>
      guarded(_tag, 'control', () async {
        final c = await _conn(d);
        if (c case Err(:final error)) return Err(error);
        final conn = (c as Ok<_TuyaConn>).value;
        final (cmd, json) = conn.payloads.control(_now(), dps);
        return (await conn.request(cmd, json)).map((_) {});
      });

  @override
  Future<Result<void>> setPower(Device d, bool on) =>
      setDps(d, {dpMapOf(d)[TuyaDp.switch_]!: on});

  /// tinytuya BulbDevice.set_white(): mode "white" + brightness (+ switch on), value =
  /// int(value_max * pct // 100) as in set_brightness_percentage(), not below value_min.
  @override
  Future<Result<void>> setBrightness(Device d, int pct) {
    final map = dpMapOf(d);
    final dp = map[TuyaDp.brightness];
    final max = map[TuyaDp.valueMax];
    if (dp == null || max == null) {
      return Future.value(Err(DeviceError.unsupported('brightness')));
    }
    final v = (max * pct.clamp(0, 100) ~/ 100).clamp(
      map[TuyaDp.valueMin] ?? 0,
      max,
    );
    return setDps(d, {
      ?map[TuyaDp.mode]: TuyaDp.modeWhite,
      dp: v,
      map[TuyaDp.switch_]!: true,
    });
  }

  /// tinytuya BulbDevice.set_colourtemp(): mode "white" + colourtemp (+ switch on).
  @override
  Future<Result<void>> setColorTemp(Device d, int kelvin) {
    final map = dpMapOf(d);
    final dp = map[TuyaDp.colorTemp];
    final max = map[TuyaDp.valueMax];
    if (dp == null || max == null) {
      return Future.value(Err(DeviceError.unsupported('color temperature')));
    }
    final k = kelvin.clamp(TuyaDp.kelvinMin, TuyaDp.kelvinMax);
    final v =
        (max * (k - TuyaDp.kelvinMin) / (TuyaDp.kelvinMax - TuyaDp.kelvinMin))
            .round();
    return setDps(d, {
      ?map[TuyaDp.mode]: TuyaDp.modeWhite,
      dp: v,
      map[TuyaDp.switch_]!: true,
    });
  }

  @override
  Duration? nativeCountdownMax(Device d) =>
      dpMapOf(d).containsKey(TuyaDp.countdown) ? countdownMax : null;

  /// Tuya countdowns flip the switch when they reach 0, so they can only end in the
  /// opposite of the current state. VERIFY on hardware (T3.6).
  @override
  bool canCountdownTo(Device d, bool endState, {bool? currentOn}) =>
      nativeCountdownMax(d) != null &&
      currentOn != null &&
      currentOn != endState;

  @override
  Future<Result<CountdownHandle>> setCountdown(
    Device d,
    Duration after,
    bool targetOn,
  ) async {
    final dp = dpMapOf(d)[TuyaDp.countdown];
    if (dp == null) return Err(DeviceError.unsupported('no countdown DP'));
    final s = await getState(d);
    if (s case Err(:final error)) return Err(error);
    if ((s as Ok<DeviceState>).value.on == targetOn) {
      return Err(
        DeviceError.protocol(
          'already ${targetOn ? 'on' : 'off'}: countdown flips',
        ),
      );
    }
    final r = await setDps(d, {dp: after.inSeconds});
    return r.map((_) => const <String, String>{});
  }

  @override
  Future<Result<Duration?>> getCountdown(Device d, CountdownHandle? h) async {
    final dp = dpMapOf(d)[TuyaDp.countdown];
    if (dp == null) return Err(DeviceError.unsupported('no countdown DP'));
    return (await queryDps(d)).map((dps) {
      final v = dps['$dp'];
      return v is num && v > 0 ? Duration(seconds: v.toInt()) : null;
    });
  }

  @override
  Future<Result<void>> cancelCountdown(Device d, CountdownHandle? h) async {
    final dp = dpMapOf(d)[TuyaDp.countdown];
    if (dp == null) return Err(DeviceError.unsupported('no countdown DP'));
    return setDps(d, {dp: 0});
  }

  @override
  Stream<DeviceState>? watch(Device d) {
    // Closed in disposeAll().
    // ignore: close_sinks
    final ctl = _watchers.putIfAbsent(
      d.id,
      StreamController<DeviceState>.broadcast,
    );
    unawaited(_conn(d)); // open the connection so STATUS pushes arrive
    return ctl.stream;
  }

  void _emitStatus(Device d, Map<String, Object?> dps) {
    // Owned by _watchers; closed in disposeAll().
    // ignore: close_sinks
    final ctl = _watchers[d.id];
    if (ctl == null || ctl.isClosed) return;
    // Pushes carry only changed DPs; report what we can.
    final map = dpMapOf(d);
    final sw = dps['${map[TuyaDp.switch_]}'];
    if (sw is bool) ctl.add(_stateFrom(d, dps));
  }

  @override
  Future<void> dispose(Device d) async {
    final tid = tuyaIdOf(d);
    _gangs[tid]?.remove(d.id);
    _conns.remove(tid)?.close();
  }

  @override
  Future<void> disposeAll() async {
    for (final c in _conns.values) {
      c.close();
    }
    _conns.clear();
    _gangs.clear();
    for (final w in _watchers.values) {
      await w.close();
    }
    _watchers.clear();
  }
}

/// One TCP session to a Tuya device: request/reply by sequence number, STATUS pushes,
/// heartbeats. Closed on any socket error; the adapter reconnects on the next call.
class _TuyaConn {
  _TuyaConn(
    this._socket,
    this._codec,
    this.payloads, {
    required this.timeout,
    required Duration heartbeatEvery,
    required this.now,
    required this.onStatus,
  }) {
    _sub = _socket.listen(
      _onData,
      onError: (Object _) => close(),
      onDone: close,
      cancelOnError: true,
    );
    _heartbeat = Timer.periodic(heartbeatEvery, (_) => _beat());
  }

  final Socket _socket;
  final TuyaCodec _codec;
  TuyaPayloads payloads;
  final Duration timeout;
  final DateTime Function() now;
  final void Function(Map<String, Object?> dps) onStatus;

  late final _decoder = TuyaFrameDecoder(hmacKey: _codec.frameKey);
  final Map<int, Completer<TuyaFrame>> _pending = {};

  /// Command each pending request expects back (3.5 replies carry the device's own
  /// incrementing seqno, not ours — tinytuya XenonDevice._get_retcode).
  final Map<int, int> _pendingCmd = {};
  Completer<TuyaFrame>? _negotiation;
  late final StreamSubscription<Uint8List> _sub;
  late final Timer _heartbeat;
  int _seq = 1;
  int _missedBeats = 0;
  bool _open = true;

  bool get isOpen => _open;

  void _onData(Uint8List data) {
    final List<TuyaFrame> frames;
    try {
      frames = _decoder.add(data);
    } on TuyaDecodeException {
      close();
      return;
    }
    for (final f in frames) {
      final neg = _negotiation;
      if (neg != null && f.cmd == TuyaCmd.sessKeyNegResp) {
        _negotiation = null;
        neg.complete(f); // checked (HMAC included) by negotiateFinish
        continue;
      }
      if (!f.crcOk) continue;
      if (f.cmd == TuyaCmd.status) {
        _handleStatus(f);
        continue;
      }
      final seq = _codec.version == '3.5'
          ? _pendingCmd.entries
                .where((e) => e.value == f.cmd)
                .map((e) => e.key)
                .firstOrNull
          : f.seq;
      final waiter = seq == null ? null : _pending.remove(seq);
      if (seq != null) _pendingCmd.remove(seq);
      if (waiter != null) {
        waiter.complete(f);
      } else if (f.cmd == TuyaCmd.heartBeat) {
        _missedBeats = 0;
      }
    }
  }

  void _handleStatus(TuyaFrame f) {
    try {
      if (_codec.decode(f.payload, device22: payloads.device22) case TuyaJson(
        :final json,
      )) {
        final dps = json['dps'];
        if (dps is Map) onStatus(dps.cast<String, Object?>());
      }
    } on Object {
      // A garbled push is not worth dropping the session for.
    }
  }

  /// Protocol 3.4/3.5 session key negotiation (tinytuya XenonDevice._negotiate_session_key).
  /// A device that cannot prove it knows the local key → auth error.
  Future<Result<void>> negotiate() async {
    final codec = _codec as TuyaSessionCodec;
    final rnd = Random.secure();
    final nonce = Uint8List.fromList(
      List.generate(16, (_) => rnd.nextInt(256)),
    );
    final waiter = _negotiation = Completer<TuyaFrame>();
    try {
      _socket.add(codec.negotiateStart(_seq++, nonce));
      final resp = await waiter.future.timeout(timeout);
      _socket.add(codec.negotiateFinish(_seq++, resp));
      _decoder.hmacKey = codec.frameKey;
      return const Ok(null);
    } on TimeoutException {
      return Err(DeviceError.timeout('tuya 3.4: no session key reply'));
    } on TuyaDecodeException catch (e) {
      return Err(DeviceError.auth('tuya 3.4: ${e.message}; wrong key?'));
    } on SocketException catch (e) {
      return Err(mapSocketError(e, 'tuya'));
    } on StateError {
      // The frame's HMAC is keyed with the local key, so a device with another key
      // cannot verify step 1 and hangs up. VERIFY on hardware that it closes (rather
      // than staying silent, which ends up as a timeout above).
      return Err(
        DeviceError.auth(
          'tuya 3.4: device closed during key negotiation; wrong key?',
        ),
      );
    } finally {
      _negotiation = null;
    }
  }

  Future<Result<TuyaDecoded>> request(int cmd, String json) async {
    if (!_open) return Err(DeviceError.offline('tuya: connection closed'));
    final seq = _seq++;
    final waiter = Completer<TuyaFrame>();
    _pending[seq] = waiter;
    _pendingCmd[seq] = cmd;
    try {
      _socket.add(_codec.encode(seq, cmd, json));
      final f = await waiter.future.timeout(timeout);
      if (f.retcode != null && f.retcode != 0) {
        return Err(DeviceError.protocol('tuya: retcode ${f.retcode}'));
      }
      return Ok(_codec.decode(f.payload, device22: payloads.device22));
    } on TimeoutException {
      _pending.remove(seq);
      _pendingCmd.remove(seq);
      return Err(DeviceError.timeout('tuya: no reply to cmd $cmd'));
    } on StateError {
      return Err(DeviceError.offline('tuya: connection closed'));
    } on SocketException catch (e) {
      close();
      return Err(mapSocketError(e, 'tuya'));
    } on TuyaDecodeException catch (e) {
      return Err(
        DeviceError.auth(
          'tuya: cannot decrypt reply (${e.message}); wrong key?',
        ),
      );
    } on FormatException catch (e) {
      return Err(
        DeviceError.auth(
          'tuya: cannot decode reply (${e.message}); wrong key?',
        ),
      );
    }
  }

  Future<void> _beat() async {
    if (!_open || _negotiation != null) return;
    if (_missedBeats >= 2) {
      close();
      return;
    }
    _missedBeats++;
    final (cmd, json) = payloads.heartBeat();
    try {
      _socket.add(_codec.encode(_seq++, cmd, json));
    } on Object {
      close();
    }
  }

  void close() {
    if (!_open) return;
    _open = false;
    _heartbeat.cancel();
    unawaited(_sub.cancel());
    _socket.destroy();
    for (final w in _pending.values) {
      if (!w.isCompleted) {
        w.completeError(StateError('closed'));
      }
    }
    _pending.clear();
    _pendingCmd.clear();
    final neg = _negotiation;
    if (neg != null && !neg.isCompleted) {
      neg.completeError(StateError('closed'));
    }
  }
}
