import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../home_widget_sync.dart';
import '../providers.dart';
import '../widgets/net_banner.dart';
import 'add_devices_screen.dart';
import 'camera_view_screen.dart';
import 'device_detail_screen.dart';
import 'home_screen.dart';
import 'settings_screen.dart';
import 'timers_screen.dart';
import 'voice_sheet.dart';

/// Bottom navigation: Home · Timers · Settings, with the network banner above.
class Shell extends ConsumerStatefulWidget {
  const Shell({super.key, this.pages});

  /// Injected by tests; defaults to Home, Timers and Settings.
  final List<ShellPage>? pages;

  @override
  ConsumerState<Shell> createState() => _ShellState();
}

class ShellPage {
  const ShellPage(this.label, this.icon, this.selectedIcon, this.builder);
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final WidgetBuilder builder;
}

class _ShellState extends ConsumerState<Shell> {
  int _index = 0;
  StreamSubscription<Uri?>? _clicks;

  @override
  void initState() {
    super.initState();
    final bridge = ref.read(homeWidgetBridgeProvider);
    _clicks = bridge.clicks.listen(_onWidgetUri);
    unawaited(bridge.initialUri().then(_onWidgetUri));
  }

  @override
  void dispose() {
    unawaited(_clicks?.cancel());
    super.dispose();
  }

  /// A tap on the home-screen widget or the quick-settings tile (T5.9).
  Future<void> _onWidgetUri(Uri? uri) async {
    if (!mounted) return;
    switch (parseWidgetUri(uri)) {
      case OpenVoice():
        setState(() => _index = 0);
        await showVoiceSheet(context, ref);
      case ToggleDevice(:final deviceId):
        final d = await ref.read(servicesProvider).devices.byId(deviceId);
        if (d != null && mounted) await HomeScreen.toggle(ref, d);
      case null:
        break;
    }
  }

  void _publishWidget() {
    final devices = ref.read(devicesProvider).value;
    if (devices == null) return;
    final states = ref.read(deviceStatesProvider).value ?? const {};
    unawaited(
      ref.read(homeWidgetBridgeProvider).publish(widgetData(devices, states)),
    );
  }

  static final defaultPages = [
    ShellPage(
      'Home',
      Icons.home_outlined,
      Icons.home,
      (context) => Consumer(
        builder: (context, ref, _) => HomeScreen(
          onMic: () => showVoiceSheet(context, ref),
          onAddDevices: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const AddDevicesScreen()),
          ),
          onOpenDevice: (d) => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => DeviceDetailScreen(deviceId: d.id),
            ),
          ),
          onOpenCamera: (c) => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => CameraViewScreen(camera: c),
            ),
          ),
        ),
      ),
    ),
    ShellPage(
      'Timers',
      Icons.timer_outlined,
      Icons.timer,
      (_) => const TimersScreen(),
    ),
    ShellPage(
      'Settings',
      Icons.settings_outlined,
      Icons.settings,
      (_) => const SettingsScreen(),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final pages = widget.pages ?? defaultPages;
    ref.listen(devicesProvider, (_, _) => _publishWidget());
    ref.listen(deviceStatesProvider, (_, _) => _publishWidget());
    final net = ref.watch(netStateProvider).value;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            if (net != null) NetBannerView(net: net),
            Expanded(child: pages[_index].builder(context)),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          for (final p in pages)
            NavigationDestination(
              icon: Icon(p.icon),
              selectedIcon: Icon(p.selectedIcon),
              label: p.label,
            ),
        ],
      ),
    );
  }
}
