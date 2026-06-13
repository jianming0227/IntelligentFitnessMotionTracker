import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// FR-4.2: Recent activity dashboard — parses the `session_history` strings
/// written by SessionSummaryView and shows: last sessions list, a 7-day rep
/// bar chart, and a day streak counter.
///
/// History entry format (new entries): `<ISO date>|<Exercise> — Set 1: ...`
/// Legacy entries have no date prefix — they still appear in the sessions
/// list but are excluded from the chart and streak (no timestamp).
class RecentActivityPanel extends StatefulWidget {
  const RecentActivityPanel({super.key});

  @override
  State<RecentActivityPanel> createState() => _RecentActivityPanelState();
}

class _RecentActivityPanelState extends State<RecentActivityPanel> {
  late final Future<List<_SessionRecord>> _records = _load();

  Future<List<_SessionRecord>> _load() async {
    final prefs = await SharedPreferences.getInstance();
    // UID-prefixed — matches SessionSummaryView and PlanController.
    final uid = Supabase.instance.client.auth.currentUser?.id ?? 'demo';
    final raw = prefs.getStringList('${uid}_session_history') ?? [];
    return raw.map(_parse).toList();
  }

  _SessionRecord _parse(String entry) {
    DateTime? date;
    var body = entry;
    final pipe = entry.indexOf('|');
    if (pipe > 0) {
      // Legacy entries also contain '|' between set summaries, but the text
      // before it never parses as a date — tryParse keeps them safe.
      date = DateTime.tryParse(entry.substring(0, pipe));
      if (date != null) body = entry.substring(pipe + 1);
    }

    final dash = body.indexOf(' — ');
    final exercise = dash > 0 ? body.substring(0, dash) : 'Workout';

    final totalReps = RegExp(r'(\d+) reps')
        .allMatches(body)
        .map((m) => int.parse(m.group(1)!))
        .fold(0, (a, b) => a + b);

    final forms = RegExp(r'form (\d+)%')
        .allMatches(body)
        .map((m) => int.parse(m.group(1)!))
        .toList();
    final avgForm = forms.isEmpty
        ? 0
        : (forms.reduce((a, b) => a + b) / forms.length).round();

    return _SessionRecord(
      date: date,
      exercise: exercise,
      totalReps: totalReps,
      avgFormPct: avgForm,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<_SessionRecord>>(
      future: _records,
      builder: (context, snapshot) {
        final records = snapshot.data ?? [];
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox.shrink();
        }
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
                if (dated.isNotEmpty) _StreakChip(streak: _streak(dated)),
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
      },
    );
  }

  /// Consecutive days with at least one session, counting back from today
  /// (or yesterday, so an unfinished today doesn't break the streak).
  int _streak(List<_SessionRecord> dated) {
    final days = dated
        .map((r) =>
            DateTime(r.date!.year, r.date!.month, r.date!.day))
        .toSet();
    final now = DateTime.now();
    var cursor = DateTime(now.year, now.month, now.day);
    if (!days.contains(cursor)) {
      cursor = cursor.subtract(const Duration(days: 1));
    }
    var streak = 0;
    while (days.contains(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }
}

class _SessionRecord {
  const _SessionRecord({
    required this.date,
    required this.exercise,
    required this.totalReps,
    required this.avgFormPct,
  });

  final DateTime? date;
  final String exercise;
  final int totalReps;
  final int avgFormPct;
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
  final List<_SessionRecord> records;

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
  final _SessionRecord record;

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
              record.exercise.toLowerCase().contains('squat')
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
                Text(record.exercise, style: tt.titleMedium),
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
