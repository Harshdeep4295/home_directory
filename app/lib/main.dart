import 'package:flutter/material.dart';

import 'app/services.dart';
import 'net/platform_bridge.dart';
import 'ui/debug/net_debug_screen.dart';
import 'ui/debug/scan_debug_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final services = await AppServices.create();
  runApp(OfflineHomeApp(platform: services.platform, services: services));
}

/// Placeholder shell with the debug screens; the real shell arrives in T5.1.
class OfflineHomeApp extends StatelessWidget {
  const OfflineHomeApp({super.key, required this.platform, this.services});
  final PlatformBridge platform;
  final AppServices? services;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Offline Home',
      home: Builder(
        builder: (context) => NetDebugScreen(
          platform: platform,
          onOpenScan: services == null
              ? null
              : () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ScanDebugScreen(services: services!),
                  ),
                ),
        ),
      ),
    );
  }
}
