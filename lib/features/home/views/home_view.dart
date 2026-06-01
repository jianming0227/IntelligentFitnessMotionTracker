import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/widgets/app_logo.dart';
import '../../../core/widgets/gradient_background.dart';
import '../../train/models/exercise.dart';

// FR-3.2: Home screen — shows an empty coaching prompt until the user completes
// their first session. After each session, a Gemini-generated plan is saved and
// displayed here, regenerating and appending to history with each new session.
class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> with RouteAware {
  late Future<Map<String, String?>> _planFuture;

  @override
  void initState() {
    super.initState();
    _loadPlan();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload plan every time this tab regains focus (e.g. after session ends)
    _loadPlan();
  }

  void _loadPlan() {
    _planFuture = _fetchPlan();
  }

  Future<Map<String, String?>> _fetchPlan() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'plan': prefs.getString('latest_plan'),
      'exercise': prefs.getString('latest_plan_exercise'),
      'date': prefs.getString('latest_plan_date'),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: FutureBuilder<Map<String, String?>>(
            future: _planFuture,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                );
              }
              final plan = snap.data?['plan'];
              final exercise = snap.data?['exercise'];
              final dateStr = snap.data?['date'];

              return plan == null
                  ? const _EmptyState()
                  : _PlanView(plan: plan, exercise: exercise, dateStr: dateStr);
            },
          ),
        ),
      ),
    );
  }
}

// ── Empty state — shown before the first session ───────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 48),
          const AppLogo(size: 36),
          const SizedBox(height: 48),
          Center(
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.auto_awesome_outlined,
                      color: AppColors.primary, size: 52),
                  const SizedBox(height: 20),
                  Text('No plan yet', style: AppTextStyles.titleMedium),
                  const SizedBox(height: 10),
                  Text(
                    'Complete your first training session and your AI coach will generate a personalised plan right here.',
                    style: AppTextStyles.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Plan view — shown after at least one session is saved ─────────────────────

class _PlanView extends StatelessWidget {
  const _PlanView({
    required this.plan,
    this.exercise,
    this.dateStr,
  });

  final String plan;
  final String? exercise;
  final String? dateStr;

  String _formatDate(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return '';
    }
  }

  // Detect which exercise to launch from the Gemini plan text.
  Exercise? _detectExercise() {
    final lower = plan.toLowerCase();
    if (lower.contains('bicep curl')) {
      return Exercise.all.firstWhere((e) => e.id == 'bicep_curl');
    }
    if (lower.contains('squat')) {
      return Exercise.all.firstWhere((e) => e.id == 'squat');
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final detected = _detectExercise();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      children: [
        const SizedBox(height: 24),
        const AppLogo(size: 30),
        const SizedBox(height: 28),
        Row(
          children: [
            const Icon(Icons.auto_awesome, color: AppColors.primary, size: 18),
            const SizedBox(width: 8),
            Text('Your Plan', style: AppTextStyles.titleLarge),
            const Spacer(),
            Text(_formatDate(dateStr), style: AppTextStyles.caption),
          ],
        ),
        if (exercise != null) ...[
          const SizedBox(height: 4),
          Text(
            'Based on: $exercise',
            style: AppTextStyles.bodyMedium,
          ),
        ],
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Text(plan, style: AppTextStyles.bodyLarge),
        ),
        if (detected != null) ...[
          const SizedBox(height: 20),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: const Icon(Icons.fitness_center),
            label: Text(
              'Start Today\'s Session — ${detected.name}',
              style: AppTextStyles.button.copyWith(color: Colors.white),
            ),
            onPressed: () => context.push('/train/camera', extra: detected),
          ),
        ],
        const SizedBox(height: 24),
      ],
    );
  }
}
