import 'package:fitnessapp/features/progress/logic/mascot_mood.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _plan(List<(String date, String action, String exercise)> days) => {
  'type': 'WorkoutPlanView',
  'sessions': [
    for (final (i, (date, action, exercise)) in days.indexed)
      {
        'type': 'SessionCard',
        'day': 'Day ${i + 1}',
        'date': date,
        'exercise': exercise,
        'actionId': action,
      },
  ],
};

void main() {
  // Monday 9 Nov 2026, evening.
  final now = DateTime(2026, 11, 9, 20);
  DateTime d(int month, int day, [int hour = 8]) => DateTime(2026, month, day, hour);

  group('parsePlanDate', () {
    test('parses the plan format', () {
      expect(parsePlanDate('Wed, Jun 3', DateTime(2026, 6, 1)), DateTime(2026, 6, 3));
    });
    test('rolls over the new year', () {
      expect(parsePlanDate('Thu, Jan 1', DateTime(2026, 12, 30)), DateTime(2027, 1, 1));
      expect(parsePlanDate('Tue, Dec 30', DateTime(2027, 1, 2)), DateTime(2026, 12, 30));
    });
    test('null on junk', () {
      expect(parsePlanDate('Someday', now), isNull);
      expect(parsePlanDate('Mon, Foo 3', now), isNull);
    });
  });

  group('planDays', () {
    test('marks Active Recovery and missing actionId as rest', () {
      final days = planDays(_plan([
        ('Tue, Nov 10', 'start_squat', 'Squat'),
        ('Wed, Nov 11', '', 'Active Recovery'),
        ('Thu, Nov 12', 'start_bicep_curl', 'Bicep Curl'),
      ]), now);
      expect([for (final x in days) x.isRest], [false, true, false]);
    });
    test('empty for null or malformed plans', () {
      expect(planDays(null, now), isEmpty);
      expect(planDays({'sessions': 'nope'}, now), isEmpty);
    });
  });

  group('mascotMoodFor', () {
    test('happy when trained today, even with no plan', () {
      expect(mascotMoodFor(plan: null, sessionDates: [d(11, 9)], now: now), MascotMood.happy);
    });
    test('idle with no plan', () {
      expect(mascotMoodFor(plan: null, sessionDates: [d(11, 1)], now: now), MascotMood.idle);
    });
    test('sleepy on a planned rest day', () {
      final plan = _plan([
        ('Sun, Nov 8', 'start_squat', 'Squat'),
        ('Mon, Nov 9', '', 'Active Recovery'),
        ('Tue, Nov 10', 'start_squat', 'Squat'),
      ]);
      expect(mascotMoodFor(plan: plan, sessionDates: [d(11, 8)], now: now), MascotMood.sleepy);
    });
    test('sad after a missed training day', () {
      final plan = _plan([
        ('Sun, Nov 8', 'start_squat', 'Squat'),
        ('Mon, Nov 9', 'start_squat', 'Squat'),
        ('Tue, Nov 10', 'start_squat', 'Squat'),
      ]);
      expect(mascotMoodFor(plan: plan, sessionDates: [d(11, 1)], now: now), MascotMood.sad);
    });
    test('sad ends once the user trains again', () {
      final plan = _plan([
        ('Sat, Nov 7', 'start_squat', 'Squat'),
        ('Sun, Nov 8', 'start_squat', 'Squat'),
        ('Mon, Nov 9', 'start_squat', 'Squat'),
      ]);
      // Missed the 7th, trained the 8th, today not done yet -> idle, not sad.
      expect(mascotMoodFor(plan: plan, sessionDates: [d(11, 8)], now: now), MascotMood.idle);
    });
    test('idle on a training day not done yet', () {
      final plan = _plan([
        ('Mon, Nov 9', 'start_squat', 'Squat'),
        ('Tue, Nov 10', 'start_squat', 'Squat'),
        ('Wed, Nov 11', 'start_squat', 'Squat'),
      ]);
      expect(mascotMoodFor(plan: plan, sessionDates: const [], now: now), MascotMood.idle);
    });
    test('idle before the plan starts, happy after finishing it', () {
      final future = _plan([
        ('Tue, Nov 10', 'start_squat', 'Squat'),
        ('Wed, Nov 11', 'start_squat', 'Squat'),
        ('Thu, Nov 12', 'start_squat', 'Squat'),
      ]);
      expect(mascotMoodFor(plan: future, sessionDates: const [], now: now), MascotMood.idle);
      final done = _plan([
        ('Thu, Nov 5', 'start_squat', 'Squat'),
        ('Fri, Nov 6', '', 'Active Recovery'),
        ('Sat, Nov 7', 'start_squat', 'Squat'),
      ]);
      expect(
        mascotMoodFor(plan: done, sessionDates: [d(11, 5), d(11, 7)], now: now),
        MascotMood.happy,
      );
    });
  });

  group('celebrationKey', () {
    test('fires when every plan training day is done', () {
      final plan = _plan([
        ('Sat, Nov 7', 'start_squat', 'Squat'),
        ('Sun, Nov 8', '', 'Active Recovery'),
        ('Mon, Nov 9', 'start_squat', 'Squat'),
      ]);
      expect(
        celebrationKey(plan: plan, sessionDates: [d(11, 7), d(11, 9)], now: now),
        'plan:2026-11-07-2026-11-09',
      );
      expect(celebrationKey(plan: plan, sessionDates: [d(11, 7)], now: now), isNull);
    });
    test('fires for a PR set today only', () {
      expect(
        celebrationKey(
          plan: null,
          sessionDates: [d(11, 9)],
          now: now,
          mostRepsRecord: (value: 15, date: d(11, 9)),
        ),
        'pr:reps:15:2026-11-09',
      );
      expect(
        celebrationKey(
          plan: null,
          sessionDates: [d(11, 8)],
          now: now,
          bestFormRecord: (value: 90, date: d(11, 8)),
        ),
        isNull,
      );
    });
  });

  test('mascotLine never empty and uses the streak', () {
    for (final m in MascotMood.values) {
      expect(mascotLine(m, streak: 0, hasPlan: true), isNotEmpty);
    }
    expect(mascotLine(MascotMood.happy, streak: 4, hasPlan: true), contains('4-day'));
  });

  group('mascotStatusFor', () {
    test('sad names the missed day and puts "one workout" first', () {
      final plan = _plan([
        ('Sun, Nov 8', 'start_squat', 'Squat'),
        ('Mon, Nov 9', 'start_squat', 'Squat'),
        ('Tue, Nov 10', 'start_squat', 'Squat'),
      ]);
      final st = mascotStatusFor(plan: plan, sessionDates: [d(11, 1)], now: now);
      expect(st.mood, MascotMood.sad);
      expect(st.reason, contains('Sun, Nov 8'));
      expect(st.checklist.first.text, 'Do one workout today');
      expect(st.checklist.first.state, ChecklistState.todo);
      expect([for (final c in st.checklist.skip(1)) c.state],
          [ChecklistState.missed, ChecklistState.todo, ChecklistState.upcoming]);
    });
    test('happy after training today ticks the first item', () {
      final st = mascotStatusFor(plan: null, sessionDates: [d(11, 9)], now: now);
      expect(st.mood, MascotMood.happy);
      expect(st.checklist.first.state, ChecklistState.done);
      expect(st.checklist.any((c) => c.text == 'Get your 3-day plan'), isTrue);
    });
    test('rest day is not a to-do', () {
      final plan = _plan([
        ('Sun, Nov 8', 'start_squat', 'Squat'),
        ('Mon, Nov 9', '', 'Active Recovery'),
      ]);
      final st = mascotStatusFor(plan: plan, sessionDates: [d(11, 8)], now: now);
      expect(st.mood, MascotMood.sleepy);
      expect(st.checklist.first.state, ChecklistState.rest);
    });
  });
}
