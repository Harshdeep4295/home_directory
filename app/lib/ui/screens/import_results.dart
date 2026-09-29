import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/result.dart';
import '../../onboarding/devices_json_import.dart';
import '../providers.dart';

/// Result of the post-import check for one device.
enum KeyCheck {
  pending('Checking…'),
  ok('Key works'),
  rejected('Key rejected'),
  notFound('Not found on this Wi-Fi yet');

  const KeyCheck(this.label);
  final String label;
}

/// Lists import outcomes and checks every stored key: quick scan (fills current IPs and
/// versions), then one status read per device (T6.1 / T6.3).
class ImportResults extends ConsumerStatefulWidget {
  const ImportResults({super.key, required this.outcomes});
  final List<ImportOutcome> outcomes;

  @override
  ConsumerState<ImportResults> createState() => _ImportResultsState();
}

class _ImportResultsState extends ConsumerState<ImportResults> {
  final Map<String, KeyCheck> _checks = {};

  @override
  void initState() {
    super.initState();
    for (final o in widget.outcomes.where((o) => o.status.stored)) {
      _checks[o.entry.id] = KeyCheck.pending;
    }
    _verify();
  }

  Future<void> _verify() async {
    final s = ref.read(servicesProvider);
    await s.discovery.scan(window: const Duration(seconds: 3));
    for (final o in widget.outcomes.where((o) => o.status.stored)) {
      final d = await s.devices.byId(o.entry.id);
      final KeyCheck check;
      if (d == null || d.ip.isEmpty) {
        check = KeyCheck.notFound;
      } else {
        check = switch ((await s.engine.status([d])).single.result) {
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
    final out = widget.outcomes;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${out.where((o) => o.status.stored).length} of ${out.length} keys imported',
          style: theme.textTheme.titleMedium,
        ),
        for (final o in out)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              o.status.stored ? Icons.key : Icons.block,
              color: o.status.stored ? null : theme.disabledColor,
            ),
            title: Text(o.device?.name ?? o.entry.name),
            subtitle: Text(
              o.status.stored
                  ? '${o.status.label} · ${(_checks[o.entry.id] ?? KeyCheck.pending).label}'
                  : o.status.label,
            ),
          ),
      ],
    );
  }
}
