import 'package:fitnessapp/features/plan/logic/plan_edits.dart';
import 'package:fitnessapp/features/plan/logic/schedule_logic.dart';
import 'package:fitnessapp/features/progress/logic/mascot_mood.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _plan() => {
  'type': 'WorkoutPlanView',
  'sessions': [
    {
      'type': 'SessionCard',
      'day': 'Day 1',
      'date': 'Wed, Nov 11',
      'time': '08:00 AM',
      'exercise': 'Squat',
      'volume': '3 sets x 11 reps',
      'intensity': 'Keep knees out.',
      'actionId': 'start_squat',
    },
    {
      'type': 'SessionCard',
      'day': 'Day 2',
      'date': 'Thu, Nov 12',
      'time': '08:00 AM',
      'exercise': 'Bicep Curl',
      'volume': '3 sets × 10 reps',
      'intensity': 'Slow lowering.',
      'actionId': 'start_bicep_curl',
    },
  ],
};

final _now = DateTime(2026, 11, 10, 9);

SessionEdit _edit({
  String exercise = 'Squat',
  String? actionId = 'start_squat',
  int sets = 4,
  int reps = 8,
  DateTime? date,
}) => SessionEdit(
  exercise: exercise,
  actionId: actionId,
  sets: sets,
  reps: reps,
  time: '06:30 PM',
  date: date ?? DateTime(2026, 11, 11),
);

void main() {
  test('setsRepsOf reads x and × labels, falls back to 3 x 10', () {
    expect(setsRepsOf({'volume': '3 sets x 11 reps'}), (sets: 3, reps: 11));
    expect(setsRepsOf({'volume': '4 sets × 12 reps'}), (sets: 4, reps: 12));
    expect(setsRepsOf({'sets': 2, 'reps': 5, 'volume': 'junk'}), (
      sets: 2,
      reps: 5,
    ));
    expect(setsRepsOf({'volume': 'Light stretching'}), (sets: 3, reps: 10));
  });

  test('plan time parse and format round-trip', () {
    expect(parsePlanTime('08:00 AM'), (hour: 8, minute: 0));
    expect(parsePlanTime('12:15 AM'), (hour: 0, minute: 15));
    expect(parsePlanTime('06:30 PM'), (hour: 18, minute: 30));
    expect(parsePlanTime('nope'), isNull);
    expect(formatPlanTime(18, 30), '06:30 PM');
    expect(formatPlanTime(0, 5), '12:05 AM');
  });

  test('editSession keeps the AI original and does not touch the input', () {
    final plan = _plan();
    final out = editSession(plan, 0, _edit());
    final card = (out['sessions'] as List)[0] as Map;
    expect(card['volume'], '4 sets x 8 reps');
    expect(card['time'], '06:30 PM');
    expect(card['edited'], isTrue);
    expect(card['aiVolume'], '3 sets x 11 reps');
    expect(card['intensity'], 'Keep knees out.', reason: 'same exercise');
    expect(((plan['sessions'] as List)[0] as Map)['edited'], isNull);

    // A second edit keeps the first AI original.
    final again = editSession(out, 0, _edit(sets: 5));
    expect(
      ((again['sessions'] as List)[0] as Map)['aiVolume'],
      '3 sets x 11 reps',
    );
  });

  test('swapping exercise clears the old tip; moving changes the date', () {
    final out = editSession(
      _plan(),
      0,
      _edit(
        exercise: 'Bicep Curl',
        actionId: 'start_bicep_curl',
        date: DateTime(2026, 11, 13),
      ),
    );
    final card = (out['sessions'] as List)[0] as Map<String, dynamic>;
    expect(card['intensity'], '');
    expect(card['date'], 'Fri, Nov 13');
    expect(planEntriesOn(out, DateTime(2026, 11, 13), _now), hasLength(1));
    expect(planEntriesOn(out, DateTime(2026, 11, 11), _now), isEmpty);
  });

  test('own exercise is a workout day, not a rest day, and can be ticked', () {
    var out = addSession(
      _plan(),
      _edit(exercise: 'Push-ups', actionId: null, date: DateTime(2026, 11, 14)),
    );
    final entries = planEntriesOn(out, DateTime(2026, 11, 14), _now);
    expect(entries.single.card['custom'], isTrue);
    expect(entries.single.card['userAdded'], isTrue);
    expect(entries.single.card.containsKey('actionId'), isFalse);

    var day = planDays(out, _now).firstWhere((d) => d.label == 'Push-ups');
    expect(day.isRest, isFalse);
    expect(day.done, isFalse);

    out = setDone(out, entries.single.index, true);
    day = planDays(out, _now).firstWhere((d) => d.label == 'Push-ups');
    expect(day.done, isTrue);
  });

  test('skipping makes a rest day; undo restores it', () {
    final skipped = setSkipped(_plan(), 1, true);
    expect(planDays(skipped, _now)[1].isRest, isTrue);
    final back = setSkipped(skipped, 1, false);
    expect(planDays(back, _now)[1].isRest, isFalse);
  });

  test('isRestSession ignores "rest" in the tip, not in the name', () {
    expect(
      isRestSession({
        'exercise': 'Squat',
        'actionId': 'start_squat',
        'intensity': 'Rest 60 s between sets.',
      }),
      isFalse,
    );
    expect(
      isRestSession({
        'exercise': 'Active Recovery',
        'actionId': 'start_bicep_curl',
      }),
      isTrue,
      reason: 'Gemini sometimes puts an actionId on recovery days',
    );
    expect(isRestSession({'exercise': 'Push-ups', 'custom': true}), isFalse);
    expect(
      isRestSession({
        'exercise': 'Squat',
        'actionId': 'start_squat',
        'skipped': true,
      }),
      isTrue,
    );
  });

  test('calendar: a workout beats a skipped card on the same date', () {
    // Day 1 skipped, then a squat added on the same day.
    var plan = setSkipped(_plan(), 0, true);
    plan = addSession(plan, _edit(date: DateTime(2026, 11, 11)));
    final planned = plannedRestByDay(planDays(plan, _now));
    expect(planned[DateTime(2026, 11, 11)], isFalse);
    expect(planned[DateTime(2026, 11, 12)], isFalse);

    // Only the skipped card left → rest.
    final only = plannedRestByDay(planDays(setSkipped(_plan(), 0, true), _now));
    expect(only[DateTime(2026, 11, 11)], isTrue);
  });

  test('removeSession drops the card', () {
    final out = removeSession(_plan(), 0);
    expect(out['sessions'], hasLength(1));
  });

  test('a ticked own workout counts as trained for Flick', () {
    final plan = setDone(
      addSession(
        _plan(),
        _edit(exercise: 'Plank', actionId: null, date: DateTime(2026, 11, 10)),
      ),
      2,
      true,
    );
    expect(
      mascotMoodFor(plan: plan, sessionDates: const [], now: _now),
      MascotMood.happy,
    );
  });

  test('describeUserEdits lists every kind of change', () {
    var plan = editSession(_plan(), 0, _edit());
    plan = setSkipped(plan, 1, true);
    plan = addSession(plan, _edit(exercise: 'Running', actionId: null));
    final lines = describeUserEdits(plan);
    expect(lines, hasLength(3));
    expect(
      lines[0],
      contains('changed Squat 3 sets x 11 reps to Squat 4 sets x 8 reps'),
    );
    expect(lines[1], contains('skipped Bicep Curl'));
    expect(lines[2], contains('added Running'));
    expect(lines[2], contains('not camera-tracked'));
    expect(describeUserEdits(null), isEmpty);
    expect(describeUserEdits(_plan()), isEmpty);
  });
}
