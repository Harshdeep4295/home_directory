import '../adapters/device_adapter.dart';
import '../adapters/tuya/tuya_adapter.dart';
import '../core/models.dart';
import '../core/result.dart';
import '../engine/command_engine.dart';
import '../registry/secret_store.dart';

/// Outcome of entering a Tuya local key by hand (T6.2, PSEUDOCODE §12.2).
enum ManualKeyResult {
  invalid('A local key is exactly 16 characters.'),
  ok('Key works.'),
  rejected('The device rejected this key. The previous key was kept.'),
  unverified(
    'Key saved, but the device did not answer, so it is not verified yet.',
  );

  const ManualKeyResult(this.message);
  final String message;
}

/// Tuya local keys are 16 printable ASCII characters (tinytuya: `local_key`, used as the
/// AES-128 key, so exactly 16 bytes).
bool isValidLocalKey(String key) =>
    key.length == 16 && key.codeUnits.every((c) => c > 0x20 && c < 0x7f);

/// Stores [key] for [d], drops any open session so the next call uses it, then checks
/// it with one status read. A rejected key is rolled back to the previous one.
Future<ManualKeyResult> enterLocalKey({
  required Device d,
  required String key,
  required SecretStore secrets,
  required AdapterRegistry adapters,
  required CommandEngine engine,
}) async {
  key = key.trim();
  if (!isValidLocalKey(key)) return ManualKeyResult.invalid;
  final id = TuyaAdapter.tuyaIdOf(d); // one key for all gangs of a switch
  final previous = await secrets.get(id, SecretName.localKey);
  await secrets.set(id, SecretName.localKey, key);
  final adapter = adapters.adapterFor(d);
  await adapter?.dispose(d);
  if (d.ip.isEmpty) return ManualKeyResult.unverified;
  final r = (await engine.status([d])).single.result;
  switch (r) {
    case Ok():
      return ManualKeyResult.ok;
    case Err(:final error) when error.kind == DeviceErrorKind.auth:
      if (previous == null) {
        await secrets.delete(id, SecretName.localKey);
      } else {
        await secrets.set(id, SecretName.localKey, previous);
      }
      await adapter?.dispose(d);
      return ManualKeyResult.rejected;
    case Err():
      return ManualKeyResult.unverified;
  }
}
