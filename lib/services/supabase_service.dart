import 'package:supabase_flutter/supabase_flutter.dart';

// FR-1.1: Central auth service — wraps Supabase email/password auth operations.
class SupabaseService {
  final SupabaseClient _client = Supabase.instance.client;

  // FR-1.1: The currently signed-in user, or null if signed out
  User? get currentUser => _client.auth.currentUser;

  // FR-1.1: Stream that emits on every auth state change (sign in, sign out, token refresh)
  Stream<AuthState> get authStateChange => _client.auth.onAuthStateChange;

  // FR-1.1: Register a new user with email + password
  Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) {
    return _client.auth.signUp(email: email, password: password);
  }

  // FR-1.1: Log in an existing user
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) {
    return _client.auth.signInWithPassword(email: email, password: password);
  }

  // FR-1.1: Sign out the current user
  Future<void> signOut() => _client.auth.signOut();

  // FR-3.2: Persist or replace the latest adaptive plan for the current user.
  // Requires this table in Supabase (run once in the SQL Editor):
  //
  //   CREATE TABLE plans (
  //     id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  //     user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  //     plan_json JSONB NOT NULL,
  //     exercise_name TEXT NOT NULL,
  //     created_at TIMESTAMPTZ DEFAULT NOW()
  //   );
  //   ALTER TABLE plans ENABLE ROW LEVEL SECURITY;
  //   CREATE POLICY "own_plans" ON plans FOR ALL USING (auth.uid() = user_id);
  //   CREATE UNIQUE INDEX plans_user_idx ON plans (user_id);
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
