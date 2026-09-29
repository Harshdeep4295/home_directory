import 'package:flutter_test/flutter_test.dart';
import 'package:offline_home/net/network_monitor.dart';
import 'package:offline_home/net/platform_bridge.dart';

import '../support/fake_platform.dart';

const home = NetInfo(
  wifi: true,
  internet: true,
  ip: '192.168.1.37',
  prefix: 24,
);

void main() {
  test('bannerFor', () {
    expect(bannerFor(home), NetBanner.none);
    expect(
      bannerFor(const NetInfo(wifi: true, internet: false)),
      NetBanner.localMode,
    );
    expect(
      bannerFor(const NetInfo(wifi: true)),
      NetBanner.none,
    ); // iOS: unknown
    expect(
      bannerFor(const NetInfo(wifi: false, internet: true)),
      NetBanner.noWifi,
    );
  });

  test('seeds from netInfo, follows changes, drops duplicates', () async {
    final p = FakePlatformBridge(info: home);
    final m = NetworkMonitor(p);
    final seen = <NetInfo>[];
    m.states.listen(seen.add);
    await m.start();
    expect(m.current, home);

    const wanDown = NetInfo(
      wifi: true,
      internet: false,
      ip: '192.168.1.37',
      prefix: 24,
    );
    p
      ..emit(home) // duplicate
      ..emit(wanDown)
      ..emit(wanDown); // duplicate
    await pumpEventQueue();
    expect(seen, [home, wanDown]);
    await m.dispose();
    await p.dispose();
  });

  test('wifiChanges ignores internet-only changes', () async {
    final p = FakePlatformBridge(info: home);
    final m = NetworkMonitor(p);
    await m.start();
    final wifi = <NetInfo>[];
    m.wifiChanges.listen(wifi.add);

    p
      ..emit(
        const NetInfo(
          wifi: true,
          internet: false,
          ip: '192.168.1.37',
          prefix: 24,
        ),
      )
      ..emit(const NetInfo(wifi: false))
      ..emit(
        const NetInfo(
          wifi: true,
          internet: true,
          ip: '192.168.1.99',
          prefix: 24,
        ),
      );
    await pumpEventQueue();
    expect(wifi.map((n) => (n.wifi, n.ip)), [
      (false, null),
      (true, '192.168.1.99'),
    ]);
    await m.dispose();
    await p.dispose();
  });
}
