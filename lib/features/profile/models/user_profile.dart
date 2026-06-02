class UserProfile {
  const UserProfile({
    this.heightCm,
    this.weightKg,
    this.fitnessGoal,
  });

  final double? heightCm;
  final double? weightKg;
  final String? fitnessGoal;

  static const List<String> goals = [
    'Lose weight',
    'Build muscle',
    'Improve endurance',
    'General fitness',
  ];

  bool get isComplete =>
      heightCm != null && weightKg != null && fitnessGoal != null;

  // Injected into Gemini prompts so coaching is tailored to the user.
  String toPromptContext() {
    if (heightCm == null && weightKg == null && fitnessGoal == null) return '';
    final parts = <String>[];
    if (heightCm != null) parts.add('height: ${heightCm!.toStringAsFixed(0)}cm');
    if (weightKg != null) parts.add('weight: ${weightKg!.toStringAsFixed(1)}kg');
    if (fitnessGoal != null) parts.add('goal: $fitnessGoal');
    return 'User profile — ${parts.join(', ')}.';
  }
}
