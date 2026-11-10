import 'package:fitnessapp/features/progress/logic/progress_stats.dart';
import 'package:fitnessapp/features/progress/logic/streak.dart';
import 'package:fitnessapp/features/progress/models/session_record.dart';
import 'package:flutter_test/flutter_test.dart';

SessionRecord _s(
  String name,
  DateTime? date,
  List<(int, double)> sets, {
  int durationMs = 0,
}) => SessionRecord(
  date: date,
  exerciseName: name,
  sets: [
    for (final (reps, form) in sets)
      SetRecord(reps: reps, formScore: form, durationMs: durationMs),
  ],
);

void main() {
  final now = DateTime(2026, 11, 9, 20);
  DateTime daysAgo(int d) => DateTime(2026, 11, 9 - d, 8);

  group('weekStats', () {
    test('counts the last 7 days only', () {
      final w = weekStats([
        _s('Squat', daysAgo(0), [(10, 0.8), (8, 0.6)]),
        _s('Squat', daysAgo(6), [(10, 1.0)]),
        _s('Squat', daysAgo(7), [(50, 0.0)]),
        _s('Squat', null, [(50, 0.0)]),
      ], now, 70);
      expect(w.sessions, 2);
      expect(w.reps, 28);
      expect(w.avgFormPct, 80);
      expect(w.kcal, isNull, reason: 'no durations recorded');
    });

    test('kcal sums sessions that have durations', () {
      // 3.5 MET × 60 kg × (1/60) h = 3.5 kcal per minute-long session
      final w = weekStats([
        _s('Squat', daysAgo(1), [(10, 0.8)], durationMs: 60000),
        _s('Squat', daysAgo(2), [(10, 0.8)], durationMs: 60000),
      ], now, 60);
      expect(w.kcal, closeTo(7.0, 1e-9));
      expect(w.activeTime, const Duration(minutes: 2));
    });

    test('empty week', () {
      final w = weekStats(const [], now, 70);
      expect(w.sessions, 0);
      expect(w.avgFormPct, isNull);
    });
  });

  test('formTrend keeps the last n dated sessions, oldest first', () {
    final records = [
      for (var d = 12; d >= 0; d--) _s('Squat', daysAgo(d), [(10, 0.5)]),
      _s('Squat', null, [(10, 0.5)]),
    ];
    final t = formTrend(records, count: 10);
    expect(t, hasLength(10));
    expect(t.first.date, daysAgo(9));
    expect(t.last.date, daysAgo(0));
  });

  test('personalRecords finds best set, best session and longest streak', () {
    final prs = personalRecords([
      _s('Squat', daysAgo(10), [(12, 0.5)]),
      _s('Squat', daysAgo(9), [(8, 0.9), (8, 0.9)]),
      _s('Bicep Curl', daysAgo(8), [(10, 0.6)]),
      _s('Squat', daysAgo(2), [(9, 0.7)]),
    ]);
    expect(prs.mostRepsInSet!.value, 12);
    expect(prs.mostRepsInSet!.date, daysAgo(10));
    expect(prs.bestFormSession!.value, 90);
    expect(prs.longestStreakDays, 3);
  });

  test('exerciseBreakdown groups the last 30 days, most sessions first', () {
    final b = exerciseBreakdown([
      _s('Bicep Curl', daysAgo(1), [(10, 0.6)]),
      _s('Squat', daysAgo(2), [(10, 0.8)]),
      _s('Squat', daysAgo(3), [(6, 0.6)]),
      _s('Squat', daysAgo(40), [(99, 0.1)]),
    ], now);
    expect(b.map((e) => e.exerciseName), ['Squat', 'Bicep Curl']);
    expect(b.first.sessions, 2);
    expect(b.first.reps, 16);
    expect(b.first.avgFormPct, 70);
  });

  group('longestStreak', () {
    test('finds the longest run, not the latest', () {
      expect(
        longestStreak([
          DateTime(2026, 10, 1),
          DateTime(2026, 10, 2),
          DateTime(2026, 10, 3),
          DateTime(2026, 10, 10),
          DateTime(2026, 10, 11),
        ]),
        3,
      );
    });

    test('same-day sessions count once, across a month boundary', () {
      expect(
        longestStreak([
          DateTime(2026, 10, 31, 8),
          DateTime(2026, 10, 31, 19),
          DateTime(2026, 11, 1),
        ]),
        2,
      );
    });

    test('empty is 0', () => expect(longestStreak(const []), 0));
  });
}
