import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../voice/voice_controller.dart';
import '../providers.dart';

/// Opens the voice sheet and starts listening (T5.5).
Future<void> showVoiceSheet(
  BuildContext context,
  WidgetRef ref, {
  bool listen = true,
}) async {
  final voice = ref.read(servicesProvider).voice;
  if (voice == null) return;
  if (listen) unawaited(voice.start());
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const VoiceSheet(),
  );
  await voice.stopListening();
}

class VoiceSheet extends ConsumerStatefulWidget {
  const VoiceSheet({super.key});

  @override
  ConsumerState<VoiceSheet> createState() => _VoiceSheetState();
}

class _VoiceSheetState extends ConsumerState<VoiceSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);
  final _typed = TextEditingController();

  @override
  void dispose() {
    _pulse.dispose();
    _typed.dispose();
    super.dispose();
  }

  VoiceController get _voice => ref.read(servicesProvider).voice!;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(voiceStateProvider).value ?? const VoiceIdle();
    final theme = Theme.of(context);
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
          switch (state) {
            VoiceListening(:final partial) => Column(
              children: [
                ScaleTransition(
                  scale: Tween(begin: 0.9, end: 1.15).animate(_pulse),
                  child: CircleAvatar(
                    radius: 36,
                    backgroundColor: theme.colorScheme.primary,
                    child: Icon(
                      Icons.mic,
                      size: 36,
                      color: theme.colorScheme.onPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  partial.isEmpty ? 'Listening…' : partial,
                  style: theme.textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                TextButton(
                  onPressed: _voice.stopListening,
                  child: const Text('Stop'),
                ),
              ],
            ),
            VoiceConfirming(
              :final transcript,
              :final question,
              :final options,
            ) =>
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('“$transcript”', style: theme.textTheme.bodySmall),
                  const SizedBox(height: 8),
                  Text(question, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final d in options)
                        ActionChip(
                          label: Text(d.name),
                          onPressed: () => _voice.confirm([d]),
                        ),
                      ActionChip(
                        avatar: const Icon(Icons.done_all, size: 16),
                        label: Text(
                          options.length > 3
                              ? 'Yes, all ${options.length}'
                              : 'All of these',
                        ),
                        onPressed: () => _voice.confirm(options),
                      ),
                      ActionChip(
                        label: const Text('Cancel'),
                        onPressed: _voice.cancelConfirmation,
                      ),
                    ],
                  ),
                ],
              ),
            VoiceResult(
              :final transcript,
              :final message,
              :final ok,
              :final canUndo,
            ) =>
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (transcript.isNotEmpty)
                    Text('“$transcript”', style: theme.textTheme.bodySmall),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        ok ? Icons.check_circle : Icons.error_outline,
                        color: ok
                            ? theme.colorScheme.primary
                            : theme.colorScheme.error,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          message,
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      if (canUndo)
                        TextButton(
                          onPressed: _voice.undo,
                          child: const Text('Undo'),
                        ),
                      const Spacer(),
                      FilledButton.icon(
                        onPressed: () => unawaited(_voice.start()),
                        icon: const Icon(Icons.mic),
                        label: const Text('Speak again'),
                      ),
                    ],
                  ),
                ],
              ),
            VoiceIdle() => Center(
              child: FilledButton.icon(
                onPressed: () => unawaited(_voice.start()),
                icon: const Icon(Icons.mic),
                label: const Text('Tap to speak'),
              ),
            ),
          },
          const SizedBox(height: 16),
          TextField(
            controller: _typed,
            decoration: const InputDecoration(
              hintText: 'Or type: "geyser on for 20 minutes"',
              prefixIcon: Icon(Icons.keyboard),
            ),
            textInputAction: TextInputAction.go,
            onSubmitted: (t) {
              if (t.trim().isEmpty) return;
              _typed.clear();
              unawaited(_voice.handleText(t));
            },
          ),
        ],
      ),
    );
  }
}
