import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/friendly_error.dart';
import '../../profile/models/user_profile_biometrics.dart';
import '../../profile/providers/profile_providers.dart';
import '../../progress/providers/progress_providers.dart';
import '../controllers/plan_controller.dart';
import '../widgets/dynamic_ui_parser.dart';

/// FR-3.2: Dedicated Plan tab — renders the server-driven adaptive plan.
/// Pull-to-refresh re-runs the full Gemini generation flow using the stored
/// session history and current biometric profile.
class PlanScreen extends ConsumerWidget {
  const PlanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final planAsync = ref.watch(planProvider);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    // Calendar rings and month stats come from session history.
    final records = ref.watch(sessionHistoryProvider).value ?? const [];
    final weightKg =
        (ref.watch(profileProvider).value ?? UserProfileBiometrics.defaults)
            .weightKg;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Row(children: [Text('Schedule', style: tt.titleLarge)]),
            ),
            Expanded(
              //1. User clicked on the Generate Plan Button
              child: planAsync.when(
                loading: () => _LoadingView(),
                error: (err, _) =>
                    _ErrorView(error: err, onRetry: () => _refresh(ref)),
                data: (json) => json == null || json.isEmpty
                    /// 7. Receive the decoded json and pass to parser to call buildDynamicWidget
                    ? _EmptyView(onGenerate: () => _refresh(ref))
                    // Pull down to regenerate. Returns at once: the loading
                    // view takes over while Gemini works.
                    : RefreshIndicator(
                        color: cs.primary,
                        onRefresh: () async => _refresh(ref),
                        child: buildDynamicWidget(
                          json,
                          context,
                          records: records,
                          weightKg: weightKg,
                          onPlanChanged: ref
                              .read(planProvider.notifier)
                              .saveEditedPlan,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  //2. Trigger the plan provider to listen and call refreshPlan together with the biometric profile
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
              friendlyError(error),
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
  const _EmptyView({required this.onGenerate});
  final VoidCallback onGenerate;

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
              child: Icon(
                Icons.calendar_today_rounded,
                color: cs.primary,
                size: 36,
              ),
            ),
            const SizedBox(height: 20),
            Text('No active adaptive routine', style: tt.titleMedium),
            const SizedBox(height: 10),
            Text(
              'Generate a plan from your workout history, or tap the play button to log a session first.',
              style: tt.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.auto_awesome, size: 20),
              label: const Text('Generate plan'),
              onPressed: onGenerate,
            ),
          ],
        ),
      ),
    );
  }
}
