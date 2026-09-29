import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:offline_home/core/log.dart';
import 'package:offline_home/core/models.dart';
import 'package:offline_home/discovery/discovery_service.dart';
import 'package:offline_home/discovery/evidence.dart';
import 'package:offline_home/registry/database.dart';
import 'package:offline_home/registry/repositories.dart';
import 'package:offline_home/registry/secret_store.dart';

class FakeSource implements EvidenceSource {
  Map<String, HostEvidence> next = {};
  @override
  Future<Map<String, HostEvidence>> collect({
    Duration window = Duration.zero,
  }) async => next;
}

HostEvidence wizAt(String ip, String mac) => HostEvidence(ip)
  ..addUdp(
    UdpProbe.wiz,
    Uint8List.fromList(
      utf8.encode(
        '{"method":"registration","result":{"mac":"$mac","success":true}}',
      ),
    ),
  );

void main() {
  late AppDatabase db;
  late DeviceRepository devices;
  late SecretStore secrets;
  late FakeSource source;
  late DiscoveryService svc;
  final t0 = DateTime.utc(2026, 9, 29, 8);
  var now = t0;

  setUp(() {
    db = AppDatabase.memory();
    devices = DeviceRepository(db);
    secrets = SecretStore(MemorySecretBackend(), Redactor());
    source = FakeSource();
    now = t0;
    svc = DiscoveryService(source, devices, secrets, now: () => now);
  });
  tearDown(() => db.close());

  test(
    'new devices are reported, not auto-added; add() applies defaults',
    () async {
      source.next = {'192.168.1.31': wizAt('192.168.1.31', 'a8bb5006033d')};
      final r = await svc.scan();
      expect(r.results.single.isNew, isTrue);
      expect(await devices.all(), isEmpty);

      final d = await svc.add(r.results.single.candidate);
      expect(d.id, 'a8bb5006033d');
      expect(d.name, 'WiZ 033d');
      expect(d.capabilities, {Capability.power});
    },
  );

  test(
    'device changes IP: registry updates, user settings preserved',
    () async {
      source.next = {'192.168.1.31': wizAt('192.168.1.31', 'a8bb5006033d')};
      final first = (await svc.scan()).results.single;
      final added = await svc.add(
        first.candidate,
        name: 'Bedroom lamp',
        roomId: null,
        aliases: ['batti'],
      );
      await devices.upsert(
        added.copyWith(defaultAutoOff: const Duration(minutes: 30)),
      );

      now = t0.add(const Duration(days: 1));
      source.next = {'192.168.1.77': wizAt('192.168.1.77', 'a8bb5006033d')};
      final r = (await svc.scan()).results.single;
      expect(r.movedFrom, '192.168.1.31');
      expect(r.isNew, isFalse);

      final d = (await devices.byId('a8bb5006033d'))!;
      expect(d.ip, '192.168.1.77');
      expect(d.name, 'Bedroom lamp');
      expect(d.aliases, ['batti']);
      expect(d.defaultAutoOff, const Duration(minutes: 30));
      expect(d.lastSeen, now);
    },
  );

  test(
    'matches by MAC when the id differs, and by IP only for the same brand',
    () async {
      await devices.upsert(
        Device(
          id: 'custom-id',
          brand: Brand.wiz,
          protocol: 'wiz',
          ip: '10.0.0.5',
          mac: 'a8bb5006033d',
          name: 'Lamp',
          lastSeen: t0,
        ),
      );
      await devices.upsert(
        Device(
          id: 'ip:10.0.0.9',
          brand: Brand.tasmota,
          protocol: 'tasmota',
          ip: '10.0.0.9',
          name: 'Heater',
          lastSeen: t0,
        ),
      );
      source.next = {
        '10.0.0.6': wizAt('10.0.0.6', 'a8bb5006033d'),
        '10.0.0.9': wizAt(
          '10.0.0.9',
          'a8bb50ffffff',
        ), // a WiZ took the Tasmota's old IP
      };
      final results = (await svc.scan()).results;
      final byIp = {for (final r in results) r.candidate.ip: r};
      expect(byIp['10.0.0.6']!.device!.id, 'custom-id');
      expect(
        byIp['10.0.0.9']!.isNew,
        isTrue,
        reason: 'different brand at the same IP',
      );
      expect((await devices.byId('ip:10.0.0.9'))!.brand, Brand.tasmota);
    },
  );

  test(
    'stored Tuya key → candidate is ready; unseen devices reported',
    () async {
      await secrets.set(
        '01234567890123456789',
        SecretName.localKey,
        '0123456789abcdef',
      );
      await devices.upsert(
        Device(
          id: 'gone',
          brand: Brand.wiz,
          protocol: 'wiz',
          ip: '10.0.0.50',
          name: 'Old',
          lastSeen: t0,
        ),
      );
      final beacon = HostEvidence('192.168.1.30')
        ..addUdp(
          UdpProbe.tuyaBeacon,
          Uint8List.fromList(
            utf8.encode(
              '{"ip":"192.168.1.30","gwId":"01234567890123456789","version":"3.3"}',
            ),
          ),
        );
      source.next = {'192.168.1.30': beacon};
      final r = await svc.scan();
      expect(r.results.single.candidate.needsKey, isFalse);
      expect(r.notSeen.map((d) => d.id), ['gone']);
    },
  );

  test('re-discovery without version keeps the known Tuya version', () async {
    await devices.upsert(
      Device(
        id: 'ip:192.168.1.41',
        brand: Brand.tuya,
        protocol: 'tuya-3.3',
        ip: '192.168.1.41',
        name: 'Plug',
        lastSeen: t0,
      ),
    );
    source.next = {
      '192.168.1.41': HostEvidence('192.168.1.41')
        ..openPorts.add(ScanPort.tuya),
    };
    await svc.scan();
    expect((await devices.byId('ip:192.168.1.41'))!.protocol, 'tuya-3.3');
  });

  test('defaultName', () {
    expect(
      DiscoveryService.defaultName(Brand.tuya, 'bf0123456789abcdefghij'),
      'Tuya ghij',
    );
    expect(DiscoveryService.defaultName(Brand.shelly, 'ab'), 'Shelly ab');
  });
}
