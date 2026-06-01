enum ExerciseCategory { legs, upper, core }

class Exercise {
  const Exercise({
    required this.id,
    required this.name,
    required this.category,
    required this.emoji,
    required this.description,
    required this.targetAngleMin,
    required this.targetAngleMax,
  });

  final String id;
  final String name;
  final ExerciseCategory category;
  final String emoji;
  final String description;

  // FR-2.2: Target joint angle range (degrees) that constitutes correct biomechanical form
  final double targetAngleMin;
  final double targetAngleMax;

  String get categoryLabel => switch (category) {
        ExerciseCategory.legs => 'Legs',
        ExerciseCategory.upper => 'Upper',
        ExerciseCategory.core => 'Core',
      };

  // FR-2.2: Supported exercises with per-exercise biomechanical angle parameters
  static const List<Exercise> all = [
    Exercise(
      id: 'squat',
      name: 'Squat',
      category: ExerciseCategory.legs,
      emoji: '🦵',
      description: 'Full body lower compound',
      targetAngleMin: 70,
      targetAngleMax: 100,
    ),
    Exercise(
      id: 'bicep_curl',
      name: 'Bicep Curl',
      category: ExerciseCategory.upper,
      emoji: '💪',
      description: 'Elbow flexion — full ROM',
      targetAngleMin: 30,
      targetAngleMax: 60,
    ),
  ];
}
