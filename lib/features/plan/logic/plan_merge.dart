import 'dart:convert';

import '../../progress/logic/mascot_mood.dart';
import '../../train/models/exercise.dart';
import 'plan_edits.dart';

/// Rolling plan: cards are never replaced wholesale. Each generation only
/// plans the days that need it, inside a window of the next [planWindowDays]
/// days after today, and merges them into the existing plan.
///
/// Rules (agreed 2026-11-11):
/// * window = tomorrow .. +3 days; today is never auto-planned
/// * empty window days get one card each
/// * after a workout, tomorrow may be re-planned, but only when every card on
///   it is an untouched AI card
/// * past cards stay as the record (done / missed / skipped); cards older
///   than [keepHistoryDays] drop out of the local plan (Supabase keeps them)

const planWindowDays = 3;
const keepHistoryDays = 60;

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// Tomorrow, +2, +3.
List<DateTime> windowDates(DateTime now) => [
  for (var i = 1; i <= planWindowDays; i++)
    DateTime(now.year, now.month, now.day + i),
];

List<Map<String, dynamic>> _cards(Map<String, dynamic>? plan) =>
    plan?['sessions'] is List
    ? (plan!['sessions'] as List).whereType<Map<String, dynamic>>().toList()
    : <Map<String, dynamic>>[];

List<Map<String, dynamic>> _cardsOn(
  Map<String, dynamic>? plan,
  DateTime day,
  DateTime now,
) => [
  for (final c in _cards(plan))
    if (cardDate(c, now) == _day(day)) c,
];

/// An AI card nobody has touched: not edited, added, skipped, done or own.
/// Only these may be re-planned.
bool isUntouchedAiCard(Map<String, dynamic> card) =>
    card['edited'] != true &&
    card['userAdded'] != true &&
    card['skipped'] != true &&
    card['done'] != true &&
    card['custom'] != true &&
    card['completedSessionId'] == null;

/// Window days the AI should plan now: empty days, plus tomorrow when
/// [replanTomorrow] (a workout was just done) and tomorrow only has untouched
/// AI cards.
List<DateTime> datesToPlan(
  Map<String, dynamic>? plan,
  DateTime now, {
  bool replanTomorrow = false,
}) {
  final window = windowDates(now);
  return [
    for (final d in window)
      if (_cardsOn(plan, d, now) case final cards
          when cards.isEmpty ||
              (replanTomorrow &&
                  d == window.first &&
                  cards.every(isUntouchedAiCard)))
        d,
  ];
}

/// One line per existing card from today on, so Gemini knows what is
/// already planned and keeps the week balanced.
List<String> describeUpcoming(Map<String, dynamic>? plan, DateTime now) {
  final today = _day(now);
  final rows = <(DateTime, String)>[];
  for (final c in _cards(plan)) {
    final d = cardDate(c, now);
    if (d == null || d.isBefore(today)) continue;
    final status = c['skipped'] == true
        ? 'rest day (skipped by user)'
        : c['done'] == true
        ? 'done'
        : isRestSession(c)
        ? 'rest day'
        : 'planned';
    rows.add((
      d,
      '${shortDate(d)}: ${c['exercise'] ?? 'Workout'} '
          '${c['volume'] ?? ''} ($status)',
    ));
  }
  rows.sort((a, b) => a.$1.compareTo(b.$1));
  return [for (final r in rows) r.$2];
}

Map<String, dynamic> _copy(Map<String, dynamic> m) =>
    jsonDecode(jsonEncode(m)) as Map<String, dynamic>;

/// Puts one card per date of [dates] into [existing]:
/// * untouched AI cards already on those dates are replaced (re-plan)
/// * the generated card for a date is used, or the next unused one when the
///   AI got the date wrong; dates that still hold a user card are skipped
/// * title and coach note come from [generated] when present
/// * cards older than [keepHistoryDays] are dropped
Map<String, dynamic> mergeGenerated(
  Map<String, dynamic>? existing,
  Map<String, dynamic> generated,
  List<DateTime> dates,
  DateTime now,
) {
  final out = existing == null
      ? <String, dynamic>{'type': 'WorkoutPlanView', 'sessions': []}
      : _copy(existing);
  out['type'] = 'WorkoutPlanView';
  final targets = dates.map(_day).toSet();

  final kept = [
    for (final c in _cards(out))
      if (!(targets.contains(cardDate(c, now)) && isUntouchedAiCard(c))) c,
  ];

  final pool = [for (final c in _cards(generated)) _copy(c)..remove('id')];
  final used = <Map<String, dynamic>>{};
  Map<String, dynamic>? pick(DateTime d) {
    for (final c in pool) {
      if (!used.contains(c) && cardDate(c, now) == d) return c;
    }
    for (final c in pool) {
      if (!used.contains(c)) return c;
    }
    return null;
  }

  for (final d in targets.toList()..sort()) {
    if (kept.any((c) => cardDate(c, now) == d)) continue; // user card stays
    final card = pick(d);
    if (card == null) break;
    used.add(card);
    card['type'] = 'SessionCard';
    card['date'] = shortDate(d);
    card['isoDate'] = isoDay(d);
    kept.add(card);
  }

  final oldest = _day(now).subtract(const Duration(days: keepHistoryDays));
  kept.removeWhere((c) => cardDate(c, now)?.isBefore(oldest) ?? false);
  kept.sort(
    (a, b) => (cardDate(a, now) ?? DateTime(9999)).compareTo(
      cardDate(b, now) ?? DateTime(9999),
    ),
  );
  out['sessions'] = kept;

  for (final key in ['title', 'coachNote']) {
    final v = generated[key];
    if (v is String && v.trim().isNotEmpty) out[key] = v;
  }
  return out;
}

/// Offline demo mode has no AI: fills [dates] by alternating the tracked
/// exercises at the volume and time of the last planned workout.
Map<String, dynamic> ruleBasedCards(
  Map<String, dynamic>? existing,
  List<DateTime> dates,
  DateTime now,
) {
  final workouts =
      [
        for (final c in _cards(existing))
          if (exerciseForActionId(c['actionId'] as String?) != null &&
              !isRestSession(c))
            c,
      ]..sort(
        (a, b) => (cardDate(a, now) ?? DateTime(0)).compareTo(
          cardDate(b, now) ?? DateTime(0),
        ),
      );
  final last = workouts.lastOrNull;
  var exercise =
      exerciseForActionId(last?['actionId'] as String?) ?? Exercise.all.last;
  final (:sets, :reps) = last == null ? (sets: 3, reps: 10) : setsRepsOf(last);
  final time = last?['time'] as String? ?? '08:00 AM';

  final cards = <Map<String, dynamic>>[];
  for (final d in dates) {
    final i = Exercise.all.indexOf(exercise);
    exercise = Exercise.all[(i + 1) % Exercise.all.length];
    cards.add({
      'type': 'SessionCard',
      'date': shortDate(d),
      'isoDate': isoDay(d),
      'time': time,
      'exercise': exercise.name,
      'actionId': actionIdFor(exercise),
      'sets': sets,
      'reps': reps,
      'volume': volumeLabel(sets, reps),
      'intensity': '',
    });
  }
  return {
    'type': 'WorkoutPlanView',
    if (existing?['coachNote'] == null)
      'coachNote':
          'Planned offline: alternating exercises at your last volume.',
    'sessions': cards,
  };
}

/// Today's not-yet-done card for [exerciseName], so a workout started from
/// the Train tab still ticks the plan. Null when there is none.
String? todayCardIdFor(
  Map<String, dynamic>? plan,
  String exerciseName,
  DateTime now,
) {
  final name = exerciseName.trim().toLowerCase();
  for (final c in _cardsOn(plan, now, now)) {
    if (c['done'] == true || c['skipped'] == true) continue;
    if ((c['exercise'] as String?)?.trim().toLowerCase() == name &&
        c['id'] is String) {
      return c['id'] as String;
    }
  }
  return null;
}
