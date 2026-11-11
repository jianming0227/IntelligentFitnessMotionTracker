import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/profile/models/user_profile_biometrics.dart';
import '../features/progress/logic/mascot_mood.dart';
import '../features/train/models/set_metrics.dart';

/// FR-3.1 / FR-3.2: Central Gemini wrapper.
///
/// Prompts are built here, but Gemini is called by the `gemini` Supabase Edge
/// Function (supabase/functions/gemini), which holds the API key and picks the
/// model. The app only sends the prompt with the signed-in user's token.
///   json: false — prose output (post-set coaching tips).
///   json: true  — strict JSON output (adaptive plan generation).
///
/// The function returns the whole answer at once, so each stream yields a
/// single chunk. Callers keep their stream-based code unchanged.
class GeminiService {
  // FR-3.1: Streams a brief prose coaching tip after each set.
  Stream<String> streamSetCoaching({
    required String exerciseName,
    required SetMetrics metrics,
  }) => _generate(_buildSetPrompt(exerciseName, metrics), json: false);

  /// FR-3.2: Streams a JSON adaptive plan based on session metrics + biometrics.
  /// The plan is rolling: Gemini plans only [datesToPlan] (one card each) and
  /// sees [alreadyPlanned] so the new days fit around the existing ones.
  /// Caller accumulates all chunks then `jsonDecode`s the combined string.
  Stream<String> streamSessionAnalysis({
    required String exerciseName,
    required List<SetMetrics> sets,
    required List<String> previousSessionSummaries,
    required UserProfileBiometrics biometrics,
    required DateTime currentLocalTime,
    required List<DateTime> datesToPlan,
    List<String> alreadyPlanned = const [],
    List<String> userEdits = const [],
  }) => _generate(
    _buildSessionPrompt(
      exerciseName,
      sets,
      previousSessionSummaries,
      biometrics,
      currentLocalTime,
      datesToPlan,
      alreadyPlanned,
      userEdits,
    ),
    json: true,
  );

  Stream<String> _generate(String prompt, {required bool json}) async* {
    final client = Supabase.instance.client;
    // The function rejects the anon key, so skip the round trip in demo mode.
    if (client.auth.currentSession == null) {
      throw StateError('AI needs a signed-in user');
    }
    final res = await client.functions.invoke(
      'gemini',
      body: {'prompt': prompt, 'json': json},
    );
    final text = (res.data as Map<String, dynamic>?)?['text'] as String?;
    if (text == null || text.isEmpty) {
      throw const FormatException('Empty response from AI');
    }
    yield text;
  }

  String _buildSetPrompt(String exerciseName, SetMetrics m) =>
      '''
You are a concise fitness coach. The user just completed Set ${m.setNumber} of $exerciseName.
Results: ${m.repsCompleted} reps | Form: ${m.formPercent} | Fatigue: ${m.fatigueLabel}
Range of motion: ${m.romPercent} of a full-range rep | Time under tension: ${m.tutLabel} (${(m.tutRatio * 100).round()}% of the set)
Endurance (ROM x TUT composite): ${m.endurancePercent} — ${m.enduranceLabel}
Rep durations (ms): ${m.repDurationsMs.join(', ')}
Per-rep excursion (degrees): ${m.repRomSpans.map((d) => d.round()).join(', ')}

If range of motion is under 75%, the tip must be about rep depth, not speed or effort.

Give 2–3 sentences of specific, motivating feedback. Note one thing they did well and one actionable tip for their next set. Under 50 words.
''';

  String _buildSessionPrompt(
    String exerciseName,
    List<SetMetrics> sets,
    List<String> history,
    UserProfileBiometrics bio,
    DateTime now,
    List<DateTime> dates,
    List<String> alreadyPlanned,
    List<String> userEdits,
  ) {
    final editsSection = userEdits.isEmpty
        ? '  None.'
        : userEdits.map((e) => '  • $e').join('\n');
    final setLines = sets.isEmpty
        ? '  No workout today.'
        : sets
              .map(
                (s) =>
                    '  Set ${s.setNumber}: ${s.repsCompleted} reps | Form: ${s.formPercent} | Fatigue: ${s.fatigueLabel} | TUT: ${s.tutLabel} | ROM: ${s.romPercent} | Endurance: ${s.endurancePercent} (${s.enduranceLabel})',
              )
              .join('\n');

    final historySection = history.isEmpty
        ? '  No previous sessions — this is their first session.'
        : history
              .asMap()
              .entries
              .map((e) => '  Session ${e.key + 1}: ${e.value}')
              .join('\n');

    final plannedSection = alreadyPlanned.isEmpty
        ? '  Nothing yet.'
        : alreadyPlanned.map((e) => '  • $e').join('\n');

    // Exact dates to plan, so the model never has to work out "tomorrow".
    final dateList = dates.map(shortDate).toList();
    final cardSchema = [
      for (final d in dateList)
        '''
    {
      "type": "SessionCard",
      "date": "$d",
      "time": "<HH:MM AM/PM, e.g. 08:00 AM>",
      "exercise": "<exercise name from catalog, or 'Active Recovery'>",
      "volume": "<computed sets × reps, e.g. '3 sets × 12 reps'>",
      "intensity": "<one short specific instruction>",
      "actionId": "<exactly 'start_squat' or 'start_bicep_curl'>"
    }''',
    ].join(',\n');

    return '''
You are FitForm's Expert AI Strength & Conditioning Coach. The user's plan is rolling: days that are already planned stay as they are, and you plan ONLY the dates listed below, one session card per date. Every field must be computed from the actual data — never copy placeholder text or repeat the schema examples literally.

--- CURRENT LOCAL TIME ---
${now.toIso8601String()}

--- DATES TO PLAN (exactly ${dateList.length}, one card each, in this order) ---
${dateList.map((d) => '  • $d').join('\n')}
Time of day should be chosen sensibly (mirror the user's usual training hour from the plan below, else 08:00 AM).

--- ALREADY PLANNED (do not change; plan around these) ---
$plannedSection
Keep the week balanced: avoid the same exercise on more than two days in a row, and never repeat a planned rest day back to back.

--- USER PROFILE ---
Gender: ${bio.gender} | Age: ${bio.age}
Weight: ${bio.weightKg} kg | Height: ${bio.heightCm} cm
Goal: ${bio.fitnessGoal} | Experience Level: ${bio.experienceLevel}

--- TODAY'S SESSION: $exerciseName ---
$setLines

--- TRAINING HISTORY (oldest → newest) ---
$historySection

--- USER'S OWN CHANGES TO THE PLAN ---
$editsSection
Treat these as the user's preferences. Do not raise volume above what the user set unless form and fatigue clearly allow it, and keep a skipped exercise lighter. Exercises the user added that are not in the catalog below cannot be camera-tracked: never put them in the plan, but count them as extra training load.

--- PROGRESSION DECISION RULES ---
Evaluate the fatigue trend across the latest sets, then apply exactly one rule:
• MAINTENANCE — if any set has 'High' fatigue: prescribe the same volume as the last session, and you may make ONE of the dates to plan an "Active Recovery" day with light stretching advice (use actionId "rest").
• PROGRESSIVE OVERLOAD — if fatigue is 'Low' or 'Moderate' across all sets: safely escalate one of (a) +1–2 reps per set, (b) +1 set, or (c) a 5% load increase.

Consider form score when choosing overload magnitude: a form score below 60% should reduce escalation; above 80% allows full escalation.

Apply these biometric rules on top of the fatigue decision:
• If experienceLevel is 'Beginner': cap escalation at +1 rep per set only — never add sets or increase load.
• If experienceLevel is 'Intermediate' or 'Advanced': all three escalation options are available.
• If goal is 'Weight Loss': prefer higher reps (12–15) with shorter rest; avoid load increases.
• If goal is 'Build Muscle': prefer +1–2 reps or +1 set; load increase only if form score is above 80%.
• If goal is 'Improve Fitness': balance reps and sets evenly; mirror the last volume on maintenance days.
• If age is above 50: prefer higher sets × lower reps over load increases.

TUT (Time Under Tension) guidance — apply to the intensity field:
• If average TUT across sets is below 2.0s: add a tempo cue, e.g. "Focus on a 3s lowering phase".
• If average TUT is above 4.0s: acknowledge the strong time under tension; apply full overload if fatigue permits.

--- EXERCISE CATALOG ---
Only assign exercises from this list. The actionId must match exactly:
• Squat → actionId: "start_squat"
• Bicep Curl → actionId: "start_bicep_curl"

--- OUTPUT FORMAT ---
Return a single raw JSON object. No markdown, no code fences, no commentary outside the JSON.
The "sessions" array has exactly ${dateList.length} card(s), one per date to plan, using those exact "date" strings. The title must reflect their goal. The coachNote is one plain sentence explaining why the new day(s) look this way, using their real form score or fatigue and the progression decision you made.

JSON schema (replace every angle-bracket field with computed content):
{
  "type": "WorkoutPlanView",
  "title": "<concise motivating title tailored to their specific goal and level>",
  "coachNote": "<exactly 1 short, simple sentence, max 20 words, saying why: the key number and the decision, e.g. 'Form held at 84% with low fatigue, so reps go up by one.'>",
  "sessions": [
$cardSchema
  ]
}
''';
  }
}

final geminiServiceProvider = Provider<GeminiService>((_) => GeminiService());
