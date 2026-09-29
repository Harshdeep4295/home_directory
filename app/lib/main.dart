import 'package:flutter/material.dart';

import 'net/platform_bridge.dart';
import 'ui/debug/net_debug_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final platform = platformBridgeForHost();
  await platform.init();
  runApp(OfflineHomeApp(platform: platform));
}

/// Placeholder shell showing the network debug screen; the real shell arrives in T5.1.
class OfflineHomeApp extends StatelessWidget {
  const OfflineHomeApp({super.key, required this.platform});
  final PlatformBridge platform;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Offline Home',
      home: NetDebugScreen(platform: platform),
    );
  }
}
