import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../progress/logic/streak.dart';
import '../../progress/models/session_record.dart';
import '../../progress/providers/progress_providers.dart';

/// FR-4.2: Recent activity dashboard: last sessions list, a 7-day rep bar
/// chart, and a day streak counter. Data comes from [sessionHistoryProvider]
/// (Supabase when signed in, local history otherwise).
///
/// Legacy local entries have no date. They still appear in the sessions list
/// but are excluded from the chart and streak.
class RecentActivityPanel extends ConsumerWidget {
  const RecentActivityPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final records = ref.watch(sessionHistoryProvider).value;
    if (records == null) return const SizedBox.shrink();
    if (records.isEmpty) return const _EmptyActivityCard();

    final dated = records.where((r) => r.date != null).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Recent Activity',
                style: Theme.of(context).textTheme.titleLarge),
            if (dated.isNotEmpty)
              _StreakChip(
                streak: currentStreak(dated.map((r) => r.date!), DateTime.now()),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (dated.isNotEmpty) ...[
          _WeeklyRepChart(records: dated),
          const SizedBox(height: 12),
        ],
        ...records.reversed.take(3).map((r) => _SessionTile(record: r)),
      ],
    );
  }
}

class _StreakChip extends StatelessWidget {
  const _StreakChip({required this.streak});
  final int streak;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🔥', style: TextStyle(fontSize: 14)),
          const SizedBox(width: 4),
          Text(
            '$streak day${streak == 1 ? '' : 's'}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: cs.primary,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

/// Custom bar chart — reps per day for the last 7 days. No chart package
/// needed; each bar is a Container scaled against the busiest day.
class _WeeklyRepChart extends StatelessWidget {
  const _WeeklyRepChart({required this.records});
  final List<SessionRecord> records;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Index 0 = six days ago … index 6 = today.
    final days = List.generate(
        7, (i) => today.subtract(Duration(days: 6 - i)));
    final repsPerDay = days.map((day) {
      return records
          .where((r) =>
              r.date!.year == day.year &&
              r.date!.month == day.month &&
              r.date!.day == day.day)
          .fold(0, (sum, r) => sum + r.totalReps);
    }).toList();

    final maxReps = repsPerDay.fold(0, (a, b) => a > b ? a : b);
    const weekdays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('REPS THIS WEEK',
              style: tt.bodyMedium?.copyWith(
                fontSize: 11,
                letterSpacing: 1.4,
                fontWeight: FontWeight.w700,
                color: cs.onSurface.withValues(alpha: 0.6),
              )),
          const SizedBox(height: 12),
          SizedBox(
            height: 84,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (i) {
                final reps = repsPerDay[i];
                final frac = maxReps == 0 ? 0.0 : reps / maxReps;
                final isToday = i == 6;
                return Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Fixed-height slot whether or not the label shows, so
                      // all bars bottom-align and the column never overflows.
                      SizedBox(
                        height: 16,
                        child: reps > 0
                            ? Text('$reps',
                                style: tt.bodyMedium?.copyWith(
                                  fontSize: 10,
                                  color: cs.onSurface.withValues(alpha: 0.6),
                                ))
                            : null,
                      ),
                      const SizedBox(height: 2),
                      Container(
                        height: (40 * frac).clamp(3.0, 40.0),
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        decoration: BoxDecoration(
                          color: reps > 0
                              ? cs.primary
                              : cs.onSurface.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        weekdays[days[i].weekday - 1],
                        style: tt.bodyMedium?.copyWith(
                          fontSize: 10,
                          fontWeight:
                              isToday ? FontWeight.w800 : FontWeight.w400,
                          color: isToday
                              ? cs.primary
                              : cs.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({required this.record});
  final SessionRecord record;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final d = record.date;
    final dateLabel = d == null
        ? ''
        : '${d.day}/${d.month}  ·  ';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              record.exerciseName.toLowerCase().contains('squat')
                  ? Icons.fitness_center_rounded
                  : Icons.sports_gymnastics_rounded,
              color: cs.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(record.exerciseName, style: tt.titleMedium),
                const SizedBox(height: 2),
                Text(
                  '$dateLabel${record.totalReps} reps  ·  ${record.avgFormPct}% form',
                  style: tt.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyActivityCard extends StatelessWidget {
  const _EmptyActivityCard();

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
          Icon(Icons.timeline_rounded,
              color: cs.onSurface.withValues(alpha: 0.4), size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'No workouts yet — complete your first session to see progress here',
              style: tt.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
