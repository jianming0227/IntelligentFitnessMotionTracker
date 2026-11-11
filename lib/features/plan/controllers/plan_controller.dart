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
import '../logic/plan_edits.dart';
import '../logic/plan_merge.dart';
import '../logic/plan_sync.dart';

/// Result of a plan update.
/// * added: new day(s) planned and saved
/// * upToDate: the next days were already planned, nothing was called
/// * failed: generation failed, the existing plan stays
enum PlanUpdate { added, upToDate, failed }

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
        return _withIds(prefs, jsonDecode(raw) as Map<String, dynamic>);
      } catch (e) {
        AppLog.warn('Plan', 'Saved plan unreadable, starting empty: $e');
      }
    }

    // Local cache empty (sign-out clears it, new device): use the cloud copy.
    final remote = await ref.read(supabaseServiceProvider).fetchPlan();
    if (remote == null) return null;
    return _withIds(prefs, remote);
  }

  /// Plans saved before card ids existed get ids once, stored locally so they
  /// stay the same; Supabase gets them on the next save.
  Future<Map<String, dynamic>> _withIds(
    SharedPreferences prefs,
    Map<String, dynamic> plan,
  ) async {
    final withIds = withCardIds(plan, DateTime.now());
    await prefs.setString(_keyPlan, jsonEncode(withIds));
    return withIds;
  }

  /// Rolling update (see plan_merge.dart): plans only the window days that
  /// need it and merges them into the existing plan. [replanTomorrow] is set
  /// after a workout so tomorrow's untouched AI card can adapt to it.
  ///
  /// [PlanUpdate.upToDate] means nothing needed planning (no AI call). On
  /// failure the existing plan stays on screen.
  Future<PlanUpdate> generateAdaptivePlan({
    required String exerciseName,
    required List<SetMetrics> sets,
    required UserProfileBiometrics biometrics,
    required List<String> sessionHistory,
    bool replanTomorrow = false,
  }) async {
    final now = DateTime.now();
    final previous = state.valueOrNull;
    final dates = datesToPlan(previous, now, replanTomorrow: replanTomorrow);
    if (dates.isEmpty) {
      AppLog.info('Plan', 'Next $planWindowDays days already planned');
      return PlanUpdate.upToDate;
    }

    // Offline demo mode: the Gemini function needs a signed-in user, so fill
    // the gaps by rule instead.
    if (Supabase.instance.client.auth.currentSession == null) {
      final merged = mergeGenerated(
        previous,
        ruleBasedCards(previous, dates, now),
        dates,
        now,
      );
      await _save(merged, exerciseName);
      AppLog.ok('Plan', 'Offline plan filled for ${dates.length} day(s)');
      return PlanUpdate.added;
    }

    // B7: the user's own changes, so Gemini doesn't undo them.
    final userEdits = describeUserEdits(previous);
    final alreadyPlanned = describeUpcoming(previous, now);
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
        'Planning ${dates.length} day(s) after $exerciseName '
            '(attempt $attempt/$maxAttempts)',
      );
      try {
        final generated = await _streamAndParsePlan(
          exerciseName: exerciseName,
          sets: sets,
          biometrics: biometrics,
          sessionHistory: sessionHistory,
          userEdits: userEdits,
          datesToPlan: dates,
          alreadyPlanned: alreadyPlanned,
        );
        // Existing cards stay; only the planned dates change.
        await _save(
          mergeGenerated(previous, generated, dates, now),
          exerciseName,
        );
        AppLog.ok('Plan', 'Planned ${dates.length} day(s) and saved');
        return PlanUpdate.added;
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
    if (previous != null) {
      state = AsyncValue.data(previous);
    } else {
      state = AsyncValue.error(
        _friendlyError(lastError),
        lastStack ?? StackTrace.current,
      );
    }
    return PlanUpdate.failed;
  }

  /// Card ids + exact dates, then local cache, JSON file and Supabase
  /// (plans + plan_sessions mirror).
  Future<void> _save(Map<String, dynamic> merged, String exerciseName) async {
    final plan = withCardIds(merged, DateTime.now());
    final jsonString = jsonEncode(plan);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPlan, jsonString);
    await prefs.setString(_keyLastExercise, exerciseName);
    await _writeJsonFile(jsonString);
    try {
      await ref
          .read(supabaseServiceProvider)
          .upsertPlan(planJson: plan, exerciseName: exerciseName);
    } catch (e) {
      AppLog.warn('Plan', 'Supabase upsert skipped: $e');
    }

    /// 6. Change the state and ref.read will change the ui
    state = AsyncValue.data(plan);
  }

  /// 5. Streams the Gemini plan, accumulates all chunks, then decodes into map. Throws a
  /// [FormatException] if the stream was empty or the JSON is incomplete.
  Future<Map<String, dynamic>> _streamAndParsePlan({
    required String exerciseName,
    required List<SetMetrics> sets,
    required UserProfileBiometrics biometrics,
    required List<String> sessionHistory,
    required List<String> userEdits,
    required List<DateTime> datesToPlan,
    required List<String> alreadyPlanned,
  }) async {
    final buffer = StringBuffer();
    await for (final chunk // Call gemini provider
        in ref
            .read(geminiServiceProvider)
            .streamSessionAnalysis(
              exerciseName: exerciseName,
              sets: sets,
              previousSessionSummaries: sessionHistory,
              userEdits: userEdits,
              biometrics: biometrics,
              currentLocalTime: DateTime.now(),
              datesToPlan: datesToPlan,
              alreadyPlanned: alreadyPlanned,
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
  Future<PlanUpdate> refreshPlan({
    required UserProfileBiometrics biometrics,
  }) async {
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

    // Pull-to-refresh only fills empty days (no re-plan without a workout).
    return generateAdaptivePlan(
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

  /// Saves a plan the user edited by hand (local first, Supabase best-effort).
  Future<void> saveEditedPlan(Map<String, dynamic> edited) async {
    final plan = withCardIds(edited, DateTime.now()); // added cards get ids
    state = AsyncValue.data(plan);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPlan, jsonEncode(plan));
    try {
      await ref
          .read(supabaseServiceProvider)
          .upsertPlan(
            planJson: plan,
            exerciseName: prefs.getString(_keyLastExercise) ?? 'Squat',
          );
    } catch (e) {
      AppLog.warn('Plan', 'Supabase upsert of edited plan skipped: $e');
    }
    AppLog.ok('Plan', 'Edited plan saved');
  }

  /// A workout of [exerciseName] finished. Ticks the plan card it belongs to:
  /// [planSessionId] when started from a card's Play, otherwise today's
  /// not-done card of the same exercise (started from the Train tab).
  Future<void> markWorkoutDone({
    required String exerciseName,
    required String? planSessionId,
    required String? workoutSessionId,
  }) async {
    final cardId =
        planSessionId ??
        todayCardIdFor(state.valueOrNull, exerciseName, DateTime.now());
    if (cardId == null) return;
    await markSessionDone(cardId, workoutSessionId);
  }

  /// Marks card [cardId] done in Supabase (linked to [workoutSessionId]) and
  /// ticks it locally.
  Future<void> markSessionDone(String cardId, String? workoutSessionId) async {
    try {
      await ref
          .read(supabaseServiceProvider)
          .markPlanSessionDone(
            planSessionId: cardId,
            workoutSessionId: workoutSessionId,
          );
    } catch (e) {
      AppLog.warn('Plan', 'plan_sessions done update skipped: $e');
    }
    // While a new plan is generating, leave the state alone: the server row
    // is already done, and the new plan replaces these cards anyway.
    final plan = state.valueOrNull;
    if (state.isLoading || plan == null) return;
    final updated = markCardDone(plan, cardId, workoutSessionId);
    if (updated != null) await saveEditedPlan(updated);
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
