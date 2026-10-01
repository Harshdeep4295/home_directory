import 'dart:async';
import 'dart:convert';

import '../core/log.dart';
import '../core/models.dart';
import '../core/result.dart';
import '../registry/repositories.dart';
import '../registry/secret_store.dart';
import 'camera.dart';
import 'rtsp_client.dart';

/// Adds, lists and removes cameras (T9.4). Only reads from cameras: it never changes or
/// resets a camera's password or settings.
class CameraService {
  CameraService(this._rtsp, this._secrets, this._settings);

  final RtspClient _rtsp;
  final SecretStore _secrets;
  final SettingsRepository _settings;
  final _changes = StreamController<List<Camera>>.broadcast();

  static const _key = 'cameras';
  static const _tag = 'camera';
  static const defaultUser = 'admin';

  /// Emits the camera list after every change.
  Stream<List<Camera>> get changes => _changes.stream;

  Future<List<Camera>> all() async {
    final raw = await _settings.get(_key);
    if (raw == null) return const [];
    try {
      return [
        for (final j in jsonDecode(raw) as List<Object?>)
          Camera.fromJson((j! as Map).cast<String, Object?>()),
      ];
    } on Object catch (e) {
      log.w(_tag, 'stored camera list unreadable', e);
      return const [];
    }
  }

  Future<void> _save(List<Camera> cams) async {
    await _settings.set(_key, jsonEncode([for (final c in cams) c.toJson()]));
    _changes.add(cams);
  }

  /// Checks [user]/[password] against the camera (RTSP DESCRIBE), finds its main and
  /// sub stream, then stores it. Wrong credentials → auth error; nothing is changed on
  /// the camera.
  Future<Result<Camera>> add(
    Candidate c, {
    required String name,
    String user = defaultUser,
    required String password,
    String? roomId,
    int port = 554,
  }) async {
    final main = await _rtsp.probe(
      c.ip,
      port,
      user,
      password,
      RtspClient.mainPaths,
      firstOnly: true,
    );
    switch (main) {
      case Err(:final error):
        return Err(error);
      case Ok(value: StreamProbe(authFailed: true)):
        return Err(
          DeviceError.auth('the camera did not accept this user / password'),
        );
      case Ok(value: StreamProbe(working: [])):
        return Err(
          DeviceError.unsupported(
            'the camera answered but offers no known stream (RTSP may be off)',
          ),
        );
      case Ok():
        break;
    }
    final sub = await _rtsp.probe(
      c.ip,
      port,
      user,
      password,
      RtspClient.subPaths,
      firstOnly: true,
    );
    final cam = Camera(
      id: c.mac ?? c.deviceId ?? 'ip:${c.ip}',
      name: name,
      ip: c.ip,
      port: port,
      model: c.model,
      mainPath: main.valueOrNull!.working.first,
      subPath: sub.valueOrNull?.working.firstOrNull,
      roomId: roomId,
    );
    await _secrets.set(cam.id, SecretName.username, user);
    await _secrets.set(cam.id, SecretName.password, password);
    await put(cam);
    log.i(_tag, 'added ${cam.name} (${cam.mainPath}, sub ${cam.subPath})');
    return Ok(cam);
  }

  Future<void> remove(String id) async {
    await _save([...(await all()).where((c) => c.id != id)]);
    await _secrets.deleteDevice(id);
  }

  /// Inserts or replaces [cam] (credentials are not touched).
  Future<void> put(Camera cam) async =>
      _save([...(await all()).where((c) => c.id != cam.id), cam]);

  /// RTSP URL with stored credentials, for the player only. Never log it.
  Future<String?> streamUrl(Camera cam, {bool sub = false}) async {
    final user = await _secrets.get(cam.id, SecretName.username);
    final pw = await _secrets.get(cam.id, SecretName.password);
    if (pw == null) return null;
    return cam.streamUrl(user ?? defaultUser, pw, sub: sub);
  }

  /// Camera ids / IPs already added, to hide them from the Add devices list.
  Future<Set<String>> knownKeys() async => {
    for (final c in await all()) ...[c.id, c.ip],
  };

  Future<void> dispose() => _changes.close();
}
