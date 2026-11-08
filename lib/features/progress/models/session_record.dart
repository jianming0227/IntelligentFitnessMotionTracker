import '../../train/models/exercise.dart';
import '../logic/calories.dart';

/// One set inside a [SessionRecord]. [durationMs] is 0 when unknown (local
/// history strings don't carry it).
class SetRecord {
  const SetRecord({
    required this.reps,
    required this.formScore,
    this.durationMs = 0,
  });

  final int reps;

  /// 0.0–1.0 fraction of frames inside the form zone.
  final double formScore;
  final int durationMs;
}

/// A finished workout, read from Supabase `workout_sessions` or, in demo
/// mode / offline, from the local `session_history` strings. Every analytics
/// widget works off this model.
class SessionRecord {
  const SessionRecord({
    required this.date,
    required this.exerciseName,
    required this.sets,
  });

  /// Null only for legacy local entries written before dates were stored.
  final DateTime? date;
  final String exerciseName;
  final List<SetRecord> sets;

  Exercise? get exercise => Exercise.byName(exerciseName);

  int get totalReps => sets.fold(0, (sum, s) => sum + s.reps);

  int get avgFormPct => sets.isEmpty
      ? 0
      : (sets.fold(0.0, (sum, s) => sum + s.formScore) / sets.length * 100)
          .round();

  Duration get activeDuration =>
      Duration(milliseconds: sets.fold(0, (sum, s) => sum + s.durationMs));

  /// Null when the exercise is unknown or set durations weren't recorded.
  double? calories(double weightKg) {
    final ex = exercise;
    if (ex == null || activeDuration == Duration.zero) return null;
    return caloriesBurned(
      met: ex.met,
      weightKg: weightKg,
      active: activeDuration,
    );
  }

  /// Parses a `workout_sessions` row (see SupabaseService.insertWorkoutSession).
  factory SessionRecord.fromSupabaseRow(Map<String, dynamic> row) {
    final rawSets = (row['session_data'] as List?) ?? const [];
    return SessionRecord(
      // No toLocal(): insertWorkoutSession writes the phone's local clock
      // without an offset, so the stored fields already are local time.
      date: DateTime.tryParse('${row['created_at']}'),
      exerciseName: (row['exercise_type'] as String?) ?? 'Workout',
      sets: [
        for (final s in rawSets.whereType<Map>())
          SetRecord(
            reps: (s['reps'] as num?)?.toInt() ?? 0,
            formScore: (s['form_score'] as num?)?.toDouble() ?? 0,
            durationMs: (s['set_duration_ms'] as num?)?.toInt() ?? 0,
          ),
      ],
    );
  }

  /// Parses a local history entry written by SessionSummaryView:
  /// `<ISO date>|<Exercise> — Set 1: 8 reps, form 82%, ... | Set 2: ...`.
  /// Legacy entries have no date prefix; their [date] is null.
  factory SessionRecord.fromLocalHistory(String entry) {
    DateTime? date;
    var body = entry;
    final pipe = entry.indexOf('|');
    if (pipe > 0) {
      // Legacy entries also contain '|' between set summaries, but the text
      // before it never parses as a date, so tryParse keeps them safe.
      date = DateTime.tryParse(entry.substring(0, pipe));
      if (date != null) body = entry.substring(pipe + 1);
    }

    final dash = body.indexOf(' — ');
    final exerciseName = dash > 0 ? body.substring(0, dash) : 'Workout';

    final setPattern = RegExp(r'(\d+) reps, form (\d+)%');
    return SessionRecord(
      date: date,
      exerciseName: exerciseName,
      sets: [
        for (final m in setPattern.allMatches(body))
          SetRecord(
            reps: int.parse(m.group(1)!),
            formScore: int.parse(m.group(2)!) / 100,
          ),
      ],
    );
  }
}
