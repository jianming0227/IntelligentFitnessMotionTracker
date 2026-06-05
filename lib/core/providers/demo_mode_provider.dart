import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Demo mode bypasses Supabase auth. All prefs are stored under the 'demo'
/// UID prefix (same as offline fallback in ProfileController + PlanController).
final demoModeProvider = StateProvider<bool>((ref) => false);

/// Seeds biometric + plan data under the 'demo_' prefix so the app is fully
/// populated when demo mode activates. Safe to call multiple times — idempotent.
Future<void> seedDemoData() async {
  const uid = 'demo';
  final prefs = await SharedPreferences.getInstance();

  // Biometrics
  await prefs.setString('${uid}_profile_gender', 'Male');
  await prefs.setInt('${uid}_profile_age', 23);
  await prefs.setDouble('${uid}_profile_height_cm', 175);
  await prefs.setDouble('${uid}_profile_weight_kg', 70);
  await prefs.setString('${uid}_profile_fitness_goal', 'Build muscle');
  await prefs.setString('${uid}_profile_experience_level', 'Intermediate');

  // AI workout plan — pre-generated, no Gemini call needed
  const planJson = '''
{
  "type": "WorkoutPlanView",
  "title": "Muscle Building — Progressive Overload Block",
  "coachNote": "Your previous session showed Moderate fatigue with 82% form score. Applying +1 rep progressive overload this block to safely drive hypertrophy.",
  "sessions": [
    {
      "type": "SessionCard",
      "day": "Day 1",
      "date": "Mon, Jun 9",
      "time": "08:00 AM",
      "exercise": "Squat",
      "volume": "3 sets x 11 reps",
      "intensity": "Increase to 11 reps per set. Maintain full depth — knee angle below 95 degrees at bottom.",
      "actionId": "start_squat"
    },
    {
      "type": "SessionCard",
      "day": "Day 2",
      "date": "Wed, Jun 11",
      "time": "08:00 AM",
      "exercise": "Bicep Curl",
      "volume": "3 sets x 11 reps",
      "intensity": "Full extension at the bottom, full squeeze at the top. Control the eccentric phase.",
      "actionId": "start_bicep_curl"
    },
    {
      "type": "SessionCard",
      "day": "Day 3",
      "date": "Fri, Jun 13",
      "time": "08:00 AM",
      "exercise": "Squat",
      "volume": "4 sets x 10 reps",
      "intensity": "Add a fourth set. Prioritise depth and knee tracking over speed.",
      "actionId": "start_squat"
    }
  ]
}
''';

  await prefs.setString('${uid}_adaptive_plan_json', planJson);
  await prefs.setString('${uid}_last_plan_exercise', 'Squat');
}
