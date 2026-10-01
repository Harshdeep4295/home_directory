@Tags(['sim'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:offline_home/cameras/camera_service.dart';
import 'package:offline_home/cameras/rtsp_client.dart';
import 'package:offline_home/core/log.dart';
import 'package:offline_home/core/models.dart';
import 'package:offline_home/core/result.dart';
import 'package:offline_home/net/lan_socket_factory.dart';
import 'package:offline_home/registry/database.dart';
import 'package:offline_home/registry/repositories.dart';
import 'package:offline_home/registry/secret_store.dart';

import '../support/fake_platform.dart';
import '../support/sim_process.dart';

void main() {
  late SimProcess sim;
  late FakePlatformBridge platform;
  late AppDatabase db;
  late SecretStore secrets;
  late CameraService cams;
  late RtspClient rtsp;

  setUp(() async {
    sim = await SimProcess.start(
      'rtsp:password=QWERTY:paths=/h264/ch1/main/av_stream|/h264/ch1/sub/av_stream,'
      'rtsp:name=hik:password=pw1',
    );
    platform = FakePlatformBridge();
    db = AppDatabase.memory();
    secrets = SecretStore(MemorySecretBackend(), Redactor());
    rtsp = RtspClient(LanSocketFactory(platform));
    cams = CameraService(rtsp, secrets, SettingsRepository(db));
  });
  tearDown(() async {
    await sim.stop();
    await cams.dispose();
    await db.close();
    await platform.dispose();
  });

  Candidate cand() => const Candidate(
    ip: '127.0.0.1',
    mac: 'c056e3123456',
    brand: Brand.unknown,
    protocol: 'unknown',
    category: DeviceCategory.camera,
    model: 'CS-C6N',
  );

  test('EZVIZ paths: finds main + sub, stores credentials in SecretStore', () async {
    final r = await cams.add(
      cand(),
      name: 'Gate camera',
      password: 'QWERTY',
      port: sim['rtsp'].port,
    );
    final cam = r.valueOrNull!;
    expect(cam.mainPath, '/h264/ch1/main/av_stream');
    expect(cam.subPath, '/h264/ch1/sub/av_stream');
    expect(cam.id, 'c056e3123456');
    expect((await cams.all()).single.name, 'Gate camera');
    expect(await secrets.get(cam.id, SecretName.password), 'QWERTY');
    expect(
      await db.select(db.settings).get(),
      everyElement(predicate<SettingRow>((s) => !s.value.contains('QWERTY'))),
      reason: 'the password never lands in SQLite',
    );
    expect(
      await cams.streamUrl(cam, sub: true),
      'rtsp://admin:QWERTY@127.0.0.1:${sim['rtsp'].port}/h264/ch1/sub/av_stream',
    );
    await cams.remove(cam.id);
    expect(await cams.all(), isEmpty);
    expect(await secrets.get(cam.id, SecretName.password), isNull);
  });

  test('Hikvision default paths use /Streaming/Channels', () async {
    final r = await cams.add(
      cand(),
      name: 'Hik',
      password: 'pw1',
      port: sim['hik'].port,
    );
    expect(r.valueOrNull!.mainPath, '/Streaming/Channels/101');
    expect(r.valueOrNull!.subPath, '/Streaming/Channels/102');
  });

  test('wrong code → auth error, nothing stored', () async {
    final r = await cams.add(
      cand(),
      name: 'x',
      password: 'WRONG1',
      port: sim['rtsp'].port,
    );
    expect(r.errorOrNull!.kind, DeviceErrorKind.auth);
    expect(await cams.all(), isEmpty);
    expect(await secrets.get('c056e3123456', SecretName.password), isNull);
  });

  test('nothing listening → offline/refused error', () async {
    final port = sim['rtsp'].port;
    await sim.stop();
    final r = await rtsp.probe(
      '127.0.0.1',
      port,
      'admin',
      'x',
      RtspClient.mainPaths,
    );
    expect(r.errorOrNull, isNotNull);
  });
}
