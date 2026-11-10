import 'dart:convert';

import '../../progress/logic/mascot_mood.dart';
import '../../train/models/exercise.dart';

/// User edits on the plan JSON. Every function returns a new plan map and
/// leaves the input untouched, so the old plan can still be compared.
///
/// Extra `SessionCard` fields written here (Gemini never sends them):
///   sets, reps   ints behind the `volume` label
///   edited       user changed an AI card; `aiExercise` / `aiVolume` keep the
///                original so the next generation knows what was changed
///   userAdded    the user created this card
///   custom       own exercise without camera tracking (no actionId)
///   skipped      turned into a rest day
///   done         custom workout marked done by hand

typedef SetsReps = ({int sets, int reps});

/// One card of the plan with its position in `sessions`.
typedef PlanEntry = ({int index, Map<String, dynamic> card});

/// What the edit sheet hands back. [actionId] null = own exercise.
class SessionEdit {
  const SessionEdit({
    required this.exercise,
    required this.actionId,
    required this.sets,
    required this.reps,
    required this.time,
    required this.date,
  });

  final String exercise;
  final String? actionId;
  final int sets;
  final int reps;
  final String time;
  final DateTime date;
}

/// Camera-tracked exercise behind an actionId (`start_<exercise id>`).
Exercise? exerciseForActionId(String? actionId) =>
    Exercise.all.where((e) => 'start_${e.id}' == actionId).firstOrNull;

String actionIdFor(Exercise e) => 'start_${e.id}';

/// Reads "3 sets x 12 reps" / "3 sets × 12 reps". Falls back to the card's
/// own `sets`/`reps` fields, then 3 x 10.
SetsReps setsRepsOf(Map<String, dynamic> card) {
  if (card['sets'] is int && card['reps'] is int) {
    return (sets: card['sets'] as int, reps: card['reps'] as int);
  }
  final m = RegExp(
    r'(\d+)\s*sets?\D+?(\d+)\s*reps?',
    caseSensitive: false,
  ).firstMatch(card['volume'] as String? ?? '');
  if (m == null) return (sets: 3, reps: 10);
  return (sets: int.parse(m.group(1)!), reps: int.parse(m.group(2)!));
}

String volumeLabel(int sets, int reps) =>
    '$sets ${sets == 1 ? 'set' : 'sets'} x $reps reps';

/// "08:00 AM" → (8, 0). Null when unreadable.
({int hour, int minute})? parsePlanTime(String? raw) {
  final m = RegExp(r'(\d{1,2}):(\d{2})\s*([AaPp][Mm])?').firstMatch(raw ?? '');
  if (m == null) return null;
  var hour = int.parse(m.group(1)!);
  final minute = int.parse(m.group(2)!);
  final ampm = m.group(3)?.toUpperCase();
  if (ampm == 'PM' && hour < 12) hour += 12;
  if (ampm == 'AM' && hour == 12) hour = 0;
  if (hour > 23 || minute > 59) return null;
  return (hour: hour, minute: minute);
}

String formatPlanTime(int hour, int minute) {
  final h12 = hour % 12 == 0 ? 12 : hour % 12;
  final ampm = hour < 12 ? 'AM' : 'PM';
  return '${h12.toString().padLeft(2, '0')}:'
      '${minute.toString().padLeft(2, '0')} $ampm';
}

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// Cards dated on [day], with their index for later edits.
List<PlanEntry> planEntriesOn(
  Map<String, dynamic> plan,
  DateTime day,
  DateTime now,
) {
  final sessions = plan['sessions'];
  if (sessions is! List) return const [];
  return [
    for (final (i, s) in sessions.indexed)
      if (s is Map<String, dynamic> &&
          s['date'] is String &&
          parsePlanDate(s['date'], now) == _day(day))
        (index: i, card: s),
  ];
}

Map<String, dynamic> _copy(Map<String, dynamic> plan) =>
    jsonDecode(jsonEncode(plan)) as Map<String, dynamic>;

List<dynamic> _sessionsOf(Map<String, dynamic> plan) => plan['sessions'] is List
    ? plan['sessions'] as List
    : (plan['sessions'] = []);

void _write(Map<String, dynamic> card, SessionEdit e) {
  card['exercise'] = e.exercise.trim();
  if (e.actionId == null) {
    card.remove('actionId');
    card['custom'] = true;
  } else {
    card['actionId'] = e.actionId;
    card.remove('custom');
  }
  card['sets'] = e.sets;
  card['reps'] = e.reps;
  card['volume'] = volumeLabel(e.sets, e.reps);
  card['time'] = e.time;
  card['date'] = shortDate(e.date);
}

/// B1/B2/B4: change exercise, sets, reps, time or date of card [index].
Map<String, dynamic> editSession(
  Map<String, dynamic> plan,
  int index,
  SessionEdit edit,
) {
  final out = _copy(plan);
  final card = _sessionsOf(out)[index] as Map<String, dynamic>;
  if (card['userAdded'] != true && card['edited'] != true) {
    card['aiExercise'] = card['exercise'];
    card['aiVolume'] = card['volume'];
  }
  // The coach tip was written for the old exercise.
  if ((card['exercise'] as String?)?.trim() != edit.exercise.trim()) {
    card['intensity'] = '';
  }
  _write(card, edit);
  if (card['userAdded'] != true) card['edited'] = true;
  return out;
}

/// B5/B6: a new card the user created.
Map<String, dynamic> addSession(Map<String, dynamic> plan, SessionEdit edit) {
  final out = _copy(plan);
  final card = <String, dynamic>{
    'type': 'SessionCard',
    'day': 'Added',
    'intensity': '',
    'userAdded': true,
  };
  _write(card, edit);
  _sessionsOf(out).add(card);
  return out;
}

Map<String, dynamic> removeSession(Map<String, dynamic> plan, int index) {
  final out = _copy(plan);
  _sessionsOf(out).removeAt(index);
  return out;
}

/// B3: rest day on/off.
Map<String, dynamic> setSkipped(
  Map<String, dynamic> plan,
  int index,
  bool skipped,
) => _setFlag(plan, index, 'skipped', skipped);

/// Own exercises can't be camera-tracked, so the user ticks them off.
Map<String, dynamic> setDone(Map<String, dynamic> plan, int index, bool done) =>
    _setFlag(plan, index, 'done', done);

Map<String, dynamic> _setFlag(
  Map<String, dynamic> plan,
  int index,
  String key,
  bool value,
) {
  final out = _copy(plan);
  final card = _sessionsOf(out)[index] as Map<String, dynamic>;
  if (value) {
    card[key] = true;
  } else {
    card.remove(key);
  }
  return out;
}

/// B7: one line per user change, for the next Gemini prompt.
List<String> describeUserEdits(Map<String, dynamic>? plan) {
  final sessions = plan?['sessions'];
  if (sessions is! List) return const [];
  final lines = <String>[];
  for (final s in sessions.whereType<Map<String, dynamic>>()) {
    final date = s['date'] ?? '';
    final name = s['exercise'] ?? 'Workout';
    final volume = s['volume'] ?? '';
    final own = s['custom'] == true
        ? ' (own exercise, not camera-tracked)'
        : '';
    if (s['skipped'] == true) {
      lines.add('$date: user skipped $name and made it a rest day');
    } else if (s['userAdded'] == true) {
      final done = s['done'] == true ? ', marked done' : '';
      lines.add('$date: user added $name $volume$own$done');
    } else if (s['edited'] == true) {
      lines.add(
        '$date: user changed ${s['aiExercise'] ?? name} ${s['aiVolume'] ?? ''} '
        'to $name $volume$own',
      );
    }
  }
  return lines;
}
