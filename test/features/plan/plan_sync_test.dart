import 'package:fitnessapp/features/plan/logic/plan_edits.dart';
import 'package:fitnessapp/features/plan/logic/plan_sync.dart';
import 'package:fitnessapp/features/progress/logic/mascot_mood.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime(2026, 11, 10, 9);

Map<String, dynamic> _plan() => {
  'type': 'WorkoutPlanView',
  'sessions': [
    {
      'day': 'Day 1',
      'date': 'Wed, Nov 11',
      'time': '08:00 AM',
      'exercise': 'Squat',
      'volume': '3 sets x 11 reps',
      'actionId': 'start_squat',
    },
    {
      'day': 'Day 2',
      'date': 'Thu, Nov 12',
      'exercise': 'Active Recovery',
      'volume': 'Light stretching',
    },
    {'day': 'Day 3', 'exercise': 'Bicep Curl', 'date': 'someday'},
  ],
};

void main() {
  test('newCardId is a v4 UUID and unique', () {
    final a = newCardId(), b = newCardId();
    expect(
      a,
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ),
      ),
    );
    expect(a, isNot(b));
  });

  test('withCardIds adds ids + exact dates and keeps existing ids', () {
    final once = withCardIds(_plan(), _now);
    final cards = (once['sessions'] as List).cast<Map<String, dynamic>>();
    expect(cards[0]['id'], isA<String>());
    expect(cards[0]['isoDate'], '2026-11-11');
    expect(cards[2].containsKey('isoDate'), isFalse, reason: 'unreadable date');

    final twice = withCardIds(once, _now);
    expect(((twice['sessions'] as List)[0] as Map)['id'], cards[0]['id']);
    expect(_plan()['sessions'][0].containsKey('id'), isFalse);
  });

  test('isoDate wins over the year-less display date', () {
    // Viewed from June, "Nov 11" alone would resolve to last November.
    final card = {'date': 'Wed, Nov 11', 'isoDate': '2027-11-11'};
    expect(cardDate(card, DateTime(2027, 6, 1)), DateTime(2027, 11, 11));
    expect(cardDate({'date': 'Wed, Nov 11'}, _now), DateTime(2026, 11, 11));
  });

  test('planSessionRows: one dated row per card, rest days without volume', () {
    final rows = planSessionRows(
      withCardIds(_plan(), _now),
      userId: 'u1',
      planId: 'p1',
    );
    expect(rows, hasLength(2), reason: 'the undated card is skipped');
    expect(rows[0], containsPair('session_date', '2026-11-11'));
    expect(rows[0], containsPair('exercise_id', 'squat'));
    expect(rows[0], containsPair('sets', 3));
    expect(rows[0], containsPair('reps', 11));
    expect(rows[0], containsPair('status', 'planned'));
    expect(rows[0], containsPair('source', 'ai'));
    expect(rows[0], containsPair('plan_id', 'p1'));
    expect(rows[1], containsPair('exercise_name', 'Active Recovery'));
    expect(rows[1]['exercise_id'], isNull);
    expect(rows[1]['sets'], isNull);
  });

  test('statuses and user edits reach the row', () {
    var plan = withCardIds(_plan(), _now);
    plan = setSkipped(plan, 0, true);
    plan = addSession(
      plan,
      SessionEdit(
        exercise: 'Push-ups',
        actionId: null,
        sets: 3,
        reps: 15,
        time: '06:30 PM',
        date: DateTime(2026, 11, 13),
      ),
    );
    plan = withCardIds(plan, _now);
    final rows = planSessionRows(plan, userId: 'u1');
    expect(rows[0]['status'], 'skipped');
    final added = rows.last;
    expect(added['session_date'], '2026-11-13');
    expect(added['source'], 'user');
    expect(added['is_custom'], isTrue);
    expect(added['exercise_id'], isNull);
    expect(added.containsKey('plan_id'), isFalse);
  });

  test('markCardDone ticks the card and records the workout', () {
    final plan = withCardIds(_plan(), _now);
    final id = ((plan['sessions'] as List)[0] as Map)['id'] as String;
    final done = markCardDone(plan, id, 'w1')!;
    final card = (done['sessions'] as List)[0] as Map<String, dynamic>;
    expect(card['done'], isTrue);
    expect(card['completedSessionId'], 'w1');
    final row = planSessionRows(done, userId: 'u1').first;
    expect(row['status'], 'done');
    expect(row['completed_session_id'], 'w1');
    expect(markCardDone(plan, 'missing', 'w1'), isNull);
  });
}
