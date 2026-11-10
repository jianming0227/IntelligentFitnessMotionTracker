import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../progress/logic/mascot_mood.dart';
import '../../progress/models/session_record.dart';
import '../../progress/widgets/mascot/flick_mascot.dart';
import '../../train/data/exercise_images.dart';
import '../../train/models/exercise.dart';
import '../logic/schedule_logic.dart';

/// Decodes a Gemini-generated JSON map into native Flutter widgets.
/// Supports two node types: WorkoutPlanView (top-level) and SessionCard.
///
/// [records], [weightKg] and [mood] are app data shown around the plan
/// (calendar rings, month stats, Flick's mood); the JSON format is unchanged.
Widget buildDynamicWidget(
  Map<String, dynamic> jsonNode,
  BuildContext context, {
  List<SessionRecord> records = const [],
  double weightKg = 70,
  MascotMood mood = MascotMood.idle,
}) {
  //8. Change the json map into widgets
  //Checked the type of json node (Gemini Prompt output json schema)
  return switch (jsonNode['type'] as String? ?? '') {
    'WorkoutPlanView' => _WorkoutPlanView(
        node: jsonNode,
        records: records,
        weightKg: weightKg,
        mood: mood,
      ),
    'SessionCard' => _DayPlanCard(node: jsonNode),
    _ => const SizedBox.shrink(),
  };
}

const _monthNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

DateTime _dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

// ── WorkoutPlanView: stats → calendar → daily plan → Flick ──────────────────

class _WorkoutPlanView extends StatefulWidget {
  const _WorkoutPlanView({
    required this.node,
    required this.records,
    required this.weightKg,
    required this.mood,
  });

  final Map<String, dynamic> node;
  final List<SessionRecord> records;
  final double weightKg;
  final MascotMood mood;

  @override
  State<_WorkoutPlanView> createState() => _WorkoutPlanViewState();
}

class _WorkoutPlanViewState extends State<_WorkoutPlanView> {
  late DateTime _month; // first day of the month on screen
  late DateTime _selected;

  @override
  void initState() {
    super.initState();
    final today = _dayOf(DateTime.now());
    _selected = today;
    _month = DateTime(today.year, today.month);
  }

  void _shiftMonth(int delta) =>
      setState(() => _month = DateTime(_month.year, _month.month + delta));

  void _select(DateTime day) => setState(() {
    _selected = day;
    _month = DateTime(day.year, day.month);
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final node = widget.node;
    final title = node['title'] as String? ?? 'Your Adaptive Plan';
    final coachNote = firstSentences(node['coachNote'] as String? ?? '');
    final stats = monthStats(widget.records, _month, widget.weightKg);
    final planned = {
      for (final d in planDays(node, now)) d.date: d.isRest,
    };
    final cards = planCardsOn(node, _selected, now);
    final done = sessionsOn(widget.records, _selected);

    return ListView(
      // Bottom padding clears the floating nav bar.
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: 'Total kcal burned',
                value: stats.kcal.round().toString(),
                icon: Icons.local_fire_department_rounded,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                label: 'Days completed',
                value: '${stats.daysCompleted} '
                    '${stats.daysCompleted == 1 ? 'day' : 'days'}',
                icon: Icons.check_circle_outline_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _Calendar(
          month: _month,
          selected: _selected,
          today: _dayOf(now),
          trained: trainedDays(widget.records),
          planned: planned,
          onPrev: () => _shiftMonth(-1),
          onNext: () => _shiftMonth(1),
          onSelect: _select,
        ),
        const SizedBox(height: 24),
        _DailyPlanTitle(day: _selected),
        const SizedBox(height: 12),
        for (final c in cards) ...[
          _DayPlanCard(node: c),
          const SizedBox(height: 12),
        ],
        for (final r in done) ...[
          _DoneRow(record: r),
          const SizedBox(height: 10),
        ],
        if (cards.isEmpty && done.isEmpty) const _EmptyDay(),
        const SizedBox(height: 22),
        _FlickSays(mood: widget.mood, title: title, text: coachNote),
      ],
    );
  }
}

// ── Stat cards ───────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, required this.icon});

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: tt.bodySmall?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
              Icon(icon, size: 20, color: cs.onSurface.withValues(alpha: 0.8)),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Calendar ─────────────────────────────────────────────────────────────────

class _Calendar extends StatelessWidget {
  const _Calendar({
    required this.month,
    required this.selected,
    required this.today,
    required this.trained,
    required this.planned,
    required this.onPrev,
    required this.onNext,
    required this.onSelect,
  });

  final DateTime month;
  final DateTime selected;
  final DateTime today;
  final Set<DateTime> trained;

  /// Plan day → is it a rest day.
  final Map<DateTime, bool> planned;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final lead = DateTime(month.year, month.month).weekday - 1; // Mon first
    final rows = ((lead + daysInMonth) / 7).ceil();
    final name = _monthNames[month.month - 1];
    final muted = cs.onSurface.withValues(alpha: 0.55);

    return Column(
      children: [
        Row(
          children: [
            Icon(Icons.calendar_month_rounded, size: 18, color: cs.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$name 1 - $name $daysInMonth, ${month.year}',
                style: tt.titleSmall?.copyWith(
                  color: cs.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.chevron_left_rounded),
              tooltip: 'Previous month',
              onPressed: onPrev,
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.chevron_right_rounded),
              tooltip: 'Next month',
              onPressed: onNext,
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (final d in const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'])
              Expanded(
                child: Center(
                  child: Text(d, style: tt.bodySmall?.copyWith(color: muted)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        for (var row = 0; row < rows; row++)
          Row(
            children: [
              for (var col = 0; col < 7; col++)
                Expanded(
                  child: _dayCell(
                    // Day arithmetic via the constructor keeps DST out of it.
                    DateTime(month.year, month.month, 1 + row * 7 + col - lead),
                  ),
                ),
            ],
          ),
        const SizedBox(height: 10),
        const _CalendarLegend(),
      ],
    );
  }

  Widget _dayCell(DateTime day) {
    final inMonth = day.month == month.month;
    return _DayCell(
      day: day,
      inMonth: inMonth,
      isToday: day == today,
      isSelected: day == selected,
      trained: inMonth && trained.contains(day),
      plannedRest: inMonth ? planned[day] : null,
      onTap: () => onSelect(day),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.inMonth,
    required this.isToday,
    required this.isSelected,
    required this.trained,
    required this.plannedRest,
    required this.onTap,
  });

  final DateTime day;
  final bool inMonth;
  final bool isToday;
  final bool isSelected;
  final bool trained;

  /// null = nothing planned, true = rest day, false = workout day.
  final bool? plannedRest;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final Color? fill = isSelected
        ? cs.primary
        : isToday
        ? cs.onSurface
        : null;
    final Color text = isSelected
        ? cs.onPrimary
        : isToday
        ? cs.surface
        : cs.onSurface.withValues(alpha: inMonth ? 0.9 : 0.25);
    final BoxBorder? border = trained
        ? Border.all(color: cs.onSurface.withValues(alpha: 0.85), width: 2)
        : plannedRest == false
        ? Border.all(color: cs.primary, width: 2)
        : null;

    return AspectRatio(
      aspectRatio: 1,
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: fill,
                  border: border,
                ),
              ),
              Text(
                '${day.day}',
                style: tt.bodyMedium?.copyWith(
                  color: text,
                  fontWeight: isToday || isSelected
                      ? FontWeight.w800
                      : FontWeight.w500,
                ),
              ),
              if (plannedRest == true)
                Positioned(
                  bottom: 4,
                  child: Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: cs.onSurface.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CalendarLegend extends StatelessWidget {
  const _CalendarLegend();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: cs.onSurface.withValues(alpha: 0.6),
    );
    Widget ring(Color c) => Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: c, width: 2),
      ),
    );
    Widget item(Widget mark, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [mark, const SizedBox(width: 6), Text(label, style: style)],
    );
    return Wrap(
      spacing: 16,
      runSpacing: 6,
      alignment: WrapAlignment.center,
      children: [
        item(ring(cs.onSurface.withValues(alpha: 0.85)), 'Trained'),
        item(ring(cs.primary), 'Planned'),
        item(
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: cs.onSurface.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
          ),
          'Rest day',
        ),
      ],
    );
  }
}

// ── Daily plan ───────────────────────────────────────────────────────────────

class _DailyPlanTitle extends StatelessWidget {
  const _DailyPlanTitle({required this.day});

  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Text.rich(
      TextSpan(
        style: tt.titleLarge,
        children: [
          const TextSpan(text: 'Daily plan: '),
          TextSpan(
            text: '${_monthNames[day.month - 1]} ${day.day}',
            style: TextStyle(color: cs.primary),
          ),
        ],
      ),
    );
  }
}

/// One plan `SessionCard`: details on the left, photo on the right, Play
/// below. Cards without a start action (rest / active recovery) get no Play.
class _DayPlanCard extends StatelessWidget {
  const _DayPlanCard({required this.node});

  final Map<String, dynamic> node;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final muted = cs.onSurface.withValues(alpha: 0.6);

    final day = node['day'] as String? ?? '';
    final time = node['time'] as String? ?? '';
    final exercise = node['exercise'] as String? ?? '';
    final volume = node['volume'] as String? ?? '';
    final intensity = node['intensity'] as String? ?? '';
    final target = _exerciseFromActionId(node['actionId'] as String?);
    final imagePath = target != null ? exerciseImageFor(target.id) : null;
    final placeholder = Center(
      child: Icon(
        target == null ? Icons.self_improvement_rounded : Icons.fitness_center,
        color: cs.primary,
        size: 30,
      ),
    );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      [day, time].where((s) => s.isNotEmpty).join(' · '),
                      style: tt.bodySmall?.copyWith(color: muted),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      exercise,
                      style: tt.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (volume.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(volume, style: tt.bodyMedium),
                    ],
                    if (intensity.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        intensity,
                        style: tt.bodySmall?.copyWith(color: muted),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: 104,
                  height: 88,
                  color: cs.onSurface.withValues(alpha: 0.08),
                  child: imagePath == null
                      ? placeholder
                      : Image.asset(
                          imagePath,
                          fit: BoxFit.cover,
                          alignment: const Alignment(0, -0.2),
                          errorBuilder: (_, _, _) => placeholder,
                        ),
                ),
              ),
            ],
          ),
          if (target != null) ...[
            const SizedBox(height: 14),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: cs.primary,
                foregroundColor: cs.onPrimary,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              icon: const Icon(Icons.play_circle_outline_rounded, size: 22),
              label: const Text('Play'),
              onPressed: () => context.push('/train/camera', extra: target),
            ),
          ],
        ],
      ),
    );
  }
}

/// A session already finished on the selected day.
class _DoneRow extends StatelessWidget {
  const _DoneRow({required this.record});

  final SessionRecord record;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.onSurface.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle_rounded, color: cs.primary, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Done: ${record.exerciseName}',
              style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          Text(
            '${record.totalReps} reps · ${record.avgFormPct}% form',
            style: tt.bodySmall?.copyWith(
              color: cs.onSurface.withValues(alpha: 0.65),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyDay extends StatelessWidget {
  const _EmptyDay();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.onSurface.withValues(alpha: 0.12)),
      ),
      child: Text(
        'Nothing planned for this day.',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: cs.onSurface.withValues(alpha: 0.6),
        ),
      ),
    );
  }
}

// ── Flick + speech bubble ────────────────────────────────────────────────────

class _FlickSays extends StatelessWidget {
  const _FlickSays({required this.mood, required this.title, required this.text});

  final MascotMood mood;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    if (text.isEmpty) return const SizedBox.shrink();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        FlickMascot(mood: mood, size: 92),
        Expanded(
          child: CustomPaint(
            painter: _BubbleTail(color: cs.surface),
            child: Container(
              margin: const EdgeInsets.only(left: 10, bottom: 18),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: tt.labelMedium?.copyWith(
                      color: cs.primary,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(text, style: tt.bodyMedium?.copyWith(height: 1.4)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Small triangle on the bubble's lower-left edge pointing at Flick.
class _BubbleTail extends CustomPainter {
  _BubbleTail({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height - 34;
    canvas.drawPath(
      Path()
        ..moveTo(12, y - 8)
        ..lineTo(0, y + 6)
        ..lineTo(16, y + 6)
        ..close(),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_BubbleTail old) => old.color != color;
}

/// Maps the Gemini-generated actionId to the local Exercise object so GoRouter
/// can hand a typed instance to CameraView.
Exercise? _exerciseFromActionId(String? actionId) {
  return switch (actionId) {
    'start_squat' => Exercise.all.firstWhere((e) => e.id == 'squat'),
    'start_bicep_curl' =>
      Exercise.all.firstWhere((e) => e.id == 'bicep_curl'),
    _ => null,
  };
}
