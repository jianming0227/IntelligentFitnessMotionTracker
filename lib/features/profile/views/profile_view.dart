import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/theme_mode_provider.dart';
import '../../../core/utils/display_name.dart';
import '../../auth/providers/auth_providers.dart';
import '../models/user_profile_biometrics.dart';
import '../providers/profile_providers.dart';

/// FR-1.2: Profile screen. Avatar + name, biometric stat cards, a settings
/// menu (edit biometrics, dark mode, about) and a sign-out tile.
class ProfileView extends ConsumerWidget {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);
    final email = ref.watch(supabaseServiceProvider).currentUser?.email;
    final name = displayNameFromEmail(email);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      body: Stack(
        children: [
          const Positioned(top: -70, right: -70, child: _Rings()),
          SafeArea(
            child: profileAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator(strokeWidth: 2)),
              error: (_, _) =>
                  const Center(child: Text('Could not load profile')),
              data: (profile) => ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                children: [
                  Center(child: Text('My Profile', style: tt.titleMedium)),
                  const SizedBox(height: 28),
                  Center(
                    child: _Avatar(
                      initial: name[0],
                      onEdit: () => context.push('/survey'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(child: Text(name, style: tt.titleLarge)),
                  if (email != null) ...[
                    const SizedBox(height: 2),
                    Center(child: Text(email, style: tt.bodyMedium)),
                  ],
                  const SizedBox(height: 28),

                  if (profile == null)
                    _MissingProfileCard(onStart: () => context.push('/survey'))
                  else ...[
                    _StatRow(profile: profile),
                    const SizedBox(height: 10),
                    _GoalLine(profile: profile),
                  ],

                  const SizedBox(height: 32),
                  _MenuTile(
                    icon: Icons.tune_rounded,
                    label: 'Edit biometrics',
                    onTap: () => context.push('/survey'),
                  ),
                  _MenuTile(
                    icon: Icons.dark_mode_rounded,
                    label: 'Dark mode',
                    trailing: Switch(
                      value: isDark,
                      onChanged: (on) =>
                          ref.read(themeModeProvider.notifier).state =
                              on ? ThemeMode.dark : ThemeMode.light,
                    ),
                  ),
                  _MenuTile(
                    icon: Icons.info_outline_rounded,
                    label: 'About FitForm',
                    onTap: () => showAboutDialog(
                      context: context,
                      applicationName: 'FitForm',
                      applicationLegalese:
                          'AI form coaching with on-device pose detection.',
                    ),
                  ),
                  const SizedBox(height: 24),
                  _MenuTile(
                    icon: Icons.logout_rounded,
                    label: 'Logout',
                    danger: true,
                    onTap: () =>
                        ref.read(authControllerProvider.notifier).signOut(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Faint concentric circles in the top-right corner, purely decorative.
class _Rings extends StatelessWidget {
  const _Rings();

  @override
  Widget build(BuildContext context) {
    final color =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.06);
    return IgnorePointer(
      child: SizedBox(
        width: 240,
        height: 240,
        child: Stack(
          alignment: Alignment.center,
          children: [
            for (final size in [240.0, 170.0, 100.0])
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: color),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.initial, required this.onEdit});

  final String initial;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: 112,
      height: 112,
      child: Stack(
        children: [
          Container(
            width: 112,
            height: 112,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: cs.primary.withValues(alpha: 0.15),
              border: Border.all(color: cs.primary, width: 2),
            ),
            child: Text(
              initial.toUpperCase(),
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                color: cs.primary,
                fontSize: 48,
              ),
            ),
          ),
          Positioned(
            right: 0,
            bottom: 4,
            child: Material(
              color: cs.primary,
              shape: CircleBorder(
                side: BorderSide(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  width: 3,
                ),
              ),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onEdit,
                child: Padding(
                  padding: const EdgeInsets.all(7),
                  child: Icon(Icons.edit_rounded, size: 16, color: cs.onPrimary),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.profile});
  final UserProfileBiometrics profile;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatCard(
          value: '${profile.weightKg.toStringAsFixed(0)} kg',
          label: 'Weight',
        ),
        const SizedBox(width: 10),
        _StatCard(value: '${profile.age}', label: 'Age'),
        const SizedBox(width: 10),
        _StatCard(
          value: '${profile.heightCm.toStringAsFixed(0)} cm',
          label: 'Height',
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: tt.titleLarge?.copyWith(color: cs.primary),
              ),
            ),
            const SizedBox(height: 4),
            Text(label, style: tt.labelSmall),
          ],
        ),
      ),
    );
  }
}

/// Goal, level and gender in one muted line under the stat cards.
class _GoalLine extends StatelessWidget {
  const _GoalLine({required this.profile});
  final UserProfileBiometrics profile;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        '${profile.fitnessGoal} · ${profile.experienceLevel} · '
        '${profile.gender}',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.label,
    this.onTap,
    this.trailing,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final accent = danger ? cs.error : cs.primary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: danger ? cs.error.withValues(alpha: 0.18) : cs.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 20, color: accent),
                ),
                const SizedBox(width: 14),
                Expanded(child: Text(label, style: tt.titleSmall)),
                trailing ??
                    Icon(
                      Icons.chevron_right_rounded,
                      color: cs.onSurface.withValues(alpha: 0.4),
                    ),
              ],
            ),
          ),
        ),
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
