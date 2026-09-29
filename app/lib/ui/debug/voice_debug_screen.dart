import 'dart:async';

import 'package:flutter/material.dart';

import '../../voice/stt_service.dart';
import '../../voice/voice_controller.dart';

/// T4.1 / T4.9 check: hold the mic, speak, see transcript → result. Also accepts typed
/// commands and lists the recogniser's locales.
class VoiceDebugScreen extends StatefulWidget {
  const VoiceDebugScreen({super.key, required this.voice, this.stt});
  final VoiceController voice;
  final SttService? stt;

  @override
  State<VoiceDebugScreen> createState() => _VoiceDebugScreenState();
}

class _VoiceDebugScreenState extends State<VoiceDebugScreen> {
  final _typed = TextEditingController();
  late final StreamSubscription<VoiceState> _sub;
  VoiceState _state = const VoiceIdle();
  String _locales = '';
  final List<String> _history = [];

  @override
  void initState() {
    super.initState();
    _sub = widget.voice.states.listen((s) {
      setState(() => _state = s);
      if (s is VoiceResult && s.transcript.isNotEmpty) {
        _history.insert(0, '“${s.transcript}” → ${s.message}');
      }
    });
    unawaited(_loadLocales());
  }

  Future<void> _loadLocales() async {
    final caps = await widget.stt?.capabilities();
    if (!mounted || caps == null) return;
    setState(
      () => _locales = caps.available
          ? caps.locales
                .where((l) => l.startsWith('en') || l.startsWith('hi'))
                .join(', ')
          : 'speech recognition unavailable',
    );
  }

  @override
  void dispose() {
    unawaited(_sub.cancel());
    _typed.dispose();
    super.dispose();
  }

  Widget _stateView() => switch (_state) {
    VoiceIdle() => const Text('Hold the mic and speak.'),
    VoiceListening(:final partial) => Text('Listening… $partial'),
    VoiceConfirming(:final question, :final options) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(question),
        Wrap(
          spacing: 8,
          children: [
            for (final d in options)
              ActionChip(
                label: Text(d.name),
                onPressed: () => widget.voice.confirm([d]),
              ),
            ActionChip(
              label: const Text('All of these'),
              onPressed: () => widget.voice.confirm(options),
            ),
            ActionChip(
              label: const Text('Cancel'),
              onPressed: widget.voice.cancelConfirmation,
            ),
          ],
        ),
      ],
    ),
    VoiceResult(:final message, :final canUndo, :final ok) => Row(
      children: [
        Icon(
          ok ? Icons.check_circle : Icons.error,
          color: ok ? Colors.green : Colors.red,
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(message)),
        if (canUndo)
          TextButton(onPressed: widget.voice.undo, child: const Text('Undo')),
      ],
    ),
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Voice')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Recogniser locales: $_locales'),
          const SizedBox(height: 16),
          _stateView(),
          const SizedBox(height: 16),
          TextField(
            controller: _typed,
            decoration: const InputDecoration(labelText: 'Or type a command'),
            onSubmitted: (t) => widget.voice.handleText(t),
          ),
          const Divider(height: 32),
          for (final h in _history) Text(h),
        ],
      ),
      floatingActionButton: GestureDetector(
        onLongPressStart: (_) => widget.voice.start(),
        onLongPressEnd: (_) => widget.voice.stopListening(),
        child: const FloatingActionButton(
          onPressed: null,
          tooltip: 'Hold to talk',
          child: Icon(Icons.mic),
        ),
      ),
    );
  }
}
