import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/services.dart';
import '../../onboarding/permissions.dart';
import '../../voice/stt_service.dart';
import '../providers.dart';
import 'add_devices_screen.dart';

final permissionsProvider = Provider<PermissionsService>((ref) {
  final s = ref.watch(servicesProvider);
  return PlatformPermissions(
    s.platform,
    s.stt,
    s.phoneAlarms ?? NoopPhoneAlarms(),
  );
});

final onboardedProvider = FutureProvider<bool>(
  (ref) => ref.watch(servicesProvider).appSettings.onboarded(),
);

/// First run (T5.8, PSEUDOCODE §0.1): welcome → permissions → offline speech model →
/// add devices.
class FirstRunFlow extends ConsumerStatefulWidget {
  const FirstRunFlow({super.key, this.isIOS});
  final bool? isIOS;

  @override
  ConsumerState<FirstRunFlow> createState() => _FirstRunFlowState();
}

class _FirstRunFlowState extends ConsumerState<FirstRunFlow> {
  int _step = 0;
  final Map<PermissionKind, PermissionStatus> _status = {};
  SttCapabilities? _caps;

  bool get _ios => widget.isIOS ?? Platform.isIOS;

  static const _labels = {
    PermissionKind.localNetwork: (
      'Local network',
      'To find and control devices on your Wi-Fi',
    ),
    PermissionKind.microphone: (
      'Microphone & speech',
      'Only while you hold the mic; audio stays on the phone',
    ),
    PermissionKind.notifications: (
      'Notifications',
      'For timers that run on the phone',
    ),
    PermissionKind.exactAlarms: (
      'Alarms & reminders',
      'So phone timers fire on time',
    ),
  };

  Future<void> _finish() async {
    await ref.read(servicesProvider).appSettings.setOnboarded(true);
    ref.invalidate(onboardedProvider);
  }

  Future<void> _request(PermissionKind k) async {
    final s = await ref.read(permissionsProvider).request(k);
    if (mounted) setState(() => _status[k] = s);
  }

  Future<void> _checkSpeech() async {
    final c = await ref.read(servicesProvider).stt?.capabilities();
    if (mounted) setState(() => _caps = c);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pages = <Widget>[
      _Page(
        icon: Icons.home_outlined,
        title: 'Offline Home',
        body:
            'Control your smart plugs, switches and lights directly over your home Wi-Fi — '
            'no internet, no vendor cloud — by tap or by voice in English and Hinglish.\n\n'
            'Not affiliated with any device maker.',
      ),
      Column(
        children: [
          const _Header(
            'Permissions',
            'Allow what you need. You can change these later in the phone settings.',
          ),
          for (final k in ref.watch(permissionsProvider).needed)
            ListTile(
              title: Text(_labels[k]!.$1),
              subtitle: Text(_labels[k]!.$2),
              trailing: switch (_status[k]) {
                PermissionStatus.granted || PermissionStatus.notNeeded =>
                  const Icon(Icons.check_circle, color: Colors.green),
                PermissionStatus.denied => TextButton(
                  onPressed: () => _request(k),
                  child: const Text('Try again'),
                ),
                _ => FilledButton.tonal(
                  onPressed: () => _request(k),
                  child: const Text('Allow'),
                ),
              },
            ),
        ],
      ),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Header(
            'Offline speech',
            'Voice commands are recognised on the phone. It needs the offline language model once.',
          ),
          ListTile(
            title: Text(
              _caps == null
                  ? 'Not checked yet'
                  : _caps!.available
                  ? 'Languages on this phone: ${_caps!.locales.where((l) => l.startsWith('en') || l.startsWith('hi')).join(', ')}'
                  : 'Speech recognition is not available',
            ),
            trailing: TextButton(
              onPressed: _checkSpeech,
              child: const Text('Check'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              _ios
                  ? 'iPhone: Settings → General → Keyboard → turn on Dictation, and add English (India) '
                        'and Hindi under Dictation Languages while online. On-device recognition then works offline.'
                  : 'Android: Settings → Google → Speech (or "Offline speech recognition") → download '
                        'English (India) and Hindi while online.',
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
      Column(
        children: [
          const _Header(
            'Add your devices',
            'Scan the Wi-Fi now, or later from Settings.',
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const AddDevicesScreen()),
            ),
            icon: const Icon(Icons.radar),
            label: const Text('Scan for devices'),
          ),
        ],
      ),
    ];
    final last = _step == pages.length - 1;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: pages[_step],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              if (_step > 0)
                TextButton(
                  onPressed: () => setState(() => _step--),
                  child: const Text('Back'),
                ),
              const Spacer(),
              Text('${_step + 1} / ${pages.length}'),
              const SizedBox(width: 16),
              FilledButton(
                onPressed: last ? _finish : () => setState(() => _step++),
                child: Text(last ? 'Done' : 'Next'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.title, this.body);
  final String title;
  final String body;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(body),
      ],
    ),
  );
}

class _Page extends StatelessWidget {
  const _Page({required this.icon, required this.title, required this.body});
  final IconData icon;
  final String title;
  final String body;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      const SizedBox(height: 48),
      Icon(icon, size: 72, color: Theme.of(context).colorScheme.primary),
      const SizedBox(height: 16),
      Text(title, style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 16),
      Text(body, textAlign: TextAlign.center),
    ],
  );
}
