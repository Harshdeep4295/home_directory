import 'package:flutter_test/flutter_test.dart';
import 'package:offline_home/adapters/device_adapter.dart';
import 'package:offline_home/adapters/fake_adapter.dart';
import 'package:offline_home/core/models.dart';
import 'package:offline_home/core/result.dart';

import '../support/adapter_contract.dart';

Device fakeDevice(String id, {String protocol = 'fake'}) => Device(
  id: id,
  brand: Brand.unknown,
  protocol: protocol,
  ip: '127.0.0.1',
  name: id,
  lastSeen: DateTime.utc(2026),
);

void main() {
  adapterContractTest('Fake', () async {
    final a = FakeAdapter(latency: const Duration(milliseconds: 5));
    final d = fakeDevice('f1');
    return ContractHarness(
      adapter: a,
      device: d,
      stopDevice: () async => a.offline.add(d.id),
      tearDown: () async {},
      expectedTimeout: const Duration(milliseconds: 100),
      countdownSupported: true,
    );
  });

  group('AdapterRegistry', () {
    final fake = FakeAdapter();
    final registry = AdapterRegistry([fake]);

    test('matches protocol exactly or by "<id>-" prefix', () {
      expect(registry.adapterFor(fakeDevice('a')), fake);
      expect(registry.adapterFor(fakeDevice('b', protocol: 'fake-2')), fake);
      expect(registry.adapterFor(fakeDevice('c', protocol: 'fakery')), isNull);
      expect(registry.byBrand(Brand.unknown), fake);
      expect(registry.byBrand(Brand.wiz), isNull);
    });
  });

  test('guarded converts throws into Err(protocol)', () async {
    final r = await guarded<int>(
      't',
      'boom',
      () async => throw StateError('x'),
    );
    expect(r.errorOrNull?.kind, DeviceErrorKind.protocol);
    expect(await guarded('t', 'fine', () async => const Ok(1)), const Ok(1));
  });

  test('flip-based canCountdownTo', () {
    final a = FakeAdapter();
    final d = fakeDevice('x');
    expect(a.canCountdownTo(d, false, currentOn: true), isTrue);
    expect(a.canCountdownTo(d, true, currentOn: true), isFalse);
    expect(
      FakeAdapter(countdownMax: null).canCountdownTo(d, false, currentOn: true),
      isFalse,
    );
  });
}
