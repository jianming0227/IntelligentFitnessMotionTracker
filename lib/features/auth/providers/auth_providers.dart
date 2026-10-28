import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/utils/app_log.dart';
import '../../../services/supabase_service.dart';

// A provider that creates and exposes a single SupabaseService instance
final supabaseServiceProvider = Provider<SupabaseService>((ref) {
  return SupabaseService();
});

// 1. Stream of auth state — emits every time the user signs in or out
final authStateStreamProvider = StreamProvider<AuthState>((ref) {
  final service = ref.watch(supabaseServiceProvider);
  return service.authStateChange;
});

// 2. The AuthController — handles signIn, signUp, signOut
class AuthController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final service = ref.read(supabaseServiceProvider);
      await service.signIn(email: email, password: password);
    });
    _log('Sign-in');
  }

  Future<void> signUp({
    required String email,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final service = ref.read(supabaseServiceProvider);
      await service.signUp(email: email, password: password);
    });
    _log('Sign-up');
  }

  Future<void> signOut() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final service = ref.read(supabaseServiceProvider);
      await service.signOut();
    });
    _log('Sign-out');
  }

  // Email and password are never logged — only the outcome.
  void _log(String action) {
    if (state.hasError) {
      AppLog.error('Auth', '$action failed', state.error, state.stackTrace);
    } else {
      AppLog.ok('Auth', '$action succeeded');
    }
  }
}

final authControllerProvider = AsyncNotifierProvider<AuthController, void>(
  AuthController.new,
);
