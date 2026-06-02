import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../services/gemini_service.dart';
import '../../auth/providers/auth_providers.dart';
import '../../profile/models/user_profile_biometrics.dart';
import '../../train/models/set_metrics.dart';

// FR-3.2: Manages the adaptive plan lifecycle.
// Accumulates the JSON stream, parses it, writes a debug JSON file to device
// storage, persists to SharedPreferences, and upserts to Supabase.
class PlanController extends AsyncNotifier<Map<String, dynamic>?> {
  static const _keyPlan = 'adaptive_plan_json';
  static const _keyLastExercise = 'last_plan_exercise';
  static const _outputFileName = 'fitform_plan.json';

  @override
  Future<Map<String, dynamic>?> build() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyPlan);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> generateAdaptivePlan({
    required String exerciseName,
    required List<SetMetrics> sets,
    required UserProfileBiometrics biometrics,
    required List<String> sessionHistory,
  }) async {
    state = const AsyncValue.loading();
    try {
      final buffer = StringBuffer();
      // Captured once so the model has a single, stable temporal anchor for
      // every Day 1 / Day 2 / Day 3 schedule it computes.
      final currentLocalTime = DateTime.now();

      await for (final chunk in ref
          .read(geminiServiceProvider)
          .streamSessionAnalysis(
            exerciseName: exerciseName,
            sets: sets,
            previousSessionSummaries: sessionHistory,
            biometrics: biometrics,
            currentLocalTime: currentLocalTime,
          )) {
        buffer.write(chunk);
      }

      final jsonString = buffer.toString();
      // Wrapped explicitly so network drops, partial chunks, and malformed
      // JSON all surface as a single AsyncValue.error via the outer catch.
      final parsed = jsonDecode(jsonString) as Map<String, dynamic>;

      // ── Persist to SharedPreferences ───────────────────────────────────────
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyPlan, jsonString);
      await prefs.setString(_keyLastExercise, exerciseName);

      // ── Write debug JSON file to device storage ────────────────────────────
      await _writeJsonFile(jsonString);

      // ── Upsert to Supabase (non-fatal if table doesn't exist yet) ──────────
      try {
        await ref
            .read(supabaseServiceProvider)
            .upsertPlan(planJson: parsed, exerciseName: exerciseName);
      } catch (e) {
        debugPrint('[PlanController] Supabase upsert skipped: $e');
      }

      state = AsyncValue.data(parsed);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  // Refreshes the plan from stored history + current biometrics (no live session).
  Future<void> refreshPlan({required UserProfileBiometrics biometrics}) async {
    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getStringList('session_history') ?? [];
    final exerciseName = prefs.getString(_keyLastExercise) ?? 'Squat';

    await generateAdaptivePlan(
      exerciseName: exerciseName,
      sets: const [], // history-only refresh — no live session data
      biometrics: biometrics,
      sessionHistory: history,
    );
  }

  // Writes pretty-printed JSON to {documentsDir}/fitform_plan.json.
  // On Android this is /data/user/0/<package>/app_flutter/fitform_plan.json.
  // Pull with: adb pull /data/user/0/<package>/app_flutter/fitform_plan.json
  Future<void> _writeJsonFile(String jsonString) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_outputFileName');
      const encoder = JsonEncoder.withIndent('  ');
      final pretty = encoder.convert(jsonDecode(jsonString));
      await file.writeAsString(pretty, flush: true);
      debugPrint('[PlanController] Plan JSON written to: ${file.path}');
      debugPrint('[PlanController] --- fitform_plan.json ---\n$pretty');
    } catch (e) {
      debugPrint('[PlanController] File write failed: $e');
    }
  }
}

final planProvider =
    AsyncNotifierProvider<PlanController, Map<String, dynamic>?>(
        PlanController.new);
