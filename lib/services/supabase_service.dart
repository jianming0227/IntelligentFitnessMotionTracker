import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
    await _client.from('profiles').upsert(
      {
        'id': userId,
        'gender': gender,
        'age': age,
        'height_cm': heightCm,
        'weight_kg': weightKg,
        'goal': fitnessGoal,
        'experience_level': experienceLevel,
        'updated_at': DateTime.now().toIso8601String(),
      },
      onConflict: 'id',
    );
  }

  Future<void> upsertPlan({
    required Map<String, dynamic> planJson,
    required String exerciseName,
  }) async {
    final userId = currentUser?.id;
    if (userId == null) return;
    await _client.from('plans').upsert(
      {
        'user_id': userId,
        'plan_json': planJson,
        'exercise_name': exerciseName,
        'created_at': DateTime.now().toIso8601String(),
      },
      onConflict: 'user_id',
    );
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

  Future<void> insertWorkoutSession({
    required String exerciseName,
    required int setsCompleted,
    required List<Map<String, dynamic>> sessionData,
  }) async {
    final userId = currentUser?.id;
    // ignore: avoid_print
    print('[SupabaseService] insertWorkoutSession userId=$userId');
    if (userId == null) return;
    await _client.from('workout_sessions').insert({
      'user_id': userId,
      'exercise_type': exerciseName,
      'sets_completed': setsCompleted,
      'session_data': sessionData,
      'created_at': DateTime.now().toIso8601String(),
    });
  }
}
