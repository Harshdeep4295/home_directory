import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:offline_home/cameras/camera.dart';
import 'package:offline_home/core/models.dart';
import 'package:offline_home/registry/config_export.dart';
import 'package:offline_home/registry/secret_store.dart';

import '../support/test_services.dart';

void main() {
  test(
    'round trip with and without secrets; wrong passphrase; not a config',
    () async {
      final src = await TestServices.create(
        devices: [
          testDevice(
            'geyser',
            'Geyser',
            room: 'bath',
          ).copyWith(aliases: ['garam pani']),
        ],
        rooms: const [Room(id: 'bath', name: 'Bathroom')],
      );
      await src.services.secrets.set(
        'geyser',
        SecretName.localKey,
        '0123456789abcdef',
      );
      await src.services.appSettings.setTts(false);
      final exporter = ConfigExporter(
        src.services.devices,
        src.services.rooms,
        src.services.settings,
        src.services.secrets,
        iterations: 1000,
      );

      final plain = await exporter.export('passphrase');
      final withKeys = await exporter.export(
        'passphrase',
        includeSecrets: true,
      );
      expect(
        utf8.decode(withKeys),
        isNot(contains('0123456789abcdef')),
        reason: 'encrypted',
      );
      expect(utf8.decode(plain), isNot(contains('Geyser')));

      final dst = await TestServices.create();
      final imp = ConfigExporter(
        dst.services.devices,
        dst.services.rooms,
        dst.services.settings,
        dst.services.secrets,
        iterations: 1000,
      );
      expect(
        () => imp.import(plain, 'wrong-pass'),
        throwsA(isA<ConfigException>()),
      );
      expect(
        () => imp.import(utf8.encode('{"hello":1}'), 'x'),
        throwsA(isA<ConfigException>()),
      );

      expect(await imp.import(plain, 'passphrase'), 1);
      final d = (await dst.services.devices.byId('geyser'))!;
      expect(d.name, 'Geyser');
      expect(d.aliases, ['garam pani']);
      expect((await dst.services.rooms.all()).single.name, 'Bathroom');
      expect(await dst.services.appSettings.tts(), isFalse);
      expect(
        await dst.services.secrets.get('geyser', SecretName.localKey),
        isNull,
        reason: 'not opted in',
      );

      await imp.import(withKeys, 'passphrase');
      expect(
        await dst.services.secrets.get('geyser', SecretName.localKey),
        '0123456789abcdef',
      );

      expect(() => exporter.export('short'), throwsA(isA<ConfigException>()));
      await src.dispose();
      await dst.dispose();
    },
  );

  test(
    'places, cameras and camera credentials travel with the secrets',
    () async {
      final src = await TestServices.create(
        devices: [testDevice('lamp', 'Lamp').copyWith(place: 'Office')],
      );
      const cam = Camera(
        id: 'cam1',
        name: 'Door',
        ip: '192.168.1.7',
        mainPath: '/Streaming/Channels/101',
        place: 'Office',
      );
      await src.services.settings.set('cameras', jsonEncode([cam.toJson()]));
      await src.services.secrets.set('cam1', SecretName.username, 'admin');
      await src.services.secrets.set('cam1', SecretName.password, 'ABCDEF');
      await src.services.secrets.set('bridge1', SecretName.hueUser, 'hue-user');
      ConfigExporter ex(TestServices t) => ConfigExporter(
        t.services.devices,
        t.services.rooms,
        t.services.settings,
        t.services.secrets,
        iterations: 1000,
      );
      final file = await ex(src).export('passphrase', includeSecrets: true);

      final dst = await TestServices.create();
      await ex(dst).import(file, 'passphrase');
      expect((await dst.services.devices.byId('lamp'))!.place, 'Office');
      final cams = jsonDecode((await dst.services.settings.get('cameras'))!);
      expect(
        Camera.fromJson((cams as List).single as Map<String, Object?>).place,
        'Office',
      );
      expect(
        await dst.services.secrets.get('cam1', SecretName.password),
        'ABCDEF',
      );
      expect(
        await dst.services.secrets.get('bridge1', SecretName.hueUser),
        'hue-user',
      );
      await src.dispose();
      await dst.dispose();
    },
  );

  test(
    'partial export (T10.6): only chosen items, their rooms and keys',
    () async {
      final src = await TestServices.create(
        devices: [
          testDevice(
            'geyser',
            'Geyser',
            room: 'bath',
          ).copyWith(place: 'Village'),
          testDevice('fan', 'Fan', room: 'bed'),
          testDevice('strip-2', 'Strip 2').copyWith(meta: {'tuyaId': 'strip'}),
          testDevice('tapo1', 'Tapo', brand: Brand.tapo),
        ],
        rooms: const [
          Room(id: 'bath', name: 'Bathroom'),
          Room(id: 'bed', name: 'Bedroom'),
        ],
      );
      final sec = src.services.secrets;
      await sec.set('geyser', SecretName.localKey, 'geyserkey0123456');
      await sec.set('fan', SecretName.localKey, 'fankey0123456789');
      await sec.set('strip', SecretName.localKey, 'stripkey01234567');
      await sec.set('tplink', SecretName.email, 'me@example.com');
      await sec.set('cam1', SecretName.password, 'ABCDEF');
      await sec.set('cam2', SecretName.password, 'GHIJKL');
      for (final c in const [
        Camera(id: 'cam1', name: 'Door', ip: '192.168.1.7', mainPath: '/m'),
        Camera(id: 'cam2', name: 'Shop', ip: '192.168.1.8', mainPath: '/m'),
      ]) {
        await src.services.cameras.put(c);
      }
      await src.services.appSettings.setTts(false);
      ConfigExporter ex(TestServices t) => ConfigExporter(
        t.services.devices,
        t.services.rooms,
        t.services.settings,
        t.services.secrets,
        iterations: 1000,
      );
      final file = await ex(src).export(
        'passphrase',
        includeSecrets: true,
        only: {'geyser', 'strip-2', 'cam1'},
      );

      final dst = await TestServices.create(
        devices: [testDevice('own', 'Own lamp')],
      );
      await dst.services.cameras.put(
        const Camera(
          id: 'cam9',
          name: 'Mine',
          ip: '192.168.1.9',
          mainPath: '/m',
        ),
      );
      expect(await ex(dst).import(file, 'passphrase'), 2);
      final ids = {for (final d in await dst.services.devices.all()) d.id};
      expect(ids, {'own', 'geyser', 'strip-2'});
      expect((await dst.services.devices.byId('geyser'))!.place, 'Village');
      expect([for (final r in await dst.services.rooms.all()) r.id], ['bath']);
      final dsec = dst.services.secrets;
      expect(await dsec.get('geyser', SecretName.localKey), 'geyserkey0123456');
      expect(
        await dsec.get('strip', SecretName.localKey),
        'stripkey01234567',
        reason: 'gang outlet needs its parent key',
      );
      expect(await dsec.get('fan', SecretName.localKey), isNull);
      expect(await dsec.get('tplink', SecretName.email), isNull);
      expect(await dsec.get('cam1', SecretName.password), 'ABCDEF');
      expect(await dsec.get('cam2', SecretName.password), isNull);
      expect(
        {for (final c in await dst.services.cameras.all()) c.id},
        {'cam9', 'cam1'},
        reason: 'cameras merge; the receiver keeps its own',
      );
      expect(
        await dst.services.appSettings.tts(),
        isTrue,
        reason: 'phone-wide settings stay out of a partial share',
      );

      // Choosing a Tapo device brings the TP-Link account along.
      final tapo = await ex(src)
          .export('passphrase', includeSecrets: true, only: {'tapo1'});
      await ex(dst).import(tapo, 'passphrase');
      expect(await dsec.get('tplink', SecretName.email), 'me@example.com');
      await src.dispose();
      await dst.dispose();
    },
  );
}
