import '../../train/models/exercise.dart';
import '../../train/models/muscle.dart';
import '../models/session_record.dart';

/// Body map colour for one muscle.
enum MuscleStatus {
  /// Trained recently with good form (green).
  good,

  /// Trained this week, but form was below [goodFormThreshold] (orange).
  needsForm,

  /// An exercise in the catalog trains it, but not recently enough (red).
  needsWork,

  /// No exercise in the catalog trains it yet (grey).
  untracked,
}

// Tunables. Change here, the body map and its tests follow.
/// Sessions older than this don't count toward a muscle's status.
const statusWindowDays = 7;

/// "Good" needs a session within this many days...
const goodWithinDays = 4;

/// ...and a weighted average form at or above this fraction.
const goodFormThreshold = 0.70;

/// Secondary muscles count at this weight against primary ones.
const secondaryWeight = 0.5;

/// What the body map shows for one muscle, plus the numbers for its sheet.
class MuscleStat {
  const MuscleStat({
    required this.muscle,
    required this.status,
    required this.trainedBy,
    this.lastTrained,
    this.sessionsInWindow = 0,
    this.avgForm,
  });

  final Muscle muscle;
  final MuscleStatus status;

  /// Catalog exercises that work this muscle, primary movers first.
  final List<Exercise> trainedBy;

  /// Most recent session that hit this muscle, any age.
  final DateTime? lastTrained;

  /// Sessions in the last [statusWindowDays] days that hit this muscle.
  final int sessionsInWindow;

  /// Weighted average form (0–1) over those sessions. Null when none.
  final double? avgForm;
}

/// Status of every [Muscle] from [records] as of [now].
///
/// A session hits a muscle at weight 1 when it's a primary mover of the
/// session's exercise and [secondaryWeight] when secondary. Rules, in order:
///   - no catalog exercise trains it → untracked
///   - no session in [statusWindowDays] days → needsWork
///   - weighted form < [goodFormThreshold] → needsForm
///   - last session within [goodWithinDays] days → good
///   - otherwise (good form, but 5–7 days ago) → needsWork, it's due again
Map<Muscle, MuscleStat> muscleStatuses(
  List<SessionRecord> records,
  DateTime now,
) {
  final today = DateTime(now.year, now.month, now.day);
  final windowStart = today.subtract(
    const Duration(days: statusWindowDays - 1),
  );

  return {
    for (final muscle in Muscle.values)
      muscle: _statFor(muscle, records, today, windowStart),
  };
}

MuscleStat _statFor(
  Muscle muscle,
  List<SessionRecord> records,
  DateTime today,
  DateTime windowStart,
) {
  final trainedBy = [
    ...Exercise.all.where((e) => e.primaryMuscles.contains(muscle)),
    ...Exercise.all.where((e) => e.secondaryMuscles.contains(muscle)),
  ];
  if (trainedBy.isEmpty) {
    return MuscleStat(
      muscle: muscle,
      status: MuscleStatus.untracked,
      trainedBy: const [],
    );
  }

  DateTime? lastTrained;
  var sessions = 0;
  var weightSum = 0.0;
  var formSum = 0.0;
  for (final r in records) {
    final ex = r.exercise;
    final date = r.date;
    if (ex == null || date == null || r.sets.isEmpty) continue;
    final weight = ex.primaryMuscles.contains(muscle)
        ? 1.0
        : ex.secondaryMuscles.contains(muscle)
        ? secondaryWeight
        : 0.0;
    if (weight == 0) continue;

    if (lastTrained == null || date.isAfter(lastTrained)) lastTrained = date;
    if (date.isBefore(windowStart)) continue;
    sessions++;
    weightSum += weight;
    formSum += weight * r.avgFormPct / 100;
  }

  final avgForm = weightSum == 0 ? null : formSum / weightSum;
  final MuscleStatus status;
  if (avgForm == null) {
    status = MuscleStatus.needsWork;
  } else if (avgForm < goodFormThreshold) {
    status = MuscleStatus.needsForm;
  } else {
    final last = DateTime(
      lastTrained!.year,
      lastTrained.month,
      lastTrained.day,
    );
    status = today.difference(last).inDays <= goodWithinDays
        ? MuscleStatus.good
        : MuscleStatus.needsWork;
  }

  return MuscleStat(
    muscle: muscle,
    status: status,
    trainedBy: trainedBy,
    lastTrained: lastTrained,
    sessionsInWindow: sessions,
    avgForm: avgForm,
  );
}
