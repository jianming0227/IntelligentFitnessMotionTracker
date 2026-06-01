import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../services/gemini_service.dart';
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

// FR-3.2: Session summary screen (Option B).
// Shows a per-set breakdown table, then streams a Gemini full-session analysis
// and personalised 3-day plan. "Save & Done" persists the plan and returns home.
class SessionSummaryView extends ConsumerStatefulWidget {
  const SessionSummaryView({super.key, required this.data});

  final SessionSummaryData data;

  @override
  ConsumerState<SessionSummaryView> createState() => _SessionSummaryViewState();
}

class _SessionSummaryViewState extends ConsumerState<SessionSummaryView> {
  String _analysisText = '';
  bool _analysisDone = false;
  bool _saving = false;
  StreamSubscription<String>? _sub;

  @override
  void initState() {
    super.initState();
    _startAnalysis();
  }

  Future<void> _startAnalysis() async {
    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getStringList('session_history') ?? [];

    _sub = ref
        .read(geminiServiceProvider)
        .streamSessionAnalysis(
          exerciseName: widget.data.exerciseName,
          sets: widget.data.sets,
          previousSessionSummaries: history,
        )
        .listen(
          (chunk) => setState(() => _analysisText += chunk),
          onDone: () => setState(() => _analysisDone = true),
          onError: (_) => setState(() {
            _analysisText =
                'Great session! Your form and consistency will keep improving. Keep showing up!';
            _analysisDone = true;
          }),
        );
  }

  Future<void> _saveAndDone() async {
    setState(() => _saving = true);
    final prefs = await SharedPreferences.getInstance();

    // Append a text summary of this session to the running history
    final history = prefs.getStringList('session_history') ?? [];
    final summary =
        '${widget.data.exerciseName} — ${widget.data.sets.map((s) => s.toHistorySummary()).join(' | ')}';
    history.add(summary);
    await prefs.setStringList('session_history', history);

    // Persist the generated plan so HomeView can display it
    await prefs.setString('latest_plan', _analysisText);
    await prefs.setString('latest_plan_exercise', widget.data.exerciseName);
    await prefs.setString(
        'latest_plan_date', DateTime.now().toIso8601String());

    if (mounted) context.go('/home');
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text('Session Complete', style: AppTextStyles.titleMedium),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── Per-set breakdown table ────────────────────────────────────────
          Text('Set Breakdown', style: AppTextStyles.titleMedium),
          const SizedBox(height: 12),
          _SetTable(sets: widget.data.sets),

          const SizedBox(height: 28),

          // ── Gemini analysis ───────────────────────────────────────────────
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              Text('AI Coach Analysis', style: AppTextStyles.titleMedium),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: _analysisText.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : Text(_analysisText, style: AppTextStyles.bodyLarge),
          ),

          const SizedBox(height: 32),

          // ── Save button ───────────────────────────────────────────────────
          ElevatedButton(
            onPressed: (_analysisDone && !_saving) ? _saveAndDone : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.secondary,
              disabledBackgroundColor: AppColors.border,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: Text(
              _saving
                  ? 'Saving…'
                  : (_analysisDone ? 'Save & Done' : 'Generating Plan…'),
              style: AppTextStyles.button
                  .copyWith(color: AppColors.background),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ── Per-set breakdown table ────────────────────────────────────────────────────

class _SetTable extends StatelessWidget {
  const _SetTable({required this.sets});

  final List<SetMetrics> sets;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _TableRow(
            set: 'SET',
            reps: 'REPS',
            form: 'FORM',
            fatigue: 'FATIGUE',
            isHeader: true,
          ),
          const Divider(color: AppColors.border, height: 1),
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
                  const Divider(color: AppColors.border, height: 1),
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

  final String set;
  final String reps;
  final String form;
  final String fatigue;
  final bool isHeader;

  @override
  Widget build(BuildContext context) {
    final baseStyle =
        isHeader ? AppTextStyles.caption : AppTextStyles.bodyMedium;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Text(set,
                style: baseStyle.copyWith(
                    color: isHeader
                        ? AppColors.textMuted
                        : AppColors.textPrimary),
                textAlign: TextAlign.center),
          ),
          Expanded(
            child: Text(reps,
                style: baseStyle.copyWith(
                    color: isHeader
                        ? AppColors.textMuted
                        : AppColors.textPrimary),
                textAlign: TextAlign.center),
          ),
          Expanded(
            child: Text(form,
                style: baseStyle.copyWith(
                    color: isHeader ? AppColors.textMuted : _formColor(form)),
                textAlign: TextAlign.center),
          ),
          Expanded(
            child: Text(fatigue,
                style: baseStyle.copyWith(
                    color: isHeader
                        ? AppColors.textMuted
                        : _fatigueColor(fatigue)),
                textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }

  Color _formColor(String f) {
    final pct = int.tryParse(f.replaceAll('%', '')) ?? 0;
    if (pct >= 70) return AppColors.secondary;
    if (pct >= 40) return Colors.orange;
    return AppColors.error;
  }

  Color _fatigueColor(String f) {
    if (f == 'Low') return AppColors.secondary;
    if (f == 'Moderate') return Colors.orange;
    return AppColors.error;
  }
}
