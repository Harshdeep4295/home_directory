import 'package:flutter/material.dart';

import '../../net/network_monitor.dart';
import '../../net/platform_bridge.dart';

/// "Internet down · Local mode" (info) or "Connect to home Wi-Fi" (blocking), per
/// PSEUDOCODE §3.4. Renders nothing when the network is fine.
class NetBannerView extends StatelessWidget {
  const NetBannerView({super.key, required this.net});
  final NetInfo net;

  static const localModeText = 'Internet down · Local mode';
  static const noWifiText = 'Connect to home Wi-Fi';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return switch (bannerFor(net)) {
      NetBanner.none => const SizedBox.shrink(),
      NetBanner.localMode => MaterialBanner(
        leading: const Icon(Icons.wifi_off_outlined),
        content: const Text(localModeText),
        backgroundColor: scheme.secondaryContainer,
        actions: const [SizedBox.shrink()],
      ),
      NetBanner.noWifi => MaterialBanner(
        leading: const Icon(Icons.signal_wifi_bad),
        content: const Text(noWifiText),
        backgroundColor: scheme.errorContainer,
        actions: const [SizedBox.shrink()],
      ),
    };
  }
}
