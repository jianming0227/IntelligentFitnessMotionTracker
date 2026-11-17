import 'dart:convert';
import 'dart:io';

import 'package:fitnessapp/features/train/data/exercise_catalog.dart';
import 'package:fitnessapp/features/train/data/pose_joints.dart';
import 'package:fitnessapp/features/train/models/exercise.dart';
import 'package:fitnessapp/features/train/models/muscle.dart';
import 'package:fitnessapp/features/train/models/rep_state_machine.dart';
import 'package:fitnessapp/features/train/models/side_selector.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:flutter_test/flutter_test.dart';

/// A valid row for a made-up exercise, like one added in the dashboard.
Map<String, dynamic> _stepUp({Map<String, dynamic> override = const {}}) => {
  'id': 'step_up',
  'name': 'Step Up',
  'category': 'legs',
  'sort_order': 999,
  'is_active': true,
  'joints': ['hip', 'knee', 'ankle'],
  'angle_at_bottom': 'small',
  'target_angle_min': 80,
  'target_angle_max': 110,
  'rep_bottom_angle': 100,
  'rep_top_angle': 160,
  'rom_full_span_deg': 80,
  'form_cues': ['Front knee over ankle'],
  'primary_muscles': ['quads', 'glutes', 'notAMuscle'],
  'image_url':
      'https://example.supabase.co/storage/v1/object/public/exercise-media/step_up.png',
  ...override,
};

void main() {
  final bundled =
      jsonDecode(File(ExerciseCatalog.bundledAsset).readAsStringSync()) as List;
  final bundledIds = [for (final r in bundled.cast<Map>()) r['id'] as String];

  test('bundled copy loads Squat and Bicep Curl with the old values', () {
    final squat = Exercise.byId('squat')!;
    expect(squat.name, 'Squat');
    expect(squat.joints, ['hip', 'knee', 'ankle']);
    expect(squat.angleAtBottom, AngleAtBottom.small);
    expect(squat.repBottomAngleStrict, 95);
    expect(squat.repTopAngleStrict, 168);
    expect(squat.minRepDurationMs, 800);
    expect(squat.primaryMuscles, [Muscle.quads, Muscle.glutes]);

    final curl = Exercise.byName('bicep curl')!;
    expect(curl.joints, ['shoulder', 'elbow', 'wrist']);
    expect(curl.angleAtBottom, AngleAtBottom.large);
    expect(curl.repBottomAngleStrict, 162);
    expect(curl.formCues, contains('Keep your elbow still'));
    expect(curl.tutorial?.cues, hasLength(4));
  });

  test('a new row joins the catalog, sorted, with unknown muscles skipped', () {
    final list = ExerciseCatalog.parse([...bundled, _stepUp()]);
    expect(list.map((e) => e.id), [...bundledIds, 'step_up']);
    final stepUp = list.last;
    expect(stepUp.primaryMuscles, [Muscle.quads, Muscle.glutes]);
    expect(stepUp.minRepDurationMs, 700, reason: 'column default');
    expect(stepUp.tutorial, isNull);
  });

  group('new exercises (F4)', () {
    final start = DateTime(2026);
    int reps(String id, List<double> angles) {
      final m = RepStateMachine(exercise: Exercise.byId(id)!);
      var n = 0;
      for (final (i, a) in angles.indexed) {
        if (m.feed(a, start.add(Duration(seconds: i)))) n++;
      }
      return n;
    }

    test('catalog order and body-map muscles', () {
      expect(bundledIds, [
        'squat',
        'bicep_curl',
        'lunge',
        'shoulder_press',
        'lateral_raise',
      ]);
      expect(Exercise.byId('shoulder_press')!.primaryMuscles, [
        Muscle.shoulders,
      ]);
      expect(Exercise.byId('lateral_raise')!.secondaryMuscles, [Muscle.back]);
      expect(Exercise.byId('lunge')!.secondaryMuscles, hasLength(3));
    });

    test('full reps count, half reps do not', () {
      // Lunge knee: standing ~175°, bottom ~92°.
      expect(reps('lunge', [175, 95, 175, 92, 172]), 2);
      expect(reps('lunge', [175, 120, 175]), 0, reason: 'too shallow');
      // Shoulder press elbow: ~90° at the shoulders, ~165° locked out.
      expect(reps('shoulder_press', [165, 90, 165, 88, 168]), 2);
      expect(
        reps('shoulder_press', [165, 90, 140, 90]),
        0,
        reason: 'no lockout',
      );
      // Lateral raise shoulder: ~20° by the sides, ~88° at shoulder height.
      expect(reps('lateral_raise', [80, 20, 85, 20, 88]), 2);
      expect(reps('lateral_raise', [80, 20, 60, 20]), 0, reason: 'too low');
    });

    test('new exercises have a photo and a 3D demo', () {
      for (final id in ['lunge', 'shoulder_press', 'lateral_raise']) {
        expect(
          Exercise.byId(id)!.imageUrl,
          startsWith('assets/images/'),
          reason: id,
        );
        expect(Exercise.byId(id)!.tutorial, isNotNull, reason: id);
      }
    });
  });

  test('bad and inactive rows are skipped, the rest still load', () {
    final list = ExerciseCatalog.parse([
      ...bundled,
      _stepUp(
        override: {
          'id': 'two',
          'joints': ['hip', 'knee'],
        },
      ),
      _stepUp(
        override: {
          'id': 'nose',
          'joints': ['nose', 'knee', 'ankle'],
        },
      ),
      _stepUp(override: {'id': 'dir', 'angle_at_bottom': 'sideways'}),
      _stepUp(override: {'id': 'nan', 'rep_top_angle': 'high'}),
      _stepUp(override: {'id': 'off', 'is_active': false}),
      'not a row',
    ]);
    expect(list.map((e) => e.id), bundledIds);
  });

  test('joint names map to left/right ML Kit landmarks', () {
    expect(landmarksFor(['hip', 'knee', 'ankle'], BodySide.left), [
      PoseLandmarkType.leftHip,
      PoseLandmarkType.leftKnee,
      PoseLandmarkType.leftAnkle,
    ]);
    // Every joint the catalog accepts exists in ML Kit on both sides.
    for (final side in BodySide.values) {
      expect(landmarksFor(trackableJoints.toList(), side), hasLength(8));
    }
  });

  test('rep direction comes from the row', () {
    final start = DateTime(2026);
    int count(Exercise e, List<double> angles) {
      final m = RepStateMachine(exercise: e);
      var reps = 0;
      for (final (i, a) in angles.indexed) {
        if (m.feed(a, start.add(Duration(seconds: i)))) reps++;
      }
      return reps;
    }

    final small = Exercise.fromJson(_stepUp());
    final large = Exercise.fromJson(
      _stepUp(
        override: {
          'angle_at_bottom': 'large',
          'rep_bottom_angle': 160,
          'rep_top_angle': 50,
        },
      ),
    );
    expect(count(small, [170, 90, 170, 90, 170]), 2);
    expect(count(large, [170, 90, 170, 40, 170, 40]), 2);
    expect(count(large, [90, 170, 90, 170]), 0, reason: 'wrong direction');
  });

  test('migrations seed the same exercises the app bundles', () {
    // Every bundled exercise must also be inserted by some migration.
    final sql = [
      for (final f in Directory('supabase/migrations').listSync())
        if (f is File && f.path.endsWith('.sql')) f.readAsStringSync(),
    ].join('\n');
    for (final row in bundled.cast<Map>()) {
      expect(sql, contains("'${row['id']}', '${row['name']}'"));
    }
  });
}
