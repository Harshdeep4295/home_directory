import 'package:flutter_test/flutter_test.dart';
import 'package:offline_home/app/app_settings.dart';
import 'package:offline_home/registry/database.dart';
import 'package:offline_home/registry/repositories.dart';

void main() {
  late AppDatabase db;
  late AppSettings s;
  setUp(() {
    db = AppDatabase.memory();
    s = AppSettings(SettingsRepository(db));
  });
  tearDown(() => db.close());

  test('default place: Home filter, else last used, else Home', () async {
    expect(await s.homePlace(), AppSettings.allPlaces);
    expect(await s.defaultPlace(), 'Home');
    await s.setLastPlace('Office');
    expect(await s.defaultPlace(), 'Office');
    await s.setHomePlace('Village');
    expect(await s.defaultPlace(), 'Village');
    await s.setHomePlace(AppSettings.allPlaces);
    expect(await s.defaultPlace(), 'Office');
  });
}
