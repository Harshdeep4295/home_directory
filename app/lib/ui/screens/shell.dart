import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../widgets/net_banner.dart';
import 'home_screen.dart';

/// Bottom navigation: Home · Timers · Settings. Screens arrive in T5.2–T5.7; the
/// network banner sits above all of them.
class Shell extends ConsumerStatefulWidget {
  const Shell({super.key, this.pages});

  /// Injected by later tasks / tests; defaults to placeholders.
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

  static final defaultPages = [
    ShellPage(
      'Home',
      Icons.home_outlined,
      Icons.home,
      (_) => const HomeScreen(),
    ),
    ShellPage(
      'Timers',
      Icons.timer_outlined,
      Icons.timer,
      (_) => const _Placeholder('Timers'),
    ),
    ShellPage(
      'Settings',
      Icons.settings_outlined,
      Icons.settings,
      (_) => const _Placeholder('Settings'),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final pages = widget.pages ?? defaultPages;
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

class _Placeholder extends StatelessWidget {
  const _Placeholder(this.title);
  final String title;
  @override
  Widget build(BuildContext context) => Center(child: Text(title));
}
