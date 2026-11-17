import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/friendly_error.dart';
import '../../community/providers/community_providers.dart';
import '../../community/widgets/community_preview_card.dart';
import '../../profile/models/user_profile_biometrics.dart';
import '../../profile/providers/profile_providers.dart';
import '../logic/muscle_status.dart';
import '../logic/progress_stats.dart';
import '../models/session_record.dart';
import '../providers/progress_providers.dart';
import '../widgets/body_map.dart';
import '../widgets/form_trend_chart.dart';
import '../widgets/mascot_card.dart';

/// FR-4.3: Progress tab — this week's totals, the muscle body map, form trend,
/// personal records and a monthly per-exercise breakdown. Everything is
/// computed from [sessionHistoryProvider]; pull down to reload it.
class ProgressView extends ConsumerWidget {
  const ProgressView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(sessionHistoryProvider);
    final weightKg =
        (ref.watch(profileProvider).value ?? UserProfileBiometrics.defaults)
            .weightKg;
    final tt = Theme.of(context).textTheme;
    // This week's KPIs sit beside Flick; null while loading or on error (tiles
    // show dashes so the card never jumps).
    final records = history.value;
    final week = records == null
        ? null
        : weekStats(records, DateTime.now(), weightKg);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () {
            ref.invalidate(feedProvider); // Community card reloads too
            return ref.refresh(sessionHistoryProvider.future);
          },
          child: ListView(
            // Bottom padding clears the floating nav bar (AppShell extendBody).
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
            children: [
              Text('Progress', style: tt.titleLarge),
              const SizedBox(height: 16),
              // Flick + this week's KPIs (2x2), shown in every state so a
              // brand-new account still sees the mascot and zeroed tiles.
              const _SectionLabel('This week'),
              MascotCard(kpis: _KpiGrid(stats: week)),
              const SizedBox(height: 20),
              const CommunityPreviewCard(),
              const SizedBox(height: 20),
              ...history.when(
                loading: () => const [
                  SizedBox(height: 120),
                  Center(child: CircularProgressIndicator()),
                ],
                error: (e, _) => [_Message(friendlyError(e))],
                data: (records) => records.isEmpty
                    ? const [
                        _Message(
                          'No workouts yet. Tap the play button to log a '
                          'session and your progress shows up here.',
                        ),
                      ]
                    : _sections(context, records, weightKg),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _sections(
    BuildContext context,
    List<SessionRecord> records,
    double weightKg,
  ) {
    final now = DateTime.now();
    final muscles = muscleStatuses(records, now);
    final trend = formTrend(records);
    final prs = personalRecords(records);
    final breakdown = exerciseBreakdown(records, now);

    return [
      const _SectionLabel('Muscles · last 7 days'),
      _Card(
        child: Column(
          children: [
            BodyMap(
              stats: muscles,
              onMuscleTap: (m) => _showMuscleSheet(context, muscles[m]!),
            ),
            const SizedBox(height: 12),
            const BodyMapLegend(),
          ],
        ),
      ),
      if (trend.isNotEmpty) ...[
        const SizedBox(height: 20),
        _SectionLabel('Form trend · last ${trend.length} sessions'),
        _Card(child: FormTrendChart(sessions: trend)),
      ],
      const SizedBox(height: 20),
      const _SectionLabel('Personal records'),
      _PersonalRecordsCard(prs: prs),
      if (breakdown.isNotEmpty) ...[
        const SizedBox(height: 20),
        const _SectionLabel('Last 30 days by exercise'),
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, e) in breakdown.indexed) ...[
                if (i > 0) const Divider(height: 20),
                _BreakdownRow(summary: e),
              ],
            ],
          ),
        ),
      ],
    ];
  }

  void _showMuscleSheet(BuildContext context, MuscleStat stat) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => _MuscleSheet(stat: stat),
    );
  }
}

// ── Building blocks ──────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: child,
    );
  }
}

/// Small caps header, same style as the Home chart title.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontSize: 11,
          letterSpacing: 1.4,
          fontWeight: FontWeight.w700,
          color: cs.onSurface.withValues(alpha: 0.6),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return _Card(
      child: Row(
        children: [
          Icon(
            Icons.insights_rounded,
            color: cs.onSurface.withValues(alpha: 0.4),
            size: 28,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

/// This week's four KPIs as a 2x2 grid (lives inside [MascotCard]).
class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.stats});

  /// Null while history is loading or failed: every tile shows a dash.
  final WeekStats? stats;

  @override
  Widget build(BuildContext context) {
    final s = stats;
    String dash(Object? v, [String suffix = '']) =>
        v == null ? '–' : '$v$suffix';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            _KpiTile(value: dash(s?.sessions), label: 'Sessions'),
            const SizedBox(width: 8),
            _KpiTile(value: dash(s?.reps), label: 'Reps'),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _KpiTile(value: dash(s?.avgFormPct, '%'), label: 'Form'),
            const SizedBox(width: 8),
            _KpiTile(value: dash(s?.kcal?.round()), label: 'kcal'),
          ],
        ),
      ],
    );
  }
}

class _KpiTile extends StatelessWidget {
  const _KpiTile({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          // A step up from the card so the tiles read as separate cells.
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value, style: tt.titleLarge),
            ),
            const SizedBox(height: 2),
            Text(label, style: tt.bodyMedium?.copyWith(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _PersonalRecordsCard extends StatelessWidget {
  const _PersonalRecordsCard({required this.prs});
  final PersonalRecords prs;

  @override
  Widget build(BuildContext context) {
    String detail(RecordEntry e) {
      final d = e.date;
      return d == null
          ? e.exerciseName
          : '${e.exerciseName} · ${d.day}/${d.month}';
    }

    return _Card(
      child: Column(
        children: [
          _RecordRow(
            icon: Icons.repeat_rounded,
            title: 'Most reps in one set',
            value: prs.mostRepsInSet == null
                ? '–'
                : '${prs.mostRepsInSet!.value}',
            detail: prs.mostRepsInSet == null
                ? null
                : detail(prs.mostRepsInSet!),
          ),
          const Divider(height: 20),
          _RecordRow(
            icon: Icons.verified_rounded,
            title: 'Best session form',
            value: prs.bestFormSession == null
                ? '–'
                : '${prs.bestFormSession!.value}%',
            detail: prs.bestFormSession == null
                ? null
                : detail(prs.bestFormSession!),
          ),
          const Divider(height: 20),
          _RecordRow(
            icon: Icons.local_fire_department_rounded,
            title: 'Longest streak',
            value:
                '${prs.longestStreakDays} day${prs.longestStreakDays == 1 ? '' : 's'}',
          ),
        ],
      ),
    );
  }
}

class _RecordRow extends StatelessWidget {
  const _RecordRow({
    required this.icon,
    required this.title,
    required this.value,
    this.detail,
  });

  final IconData icon;
  final String title;
  final String value;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: cs.primary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: cs.primary, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: tt.titleMedium),
              if (detail != null) Text(detail!, style: tt.bodyMedium),
            ],
          ),
        ),
        Text(value, style: tt.titleLarge),
      ],
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({required this.summary});
  final ExerciseSummary summary;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final s = summary;
    // Stacked, not one row: long exercise names would push the stats off a
    // narrow phone screen.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(s.exerciseName, style: tt.titleMedium),
        const SizedBox(height: 2),
        Text(
          '${s.sessions} session${s.sessions == 1 ? '' : 's'} · '
          '${s.reps} reps · ${s.avgFormPct}% form',
          style: tt.bodyMedium,
        ),
      ],
    );
  }
}

class _MuscleSheet extends StatelessWidget {
  const _MuscleSheet({required this.stat});
  final MuscleStat stat;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final color = muscleStatusColor(stat.status, cs);

    final String lastLabel;
    final last = stat.lastTrained;
    if (last == null) {
      lastLabel = 'Never';
    } else {
      final now = DateTime.now();
      final days = DateTime(
        now.year,
        now.month,
        now.day,
      ).difference(DateTime(last.year, last.month, last.day)).inDays;
      lastLabel = switch (days) {
        0 => 'Today',
        1 => 'Yesterday',
        _ => '$days days ago',
      };
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(stat.muscle.label, style: tt.titleLarge),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    muscleStatusLabel(stat.status),
                    style: tt.bodyMedium?.copyWith(
                      color: stat.status == MuscleStatus.untracked
                          ? cs.onSurface
                          : color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (stat.status == MuscleStatus.untracked)
              Text(
                'No exercise in FitForm trains this muscle yet.',
                style: tt.bodyMedium,
              )
            else ...[
              _SheetLine('Last trained', lastLabel),
              _SheetLine('Sessions, last 7 days', '${stat.sessionsInWindow}'),
              _SheetLine(
                'Average form',
                stat.avgForm == null
                    ? '–'
                    : '${(stat.avgForm! * 100).round()}%',
              ),
              const SizedBox(height: 16),
              Text('Train it with', style: tt.titleMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final e in stat.trainedBy)
                    ActionChip(
                      label: Text(e.name),
                      onPressed: () {
                        context.pop();
                        context.push('/train/detail', extra: e);
                      },
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SheetLine extends StatelessWidget {
  const _SheetLine(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(label, style: tt.bodyMedium)),
          Text(value, style: tt.titleMedium),
        ],
      ),
    );
  }
}
