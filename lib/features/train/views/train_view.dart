import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/exercise_images.dart';
import '../models/exercise.dart';

/// Train tab — vertical "Courses" list. Each row shows a soft-tinted card
/// with the exercise photo on the right and the title + program count on the
/// left. Tapping a row opens [ExerciseDetailView] (not the camera directly).
class TrainView extends StatelessWidget {
  const TrainView({super.key});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title bar — centered like the reference's "Courses" page
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(
                children: [
                  _CircleIconButton(
                    icon: Icons.chevron_left_rounded,
                    onTap: () {
                      if (context.canPop()) context.pop();
                    },
                  ),
                  Expanded(
                    child: Center(
                      child: Text('Courses', style: tt.titleLarge),
                    ),
                  ),
                  const SizedBox(width: 44), // mirror back-button for centering
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                itemCount: Exercise.all.length,
                separatorBuilder: (_, _) => const SizedBox(height: 14),
                itemBuilder: (context, i) =>
                    _CourseRow(exercise: Exercise.all[i]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surface,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, size: 22, color: cs.onSurface),
        ),
      ),
    );
  }
}

class _CourseRow extends StatelessWidget {
  const _CourseRow({required this.exercise});

  final Exercise exercise;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final imagePath = exerciseImageFor(exercise.id);

    return Material(
      color: cs.surface,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => context.push('/train/detail', extra: exercise),
        child: SizedBox(
          height: 96,
          child: Row(
            children: [
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exercise.name,
                      style: tt.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '24 Workout Programs',
                      style: tt.bodyMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Photo thumbnail on the right, bleeding to the card edge.
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(22),
                  bottomRight: Radius.circular(22),
                ),
                child: SizedBox(
                  width: 140,
                  height: 96,
                  child: imagePath != null
                      ? Image.asset(
                          imagePath,
                          fit: BoxFit.cover,
                          alignment: const Alignment(0, -0.1),
                          errorBuilder: (_, _, _) =>
                              _ThumbFallback(emoji: exercise.emoji),
                        )
                      : _ThumbFallback(emoji: exercise.emoji),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThumbFallback extends StatelessWidget {
  const _ThumbFallback({required this.emoji});
  final String emoji;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      color: cs.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Text(emoji, style: const TextStyle(fontSize: 48)),
    );
  }
}
