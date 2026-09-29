import 'package:flutter_test/flutter_test.dart';
import 'package:offline_home/adapters/tuya/tuya_adapter.dart';
import 'package:offline_home/core/models.dart';

/// Profile detection ported from tinytuya BulbDevice.detect_bulb (examples are the ones
/// in its docstring).
void main() {
  test('Sylvania BR30 (type B, RGB+CCT)', () {
    final m = TuyaDp.detect({
      '20': true,
      '21': 'colour',
      '22': 750,
      '23': 278,
      '24': '00f003e803e8',
      '25': '000e0d0000000000000000c803e8',
      '26': 0,
    });
    expect(m, TuyaDp.bulb);
    expect(TuyaDp.capabilities(m), {
      Capability.power,
      Capability.nativeCountdown,
      Capability.brightness,
      Capability.colorTemp,
    });
  });

  test('Feit soft white (type B without CCT) keeps only reported roles', () {
    final m = TuyaDp.detect({'20': true, '21': 'white', '22': 60, '26': 0});
    expect(m.containsKey(TuyaDp.colorTemp), isFalse);
    expect(m[TuyaDp.brightness], 22);
  });

  test('Geeni filament (type C: 1 switch, 2 brightness, 3 temp)', () {
    final m = TuyaDp.detect({'1': true, '2': 25, '3': 0});
    expect(m[TuyaDp.brightness], 2);
    expect(m[TuyaDp.colorTemp], 3);
    expect(m[TuyaDp.valueMax], 255);
  });

  test('type A: DP 2 is the mode string', () {
    final m = TuyaDp.detect({'1': true, '2': 'white', '3': 255, '4': 0});
    expect(m[TuyaDp.brightness], 3);
    expect(m[TuyaDp.mode], 2);
  });

  test('plugs: 1+9, and 1+20 (metering) are not bulbs', () {
    expect(TuyaDp.detect({'1': true, '9': 0}), TuyaDp.plug);
    expect(TuyaDp.detect({'1': true, '9': 0, '20': 2300}), TuyaDp.plug);
    expect(TuyaDp.capabilities(TuyaDp.plug), {
      Capability.power,
      Capability.nativeCountdown,
    });
  });

  test('gang defaults and ids', () {
    expect(TuyaDp.gang(2), {TuyaDp.switch_: 2, TuyaDp.countdown: 8});
    expect(TuyaAdapter.gangDeviceId('bfx', 1), 'bfx');
    expect(TuyaAdapter.gangDeviceId('bfx', 3), 'bfx#3');
  });
}
