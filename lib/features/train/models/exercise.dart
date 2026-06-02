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
///   • [minRepDurationMs] — discards rep crossings faster than this; kills
///     jitter from landmark wobble while standing still.
///   • [minLandmarkConfidence] — drop frames where the three key joints have
///     an ML Kit likelihood lower than this.
///   • [restBetweenSetsSec] — countdown shown after the coaching sheet
///     dismisses, before the next set begins rep counting again.
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

  final int minRepDurationMs;
  final double minLandmarkConfidence;
  final int restBetweenSetsSec;

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
      repBottomAngleStrict: 95,  // must drop below this to count "down"
      repTopAngleStrict: 168,    // must return above this to count "up"
      minRepDurationMs: 800,
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
      targetAngleMax: 60,
      repBottomAngleStrict: 162, // arm must straighten past this
      repTopAngleStrict: 55,     // arm must curl past this
      minRepDurationMs: 600,
    ),
  ];
}
