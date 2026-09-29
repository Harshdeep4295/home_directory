import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/result.dart';
import '../../onboarding/devices_json_import.dart';
import '../file_access.dart';
import '../providers.dart';

Future<void> openDevicesJsonImport(BuildContext context) =>
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const DevicesJsonImportScreen()),
    );

/// Result of the post-import check for one device.
enum KeyCheck {
  pending('Checking…'),
  ok('Key works'),
  rejected('Key rejected'),
  notFound('Not found on this Wi-Fi yet');

  const KeyCheck(this.label);
  final String label;
}

/// T6.1: pick tinytuya's devices.json → keys to SecretStore → quick scan → verify.
/// The file's bytes live only in memory for the duration of [_import].
class DevicesJsonImportScreen extends ConsumerStatefulWidget {
  const DevicesJsonImportScreen({super.key});

  @override
  ConsumerState<DevicesJsonImportScreen> createState() =>
      _DevicesJsonImportScreenState();
}

class _DevicesJsonImportScreenState
    extends ConsumerState<DevicesJsonImportScreen> {
  List<ImportOutcome>? _outcomes;
  final Map<String, KeyCheck> _checks = {};
  String? _error;
  bool _busy = false;

  Future<void> _import() async {
    final picked = await ref
        .read(fileAccessProvider)
        .pick(extensions: const ['json']);
    if (picked == null) return;
    final s = ref.read(servicesProvider);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final text = utf8.decode(picked.$2, allowMalformed: true);
      final out = await DevicesJsonImporter(
        s.devices,
        s.secrets,
      ).importText(text);
      setState(() {
        _outcomes = out;
        for (final o in out.where((o) => o.status.stored)) {
          _checks[o.entry.id] = KeyCheck.pending;
        }
      });
      await _verify(out);
    } on DevicesJsonFormatException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Quick scan fills current IPs / versions, then one status call per device.
  Future<void> _verify(List<ImportOutcome> out) async {
    final s = ref.read(servicesProvider);
    await s.discovery.scan(window: const Duration(seconds: 3));
    for (final o in out.where((o) => o.status.stored)) {
      final d = await s.devices.byId(o.entry.id);
      final KeyCheck check;
      if (d == null || d.ip.isEmpty) {
        check = KeyCheck.notFound;
      } else {
        final r = (await s.engine.status([d])).single.result;
        check = switch (r) {
          Ok() => KeyCheck.ok,
          Err(:final error) when error.kind == DeviceErrorKind.auth =>
            KeyCheck.rejected,
          Err() => KeyCheck.notFound,
        };
      }
      if (!mounted) return;
      setState(() => _checks[o.entry.id] = check);
    }
  }

  @override
  Widget build(BuildContext context) {
    final out = _outcomes;
    return Scaffold(
      appBar: AppBar(title: const Text('Import Tuya keys')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'On your computer run  python -m tinytuya wizard  (it logs in to your '
            'Tuya IoT project once). It writes devices.json with each device\'s '
            'local key. Send that file to this phone and pick it here. Keys are '
            'stored in the phone\'s secure storage; the file itself is not kept.',
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _busy ? null : _import,
            icon: const Icon(Icons.upload_file),
            label: const Text('Choose devices.json'),
          ),
          if (_busy) const LinearProgressIndicator(),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (out != null) ...[
            const SizedBox(height: 16),
            Text(
              '${out.where((o) => o.status.stored).length} of ${out.length} keys imported',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            for (final o in out)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  o.status.stored ? Icons.key : Icons.block,
                  color: o.status.stored
                      ? null
                      : Theme.of(context).disabledColor,
                ),
                title: Text(o.device?.name ?? o.entry.name),
                subtitle: Text(
                  o.status.stored
                      ? '${o.status.label} · ${(_checks[o.entry.id] ?? KeyCheck.pending).label}'
                      : o.status.label,
                ),
              ),
          ],
        ],
      ),
    );
  }
}
