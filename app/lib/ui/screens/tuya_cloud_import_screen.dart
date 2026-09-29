import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/result.dart';
import '../../onboarding/cloud_import/tuya_cloud.dart';
import '../../onboarding/devices_json_import.dart';
import '../../registry/secret_store.dart';
import '../providers.dart';
import 'import_results.dart';

/// HTTP used by the cloud import; overridden in tests. The only internet access in the
/// app, and only after the user taps "Fetch keys" (CLAUDE.md rule 1).
final tuyaCloudHttpProvider = Provider<CloudHttp>((ref) => IoCloudHttp());

/// Pseudo device id under which the Tuya IoT project credentials live in SecretStore.
const tuyaCloudSecretId = 'tuya-cloud';

/// T6.3: Tuya IoT project Access ID / Secret → device list with local keys → import.
class TuyaCloudImportScreen extends ConsumerStatefulWidget {
  const TuyaCloudImportScreen({super.key});

  @override
  ConsumerState<TuyaCloudImportScreen> createState() =>
      _TuyaCloudImportScreenState();
}

class _TuyaCloudImportScreenState extends ConsumerState<TuyaCloudImportScreen> {
  final _id = TextEditingController();
  final _secret = TextEditingController();
  TuyaRegion _region = TuyaRegion.india;
  bool _remember = true;
  bool _busy = false;
  String? _error;
  List<ImportOutcome>? _outcomes;

  @override
  void initState() {
    super.initState();
    _prefill();
  }

  Future<void> _prefill() async {
    final s = ref.read(servicesProvider).secrets;
    final id = await s.get(tuyaCloudSecretId, SecretName.username);
    final secret = await s.get(tuyaCloudSecretId, SecretName.password);
    if (!mounted) return;
    if (id != null) _id.text = id;
    if (secret != null) _secret.text = secret;
  }

  @override
  void dispose() {
    _id.dispose();
    _secret.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    final id = _id.text.trim();
    final secret = _secret.text.trim();
    if (id.isEmpty || secret.isEmpty) {
      setState(() => _error = 'Enter the Access ID and Access Secret.');
      return;
    }
    final s = ref.read(servicesProvider);
    setState(() {
      _busy = true;
      _error = null;
      _outcomes = null;
    });
    try {
      final r = await TuyaCloudClient(
        accessId: id,
        accessSecret: secret,
        region: _region,
        http: ref.read(tuyaCloudHttpProvider),
      ).fetchDevices();
      switch (r) {
        case Ok(:final value):
          if (_remember) {
            await s.secrets.set(tuyaCloudSecretId, SecretName.username, id);
            await s.secrets.set(tuyaCloudSecretId, SecretName.password, secret);
          } else {
            await s.secrets.deleteDevice(tuyaCloudSecretId);
          }
          final out = await DevicesJsonImporter(
            s.devices,
            s.secrets,
          ).importEntries(value);
          if (mounted) setState(() => _outcomes = out);
        case Err(:final error):
          if (mounted) {
            setState(
              () => _error = switch (error.kind) {
                DeviceErrorKind.auth =>
                  'Tuya rejected the credentials or region: ${error.message}',
                DeviceErrorKind.offline || DeviceErrorKind.timeout =>
                  'Could not reach Tuya. This step needs internet.',
                _ => 'Tuya cloud error: ${error.message}',
              },
            );
          }
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final out = _outcomes;
    return Scaffold(
      appBar: AppBar(title: const Text('Import from Tuya cloud')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Uses your Tuya IoT project (iot.tuya.com → Cloud → your project → '
            'Overview). This is the only time the app goes online; control stays '
            'on your Wi-Fi.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _id,
            decoration: const InputDecoration(labelText: 'Access ID'),
            autocorrect: false,
          ),
          TextField(
            controller: _secret,
            decoration: const InputDecoration(labelText: 'Access Secret'),
            obscureText: true,
            autocorrect: false,
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<TuyaRegion>(
            initialValue: _region,
            decoration: const InputDecoration(labelText: 'Data centre'),
            items: [
              for (final r in TuyaRegion.values)
                DropdownMenuItem(value: r, child: Text(r.label)),
            ],
            onChanged: (r) => setState(() => _region = r ?? _region),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Remember on this phone'),
            subtitle: const Text('Stored in secure storage'),
            value: _remember,
            onChanged: (v) => setState(() => _remember = v),
          ),
          FilledButton.icon(
            onPressed: _busy ? null : _fetch,
            icon: const Icon(Icons.cloud_download_outlined),
            label: const Text('Fetch keys'),
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
