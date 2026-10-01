import 'dart:typed_data';

import '../core/models.dart';
import 'camera_probes.dart';
import 'evidence.dart';

/// Decides a [DeviceCategory] (plus model / vendor when a probe reported one) from the
/// discovery evidence (T9.2). Pure; strongest clue first.
abstract final class Categorizer {
  /// DNS-SD service types (IANA service-name registry) that say what a host is.
  static const tvTypes = {
    '_googlecast._tcp', // Chromecast / Google TV (pychromecast discovery.py)
    '_airplay._tcp', // Apple TV, AirPlay TVs
    '_amzn-wplay._tcp', // Fire TV (Amazon "whisperplay")
    '_androidtvremote2._tcp', // Android TV Remote v2
  };
  static const speakerTypes = {'_spotify-connect._tcp', '_raop._tcp'};
  static const printerTypes = {'_ipp._tcp', '_printer._tcp'};
  static const computerTypes = {
    '_companion-link._tcp', // iPhone / iPad / Mac
    '_device-info._tcp',
    '_smb._tcp',
  };

  /// Extra mDNS types browsed only to categorize (also in iOS NSBonjourServices). Kept
  /// short: Android NSD resolves one service at a time.
  // VERIFY: scan time with ~16 browsed types on Android 10–13.
  static const mdnsTypes = [
    ...tvTypes,
    ...speakerTypes,
    ...printerTypes,
    ...computerTypes,
  ];

  /// pychromecast const.py CAST_TYPES entries of type CAST_TYPE_AUDIO (Cast `md` values).
  static const castAudioModels = {
    'chromecast audio',
    'google home mini',
    'google home',
    'google nest mini',
    'nest audio',
    'nest wifi point',
    'bose smart ultra soundbar',
    'c4a',
    'jbl link 10',
    'jbl link 20',
    'jbl link 300',
    'jbl link 500',
    'jbl link portable',
    'lenovocd-24502f',
    'lg wk7 thinq speaker',
    'marshall stanmore ii',
    'pioneer vsx-831',
    'pioneer vsx-1131',
    'pioneer vsx-lx305',
    'smart soundbar 10',
    'svs pro soundbase',
  };

  /// Web/RTSP server names of Hikvision firmware (incl. EZVIZ).
  // VERIFY: Server header strings seen on real Hikvision / EZVIZ firmware.
  static final hikvisionServer = RegExp(
    r'hikvision|ezviz|app-webs|dnvrs-webs|davinci',
    caseSensitive: false,
  );

  /// Section a candidate belongs in: every device an adapter controls is a light/plug.
  static DeviceCategory of(Candidate c) =>
      c.brand == Brand.unknown ? c.category : DeviceCategory.lightsPlugs;

  /// Fills [Candidate.category], [Candidate.model] and a better name for unknown hosts.
  static Candidate apply(Candidate c, HostEvidence e) {
    if (c.brand != Brand.unknown) {
      return c.copyWith(category: DeviceCategory.lightsPlugs);
    }
    final cam = camera(e);
    if (cam != null) {
      return c.copyWith(
        category: DeviceCategory.camera,
        model: cam.model,
        mac: c.mac ?? cam.mac,
        name: c.name ?? _join(cam.vendor, cam.model) ?? 'Camera',
        evidence: [...c.evidence, ...cam.evidence],
      );
    }
    final cast = e.mdnsOf('_googlecast._tcp');
    if (cast != null) {
      final md = cast.attributes['md'];
      final audio = castAudioModels.contains(md?.toLowerCase());
      return c.copyWith(
        category: audio ? DeviceCategory.speaker : DeviceCategory.tv,
        model: md,
        name: cast.attributes['fn'] ?? c.name,
      );
    }
    for (final (types, cat) in [
      (tvTypes, DeviceCategory.tv),
      (speakerTypes, DeviceCategory.speaker),
      (printerTypes, DeviceCategory.printer),
      (computerTypes, DeviceCategory.computer),
    ]) {
      for (final r in e.mdns) {
        if (types.contains(r.type)) {
          return c.copyWith(
            category: cat,
            model: r.attributes['model'] ?? r.attributes['ty'],
            name: c.name ?? r.name,
          );
        }
      }
    }
    // Home routers sit on .1 (or .254) and serve a web admin page.
    // VERIFY: heuristic; the gateway address is not available to the app.
    final last = e.ip.split('.').last;
    if ((last == '1' || last == '254') &&
        (e.openPorts.contains(ScanPort.http) || e.http.isNotEmpty)) {
      return c.copyWith(category: DeviceCategory.network);
    }
    return c.copyWith(category: DeviceCategory.other);
  }

  /// Camera evidence, strongest first: SADP (Hikvision), ONVIF video device, RTSP port,
  /// Hikvision web server name.
  static CameraEvidence? camera(HostEvidence e) {
    SadpReply? sadp;
    for (final raw in e.udp[UdpProbe.sadp] ?? const <Uint8List>[]) {
      sadp ??= SadpReply.parse(raw);
    }
    OnvifMatch? onvif;
    for (final raw in e.udp[UdpProbe.onvif] ?? const <Uint8List>[]) {
      final m = OnvifMatch.parse(raw);
      if (m != null && m.isVideo) onvif ??= m;
    }
    final httpServer = e.http['/']?.headers['server'];
    final hikServer = [
      httpServer,
      e.rtspServer,
    ].any((s) => s != null && hikvisionServer.hasMatch(s));
    final rtsp = e.openPorts.contains(ScanPort.rtsp) || e.rtspServer != null;
    if (sadp == null && onvif == null && !rtsp && !hikServer) return null;
    final hikvision =
        sadp != null ||
        hikServer ||
        (onvif?.vendor?.toLowerCase().contains(RegExp('hikvision|ezviz')) ??
            false);
    final onvifVendor = onvif?.vendor;
    return CameraEvidence(
      vendor: onvifVendor != null && onvifVendor.isNotEmpty
          ? onvifVendor
          : hikvision
          ? 'Hikvision'
          : null,
      model: sadp?.model ?? onvif?.model,
      mac: sadp?.mac,
      hikvision: hikvision,
      activated: sadp?.activated,
      evidence: [
        if (sadp != null) 'sadp ${sadp.model ?? sadp.serial}',
        if (onvif != null) 'onvif ${onvif.vendor ?? ''} ${onvif.model ?? ''}',
        if (e.rtspServer case final String s) 'rtsp server "$s"',
        if (e.rtspServer == null && rtsp) 'tcp 554 open',
      ],
    );
  }

  static String? _join(String? a, String? b) {
    final parts = [a, b].whereType<String>().where((s) => s.isNotEmpty);
    return parts.isEmpty ? null : parts.join(' ');
  }
}

class CameraEvidence {
  const CameraEvidence({
    this.vendor,
    this.model,
    this.mac,
    this.hikvision = false,
    this.activated,
    this.evidence = const [],
  });

  final String? vendor;
  final String? model;
  final String? mac;

  /// Hikvision firmware (incl. EZVIZ / Hik-Connect): the camera adapter can try it.
  final bool hikvision;

  /// SADP `Activated`: an inactive camera has no password yet (activate it in its app).
  final bool? activated;
  final List<String> evidence;
}
