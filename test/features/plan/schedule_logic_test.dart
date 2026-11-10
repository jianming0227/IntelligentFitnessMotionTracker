import 'package:fitnessapp/features/plan/logic/schedule_logic.dart';
import 'package:fitnessapp/features/progress/models/session_record.dart';
import 'package:flutter_test/flutter_test.dart';

SessionRecord _s(
  DateTime? date, {
  int durationMs = 60000,
  bool empty = false,
}) => SessionRecord(
  date: date,
  exerciseName: 'Squat',
  sets: empty
      ? const []
      : [SetRecord(reps: 10, formScore: 0.8, durationMs: durationMs)],
);

void main() {
  final now = DateTime(2026, 11, 10, 20);

  group('monthStats', () {
    test('counts distinct days and kcal inside the month only', () {
      final m = monthStats(
        [
          _s(DateTime(2026, 11, 2, 8)),
          _s(DateTime(2026, 11, 2, 19)), // same day, counted once
          _s(DateTime(2026, 11, 5, 8), durationMs: 0), // no duration: 0 kcal
          _s(DateTime(2026, 10, 31, 8)), // other month
          _s(null),
          _s(DateTime(2026, 11, 6), empty: true),
        ],
        DateTime(2026, 11),
        60,
      );
      expect(m.daysCompleted, 2);
      // 3.5 MET × 60 kg × (1/60) h = 3.5 kcal per minute-long session, ×2
      expect(m.kcal, closeTo(7.0, 1e-9));
    });

    test('empty month', () {
      final m = monthStats(const [], DateTime(2026, 11), 70);
      expect(m.daysCompleted, 0);
      expect(m.kcal, 0);
    });
  });

  test('trainedDays and sessionsOn match by calendar day', () {
    final records = [
      _s(DateTime(2026, 11, 9, 7)),
      _s(DateTime(2026, 11, 9, 21)),
      _s(DateTime(2026, 11, 8, 7)),
    ];
    expect(trainedDays(records), {
      DateTime(2026, 11, 9),
      DateTime(2026, 11, 8),
    });
    expect(sessionsOn(records, DateTime(2026, 11, 9, 12)), hasLength(2));
    expect(sessionsOn(records, DateTime(2026, 11, 10)), isEmpty);
  });

  test('planCardsOn picks cards dated on that day', () {
    final plan = {
      'sessions': [
        {'type': 'SessionCard', 'date': 'Wed, Nov 11', 'exercise': 'Squat'},
        {'type': 'SessionCard', 'date': 'Fri, Nov 13', 'exercise': 'Curl'},
        {'type': 'SessionCard', 'date': 'Mon', 'exercise': 'Bad date'},
      ],
    };
    final cards = planCardsOn(plan, DateTime(2026, 11, 11), now);
    expect(cards.map((c) => c['exercise']), ['Squat']);
    expect(planCardsOn(plan, DateTime(2026, 11, 12), now), isEmpty);
    expect(planCardsOn(const {}, DateTime(2026, 11, 11), now), isEmpty);
  });

  group('firstSentences', () {
    test('keeps the first two sentences', () {
      expect(
        firstSentences(
          'Form is 82%. Fatigue is low! Added one rep. Keep going.',
        ),
        'Form is 82%. Fatigue is low!',
      );
    });

    test('short text is unchanged', () {
      expect(firstSentences('One sentence only.'), 'One sentence only.');
      expect(firstSentences(''), '');
    });
  });
}
