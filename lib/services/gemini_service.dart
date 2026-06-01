import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

import '../features/train/models/set_metrics.dart';

// FR-3.1 / FR-3.2: Central Gemini wrapper — all AI prompts and streaming
// responses are routed through this service.
class GeminiService {
  GeminiService()
      : _model = GenerativeModel(
          model: 'gemini-1.5-flash',
          apiKey: dotenv.env['GEMINI_API_KEY']!,
        );

  final GenerativeModel _model;

  // FR-3.1: Stream brief coaching feedback immediately after a single set ends.
  Stream<String> streamSetCoaching({
    required String exerciseName,
    required SetMetrics metrics,
  }) =>
      _stream(_buildSetPrompt(exerciseName, metrics));

  // FR-3.2: Stream a full session analysis + personalised 3-day training plan.
  // Receives the complete prior-session history so the plan improves over time.
  Stream<String> streamSessionAnalysis({
    required String exerciseName,
    required List<SetMetrics> sets,
    required List<String> previousSessionSummaries,
  }) =>
      _stream(_buildSessionPrompt(exerciseName, sets, previousSessionSummaries));

  Stream<String> _stream(String prompt) async* {
    final responses =
        _model.generateContentStream([Content.text(prompt)]);
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
  ) {
    final setLines = sets
        .map((s) =>
            '  Set ${s.setNumber}: ${s.repsCompleted} reps | Form: ${s.formPercent} | Fatigue: ${s.fatigueLabel}')
        .join('\n');

    final historySection = history.isEmpty
        ? '  No previous sessions — this is their first session.'
        : history
            .asMap()
            .entries
            .map((e) => '  Session ${e.key + 1}: ${e.value}')
            .join('\n');

    return '''
You are a personalised AI fitness coach. Analyse this $exerciseName session and all prior sessions to create a tailored plan.

TODAY'S SESSION:
$setLines

PREVIOUS SESSIONS (oldest first):
$historySection

1. Analyse today's performance (2–3 sentences): form quality, fatigue trend, progress vs prior sessions.
2. Personalised 3-Day Plan:
   Day 1: [exercise] [sets]×[reps] — [focus tip]
   Day 2: [exercise] [sets]×[reps] — [focus tip]
   Day 3: [exercise] [sets]×[reps] — [focus tip]
3. One motivational closing sentence.

Keep total under 200 words.
''';
  }
}

final geminiServiceProvider = Provider<GeminiService>((_) => GeminiService());
