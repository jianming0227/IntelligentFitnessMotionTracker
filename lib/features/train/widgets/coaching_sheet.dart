import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../services/gemini_service.dart';
import '../models/set_metrics.dart';

// FR-3.1: Post-set bottom sheet — streams a brief Gemini coaching tip immediately
// after each set completes. The "Continue" button is locked until streaming ends
// so the user reads the feedback before moving on.
class CoachingSheet extends ConsumerStatefulWidget {
  const CoachingSheet({
    super.key,
    required this.exerciseName,
    required this.metrics,
    required this.onContinue,
  });

  final String exerciseName;
  final SetMetrics metrics;
  final VoidCallback onContinue;

  @override
  ConsumerState<CoachingSheet> createState() => _CoachingSheetState();
}

class _CoachingSheetState extends ConsumerState<CoachingSheet> {
  String _text = '';
  bool _done = false;
  StreamSubscription<String>? _sub;

  @override
  void initState() {
    super.initState();
    _startStream();
  }

  void _startStream() {
    _sub = ref
        .read(geminiServiceProvider)
        .streamSetCoaching(
          exerciseName: widget.exerciseName,
          metrics: widget.metrics,
        )
        .listen(
          (chunk) => setState(() => _text += chunk),
          onDone: () => setState(() => _done = true),
          onError: (_) => setState(() {
            _text = 'Great effort! Keep that energy for the next set.';
            _done = true;
          }),
        );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Set result chips
          Row(
            children: [
              _MetricChip(
                label: 'Set ${widget.metrics.setNumber}',
                value: '',
                highlight: true,
              ),
              const SizedBox(width: 8),
              _MetricChip(label: 'Reps', value: '${widget.metrics.repsCompleted}'),
              const SizedBox(width: 8),
              _MetricChip(label: 'Form', value: widget.metrics.formPercent),
              const SizedBox(width: 8),
              _MetricChip(label: 'Fatigue', value: widget.metrics.fatigueLabel),
            ],
          ),
          const SizedBox(height: 20),

          // Streaming coaching text
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.auto_awesome,
                    color: AppColors.primary, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: _text.isEmpty
                      ? const _TypingIndicator()
                      : Text(_text, style: AppTextStyles.bodyLarge),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Continue button — locked until streaming completes
          ElevatedButton(
            onPressed: _done ? widget.onContinue : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              disabledBackgroundColor: AppColors.border,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: Text(
              _done ? 'Continue' : 'Coach is thinking…',
              style: AppTextStyles.button,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          color: highlight
              ? AppColors.primary.withValues(alpha: 0.15)
              : AppColors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: highlight ? AppColors.primary : AppColors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value.isEmpty ? label : value,
                style: AppTextStyles.titleMedium.copyWith(
                  color: highlight ? AppColors.primary : AppColors.textPrimary,
                  fontSize: 14,
                ),
                maxLines: 1,
              ),
            ),
            if (value.isNotEmpty)
              Text(label, style: AppTextStyles.caption),
          ],
        ),
      ),
    );
  }
}

// Animated pulsing placeholder while waiting for the first Gemini token.
class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _fade = Tween<double>(begin: 0.3, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: Text('Analysing your set…', style: AppTextStyles.bodyMedium),
    );
  }
}
