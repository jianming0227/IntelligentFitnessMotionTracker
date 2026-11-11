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
Map<String, dynamic> _lunge({Map<String, dynamic> override = const {}}) => {
  'id': 'lunge',
  'name': 'Lunge',
  'category': 'legs',
  'sort_order': 30,
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
      'https://example.supabase.co/storage/v1/object/public/exercise-media/lunge.png',
  ...override,
};

void main() {
  final bundled =
      jsonDecode(File(ExerciseCatalog.bundledAsset).readAsStringSync()) as List;

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
    final list = ExerciseCatalog.parse([...bundled, _lunge()]);
    expect(list.map((e) => e.id), ['squat', 'bicep_curl', 'lunge']);
    final lunge = list.last;
    expect(lunge.primaryMuscles, [Muscle.quads, Muscle.glutes]);
    expect(lunge.minRepDurationMs, 700, reason: 'column default');
    expect(lunge.tutorial, isNull);
  });

  test('bad and inactive rows are skipped, the rest still load', () {
    final list = ExerciseCatalog.parse([
      ...bundled,
      _lunge(
        override: {
          'id': 'two',
          'joints': ['hip', 'knee'],
        },
      ),
      _lunge(
        override: {
          'id': 'nose',
          'joints': ['nose', 'knee', 'ankle'],
        },
      ),
      _lunge(override: {'id': 'dir', 'angle_at_bottom': 'sideways'}),
      _lunge(override: {'id': 'nan', 'rep_top_angle': 'high'}),
      _lunge(override: {'id': 'off', 'is_active': false}),
      'not a row',
    ]);
    expect(list.map((e) => e.id), ['squat', 'bicep_curl']);
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

    final small = Exercise.fromJson(_lunge());
    final large = Exercise.fromJson(
      _lunge(
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

  test('migration seeds the same exercises the app bundles', () {
    final sql = File(
      'supabase/migrations/20261112000000_exercises.sql',
    ).readAsStringSync();
    for (final row in bundled.cast<Map>()) {
      expect(sql, contains("'${row['id']}', '${row['name']}'"));
    }
  });
}
