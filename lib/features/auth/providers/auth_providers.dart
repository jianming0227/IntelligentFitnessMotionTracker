import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
    // No initial loading needed — we just track future actions
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
  }

  Future<void> signOut() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final service = ref.read(supabaseServiceProvider);
      await service.signOut();
    });
  }
}

final authControllerProvider = AsyncNotifierProvider<AuthController, void>(
  AuthController.new,
);
