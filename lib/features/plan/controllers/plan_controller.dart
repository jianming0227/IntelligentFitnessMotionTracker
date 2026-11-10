import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/app_log.dart';
import '../../../services/gemini_service.dart';
import '../../auth/providers/auth_providers.dart';
import '../../profile/models/user_profile_biometrics.dart';
import '../../progress/models/session_record.dart';
import '../../progress/providers/progress_providers.dart';
import '../../train/models/set_metrics.dart';

// FR-3.2: Manages the adaptive plan lifecycle.
// All SharedPreferences keys are prefixed with the Supabase user ID (or
// 'demo' in offline mode) so multiple accounts on the same device are isolated.
class PlanController extends AsyncNotifier<Map<String, dynamic>?> {
  static const _outputFileName = 'fitform_plan.json';

  String get _uid => Supabase.instance.client.auth.currentUser?.id ?? 'demo';
  String get _keyPlan => '${_uid}_adaptive_plan_json';
  String get _keyLastExercise => '${_uid}_last_plan_exercise';
  String get _keyHistory => '${_uid}_session_history';

  @override
  Future<Map<String, dynamic>?> build() async {
    // Re-read on sign-in / sign-out so each account sees its own plan.
    ref.watch(authStateStreamProvider);
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyPlan);
    if (raw != null) {
      try {
        return jsonDecode(raw) as Map<String, dynamic>;
      } catch (e) {
        AppLog.warn('Plan', 'Saved plan unreadable, starting empty: $e');
      }
    }

    // Local cache empty (sign-out clears it, new device): use the cloud copy.
    final remote = await ref.read(supabaseServiceProvider).fetchPlan();
    if (remote != null) {
      await prefs.setString(_keyPlan, jsonEncode(remote));
    }
    return remote;
  }

  /// Returns true when a new plan was saved, false when every attempt failed
  /// (the previous plan, if any, stays on screen).
  Future<bool> generateAdaptivePlan({
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

    //4.  Retry for two time to call Stream function and write to storage
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      AppLog.info(
        'Plan',
        'Generating plan for $exerciseName '
            '(attempt $attempt/$maxAttempts)',
      );
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
          AppLog.warn('Plan', 'Supabase upsert skipped: $e');
        }

        /// 6. Change the state and ref.read will change the ui
        state = AsyncValue.data(parsed);
        AppLog.ok('Plan', 'Plan generated and saved');
        return true;
      } catch (e, st) {
        lastError = e;
        lastStack = st;
        AppLog.error('Plan', 'Attempt $attempt/$maxAttempts failed', e);
      }
    }
    AppLog.error(
      'Plan',
      'All attempts failed: '
          '${previous != null ? 'keeping previous plan' : 'no plan to show'}',
      lastError,
      lastStack,
    );

    // All attempts failed. Never blank-wipe a working plan: if one already
    // exists, keep it on screen. Only surface an error when there is nothing
    // to fall back to (e.g. the very first generation).
    // Preserve previous
    if (previous != null) {
      state = AsyncValue.data(previous);
    } else {
      state = AsyncValue.error(
        _friendlyError(lastError),
        lastStack ?? StackTrace.current,
      );
    }
    return false;
  }

  /// 5. Streams the Gemini plan, accumulates all chunks, then decodes into map. Throws a
  /// [FormatException] if the stream was empty or the JSON is incomplete.

  Future<Map<String, dynamic>> _streamAndParsePlan({
    required String exerciseName,
    required List<SetMetrics> sets,
    required UserProfileBiometrics biometrics,
    required List<String> sessionHistory,
  }) async {
    final buffer = StringBuffer();
    await for (final chunk // Call gemini provider
        in ref
            .read(geminiServiceProvider)
            .streamSessionAnalysis(
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
    //decode as Map
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

  //3. Refresh Button is trigger and call generate plan, saved the history and exercise name
  Future<void> refreshPlan({required UserProfileBiometrics biometrics}) async {
    final prefs = await SharedPreferences.getInstance();
    var history = prefs.getStringList(_keyHistory) ?? [];
    var exerciseName = prefs.getString(_keyLastExercise);

    // Local history is wiped on sign-out; fall back to the Supabase sessions
    // so a fresh login (e.g. the demo account) still gets a grounded plan.
    if (history.isEmpty) {
      final records = await ref.read(sessionHistoryProvider.future);
      final recent = records.length > 10
          ? records.sublist(records.length - 10)
          : records;
      history = [for (final r in recent) _summarise(r)];
      exerciseName ??= recent.isEmpty ? null : recent.last.exerciseName;
    }

    await generateAdaptivePlan(
      exerciseName: exerciseName ?? 'Squat',
      sets: const [],
      biometrics: biometrics,
      sessionHistory: history,
    );
  }

  /// Same shape as the local history lines SessionSummaryView writes.
  String _summarise(SessionRecord r) {
    final sets = [
      for (final (i, s) in r.sets.indexed)
        'Set ${i + 1}: ${s.reps} reps, form ${(s.formScore * 100).round()}%',
    ].join(' | ');
    return '${r.exerciseName} — $sets';
  }

  Future<void> clearPlan() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyPlan);
    await prefs.remove(_keyLastExercise);
    try {
      await ref.read(supabaseServiceProvider).deletePlan();
    } catch (e) {
      AppLog.warn('Plan', 'Supabase delete skipped: $e');
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
      AppLog.ok('Plan', 'Plan JSON written to: ${file.path}');
    } catch (e) {
      AppLog.warn('Plan', 'File write failed: $e');
    }
  }
}

final planProvider =
    AsyncNotifierProvider<PlanController, Map<String, dynamic>?>(
      PlanController.new,
    );
