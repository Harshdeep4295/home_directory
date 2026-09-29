import 'package:flutter_test/flutter_test.dart';
import 'package:offline_home/voice/normaliser.dart';

String n(String s) => Normaliser.normalise(s).text;

void main() {
  final cases = <String, String>{
    // basics
    'Turn ON the Geyser, please!': 'turn on geyser',
    'switch off the A.C.': 'switch off ac',
    'a c band karo': 'ac band karo',
    // variants
    'geezer bandh kar do': 'geyser band karo',
    'gizer chaalu kardo': 'geyser chalu karo',
    'pankha bund karo na': 'pankha band karo',
    'batiyan band karo': 'battiyan band karo',
    // verb + do (ambiguity rule)
    'light jala do': 'light jalao',
    'fan bujha do yaar': 'fan bujhao',
    'fan chala do': 'fan chalao',
    'geyser ka timer hata do': 'geyser ka timer hatao',
    // "do" as a number before a unit
    'do minute baad fan band karo': '2 minute baad fan band karo',
    'do ghante ke liye ac chalao': '2 ghanta ke liye ac chalao',
    // "saath": 60 only before a unit
    'saath minute': '60 minute',
    'bedroom ke saath hall bhi': 'bedroom ke hall',
    // number words
    'turn on geyser for twenty five minutes': 'turn on geyser for 25 minute',
    'fan off in five mins': 'fan off in 5 minute',
    'geyser bees minit ke liye chalu karo':
        'geyser 20 minute ke liye chalu karo',
    'pandrah minute': '15 minute',
    'one hundred': '100',
    // fractions
    'adha ghanta': '0.5 ghanta',
    'dedh ghante': '1.5 ghanta',
    'dhai ghante': '2.5 ghanta',
    'saadhe das baje': '10.5 baje',
    'sava nau baje': '9.25 baje',
    'paune gyarah baje': '10.75 baje',
    'half an hour': '0.5 hour',
    'for an hour': 'for 1 hour',
    'in a minute': 'in 1 minute',
    // clock times kept
    'AC off at 11:30 pm': 'ac off at 11:30 pm',
    'raat 11 baje': 'raat 11 baje',
    // Devanagari
    'गीज़र 20 मिनट के लिए चालू करो': 'geyser 20 minute ke liye chalu karo',
    'एसी बंद करो ११ बजे': 'ac band karo 11 baje',
    'पंखा बंद कर दो': 'pankha band karo',
    'सब बत्ती बंद करो': 'sab batti band karo',
  };

  cases.forEach((input, expected) {
    test('"$input"', () => expect(n(input), expected));
  });

  test('unknown Devanagari words fall back to letter transliteration', () {
    expect(Normaliser.transliterateDevanagari('नमस्ते'), 'namaste');
    expect(Normaliser.transliterateDevanagari('कमल'), 'kamal');
  });

  test('tokens list matches text', () {
    expect(Normaliser.normalise('geyser on').tokens, ['geyser', 'on']);
    expect(Normaliser.normalise('   ').tokens, isEmpty);
  });
}
