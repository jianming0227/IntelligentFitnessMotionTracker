import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../train/data/exercise_images.dart';
import '../../train/models/exercise.dart';

/// Decodes a Gemini-generated JSON map into native Flutter widgets.
/// Supports two node types: WorkoutPlanView (top-level) and SessionCard.
Widget buildDynamicWidget(
  Map<String, dynamic> jsonNode,
  BuildContext context, {
  VoidCallback? onRefresh,
  bool isLoading = false,
}) {
  return switch (jsonNode['type'] as String? ?? '') {
    'WorkoutPlanView' => _WorkoutPlanView(
        node: jsonNode,
        onRefresh: onRefresh,
        isLoading: isLoading,
      ),
    'SessionCard' => _SessionCard(node: jsonNode),
    _ => const SizedBox.shrink(),
  };
}

// ── WorkoutPlanView ───────────────────────────────────────────────────────────

class _WorkoutPlanView extends StatelessWidget {
  const _WorkoutPlanView({
    required this.node,
    this.onRefresh,
    this.isLoading = false,
  });
  final Map<String, dynamic> node;
  final VoidCallback? onRefresh;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final title = node['title'] as String? ?? 'Your Adaptive Plan';
    final coachNote = node['coachNote'] as String? ?? '';
    final sessions = (node['sessions'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        Row(
          children: [
            Icon(Icons.auto_awesome, color: cs.primary, size: 22),
            const SizedBox(width: 10),
            Expanded(child: Text(title, style: tt.titleLarge)),
          ],
        ),
        if (coachNote.isNotEmpty) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: cs.primary.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.insights_rounded, color: cs.primary, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    coachNote,
                    style: tt.bodyMedium?.copyWith(
                      color: cs.onSurface,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
        Row(
          children: [
            Text('Your Schedule', style: tt.titleMedium),
            const Spacer(),
            SizedBox(
              width: 36,
              height: 36,
              child: isLoading
                  ? Padding(
                      padding: const EdgeInsets.all(8),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: cs.primary,
                      ),
                    )
                  : IconButton(
                      padding: EdgeInsets.zero,
                      icon: Icon(Icons.refresh_rounded,
                          color: cs.primary, size: 22),
                      tooltip: 'Refresh plan',
                      onPressed: onRefresh,
                    ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        ...sessions.map(
          (s) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: buildDynamicWidget(s, context),
          ),
        ),
      ],
    );
  }
}

// ── SessionCard ───────────────────────────────────────────────────────────────

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.node});
  final Map<String, dynamic> node;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final day = node['day'] as String? ?? '';
    final date = node['date'] as String? ?? '';
    final time = node['time'] as String? ?? '';
    final exercise = node['exercise'] as String? ?? '';
    final volume = node['volume'] as String? ?? '';
    final intensity = node['intensity'] as String? ?? '';
    final actionId = node['actionId'] as String?;
    final target = _exerciseFromActionId(actionId);
    final imagePath =
        target != null ? exerciseImageFor(target.id) : null;

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Stack(
        children: [
          // ── Background photo ──────────────────────────────────────────────
          Positioned.fill(
            child: imagePath != null
                ? Image.asset(
                    imagePath,
                    fit: BoxFit.cover,
                    alignment: const Alignment(0, -0.2),
                    errorBuilder: (_, _, _) =>
                        Container(color: cs.surfaceContainerHighest),
                  )
                : Container(color: cs.surfaceContainerHighest),
          ),

          // ── Dark vertical gradient — guarantees text legibility ──────────
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x33000000),
                    Color(0xCC000000),
                    Color(0xF2000000),
                  ],
                  stops: [0.0, 0.55, 1.0],
                ),
              ),
            ),
          ),

          // ── Content ───────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _Badge(text: day, color: cs.primary),
                    _DateTimeChip(date: date, time: time),
                  ],
                ),
                const SizedBox(height: 110),
                Text(
                  exercise,
                  style: tt.displayMedium?.copyWith(
                    fontSize: 28,
                    color: Colors.white,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 8),
                if (volume.isNotEmpty)
                  Row(
                    children: [
                      const Icon(Icons.repeat_rounded,
                          size: 16, color: Colors.white70),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          volume,
                          style: tt.bodyLarge?.copyWith(
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                if (intensity.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.bolt_rounded,
                          size: 16, color: Colors.white70),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          intensity,
                          style: tt.bodyMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.78),
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: cs.primary,
                      foregroundColor: cs.onPrimary,
                      disabledBackgroundColor:
                          Colors.white.withValues(alpha: 0.15),
                      disabledForegroundColor:
                          Colors.white.withValues(alpha: 0.5),
                      minimumSize: const Size.fromHeight(50),
                    ),
                    icon: const Icon(Icons.play_arrow_rounded, size: 22),
                    label: const Text('Start Workout Session'),
                    onPressed: target == null
                        ? null
                        : () => context
                            .push('/train/camera', extra: target),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: tt.labelMedium?.copyWith(
          color: Colors.black,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _DateTimeChip extends StatelessWidget {
  const _DateTimeChip({required this.date, required this.time});
  final String date;
  final String time;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    if (date.isEmpty && time.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.event_rounded, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            [date, time].where((s) => s.isNotEmpty).join(' · '),
            style: tt.labelMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Maps the Gemini-generated actionId to the local Exercise object so GoRouter
/// can hand a typed instance to CameraView.
Exercise? _exerciseFromActionId(String? actionId) {
  return switch (actionId) {
    'start_squat' => Exercise.all.firstWhere((e) => e.id == 'squat'),
    'start_bicep_curl' =>
      Exercise.all.firstWhere((e) => e.id == 'bicep_curl'),
    _ => null,
  };
}
