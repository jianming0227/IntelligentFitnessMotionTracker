import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/app_log.dart';
import '../../../core/widgets/gradient_background.dart';
import '../../../services/supabase_service.dart';
import '../../plan/controllers/plan_controller.dart';
import '../../profile/models/user_profile_biometrics.dart';
import '../../profile/providers/profile_providers.dart';
import '../../progress/providers/progress_providers.dart';
import '../../community/logic/community_format.dart';
import '../../community/widgets/share_card.dart';
import '../../community/widgets/share_sheet.dart';
import '../../progress/logic/streak.dart';
import '../../train/models/exercise.dart';
import '../../train/models/set_metrics.dart';

// Passed via GoRouter extra when navigating to /session/summary.
class SessionSummaryData {
  const SessionSummaryData({
    required this.exerciseName,
    required this.sets,
    this.planSessionId,
  });

  final String exerciseName;
  final List<SetMetrics> sets;

  /// The plan card this workout was started from, if any.
  final String? planSessionId;
}

enum _PlanStatus { generating, ready, upToDate, failed }

// FR-3.2: Session summary screen.
// On open: saves the session once (local history + Supabase) and ticks its
// plan card, then updates the rolling plan without blocking the page.
// planProvider is app-wide, so the update keeps running if the user leaves.
class SessionSummaryView extends ConsumerStatefulWidget {
  const SessionSummaryView({super.key, required this.data});

  final SessionSummaryData data;

  @override
  ConsumerState<SessionSummaryView> createState() => _SessionSummaryViewState();
}

class _SessionSummaryViewState extends ConsumerState<SessionSummaryView> {
  _PlanStatus _planStatus = _PlanStatus.generating;

  /// Supabase id of this workout once saved; links a community post to it.
  String? _workoutSessionId;

  // UID-prefixed so multiple accounts on one device stay isolated — must
  // match PlanController._keyHistory.
  String get _historyKey =>
      '${SupabaseService().currentUser?.id ?? 'demo'}_session_history';

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    // Grabbed up front: the user may leave before the save finishes, and
    // `ref` can't be used after this widget is disposed.
    final container = ProviderScope.containerOf(context, listen: false);
    final prefs = await SharedPreferences.getInstance();
    // Gemini gets the history from before this session; today's sets are
    // passed separately.
    final history = List<String>.of(prefs.getStringList(_historyKey) ?? []);
    // Save (and tick the plan card) first: the plan update must see today's
    // card as done, or it would overwrite the tick.
    await _saveSession(container, prefs, history);
    unawaited(_generatePlan(container, history));
  }

  Future<void> _generatePlan(
    ProviderContainer container,
    List<String> history,
  ) async {
    final profile =
        container.read(profileProvider).value ?? UserProfileBiometrics.defaults;
    // A workout was just done: tomorrow's untouched card may adapt to it.
    final result = await container
        .read(planProvider.notifier)
        .generateAdaptivePlan(
          exerciseName: widget.data.exerciseName,
          sets: widget.data.sets,
          biometrics: profile,
          sessionHistory: history,
          replanTomorrow: true,
        );
    if (mounted) {
      setState(
        () => _planStatus = switch (result) {
          PlanUpdate.added => _PlanStatus.ready,
          PlanUpdate.upToDate => _PlanStatus.upToDate,
          PlanUpdate.failed => _PlanStatus.failed,
        },
      );
    }
  }

  Future<void> _saveSession(
    ProviderContainer container,
    SharedPreferences prefs,
    List<String> history,
  ) async {
    if (widget.data.sets.isEmpty) return;

    // ISO date prefix lets Home/Progress compute streaks and weekly stats.
    final summary =
        '${DateTime.now().toIso8601String()}|${widget.data.exerciseName} — ${widget.data.sets.map((s) => s.toHistorySummary()).join(' | ')}';
    final updated = [...history, summary];
    await prefs.setStringList(
      _historyKey,
      updated.length > 10 ? updated.sublist(updated.length - 10) : updated,
    );

    // Best-effort write to Supabase workout_sessions.
    final planSessionId = widget.data.planSessionId;
    String? sessionId;
    try {
      sessionId = _workoutSessionId = await SupabaseService().insertWorkoutSession(
        planSessionId: planSessionId,
        exerciseName: widget.data.exerciseName,
        setsCompleted: widget.data.sets.length,
        sessionData: widget.data.sets
            .map(
              (s) => {
                'set': s.setNumber,
                'reps': s.repsCompleted,
                'form_score': s.formScore,
                'fatigue_index': s.fatigueIndex,
                'fatigue_label': s.fatigueLabel,
                'tut_ms': s.tutMs,
                'set_duration_ms': s.setDurationMs,
                'rom_score': s.romScore,
                'rep_rom_spans': s.repRomSpans,
                'endurance_score': s.enduranceScore,
                'completed_at': s.completedAt.toIso8601String(),
              },
            )
            .toList(),
      );
      AppLog.ok('Session', 'Session saved');
    } catch (e, st) {
      AppLog.error('Supabase', 'Session save failed', e, st);
    }
    // Tick the plan card (and its plan_sessions row): the card it was started
    // from, or today's card of the same exercise.
    await container
        .read(planProvider.notifier)
        .markWorkoutDone(
          exerciseName: widget.data.exerciseName,
          planSessionId: planSessionId,
          workoutSessionId: sessionId,
        );
    // Home + Progress re-read history so the new session shows up.
    container.invalidate(sessionHistoryProvider);
  }

  /// Share card / community post for this workout.
  void _openShare() {
    final now = DateTime.now();
    final weightKg =
        (ref.read(profileProvider).value ?? UserProfileBiometrics.defaults)
            .weightKg;
    final dates = [
      ...?ref.read(sessionHistoryProvider).value?.map((r) => r.date).nonNulls,
      now, // this workout, in case history hasn't reloaded yet
    ];
    showShareSheet(
      context,
      workoutSessionId: _workoutSessionId,
      data: ShareCardData(
        exerciseName: widget.data.exerciseName,
        date: now,
        streakDays: currentStreak(dates, now),
        stats: statsFromSets(
          widget.data.sets,
          met: Exercise.byName(widget.data.exerciseName)?.met ?? 3.5,
          weightKg: weightKg,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sets = widget.data.sets;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go('/home');
      },
      child: GradientBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            automaticallyImplyLeading: false,
            leading: IconButton(
              icon: const Icon(Icons.close_rounded),
              tooltip: 'Back to Home',
              onPressed: () => context.go('/home'),
            ),
            title: const Text('Session Complete'),
            centerTitle: true,
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              _HeroCard(exerciseName: widget.data.exerciseName, sets: sets),
              const SizedBox(height: 24),
              Text('Sets', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              for (final (i, s) in sets.indexed) ...[
                _SetCard(
                  set: s,
                  isBest: sets.length > 1 && i == _bestIndex(sets),
                ),
                const SizedBox(height: 10),
              ],
              if (sets.isNotEmpty) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _openShare,
                  icon: const Icon(Icons.ios_share_rounded, size: 18),
                  label: const Text('Share workout'),
                ),
              ],
            ],
          ),
          bottomNavigationBar: SafeArea(
            minimum: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _PlanStatusLine(status: _planStatus),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => context.go('/home'),
                        style: _buttonShape(),
                        child: const Text('Back to Home'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => context.go('/plan'),
                        style: _buttonShape(),
                        child: const Text('View Plan'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  ButtonStyle _buttonShape() => ButtonStyle(
    padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(vertical: 16)),
    shape: WidgetStatePropertyAll(
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}

/// Best set = highest form score, more reps breaks a tie.
int _bestIndex(List<SetMetrics> sets) {
  var best = 0;
  for (var i = 1; i < sets.length; i++) {
    final a = sets[i], b = sets[best];
    if (a.formScore > b.formScore ||
        (a.formScore == b.formScore && a.repsCompleted > b.repsCompleted)) {
      best = i;
    }
  }
  return best;
}

Color _scoreColor(BuildContext context, double score) => switch (score) {
  >= 0.7 => Theme.of(context).colorScheme.primary,
  >= 0.4 => AppColors.secondary,
  _ => AppColors.error,
};

Color _fatigueColor(BuildContext context, String label) => switch (label) {
  'Low' => Theme.of(context).colorScheme.primary,
  'Moderate' => AppColors.secondary,
  _ => AppColors.error,
};

// ── Hero ──────────────────────────────────────────────────────────────────────

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.exerciseName, required this.sets});

  final String exerciseName;
  final List<SetMetrics> sets;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final reps = sets.fold(0, (sum, s) => sum + s.repsCompleted);
    final avgForm = sets.isEmpty
        ? null
        : sets.fold(0.0, (sum, s) => sum + s.formScore) / sets.length;
    final ms = sets.fold(0, (sum, s) => sum + s.setDurationMs);
    final time = Duration(milliseconds: ms);
    final timeLabel =
        '${time.inMinutes}:${(time.inSeconds % 60).toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: cs.primary.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: cs.primary,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check_rounded, color: cs.onPrimary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nice work!',
                      style: tt.bodyMedium?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    Text(
                      exerciseName,
                      style: tt.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _HeroStat(value: '$reps', label: 'Reps'),
              _HeroStat(
                value: avgForm == null ? '–' : '${(avgForm * 100).round()}%',
                label: 'Avg form',
                color: avgForm == null ? null : _scoreColor(context, avgForm),
              ),
              _HeroStat(value: '${sets.length}', label: 'Sets'),
              _HeroStat(value: ms == 0 ? '–' : timeLabel, label: 'Time'),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.value, required this.label, this.color});

  final String value;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Expanded(
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: tt.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: color ?? cs.onSurface,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: tt.bodySmall?.copyWith(
              color: cs.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Set card ──────────────────────────────────────────────────────────────────

class _SetCard extends StatelessWidget {
  const _SetCard({required this.set, required this.isBest});

  final SetMetrics set;
  final bool isBest;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final muted = cs.onSurface.withValues(alpha: 0.6);
    final fatigueColor = _fatigueColor(context, set.fatigueLabel);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isBest ? cs.primary : cs.onSurface.withValues(alpha: 0.08),
          width: isBest ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: cs.onSurface.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Text(
              '${set.setNumber}',
              style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        '${set.repsCompleted} reps',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tt.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (isBest) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: cs.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Best',
                          style: tt.labelSmall?.copyWith(
                            color: cs.onPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'ROM ${set.romPercent}  ·  TUT ${set.tutLabel}',
                    maxLines: 1,
                    style: tt.bodySmall?.copyWith(color: muted),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                set.formPercent,
                style: tt.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: _scoreColor(context, set.formScore),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: fatigueColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${set.fatigueLabel} fatigue',
                  style: tt.labelSmall?.copyWith(color: fatigueColor),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Plan status (never blocks the buttons) ───────────────────────────────────

class _PlanStatusLine extends StatelessWidget {
  const _PlanStatusLine({required this.status});

  final _PlanStatus status;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final muted = cs.onSurface.withValues(alpha: 0.6);

    final (Widget icon, String text, Color color) = switch (status) {
      _PlanStatus.generating => (
        SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary),
        ),
        'Flick is building your next plan…',
        muted,
      ),
      _PlanStatus.ready => (
        Icon(Icons.check_circle_rounded, size: 16, color: cs.primary),
        'Plan updated',
        cs.primary,
      ),
      _PlanStatus.upToDate => (
        Icon(Icons.check_circle_rounded, size: 16, color: cs.primary),
        'Plan already covers the next 3 days',
        cs.primary,
      ),
      _PlanStatus.failed => (
        Icon(Icons.info_outline_rounded, size: 16, color: muted),
        'Plan unavailable, keeping your last plan',
        muted,
      ),
    };

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        icon,
        const SizedBox(width: 8),
        Flexible(
          child: Text(text, style: tt.bodySmall?.copyWith(color: color)),
        ),
      ],
    );
  }
}
