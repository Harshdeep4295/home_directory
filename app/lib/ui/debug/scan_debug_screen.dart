import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/services.dart';
import '../../core/models.dart';
import '../../core/result.dart';
import '../../discovery/discovery_service.dart';
import '../../registry/secret_store.dart';

/// T2.10 hardware check: scan the LAN, add what was found, paste a Tuya key, toggle.
class ScanDebugScreen extends StatefulWidget {
  const ScanDebugScreen({super.key, required this.services});
  final AppServices services;

  @override
  State<ScanDebugScreen> createState() => _ScanDebugScreenState();
}

class _ScanDebugScreenState extends State<ScanDebugScreen> {
  AppServices get s => widget.services;
  bool _scanning = false;
  List<ScanResult> _results = const [];
  List<Device> _devices = const [];
  final Map<String, String> _status = {};

  @override
  void initState() {
    super.initState();
    unawaited(_reload());
  }

  Future<void> _reload() async {
    final d = await s.devices.all();
    if (mounted) setState(() => _devices = d);
  }

  Future<void> _scan() async {
    setState(() => _scanning = true);
    final sw = Stopwatch()..start();
    final r = await s.discovery.scan();
    await _reload();
    if (!mounted) return;
    setState(() {
      _scanning = false;
      _results = r.results;
      _status['scan'] = '${r.results.length} found in ${sw.elapsed.inSeconds}s';
    });
  }

  Future<void> _add(Candidate c) async {
    await s.discovery.add(c);
    await _reload();
  }

  Future<void> _pasteKey(Device d) async {
    final ctl = TextEditingController();
    final key = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Local key for ${d.name}'),
        content: TextField(
          controller: ctl,
          decoration: const InputDecoration(hintText: '16 characters'),
          maxLength: 16,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctl.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    ctl.dispose();
    if (key == null || key.length != 16) return;
    await s.secrets.set(d.id, SecretName.localKey, key);
    await _refresh(d);
  }

  Future<void> _refresh(Device d) async {
    final a = s.adapters.adapterFor(d);
    if (a == null) return;
    final r = await a.getState(d);
    if (mounted) setState(() => _status[d.id] = _describe(r));
  }

  Future<void> _toggle(Device d) async {
    final a = s.adapters.adapterFor(d);
    if (a == null) {
      setState(() => _status[d.id] = 'no adapter for ${d.protocol} yet');
      return;
    }
    final sw = Stopwatch()..start();
    final st = await a.getState(d);
    final on = st.valueOrNull?.on ?? false;
    final r = await a.setPower(d, !on);
    if (!mounted) return;
    setState(
      () => _status[d.id] = r.isOk
          ? 'turned ${on ? 'off' : 'on'} in ${sw.elapsedMilliseconds} ms'
          : 'FAILED: ${r.errorOrNull!.kind.name} ${r.errorOrNull!.message}',
    );
  }

  static String _describe(Result<DeviceState> r) => switch (r) {
    Ok(:final value) => 'on: ${value.on}',
    Err(:final error) => '${error.kind.name}: ${error.message}',
  };

  static String badge(Candidate c) => c.brand == Brand.unknown
      ? 'Unknown'
      : c.needsKey
      ? (c.brand == Brand.hue ? 'Needs pairing' : 'Needs key')
      : 'Ready';

  @override
  Widget build(BuildContext context) {
    final newOnes = _results.where((r) => r.isNew).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Scan + toggle')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _scanning ? null : _scan,
        icon: const Icon(Icons.radar),
        label: Text(_scanning ? 'Scanning…' : 'Scan'),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          if (_status['scan'] case final String st) ListTile(title: Text(st)),
          const ListTile(title: Text('Registered devices')),
          for (final d in _devices)
            ListTile(
              title: Text(d.name),
              subtitle: Text('${d.protocol} · ${d.ip}\n${_status[d.id] ?? ''}'),
              isThreeLine: true,
              onTap: () => _toggle(d),
              trailing: d.brand == Brand.tuya
                  ? IconButton(
                      tooltip: 'Paste local key',
                      icon: const Icon(Icons.key),
                      onPressed: () => _pasteKey(d),
                    )
                  : null,
            ),
          if (newOnes.isNotEmpty) const ListTile(title: Text('Found (new)')),
          for (final r in newOnes)
            ListTile(
              title: Text(
                '${r.candidate.name ?? r.candidate.brand.name} · ${badge(r.candidate)}',
              ),
              subtitle: Text(
                '${r.candidate.protocol} · ${r.candidate.ip}\n'
                '${r.candidate.evidence.join(', ')}',
              ),
              isThreeLine: true,
              trailing: IconButton(
                tooltip: 'Add',
                icon: const Icon(Icons.add),
                onPressed: () => _add(r.candidate),
              ),
            ),
        ],
      ),
    );
  }
}
