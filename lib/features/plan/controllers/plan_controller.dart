import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../services/gemini_service.dart';
import '../../auth/providers/auth_providers.dart';
import '../../profile/models/user_profile_biometrics.dart';
import '../../train/models/set_metrics.dart';

// FR-3.2: Manages the adaptive plan lifecycle.
// All SharedPreferences keys are prefixed with the Supabase user ID (or
// 'demo' in offline mode) so multiple accounts on the same device are isolated.
class PlanController extends AsyncNotifier<Map<String, dynamic>?> {
  static const _outputFileName = 'fitform_plan.json';

  String get _uid =>
      Supabase.instance.client.auth.currentUser?.id ?? 'demo';
  String get _keyPlan => '${_uid}_adaptive_plan_json';
  String get _keyLastExercise => '${_uid}_last_plan_exercise';
  String get _keyHistory => '${_uid}_session_history';

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
      final parsed = jsonDecode(jsonString) as Map<String, dynamic>;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyPlan, jsonString);
      await prefs.setString(_keyLastExercise, exerciseName);

      await _writeJsonFile(jsonString);

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

  Future<void> refreshPlan({required UserProfileBiometrics biometrics}) async {
    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getStringList(_keyHistory) ?? [];
    final exerciseName = prefs.getString(_keyLastExercise) ?? 'Squat';

    await generateAdaptivePlan(
      exerciseName: exerciseName,
      sets: const [],
      biometrics: biometrics,
      sessionHistory: history,
    );
  }

  Future<void> clearPlan() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyPlan);
    await prefs.remove(_keyLastExercise);
    try {
      await ref.read(supabaseServiceProvider).deletePlan();
    } catch (e) {
      debugPrint('[PlanController] Supabase delete skipped: $e');
    }
    state = const AsyncValue.data(null);
  }

  Future<void> _writeJsonFile(String jsonString) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_outputFileName');
      const encoder = JsonEncoder.withIndent('  ');
      final pretty = encoder.convert(jsonDecode(jsonString));
      await file.writeAsString(pretty, flush: true);
      debugPrint('[PlanController] Plan JSON written to: ${file.path}');
    } catch (e) {
      debugPrint('[PlanController] File write failed: $e');
    }
  }
}

final planProvider =
    AsyncNotifierProvider<PlanController, Map<String, dynamic>?>(
        PlanController.new);
