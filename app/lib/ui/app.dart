import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';
import 'screens/first_run.dart';
import 'screens/shell.dart';
import 'theme.dart';

/// Root widget (T5.1). Hooks app lifecycle into the poller, timers and iOS ticker.
class OfflineHomeApp extends ConsumerStatefulWidget {
  const OfflineHomeApp({super.key});

  @override
  ConsumerState<OfflineHomeApp> createState() => _OfflineHomeAppState();
}

class _OfflineHomeAppState extends ConsumerState<OfflineHomeApp> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onResume: _onForeground,
      onPause: _onBackground,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _onForeground());
  }

  Future<void> _onForeground() async {
    final s = ref.read(servicesProvider);
    s.poller.onForeground(await s.devices.all());
    if (Platform.isIOS) s.phoneTicker.start();
    unawaited(s.timerService.reconcile());
  }

  void _onBackground() {
    final s = ref.read(servicesProvider);
    s.poller.onBackground();
    s.phoneTicker.stop();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Keep polling in sync with the registry while visible.
    ref.listen(devicesProvider, (_, next) {
      final devices = next.value;
      if (devices != null) {
        ref.read(servicesProvider).poller.onForeground(devices);
      }
    });
    return MaterialApp(
      title: 'Offline Home',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: switch (ref.watch(onboardedProvider)) {
        AsyncData(value: true) => const Shell(),
        AsyncData() => const FirstRunFlow(),
        _ => const Scaffold(body: Center(child: CircularProgressIndicator())),
      },
    );
  }
}
