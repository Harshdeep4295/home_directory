import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/intent.dart';
import '../../core/models.dart';
import '../../core/result.dart';
import '../../onboarding/manual_key.dart';
import '../../registry/secret_store.dart';
import '../../timers/tier_copy.dart';
import '../alias_suggestions.dart';
import '../home_widget_sync.dart';
import '../providers.dart';
import '../widgets/device_tile.dart';
import '../widgets/prompt.dart';

/// Everything about one device (T5.3).
class DeviceDetailScreen extends ConsumerStatefulWidget {
  const DeviceDetailScreen({super.key, required this.deviceId});
  final String deviceId;

  @override
  ConsumerState<DeviceDetailScreen> createState() => _DeviceDetailScreenState();
}

class _DeviceDetailScreenState extends ConsumerState<DeviceDetailScreen> {
  double? _brightness;
  double? _colorTemp;

  static const presets = [15, 30, 60];
  static const autoOffChoices = [null, 15, 30, 60, 120];

  void _say(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(m), duration: const Duration(seconds: 6)),
      );
  }

  Future<void> _power(Device d, bool on) async {
    final s = ref.read(servicesProvider);
    final r = await s.engine.powerOne(d, on);
    if (r case Err(:final error)) {
      _say('${d.name}: ${error.kind.name} ${error.message}');
    } else if (on) {
      await s.timerService.applyAutoOff([d]);
    }
  }

  Future<void> _timer(Device d, Duration dur) async {
    final s = ref.read(servicesProvider);
    final out = await s.timerService.powerFor([d], PowerAction.on, dur);
    switch (out.single.result) {
      case Ok(value: final j):
        _say(
          j.tier == TimerTier.phone && Platform.isIOS
              ? TierCopy.iosPhoneWarning
              : 'On for ${remainingText(dur)} ${TierCopy.feedbackSuffix(j.tier, isIOS: Platform.isIOS)}.',
        );
      case Err(:final error):
        _say('Timer failed: ${error.kind.name} ${error.message}');
    }
  }

  Future<void> _customTimer(Device d) async {
    final text = await promptText(
      context,
      title: 'On for how many minutes?',
      action: 'Start',
      keyboardType: TextInputType.number,
    );
    final minutes = int.tryParse(text ?? '');
    if (minutes != null && minutes > 0) {
      await _timer(d, Duration(minutes: minutes));
    }
  }

  Future<void> _save(Device d) => ref.read(servicesProvider).devices.upsert(d);

  Future<void> _rename(Device d) async {
    final name = await promptText(context, title: 'Name', initial: d.name);
    if (name != null && name.isNotEmpty) await _save(d.copyWith(name: name));
  }

  Future<void> _addAlias(Device d, [String? preset]) async {
    var alias = preset;
    alias ??= (await promptText(
      context,
      title: 'Add a name you say',
      hint: 'e.g. batti, pankha',
      action: 'Add',
    ))?.toLowerCase();
    if (alias == null || alias.isEmpty || d.aliases.contains(alias)) return;
    await _save(d.copyWith(aliases: [...d.aliases, alias]));
  }

  Future<void> _enterKey(Device d) async {
    final key = await promptText(
      context,
      title: 'Enter local key',
      message: 'Device ${d.id}',
      hint: '16 characters from devices.json',
      maxLength: 16,
    );
    if (key == null || key.isEmpty) return;
    final s = ref.read(servicesProvider);
    final r = await enterLocalKey(
      d: d,
      key: key,
      secrets: s.secrets,
      adapters: s.adapters,
      engine: s.engine,
    );
    _say(r.message);
    if (mounted) setState(() {}); // refresh "Local key: stored / missing"
  }

  Future<void> _rescan(Device d) async {
    _say('Scanning…');
    final r = await ref.read(servicesProvider).discovery.scan();
    final hit = r.results.where((x) => x.device?.id == d.id).firstOrNull;
    _say(
      hit == null
          ? 'Not found on the network. Is it powered and on this Wi-Fi?'
          : hit.movedFrom != null
          ? 'Found at a new address ${hit.candidate.ip} (was ${hit.movedFrom}).'
          : 'Found at ${hit.candidate.ip}.',
    );
  }

  Future<void> _delete(Device d) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove ${d.name}?'),
        content: const Text('Its timers and stored key are removed too.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final s = ref.read(servicesProvider);
    await s.timerService.cancel([d]);
    await s.adapters.adapterFor(d)?.dispose(d);
    await s.secrets.deleteDevice(d.id);
    await s.devices.delete(d.id);
    if (mounted) await Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final devices = ref.watch(devicesProvider).value ?? const <Device>[];
    final d = devices.where((x) => x.id == widget.deviceId).firstOrNull;
    if (d == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Device not found')),
      );
    }
    final state = (ref.watch(deviceStatesProvider).value ?? const {})[d.id];
    final job = (ref.watch(timersProvider).value ?? const <TimerJob>[])
        .where((j) => j.deviceId == d.id)
        .firstOrNull;
    final rooms = ref.watch(roomsProvider).value ?? const <Room>[];
    final now = ref.watch(clockProvider)();
    final caps = d.capabilities;
    final s = ref.read(servicesProvider);
    final suggestions = aliasSuggestions(d.name)
        .where((a) => !d.aliases.contains(a))
        .toList();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(d.name),
        actions: [
          IconButton(
            tooltip: isFavourite(d)
                ? 'Remove from widget'
                : 'Add to home-screen widget',
            onPressed: () => _save(withFavourite(d, !isFavourite(d))),
            icon: Icon(isFavourite(d) ? Icons.star : Icons.star_border),
          ),
          IconButton(
            tooltip: 'Rename',
            onPressed: () => _rename(d),
            icon: const Icon(Icons.edit),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            secondary: Icon(iconFor(d), size: 32),
            title: Text(
              state?.online == false
                  ? 'Offline'
                  : state?.on == true
                  ? 'On'
                  : 'Off',
            ),
            value: state?.on ?? false,
            onChanged: state?.online == false ? null : (v) => _power(d, v),
          ),
          if (caps.contains(Capability.brightness)) ...[
            const ListTile(title: Text('Brightness')),
            Slider(
              min: 1,
              max: 100,
              value: (_brightness ?? (state?.brightness ?? 100).toDouble())
                  .clamp(1, 100),
              label: '${(_brightness ?? state?.brightness ?? 100).round()} %',
              divisions: 99,
              onChanged: (v) => setState(() => _brightness = v),
              onChangeEnd: (v) =>
                  s.engine.run(d, (a) => a.setBrightness(d, v.round())),
            ),
          ],
          if (caps.contains(Capability.colorTemp)) ...[
            const ListTile(title: Text('Colour temperature')),
            Slider(
              min: 2200,
              max: 6500,
              value: (_colorTemp ?? (state?.colorTemp ?? 2700).toDouble())
                  .clamp(2200, 6500),
              label: '${(_colorTemp ?? state?.colorTemp ?? 2700).round()} K',
              onChanged: (v) => setState(() => _colorTemp = v),
              onChangeEnd: (v) =>
                  s.engine.run(d, (a) => a.setColorTemp(d, v.round())),
            ),
          ],
          const Divider(height: 32),
          Text('Timer', style: theme.textTheme.titleMedium),
          if (job != null)
            ListTile(
              leading: const Icon(Icons.timer_outlined),
              title: Text(
                '${job.endOn ? 'On' : 'Off'} in ${remainingText(job.fireAt.difference(now))}',
              ),
              subtitle: Text('${TierCopy.badge(job.tier, d.brand)} timer'),
              trailing: TextButton(
                onPressed: () => s.timerService.cancel([d]),
                child: const Text('Cancel'),
              ),
            ),
          Wrap(
            spacing: 8,
            children: [
              for (final m in presets)
                ActionChip(
                  label: Text('On for $m min'),
                  onPressed: () => _timer(d, Duration(minutes: m)),
                ),
              ActionChip(
                label: const Text('Custom…'),
                onPressed: () => _customTimer(d),
              ),
            ],
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Turn off automatically'),
            subtitle: const Text('Whenever it is switched on from this app'),
            trailing: DropdownButton<int?>(
              value: d.defaultAutoOff?.inMinutes,
              items: [
                for (final m in autoOffChoices)
                  DropdownMenuItem(
                    value: m,
                    child: Text(m == null ? 'Never' : 'after $m min'),
                  ),
              ],
              onChanged: (m) => _save(
                d.copyWith(
                  defaultAutoOff: m == null ? null : Duration(minutes: m),
                ),
              ),
            ),
          ),
          const Divider(height: 32),
          Text('Room and names', style: theme.textTheme.titleMedium),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Room'),
            trailing: DropdownButton<String?>(
              value: rooms.any((r) => r.id == d.roomId) ? d.roomId : null,
              items: [
                const DropdownMenuItem(value: null, child: Text('No room')),
                for (final r in rooms)
                  DropdownMenuItem(value: r.id, child: Text(r.name)),
              ],
              onChanged: (id) => _save(d.copyWith(roomId: id)),
            ),
          ),
          Wrap(
            spacing: 8,
            children: [
              for (final a in d.aliases)
                InputChip(
                  label: Text(a),
                  onDeleted: () => _save(
                    d.copyWith(
                      aliases: d.aliases.where((x) => x != a).toList(),
                    ),
                  ),
                ),
              for (final a in suggestions)
                ActionChip(
                  avatar: const Icon(Icons.add, size: 16),
                  label: Text(a),
                  onPressed: () => _addAlias(d, a),
                ),
              ActionChip(
                label: const Text('Add name…'),
                onPressed: () => _addAlias(d),
              ),
            ],
          ),
          const Divider(height: 32),
          Text('Connection', style: theme.textTheme.titleMedium),
          _info('Brand', d.brand.name),
          _info('Protocol', d.protocol),
          _info('IP address', d.ip),
          if (d.mac != null) _info('MAC', d.mac!),
          _info('Device id', d.id),
          if (d.brand == Brand.tuya)
            FutureBuilder<bool>(
              future: s.secrets.has(d.id, SecretName.localKey),
              builder: (_, snap) =>
                  _info('Local key', snap.data == true ? 'stored' : 'missing'),
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              if (d.brand == Brand.tuya)
                OutlinedButton.icon(
                  onPressed: () => _enterKey(d),
                  icon: const Icon(Icons.key),
                  label: const Text('Enter local key'),
                ),
              OutlinedButton.icon(
                onPressed: () => _rescan(d),
                icon: const Icon(Icons.radar),
                label: const Text('Re-scan IP'),
              ),
              OutlinedButton.icon(
                onPressed: () => _delete(d),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Remove device'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _info(String k, String v) => ListTile(
    dense: true,
    contentPadding: EdgeInsets.zero,
    title: Text(k),
    trailing: SelectableText(v),
  );
}
