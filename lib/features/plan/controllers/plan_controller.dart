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
    // Preserve the current plan so a transient failure can never blank-wipe it.
    final previous = state.valueOrNull;
    state = const AsyncValue.loading();

    // A truncated stream (flaky network) surfaces as a FormatException on decode
    // and is transient — one silent retry usually succeeds. Try at most twice.
    const maxAttempts = 2;
    Object? lastError;
    StackTrace? lastStack;

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final parsed = await _streamAndParsePlan(
          exerciseName: exerciseName,
          sets: sets,
          biometrics: biometrics,
          sessionHistory: sessionHistory,
        );

        // The parsed Map is re-encoded canonically, then saved to local + supa.
        final jsonString = jsonEncode(parsed);
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
        return;
      } catch (e, st) {
        lastError = e;
        lastStack = st;
        debugPrint(
            '[PlanController] generate attempt $attempt/$maxAttempts failed: $e');
      }
    }

    // All attempts failed. Never blank-wipe a working plan: if one already
    // exists, keep it on screen. Only surface an error when there is nothing
    // to fall back to (e.g. the very first generation).
    if (previous != null) {
      state = AsyncValue.data(previous);
    } else {
      state = AsyncValue.error(
        _friendlyError(lastError),
        lastStack ?? StackTrace.current,
      );
    }
  }

  /// Streams the Gemini plan, accumulates all chunks, then decodes. Throws a
  /// [FormatException] if the stream was empty or the JSON is incomplete.
  Future<Map<String, dynamic>> _streamAndParsePlan({
    required String exerciseName,
    required List<SetMetrics> sets,
    required UserProfileBiometrics biometrics,
    required List<String> sessionHistory,
  }) async {
    final buffer = StringBuffer();
    await for (final chunk
        in ref.read(geminiServiceProvider).streamSessionAnalysis(
              exerciseName: exerciseName,
              sets: sets,
              previousSessionSummaries: sessionHistory,
              biometrics: biometrics,
              currentLocalTime: DateTime.now(),
            )) {
      buffer.write(chunk);
    }
    final jsonString = buffer.toString().trim();
    if (jsonString.isEmpty) {
      throw const FormatException('Empty response from AI');
    }
    return jsonDecode(jsonString) as Map<String, dynamic>;
  }

  /// Converts a raw decode/stream failure into a user-readable message for the
  /// error view. A truncated stream is almost always a connection drop.
  Object _friendlyError(Object? error) {
    if (error is FormatException) {
      return Exception(
        'The connection dropped while generating your plan. '
        'Check your internet and tap Retry.',
      );
    }
    return error ?? Exception('Could not generate plan. Tap Retry.');
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
