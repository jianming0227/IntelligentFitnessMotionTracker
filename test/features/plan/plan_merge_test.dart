import 'package:fitnessapp/features/plan/logic/plan_edits.dart';
import 'package:fitnessapp/features/plan/logic/plan_merge.dart';
import 'package:fitnessapp/features/plan/logic/plan_sync.dart';
import 'package:fitnessapp/features/progress/logic/mascot_mood.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _card(
  DateTime d,
  String exercise, {
  String? action,
  Map<String, dynamic> extra = const {},
}) => {
  'type': 'SessionCard',
  'date': shortDate(d),
  'isoDate': isoDay(d),
  'time': '08:00 AM',
  'exercise': exercise,
  'volume': '3 sets x 10 reps',
  'actionId': ?action,
  ...extra,
};

Map<String, dynamic> _plan(List<Map<String, dynamic>> cards) => withCardIds({
  'type': 'WorkoutPlanView',
  'coachNote': 'Old note.',
  'sessions': cards,
}, DateTime(2026, 11, 10));

DateTime _d(int day, [int month = 11]) => DateTime(2026, month, day);

List<String> _isoDates(Map<String, dynamic> plan) => [
  for (final c in (plan['sessions'] as List).cast<Map>())
    c['isoDate'] as String,
];

Map<String, dynamic> _gen(List<Map<String, dynamic>> cards) => {
  'type': 'WorkoutPlanView',
  'title': 'New title',
  'coachNote': 'New note.',
  'sessions': cards,
};

void main() {
  // Plan made on Nov 10 for Nov 11, 12, 13.
  final nov10Plan = _plan([
    _card(_d(11), 'Squat', action: 'start_squat'),
    _card(_d(12), 'Bicep Curl', action: 'start_bicep_curl'),
    _card(_d(13), 'Squat', action: 'start_squat'),
  ]);

  test('window is tomorrow to +3 days', () {
    expect(windowDates(DateTime(2026, 11, 30, 23)), [
      _d(1, 12),
      _d(2, 12),
      _d(3, 12),
    ]);
  });

  test('no plan yet: all 3 window days need planning', () {
    expect(datesToPlan(null, DateTime(2026, 11, 10, 9)), [
      _d(11),
      _d(12),
      _d(13),
    ]);
  });

  test('day changes from Nov 10 to 11: only Nov 14 is planned, rest kept', () {
    final now = DateTime(2026, 11, 11, 0, 5);
    final dates = datesToPlan(nov10Plan, now);
    expect(dates, [_d(14)]);

    final merged = mergeGenerated(
      nov10Plan,
      _gen([_card(_d(14), 'Bicep Curl', action: 'start_bicep_curl')]),
      dates,
      now,
    );
    expect(_isoDates(merged), [
      '2026-11-11',
      '2026-11-12',
      '2026-11-13',
      '2026-11-14',
    ]);
    // Existing cards keep their ids, so plan_sessions rows stay the same.
    final before = (nov10Plan['sessions'] as List).map((c) => c['id']).toList();
    final after = (merged['sessions'] as List).map((c) => c['id']).take(3);
    expect(after, before);
    expect(merged['coachNote'], 'New note.');
  });

  test('window full: nothing to plan (no AI call)', () {
    expect(datesToPlan(nov10Plan, DateTime(2026, 11, 10, 20)), isEmpty);
  });

  group('re-plan tomorrow after a workout', () {
    final now = DateTime(2026, 11, 10, 20);

    test('untouched AI card tomorrow is re-planned', () {
      final dates = datesToPlan(nov10Plan, now, replanTomorrow: true);
      expect(dates, [_d(11)]);
      final merged = mergeGenerated(
        nov10Plan,
        _gen([
          _card(_d(11), 'Squat', action: 'start_squat')
            ..['volume'] = '3 sets x 12 reps',
        ]),
        dates,
        now,
      );
      final nov11 = (merged['sessions'] as List).cast<Map>().where(
        (c) => c['isoDate'] == '2026-11-11',
      );
      expect(nov11, hasLength(1));
      expect(nov11.single['volume'], '3 sets x 12 reps');
      expect(_isoDates(merged), hasLength(3), reason: 'days 2-3 untouched');
    });

    for (final flag in ['edited', 'skipped', 'userAdded', 'done', 'custom']) {
      test('tomorrow with a $flag card is left alone', () {
        final plan = _plan([
          _card(_d(11), 'Squat', action: 'start_squat', extra: {flag: true}),
          _card(_d(12), 'Bicep Curl', action: 'start_bicep_curl'),
          _card(_d(13), 'Squat', action: 'start_squat'),
        ]);
        expect(datesToPlan(plan, now, replanTomorrow: true), isEmpty);
      });
    }
  });

  test('a user card on a planned date is never replaced', () {
    final now = DateTime(2026, 11, 10, 9);
    final plan = _plan([
      _card(_d(11), 'Push-ups', extra: {'custom': true, 'userAdded': true}),
    ]);
    final merged = mergeGenerated(
      plan,
      _gen([_card(_d(11), 'Squat', action: 'start_squat')]),
      [_d(11)],
      now,
    );
    final cards = (merged['sessions'] as List).cast<Map>();
    expect(cards, hasLength(1));
    expect(cards.single['exercise'], 'Push-ups');
  });

  test('AI got the date wrong or sent extra cards: one card per date', () {
    final now = DateTime(2026, 11, 11, 9);
    final merged = mergeGenerated(
      nov10Plan,
      _gen([
        _card(_d(20), 'Bicep Curl', action: 'start_bicep_curl'),
        _card(_d(21), 'Squat', action: 'start_squat'),
      ]),
      [_d(14)],
      now,
    );
    final cards = (merged['sessions'] as List).cast<Map>();
    expect(_isoDates(merged).last, '2026-11-14');
    expect(cards.last['exercise'], 'Bicep Curl');
    expect(cards, hasLength(4));
  });

  test('cards older than 60 days drop out locally', () {
    final now = DateTime(2026, 11, 10, 9);
    final plan = _plan([
      _card(_d(1, 9), 'Squat', action: 'start_squat'),
      _card(_d(20, 10), 'Squat', action: 'start_squat'),
    ]);
    final merged = mergeGenerated(plan, _gen([]), const [], now);
    expect(_isoDates(merged), ['2026-10-20']);
  });

  test('offline rule fill alternates exercises at the last volume', () {
    final now = DateTime(2026, 11, 13, 9);
    final dates = datesToPlan(nov10Plan, now); // 14, 15, 16
    final merged = mergeGenerated(
      nov10Plan,
      ruleBasedCards(nov10Plan, dates, now),
      dates,
      now,
    );
    final added = (merged['sessions'] as List).cast<Map>().skip(3).toList();
    expect(added.map((c) => c['exercise']), [
      'Bicep Curl',
      'Squat',
      'Bicep Curl',
    ]);
    expect(added.first['volume'], '3 sets x 10 reps');
    expect(merged['coachNote'], 'Old note.', reason: 'keeps the AI note');
  });

  test('a Train-tab workout ticks today\'s card of the same exercise', () {
    final now = DateTime(2026, 11, 11, 18);
    final squatId = ((nov10Plan['sessions'] as List)[0] as Map)['id'];
    expect(todayCardIdFor(nov10Plan, 'squat', now), squatId);
    expect(todayCardIdFor(nov10Plan, 'Bicep Curl', now), isNull);
    final done = setDone(nov10Plan, 0, true);
    expect(todayCardIdFor(done, 'Squat', now), isNull);
  });

  test('describeUpcoming lists today on, oldest first, with status', () {
    final lines = describeUpcoming(
      setSkipped(nov10Plan, 1, true),
      DateTime(2026, 11, 12, 9),
    );
    expect(lines, hasLength(2));
    expect(lines.first, startsWith('Thu, Nov 12: Bicep Curl'));
    expect(lines.first, endsWith('(rest day (skipped by user))'));
    expect(lines.last, endsWith('(planned)'));
  });
}
