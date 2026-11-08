import 'package:fitnessapp/core/providers/demo_mode_provider.dart';
import 'package:fitnessapp/features/progress/logic/calories.dart';
import 'package:fitnessapp/features/progress/logic/streak.dart';
import 'package:fitnessapp/features/progress/models/session_record.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SessionRecord.fromSupabaseRow', () {
    final row = {
      'exercise_type': 'Squat',
      'created_at': '2026-11-01T10:00:00',
      'session_data': [
        {'reps': 10, 'form_score': 0.8, 'set_duration_ms': 30000},
        {'reps': 8, 'form_score': 0.6, 'set_duration_ms': 30000},
      ],
    };

    test('reads sets, totals and the catalog exercise', () {
      final r = SessionRecord.fromSupabaseRow(row);
      expect(r.date, DateTime(2026, 11, 1, 10));
      expect(r.exercise?.id, 'squat');
      expect(r.totalReps, 18);
      expect(r.avgFormPct, 70);
      expect(r.activeDuration, const Duration(minutes: 1));
    });

    test('calories use MET × kg × hours', () {
      final r = SessionRecord.fromSupabaseRow(row);
      // 3.5 MET × 60 kg × (1/60) h = 3.5 kcal
      expect(r.calories(60), closeTo(3.5, 1e-9));
    });

    test('unknown exercise keeps the name but has no calories', () {
      final r = SessionRecord.fromSupabaseRow({...row, 'exercise_type': 'Yoga'});
      expect(r.exerciseName, 'Yoga');
      expect(r.exercise, isNull);
      expect(r.calories(60), isNull);
    });

    test('missing session_data gives an empty session', () {
      final r = SessionRecord.fromSupabaseRow({'exercise_type': 'Squat'});
      expect(r.sets, isEmpty);
      expect(r.date, isNull);
      expect(r.avgFormPct, 0);
    });
  });

  group('SessionRecord.fromLocalHistory', () {
    test('parses dated entry', () {
      final r = SessionRecord.fromLocalHistory(
        '2026-11-01T09:00:00.000|Bicep Curl — '
        'Set 1: 12 reps, form 90%, fatigue Low, TUT 4.0s, ROM 80%, endurance 70% | '
        'Set 2: 10 reps, form 70%, fatigue Moderate, TUT 3.0s, ROM 75%, endurance 60%',
      );
      expect(r.date, DateTime(2026, 11, 1, 9));
      expect(r.exercise?.id, 'bicep_curl');
      expect(r.totalReps, 22);
      expect(r.avgFormPct, 80);
      expect(r.calories(70), isNull, reason: 'no duration in local history');
    });

    test('legacy entry without date', () {
      final r = SessionRecord.fromLocalHistory(
        'Squat — Set 1: 5 reps, form 50%, fatigue Low',
      );
      expect(r.date, isNull);
      expect(r.exerciseName, 'Squat');
      expect(r.totalReps, 5);
    });
  });

  test('offline demo history parses and keeps a streak through today', () {
    final now = DateTime(2026, 11, 5, 20);
    final records = demoHistory(now).map(SessionRecord.fromLocalHistory).toList();
    expect(records, hasLength(10));
    expect(records.every((r) => r.exercise != null && r.totalReps > 0), isTrue);
    expect(currentStreak(records.map((r) => r.date!), now), 3);
  });

  test('caloriesBurned', () {
    expect(
      caloriesBurned(met: 8, weightKg: 75, active: const Duration(minutes: 30)),
      300,
    );
  });

  group('currentStreak', () {
    final now = DateTime(2026, 11, 5, 20);

    test('counts back from today', () {
      final dates = [DateTime(2026, 11, 5, 8), DateTime(2026, 11, 4), DateTime(2026, 11, 3)];
      expect(currentStreak(dates, now), 3);
    });

    test('nothing today still counts yesterday run', () {
      expect(currentStreak([DateTime(2026, 11, 4), DateTime(2026, 11, 3)], now), 2);
    });

    test('gap breaks it', () {
      expect(currentStreak([DateTime(2026, 11, 3)], now), 0);
    });
  });
}
