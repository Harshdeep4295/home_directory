import 'package:flutter_test/flutter_test.dart';
import 'package:offline_home/core/log.dart';

void main() {
  late Redactor redactor;
  late MemorySink sink;
  late Logger logger;

  setUp(() {
    redactor = Redactor();
    sink = MemorySink();
    logger = Logger(redactor: redactor, sinks: [sink]);
  });

  String all() => sink.records.map((r) => r.toString()).join('\n');

  test('registered secrets never appear in message, error, stack or tag', () {
    const key = '0123456789abcdef';
    const password = 'hunter2hunter2';
    redactor
      ..register(key)
      ..register(password);

    logger
      ..d('tuya', 'connecting with key $key')
      ..i('tag-$key', 'x')
      ..w('klap', 'handshake failed', Exception('bad password $password'))
      ..e('tuya', 'boom', StateError(key), StackTrace.fromString('at $key'));

    final out = all();
    expect(out, isNot(contains(key)));
    expect(out, isNot(contains(password)));
    expect(out, contains(Redactor.placeholder));
    expect(sink.records, hasLength(4));
  });

  test('longest secret is redacted whole when one contains another', () {
    redactor
      ..register('abcd')
      ..register('abcdefgh');
    logger.i('t', 'v=abcdefgh');
    expect(sink.records.single.message, 'v=${Redactor.placeholder}');
  });

  test('short values are not registered', () {
    redactor.register('on');
    logger.i('t', 'turned on');
    expect(sink.records.single.message, 'turned on');
  });

  test('unregister stops redaction', () {
    redactor
      ..register('secretvalue')
      ..unregister('secretvalue');
    logger.i('t', 'secretvalue');
    expect(sink.records.single.message, 'secretvalue');
  });

  test('minLevel filters and memory sink is bounded', () {
    final small = MemorySink(capacity: 3);
    final l = Logger(sinks: [small], minLevel: LogLevel.info);
    l.d('t', 'dropped');
    for (var i = 0; i < 5; i++) {
      l.i('t', 'm$i');
    }
    expect(small.records.map((r) => r.message), ['m2', 'm3', 'm4']);
  });
}
