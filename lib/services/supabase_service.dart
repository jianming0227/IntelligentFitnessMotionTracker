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
}
