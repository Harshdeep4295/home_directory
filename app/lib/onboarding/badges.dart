import '../adapters/device_adapter.dart';
import '../core/models.dart';

/// Onboarding status of a discovered device (PLAN §9 step 3).
enum OnboardingBadge {
  ready('Ready'),
  needsKey('Needs key'),
  needsPairing('Needs pairing'),
  cloudOnly('Cloud-only'),
  notSupportedYet('Not supported yet'),

  /// A camera: add it with its own login (EZVIZ sticker code / device password).
  cameraLogin('Needs password'),
  unknown('Unknown');

  const OnboardingBadge(this.label);
  final String label;
}

OnboardingBadge badgeFor(Candidate c, AdapterRegistry adapters) {
  if (c.brand == Brand.unknown) {
    return c.category == DeviceCategory.camera
        ? OnboardingBadge.cameraLogin
        : OnboardingBadge.unknown;
  }
  if (!adapters.supportsProtocol(c.protocol)) {
    return OnboardingBadge.notSupportedYet;
  }
  if (c.needsKey) {
    return c.brand == Brand.hue
        ? OnboardingBadge.needsPairing
        : OnboardingBadge.needsKey;
  }
  return OnboardingBadge.ready;
}
