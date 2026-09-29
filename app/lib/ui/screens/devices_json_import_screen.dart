import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../onboarding/devices_json_import.dart';
import '../file_access.dart';
import '../providers.dart';
import 'import_results.dart';
import 'tuya_cloud_import_screen.dart';

Future<void> openDevicesJsonImport(BuildContext context) =>
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const DevicesJsonImportScreen()),
    );

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
      _outcomes = null;
    });
    try {
      final text = utf8.decode(picked.$2, allowMalformed: true);
      final out = await DevicesJsonImporter(
        s.devices,
        s.secrets,
      ).importText(text);
      if (mounted) setState(() => _outcomes = out);
    } on DevicesJsonFormatException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _push(Widget w) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => w));

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
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _push(const TuyaCloudImportScreen()),
            icon: const Icon(Icons.cloud_download_outlined),
            label: const Text('Import from Tuya cloud instead'),
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
            ImportResults(key: ObjectKey(out), outcomes: out),
          ],
        ],
      ),
    );
  }
}
