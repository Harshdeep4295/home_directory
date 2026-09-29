import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:offline_home/core/intent.dart';
import 'package:offline_home/core/models.dart';
import 'package:offline_home/voice/fuzzy.dart';
import 'package:offline_home/voice/intent_parser.dart';
import 'package:offline_home/voice/lexicon.dart';
import 'package:offline_home/voice/target_resolver.dart';

Device dev(
  String id,
  String name, {
  String? room,
  List<String> aliases = const [],
  Set<Capability>? caps,
  Brand brand = Brand.tuya,
}) => Device(
  id: id,
  brand: brand,
  protocol: 'x',
  ip: '1.1.1.1',
  name: name,
  roomId: room,
  aliases: aliases,
  capabilities: caps ?? {Capability.power},
  lastSeen: DateTime.utc(2026),
);

void main() {
  final lex = Lexicon.fromYaml([
    for (final p in Lexicon.assetPaths) File(p).readAsStringSync(),
  ]);
  final resolver = TargetResolver(lex);
  final parser = IntentParser(lex);
  final rooms = const [
    Room(id: 'bed', name: 'Bedroom'),
    Room(id: 'hall', name: 'Hall'),
    Room(id: 'kit', name: 'Kitchen'),
    Room(id: 'bath', name: 'Bathroom'),
  ];
  final devices = [
    dev('geyser', 'Geyser', room: 'bath', aliases: ['water heater']),
    dev('bedlight', 'Bedroom Light', room: 'bed', aliases: ['batti']),
    dev('bedfan', 'Bedroom Fan', room: 'bed', aliases: ['pankha']),
    dev(
      'lamp',
      'Reading Lamp',
      room: 'bed',
      brand: Brand.wiz,
      caps: {Capability.power, Capability.brightness},
    ),
    dev('halllight', 'Hall Light', room: 'hall'),
    dev('kitlight', 'Kitchen Light', room: 'kit'),
    dev('ac', 'AC', room: 'hall'),
    dev('tv', 'TV', room: 'hall'),
  ];

  List<String> ids(String utterance) {
    final intent = parser.parse(utterance, now: DateTime(2026, 9, 29, 20));
    final span = switch (intent) {
      PowerIntent(:final targets) ||
      PowerForIntent(:final targets) ||
      PowerAfterIntent(:final targets) ||
      PowerAtIntent(:final targets) ||
      PowerUntilIntent(:final targets) ||
      CancelTimerIntent(:final targets) ||
      StatusIntent(:final targets) => targets,
      UnknownIntent() => throw StateError('unknown: $utterance'),
    };
    return resolver
        .resolve(span, devices: devices, rooms: rooms)
        .devices
        .map((d) => d.id)
        .toList()
      ..sort();
  }

  group('end to end: utterance → device ids', () {
    final cases = <String, List<String>>{
      'turn on the geyser': ['geyser'],
      'geezer on karo': ['geyser'],
      'water heater off': ['geyser'],
      'bedroom light off': ['bedlight'],
      // singular → the device named so (plural "lights" would mean all of them)
      'bedroom ki batti band karo': ['bedlight'],
      'turn off all lights except bedroom': ['halllight', 'kitlight'],
      'sab batti band karo bedroom ke alawa': ['halllight', 'kitlight'],
      'bedroom ki lights band karo': ['bedlight', 'lamp'],
      'bedroom band karo': ['bedfan', 'bedlight', 'lamp'],
      'sab band karo': [
        'ac',
        'bedfan',
        'bedlight',
        'geyser',
        'halllight',
        'kitlight',
        'lamp',
        'tv',
      ],
      'pankha chala do': ['bedfan'],
      'ac band karo': ['ac'],
      'reading lamp on': ['lamp'],
      'turn off all lights except the kitchen light': [
        'bedlight',
        'halllight',
        'lamp',
      ],
    };
    cases.forEach((u, want) => test(u, () => expect(ids(u), want)));
  });

  test('ambiguous → chips, not a guess', () {
    final r = resolver.resolve(
      const TargetSpan(words: ['light']),
      devices: devices,
      rooms: rooms,
    );
    expect(r.ambiguous, isTrue);
    expect(r.devices, isEmpty);
    expect(r.choices.length, greaterThanOrEqualTo(2));
  });

  test('nothing close → empty', () {
    final r = resolver.resolve(
      const TargetSpan(words: ['microwave']),
      devices: devices,
      rooms: rooms,
    );
    expect(r.isEmpty, isTrue);
  });

  test('fuzzy helpers', () {
    expect(Fuzzy.jaroWinkler('martha', 'marhta'), closeTo(0.961, 0.001));
    expect(Fuzzy.jaroWinkler('geyser', 'geyser'), 1);
    expect(Fuzzy.phoneticKey('geezer'), Fuzzy.phoneticKey('gizer'));
    expect(Fuzzy.phoneticKey('batti'), Fuzzy.phoneticKey('bati'));
    expect(Fuzzy.phoneticKey('pankha'), Fuzzy.phoneticKey('panka'));
    expect(Fuzzy.phoneticKey('fan'), isNot(Fuzzy.phoneticKey('pan')));
  });
}
