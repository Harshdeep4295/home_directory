import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

/// Camera discovery messages: ONVIF WS-Discovery and Hikvision SADP (T9.1).
///
/// Both are plain XML over UDP. Parsing is tag-based (namespace prefixes vary by vendor),
/// enough to read a handful of text fields.
abstract final class CameraProbes {
  /// WS-Discovery multicast group and port (python WSDiscovery 2.1.2,
  /// wsdiscovery/threaded.py MULTICAST_IPV4_ADDRESS / MULTICAST_PORT). SADP uses the same
  /// group (hiktools 1.2.2, hiktools/sadp/client.py: ("239.255.255.250", 37020)).
  static const multicastGroup = '239.255.255.250';
  static const onvifPort = 3702;
  static const sadpPort = 37020;

  /// RFC 2326 §3.2: default RTSP port.
  static const rtspPort = 554;

  /// WS-Discovery Probe for ONVIF video devices, as built by WSDiscovery's
  /// actions/probe.py createProbeMessage (namespaces from wsdiscovery/namespaces.py; the
  /// `dn:NetworkVideoTransmitter` type is the ONVIF network WSDL device type).
  static Uint8List onvifProbe([String? messageId]) => utf8.encode(
    '<?xml version="1.0" encoding="UTF-8"?>'
    '<s:Envelope xmlns:a="http://schemas.xmlsoap.org/ws/2004/08/addressing" '
    'xmlns:d="http://schemas.xmlsoap.org/ws/2005/04/discovery" '
    'xmlns:s="http://www.w3.org/2003/05/soap-envelope" '
    'xmlns:dn="http://www.onvif.org/ver10/network/wsdl">'
    '<s:Header>'
    '<a:Action>http://schemas.xmlsoap.org/ws/2005/04/discovery/Probe</a:Action>'
    '<a:MessageID>urn:uuid:${messageId ?? uuid4()}</a:MessageID>'
    '<a:To>urn:schemas-xmlsoap-org:ws:2005:04:discovery</a:To>'
    '</s:Header>'
    '<s:Body><d:Probe><d:Types>dn:NetworkVideoTransmitter</d:Types></d:Probe></s:Body>'
    '</s:Envelope>',
  );

  /// Hikvision SADP inquiry as in hiktools' README: fromdict({Uuid, MAC: ff-ff-ff-ff-ff-ff,
  /// Types: inquiry}); byte-exact with hiktools/sadp/message.py fromdict (ElementTree
  /// tostring with xml_declaration) for the same Uuid.
  static Uint8List sadpInquiry([String? uuid]) => utf8.encode(
    "<?xml version='1.0' encoding='us-ascii'?>\n"
    '<Probe><Uuid>${(uuid ?? uuid4()).toUpperCase()}</Uuid>'
    '<MAC>ff-ff-ff-ff-ff-ff</MAC><Types>inquiry</Types></Probe>',
  );

  /// RTSP OPTIONS (RFC 2326 §10.1); needs no credentials. The reply's Server header often
  /// names the vendor.
  static String rtspOptions(String host, int port) =>
      'OPTIONS rtsp://$host:$port/ RTSP/1.0\r\nCSeq: 1\r\n'
      'User-Agent: OfflineHome\r\n\r\n';

  static String uuid4() {
    final r = Random.secure();
    final b = List<int>.generate(16, (_) => r.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-'
        '${h.substring(16, 20)}-${h.substring(20)}';
  }

  /// Text of the first element whose local name is [tag] (any namespace prefix).
  static String? xmlText(String xml, String tag) {
    final m = RegExp(
      '<(?:[\\w.-]+:)?$tag(?:\\s[^>]*)?>([^<]*)</(?:[\\w.-]+:)?$tag>',
    ).firstMatch(xml);
    final v = m?.group(1)?.trim();
    return v == null || v.isEmpty ? null : _unescape(v);
  }

  static String _unescape(String s) => s
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'")
      .replaceAll('&amp;', '&');
}

/// A WS-Discovery ProbeMatch from an ONVIF device.
class OnvifMatch {
  const OnvifMatch({
    required this.types,
    required this.scopes,
    required this.xaddrs,
  });

  final List<String> types;
  final List<String> scopes;
  final List<String> xaddrs;

  static OnvifMatch? parse(List<int> data) {
    final xml = utf8.decode(data, allowMalformed: true);
    if (!xml.contains('ProbeMatch')) return null;
    List<String> words(String tag) =>
        (CameraProbes.xmlText(xml, tag) ?? '').split(RegExp(r'\s+'))
          ..removeWhere((w) => w.isEmpty);
    return OnvifMatch(
      types: words('Types'),
      scopes: words('Scopes'),
      xaddrs: words('XAddrs'),
    );
  }

  /// ONVIF Core spec scopes: `onvif://www.onvif.org/<key>/<value>`.
  String? scope(String key) {
    final prefix = 'onvif://www.onvif.org/$key/';
    for (final s in scopes) {
      if (s.startsWith(prefix)) {
        return Uri.decodeComponent(s.substring(prefix.length));
      }
    }
    return null;
  }

  bool get isVideo =>
      types.any((t) => t.endsWith('NetworkVideoTransmitter')) ||
      scopes.any(
        (s) =>
            s == 'onvif://www.onvif.org/type/video_encoder' ||
            s == 'onvif://www.onvif.org/type/NetworkVideoTransmitter',
      );

  /// Host of the first device-service address.
  String? get ip {
    for (final x in xaddrs) {
      final h = Uri.tryParse(x)?.host;
      if (h != null && RegExp(r'^\d+\.\d+\.\d+\.\d+$').hasMatch(h)) return h;
    }
    return null;
  }

  String? get vendor => scope('name');
  String? get model => scope('hardware');
}

/// A Hikvision SADP inquiry reply (fields per hiktools DiscoveryPacket).
class SadpReply {
  const SadpReply(this.fields);
  final Map<String, String> fields;

  static const _keys = [
    'Types',
    'DeviceType',
    'DeviceDescription',
    'DeviceSN',
    'MAC',
    'Ipv4Address',
    'HttpPort',
    'Activated',
    'SoftwareVersion',
    'DigitalChannelNum',
  ];

  static SadpReply? parse(List<int> data) {
    final xml = utf8.decode(data, allowMalformed: true);
    // VERIFY: root element name of real replies (hiktools only checks <Types>).
    if (!xml.contains('<Types>')) return null;
    final f = <String, String>{
      for (final k in _keys)
        if (CameraProbes.xmlText(xml, k) case final String v) k: v,
    };
    if ((f['Types'] ?? '').toLowerCase() != 'inquiry') return null;
    if (f['DeviceDescription'] == null && f['DeviceSN'] == null) return null;
    return SadpReply(f);
  }

  String? get model => fields['DeviceDescription'];
  String? get serial => fields['DeviceSN'];
  String? get ip => fields['Ipv4Address'];
  bool? get activated => switch (fields['Activated']?.toLowerCase()) {
    'true' => true,
    'false' => false,
    _ => null,
  };

  /// `c0-56-e3-12-34-56` → `c056e3123456`.
  String? get mac {
    final m = fields['MAC']?.toLowerCase().replaceAll(RegExp('[^0-9a-f]'), '');
    return m == null || m.length != 12 ? null : m;
  }
}
