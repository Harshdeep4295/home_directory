import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
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
}
