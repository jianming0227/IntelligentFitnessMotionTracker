// FR-1.2: Complete biometric profile — every field required. The controller
// returns null until the user finishes the survey for the first time.
class UserProfileBiometrics {
  const UserProfileBiometrics({
    required this.gender,
    required this.age,
    required this.weightKg,
    required this.heightCm,
    required this.fitnessGoal,
    required this.experienceLevel,
  });

  final String gender;
  final int age;
  final double weightKg;
  final double heightCm;
  final String fitnessGoal;
  final String experienceLevel;

  static const List<String> genders = ['Male', 'Female'];

  static const List<String> goals = [
    'Lose weight',
    'Get fitter',
    'Gain flexibility',
    'Build muscle',
  ];

  static const List<String> levels = [
    'Rookie',
    'Beginner',
    'Intermediate',
    'Advance',
    'True Beast',
  ];

  static const UserProfileBiometrics defaults = UserProfileBiometrics(
    gender: 'Male',
    age: 25,
    weightKg: 70,
    heightCm: 170,
    fitnessGoal: 'Get fitter',
    experienceLevel: 'Beginner',
  );
}
