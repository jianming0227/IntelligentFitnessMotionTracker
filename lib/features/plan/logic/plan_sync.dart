import 'dart:convert';
import 'dart:math';

import '../../progress/logic/mascot_mood.dart';
import '../../train/models/exercise.dart';
import 'plan_edits.dart';

/// Turns the plan JSON into rows for the `plan_sessions` table and back.
///
/// Every card gets a stable `id` (also the row's primary key) and an exact
/// `isoDate`, so a card can be found again after edits, and a finished
/// workout can point at the card it was started from.

final _rng = Random.secure();

/// Random UUID v4 (the project has no uuid package).
String newCardId() {
  final b = List<int>.generate(16, (_) => _rng.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-'
      '${h.substring(16, 20)}-${h.substring(20)}';
}

/// Copy of [plan] where every card has an `id` and an `isoDate`. Cards whose
/// date can't be read keep no `isoDate` and are left out of the table.
Map<String, dynamic> withCardIds(Map<String, dynamic> plan, DateTime now) {
  final out = jsonDecode(jsonEncode(plan)) as Map<String, dynamic>;
  final sessions = out['sessions'];
  if (sessions is! List) return out;
  for (final s in sessions.whereType<Map<String, dynamic>>()) {
    s['id'] ??= newCardId();
    final d = cardDate(s, now);
    if (d != null) s['isoDate'] = isoDay(d);
  }
  return out;
}

/// Row status for a card.
String planSessionStatus(Map<String, dynamic> card) => card['skipped'] == true
    ? 'skipped'
    : card['done'] == true
    ? 'done'
    : 'planned';

/// `plan_sessions` rows for every dated card of [plan] (call [withCardIds]
/// first). Rest / recovery cards are included: the calendar needs them too.
List<Map<String, dynamic>> planSessionRows(
  Map<String, dynamic> plan, {
  required String userId,
  String? planId,
}) {
  final sessions = plan['sessions'];
  if (sessions is! List) return const [];
  final rows = <Map<String, dynamic>>[];
  for (final s in sessions.whereType<Map<String, dynamic>>()) {
    final id = s['id'], iso = s['isoDate'];
    if (id is! String || iso is! String) continue;
    final Exercise? target = exerciseForActionId(s['actionId'] as String?);
    final custom = s['custom'] == true;
    final (:sets, :reps) = setsRepsOf(s);
    final rest = isRestSession(s) && s['skipped'] != true;
    rows.add({
      'id': id,
      'user_id': userId,
      'plan_id': ?planId,
      'session_date': iso,
      'session_time': s['time'],
      'day_label': s['day'],
      'exercise_id': rest ? null : target?.id,
      'exercise_name': (s['exercise'] as String?)?.trim().isNotEmpty == true
          ? (s['exercise'] as String).trim()
          : (rest ? 'Active Recovery' : 'Workout'),
      'sets': rest ? null : sets,
      'reps': rest ? null : reps,
      'status': planSessionStatus(s),
      'source': s['userAdded'] == true ? 'user' : 'ai',
      'is_custom': custom,
      'ai_exercise': s['aiExercise'],
      'ai_volume': s['aiVolume'],
      'completed_session_id': s['completedSessionId'],
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }
  return rows;
}

/// Marks card [cardId] done by workout [sessionId] (null when the workout
/// couldn't be saved online). Null when the plan has no such card.
Map<String, dynamic>? markCardDone(
  Map<String, dynamic> plan,
  String cardId,
  String? sessionId,
) {
  final out = jsonDecode(jsonEncode(plan)) as Map<String, dynamic>;
  final sessions = out['sessions'];
  if (sessions is! List) return null;
  for (final s in sessions.whereType<Map<String, dynamic>>()) {
    if (s['id'] == cardId) {
      s['done'] = true;
      s.remove('skipped');
      if (sessionId != null) s['completedSessionId'] = sessionId;
      return out;
    }
  }
  return null;
}
