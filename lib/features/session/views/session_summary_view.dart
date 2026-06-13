import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/widgets/gradient_background.dart';
import '../../../services/supabase_service.dart';
import '../../plan/controllers/plan_controller.dart';
import '../../profile/models/user_profile_biometrics.dart';
import '../../profile/providers/profile_providers.dart';
import '../../train/models/set_metrics.dart';

// Passed via GoRouter extra when navigating to /session/summary.
class SessionSummaryData {
  const SessionSummaryData({
    required this.exerciseName,
    required this.sets,
  });

  final String exerciseName;
  final List<SetMetrics> sets;
}

// FR-3.2: Session summary screen.
// Shows the per-set breakdown table immediately, then triggers adaptive plan
// generation via PlanController in the background. "View Your Plan" becomes
// active once generation is complete (or failed).
class SessionSummaryView extends ConsumerStatefulWidget {
  const SessionSummaryView({super.key, required this.data});

  final SessionSummaryData data;

  @override
  ConsumerState<SessionSummaryView> createState() =>
      _SessionSummaryViewState();
}

class _SessionSummaryViewState extends ConsumerState<SessionSummaryView> {
  bool _saving = false;

  // UID-prefixed so multiple accounts on one device stay isolated — must
  // match PlanController._keyHistory.
  String get _historyKey =>
      '${SupabaseService().currentUser?.id ?? 'demo'}_session_history';

  @override
  void initState() {
    super.initState();
    _triggerPlanGeneration();
  }

  Future<void> _triggerPlanGeneration() async {
    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getStringList(_historyKey) ?? [];

    // Use saved profile or fall back to defaults so plan generation always runs.
    final profile =
        ref.read(profileProvider).value ?? UserProfileBiometrics.defaults;

    ref.read(planProvider.notifier).generateAdaptivePlan(
          exerciseName: widget.data.exerciseName,
          sets: widget.data.sets,
          biometrics: profile,
          sessionHistory: history,
        );
  }

  Future<void> _saveAndViewPlan() async {
    setState(() => _saving = true);
    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getStringList(_historyKey) ?? [];
    // ISO date prefix lets the Home dashboard compute streaks and weekly
    // charts; Gemini also benefits from dated history entries.
    final summary =
        '${DateTime.now().toIso8601String()}|${widget.data.exerciseName} — ${widget.data.sets.map((s) => s.toHistorySummary()).join(' | ')}';
    history.add(summary);
    final capped = history.length > 10 ? history.sublist(history.length - 10) : history;
    await prefs.setStringList(_historyKey, capped);

    // Best-effort write to Supabase workout_sessions.
    try {
      await SupabaseService().insertWorkoutSession(
        exerciseName: widget.data.exerciseName,
        setsCompleted: widget.data.sets.length,
        sessionData: widget.data.sets.map((s) => {
          'set': s.setNumber,
          'reps': s.repsCompleted,
          'form_score': s.formScore,
          'fatigue_index': s.fatigueIndex,
          'fatigue_label': s.fatigueLabel,
          'tut_ms': s.tutMs,
          'completed_at': s.completedAt.toIso8601String(),
        }).toList(),
      );
    } catch (_) {
    }

    if (mounted) context.go('/plan');
  }

  @override
  Widget build(BuildContext context) {
    final planAsync = ref.watch(planProvider);
    final generating = planAsync.isLoading;
    final canContinue = !generating && !_saving;

    return GradientBackground(
      child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text('Session Complete',
            style: AppTextStyles.titleMedium.copyWith(color: AppColors.primary)),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── Per-set breakdown ─────────────────────────────────────────────
          Text('Set Breakdown',
              style: AppTextStyles.titleMedium.copyWith(color: AppColors.primary)),
          const SizedBox(height: 12),
          _SetTable(sets: widget.data.sets),
          const SizedBox(height: 28),

          // ── AI plan status ────────────────────────────────────────────────
          _PlanStatusBanner(planAsync: planAsync),
          const SizedBox(height: 32),

          // ── Continue button ───────────────────────────────────────────────
          ElevatedButton(
            onPressed: canContinue ? _saveAndViewPlan : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              disabledBackgroundColor: AppColors.border,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: Text(
              _saving
                  ? 'Saving…'
                  : generating
                      ? 'Generating Plan…'
                      : 'View Your Plan →',
              style: AppTextStyles.button.copyWith(
                color: canContinue ? AppColors.background : AppColors.textMuted,
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    ),
    );
  }
}

// Shows the plan generation status inline (loading / error / ready).
class _PlanStatusBanner extends StatelessWidget {
  const _PlanStatusBanner({required this.planAsync});

  final AsyncValue<Map<String, dynamic>?> planAsync;

  @override
  Widget build(BuildContext context) {
    return planAsync.when(
      loading: () => Row(
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'AI Coach is building your adaptive plan…',
              style: AppTextStyles.bodyMedium,
            ),
          ),
        ],
      ),
      error: (_, _) => Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: AppColors.error, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Plan generation failed — you can still save your session.',
              style: AppTextStyles.bodyMedium,
            ),
          ),
        ],
      ),
      data: (_) => Row(
        children: [
          const Icon(Icons.check_circle_outline_rounded,
              color: AppColors.primary, size: 18),
          const SizedBox(width: 8),
          Text(
            'Adaptive plan ready!',
            style: AppTextStyles.bodyMedium
                .copyWith(color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}

// ── Per-set breakdown table ───────────────────────────────────────────────────

class _SetTable extends StatelessWidget {
  const _SetTable({required this.sets});

  final List<SetMetrics> sets;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
        boxShadow: const [
          BoxShadow(
            color: AppColors.primaryGlow,
            blurRadius: 18,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        children: [
          _TableRow(
              set: 'SET',
              reps: 'REPS',
              form: 'FORM',
              fatigue: 'FATIGUE',
              isHeader: true),
          Divider(color: AppColors.primary.withValues(alpha: 0.25), height: 1),
          ...sets.asMap().entries.map((e) {
            final s = e.value;
            return Column(
              children: [
                _TableRow(
                  set: '${s.setNumber}',
                  reps: '${s.repsCompleted}',
                  form: s.formPercent,
                  fatigue: s.fatigueLabel,
                ),
                if (e.key < sets.length - 1)
                  Divider(color: AppColors.primary.withValues(alpha: 0.15), height: 1),
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _TableRow extends StatelessWidget {
  const _TableRow({
    required this.set,
    required this.reps,
    required this.form,
    required this.fatigue,
    this.isHeader = false,
  });

  final String set, reps, form, fatigue;
  final bool isHeader;

  @override
  Widget build(BuildContext context) {
    final base = isHeader ? AppTextStyles.caption : AppTextStyles.bodyMedium;
    final muted = isHeader ? AppColors.primary.withValues(alpha: 0.7) : AppColors.textPrimary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(
              child: Text(set,
                  style: base.copyWith(color: muted),
                  textAlign: TextAlign.center)),
          Expanded(
              child: Text(reps,
                  style: base.copyWith(color: muted),
                  textAlign: TextAlign.center)),
          Expanded(
              child: Text(form,
                  style: base.copyWith(
                      color: isHeader ? muted : _formColor(form)),
                  textAlign: TextAlign.center)),
          Expanded(
              child: Text(fatigue,
                  style: base.copyWith(
                      color: isHeader ? muted : _fatigueColor(fatigue)),
                  textAlign: TextAlign.center)),
        ],
      ),
    );
  }

  Color _formColor(String f) {
    final pct = int.tryParse(f.replaceAll('%', '')) ?? 0;
    if (pct >= 70) return AppColors.primary;
    if (pct >= 40) return AppColors.secondary;
    return AppColors.error;
  }

  Color _fatigueColor(String f) {
    if (f == 'Low') return AppColors.primary;
    if (f == 'Moderate') return AppColors.secondary;
    return AppColors.error;
  }
}
