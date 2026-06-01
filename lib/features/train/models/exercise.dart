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
      id: 'pushup',
      name: 'Push-up',
      category: ExerciseCategory.upper,
      emoji: '💪',
      description: 'Upper body push',
      targetAngleMin: 70,
      targetAngleMax: 100,
    ),
    Exercise(
      id: 'lunge',
      name: 'Lunge',
      category: ExerciseCategory.legs,
      emoji: '🏃',
      description: 'Single leg lower',
      targetAngleMin: 80,
      targetAngleMax: 110,
    ),
    Exercise(
      id: 'plank',
      name: 'Plank',
      category: ExerciseCategory.core,
      emoji: '🔥',
      description: 'Core stability hold',
      targetAngleMin: 160,
      targetAngleMax: 180,
    ),
  ];
}
