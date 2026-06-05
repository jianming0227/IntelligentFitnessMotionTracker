import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/constants/app_theme.dart';
import 'core/providers/theme_mode_provider.dart';
import 'features/auth/providers/auth_providers.dart';
import 'features/plan/controllers/plan_controller.dart';
import 'features/profile/providers/profile_providers.dart';
import 'router/app_router.dart';

class FitnessApp extends ConsumerWidget {
  const FitnessApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    // Invalidate per-user providers on every auth transition so stale data
    // from a previous account never bleeds into a new session. Without this,
    // Riverpod's in-memory cache keeps the old AsyncData alive even after
    // prefs.clear() on sign-out, and ref.listen in HomeView never fires.
    ref.listen(authStateStreamProvider, (_, __) {
      ref.invalidate(profileProvider);
      ref.invalidate(planProvider);
    });

    return MaterialApp.router(
      title: 'FitForm',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
