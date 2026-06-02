import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

import '../features/profile/models/user_profile_biometrics.dart';
import '../features/train/models/set_metrics.dart';

/// FR-3.1 / FR-3.2: Central Gemini wrapper.
///
/// Two model instances are used:
///   _textModel — prose output (post-set coaching tips).
///   _jsonModel — strict JSON output (adaptive plan generation, enforced via
///                GenerationConfig(responseMimeType: 'application/json')).
class GeminiService {
  GeminiService()
      : _textModel = GenerativeModel(
          model: 'gemini-3.1-flash-lite',
          apiKey: dotenv.env['GEMINI_API_KEY']!,
        ),
        _jsonModel = GenerativeModel(
          model: 'gemini-3.1-flash-lite',
          apiKey: dotenv.env['GEMINI_API_KEY']!,
          generationConfig:
              GenerationConfig(responseMimeType: 'application/json'),
        );

  final GenerativeModel _textModel;
  final GenerativeModel _jsonModel;

  // FR-3.1: Streams a brief prose coaching tip after each set.
  Stream<String> streamSetCoaching({
    required String exerciseName,
    required SetMetrics metrics,
  }) =>
      _stream(_textModel, _buildSetPrompt(exerciseName, metrics));

  /// FR-3.2: Streams a JSON adaptive plan based on session metrics + biometrics.
  /// [currentLocalTime] anchors all generated `date` / `time` fields so the
  /// schedule reads as "Wed, Jun 3" / "08:00 AM" relative to the user's clock.
  /// Caller accumulates all chunks then `jsonDecode`s the combined string.
  Stream<String> streamSessionAnalysis({
    required String exerciseName,
    required List<SetMetrics> sets,
    required List<String> previousSessionSummaries,
    required UserProfileBiometrics biometrics,
    required DateTime currentLocalTime,
  }) =>
      _stream(
        _jsonModel,
        _buildSessionPrompt(
          exerciseName,
          sets,
          previousSessionSummaries,
          biometrics,
          currentLocalTime,
        ),
      );

  Stream<String> _stream(GenerativeModel model, String prompt) async* {
    final responses = model.generateContentStream([Content.text(prompt)]);
    await for (final chunk in responses) {
      final text = chunk.text;
      if (text != null && text.isNotEmpty) yield text;
    }
  }

  String _buildSetPrompt(String exerciseName, SetMetrics m) => '''
You are a concise fitness coach. The user just completed Set ${m.setNumber} of $exerciseName.
Results: ${m.repsCompleted} reps | Form: ${m.formPercent} | Fatigue: ${m.fatigueLabel}
Rep durations (ms): ${m.repDurationsMs.join(', ')}

Give 2–3 sentences of specific, motivating feedback. Note one thing they did well and one actionable tip for their next set. Under 50 words.
''';

  String _buildSessionPrompt(
    String exerciseName,
    List<SetMetrics> sets,
    List<String> history,
    UserProfileBiometrics bio,
    DateTime now,
  ) {
    final setLines = sets
        .map((s) =>
            '  Set ${s.setNumber}: ${s.repsCompleted} reps | Form: ${s.formPercent} | Fatigue: ${s.fatigueLabel} | TUT: ${s.tutLabel}')
        .join('\n');

    final historySection = history.isEmpty
        ? '  No previous sessions — this is their first session.'
        : history
            .asMap()
            .entries
            .map((e) => '  Session ${e.key + 1}: ${e.value}')
            .join('\n');

    // Compute three concrete dates so the model has unambiguous anchors and
    // never has to guess what "tomorrow" means relative to a date string.
    final day1 = now.add(const Duration(days: 1));
    final day2 = now.add(const Duration(days: 2));
    final day3 = now.add(const Duration(days: 3));

    String fmt(DateTime d) {
      const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      return '${weekdays[d.weekday - 1]}, ${months[d.month - 1]} ${d.day}';
    }

    return '''
You are FitForm's Expert AI Strength & Conditioning Coach. Your task is to analyze the data below and produce a fully personalized 3-day training plan. Every field in your output must be computed from the actual data — never copy placeholder text or repeat the schema examples literally.

--- CURRENT LOCAL TIME ---
${now.toIso8601String()}
Use this anchor for every scheduled session. Day 1 = ${fmt(day1)}, Day 2 = ${fmt(day2)}, Day 3 = ${fmt(day3)}. Time of day should be chosen sensibly (e.g. early morning if the user trained late the previous day, otherwise mirror today's training hour).

--- USER PROFILE ---
Gender: ${bio.gender} | Age: ${bio.age}
Weight: ${bio.weightKg} kg | Height: ${bio.heightCm} cm
Goal: ${bio.fitnessGoal} | Experience Level: ${bio.experienceLevel}

--- TODAY'S SESSION: $exerciseName ---
$setLines

--- TRAINING HISTORY (oldest → newest) ---
$historySection

--- PROGRESSION DECISION RULES ---
Evaluate the fatigue trend across all sets, then apply exactly one rule:
• MAINTENANCE — if any set has 'High' fatigue: prescribe the same volume as today to allow full neurological recovery.
• PROGRESSIVE OVERLOAD — if fatigue is 'Low' or 'Moderate' across all sets: safely escalate one of (a) +1–2 reps per set, (b) +1 set, or (c) a 5% load increase — whichever is most appropriate for the user's goal and experience level. Explain why.

Consider form score when choosing overload magnitude: a form score below 60% should reduce escalation; above 80% allows full escalation.

--- EXERCISE CATALOG ---
Only assign exercises from this list. The actionId must match exactly:
• Squat → actionId: "start_squat"
• Bicep Curl → actionId: "start_bicep_curl"

--- OUTPUT FORMAT ---
Return a single raw JSON object. No markdown, no code fences, no commentary outside the JSON.
All string values must be derived from the user's actual data. The title must reflect their goal. The coachNote must reference their real form score, fatigue label, and the specific progression decision you made. The `date` and `time` fields are mandatory on every SessionCard and must be computed from the CURRENT LOCAL TIME anchor above.

JSON schema (replace every angle-bracket field with computed content):
{
  "type": "WorkoutPlanView",
  "title": "<concise motivating title tailored to their specific goal and level>",
  "coachNote": "<2–3 sentences: cite actual form score and fatigue trend, then state whether you applied maintenance or progressive overload and why>",
  "sessions": [
    {
      "type": "SessionCard",
      "day": "Day 1",
      "date": "${fmt(day1)}",
      "time": "<HH:MM AM/PM, e.g. 08:00 AM>",
      "exercise": "<exercise name from catalog>",
      "volume": "<computed sets × reps, e.g. '3 sets × 12 reps'>",
      "intensity": "<specific instruction: e.g. 'Increase to 12 reps per set — your Low fatigue and 84% form score support full overload'>",
      "actionId": "<exactly 'start_squat' or 'start_bicep_curl'>"
    },
    {
      "type": "SessionCard",
      "day": "Day 2",
      "date": "${fmt(day2)}",
      "time": "<HH:MM AM/PM>",
      "exercise": "<exercise name from catalog>",
      "volume": "<computed sets × reps>",
      "intensity": "<specific instruction>",
      "actionId": "<exactly 'start_squat' or 'start_bicep_curl'>"
    },
    {
      "type": "SessionCard",
      "day": "Day 3",
      "date": "${fmt(day3)}",
      "time": "<HH:MM AM/PM>",
      "exercise": "<exercise name from catalog>",
      "volume": "<computed sets × reps>",
      "intensity": "<specific instruction>",
      "actionId": "<exactly 'start_squat' or 'start_bicep_curl'>"
    }
  ]
}
''';
  }
}

final geminiServiceProvider = Provider<GeminiService>((_) => GeminiService());
