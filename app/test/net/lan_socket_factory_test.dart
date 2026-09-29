import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:offline_home/core/result.dart';
import 'package:offline_home/net/lan_socket_factory.dart';

import '../support/fake_platform.dart';

const loopback = '127.0.0.1';

Future<RawDatagramSocket> udpEcho({int copies = 1, bool silent = false}) async {
  final s = await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);
  s.listen((e) {
    if (e != RawSocketEvent.read) return;
    final dg = s.receive();
    if (dg == null || silent) return;
    for (var i = 0; i < copies; i++) {
      s.send([...dg.data, i], dg.address, dg.port);
    }
  });
  return s;
}

void main() {
  late FakePlatformBridge platform;
  late LanSocketFactory f;

  setUp(() {
    platform = FakePlatformBridge();
    f = LanSocketFactory(platform);
  });
  tearDown(() => platform.dispose());

  group('tcp', () {
    test('connects to an echo server', () async {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((c) => c.listen(c.add, onDone: c.close));
      final r = await f.tcp(loopback, server.port);
      final s = r.valueOrNull!;
      s.add(utf8.encode('ping'));
      expect(utf8.decode(await s.first), 'ping');
      await s.close();
      await server.close();
    });

    test('closed port → refused', () async {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final port = server.port;
      await server.close();
      final r = await f.tcp(loopback, port);
      expect(r.errorOrNull?.kind, DeviceErrorKind.refused);
    });
  });

  group('udpRequest', () {
    test('first reply', () async {
      final echo = await udpEcho();
      final r = await f.udpRequest(loopback, echo.port, [1, 2]);
      expect(r.valueOrNull!.single.data, [1, 2, 0]);
      echo.close();
    });

    test('no reply → timeout within timeout + margin', () async {
      final silent = await udpEcho(silent: true);
      final sw = Stopwatch()..start();
      final r = await f.udpRequest(loopback, silent.port, [
        1,
      ], timeout: const Duration(milliseconds: 300));
      expect(r.errorOrNull?.kind, DeviceErrorKind.timeout);
      expect(sw.elapsedMilliseconds, lessThan(300 + 200));
      silent.close();
    });

    test('expectMany collects all replies; empty is Ok', () async {
      final echo = await udpEcho(copies: 3);
      final r = await f.udpRequest(
        loopback,
        echo.port,
        [9],
        timeout: const Duration(milliseconds: 300),
        expectMany: true,
      );
      expect(r.valueOrNull!.map((x) => x.data.last), [0, 1, 2]);
      echo.close();

      final silent = await udpEcho(silent: true);
      final none = await f.udpRequest(
        loopback,
        silent.port,
        [9],
        timeout: const Duration(milliseconds: 100),
        expectMany: true,
      );
      expect(none.valueOrNull, isEmpty);
      silent.close();
    });

    test('non-IP host → protocol error, no throw', () async {
      final r = await f.udpRequest('not-an-ip', 1, [0]);
      expect(r.errorOrNull?.kind, DeviceErrorKind.protocol);
    });
  });

  group('broadcast', () {
    test('unsupported when platform cannot broadcast (iOS)', () async {
      platform.canBroadcast = false;
      final r = await f.broadcast(38899, [0]);
      expect(r.errorOrNull?.kind, DeviceErrorKind.unsupported);
      expect(platform.lockAcquisitions, 0);
    });

    test('collects replies in window and releases multicast lock', () async {
      final echo = await udpEcho(copies: 2);
      final r = await f.broadcast(
        echo.port,
        [7],
        window: const Duration(milliseconds: 300),
        broadcastAddress: loopback,
      );
      expect(r.valueOrNull, hasLength(2));
      expect(platform.lockAcquisitions, 1);
      expect(platform.locksHeld, 0);
      echo.close();
    });
  });

  group('http', () {
    late HttpServer server;
    setUp(() async {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((req) async {
        switch (req.uri.path) {
          case '/shelly':
            req.response.headers.contentType = ContentType.json;
            req.response.write('{"gen":2}');
          case '/echo':
            req.response.add(
              await req.fold<List<int>>([], (a, b) => a..addAll(b)),
            );
          case '/hang':
            await Future<void>.delayed(const Duration(seconds: 3));
          default:
            req.response.statusCode = 404;
        }
        await req.response.close();
      });
    });
    tearDown(() => server.close(force: true));

    Uri u(String path) => Uri.parse('http://$loopback:${server.port}$path');

    test('GET json', () async {
      final r = (await f.http('GET', u('/shelly'))).valueOrNull!;
      expect(r.status, 200);
      expect(r.headers['content-type'], contains('application/json'));
      expect(r.json, {'gen': 2});
    });

    test('POST body round-trip and non-200 is Ok with status', () async {
      final r = (await f.http(
        'POST',
        u('/echo'),
        body: [1, 2, 3],
      )).valueOrNull!;
      expect(r.body, [1, 2, 3]);
      final nf = (await f.http('GET', u('/nope'))).valueOrNull!;
      expect(nf.status, 404);
    });

    test('hanging server → timeout', () async {
      final r = await f.http(
        'GET',
        u('/hang'),
        timeout: const Duration(milliseconds: 300),
      );
      expect(r.errorOrNull?.kind, DeviceErrorKind.timeout);
    });

    test('closed port → refused', () async {
      final tmp = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final port = tmp.port;
      await tmp.close();
      final r = await f.http('GET', Uri.parse('http://$loopback:$port/'));
      expect(r.errorOrNull?.kind, DeviceErrorKind.refused);
    });
  });
}
