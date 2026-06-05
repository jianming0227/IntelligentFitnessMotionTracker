import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../profile/models/user_profile_biometrics.dart';
import '../../profile/providers/profile_providers.dart';
import '../controllers/plan_controller.dart';
import '../widgets/dynamic_ui_parser.dart';

/// FR-3.2: Dedicated Plan tab — renders the server-driven adaptive plan.
/// The refresh FAB re-runs the full Gemini generation flow using the stored
/// session history and current biometric profile.
class PlanScreen extends ConsumerWidget {
  const PlanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final planAsync = ref.watch(planProvider);
    final isLoading = planAsync.isLoading;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Row(
                children: [
                  Text('Schedule', style: tt.titleLarge),
                  const Spacer(),
                  Icon(Icons.auto_awesome, color: cs.primary, size: 20),
                ],
              ),
            ),
            Expanded(
              child: planAsync.when(
                loading: () => _LoadingView(),
                error: (err, _) =>
                    _ErrorView(error: err, onRetry: () => _refresh(ref)),
                data: (json) => json == null || json.isEmpty
                    ? const _EmptyView()
                    : buildDynamicWidget(
                        json,
                        context,
                        onRefresh: isLoading ? null : () => _refresh(ref),
                        isLoading: isLoading,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _refresh(WidgetRef ref) {
    final biometrics =
        ref.read(profileProvider).value ?? UserProfileBiometrics.defaults;
    ref.read(planProvider.notifier).refreshPlan(biometrics: biometrics);
  }
}

// ── Async state views ─────────────────────────────────────────────────────────

class _LoadingView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 56,
              height: 56,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: cs.primary,
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'AI Coach is analyzing metrics\nand calculating optimal rest variables…',
              style: tt.bodyLarge?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.75),
                height: 1.45,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});
  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, color: cs.error, size: 52),
            const SizedBox(height: 16),
            Text('Could not generate plan', style: tt.titleMedium),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              style: tt.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh_rounded, size: 20),
              label: const Text('Retry'),
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.calendar_today_rounded,
                  color: cs.primary, size: 36),
            ),
            const SizedBox(height: 20),
            Text('No active adaptive routine', style: tt.titleMedium),
            const SizedBox(height: 10),
            Text(
              'Head to the Train tab to log your first exercise session and activate your personalized AI coaching engine.',
              style: tt.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
