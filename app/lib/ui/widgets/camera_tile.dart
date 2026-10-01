import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../cameras/camera.dart';
import '../../cameras/camera_player.dart';
import '../providers.dart';

/// Home tile for a camera: a still frame refreshed every [refresh] while visible
/// (T9.5). Tap opens live view.
class CameraTile extends ConsumerStatefulWidget {
  const CameraTile({
    super.key,
    required this.camera,
    this.onTap,
    this.refresh = const Duration(seconds: 20),
  });

  final Camera camera;
  final VoidCallback? onTap;
  final Duration refresh;

  /// Last frame per camera id, so tiles show something at once when Home reopens.
  static final thumbnails = <String, Uint8List>{};

  @override
  ConsumerState<CameraTile> createState() => _CameraTileState();
}

class _CameraTileState extends ConsumerState<CameraTile> {
  Timer? _timer;
  bool _grabbing = false;
  bool _failed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh only while visible (a covering route turns tickers off).
    if (TickerMode.valuesOf(context).enabled) {
      _timer ??= Timer.periodic(widget.refresh, (_) => unawaited(_grab()));
      if (!CameraTile.thumbnails.containsKey(widget.camera.id)) {
        unawaited(_grab());
      }
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  Future<void> _grab() async {
    if (_grabbing) return;
    _grabbing = true;
    try {
      final url = await ref
          .read(servicesProvider)
          .cameras
          .streamUrl(widget.camera, sub: true);
      if (url == null) return;
      final jpg = await grabFrame(ref.read(cameraPlayerFactoryProvider), url);
      if (!mounted) return;
      setState(() {
        _failed = jpg == null;
        if (jpg != null) CameraTile.thumbnails[widget.camera.id] = jpg;
      });
    } finally {
      _grabbing = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final jpg = CameraTile.thumbnails[widget.camera.id];
    final scheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (jpg != null)
              Image.memory(jpg, fit: BoxFit.cover, gaplessPlayback: true)
            else
              ColoredBox(
                color: scheme.surfaceContainerHighest,
                child: Icon(
                  _failed
                      ? Icons.videocam_off_outlined
                      : Icons.videocam_outlined,
                  size: 40,
                ),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                color: Colors.black54,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(
                  _failed && jpg == null
                      ? '${widget.camera.name} · no picture'
                      : widget.camera.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
