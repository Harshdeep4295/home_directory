import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// One simulator entry printed by sim/run.py.
class SimInfo {
  SimInfo(Map<String, Object?> m)
    : kind = m['kind']! as String,
      protocol = m['protocol']! as String,
      host = m['host']! as String,
      port = (m['port']! as num).toInt(),
      id = m['id']! as String;

  final String kind;
  final String protocol;
  final String host;
  final int port;
  final String id;
}

/// Runs `python3 sim/run.py --devices <spec>` for the duration of a test.
/// Python is taken from $OH_PYTHON, else `python3`.
class SimProcess {
  SimProcess._(this._process, this.devices);

  final Process _process;
  final Map<String, SimInfo> devices;
  bool _stopped = false;

  SimInfo operator [](String name) => devices[name]!;

  static Future<SimProcess> start(String spec) async {
    final python = Platform.environment['OH_PYTHON'] ?? 'python3';
    final runPy = File('../sim/run.py').absolute.path;
    final p = await Process.start(python, [runPy, '--devices', spec]);
    final stderr = StringBuffer();
    p.stderr.transform(utf8.decoder).listen(stderr.write);
    final line = await p.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .first
        .timeout(
          const Duration(seconds: 15),
          onTimeout: () => throw StateError('sim did not start: $stderr'),
        );
    final map = (jsonDecode(line) as Map<String, Object?>).map(
      (k, v) => MapEntry(k, SimInfo(v! as Map<String, Object?>)),
    );
    return SimProcess._(p, map);
  }

  /// Stops every simulator in this process (closing stdin makes run.py exit).
  Future<void> stop() async {
    if (_stopped) return;
    _stopped = true;
    await _process.stdin.close();
    final code = await _process.exitCode.timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        _process.kill();
        return -1;
      },
    );
    if (code != 0 && code != -1) {
      throw StateError('sim exited with $code');
    }
  }
}
