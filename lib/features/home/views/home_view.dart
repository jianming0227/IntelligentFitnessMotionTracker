import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_text_styles.dart';
import '../../../core/providers/theme_mode_provider.dart';
import '../../../core/utils/display_name.dart';
import '../../auth/providers/auth_providers.dart';
import '../../profile/models/user_profile_biometrics.dart';
import '../../profile/providers/profile_providers.dart';
import '../../progress/logic/progress_stats.dart';
import '../../progress/providers/progress_providers.dart';
import '../../train/models/exercise.dart';

/// Workouts per week that count as 100% on the This Week ring. The app does
/// not store a personal goal yet, so this is one shared number.
const _weeklyGoal = 4;

// FR-3.2 / E4: Home. Greeting, "Select your training" carousel, this week's
// progress ring and quick actions.
class HomeView extends ConsumerWidget {
  const HomeView({super.key});

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning';
    if (h < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final name = displayNameFromEmail(
      ref.watch(supabaseServiceProvider).currentUser?.email,
    );

    // First-time onboarding: when the profile resolves and is null, send the
    // user through the biometric survey. `ref.listen` only fires on state
    // changes, so this doesn't loop after the survey saves.
    ref.listen(profileProvider, (prev, next) {
      next.whenData((profile) {
        if (profile == null) context.go('/survey');
      });
    });

    final weightKg =
        (ref.watch(profileProvider).value ?? UserProfileBiometrics.defaults)
            .weightKg;
    // Loading or failed history shows an empty week instead of a spinner.
    final records = ref.watch(sessionHistoryProvider).value ?? const [];
    final week = weekStats(records, DateTime.now(), weightKg);

    // The carousel is the only child that bleeds past the 20px content gutter
    // (neighbour cards peek on the right). Everything else stays inside the
    // gutter so headers, panels, and the carousel's *focused* card share the
    // same left edge.
    const gutter = 20.0;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          // Bottom padding clears the floating nav bar.
          padding: const EdgeInsets.only(bottom: 120),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(gutter, 8, gutter, 0),
              child: _GreetingHeader(
                greeting: _greeting(),
                name: name,
                isDark: isDark,
                onToggleTheme: () {
                  ref.read(themeModeProvider.notifier).state = isDark
                      ? ThemeMode.light
                      : ThemeMode.dark;
                },
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: gutter),
              child: _WeekProgressCard(
                week: week,
                onViewAll: () => context.go('/progress'),
              ),
            ),
            const SizedBox(height: 24),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: gutter),
              child: _TrainingLabel(),
            ),
            const SizedBox(height: 14),
            const Padding(
              padding: EdgeInsets.only(left: gutter),
              child: _ExerciseCarousel(),
            ),
            const SizedBox(height: 20),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: gutter),
              child: _SectionTitle('Quick Actions'),
            ),
            const SizedBox(height: 12),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: gutter),
              child: _QuickActions(),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Header: greeting + name + (theme toggle / avatar) ─────────────────────────

class _GreetingHeader extends StatelessWidget {
  const _GreetingHeader({
    required this.greeting,
    required this.name,
    required this.isDark,
    required this.onToggleTheme,
  });

  final String greeting;
  final String name;
  final bool isDark;
  final VoidCallback onToggleTheme;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return SizedBox(
      height: 76,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting,
                  style: tt.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    name,
                    maxLines: 1,
                    softWrap: false,
                    style: tt.displayMedium?.copyWith(
                      fontSize: 30,
                      height: 1.1,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _ThemeToggleButton(isDark: isDark, onTap: onToggleTheme),
          const SizedBox(width: 10),
          _AvatarBubble(initial: name.isNotEmpty ? name[0] : '?'),
        ],
      ),
    );
  }
}

class _ThemeToggleButton extends StatelessWidget {
  const _ThemeToggleButton({required this.isDark, required this.onTap});

  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainerHighest,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(
            isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            size: 20,
            color: cs.primary,
          ),
        ),
      ),
    );
  }
}

class _AvatarBubble extends StatelessWidget {
  const _AvatarBubble({required this.initial});

  final String initial;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 52,
      height: 52,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: cs.primary, shape: BoxShape.circle),
      child: Text(
        initial,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          color: cs.onPrimary,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

// ── "SELECT YOUR TRAINING" label ─────────────────────────────────────────────

class _TrainingLabel extends StatelessWidget {
  const _TrainingLabel();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = cs.onSurface.withValues(alpha: 0.7);
    return Row(
      children: [
        Icon(Icons.keyboard_double_arrow_right_rounded, size: 20, color: color),
        const SizedBox(width: 6),
        Text(
          'SELECT YOUR TRAINING',
          style: AppTextStyles.button.copyWith(
            color: cs.onSurface,
            fontSize: 16,
            letterSpacing: 1.2,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }
}

// ── Exercise carousel ─────────────────────────────────────────────────────────

class _ExerciseCarousel extends StatefulWidget {
  const _ExerciseCarousel();

  @override
  State<_ExerciseCarousel> createState() => _ExerciseCarouselState();
}

class _ExerciseCarouselState extends State<_ExerciseCarousel> {
  late final PageController _controller;
  double _page = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController(viewportFraction: 0.82);
    _controller.addListener(() {
      setState(() => _page = _controller.page ?? 0);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 340,
      child: PageView.builder(
        controller: _controller,
        padEnds: false,
        itemCount: Exercise.all.length,
        itemBuilder: (context, i) {
          // Focused card = scale 1.0; neighbours shrink to 0.9 and dim slightly.
          final delta = (_page - i).abs().clamp(0.0, 1.0);
          final scale = 1.0 - delta * 0.1;
          final opacity = 1.0 - delta * 0.25;
          return Padding(
            padding: const EdgeInsets.fromLTRB(0, 12, 14, 12),
            child: Transform.scale(
              scale: scale,
              alignment: Alignment.center,
              child: Opacity(
                opacity: opacity,
                child: _ExerciseCard(exercise: Exercise.all[i]),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Per-exercise hero photo + framing controls. Edit one entry to retune just
/// that card; missing entries fall back to the emoji-gradient placeholder.
///
/// - [alignment]   which part of the photo stays visible under BoxFit.cover
///                 (x, y) range −1 to +1; (0, +0.35) bias toward the bottom.
/// - [scale]       1.0 = no zoom. >1 enlarges the photo (clipped by the card).
/// - [scaleAlignment] pivot point for the zoom — usually match [alignment].
class _CardImageConfig {
  const _CardImageConfig({
    required this.path,
    this.alignment = Alignment.center,
    this.scale = 1.0,
    this.scaleAlignment = Alignment.center,
  });

  final String path;
  final Alignment alignment;
  final double scale;
  final Alignment scaleAlignment;
}

const Map<String, _CardImageConfig> _exerciseImages = {
  'squat': _CardImageConfig(
    path: 'assets/images/squat.png',
    alignment: Alignment(0, 0.35),
    scale: 1.4,
    scaleAlignment: Alignment(-1, 0.5),
  ),
  'bicep_curl': _CardImageConfig(
    path: 'assets/images/bicep.png',
    alignment: Alignment(0, 0),
    scale: 1.4,
    scaleAlignment: Alignment(-1.01, -0.5),
  ),
};

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({required this.exercise});

  final Exercise exercise;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tt = Theme.of(context).textTheme;
    final image = _exerciseImages[exercise.id];

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: () => context.push('/train/detail', extra: exercise),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _CardBackground(
                config: image,
                fallbackEmoji: exercise.emoji,
                isDark: isDark,
              ),
              // Foreground gradient — darkens the bottom so the kcal stat
              // and description stay readable over any photo.
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0xCC000000)],
                    stops: [0.45, 1.0],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exercise.name.toUpperCase(),
                      style: tt.displayMedium?.copyWith(
                        fontSize: 30,
                        height: 1.05,
                        color: Colors.white,
                        shadows: const [
                          Shadow(
                            blurRadius: 8,
                            color: Color(0x66000000),
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: cs.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Text(
                            '🔥',
                            style: TextStyle(fontSize: 18),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${(exercise.targetAngleMax * 2.5).round()}',
                              style: tt.titleLarge?.copyWith(
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'kcal',
                              style: tt.bodyMedium?.copyWith(
                                color: Colors.white.withValues(alpha: 0.75),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      exercise.description,
                      style: tt.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Card background: real photo (driven by [_CardImageConfig]) if available,
/// otherwise an emoji-on-gradient placeholder. Either way it fills the parent.
class _CardBackground extends StatelessWidget {
  const _CardBackground({
    required this.config,
    required this.fallbackEmoji,
    required this.isDark,
  });

  final _CardImageConfig? config;
  final String fallbackEmoji;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final fallback = _FallbackBackground(emoji: fallbackEmoji, isDark: isDark);
    final cfg = config;
    if (cfg == null) return fallback;
    return Transform.scale(
      scale: cfg.scale,
      alignment: cfg.scaleAlignment,
      child: Image.asset(
        cfg.path,
        fit: BoxFit.cover,
        alignment: cfg.alignment,
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }
}

class _FallbackBackground extends StatelessWidget {
  const _FallbackBackground({required this.emoji, required this.isDark});

  final String emoji;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final colors = isDark
        ? const [Color(0xFF2A2D34), Color(0xFF0F1115)]
        : const [Color(0xFFE9ECEF), Color(0xFFCBD0D8)];
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -10,
            bottom: -10,
            child: Text(emoji, style: const TextStyle(fontSize: 180)),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, {this.onViewAll});

  final String title;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        if (onViewAll != null)
          TextButton(
            onPressed: onViewAll,
            style: TextButton.styleFrom(
              foregroundColor: cs.primary,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('View All'),
          ),
      ],
    );
  }
}

// ── This Week Progress ───────────────────────────────────────────────────────

class _WeekProgressCard extends StatelessWidget {
  const _WeekProgressCard({required this.week, required this.onViewAll});

  final WeekStats week;
  final VoidCallback onViewAll;

  static String _duration(Duration d) {
    if (d == Duration.zero) return '–';
    final h = d.inHours;
    final m = d.inMinutes % 60;
    if (h == 0) return m == 0 ? '<1m' : '${m}m';
    return '${h}h ${m.toString().padLeft(2, '0')}m';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final progress = (week.sessions / _weeklyGoal).clamp(0.0, 1.0);
    final kcal = week.kcal;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 10, 12, 18),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          _SectionTitle('This Week Progress', onViewAll: onViewAll),
          const SizedBox(height: 10),
          Row(
            children: [
              SizedBox(
                width: 132,
                height: 132,
                child: CustomPaint(
                  painter: _RingPainter(
                    progress: progress,
                    track: cs.onSurface.withValues(alpha: 0.12),
                    arc: cs.primary,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${(progress * 100).round()}%',
                          style: tt.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Completed',
                          style: tt.bodySmall?.copyWith(
                            color: cs.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _StatRow(
                      icon: Icons.fitness_center_rounded,
                      label: 'Workouts',
                      value: '${week.sessions} / $_weeklyGoal',
                    ),
                    const SizedBox(height: 12),
                    _StatRow(
                      icon: Icons.local_fire_department_rounded,
                      label: 'Calories',
                      value: kcal == null ? '–' : '${kcal.round()}',
                      unit: kcal == null ? null : 'kcal',
                    ),
                    const SizedBox(height: 12),
                    _StatRow(
                      icon: Icons.schedule_rounded,
                      label: 'Duration',
                      value: _duration(week.activeTime),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.icon,
    required this.label,
    required this.value,
    this.unit,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? unit;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final muted = cs.onSurface.withValues(alpha: 0.55);
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: cs.primary.withValues(alpha: 0.14),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 18, color: cs.primary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: tt.bodySmall?.copyWith(color: muted)),
              Text.rich(
                TextSpan(
                  text: value,
                  style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                  children: [
                    if (unit != null)
                      TextSpan(
                        text: ' $unit',
                        style: tt.bodySmall?.copyWith(color: muted),
                      ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress, required this.track, required this.arc});

  /// 0–1.
  final double progress;
  final Color track;
  final Color arc;

  static const _stroke = 12.0;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(_stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, 2 * math.pi, false, paint..color = track);
    if (progress > 0) {
      canvas.drawArc(
        rect,
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        paint..color = arc,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.track != track || old.arc != arc;
}

// ── Quick Actions ────────────────────────────────────────────────────────────

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ActionTile(
          icon: Icons.fitness_center_rounded,
          title: 'Workouts',
          subtitle: 'Explore',
          onTap: () => context.go('/train'),
        ),
        const SizedBox(width: 10),
        _ActionTile(
          icon: Icons.calendar_month_rounded,
          title: 'My Plan',
          subtitle: 'View',
          onTap: () => context.go('/plan'),
        ),
        const SizedBox(width: 10),
        _ActionTile(
          icon: Icons.insights_rounded,
          title: 'Progress',
          subtitle: 'Track',
          onTap: () => context.go('/progress'),
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Expanded(
      child: Material(
        color: cs.surface,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
            child: Column(
              children: [
                Icon(icon, color: cs.primary, size: 26),
                const SizedBox(height: 10),
                Text(
                  title,
                  style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: tt.bodySmall?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
