import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_home/cameras/camera.dart';
import 'package:offline_home/cameras/camera_player.dart';
import 'package:offline_home/registry/secret_store.dart';
import 'package:offline_home/ui/providers.dart';
import 'package:offline_home/ui/screens/camera_view_screen.dart';
import 'package:offline_home/ui/screens/home_screen.dart';
import 'package:offline_home/ui/widgets/camera_tile.dart';

import '../support/test_services.dart';

/// A real 1×1 PNG (Image.memory decodes it).
final frame = base64.decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

class FakeCameraPlayer implements CameraPlayer {
  FakeCameraPlayer(this.log, {this.video = true});
  final List<String> log;
  final bool video;
  final _width = StreamController<int>.broadcast();
  final _errors = StreamController<String>.broadcast();

  @override
  Future<void> open(String url) async {
    log.add('open $url');
    if (video) scheduleMicrotask(() => _width.add(1280));
  }

  @override
  Stream<int> get videoWidth => _width.stream;
  @override
  Stream<String> get errors => _errors.stream;
  @override
  Future<Uint8List?> snapshot() async => frame;
  @override
  Widget view({BoxFit fit = BoxFit.contain}) =>
      const ColoredBox(key: Key('video'), color: Colors.black);
  @override
  Future<void> dispose() async {
    log.add('dispose');
    await _width.close();
    await _errors.close();
  }
}

const cam = Camera(
  id: 'c056e3123456',
  name: 'Gate',
  ip: '192.168.1.40',
  model: 'CS-C6N',
  mainPath: '/h264/ch1/main/av_stream',
  subPath: '/h264/ch1/sub/av_stream',
);

void main() {
  setUp(CameraTile.thumbnails.clear);

  Future<TestServices> withCamera(WidgetTester tester) async {
    final t = await TestServices.inTester(tester);
    await tester.runAsync(() async {
      await t.services.cameras.put(cam);
      await t.services.secrets.set(cam.id, SecretName.username, 'admin');
      await t.services.secrets.set(cam.id, SecretName.password, 'ABC DEF');
    });
    return t;
  }

  testWidgets('Home shows a Cameras row with a grabbed sub-stream frame', (
    tester,
  ) async {
    final t = await withCamera(tester);
    final log = <String>[];
    Camera? opened;
    await tester.pumpWidget(
      t.wrap(
        MaterialApp(home: HomeScreen(onOpenCamera: (c) => opened = c)),
        overrides: [
          cameraPlayerFactoryProvider.overrideWithValue(
            () => FakeCameraPlayer(log),
          ),
        ],
      ),
    );
    await TestServices.settle(tester, ms: 100);
    expect(find.text('Cameras'), findsOneWidget);
    expect(find.text('Gate'), findsOneWidget);
    // grabFrame waits for a settled frame (fake time in widget tests).
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(
      log.first,
      'open rtsp://admin:ABC%20DEF@192.168.1.40:554/h264/ch1/sub/av_stream',
    );
    expect(log, contains('dispose'), reason: 'thumbnail player is closed');
    expect(CameraTile.thumbnails[cam.id], frame);
    expect(find.byType(Image), findsOneWidget);
    await tester.tap(find.text('Gate'));
    expect(opened?.id, cam.id);
    await t.tearDown(tester);
  });

  testWidgets('live view: HD, switch to SD, remove', (tester) async {
    final t = await withCamera(tester);
    final log = <String>[];
    await tester.pumpWidget(
      t.wrap(
        const MaterialApp(home: CameraViewScreen(camera: cam)),
        overrides: [
          cameraPlayerFactoryProvider.overrideWithValue(
            () => FakeCameraPlayer(log),
          ),
        ],
      ),
    );
    await TestServices.settle(tester, ms: 100);
    expect(find.byKey(const Key('video')), findsOneWidget);
    expect(log.single, endsWith('/h264/ch1/main/av_stream'));
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.tap(find.text('SD'));
    await TestServices.settle(tester, ms: 100);
    expect(log, ['open ${log.first.substring(5)}', 'dispose', isA<String>()]);
    expect(log.last, endsWith('/h264/ch1/sub/av_stream'));

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove camera'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
    await TestServices.settle(tester, ms: 100);
    expect(await tester.runAsync(t.services.cameras.all), isEmpty);
    await t.tearDown(tester);
  });

  testWidgets('no video → hint and Retry', (tester) async {
    final t = await withCamera(tester);
    final log = <String>[];
    await tester.pumpWidget(
      t.wrap(
        const MaterialApp(home: CameraViewScreen(camera: cam)),
        overrides: [
          cameraPlayerFactoryProvider.overrideWithValue(
            () => FakeCameraPlayer(log, video: false),
          ),
        ],
      ),
    );
    await TestServices.settle(tester, ms: 100);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pump(const Duration(seconds: 13));
    expect(find.textContaining('No video yet'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    await t.tearDown(tester);
  });
}
