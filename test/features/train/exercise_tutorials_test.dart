import 'dart:convert';
import 'dart:io';

import 'package:fitnessapp/features/train/data/exercise_tutorials.dart';
import 'package:fitnessapp/features/train/models/exercise.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses and sorts cues, skipping bad entries', () {
    final cues = parseTutorialCues(jsonEncode({
      'bicep_curl': [
        {'at': 2.0, 'text': 'B'},
        {'at': 0.5, 'text': 'A'},
        {'at': 'x', 'text': 'bad'},
        {'text': 'no time'},
      ],
      'oops': 'not a list',
    }));
    expect([for (final c in cues['bicep_curl']!) c.text], ['A', 'B']);
    expect(cues.containsKey('oops'), isFalse);
  });

  test('cueAt follows the loop', () {
    const cues = [TutorialCue(at: 0.5, text: 'A'), TutorialCue(at: 2, text: 'B')];
    Duration s(double x) => Duration(milliseconds: (x * 1000).round());
    expect(cueAt(cues, s(0.1), loopSeconds: 4), isNull);
    expect(cueAt(cues, s(0.6), loopSeconds: 4)?.text, 'A');
    expect(cueAt(cues, s(3.0), loopSeconds: 4)?.text, 'B');
    // second loop, before the first cue: previous loop's last cue stays up
    expect(cueAt(cues, s(4.2), loopSeconds: 4)?.text, 'B');
    expect(cueAt(cues, s(4.6), loopSeconds: 4)?.text, 'A');
  });

  test('shipped cue file: 3-4 cues per 3D exercise, <= 40 chars, inside the loop', () {
    final cues = parseTutorialCues(
      File('assets/tutorials/tutorial_cues.json').readAsStringSync(),
    );
    for (final MapEntry(key: id, value: t) in exerciseTutorials.entries) {
      expect(cues[id]!.length, inInclusiveRange(3, 4), reason: id);
      expect(cues[id]!.first.text, startsWith('Target muscle'), reason: id);
      for (final c in cues[id]!) {
        expect(c.text.length, lessThanOrEqualTo(40), reason: c.text);
        expect(c.at, lessThan(t.loopSeconds), reason: c.text);
      }
    }
  });

  test('every 3D tutorial is a real exercise with its files on disk', () {
    final ids = {for (final e in Exercise.all) e.id};
    for (final MapEntry(key: id, value: t) in exerciseTutorials.entries) {
      expect(ids, contains(id));
      expect(File(t.model).existsSync(), isTrue, reason: t.model);
      expect(File(t.poster).existsSync(), isTrue, reason: t.poster);
    }
  });
}
