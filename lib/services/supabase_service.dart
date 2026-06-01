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
}
