import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_settings.dart';
import '../../registry/config_export.dart';
import '../file_access.dart';
import '../providers.dart';
import 'add_devices_screen.dart';
import 'debug_menu.dart';
import 'devices_json_import_screen.dart';

/// Settings (T5.7): voice language + TTS, polling, backup, diagnostics.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key, this.onImportDevicesJson});

  final VoidCallback? onImportDevicesJson;

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  VoiceLanguage? _language;
  bool? _tts;
  int? _poll;

  static const pollChoices = [3, 5, 10, 30];

  AppSettings get _settings => ref.read(servicesProvider).appSettings;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final l = await _settings.language();
    final t = await _settings.tts();
    final p = await _settings.pollSeconds();
    if (!mounted) return;
    setState(() {
      _language = l;
      _tts = t;
      _poll = p;
    });
  }

  Future<void> _change(Future<void> Function() write) async {
    await write();
    await ref.read(servicesProvider).applySettings();
    await _load();
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _export() async {
    final r = await showDialog<(String, bool)>(
      context: context,
      builder: (_) => const _ExportDialog(),
    );
    if (r == null) return;
    try {
      final bytes = await ref
          .read(servicesProvider)
          .configExporter
          .export(r.$1, includeSecrets: r.$2);
      final where = await ref
          .read(fileAccessProvider)
          .save('offline-home-config.json', bytes);
      if (where != null) _snack('Saved backup${r.$2 ? ' (with keys)' : ''}.');
    } on ConfigException catch (e) {
      _snack(e.message);
    }
  }

  Future<void> _import() async {
    final file = await ref.read(fileAccessProvider).pick(extensions: ['json']);
    if (file == null || !mounted) return;
    final pass = await showDialog<String>(
      context: context,
      builder: (_) => const _PassDialog(),
    );
    if (pass == null) return;
    try {
      final n = await ref
          .read(servicesProvider)
          .configExporter
          .import(file.$2, pass);
      await ref.read(servicesProvider).applySettings();
      await _load();
      _snack('Restored $n devices.');
    } on ConfigException catch (e) {
      _snack(e.message);
    }
  }

  void _push(Widget w) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => w));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final net = ref.watch(netStateProvider).value;
    Widget header(String t) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        t,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );
    return ListView(
      children: [
        header('Voice'),
        RadioGroup<VoiceLanguage>(
          groupValue: _language,
          onChanged: (v) =>
              v == null ? null : _change(() => _settings.setLanguage(v)),
          child: Column(
            children: [
              for (final l in VoiceLanguage.values)
                RadioListTile<VoiceLanguage>(value: l, title: Text(l.label)),
            ],
          ),
        ),
        SwitchListTile(
          title: const Text('Spoken feedback'),
          subtitle: const Text('Say "Geyser on" after a command'),
          value: _tts ?? true,
          onChanged: (v) => _change(() => _settings.setTts(v)),
        ),
        header('Devices'),
        ListTile(
          leading: const Icon(Icons.add),
          title: const Text('Add devices'),
          onTap: () => _push(
            AddDevicesScreen(onImportDevicesJson: widget.onImportDevicesJson),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.key),
          title: const Text('Import Tuya keys (devices.json)'),
          onTap:
              widget.onImportDevicesJson ??
              () => openDevicesJsonImport(context),
        ),
        ListTile(
          leading: const Icon(Icons.sync),
          title: const Text('Refresh device state every'),
          trailing: DropdownButton<int>(
            value: pollChoices.contains(_poll) ? _poll : 5,
            items: [
              for (final s in pollChoices)
                DropdownMenuItem(value: s, child: Text('$s s')),
            ],
            onChanged: (s) =>
                s == null ? null : _change(() => _settings.setPollSeconds(s)),
          ),
        ),
        header('Backup'),
        ListTile(
          leading: const Icon(Icons.upload),
          title: const Text('Export configuration'),
          subtitle: const Text('Encrypted with a passphrase you choose'),
          onTap: _export,
        ),
        ListTile(
          leading: const Icon(Icons.download),
          title: const Text('Import configuration'),
          onTap: _import,
        ),
        header('Diagnostics'),
        ListTile(
          leading: const Icon(Icons.wifi),
          title: const Text('Network'),
          subtitle: Text(
            net == null
                ? '…'
                : '${net.wifi ? 'Wi-Fi ${net.ip ?? ''}' : 'No Wi-Fi'} · internet '
                      '${switch (net.internet) {
                        true => 'yes',
                        false => 'no (local mode)',
                        null => 'unknown',
                      }}',
          ),
        ),
        ListTile(
          leading: const Icon(Icons.article_outlined),
          title: const Text('Recent logs'),
          onTap: () => _push(const _LogsPage()),
        ),
        ExpansionTile(
          leading: const Icon(Icons.build_outlined),
          title: const Text('Developer tools'),
          children: const [DebugMenu()],
        ),
        header('About'),
        const ListTile(
          title: Text('Offline Home'),
          subtitle: Text(
            'Controls your devices on the local network only. Not affiliated with Tuya, '
            'Wipro, Syska, Philips/WiZ, TP-Link or any other vendor.',
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}

class _ExportDialog extends StatefulWidget {
  const _ExportDialog();
  @override
  State<_ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends State<_ExportDialog> {
  final _pass = TextEditingController();
  bool _secrets = false;

  @override
  void dispose() {
    _pass.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Export configuration'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _pass,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Passphrase (6+ characters)',
          ),
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _secrets,
          onChanged: (v) => setState(() => _secrets = v ?? false),
          title: const Text('Include device keys and passwords'),
          subtitle: const Text('Only if you keep this file safe'),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, (_pass.text, _secrets)),
        child: const Text('Export'),
      ),
    ],
  );
}

class _PassDialog extends StatefulWidget {
  const _PassDialog();
  @override
  State<_PassDialog> createState() => _PassDialogState();
}

class _PassDialogState extends State<_PassDialog> {
  final _pass = TextEditingController();
  @override
  void dispose() {
    _pass.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Passphrase'),
    content: TextField(controller: _pass, obscureText: true, autofocus: true),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _pass.text),
        child: const Text('Import'),
      ),
    ],
  );
}

class _LogsPage extends ConsumerWidget {
  const _LogsPage();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final records = ref
        .watch(servicesProvider)
        .logSink
        .records
        .reversed
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Recent logs')),
      body: records.isEmpty
          ? const Center(child: Text('Nothing logged yet'))
          : ListView.builder(
              itemCount: records.length,
              itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 2,
                ),
                child: SelectableText(
                  records[i].toString(),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ),
            ),
    );
  }
}
