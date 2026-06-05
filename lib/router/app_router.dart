import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/providers/demo_mode_provider.dart';
import '../features/auth/views/login_view.dart';
import '../features/auth/views/register_view.dart';
import '../features/home/views/home_view.dart';
import '../features/plan/views/plan_screen.dart';
import '../features/profile/views/biometric_survey_view.dart';
import '../features/profile/views/profile_view.dart';
import '../features/session/views/session_summary_view.dart';
import '../features/shell/views/app_shell.dart';
import '../features/train/models/exercise.dart';
import '../features/train/views/camera_view.dart';
import '../features/train/views/exercise_detail_view.dart';
import '../features/train/views/train_view.dart';

// Wraps a Dart Stream into a ChangeNotifier so GoRouter can re-run redirect
// every time auth state changes (sign in, sign out, token refresh).
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _sub = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/home',
    refreshListenable: GoRouterRefreshStream(
      Supabase.instance.client.auth.onAuthStateChange,
    ),
    redirect: (context, state) {
      // Demo mode bypasses all auth checks — local data only.
      final isDemo = ref.read(demoModeProvider);
      if (isDemo) return null;

      final isLoggedIn =
          Supabase.instance.client.auth.currentSession != null;
      final loc = state.matchedLocation;
      final onAuthScreen = loc == '/login' || loc == '/register';

      if (isLoggedIn && onAuthScreen) return '/home';
      if (!isLoggedIn && !onAuthScreen) return '/login';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, _) => const LoginView()),
      GoRoute(path: '/register', builder: (_, _) => const RegisterView()),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(path: '/home', builder: (_, _) => const HomeView()),
          GoRoute(path: '/train', builder: (_, _) => const TrainView()),
          GoRoute(path: '/plan', builder: (_, _) => const PlanScreen()),
          GoRoute(path: '/profile', builder: (_, _) => const ProfileView()),
        ],
      ),
      // Full-screen routes — no bottom nav
      GoRoute(
        path: '/survey',
        builder: (_, _) => const BiometricSurveyView(),
      ),
      GoRoute(
        path: '/train/detail',
        builder: (context, state) =>
            ExerciseDetailView(exercise: state.extra as Exercise),
      ),
      GoRoute(
        path: '/train/camera',
        builder: (context, state) =>
            CameraView(exercise: state.extra as Exercise),
      ),
      GoRoute(
        path: '/session/summary',
        builder: (context, state) =>
            SessionSummaryView(data: state.extra as SessionSummaryData),
      ),
    ],
  );
});
