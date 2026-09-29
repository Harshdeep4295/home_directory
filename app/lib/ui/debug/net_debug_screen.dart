import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/result.dart';
import '../../net/android_platform_bridge.dart';
import '../../net/lan_socket_factory.dart';
import '../../net/platform_bridge.dart';

PlatformBridge platformBridgeForHost() =>
    Platform.isAndroid ? AndroidPlatformBridge() : DefaultPlatformBridge();

/// Developer screen for the T1.4/T1.5 hardware checks: shows what the platform plugin
/// reports and sends a WiZ getPilot to any IP:port over the bound Wi-Fi network.
class NetDebugScreen extends StatefulWidget {
  const NetDebugScreen({super.key, required this.platform});
  final PlatformBridge platform;

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

  @override
  void initState() {
    super.initState();
    _sub = widget.platform.changes.listen((n) => setState(() => _net = n));
    unawaited(_refresh());
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
          IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Wi-Fi: ${_net.wifi ? 'connected' : 'NOT connected'}\n'
            'Internet on Wi-Fi: ${_net.internet ? 'yes' : 'no (local mode)'}\n'
            'IP: ${_net.ip ?? '-'}/${_net.prefix ?? '-'}\n'
            'SSID: ${_net.ssid ?? '(hidden: needs location permission)'}',
            style: style,
          ),
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
