import 'muscle.dart';

enum ExerciseCategory { legs, upper, core }

/// Per-exercise biomechanical parameters used by the form gauge **and** the
/// rep counter.
///
/// Tunables for accuracy:
///   • [targetAngleMin] / [targetAngleMax] — green zone for the form gauge.
///   • [repBottomAngleStrict] / [repTopAngleStrict] — hard thresholds the
///     joint must cross to register a rep. Set these tighter than the green
///     zone to reject standing-around motion. (Defaults below are tighter
///     than the form zone for both exercises.)
///   • [romFullSpanDeg] — the joint excursion of a textbook-perfect rep, in
///     degrees. Per-rep ROM is scored against this, NOT against the strict rep
///     thresholds: a rep cannot be counted without crossing those, so scoring
///     against them would rate every counted rep 100%.
///   • [minRepDurationMs] — discards rep crossings faster than this; kills
///     jitter from landmark wobble while standing still.
///   • [minLandmarkConfidence] — drop frames where the three key joints have
///     an ML Kit likelihood lower than this.
///   • [restBetweenSetsSec] — countdown shown after the coaching sheet
///     dismisses, before the next set begins rep counting again.
///
/// Analytics fields (Progress tab):
///   • [met] — metabolic equivalent for the calorie estimate
///     (kcal = MET × weight kg × active hours).
///   • [primaryMuscles] / [secondaryMuscles] — drive the body map; secondary
///     muscles count at half weight.
class Exercise {
  const Exercise({
    required this.id,
    required this.name,
    required this.category,
    required this.emoji,
    required this.description,
    required this.targetAngleMin,
    required this.targetAngleMax,
    required this.repBottomAngleStrict,
    required this.repTopAngleStrict,
    required this.romFullSpanDeg,
    required this.met,
    required this.primaryMuscles,
    this.secondaryMuscles = const [],
    this.minRepDurationMs = 700,
    this.minLandmarkConfidence = 0.55,
    this.restBetweenSetsSec = 30,
  });

  final String id;
  final String name;
  final ExerciseCategory category;
  final String emoji;
  final String description;

  // FR-2.2: form-gauge green zone (degrees).
  final double targetAngleMin;
  final double targetAngleMax;

  // FR-2.4: stricter angles the rep state machine must cross.
  final double repBottomAngleStrict;
  final double repTopAngleStrict;

  // FR-2.4: degrees of joint travel in an ideal full-range rep — the
  // denominator for RepStateMachine.romScore.
  final double romFullSpanDeg;

  final int minRepDurationMs;
  final double minLandmarkConfidence;
  final int restBetweenSetsSec;

  final double met;
  final List<Muscle> primaryMuscles;
  final List<Muscle> secondaryMuscles;

  /// Looks up a catalog entry by display name (what Supabase stores in
  /// `workout_sessions.exercise_type`). Null for unknown or renamed exercises.
  static Exercise? byName(String name) {
    for (final e in all) {
      if (e.name.toLowerCase() == name.toLowerCase()) return e;
    }
    return null;
  }

  String get categoryLabel => switch (category) {
    ExerciseCategory.legs => 'Legs',
    ExerciseCategory.upper => 'Upper',
    ExerciseCategory.core => 'Core',
  };

  // ── Catalog ────────────────────────────────────────────────────────────────
  // Tweak the numbers below to adjust accuracy without touching the camera code.
  static const List<Exercise> all = [
    Exercise(
      id: 'squat',
      name: 'Squat',
      category: ExerciseCategory.legs,
      emoji: '🦵',
      description: 'Full body lower compound',
      // Knee angle interpretation:
      //   ~180° = standing tall, ~90° = parallel squat, <70° = deep squat.
      targetAngleMin: 70,
      targetAngleMax: 100,
      repBottomAngleStrict: 95, // must drop below this to count "down"
      repTopAngleStrict: 168, // must return above this to count "up"
      romFullSpanDeg: 105, // 175° standing → 70° deep
      minRepDurationMs: 800,
      // Compendium of Physical Activities: resistance training, moderate.
      met: 3.5,
      primaryMuscles: [Muscle.quads, Muscle.glutes],
      secondaryMuscles: [Muscle.hamstrings, Muscle.calves, Muscle.core],
    ),
    Exercise(
      id: 'bicep_curl',
      name: 'Bicep Curl',
      category: ExerciseCategory.upper,
      emoji: '💪',
      description: 'Elbow flexion — full ROM',
      // Elbow angle interpretation:
      //   ~170° = arm fully extended (rep "bottom"), ~40° = curled (rep "top").
      targetAngleMin: 30,
      targetAngleMax: 100,
      repBottomAngleStrict: 162, // arm must straighten past this
      repTopAngleStrict: 40, // arm must curl past this
      romFullSpanDeg: 140, // 170° extended → 30° curled
      minRepDurationMs: 600,
      // Compendium of Physical Activities: resistance training, moderate.
      met: 3.5,
      primaryMuscles: [Muscle.biceps],
      secondaryMuscles: [Muscle.forearms],
    ),
  ];
}
