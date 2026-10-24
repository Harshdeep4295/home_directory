import 'package:flutter/material.dart';

import '../../core/models.dart';

/// Place chips (Home, Office, …) plus "New place…" with a text field (T10.2).
/// Reports the chosen place through [onChanged]; an empty new place counts as none.
class PlacePicker extends StatefulWidget {
  const PlacePicker({
    super.key,
    required this.places,
    required this.initial,
    required this.onChanged,
  });

  final List<String> places;
  final String initial;
  final ValueChanged<String?> onChanged;

  @override
  State<PlacePicker> createState() => _PlacePickerState();
}

class _PlacePickerState extends State<PlacePicker> {
  late final List<String> _places = Places.distinct([
    Places.home,
    ...widget.places,
    widget.initial,
  ]);
  late String _selected = _places.firstWhere(
    (p) => Places.same(p, widget.initial),
    orElse: () => _places.first,
  );
  bool _creating = false;
  final _new = TextEditingController();

  @override
  void dispose() {
    _new.dispose();
    super.dispose();
  }

  void _emit() {
    final n = _new.text.trim();
    widget.onChanged(
      !_creating
          ? _selected
          : n.isEmpty
          ? null
          // Reuse the existing spelling of a place typed again.
          : _places.firstWhere((p) => Places.same(p, n), orElse: () => n),
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text('Place', style: Theme.of(context).textTheme.labelLarge),
      Wrap(
        spacing: 8,
        children: [
          for (final p in _places)
            ChoiceChip(
              key: ValueKey('place-$p'),
              label: Text(p),
              selected: !_creating && _selected == p,
              onSelected: (_) {
                setState(() {
                  _selected = p;
                  _creating = false;
                });
                _emit();
              },
            ),
          ChoiceChip(
            key: const ValueKey('place-new'),
            label: const Text('New place…'),
            selected: _creating,
            onSelected: (_) {
              setState(() => _creating = true);
              _emit();
            },
          ),
        ],
      ),
      if (_creating)
        TextField(
          key: const ValueKey('place-new-field'),
          controller: _new,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Place name',
            hintText: 'e.g. Office, Village home',
          ),
          onChanged: (_) => _emit(),
        ),
    ],
  );
}

/// Dialog to move a device or camera to another place; null when cancelled.
Future<String?> pickPlace(
  BuildContext context, {
  required List<String> places,
  required String initial,
}) => showDialog<String>(
  context: context,
  builder: (_) => _PlaceDialog(places: places, initial: initial),
);

class _PlaceDialog extends StatefulWidget {
  const _PlaceDialog({required this.places, required this.initial});
  final List<String> places;
  final String initial;

  @override
  State<_PlaceDialog> createState() => _PlaceDialogState();
}

class _PlaceDialogState extends State<_PlaceDialog> {
  late String? _place = widget.initial;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Place'),
    content: SingleChildScrollView(
      child: PlacePicker(
        places: widget.places,
        initial: widget.initial,
        onChanged: (p) => setState(() => _place = p),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _place == null ? null : () => Navigator.pop(context, _place),
        child: const Text('Save'),
      ),
    ],
  );
}
