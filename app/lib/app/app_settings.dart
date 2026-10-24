import '../core/models.dart';
import '../registry/repositories.dart';

enum VoiceLanguage {
  englishIndia('English (India)', 'en_IN'),
  hinglish('Hinglish', 'en_IN'),
  hindi('Hindi (हिन्दी)', 'hi_IN');

  const VoiceLanguage(this.label, this.localeId);
  final String label;

  /// Hinglish is recognised with the en-IN model (PLAN §7); Hindi uses hi-IN if the
  /// phone has that on-device model.
  final String localeId;
}

/// Typed view over the settings table.
class AppSettings {
  AppSettings(this._repo);
  final SettingsRepository _repo;

  static const kLanguage = 'voice.language';
  static const kTts = 'voice.tts';
  static const kPoll = 'poll.seconds';
  static const kOnboarded = 'onboarded';
  static const kHomePlace = 'home.place';
  static const kLastPlace = 'place.last';

  /// Value of [kHomePlace] that shows every place.
  static const allPlaces = 'All';

  Future<VoiceLanguage> language() async =>
      VoiceLanguage.values.asNameMap()[await _repo.get(kLanguage)] ??
      VoiceLanguage.hinglish;
  Future<void> setLanguage(VoiceLanguage l) => _repo.set(kLanguage, l.name);

  Future<bool> tts() => _repo.getBool(kTts, orElse: true);
  Future<void> setTts(bool on) => _repo.setBool(kTts, on);

  Future<int> pollSeconds() async =>
      int.tryParse(await _repo.get(kPoll) ?? '') ?? 5;
  Future<void> setPollSeconds(int s) => _repo.set(kPoll, '$s');

  Future<bool> onboarded() => _repo.getBool(kOnboarded);
  Future<void> setOnboarded(bool v) => _repo.setBool(kOnboarded, v);

  /// Place filter on Home (PSEUDOCODE §15); [allPlaces] when unset.
  Future<String> homePlace() async => await _repo.get(kHomePlace) ?? allPlaces;
  Future<void> setHomePlace(String p) => _repo.set(kHomePlace, p);

  Future<void> setLastPlace(String p) => _repo.set(kLastPlace, p);

  /// Pre-selected place when adding: the Home filter, else the last one used, else
  /// Home.
  Future<String> defaultPlace() async {
    final filter = await homePlace();
    if (filter != allPlaces) return filter;
    return await _repo.get(kLastPlace) ?? Places.home;
  }
}
