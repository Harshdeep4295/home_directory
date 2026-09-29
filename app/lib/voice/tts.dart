import 'package:flutter_tts/flutter_tts.dart';

abstract interface class Tts {
  Future<void> speak(String text);
  Future<void> stop();
}

/// Platform TTS (offline voices where installed).
class PlatformTts implements Tts {
  PlatformTts({this._language = 'en-IN'});

  final FlutterTts _tts = FlutterTts();
  final String _language;
  bool _configured = false;

  @override
  Future<void> speak(String text) async {
    if (!_configured) {
      await _tts.setLanguage(_language);
      _configured = true;
    }
    await _tts.speak(text);
  }

  @override
  Future<void> stop() => _tts.stop();
}

class SilentTts implements Tts {
  final List<String> spoken = [];
  @override
  Future<void> speak(String text) async => spoken.add(text);
  @override
  Future<void> stop() async {}
}
