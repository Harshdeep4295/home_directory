/// Small IPv4 helpers for subnet scans and broadcast addresses.
library;

int? parseIpv4(String ip) {
  final parts = ip.split('.');
  if (parts.length != 4) return null;
  var v = 0;
  for (final p in parts) {
    final n = int.tryParse(p);
    if (n == null || n < 0 || n > 255) return null;
    v = (v << 8) | n;
  }
  return v;
}

String formatIpv4(int v) =>
    [24, 16, 8, 0].map((s) => (v >> s) & 0xFF).join('.');

int _mask(int prefix) =>
    prefix == 0 ? 0 : (0xFFFFFFFF << (32 - prefix)) & 0xFFFFFFFF;

/// Directed broadcast address, e.g. 192.168.1.37/24 → 192.168.1.255.
String subnetBroadcast(String ip, int prefix) {
  final v = parseIpv4(ip);
  if (v == null || prefix < 0 || prefix > 32) return '255.255.255.255';
  return formatIpv4((v | ~_mask(prefix)) & 0xFFFFFFFF);
}

/// Host addresses in the subnet, excluding network, broadcast and [ip] itself.
/// Prefixes shorter than [minPrefix] are narrowed to [minPrefix] around [ip] so a scan
/// never walks a /16 (65k hosts); the app scans at most a /22.
List<String> subnetHosts(String ip, int prefix, {int minPrefix = 22}) {
  final v = parseIpv4(ip);
  if (v == null) return const [];
  final p = prefix.clamp(minPrefix, 30);
  final mask = _mask(p);
  final network = v & mask;
  final broadcast = (network | ~mask) & 0xFFFFFFFF;
  return [
    for (var h = network + 1; h < broadcast; h++)
      if (h != v) formatIpv4(h),
  ];
}
