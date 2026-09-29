/// Hinglish alias suggestions for a device name (PLAN §9 step 5: light → batti,
/// fan → pankha …). Returned lowercase; the caller filters ones already present.
List<String> aliasSuggestions(String name) {
  final n = name.toLowerCase();
  final out = <String>[];
  void add(List<String> xs) => out.addAll(xs.where((x) => !out.contains(x)));
  if (RegExp(r'light|lamp|bulb|batti').hasMatch(n)) add(['batti', 'light']);
  if (RegExp(r'fan|pankha').hasMatch(n)) add(['pankha']);
  if (RegExp(r'geyser|heater').hasMatch(n)) add(['geyser', 'garam pani']);
  if (RegExp(r'\bac\b|air con').hasMatch(n)) add(['ac', 'a c']);
  if (RegExp(r'\btv\b|television').hasMatch(n)) add(['tv', 'television']);
  return out.where((a) => a != n).toList();
}
