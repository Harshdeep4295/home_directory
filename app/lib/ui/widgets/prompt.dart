import 'package:flutter/material.dart';

/// Asks for one line of text. The dialog owns its controller, so nothing is disposed
/// while the closing animation still uses it.
Future<String?> promptText(
  BuildContext context, {
  required String title,
  String? message,
  String initial = '',
  String? hint,
  String action = 'Save',
  int? maxLength,
  TextInputType? keyboardType,
  Widget? extra,
}) => showDialog<String>(
  context: context,
  builder: (_) => _PromptDialog(
    title: title,
    message: message,
    initial: initial,
    hint: hint,
    action: action,
    maxLength: maxLength,
    keyboardType: keyboardType,
    extra: extra,
  ),
);

class _PromptDialog extends StatefulWidget {
  const _PromptDialog({
    required this.title,
    required this.message,
    required this.initial,
    required this.hint,
    required this.action,
    required this.maxLength,
    required this.keyboardType,
    required this.extra,
  });

  final String title;
  final String? message;
  final String initial;
  final String? hint;
  final String action;
  final int? maxLength;
  final TextInputType? keyboardType;
  final Widget? extra;

  @override
  State<_PromptDialog> createState() => _PromptDialogState();
}

class _PromptDialogState extends State<_PromptDialog> {
  late final _ctl = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.message != null) Text(widget.message!),
        TextField(
          controller: _ctl,
          autofocus: true,
          maxLength: widget.maxLength,
          keyboardType: widget.keyboardType,
          decoration: InputDecoration(hintText: widget.hint),
          onSubmitted: (v) => Navigator.pop(context, v.trim()),
        ),
        ?widget.extra,
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      TextButton(
        onPressed: () => Navigator.pop(context, _ctl.text.trim()),
        child: Text(widget.action),
      ),
    ],
  );
}
