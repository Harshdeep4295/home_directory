import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../cameras/camera.dart';
import '../../cameras/camera_player.dart';
import '../file_access.dart';
import '../providers.dart';

/// Full-screen live view of one camera (T9.5): main (HD) or sub (SD) stream, snapshot,
/// remove. Video only, muted.
class CameraViewScreen extends ConsumerStatefulWidget {
  const CameraViewScreen({super.key, required this.camera});
  final Camera camera;

  @override
  ConsumerState<CameraViewScreen> createState() => _CameraViewScreenState();
}

class _CameraViewScreenState extends ConsumerState<CameraViewScreen> {
  CameraPlayer? _player;
  final _subs = <StreamSubscription<Object>>[];
  Timer? _noVideo;
  bool _sub = false;
  bool _live = false;
  String? _error;

  /// No first frame within this time → show a hint.
  static const noVideoAfter = Duration(seconds: 12);

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  Future<void> _stop() async {
    _noVideo?.cancel();
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    final p = _player;
    _player = null;
    await p?.dispose();
  }

  Future<void> _start() async {
    await _stop();
    if (!mounted) return;
    setState(() {
      _live = false;
      _error = null;
    });
    final url = await ref
        .read(servicesProvider)
        .cameras
        .streamUrl(widget.camera, sub: _sub);
    if (!mounted) return;
    if (url == null) {
      setState(() => _error = 'No password stored for this camera.');
      return;
    }
    final p = ref.read(cameraPlayerFactoryProvider)();
    _player = p;
    _subs
      ..add(
        p.videoWidth.listen((w) {
          if (w > 0 && mounted) {
            _noVideo?.cancel();
            setState(() {
              _live = true;
              _error = null;
            });
          }
        }),
      )
      ..add(
        p.errors.listen((e) {
          // libmpv messages can echo the URL: never show or log them raw.
          if (mounted && !_live) {
            setState(() => _error = 'The stream stopped. Tap Retry.');
          }
        }),
      );
    _noVideo = Timer(noVideoAfter, () {
      if (mounted && !_live) {
        setState(
          () => _error =
              'No video yet. Is the camera on this Wi-Fi and is video '
              'encryption off in its app?',
        );
      }
    });
    setState(() {});
    await p.open(url);
  }

  Future<void> _snapshot() async {
    final bytes = await _player?.snapshot();
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    if (bytes == null) {
      messenger.showSnackBar(const SnackBar(content: Text('No frame yet.')));
      return;
    }
    final ts = DateTime.now()
        .toIso8601String()
        .replaceAll(RegExp(r'[:.]'), '-')
        .substring(0, 19);
    final where = await ref
        .read(fileAccessProvider)
        .save('${widget.camera.name}-$ts.jpg', bytes, mimeType: 'image/jpeg');
    if (where != null && mounted) {
      messenger.showSnackBar(const SnackBar(content: Text('Snapshot saved.')));
    }
  }

  Future<void> _remove() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove ${widget.camera.name}?'),
        content: const Text(
          'Forgets the camera and its stored code on this phone. '
          'Nothing changes on the camera.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _stop();
    await ref.read(servicesProvider).cameras.remove(widget.camera.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    unawaited(_stop());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = _player;
    final cam = widget.camera;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(cam.name),
        actions: [
          IconButton(
            tooltip: 'Snapshot',
            onPressed: _live ? _snapshot : null,
            icon: const Icon(Icons.photo_camera_outlined),
          ),
          PopupMenuButton<String>(
            onSelected: (v) => v == 'remove' ? _remove() : null,
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'remove', child: Text('Remove camera')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (p != null) Positioned.fill(child: p.view()),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white),
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: _start,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                else if (!_live)
                  const CircularProgressIndicator(),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: SegmentedButton<bool>(
              segments: [
                const ButtonSegment(value: false, label: Text('HD')),
                ButtonSegment(
                  value: true,
                  label: const Text('SD'),
                  enabled: cam.subPath != null,
                ),
              ],
              selected: {_sub},
              onSelectionChanged: (v) {
                setState(() => _sub = v.first);
                unawaited(_start());
              },
            ),
          ),
          if (cam.model != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                '${cam.model} · ${cam.ip}',
                style: const TextStyle(color: Colors.white54),
              ),
            ),
        ],
      ),
    );
  }
}
