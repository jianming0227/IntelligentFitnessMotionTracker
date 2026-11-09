import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../logic/mascot_mood.dart';
import 'mascot/flick_mascot.dart';

/// Bottom sheet opened by tapping Flick: why he looks the way he does, a
/// checklist of what keeps him happy, and a short legend of his moods.
Future<void> showFlickSheet(
  BuildContext context, {
  required MascotStatus status,
  VoidCallback? onPreviewCelebration,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => _FlickSheet(
      status: status,
      onPreviewCelebration: onPreviewCelebration,
    ),
  );
}

class _FlickSheet extends StatelessWidget {
  const _FlickSheet({required this.status, this.onPreviewCelebration});

  final MascotStatus status;
  final VoidCallback? onPreviewCelebration;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                FlickMascot(mood: status.mood, size: 76),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(status.headline, style: tt.titleLarge),
                      const SizedBox(height: 4),
                      Text(status.reason, style: tt.bodyMedium),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text('Keep Flick happy', style: tt.titleMedium),
            const SizedBox(height: 8),
            for (final item in status.checklist) _ChecklistRow(item: item),
            const SizedBox(height: 20),
            Text(
              'How Flick reacts',
              style: tt.bodyMedium?.copyWith(
                fontSize: 11,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w700,
                color: cs.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 8),
            const Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MoodChip(color: AppColors.success, text: 'Happy: you trained today'),
                _MoodChip(color: AppColors.accentLime, text: 'Waiting: today\'s session is to do'),
                _MoodChip(color: Color(0xFF8AB4FF), text: 'Resting: plan rest day'),
                _MoodChip(color: AppColors.warning, text: 'Sad: a plan day was missed'),
                _MoodChip(color: AppColors.accentOrange, text: 'Celebrates: plan finished or new PR'),
              ],
            ),
            if (kDebugMode && onPreviewCelebration != null) ...[
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: () {
                  context.pop();
                  onPreviewCelebration!();
                },
                icon: const Icon(Icons.celebration_rounded),
                label: const Text('Preview celebration (debug)'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow({required this.item});
  final ChecklistItem item;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final muted = cs.onSurface.withValues(alpha: 0.45);
    final (icon, color, label) = switch (item.state) {
      ChecklistState.done => (Icons.check_circle_rounded, AppColors.success, 'Done'),
      ChecklistState.todo => (Icons.radio_button_unchecked_rounded, cs.primary, 'To do'),
      ChecklistState.missed => (Icons.error_outline_rounded, AppColors.warning, 'Missed'),
      ChecklistState.rest => (Icons.bedtime_outlined, muted, 'Rest'),
      ChecklistState.upcoming => (Icons.schedule_rounded, muted, 'Upcoming'),
    };
    return Semantics(
      label: '${item.text}: $label',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.text,
                    style: tt.titleMedium?.copyWith(
                      decoration: item.state == ChecklistState.done
                          ? TextDecoration.lineThrough
                          : null,
                      color: item.state == ChecklistState.upcoming ||
                              item.state == ChecklistState.rest
                          ? cs.onSurface.withValues(alpha: 0.6)
                          : null,
                    ),
                  ),
                  if (item.detail != null)
                    Text(item.detail!, style: tt.bodyMedium?.copyWith(fontSize: 12)),
                ],
              ),
            ),
            Text(label, style: tt.bodyMedium?.copyWith(fontSize: 12, color: color)),
          ],
        ),
      ),
    );
  }
}

class _MoodChip extends StatelessWidget {
  const _MoodChip({required this.color, required this.text});
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(text, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12)),
        ],
      ),
    );
  }
}
