/// A camera the user added (T9.4). Stored as JSON in the settings table; credentials
/// live in SecretStore under [id] (username / password), never here.
class Camera {
  const Camera({
    required this.id,
    required this.name,
    required this.ip,
    this.port = 554,
    this.vendor,
    this.model,
    required this.mainPath,
    this.subPath,
    this.roomId,
  });

  /// Stable id: MAC from SADP when known, else `ip:<ip>`.
  final String id;
  final String name;
  final String ip;

  /// RTSP port.
  final int port;
  final String? vendor;
  final String? model;

  /// Stream paths that answered DESCRIBE with the stored credentials.
  final String mainPath;
  final String? subPath;
  final String? roomId;

  /// `rtsp://user:pass@ip:port/path`; credentials percent-encoded. Never log the result.
  String streamUrl(String user, String password, {bool sub = false}) {
    final path = sub ? (subPath ?? mainPath) : mainPath;
    final u = Uri.encodeComponent(user);
    final p = Uri.encodeComponent(password);
    return 'rtsp://$u:$p@$ip:$port$path';
  }

  Camera copyWith({String? name, String? ip, String? roomId}) => Camera(
    id: id,
    name: name ?? this.name,
    ip: ip ?? this.ip,
    port: port,
    vendor: vendor,
    model: model,
    mainPath: mainPath,
    subPath: subPath,
    roomId: roomId ?? this.roomId,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'ip': ip,
    'port': port,
    'vendor': vendor,
    'model': model,
    'mainPath': mainPath,
    'subPath': subPath,
    'roomId': roomId,
  };

  factory Camera.fromJson(Map<String, Object?> j) => Camera(
    id: j['id']! as String,
    name: j['name']! as String,
    ip: j['ip']! as String,
    port: (j['port'] as num?)?.toInt() ?? 554,
    vendor: j['vendor'] as String?,
    model: j['model'] as String?,
    mainPath: j['mainPath']! as String,
    subPath: j['subPath'] as String?,
    roomId: j['roomId'] as String?,
  );
}
