import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/user_profile_biometrics.dart';
import '../providers/profile_providers.dart';

/// FR-1.2: First-time biometric survey. A 6-step flow inspired by the modern
/// fitness onboarding UI — gender → age → weight → height → goal → activity
/// level. Each step uses a drag interaction (wheel picker, horizontal ruler)
/// rather than a form input.
class BiometricSurveyView extends ConsumerStatefulWidget {
  const BiometricSurveyView({super.key});

  @override
  ConsumerState<BiometricSurveyView> createState() =>
      _BiometricSurveyViewState();
}

class _BiometricSurveyViewState extends ConsumerState<BiometricSurveyView> {
  final _pageCtrl = PageController();
  int _step = 0;

  // ── Collected values ────────────────────────────────────────────────────────
  String _gender = 'Male';
  int _age = 25;
  double _weightKg = 60;
  int _heightCm = 170;
  String _goal = UserProfileBiometrics.goals[1]; // 'Get fitter'
  String _level = UserProfileBiometrics.levels[2]; // 'Intermediate'

  static const _stepCount = 6;

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  void _next() {
    HapticFeedback.lightImpact();
    if (_step < _stepCount - 1) {
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    } else {
      _finish();
    }
  }

  void _back() {
    if (_step == 0) return;
    HapticFeedback.lightImpact();
    _pageCtrl.previousPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _finish() async {
    await ref.read(profileProvider.notifier).save(
          gender: _gender,
          age: _age,
          heightCm: _heightCm.toDouble(),
          weightKg: _weightKg,
          fitnessGoal: _goal,
          experienceLevel: _level,
        );
    if (mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _step == _stepCount - 1;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _Header(step: _step, total: _stepCount),
            Expanded(
              child: PageView(
                controller: _pageCtrl,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _step = i),
                children: [
                  _GenderStep(
                    value: _gender,
                    onChanged: (v) => setState(() => _gender = v),
                  ),
                  _AgeStep(
                    value: _age,
                    onChanged: (v) => setState(() => _age = v),
                  ),
                  _WeightStep(
                    value: _weightKg,
                    onChanged: (v) => setState(() => _weightKg = v),
                  ),
                  _HeightStep(
                    value: _heightCm,
                    onChanged: (v) => setState(() => _heightCm = v),
                  ),
                  _PickerStep(
                    title: "What's your goal?",
                    subtitle: 'This helps us create your personalised plan',
                    options: UserProfileBiometrics.goals,
                    value: _goal,
                    onChanged: (v) => setState(() => _goal = v),
                  ),
                  _PickerStep(
                    title: 'Your regular physical activity level?',
                    subtitle: 'This helps us create your personalised plan',
                    options: UserProfileBiometrics.levels,
                    value: _level,
                    onChanged: (v) => setState(() => _level = v),
                  ),
                ],
              ),
            ),
            _NavBar(
              showBack: _step > 0,
              isLast: isLast,
              onBack: _back,
              onNext: _next,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Top header: progress dots + skip ──────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.step, required this.total});
  final int step;
  final int total;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Row(
        children: [
          for (var i = 0; i < total; i++)
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                height: 4,
                decoration: BoxDecoration(
                  color: i <= step
                      ? cs.primary
                      : cs.onSurface.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Bottom nav: back circle + Next/Start pill ─────────────────────────────────

class _NavBar extends StatelessWidget {
  const _NavBar({
    required this.showBack,
    required this.isLast,
    required this.onBack,
    required this.onNext,
  });

  final bool showBack;
  final bool isLast;
  final VoidCallback onBack;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Row(
        children: [
          if (showBack)
            Material(
              color: cs.surface,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onBack,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Icon(Icons.arrow_back_rounded,
                      color: cs.onSurface, size: 22),
                ),
              ),
            ),
          const Spacer(),
          SizedBox(
            width: 180,
            child: ElevatedButton.icon(
              onPressed: onNext,
              icon: Text(isLast ? 'Start' : 'Next'),
              label: const Icon(Icons.chevron_right_rounded, size: 22),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared step scaffold (title + subtitle + content) ─────────────────────────

class _StepScaffold extends StatelessWidget {
  const _StepScaffold({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            title,
            style: tt.titleLarge?.copyWith(fontSize: 26),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: tt.bodyMedium?.copyWith(
              color: cs.onSurface.withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Expanded(child: Center(child: child)),
        ],
      ),
    );
  }
}

// ── Step 1: Gender ────────────────────────────────────────────────────────────

class _GenderStep extends StatelessWidget {
  const _GenderStep({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return _StepScaffold(
      title: 'Tell us about yourself!',
      subtitle: 'To give you a better experience we need to know your gender',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _GenderBubble(
            label: 'Male',
            icon: Icons.male_rounded,
            selected: value == 'Male',
            onTap: () => onChanged('Male'),
          ),
          const SizedBox(height: 24),
          _GenderBubble(
            label: 'Female',
            icon: Icons.female_rounded,
            selected: value == 'Female',
            onTap: () => onChanged('Female'),
          ),
        ],
      ),
    );
  }
}

class _GenderBubble extends StatelessWidget {
  const _GenderBubble({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = selected ? cs.primary : cs.surface;
    final fg = selected
        ? cs.onPrimary
        : cs.onSurface.withValues(alpha: 0.7);

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 130,
        height: 130,
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: cs.primary.withValues(alpha: 0.3),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 52, color: fg),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Step 2: Age (vertical wheel) ──────────────────────────────────────────────

class _AgeStep extends StatelessWidget {
  const _AgeStep({required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return _StepScaffold(
      title: 'How old are you?',
      subtitle: 'This helps us create your personalised plan',
      child: _IntWheel(
        min: 10,
        max: 90,
        value: value,
        suffix: '',
        onChanged: onChanged,
      ),
    );
  }
}

// ── Step 3: Weight (horizontal ruler) ─────────────────────────────────────────

class _WeightStep extends StatelessWidget {
  const _WeightStep({required this.value, required this.onChanged});
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return _StepScaffold(
      title: "What's your weight?",
      subtitle: 'You can always change this later',
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value.toStringAsFixed(0),
                style: tt.displayLarge?.copyWith(fontSize: 64, height: 1.0),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'kg',
                  style: tt.titleMedium?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          _Ruler(
            min: 30,
            max: 200,
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

// ── Step 4: Height (vertical wheel) ───────────────────────────────────────────

class _HeightStep extends StatelessWidget {
  const _HeightStep({required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return _StepScaffold(
      title: "What's your height?",
      subtitle: 'This helps us create your personalised plan',
      child: _IntWheel(
        min: 120,
        max: 220,
        value: value,
        suffix: 'cm',
        onChanged: onChanged,
      ),
    );
  }
}

// ── Steps 5 & 6: String picker (goal + activity level) ────────────────────────

class _PickerStep extends StatelessWidget {
  const _PickerStep({
    required this.title,
    required this.subtitle,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final List<String> options;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return _StepScaffold(
      title: title,
      subtitle: subtitle,
      child: _StringWheel(
        options: options,
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Reusable drag widgets
// ─────────────────────────────────────────────────────────────────────────────

/// Vertical wheel picker for integers. Center item is the selected value,
/// underlined with the brand accent.
class _IntWheel extends StatefulWidget {
  const _IntWheel({
    required this.min,
    required this.max,
    required this.value,
    required this.suffix,
    required this.onChanged,
  });

  final int min;
  final int max;
  final int value;
  final String suffix;
  final ValueChanged<int> onChanged;

  @override
  State<_IntWheel> createState() => _IntWheelState();
}

class _IntWheelState extends State<_IntWheel> {
  late FixedExtentScrollController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = FixedExtentScrollController(
      initialItem: widget.value - widget.min,
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final count = widget.max - widget.min + 1;
    return SizedBox(
      height: 280,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Center underline pinned beneath the selected item.
          Positioned(
            bottom: 280 / 2 - 32,
            child: Container(
              width: 120,
              height: 2,
              color: cs.primary,
            ),
          ),
          ListWheelScrollView.useDelegate(
            controller: _ctrl,
            physics: const FixedExtentScrollPhysics(),
            itemExtent: 56,
            perspective: 0.003,
            diameterRatio: 1.6,
            onSelectedItemChanged: (i) {
              HapticFeedback.selectionClick();
              widget.onChanged(widget.min + i);
            },
            childDelegate: ListWheelChildBuilderDelegate(
              childCount: count,
              builder: (context, i) {
                final n = widget.min + i;
                final selected = n == widget.value;
                final color = selected
                    ? cs.onSurface
                    : cs.onSurface.withValues(alpha: 0.25);
                final style = (selected
                        ? tt.displayMedium?.copyWith(fontSize: 36)
                        : tt.titleLarge?.copyWith(fontSize: 22))
                    ?.copyWith(color: color);
                return Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('$n', style: style),
                      if (selected && widget.suffix.isNotEmpty) ...[
                        const SizedBox(width: 4),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            widget.suffix,
                            style: tt.bodyMedium?.copyWith(
                              color: cs.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Vertical wheel picker for string options. Same look as [_IntWheel].
class _StringWheel extends StatefulWidget {
  const _StringWheel({
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final List<String> options;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  State<_StringWheel> createState() => _StringWheelState();
}

class _StringWheelState extends State<_StringWheel> {
  late FixedExtentScrollController _ctrl;

  @override
  void initState() {
    super.initState();
    final idx = widget.options.indexOf(widget.value);
    _ctrl = FixedExtentScrollController(
      initialItem: idx < 0 ? 0 : idx,
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return SizedBox(
      height: 280,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            bottom: 280 / 2 - 32,
            child: Container(
              width: 160,
              height: 2,
              color: cs.primary,
            ),
          ),
          ListWheelScrollView.useDelegate(
            controller: _ctrl,
            physics: const FixedExtentScrollPhysics(),
            itemExtent: 52,
            perspective: 0.003,
            diameterRatio: 1.6,
            onSelectedItemChanged: (i) {
              HapticFeedback.selectionClick();
              widget.onChanged(widget.options[i]);
            },
            childDelegate: ListWheelChildBuilderDelegate(
              childCount: widget.options.length,
              builder: (context, i) {
                final option = widget.options[i];
                final selected = option == widget.value;
                final color = selected
                    ? cs.onSurface
                    : cs.onSurface.withValues(alpha: 0.25);
                final style = (selected
                        ? tt.titleLarge?.copyWith(fontSize: 22)
                        : tt.bodyLarge?.copyWith(fontSize: 18))
                    ?.copyWith(color: color);
                return Center(child: Text(option, style: style));
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Horizontal tick ruler. Drag left/right to scrub through a double range.
class _Ruler extends StatefulWidget {
  const _Ruler({
    required this.min,
    required this.max,
    required this.value,
    required this.onChanged,
  });

  final double min;
  final double max;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  State<_Ruler> createState() => _RulerState();
}

class _RulerState extends State<_Ruler> {
  static const double _pxPerUnit = 10.0;
  late ScrollController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = ScrollController(
      initialScrollOffset: (widget.value - widget.min) * _pxPerUnit,
    );
    _ctrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onScroll);
    _ctrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    final raw = widget.min + (_ctrl.offset / _pxPerUnit);
    final clamped = raw.clamp(widget.min, widget.max);
    if (clamped.round() != widget.value.round()) {
      HapticFeedback.selectionClick();
    }
    widget.onChanged(clamped.toDouble());
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: 90,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final halfWidth = constraints.maxWidth / 2;
          final totalUnits = (widget.max - widget.min).toInt();
          return Stack(
            alignment: Alignment.center,
            children: [
              ListView.builder(
                controller: _ctrl,
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: totalUnits + 1,
                itemBuilder: (context, i) {
                  final isMajor = i % 5 == 0;
                  return SizedBox(
                    width: _pxPerUnit,
                    child: Align(
                      alignment: Alignment.center,
                      child: Container(
                        width: isMajor ? 2 : 1,
                        height: isMajor ? 44 : 26,
                        color: cs.primary
                            .withValues(alpha: isMajor ? 0.95 : 0.55),
                      ),
                    ),
                  );
                },
                padding: EdgeInsets.symmetric(horizontal: halfWidth),
              ),
              // Center indicator
              IgnorePointer(
                child: Container(
                  width: 3,
                  height: 60,
                  decoration: BoxDecoration(
                    color: cs.onSurface,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
