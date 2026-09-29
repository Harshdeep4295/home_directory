import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:offline_home/adapters/tuya/tuya_adapter.dart';
import 'package:offline_home/core/log.dart';
import 'package:offline_home/core/models.dart';
import 'package:offline_home/onboarding/devices_json_import.dart';
import 'package:offline_home/registry/database.dart';
import 'package:offline_home/registry/repositories.dart';
import 'package:offline_home/registry/secret_store.dart';

void main() {
  final sample = File('test/onboarding/fixtures/sample_devices.json')
      .readAsStringSync();
  late AppDatabase db;
  late DeviceRepository devices;
  late MemorySecretBackend backend;
  late SecretStore secrets;
  late DevicesJsonImporter importer;

  setUp(() {
    db = AppDatabase.memory();
    devices = DeviceRepository(db);
    backend = MemorySecretBackend();
    secrets = SecretStore(backend, Redactor());
    importer = DevicesJsonImporter(
      devices,
      secrets,
      now: () => DateTime.utc(2026, 9, 29),
    );
  });
  tearDown(() => db.close());

  test('parses the tinytuya wizard format', () {
    final e = parseDevicesJson(sample);
    expect(e.map((x) => x.id), hasLength(4));
    expect(e[0].version, '3.3');
    expect(e[0].ip, '192.168.1.40');
    expect(e[0].mapping, {1: 'switch_1', 9: 'countdown_1', 18: 'cur_current'});
    expect(e[1].ip, isNull);
    expect(e[2].subDevice, isTrue);
    expect(e[3].key, '');
  });

  test('dpMap derived from mapping codes', () {
    expect(dpMapFromMapping({1: 'switch_1', 9: 'countdown_1'}), {
      TuyaDp.switch_: 1,
      TuyaDp.countdown: 9,
    });
    expect(dpMapFromMapping({20: 'switch_led', 26: 'countdown'}), {
      TuyaDp.switch_: 20,
      TuyaDp.countdown: 26,
    });
    expect(dpMapFromMapping({18: 'cur_current'}), isNull);
    expect(dpMapFromMapping({}), isNull);
  });

  test('sample file imports; keys land in SecretStore only', () async {
    final out = await importer.importText(sample);
    expect(out.map((o) => o.status), [
      ImportStatus.added,
      ImportStatus.added,
      ImportStatus.subDevice,
      ImportStatus.noKey,
    ]);
    expect(
      await secrets.get('bf0123456789abcdefgh', SecretName.localKey),
      'k3yK3YkeyKEY0001',
    );
    final plug = (await devices.byId('bf0123456789abcdefgh'))!;
    expect(plug.brand, Brand.tuya);
    expect(plug.protocol, 'tuya-3.3');
    expect(plug.ip, '192.168.1.40');
    expect(plug.name, 'Geyser Plug');
    expect(plug.dpMap, {TuyaDp.switch_: 1, TuyaDp.countdown: 9});
    final bulb = (await devices.byId('bf9876543210zyxwvuts'))!;
    expect(bulb.protocol, 'tuya');
    expect(bulb.ip, '');
    expect(bulb.dpMap, {
      TuyaDp.switch_: 20,
      TuyaDp.countdown: 26,
      TuyaDp.brightness: 22,
      TuyaDp.valueMin: 10,
      TuyaDp.valueMax: 1000,
    });
    expect(bulb.capabilities, contains(Capability.brightness));
    expect(await devices.byId('bfsub0000000000000aa'), isNull);
    expect(await devices.byId('bfnokey0000000000000'), isNull);

    // Rule 5: nothing key-like in the database.
    final dump = (await devices.all()).map((d) => d.toJson()).toString();
    expect(dump, isNot(contains('k3yK3YkeyKEY0001')));
    expect(dump, isNot(contains('k3yK3YkeyKEY0002')));
    expect(
      secrets.redactor.redact('k=k3yK3YkeyKEY0001'),
      isNot(contains('k3yK3YkeyKEY0001')),
    );
  });

  test('existing devices matched by id keep user settings', () async {
    await RoomRepository(db).upsert(const Room(id: 'bath', name: 'Bathroom'));
    await devices.upsert(
      Device(
        id: 'bf0123456789abcdefgh',
        brand: Brand.tuya,
        protocol: 'tuya',
        ip: '192.168.1.77',
        name: 'Geyser',
        roomId: 'bath',
        aliases: const ['paani garam'],
        lastSeen: DateTime.utc(2026),
      ),
    );
    final out = await importer.importText(sample);
    expect(out.first.status, ImportStatus.updated);
    final d = (await devices.byId('bf0123456789abcdefgh'))!;
    expect(d.name, 'Geyser');
    expect(d.roomId, 'bath');
    expect(d.aliases, ['paani garam']);
    expect(d.ip, '192.168.1.77', reason: 'scanned IP beats the file');
    expect(d.protocol, 'tuya-3.3');
    expect(d.mac, 'a4:cf:12:00:00:01');
  });

  test('rejects bad input', () async {
    expect(
      () => importer.importText('not json'),
      throwsA(isA<DevicesJsonFormatException>()),
    );
    expect(
      () => importer.importText('{"id": "x"}'),
      throwsA(isA<DevicesJsonFormatException>()),
    );
    final out = await importer.importText(
      '[{"id":"bfshort","name":"x","key":"abc"}]',
    );
    expect(out.single.status, ImportStatus.badKey);
    expect(await devices.byId('bfshort'), isNull);
  });

  test('bulb ranges: from mapping values, else tinytuya defaults', () {
    expect(
      dpMapFromMapping({
        1: 'switch_led',
        2: 'work_mode',
        3: 'bright_value',
        4: 'temp_value',
      }),
      {
        TuyaDp.switch_: 1,
        TuyaDp.mode: 2,
        TuyaDp.brightness: 3,
        TuyaDp.colorTemp: 4,
        TuyaDp.valueMin: 25,
        TuyaDp.valueMax: 255,
      },
    );
    expect(
      dpMapFromMapping(
        {20: 'switch_led', 22: 'bright_value_v2'},
        ranges: {22: (10, 1000)},
      )![TuyaDp.valueMax],
      1000,
    );
    expect(rangeOf('{"min":10,"max":1000,"scale":0}'), (10, 1000));
    expect(rangeOf({'min': 25, 'max': 255}), (25, 255));
    expect(rangeOf('{}'), isNull);
  });

  test('multi-gang switch → one app device per gang, one shared key', () async {
    const text =
        '[{"id":"bfgang0000000000000x","name":"Hall Board","key":"k3yK3YkeyKEY0003",'
        '"version":"3.3","mapping":{'
        '"1":{"code":"switch_1","type":"Boolean","values":{}},'
        '"2":{"code":"switch_2","type":"Boolean","values":{}},'
        '"3":{"code":"switch_3","type":"Boolean","values":{}},'
        '"7":{"code":"countdown_1","type":"Integer","values":{}},'
        '"8":{"code":"countdown_2","type":"Integer","values":{}},'
        '"9":{"code":"countdown_3","type":"Integer","values":{}}}}]';
    final out = await importer.importText(text);
    expect(out.single.status, ImportStatus.added);
    expect(out.single.devices.map((d) => d.id), [
      'bfgang0000000000000x',
      'bfgang0000000000000x#2',
      'bfgang0000000000000x#3',
    ]);
    final g2 = (await devices.byId('bfgang0000000000000x#2'))!;
    expect(g2.name, 'Hall Board 2');
    expect(g2.dpMap, {TuyaDp.switch_: 2, TuyaDp.countdown: 8});
    expect(TuyaAdapter.tuyaIdOf(g2), 'bfgang0000000000000x');
    expect(TuyaAdapter.gangOf(g2), 2);
    expect(
      await secrets.get('bfgang0000000000000x', SecretName.localKey),
      'k3yK3YkeyKEY0003',
    );
    expect(
      await secrets.has('bfgang0000000000000x#2', SecretName.localKey),
      isFalse,
    );
  });
}
