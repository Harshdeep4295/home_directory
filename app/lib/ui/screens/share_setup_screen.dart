import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/result.dart';
import '../../onboarding/share_setup/share_setup.dart';
import '../providers.dart';

/// Shows a one-time QR that hands this phone's whole setup (devices, places, rooms,
/// cameras, keys) to another phone on the same Wi-Fi (T10.4). Nothing goes to the
/// internet: the other phone downloads it straight from this one.
class ShareSetupScreen extends ConsumerStatefulWidget {
  const ShareSetupScreen({super.key, this.only, this.count});

  /// Device / camera ids to share; null = everything (T10.6).
  final Set<String>? only;
  final int? count;

  @override
  ConsumerState<ShareSetupScreen> createState() => _ShareSetupScreenState();
}

class _ShareSetupScreenState extends ConsumerState<ShareSetupScreen> {
  SetupOffer? _offer;
  String? _error;
  ShareEnd? _end;

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  Future<void> _start() async {
    setState(() {
      _offer = null;
      _error = null;
      _end = null;
    });
    final s = ref.read(servicesProvider);
    final ip = (await s.platform.netInfo()).ip;
    final r = await s.setupSender.start(ip, only: widget.only);
    if (!mounted) {
      r.valueOrNull?.cancel();
      return;
    }
    switch (r) {
      case Err(:final error):
        setState(() => _error = error.message);
      case Ok(:final value):
        setState(() => _offer = value);
        final end = await value.done;
        if (mounted) setState(() => _end = end);
    }
  }

  @override
  void dispose() {
    _offer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final offer = _offer;
    final theme = Theme.of(context);
    Widget body;
    if (_error != null) {
      body = _Message(icon: Icons.wifi_off, text: _error!, onRetry: _start);
    } else if (_end == ShareEnd.sent) {
      body = const _Message(
        icon: Icons.check_circle_outline,
        text: 'Setup sent. The other phone now has the devices and keys.',
      );
    } else if (_end != null) {
      body = _Message(
        icon: Icons.timer_off_outlined,
        text: 'The code expired.',
        onRetry: _start,
      );
    } else if (offer == null) {
      body = const Center(child: CircularProgressIndicator());
    } else {
      body = ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(12),
              child: QrImageView(
                key: const ValueKey('setup-qr'),
                data: offer.qr.encode(),
                size: 260,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'On the other phone: Offline Home → Settings → Receive setup, '
            'then scan this code.',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Text(
            'Both phones must be on this Wi-Fi. The code works once and for 5 '
            'minutes. It copies ${widget.only == null ? 'every device, place, room, camera and key' : 'the ${widget.count ?? widget.only!.length} chosen devices / cameras with their keys'}, '
            'encrypted, straight from this phone. Nothing goes to the internet.',
          ),
          const SizedBox(height: 12),
          Text(
            'Only show it to people you trust with your devices.',
            style: TextStyle(color: theme.colorScheme.error),
          ),
        ],
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Share setup')),
      body: body,
    );
  }
}

/// Scans a setup QR and imports it (T10.4).
class ReceiveSetupScreen extends ConsumerStatefulWidget {
  const ReceiveSetupScreen({super.key, this.onDone});

  /// Called after a successful import (onboarding moves on).
  final VoidCallback? onDone;

  @override
  ConsumerState<ReceiveSetupScreen> createState() => _ReceiveSetupScreenState();
}

class _ReceiveSetupScreenState extends ConsumerState<ReceiveSetupScreen> {
  bool _busy = false;
  String? _error;
  int? _imported;

  Future<void> _onCode(String code) async {
    if (_busy || _imported != null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final s = ref.read(servicesProvider);
    final r = await s.setupReceiver.receive(code);
    if (r case Ok()) await s.applySettings();
    if (!mounted) return;
    setState(() {
      _busy = false;
      switch (r) {
        case Ok(:final value):
          _imported = value;
        case Err(:final error):
          _error = error.kind == DeviceErrorKind.unsupported
              ? error.message
              : '${error.message.isEmpty ? 'Could not reach the other phone.' : error.message}'
                    '\nAre both phones on the same Wi-Fi?';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final scanner = ref.watch(qrScannerProvider);
    final Widget body;
    if (_imported case final n?) {
      body = _Message(
        icon: Icons.check_circle_outline,
        text:
            'Received $n devices (and any cameras) with their places and keys.',
        onDone: () {
          final cb = widget.onDone;
          cb != null ? cb() : Navigator.of(context).pop();
        },
      );
    } else {
      body = Column(
        children: [
          Expanded(child: scanner((c) => unawaited(_onCode(c)))),
          Padding(
            padding: const EdgeInsets.all(16),
            child: _busy
                ? const LinearProgressIndicator()
                : Text(
                    _error ??
                        'On the phone that has the setup: Settings → Share setup. '
                            'Scan its code; both phones on the same Wi-Fi.',
                    key: const ValueKey('receive-status'),
                    style: _error == null
                        ? null
                        : TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
          ),
        ],
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Receive setup')),
      body: body,
    );
  }
}

/// QR scanner: on-device (bundled ML Kit on Android, Vision on iOS); a fake in tests.
typedef QrScannerBuilder = Widget Function(void Function(String code) onCode);

final qrScannerProvider = Provider<QrScannerBuilder>(
  (ref) =>
      (onCode) => MobileScanner(
        onDetect: (capture) {
          for (final b in capture.barcodes) {
            final v = b.rawValue;
            if (v != null && v.startsWith(SetupQr.scheme)) {
              onCode(v);
              return;
            }
          }
        },
      ),
);

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.text,
    this.onRetry,
    this.onDone,
  });
  final IconData icon;
  final String text;
  final VoidCallback? onRetry;
  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48),
          const SizedBox(height: 12),
          Text(text, textAlign: TextAlign.center),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Try again')),
          ],
          if (onDone != null) ...[
            const SizedBox(height: 12),
            FilledButton(onPressed: onDone, child: const Text('Done')),
          ],
        ],
      ),
    ),
  );
}
