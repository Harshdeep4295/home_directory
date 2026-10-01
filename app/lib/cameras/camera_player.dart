import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// Video playback seam (T9.5): the app talks to this, tests use a fake. Audio is muted.
abstract interface class CameraPlayer {
  /// Starts playing [url] (an RTSP URL with credentials; never log it).
  Future<void> open(String url);

  /// Width of the decoded video; > 0 once the first frame arrived.
  Stream<int> get videoWidth;
  Stream<String> get errors;

  /// JPEG of the current frame.
  Future<Uint8List?> snapshot();
  Widget view({BoxFit fit = BoxFit.contain});
  Future<void> dispose();
}

typedef CameraPlayerFactory = CameraPlayer Function();

/// libmpv (media_kit) player tuned for live LAN cameras.
class MediaKitCameraPlayer implements CameraPlayer {
  MediaKitCameraPlayer()
    : _player = Player(
        configuration: const PlayerConfiguration(
          muted: true,
          // LAN streams only: no http(s)/tls, so a URL can never reach the internet.
          protocolWhitelist: ['rtsp', 'rtp', 'udp', 'tcp'],
          bufferSize: 4 * 1024 * 1024,
        ),
      ) {
    _video = VideoController(_player);
  }

  final Player _player;
  late final VideoController _video;

  static bool _initialized = false;

  /// Loads libmpv; call once before the first player (main()).
  static void ensureInitialized() {
    if (_initialized) return;
    MediaKit.ensureInitialized();
    _initialized = true;
  }

  @override
  Future<void> open(String url) async {
    final native = _player.platform;
    if (native is NativePlayer) {
      // mpv/ffmpeg options for low latency on a live camera.
      // VERIFY: delay on the owner's EZVIZ camera (hardware check #28).
      await native.setProperty('demuxer-lavf-o', 'rtsp_transport=tcp');
      await native.setProperty('cache', 'no');
      await native.setProperty('untimed', 'yes');
      await native.setProperty('video-latency-hacks', 'yes');
    }
    await _player.open(Media(url));
  }

  @override
  Stream<int> get videoWidth =>
      _player.stream.width.map((w) => w ?? 0).distinct();

  @override
  Stream<String> get errors => _player.stream.error;

  @override
  Future<Uint8List?> snapshot() => _player.screenshot();

  @override
  Widget view({BoxFit fit = BoxFit.contain}) =>
      Video(controller: _video, fit: fit, controls: null);

  @override
  Future<void> dispose() => _player.dispose();
}

/// Opens [url], waits for the first frame (max [timeout]), returns a JPEG of it and
/// closes the player. Used for Home thumbnails.
Future<Uint8List?> grabFrame(
  CameraPlayerFactory create,
  String url, {
  Duration timeout = const Duration(seconds: 8),
  Duration settle = const Duration(milliseconds: 600),
}) async {
  final p = create();
  try {
    final first = p.videoWidth.firstWhere((w) => w > 0);
    await p.open(url);
    await first.timeout(timeout);
    // Let the decoder show a full (key) frame rather than the first partial one.
    await Future<void>.delayed(settle);
    return await p.snapshot();
  } on Object {
    return null;
  } finally {
    await p.dispose();
  }
}
