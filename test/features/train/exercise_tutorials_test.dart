import 'dart:io';

import 'package:fitnessapp/features/train/data/exercise_tutorials.dart';
import 'package:fitnessapp/features/train/models/exercise.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses and sorts cues, skipping bad entries', () {
    final cues = parseCues([
      {'at': 2.0, 'text': 'B'},
      {'at': 0.5, 'text': 'A'},
      {'at': 'x', 'text': 'bad'},
      {'text': 'no time'},
    ]);
    expect([for (final c in cues) c.text], ['A', 'B']);
    expect(parseCues('not a list'), isEmpty);
  });

  test('cueAt follows the loop', () {
    const cues = [
      TutorialCue(at: 0.5, text: 'A'),
      TutorialCue(at: 2, text: 'B'),
    ];
    Duration s(double x) => Duration(milliseconds: (x * 1000).round());
    expect(cueAt(cues, s(0.1), loopSeconds: 4), isNull);
    expect(cueAt(cues, s(0.6), loopSeconds: 4)?.text, 'A');
    expect(cueAt(cues, s(3.0), loopSeconds: 4)?.text, 'B');
    // second loop, before the first cue: previous loop's last cue stays up
    expect(cueAt(cues, s(4.2), loopSeconds: 4)?.text, 'B');
    expect(cueAt(cues, s(4.6), loopSeconds: 4)?.text, 'A');
  });

  test('tutorial needs model, poster and animation', () {
    expect(ExerciseTutorial.fromJson(null), isNull);
    expect(ExerciseTutorial.fromJson({'model': 'm.glb'}), isNull);
    final t = ExerciseTutorial.fromJson({
      'model': 'https://x/m.glb',
      'poster': 'https://x/p.png',
      'animation': 'Lunge',
    })!;
    expect(t.loopSeconds, 5);
    expect(t.cues, isEmpty);
  });

  final with3d = [
    for (final e in Exercise.all)
      if (e.tutorial != null) e,
  ];

  test('catalog cues: 3-4 per 3D exercise, <= 40 chars, inside the loop', () {
    expect(with3d, isNotEmpty);
    for (final e in with3d) {
      final t = e.tutorial!;
      expect(t.cues.length, inInclusiveRange(3, 4), reason: e.id);
      expect(t.cues.first.text, startsWith('Target muscle'), reason: e.id);
      for (final c in t.cues) {
        expect(c.text.length, lessThanOrEqualTo(40), reason: c.text);
        expect(c.at, lessThan(t.loopSeconds), reason: c.text);
      }
    }
  });

  test('bundled media paths exist on disk', () {
    for (final e in Exercise.all) {
      for (final path in [e.imageUrl, e.tutorial?.model, e.tutorial?.poster]) {
        if (path == null || path.startsWith('http')) continue;
        expect(File(path).existsSync(), isTrue, reason: '${e.id}: $path');
      }
    }
  });
}
