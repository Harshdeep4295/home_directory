import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../providers.dart';

/// What to share or export (T10.6): everything, whole places, or single devices and
/// cameras. Pops with [ItemChoice].
class ChooseItemsScreen extends ConsumerStatefulWidget {
  const ChooseItemsScreen({
    super.key,
    required this.title,
    required this.action,
  });
  final String title;

  /// Button label, e.g. "Share" or "Export".
  final String action;

  @override
  ConsumerState<ChooseItemsScreen> createState() => _ChooseItemsScreenState();
}

/// [only] is null when everything (including phone-wide settings) is chosen.
class ItemChoice {
  const ItemChoice(this.only, this.count);
  final Set<String>? only;
  final int count;
}

class _ChooseItemsScreenState extends ConsumerState<ChooseItemsScreen> {
  Set<String>? _picked;

  @override
  Widget build(BuildContext context) {
    final devicesAsync = ref.watch(devicesProvider);
    final camerasAsync = ref.watch(camerasProvider);
    if (!devicesAsync.hasValue || !camerasAsync.hasValue) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final devices = devicesAsync.value!;
    final cameras = camerasAsync.value!;
    final places = Places.distinct([
      for (final d in devices) d.place,
      for (final c in cameras) c.place,
    ]);
    final all = {...devices.map((d) => d.id), ...cameras.map((c) => c.id)};
    final picked = _picked ??= {...all};
    Set<String> idsOf(String place) => {
      for (final d in devices)
        if (Places.same(d.place, place)) d.id,
      for (final c in cameras)
        if (Places.same(c.place, place)) c.id,
    };
    void toggle(Iterable<String> ids, bool on) =>
        setState(() => on ? picked.addAll(ids) : picked.removeAll(ids));
    final everything = picked.length == all.length;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Wrap(
              spacing: 8,
              children: [
                FilterChip(
                  key: const ValueKey('choose-all'),
                  label: const Text('Everything'),
                  selected: everything,
                  onSelected: (on) => toggle(all, on),
                ),
                for (final p in places)
                  FilterChip(
                    key: ValueKey('choose-place-$p'),
                    label: Text(p),
                    selected: picked.containsAll(idsOf(p)),
                    onSelected: (on) => toggle(idsOf(p), on),
                  ),
              ],
            ),
          ),
          for (final p in places) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Text(p, style: Theme.of(context).textTheme.titleSmall),
            ),
            for (final d in devices)
              if (Places.same(d.place, p))
                CheckboxListTile(
                  key: ValueKey('choose-${d.id}'),
                  value: picked.contains(d.id),
                  title: Text(d.name),
                  subtitle: Text('${d.brand.name} · ${d.ip}'),
                  onChanged: (on) => toggle([d.id], on ?? false),
                ),
            for (final c in cameras)
              if (Places.same(c.place, p))
                CheckboxListTile(
                  key: ValueKey('choose-${c.id}'),
                  value: picked.contains(c.id),
                  secondary: const Icon(Icons.videocam_outlined),
                  title: Text(c.name),
                  subtitle: Text('camera · ${c.ip}'),
                  onChanged: (on) => toggle([c.id], on ?? false),
                ),
          ],
          if (everything)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Everything also includes rooms and app settings (voice, refresh).',
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: picked.isEmpty
            ? null
            : () => Navigator.pop(
                context,
                ItemChoice(everything ? null : {...picked}, picked.length),
              ),
        icon: const Icon(Icons.arrow_forward),
        label: Text(
          everything
              ? '${widget.action} everything'
              : '${widget.action} ${picked.length}',
        ),
      ),
    );
  }
}

/// Opens [ChooseItemsScreen]; null when the user backs out.
Future<ItemChoice?> chooseItems(
  BuildContext context, {
  required String title,
  required String action,
}) => Navigator.of(context).push<ItemChoice>(
  MaterialPageRoute(
    builder: (_) => ChooseItemsScreen(title: title, action: action),
  ),
);
