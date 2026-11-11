import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/utils/app_log.dart';
import '../features/plan/logic/plan_edits.dart';
import '../features/plan/logic/plan_sync.dart';

// FR-1.1: Central auth service — wraps Supabase email/password auth operations.
class SupabaseService {
  final SupabaseClient _client = Supabase.instance.client;

  User? get currentUser => _client.auth.currentUser;

  Stream<AuthState> get authStateChange => _client.auth.onAuthStateChange;

  Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) {
    return _client.auth.signUp(email: email, password: password);
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) {
    return _client.auth.signInWithPassword(email: email, password: password);
  }

  // Clears all local SharedPreferences on sign-out so the next user starts
  // fresh — prevents data leaking between accounts on the same device.
  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await _client.auth.signOut();
  }

  Future<void> upsertProfile({
    required String userId,
    required String gender,
    required int age,
    required double heightCm,
    required double weightKg,
    required String fitnessGoal,
    required String experienceLevel,
  }) async {
    await _client.from('profiles').upsert({
      'id': userId,
      'gender': gender,
      'age': age,
      'height_cm': heightCm,
      'weight_kg': weightKg,
      'goal': fitnessGoal,
      'experience_level': experienceLevel,
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'id');
  }

  /// Saves the active plan JSON, then mirrors its cards into `plan_sessions`
  /// (one dated row per card). Call with a plan from `withCardIds`.
  Future<void> upsertPlan({
    required Map<String, dynamic> planJson,
    required String exerciseName,
  }) async {
    final userId = currentUser?.id;
    if (userId == null) return;
    final saved = await _client
        .from('plans')
        .upsert({
          'user_id': userId,
          'plan_json': planJson,
          'exercise_name': exerciseName,
          'created_at': DateTime.now().toIso8601String(),
        }, onConflict: 'user_id')
        .select('id')
        .single();
    try {
      await _syncPlanSessions(userId, saved['id'] as String?, planJson);
    } catch (e) {
      // Plan JSON is saved; the dated mirror catches up on the next save.
      AppLog.warn('Supabase', 'plan_sessions sync skipped: $e');
    }
  }

  /// Upserts one row per card, then removes rows for upcoming cards that are
  /// no longer in the plan (deleted, or replaced by a new plan). Past rows
  /// and done rows are kept: they are the plan history.
  Future<void> _syncPlanSessions(
    String userId,
    String? planId,
    Map<String, dynamic> planJson,
  ) async {
    final rows = planSessionRows(planJson, userId: userId, planId: planId);
    if (rows.isNotEmpty) {
      await _client.from('plan_sessions').upsert(rows, onConflict: 'id');
    }
    final today = isoDay(DateTime.now());
    var stale = _client
        .from('plan_sessions')
        .delete()
        .eq('user_id', userId)
        .gte('session_date', today)
        .neq('status', 'done');
    if (rows.isNotEmpty) {
      stale = stale.not('id', 'in', '(${rows.map((r) => r['id']).join(',')})');
    }
    await stale;
    AppLog.ok('Supabase', 'plan_sessions synced (${rows.length} cards)');
  }

  /// Marks one planned workout done and links the finished session to it.
  Future<void> markPlanSessionDone({
    required String planSessionId,
    required String? workoutSessionId,
  }) async {
    if (currentUser == null) return;
    await _client
        .from('plan_sessions')
        .update({
          'status': 'done',
          'completed_session_id': ?workoutSessionId,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', planSessionId);
  }

  /// Planned workouts between [from] and [to] (inclusive), by date.
  Future<List<Map<String, dynamic>>> fetchPlanSessions({
    required DateTime from,
    required DateTime to,
  }) async {
    final userId = currentUser?.id;
    if (userId == null) return const [];
    return _client
        .from('plan_sessions')
        .select()
        .eq('user_id', userId)
        .gte('session_date', isoDay(from))
        .lte('session_date', isoDay(to))
        .order('session_date');
  }

  /// Signed-in user's saved plan JSON. Null when there is no user, no plan,
  /// or the request fails (caller keeps the empty state).
  Future<Map<String, dynamic>?> fetchPlan() async {
    final userId = currentUser?.id;
    if (userId == null) return null;
    try {
      final rows = await _client
          .from('plans')
          .select('plan_json')
          .eq('user_id', userId)
          .limit(1);
      if (rows.isEmpty) return null;
      AppLog.ok('Supabase', 'Loaded saved plan');
      return rows.first['plan_json'] as Map<String, dynamic>?;
    } catch (e) {
      AppLog.warn('Supabase', 'Plan fetch failed: $e');
      return null;
    }
  }

  Future<void> deletePlan() async {
    final userId = currentUser?.id;
    if (userId == null) return;
    await _client.from('plans').delete().eq('user_id', userId);
  }

  Future<Map<String, dynamic>?> fetchProfile() async {
    final userId = currentUser?.id;
    if (userId == null) return null;
    final rows = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .limit(1);
    if (rows.isEmpty) return null;
    return rows.first;
  }

  /// Signed-in user's sessions from the last [days] days, oldest first.
  /// Null when there is no user or the request fails (caller falls back to
  /// local history).
  Future<List<Map<String, dynamic>>?> fetchWorkoutSessions({
    int days = 90,
  }) async {
    final userId = currentUser?.id;
    if (userId == null) return null;
    try {
      final since = DateTime.now().subtract(Duration(days: days));
      final rows = await _client
          .from('workout_sessions')
          .select()
          .eq('user_id', userId)
          .gte('created_at', since.toIso8601String())
          .order('created_at');
      AppLog.ok('Supabase', 'Loaded ${rows.length} sessions');
      return rows;
    } catch (e) {
      AppLog.warn('Supabase', 'Session history fetch failed: $e');
      return null;
    }
  }

  /// Saves a finished workout and returns its id (null with no signed-in
  /// user). [planSessionId] links it to the plan card it was started from.
  Future<String?> insertWorkoutSession({
    required String exerciseName,
    required int setsCompleted,
    required List<Map<String, dynamic>> sessionData,
    String? planSessionId,
  }) async {
    final userId = currentUser?.id;
    if (userId == null) {
      AppLog.warn('Supabase', 'Session not saved: no signed-in user (demo?)');
      return null;
    }
    final row = await _client
        .from('workout_sessions')
        .insert({
          'user_id': userId,
          'exercise_type': exerciseName,
          'sets_completed': setsCompleted,
          'session_data': sessionData,
          'created_at': DateTime.now().toIso8601String(),
          'plan_session_id': ?planSessionId,
        })
        .select('id')
        .single();
    AppLog.ok('Supabase', 'Session saved: $exerciseName, $setsCompleted sets');
    return row['id'] as String?;
  }
}
