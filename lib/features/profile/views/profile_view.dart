import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/providers/auth_providers.dart';
import '../providers/profile_providers.dart';

/// FR-1.2: Profile screen — read-only summary of the biometric survey result
/// plus an "Update" CTA that re-opens the survey, and a sign-out action.
class ProfileView extends ConsumerWidget {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);
    final user = ref.watch(supabaseServiceProvider).currentUser;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: profileAsync.when(
          loading: () =>
              const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          error: (_, _) => const Center(child: Text('Could not load profile')),
          data: (profile) => ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              Text('Profile', style: tt.titleLarge),
              const SizedBox(height: 4),
              Text(user?.email ?? '', style: tt.bodyMedium),
              const SizedBox(height: 28),

              if (profile == null) ...[
                _MissingProfileCard(
                  onStart: () => context.push('/survey'),
                ),
              ] else ...[
                Text('Biometrics', style: tt.titleMedium),
                const SizedBox(height: 12),
                _StatTile(label: 'Gender', value: profile.gender),
                _StatTile(label: 'Age', value: '${profile.age}'),
                _StatTile(
                  label: 'Height',
                  value: '${profile.heightCm.toStringAsFixed(0)} cm',
                ),
                _StatTile(
                  label: 'Weight',
                  value: '${profile.weightKg.toStringAsFixed(0)} kg',
                ),
                _StatTile(label: 'Goal', value: profile.fitnessGoal),
                _StatTile(
                  label: 'Activity level',
                  value: profile.experienceLevel,
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () => context.push('/survey'),
                  icon: const Icon(Icons.tune_rounded, size: 20),
                  label: const Text('Update biometrics'),
                ),
              ],

              const SizedBox(height: 32),
              OutlinedButton.icon(
                onPressed: () =>
                    ref.read(authControllerProvider.notifier).signOut(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: cs.error,
                  side: BorderSide(color: cs.error),
                ),
                icon: const Icon(Icons.logout_rounded, size: 20),
                label: const Text('Sign out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: tt.bodyMedium?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.65),
              ),
            ),
          ),
          Text(value, style: tt.titleSmall),
        ],
      ),
    );
  }
}

class _MissingProfileCard extends StatelessWidget {
  const _MissingProfileCard({required this.onStart});
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.person_outline_rounded, color: cs.primary, size: 32),
          const SizedBox(height: 12),
          Text('Complete your profile', style: tt.titleMedium),
          const SizedBox(height: 6),
          Text(
            'Tell us about yourself so the AI coach can tailor every '
            'session to your goals.',
            style: tt.bodyMedium,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onStart,
            icon: const Icon(Icons.arrow_forward_rounded, size: 20),
            label: const Text('Start survey'),
          ),
        ],
      ),
    );
  }
}

