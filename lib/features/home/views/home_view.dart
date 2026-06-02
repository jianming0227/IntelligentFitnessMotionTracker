import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_text_styles.dart';
import '../../../core/providers/theme_mode_provider.dart';
import '../../auth/providers/auth_providers.dart';
import '../../profile/providers/profile_providers.dart';
import '../../train/models/exercise.dart';

// FR-3.2: Home — greets the user, surfaces a "Select Your Training" carousel
// of supported exercises, and points the user at their AI-personalised plan.
class HomeView extends ConsumerWidget {
  const HomeView({super.key});

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning';
    if (h < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  String _displayName(WidgetRef ref) {
    final email = ref.read(supabaseServiceProvider).currentUser?.email;
    if (email == null || email.isEmpty) return 'Athlete';
    final handle = email.split('@').first;
    return handle
        .split(RegExp(r'[._-]'))
        .where((s) => s.isNotEmpty)
        .map((s) => s[0].toUpperCase() + s.substring(1))
        .join(' ');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // First-time onboarding: when the profile resolves and is null, send the
    // user through the biometric survey. `ref.listen` only fires on state
    // changes, so this doesn't loop after the survey saves.
    ref.listen(profileProvider, (prev, next) {
      next.whenData((profile) {
        if (profile == null) context.go('/survey');
      });
    });

    // The carousel is the only child that bleeds past the 20px content gutter
    // (neighbour cards peek on the right). Everything else stays inside the
    // gutter so headers, panels, and the carousel's *focused* card share the
    // same left edge.
    const gutter = 20.0;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(gutter, 8, gutter, 0),
              child: _GreetingHeader(
                greeting: _greeting(),
                name: _displayName(ref),
                isDark: isDark,
                onToggleTheme: () {
                  ref.read(themeModeProvider.notifier).state = isDark
                      ? ThemeMode.light
                      : ThemeMode.dark;
                },
              ),
            ),
            const SizedBox(height: 18),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: gutter),
              child: _TrainingLabel(),
            ),
            const SizedBox(height: 14),
            const Padding(
              padding: EdgeInsets.only(left: gutter),
              child: _ExerciseCarousel(),
            ),
            const SizedBox(height: 28),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: gutter),
              child: _CoursesHeader(onSeeAll: () => context.go('/plan')),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: gutter),
              child: _AiCoachPanel(onTap: () => context.go('/plan')),
            ),
            const SizedBox(height: 12),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: gutter),
              child: _CategoryRow(
                title: 'Strength',
                subtitle: 'Lower body compound',
                icon: Icons.fitness_center_rounded,
              ),
            ),
            const SizedBox(height: 12),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: gutter),
              child: _CategoryRow(
                title: 'Upper Body',
                subtitle: 'Bicep curl form work',
                icon: Icons.sports_gymnastics_rounded,
              ),
            ),
            const SizedBox(height: 32),
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

// ── "Courses" header + AI coach panel + category rows ─────────────────────────

class _CoursesHeader extends StatelessWidget {
  const _CoursesHeader({required this.onSeeAll});
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('Workout', style: Theme.of(context).textTheme.titleLarge),
        TextButton(onPressed: onSeeAll, child: const Text('See All')),
      ],
    );
  }
}

class _AiCoachPanel extends StatelessWidget {
  const _AiCoachPanel({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Material(
      color: cs.surface,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(Icons.auto_awesome, color: cs.primary, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('AI Personalised Plan', style: tt.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      'Tap to view today\'s coach-built workout',
                      style: tt.bodyMedium,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: cs.onSurface.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: cs.primary, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: tt.titleMedium),
                const SizedBox(height: 2),
                Text(subtitle, style: tt.bodyMedium),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: cs.onSurface.withValues(alpha: 0.5),
          ),
        ],
      ),
    );
  }
}
