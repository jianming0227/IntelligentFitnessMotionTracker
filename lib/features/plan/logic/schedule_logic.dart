import '../../progress/logic/mascot_mood.dart';
import '../../progress/models/session_record.dart';

/// Totals for one calendar month on the Schedule stat cards.
typedef MonthStats = ({double kcal, int daysCompleted});

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// kcal burned and distinct training days inside [month] (any day of it).
/// Sessions without recorded durations add 0 kcal.
MonthStats monthStats(
  List<SessionRecord> records,
  DateTime month,
  double weightKg,
) {
  var kcal = 0.0;
  final days = <DateTime>{};
  for (final r in records) {
    final d = r.date;
    if (d == null || d.year != month.year || d.month != month.month) continue;
    if (r.sets.isEmpty) continue;
    days.add(_day(d));
    kcal += r.calories(weightKg) ?? 0;
  }
  return (kcal: kcal, daysCompleted: days.length);
}

/// Distinct days with at least one session, for the calendar rings.
Set<DateTime> trainedDays(List<SessionRecord> records) => {
  for (final r in records)
    if (r.date != null && r.sets.isNotEmpty) _day(r.date!),
};

/// Sessions finished on [day].
List<SessionRecord> sessionsOn(List<SessionRecord> records, DateTime day) => [
  for (final r in records)
    if (r.date != null && _day(r.date!) == _day(day) && r.sets.isNotEmpty) r,
];

/// The plan's `SessionCard` nodes dated on [day]. Plan dates carry no year,
/// so they are resolved against [now] (see [parsePlanDate]).
List<Map<String, dynamic>> planCardsOn(
  Map<String, dynamic> plan,
  DateTime day,
  DateTime now,
) {
  final sessions = plan['sessions'];
  if (sessions is! List) return const [];
  return [
    for (final s in sessions.whereType<Map<String, dynamic>>())
      if (s['date'] is String && parsePlanDate(s['date'], now) == _day(day)) s,
  ];
}

/// First [count] sentences of [text]. Older plans have 3-sentence coach notes;
/// Flick's bubble only shows two.
String firstSentences(String text, {int count = 2}) {
  final parts = text
      .trim()
      .split(RegExp(r'(?<=[.!?])\s+'))
      .where((s) => s.isNotEmpty)
      .toList();
  return parts.take(count).join(' ');
}
