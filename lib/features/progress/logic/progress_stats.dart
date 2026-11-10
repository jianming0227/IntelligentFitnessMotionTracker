import '../models/session_record.dart';
import 'streak.dart';

/// Totals for the last 7 days (today included) on the Progress KPI row.
class WeekStats {
  const WeekStats({
    required this.sessions,
    required this.reps,
    this.avgFormPct,
    this.kcal,
    this.activeTime = Duration.zero,
  });

  final int sessions;

  /// Sum of recorded set durations. Zero when none were recorded.
  final Duration activeTime;
  final int reps;

  /// Null when there were no sets this week.
  final int? avgFormPct;

  /// Null when no session this week recorded set durations.
  final double? kcal;
}

WeekStats weekStats(
  List<SessionRecord> records,
  DateTime now,
  double weightKg,
) {
  final week = _since(records, now, 7);
  final sets = [for (final r in week) ...r.sets];
  final kcals = [for (final r in week) ?r.calories(weightKg)];
  return WeekStats(
    sessions: week.length,
    reps: sets.fold(0, (sum, s) => sum + s.reps),
    avgFormPct: sets.isEmpty
        ? null
        : (sets.fold(0.0, (sum, s) => sum + s.formScore) / sets.length * 100)
              .round(),
    kcal: kcals.isEmpty ? null : kcals.reduce((a, b) => a + b),
    activeTime: week.fold(Duration.zero, (sum, r) => sum + r.activeDuration),
  );
}

/// Last [count] dated sessions with at least one set, oldest first, for the
/// form trend chart.
List<SessionRecord> formTrend(List<SessionRecord> records, {int count = 10}) {
  final dated = records.where((r) => r.date != null && r.sets.isNotEmpty);
  final sorted = dated.toList()..sort((a, b) => a.date!.compareTo(b.date!));
  return sorted.length <= count
      ? sorted
      : sorted.sublist(sorted.length - count);
}

/// One record-holding session, for the Personal Records card.
class RecordEntry {
  const RecordEntry({
    required this.value,
    required this.exerciseName,
    this.date,
  });

  final int value;
  final String exerciseName;
  final DateTime? date;
}

class PersonalRecords {
  const PersonalRecords({
    this.mostRepsInSet,
    this.bestFormSession,
    required this.longestStreakDays,
  });

  final RecordEntry? mostRepsInSet;

  /// Highest average form % across one whole session.
  final RecordEntry? bestFormSession;
  final int longestStreakDays;
}

PersonalRecords personalRecords(List<SessionRecord> records) {
  RecordEntry? reps;
  RecordEntry? form;
  for (final r in records) {
    for (final s in r.sets) {
      if (reps == null || s.reps > reps.value) {
        reps = RecordEntry(
          value: s.reps,
          exerciseName: r.exerciseName,
          date: r.date,
        );
      }
    }
    if (r.sets.isNotEmpty && (form == null || r.avgFormPct > form.value)) {
      form = RecordEntry(
        value: r.avgFormPct,
        exerciseName: r.exerciseName,
        date: r.date,
      );
    }
  }
  return PersonalRecords(
    mostRepsInSet: reps,
    bestFormSession: form,
    longestStreakDays: longestStreak([for (final r in records) ?r.date]),
  );
}

/// Per-exercise totals over the last [days] days, most sessions first.
class ExerciseSummary {
  const ExerciseSummary({
    required this.exerciseName,
    required this.sessions,
    required this.reps,
    required this.avgFormPct,
  });

  final String exerciseName;
  final int sessions;
  final int reps;
  final int avgFormPct;
}

List<ExerciseSummary> exerciseBreakdown(
  List<SessionRecord> records,
  DateTime now, {
  int days = 30,
}) {
  final byName = <String, List<SessionRecord>>{};
  for (final r in _since(records, now, days)) {
    byName.putIfAbsent(r.exerciseName, () => []).add(r);
  }
  final out = [
    for (final MapEntry(key: name, value: rs) in byName.entries)
      ExerciseSummary(
        exerciseName: name,
        sessions: rs.length,
        reps: rs.fold(0, (sum, r) => sum + r.totalReps),
        avgFormPct:
            (rs.fold(0, (sum, r) => sum + r.avgFormPct) / rs.length).round(),
      ),
  ];
  out.sort((a, b) => b.sessions.compareTo(a.sessions));
  return out;
}

/// Dated sessions from the last [days] calendar days, today included.
List<SessionRecord> _since(
  List<SessionRecord> records,
  DateTime now,
  int days,
) {
  final start = DateTime(now.year, now.month, now.day - (days - 1));
  return [
    for (final r in records)
      if (r.date case final d? when !d.isBefore(start)) r,
  ];
}
