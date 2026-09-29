import 'dart:collection';

import 'package:flutter/foundation.dart';

enum LogLevel { debug, info, warn, error }

@immutable
class LogRecord {
  const LogRecord(this.time, this.level, this.tag, this.message);
  final DateTime time;
  final LogLevel level;
  final String tag;

  /// Already redacted.
  final String message;

  @override
  String toString() =>
      '${time.toIso8601String()} ${level.name[0].toUpperCase()}/$tag: $message';
}

/// Replaces registered secret values with a placeholder. SecretStore registers every
/// value it reads or writes, so secrets cannot reach a log sink (CLAUDE.md rule 5).
class Redactor {
  static const placeholder = '‹redacted›';

  /// Values shorter than this are not registered: redacting "1" or "on" would wreck logs,
  /// and real secrets (Tuya keys, passwords, Hue usernames) are longer.
  static const minLength = 4;

  final _secrets = SplayTreeSet<String>(
    // Longest first, so a secret containing another is replaced whole.
    (a, b) => b.length != a.length ? b.length - a.length : a.compareTo(b),
  );

  void register(String secret) {
    if (secret.length >= minLength) _secrets.add(secret);
  }

  void unregister(String secret) => _secrets.remove(secret);

  String redact(String text) {
    var out = text;
    for (final s in _secrets) {
      if (out.contains(s)) out = out.replaceAll(s, placeholder);
    }
    return out;
  }
}

abstract interface class LogSink {
  void write(LogRecord record);
}

/// Prints via debugPrint (stripped of nothing: messages are already redacted).
class ConsoleSink implements LogSink {
  @override
  void write(LogRecord record) => debugPrint(record.toString());
}

/// Keeps the last [capacity] records for the diagnostics screen (T5.7).
class MemorySink implements LogSink {
  MemorySink({this.capacity = 500});
  final int capacity;
  final _records = ListQueue<LogRecord>();

  List<LogRecord> get records => List.unmodifiable(_records);

  @override
  void write(LogRecord record) {
    _records.addLast(record);
    while (_records.length > capacity) {
      _records.removeFirst();
    }
  }
}

class Logger {
  Logger({
    Redactor? redactor,
    List<LogSink>? sinks,
    this.minLevel = LogLevel.debug,
  }) : redactor = redactor ?? Redactor(),
       sinks = sinks ?? [ConsoleSink()];

  final Redactor redactor;
  final List<LogSink> sinks;
  LogLevel minLevel;

  DateTime Function() now = DateTime.now;

  void d(String tag, String message) => _log(LogLevel.debug, tag, message);
  void i(String tag, String message) => _log(LogLevel.info, tag, message);
  void w(String tag, String message, [Object? error, StackTrace? stack]) =>
      _log(LogLevel.warn, tag, message, error, stack);
  void e(String tag, String message, [Object? error, StackTrace? stack]) =>
      _log(LogLevel.error, tag, message, error, stack);

  void _log(
    LogLevel level,
    String tag,
    String message, [
    Object? error,
    StackTrace? stack,
  ]) {
    if (level.index < minLevel.index) return;
    final text = StringBuffer(message);
    if (error != null) text.write(' | $error');
    if (stack != null) text.write('\n$stack');
    final record = LogRecord(
      now(),
      level,
      redactor.redact(tag),
      redactor.redact(text.toString()),
    );
    for (final sink in sinks) {
      sink.write(record);
    }
  }
}

/// App-wide logger. Bootstrap replaces it with one sharing SecretStore's redactor.
Logger log = Logger();
