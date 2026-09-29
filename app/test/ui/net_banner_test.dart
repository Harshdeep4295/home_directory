import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_home/net/platform_bridge.dart';
import 'package:offline_home/ui/widgets/net_banner.dart';

void main() {
  Future<void> pump(WidgetTester t, NetInfo n) => t.pumpWidget(
    MaterialApp(
      home: Scaffold(body: NetBannerView(net: n)),
    ),
  );

  testWidgets('local mode, no wifi, and nothing', (t) async {
    await pump(t, const NetInfo(wifi: true, internet: false));
    expect(find.text(NetBannerView.localModeText), findsOneWidget);

    await pump(t, const NetInfo(wifi: false));
    expect(find.text(NetBannerView.noWifiText), findsOneWidget);

    await pump(t, const NetInfo(wifi: true, internet: true));
    expect(find.byType(MaterialBanner), findsNothing);
  });
}
