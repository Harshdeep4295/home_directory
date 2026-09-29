import 'package:flutter_test/flutter_test.dart';
import 'package:offline_home/adapters/device_adapter.dart';
import 'package:offline_home/core/models.dart';
import 'package:offline_home/core/result.dart';

/// A device under test plus hooks to stop/start whatever backs it (a simulator).
class ContractHarness {
  ContractHarness({
    required this.adapter,
    required this.device,
    required this.stopDevice,
    required this.tearDown,
    this.expectedTimeout = const Duration(milliseconds: 1500),
    this.countdownSupported = false,
    this.combinedPowerForOnly = false,
  });

  final DeviceAdapter adapter;
  final Device device;

  /// Makes the device unreachable (stop the simulator).
  final Future<void> Function() stopDevice;
  final Future<void> Function() tearDown;

  /// The adapter's per-call timeout; offline calls must fail within this + 200 ms.
  final Duration expectedTimeout;
  final bool countdownSupported;

  /// The only native timer is a one-shot "on now, off after d" (Tasmota PulseTime).
  final bool combinedPowerForOnly;
}

/// Shared adapter suite (PSEUDOCODE §5). Every adapter runs this against its simulator.
void adapterContractTest(
  String name,
  Future<ContractHarness> Function() create,
) {
  group('$name adapter contract', () {
    late ContractHarness h;
    setUp(() async => h = await create());
    tearDown(() async {
      await h.adapter.disposeAll();
      await h.tearDown();
    });

    Future<bool?> on() async =>
        (await h.adapter.getState(h.device)).valueOrNull?.on;

    test('setPower on/off is reflected by getState', () async {
      expect(await h.adapter.setPower(h.device, true), isA<Ok<void>>());
      expect(await on(), isTrue);
      expect(await h.adapter.setPower(h.device, false), isA<Ok<void>>());
      expect(await on(), isFalse);
    });

    test('native countdown turns the device off', () async {
      if (h.combinedPowerForOnly) {
        expect(h.adapter.supportsCombinedPowerFor(h.device), isTrue);
        final r = await h.adapter.powerFor(
          h.device,
          true,
          const Duration(seconds: 2),
        );
        expect(r, isA<Ok<CountdownHandle>>(), reason: '$r');
        expect(await on(), isTrue);
        final deadline = DateTime.now().add(const Duration(seconds: 4));
        while (DateTime.now().isBefore(deadline) && await on() != false) {
          await Future<void>.delayed(const Duration(milliseconds: 200));
        }
        expect(await on(), isFalse);
        return;
      }
      if (!h.countdownSupported) {
        expect(h.adapter.nativeCountdownMax(h.device), isNull);
        return;
      }
      expect(h.adapter.nativeCountdownMax(h.device), isNotNull);
      await h.adapter.setPower(h.device, true);
      expect(
        h.adapter.canCountdownTo(h.device, false, currentOn: true),
        isTrue,
      );
      final r = await h.adapter.setCountdown(
        h.device,
        const Duration(seconds: 2),
        false,
      );
      expect(r, isA<Ok<CountdownHandle>>(), reason: '$r');
      final deadline = DateTime.now().add(const Duration(seconds: 4));
      while (DateTime.now().isBefore(deadline) && await on() != false) {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
      expect(await on(), isFalse);
    });

    test(
      'stopped device → offline/timeout error within timeout, no throw',
      () async {
        await h.stopDevice();
        final sw = Stopwatch()..start();
        final r = await h.adapter.getState(h.device);
        final limit = h.expectedTimeout + const Duration(milliseconds: 200);
        expect(sw.elapsed, lessThan(limit));
        expect(
          r.errorOrNull?.kind,
          anyOf(
            DeviceErrorKind.offline,
            DeviceErrorKind.timeout,
            DeviceErrorKind.refused,
          ),
        );
        // Every other entry point must also fail softly.
        final d = h.device;
        final all = <Future<Result<Object?>>>[
          h.adapter.setPower(d, true),
          h.adapter.setBrightness(d, 50),
          h.adapter.setColorTemp(d, 3000),
          h.adapter.setCountdown(d, const Duration(seconds: 5), false),
          h.adapter.getCountdown(d, null),
          h.adapter.cancelCountdown(d, null),
          h.adapter.powerFor(d, true, const Duration(seconds: 5)),
        ];
        for (final r in await Future.wait(all)) {
          expect(r.isErr, isTrue, reason: '$r');
        }
      },
    );
  });
}
