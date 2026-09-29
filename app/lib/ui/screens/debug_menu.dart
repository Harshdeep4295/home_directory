import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../debug/net_debug_screen.dart';
import '../debug/scan_debug_screen.dart';
import '../debug/voice_debug_screen.dart';
import '../providers.dart';

/// Developer tools used by the hardware checks (Settings → Diagnostics).
class DebugMenu extends ConsumerWidget {
  const DebugMenu({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(servicesProvider);
    void open(Widget w) =>
        Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => w));
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.wifi),
          title: const Text('Network debug'),
          onTap: () => open(NetDebugScreen(platform: s.platform)),
        ),
        ListTile(
          leading: const Icon(Icons.radar),
          title: const Text('Scan + toggle'),
          onTap: () => open(ScanDebugScreen(services: s)),
        ),
        if (s.voice != null)
          ListTile(
            leading: const Icon(Icons.mic),
            title: const Text('Voice test'),
            onTap: () => open(VoiceDebugScreen(voice: s.voice!, stt: s.stt)),
          ),
      ],
    );
  }
}
