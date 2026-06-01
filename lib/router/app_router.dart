import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/auth/views/login_view.dart';
import '../features/auth/views/register_view.dart';
import '../features/home/views/home_view.dart';
import '../features/session/views/session_summary_view.dart';
import '../features/train/models/exercise.dart';
import '../features/train/views/camera_view.dart';
import '../features/train/views/train_view.dart';
import '../features/profile/views/profile_view.dart';
import '../features/shell/views/app_shell.dart';

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
      final isLoggedIn =
          Supabase.instance.client.auth.currentSession != null;
      final loc = state.matchedLocation;
      final onAuthScreen = loc == '/login' || loc == '/register';

      // Logged in but on login/register → push to home
      if (isLoggedIn && onAuthScreen) return '/home';
      // Not logged in but trying to reach a protected screen → push to login
      if (!isLoggedIn && !onAuthScreen) return '/login';
      // No redirect needed
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
          GoRoute(path: '/profile', builder: (_, _) => const ProfileView()),
        ],
      ),
      // Camera screen is outside the shell so it is full-screen (no bottom nav)
      GoRoute(
        path: '/train/camera',
        builder: (context, state) =>
            CameraView(exercise: state.extra as Exercise),
      ),
      // Session summary is full-screen (no bottom nav); receives SessionSummaryData via extra
      GoRoute(
        path: '/session/summary',
        builder: (context, state) =>
            SessionSummaryView(data: state.extra as SessionSummaryData),
      ),
    ],
  );
});
