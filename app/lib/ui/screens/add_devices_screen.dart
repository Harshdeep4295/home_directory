import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../adapters/hue/hue_adapter.dart';
import '../../adapters/kasa/kasa_adapter.dart';
import '../../core/models.dart';
import '../../core/result.dart';
import '../../discovery/discovery_service.dart';
import '../../onboarding/badges.dart';
import '../../onboarding/hue_pairing.dart';
import '../../registry/secret_store.dart';
import '../alias_suggestions.dart';
import '../providers.dart';
import '../widgets/prompt.dart';
import 'devices_json_import_screen.dart';

/// Scan → badges → resolve (key) → name, room, aliases → add (T5.6, PSEUDOCODE §0.1).
class AddDevicesScreen extends ConsumerStatefulWidget {
  const AddDevicesScreen({super.key, this.onImportDevicesJson});

  /// Opens the tinytuya devices.json import (T6.1).
  final VoidCallback? onImportDevicesJson;

  @override
  ConsumerState<AddDevicesScreen> createState() => _AddDevicesScreenState();
}

class _AddDevicesScreenState extends ConsumerState<AddDevicesScreen> {
  bool _scanning = false;
  ScanReport? _report;
  final Set<String> _added = {};

  @override
  void initState() {
    super.initState();
    unawaited(_scan());
  }

  Future<void> _scan() async {
    setState(() => _scanning = true);
    final r = await ref.read(servicesProvider).discovery.scan();
    if (!mounted) return;
    setState(() {
      _scanning = false;
      _report = r;
    });
  }

  String _key(Candidate c) => c.deviceId ?? c.mac ?? c.ip;

  Future<void> _resolve(Candidate c, OnboardingBadge badge) async {
    switch (badge) {
      case OnboardingBadge.ready:
        await _nameAndAdd(c);
      case OnboardingBadge.needsKey:
        if (c.brand == Brand.tuya) {
          final ok = await _pasteTuyaKey(c);
          if (ok) await _nameAndAdd(c.copyWith(needsKey: false));
        } else if (c.brand == Brand.shelly) {
          final ok = await _shellyPassword(c);
          if (ok) await _nameAndAdd(c.copyWith(needsKey: false));
        } else if (c.protocol.startsWith('klap-')) {
          final ok = await _tplinkAccount();
          if (ok) await _nameAndAdd(c.copyWith(needsKey: false));
        } else {
          _info(
            '${c.brand.name} credentials',
            'Credential entry for this brand arrives with its adapter.',
          );
        }
      case OnboardingBadge.needsPairing:
        await _pairHue(c);
      case OnboardingBadge.cloudOnly:
        _info(
          'Cloud-only',
          'This device cannot be controlled on the local network.',
        );
      case OnboardingBadge.notSupportedYet:
        _info(
          'Not supported yet',
          'Found a ${c.brand.name} device (${c.protocol}); its adapter is not built yet.',
        );
      case OnboardingBadge.unknown:
        _info(
          'Unknown device',
          'Something answered at ${c.ip} but it is not a device this app knows.\n${c.evidence.join('\n')}',
        );
    }
  }

  void _info(String title, String body) => unawaited(
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    ),
  );

  void _importDevicesJson() {
    final cb = widget.onImportDevicesJson;
    if (cb != null) return cb();
    openDevicesJsonImport(context);
  }

  /// Hue: press the bridge's link button within 30 s; its lights are then added.
  Future<void> _pairHue(Candidate c) async {
    final s = ref.read(servicesProvider);
    final hue = s.adapters.adapters.whereType<HueAdapter>().firstOrNull;
    if (hue == null) return;
    final left = ValueNotifier<int>(30);
    var cancelled = false;
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Press the round button on the Hue bridge'),
          content: ValueListenableBuilder<int>(
            valueListenable: left,
            builder: (_, v, _) => Text('Waiting for the bridge… $v s'),
          ),
          actions: [
            TextButton(
              onPressed: () {
                cancelled = true;
                Navigator.pop(ctx);
              },
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
    final r = await HuePairing(hue, s.secrets, s.devices).pairAndImport(
      c,
      onTick: (v) => left.value = v,
      cancelled: () => cancelled,
    );
    if (!mounted) return;
    if (!cancelled) Navigator.of(context).pop();
    left.dispose();
    switch (r) {
      case Ok(:final value):
        setState(() => _added.add(_key(c)));
        _info('Hue bridge paired', 'Added ${value.length} lights.');
      case Err(:final error) when !cancelled:
        _info(
          'Pairing failed',
          error.kind == DeviceErrorKind.auth
              ? 'The button was not pressed in time. Try again.'
              : error.message,
        );
      case Err():
        break;
    }
  }

  /// Tapo / new Kasa (KLAP): the TP-Link (Kasa/Tapo app) account, stored once for all
  /// devices under the pseudo id `tplink`. It is only used to derive the local
  /// handshake hash; nothing is sent to TP-Link.
  Future<bool> _tplinkAccount() async {
    final email = await promptText(
      context,
      title: 'TP-Link account e-mail',
      message: 'The account used in the Tapo / Kasa app. Stays on this phone.',
      keyboardType: TextInputType.emailAddress,
      action: 'Next',
    );
    if (email == null || email.isEmpty || !mounted) return false;
    final pw = await promptText(
      context,
      title: 'TP-Link account password',
      message: 'Case-sensitive.',
      action: 'Save',
    );
    if (pw == null || pw.isEmpty) return false;
    final secrets = ref.read(servicesProvider).secrets;
    await secrets.set(KasaAdapter.accountId, SecretName.email, email.trim());
    await secrets.set(KasaAdapter.accountId, SecretName.password, pw);
    return true;
  }

  /// Shelly with auth enabled: the device password (user "admin"), kept in SecretStore.
  Future<bool> _shellyPassword(Candidate c) async {
    final pw = await promptText(
      context,
      title: 'Shelly password',
      message: 'The password set in the Shelly app / web UI (user admin).',
      action: 'Save',
    );
    if (pw == null || pw.isEmpty) return false;
    await ref
        .read(servicesProvider)
        .secrets
        .set(_key(c), SecretName.password, pw);
    return true;
  }

  /// Tuya: paste the 16-character local key; verified against the device before adding.
  Future<bool> _pasteTuyaKey(Candidate c) async {
    final id = c.deviceId;
    if (id == null) {
      _info(
        'Device id unknown',
        'This Tuya device did not announce itself (common on iPhone). Import devices.json, '
            'which has the ids and keys of all your Tuya devices.',
      );
      return false;
    }
    final key = await promptText(
      context,
      title: 'Local key',
      message: 'Device $id',
      hint: '16 characters from devices.json',
      maxLength: 16,
      extra: Builder(
        builder: (ctx) => TextButton.icon(
          onPressed: () {
            Navigator.pop(ctx);
            _importDevicesJson();
          },
          icon: const Icon(Icons.upload_file),
          label: const Text('Import devices.json instead'),
        ),
      ),
    );
    if (key == null || key.length != 16) return false;
    final s = ref.read(servicesProvider);
    await s.secrets.set(id, SecretName.localKey, key);
    return true;
  }

  Future<void> _nameAndAdd(Candidate c) async {
    final s = ref.read(servicesProvider);
    final rooms = await s.rooms.all();
    if (!mounted) return;
    final result = await showModalBottomSheet<_NameResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _NameSheet(candidate: c, rooms: rooms),
    );
    if (result == null) return;
    var roomId = result.roomId;
    if (result.newRoom != null) {
      roomId = 'room-${DateTime.now().microsecondsSinceEpoch}';
      await s.rooms.upsert(
        Room(id: roomId, name: result.newRoom!, sort: rooms.length),
      );
    }
    final d = await s.discovery.add(
      c,
      name: result.name,
      roomId: roomId,
      aliases: result.aliases,
    );
    // Verify we can actually talk to it (wrong Tuya key → auth error).
    final r = await s.engine.status([d]);
    if (!mounted) return;
    setState(() => _added.add(_key(c)));
    final err = r.single.result.errorOrNull;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          err == null
              ? '${d.name} added.'
              : err.kind == DeviceErrorKind.auth
              ? '${d.name} added, but the key was rejected. Check it on the device page.'
              : '${d.name} added, but it did not answer yet (${err.kind.name}).',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final adapters = ref.watch(servicesProvider).adapters;
    final results = _report?.results ?? const <ScanResult>[];
    final fresh = results
        .where((r) => r.isNew && !_added.contains(_key(r.candidate)))
        .toList();
    final known = results.where((r) => !r.isNew).toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add devices'),
        actions: [
          IconButton(
            tooltip: 'Import devices.json',
            onPressed: _importDevicesJson,
            icon: const Icon(Icons.upload_file),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _scanning ? null : _scan,
        icon: _scanning
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.radar),
        label: Text(_scanning ? 'Scanning…' : 'Scan again'),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          if (_report != null && fresh.isEmpty && !_scanning)
            const ListTile(
              leading: Icon(Icons.search_off),
              title: Text('No new devices found'),
              subtitle: Text(
                'Make sure they are powered and on this Wi-Fi, then scan again.',
              ),
            ),
          for (final r in fresh)
            Builder(
              builder: (context) {
                final c = r.candidate;
                final badge = badgeFor(c, adapters);
                return ListTile(
                  title: Text(
                    c.name ?? DiscoveryService.defaultName(c.brand, _key(c)),
                  ),
                  subtitle: Text('${c.brand.name} · ${c.protocol} · ${c.ip}'),
                  trailing: Chip(label: Text(badge.label)),
                  onTap: () => _resolve(c, badge),
                );
              },
            ),
          if (known.isNotEmpty)
            ListTile(
              title: Text('Already added: ${known.length}'),
              subtitle: Text(
                known
                    .where((r) => r.movedFrom != null)
                    .map((r) => '${r.device!.name} moved to ${r.candidate.ip}')
                    .join('\n'),
              ),
            ),
        ],
      ),
    );
  }
}

class _NameResult {
  const _NameResult(this.name, this.roomId, this.newRoom, this.aliases);
  final String name;
  final String? roomId;
  final String? newRoom;
  final List<String> aliases;
}

class _NameSheet extends StatefulWidget {
  const _NameSheet({required this.candidate, required this.rooms});
  final Candidate candidate;
  final List<Room> rooms;

  @override
  State<_NameSheet> createState() => _NameSheetState();
}

class _NameSheetState extends State<_NameSheet> {
  late final TextEditingController _name = TextEditingController(
    text:
        widget.candidate.name ??
        DiscoveryService.defaultName(
          widget.candidate.brand,
          widget.candidate.deviceId ??
              widget.candidate.mac ??
              widget.candidate.ip,
        ),
  );
  final _newRoom = TextEditingController();
  String? _roomId;
  bool _creatingRoom = false;
  final Set<String> _aliases = {};

  @override
  void dispose() {
    _name.dispose();
    _newRoom.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final suggestions = aliasSuggestions(_name.text);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(
              labelText: 'Name (what you will say)',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              for (final r in widget.rooms)
                ChoiceChip(
                  label: Text(r.name),
                  selected: _roomId == r.id && !_creatingRoom,
                  onSelected: (_) => setState(() {
                    _roomId = r.id;
                    _creatingRoom = false;
                  }),
                ),
              ChoiceChip(
                label: const Text('New room…'),
                selected: _creatingRoom,
                onSelected: (_) => setState(() => _creatingRoom = true),
              ),
            ],
          ),
          if (_creatingRoom)
            TextField(
              controller: _newRoom,
              decoration: const InputDecoration(labelText: 'Room name'),
            ),
          if (suggestions.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('Also answer to'),
            Wrap(
              spacing: 8,
              children: [
                for (final a in suggestions)
                  FilterChip(
                    label: Text(a),
                    selected: _aliases.contains(a),
                    onSelected: (v) => setState(
                      () => v ? _aliases.add(a) : _aliases.remove(a),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _name.text.trim().isEmpty
                ? null
                : () => Navigator.pop(
                    context,
                    _NameResult(
                      _name.text.trim(),
                      _creatingRoom ? null : _roomId,
                      _creatingRoom && _newRoom.text.trim().isNotEmpty
                          ? _newRoom.text.trim()
                          : null,
                      _aliases.toList(),
                    ),
                  ),
            child: const Text('Add device'),
          ),
        ],
      ),
    );
  }
}
