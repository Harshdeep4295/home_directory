import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/result.dart';
import '../../net/ios_platform_bridge.dart';
import '../../net/lan_socket_factory.dart';
import '../../net/platform_bridge.dart';
import '../widgets/net_banner.dart';

/// Shown when iOS Local Network access is denied (T1.5; full screen in T5.8).
const localNetworkDeniedHelp =
    'Local Network access is off, so the app cannot see your devices.\n'
    'Open Settings → Privacy & Security → Local Network and turn on Offline Home, '
    'then come back to this screen.';

/// Developer screen for the T1.4/T1.5 hardware checks: shows what the platform plugin
/// reports and sends a WiZ getPilot to any IP:port over the bound Wi-Fi network.
class NetDebugScreen extends StatefulWidget {
  const NetDebugScreen({super.key, required this.platform, this.onOpenScan});
  final PlatformBridge platform;

  /// Opens the T2.10 scan + toggle screen (null in tests without services).
  final VoidCallback? onOpenScan;

  @override
  State<NetDebugScreen> createState() => _NetDebugScreenState();
}

class _NetDebugScreenState extends State<NetDebugScreen> {
  late final LanSocketFactory _sockets = LanSocketFactory(widget.platform);
  final _host = TextEditingController(text: '192.168.1.');
  final _port = TextEditingController(text: '38899');
  StreamSubscription<NetInfo>? _sub;
  NetInfo _net = NetInfo.unknown;
  String _result = '';
  bool _busy = false;
  LocalNetworkPermission? _permission;

  @override
  void initState() {
    super.initState();
    _sub = widget.platform.changes.listen((n) => setState(() => _net = n));
    unawaited(_refresh());
    final p = widget.platform;
    if (p is IosPlatformBridge) unawaited(_checkPermission(p));
  }

  Future<void> _checkPermission(IosPlatformBridge p) async {
    final r = await p.requestLocalNetworkPermission();
    if (mounted) setState(() => _permission = r);
  }

  Future<void> _refresh() async {
    final n = await widget.platform.netInfo();
    if (mounted) setState(() => _net = n);
  }

  Future<void> _probe() async {
    setState(() => _busy = true);
    final sw = Stopwatch()..start();
    final r = await _sockets.udpRequest(
      _host.text.trim(),
      int.tryParse(_port.text.trim()) ?? 38899,
      utf8.encode('{"method":"getPilot","params":{}}'),
    );
    final ms = sw.elapsedMilliseconds;
    setState(() {
      _busy = false;
      _result = switch (r) {
        Ok(:final value) =>
          'OK in $ms ms from ${value.first.address}\n'
              '${value.first.text}',
        Err(:final error) =>
          'FAILED in $ms ms: ${error.kind.name} ${error.message}',
      };
    });
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    _host.dispose();
    _port.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Network debug'),
        actions: [
          if (widget.onOpenScan != null)
            IconButton(
              tooltip: 'Scan + toggle',
              onPressed: widget.onOpenScan,
              icon: const Icon(Icons.radar),
            ),
          IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          NetBannerView(net: _net),
          Text(
            'Wi-Fi: ${_net.wifi ? 'connected' : 'NOT connected'}\n'
            'Internet on Wi-Fi: ${switch (_net.internet) {
              true => 'yes',
              false => 'no (local mode)',
              null => 'unknown',
            }}\n'
            'IP: ${_net.ip ?? '-'}/${_net.prefix ?? '-'}\n'
            'SSID: ${_net.ssid ?? '(hidden)'}'
            '${_permission == null ? '' : '\nLocal Network permission: ${_permission!.name}'}',
            style: style,
          ),
          if (_permission == LocalNetworkPermission.denied) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(localNetworkDeniedHelp, style: style),
              ),
            ),
          ],
          const Divider(height: 32),
          TextField(
            controller: _host,
            decoration: const InputDecoration(labelText: 'Target IP'),
            keyboardType: TextInputType.number,
          ),
          TextField(
            controller: _port,
            decoration: const InputDecoration(labelText: 'UDP port'),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _busy ? null : _probe,
            child: Text(_busy ? 'Probing…' : 'Send WiZ getPilot'),
          ),
          const SizedBox(height: 12),
          SelectableText(_result, style: style),
        ],
      ),
    );
  }
}
