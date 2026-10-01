import 'dart:async';

import 'package:bonsoir/bonsoir.dart';

import '../core/log.dart';
import 'categorizer.dart';
import 'evidence.dart';

/// mDNS service types browsed during a scan (PLAN §5). Must match iOS NSBonjourServices.
const mdnsServiceTypes = [
  '_hue._tcp',
  '_shelly._tcp',
  '_http._tcp',
  '_ewelink._tcp',
  '_esphomelib._tcp',
  ...Categorizer.mdnsTypes,
];

abstract interface class MdnsBrowser {
  /// Browses [types] for [window]; returns (ip, record) for every resolved instance.
  Future<List<(String, MdnsRecord)>> browse(
    List<String> types,
    Duration window,
  );
}

/// Native NSD (Android) / NetService (iOS) via bonsoir: works on iOS without the
/// multicast entitlement (PLAN D3).
class BonsoirMdnsBrowser implements MdnsBrowser {
  static const _tag = 'mdns';

  @override
  Future<List<(String, MdnsRecord)>> browse(
    List<String> types,
    Duration window,
  ) async {
    final found = <(String, MdnsRecord)>[];
    final discoveries = <BonsoirDiscovery>[];
    final subs = <StreamSubscription<BonsoirDiscoveryEvent>>[];
    for (final type in types) {
      try {
        final d = BonsoirDiscovery(type: type, printLogs: false);
        await d.initialize();
        subs.add(
          d.eventStream!.listen((e) {
            switch (e) {
              case BonsoirDiscoveryServiceFoundEvent(:final service):
                unawaited(
                  Future.sync(() => service.resolve(d.serviceResolver))
                      .catchError((Object _) {}),
                );
              case BonsoirDiscoveryServiceResolvedEvent(:final service):
                for (final ip in service.hostAddresses) {
                  if (ip.contains('.')) {
                    found.add((
                      ip,
                      MdnsRecord(
                        type: type,
                        name: service.name,
                        port: service.port,
                        attributes: service.attributes,
                      ),
                    ));
                  }
                }
              default:
                break;
            }
          }),
        );
        await d.start();
        discoveries.add(d);
      } on Object catch (e) {
        log.w(_tag, 'browse $type failed', e);
      }
    }
    await Future<void>.delayed(window);
    for (final s in subs) {
      await s.cancel();
    }
    for (final d in discoveries) {
      try {
        await d.stop();
      } on Object {
        // already stopped
      }
    }
    return found;
  }
}
