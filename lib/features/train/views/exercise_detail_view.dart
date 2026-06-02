import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/exercise_images.dart';
import '../models/exercise.dart';

/// Workout detail page — shown when the user taps a course in [TrainView] or
/// a card in the home carousel. Hero photo on top, a rounded info panel
/// straddled by a play button, then a description, two stat pills, and the
/// LET'S WORKOUT primary CTA that finally launches the camera session.
class ExerciseDetailView extends StatelessWidget {
  const ExerciseDetailView({super.key, required this.exercise});

  final Exercise exercise;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final imagePath = exerciseImageFor(exercise.id);

    return Scaffold(
      backgroundColor: cs.surface,
      body: Stack(
        children: [
          // Hero photo fills the top half.
          Positioned.fill(
            child: Column(
              children: [
                Expanded(
                  child: _HeroImage(
                    imagePath: imagePath,
                    emoji: exercise.emoji,
                  ),
                ),
                // Empty space at the bottom so the panel can sit on top.
                Expanded(child: Container(color: cs.surface)),
              ],
            ),
          ),

          // Back + favourite buttons over the hero
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _HeroIconButton(
                    icon: Icons.chevron_left_rounded,
                    onTap: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/home');
                      }
                    },
                  ),
                  _HeroIconButton(
                    icon: Icons.favorite_border_rounded,
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ),

          // Info panel anchored to the bottom
          Align(
            alignment: Alignment.bottomCenter,
            child: _InfoPanel(exercise: exercise),
          ),
        ],
      ),
    );
  }
}

// ── Hero photo ────────────────────────────────────────────────────────────────

class _HeroImage extends StatelessWidget {
  const _HeroImage({required this.imagePath, required this.emoji});

  final String? imagePath;
  final String emoji;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (imagePath == null) {
      return Container(
        color: cs.surfaceContainerHighest,
        alignment: Alignment.center,
        child: Text(emoji, style: const TextStyle(fontSize: 120)),
      );
    }
    return Image.asset(
      imagePath!,
      fit: BoxFit.cover,
      alignment: const Alignment(0, -0.1),
      errorBuilder: (_, _, _) => Container(
        color: cs.surfaceContainerHighest,
        alignment: Alignment.center,
        child: Text(emoji, style: const TextStyle(fontSize: 120)),
      ),
    );
  }
}

class _HeroIconButton extends StatelessWidget {
  const _HeroIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.35),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 22, color: Colors.white),
        ),
      ),
    );
  }
}

// ── Info panel ────────────────────────────────────────────────────────────────

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({required this.exercise});

  final Exercise exercise;

  String _longDescription() {
    // Built from the existing exercise metadata so it stays accurate to the
    // app's actual coaching targets.
    return 'Train your ${exercise.categoryLabel.toLowerCase()} with controlled '
        '${exercise.name.toLowerCase()} reps. Maintain a target joint angle '
        'between ${exercise.targetAngleMin.toStringAsFixed(0)}° and '
        '${exercise.targetAngleMax.toStringAsFixed(0)}° to maximise time '
        'under tension. Your AI coach will provide live form corrections '
        'and a post-set summary based on your reps, fatigue, and ROM.';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final mq = MediaQuery.of(context);

    return Container(
      // Roughly 55% of viewport so it leaves space for the hero on top.
      constraints: BoxConstraints(
        maxHeight: mq.size.height * 0.58,
      ),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Padding(
        padding:
            EdgeInsets.fromLTRB(24, 28, 24, 20 + mq.padding.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              exercise.name,
              style: tt.displayMedium?.copyWith(fontSize: 28),
            ),
            const SizedBox(height: 14),
            Flexible(
              child: SingleChildScrollView(
                child: Text(
                  _longDescription(),
                  style: tt.bodyLarge?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.7),
                    height: 1.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _StatPill(
                    icon: Icons.access_time_rounded,
                    label: 'Time',
                    value: '20 min',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatPill(
                    icon: Icons.local_fire_department_rounded,
                    label: 'Burn',
                    value:
                        '${(exercise.targetAngleMax * 2.5).round()} kcal',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: () =>
                  context.push('/train/camera', extra: exercise),
              child: const Text("LET'S WORKOUT"),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: cs.primary),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label,
                  style: tt.bodyMedium
                      ?.copyWith(fontSize: 11, letterSpacing: 0.4)),
              Text(value,
                  style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }
}
