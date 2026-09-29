import 'package:flutter_test/flutter_test.dart';
import 'package:offline_home/core/intent.dart';
import 'package:offline_home/core/models.dart';

import '../support/test_services.dart';

void main() {
  test('default auto-off schedules an off timer once', () async {
    final geyser = testDevice(
      'geyser',
      'Geyser',
    ).copyWith(defaultAutoOff: const Duration(minutes: 30));
    final fan = testDevice('fan', 'Fan');
    final t = await TestServices.create(devices: [geyser, fan]);
    final s = t.services;
    await s.engine.powerOne(geyser, true);
    final created = await s.timerService.applyAutoOff([geyser, fan]);
    expect(created, hasLength(1));
    final job = created.single.result.valueOrNull!;
    expect(job.endOn, isFalse);
    expect(job.deviceId, 'geyser');
    expect(
      await s.timerService.applyAutoOff([geyser]),
      isEmpty,
      reason: 'already has a timer',
    );
    await s.timerService.powerFor(
      [fan],
      PowerAction.on,
      const Duration(minutes: 5),
    );
    expect((await s.timers.activeFor('fan'))!.tier, TimerTier.native);
    await t.dispose();
  });
}
