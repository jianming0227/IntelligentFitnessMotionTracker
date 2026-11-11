import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../progress/logic/mascot_mood.dart';
import '../../progress/models/session_record.dart';
import '../../train/views/camera_view.dart';
import '../logic/plan_edits.dart';
import '../logic/schedule_logic.dart';
import 'plan_day_card.dart';

/// Decodes a Gemini-generated JSON map into native Flutter widgets.
/// Supports two node types: WorkoutPlanView (top-level) and SessionCard.
///
/// [records] and [weightKg] are app data shown around the plan (calendar
/// rings, month stats). [onPlanChanged] receives the whole plan after a user
/// edit; without it the plan is read-only.
Widget buildDynamicWidget(
  Map<String, dynamic> jsonNode,
  BuildContext context, {
  List<SessionRecord> records = const [],
  double weightKg = 70,
  ValueChanged<Map<String, dynamic>>? onPlanChanged,
}) {
  //8. Change the json map into widgets
  //Checked the type of json node (Gemini Prompt output json schema)
  return switch (jsonNode['type'] as String? ?? '') {
    'WorkoutPlanView' => _WorkoutPlanView(
      node: jsonNode,
      records: records,
      weightKg: weightKg,
      onChanged: onPlanChanged,
    ),
    'SessionCard' => PlanDayCard(
      card: jsonNode,
      status: PlanCardStatus.upcoming,
      onTap: () {},
      onAction: (_) {},
    ),
    _ => const SizedBox.shrink(),
  };
}

const _monthNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

DateTime _dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

// ── WorkoutPlanView: stats → calendar → daily plan → why this plan ─────────

class _WorkoutPlanView extends StatefulWidget {
  const _WorkoutPlanView({
    required this.node,
    required this.records,
    required this.weightKg,
    required this.onChanged,
  });

  final Map<String, dynamic> node;
  final List<SessionRecord> records;
  final double weightKg;
  final ValueChanged<Map<String, dynamic>>? onChanged;

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

  bool get _editable => widget.onChanged != null;

  void _save(Map<String, dynamic> plan) => widget.onChanged?.call(plan);

  /// A4: done / missed / skipped for a card on the selected day.
  PlanCardStatus _statusOf(
    Map<String, dynamic> card,
    List<SessionRecord> doneToday,
    DateTime today,
  ) {
    if (card['skipped'] == true) return PlanCardStatus.skipped;
    if (card['done'] == true) return PlanCardStatus.done;
    final target = exerciseForActionId(card['actionId'] as String?);
    if (isRestSession(card)) {
      return PlanCardStatus.upcoming; // AI rest / recovery card
    }
    if (target != null &&
        doneToday.any(
          (r) => r.exerciseName.toLowerCase() == target.name.toLowerCase(),
        )) {
      return PlanCardStatus.done;
    }
    return _selected.isBefore(today)
        ? PlanCardStatus.missed
        : PlanCardStatus.upcoming;
  }

  Future<void> _openDetails(PlanEntry entry, PlanCardStatus status) async {
    if (!_editable) return;
    final action = await showPlanDetailSheet(
      context,
      card: entry.card,
      status: status,
    );
    if (action != null && mounted) await _handle(entry, action);
  }

  Future<void> _handle(PlanEntry entry, PlanCardAction action) async {
    final plan = widget.node;
    final card = entry.card;
    switch (action) {
      case PlanCardAction.play:
        final target = exerciseForActionId(card['actionId'] as String?);
        if (target != null) {
          // The card id links the finished workout back to this card.
          context.push(
            '/train/camera',
            extra: CameraLaunch(target, planSessionId: card['id'] as String?),
          );
        }
      case PlanCardAction.toggleDone:
        _save(setDone(plan, entry.index, card['done'] != true));
      case PlanCardAction.toggleSkip:
        _save(setSkipped(plan, entry.index, card['skipped'] != true));
      case PlanCardAction.delete:
        _delete(entry);
      case PlanCardAction.edit:
        final edit = await showPlanEditSheet(
          context,
          card: card,
          date: _selected,
        );
        if (edit == null || !mounted) return;
        _save(editSession(plan, entry.index, edit));
        _select(DateTime(edit.date.year, edit.date.month, edit.date.day));
    }
  }

  /// Removes a card, with an Undo that puts the old plan back.
  void _delete(PlanEntry entry) {
    final before = widget.node;
    _save(removeSession(before, entry.index));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('${entry.card['exercise'] ?? 'Workout'} removed'),
          action: SnackBarAction(label: 'Undo', onPressed: () => _save(before)),
        ),
      );
  }

  Future<void> _add() async {
    final edit = await showPlanEditSheet(context, date: _selected);
    if (edit == null || !mounted) return;
    _save(addSession(widget.node, edit));
    _select(DateTime(edit.date.year, edit.date.month, edit.date.day));
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = _dayOf(now);
    final node = widget.node;
    // One sentence: older plans have 2-3 sentence notes.
    final coachNote = firstSentences(
      node['coachNote'] as String? ?? '',
      count: 1,
    );
    final stats = monthStats(widget.records, _month, widget.weightKg);
    final days = planDays(node, now);
    final planned = plannedRestByDay(days);
    final trained = {
      ...trainedDays(widget.records),
      for (final d in days)
        if (d.done) d.date,
    };
    final entries = planEntriesOn(node, _selected, now);
    final done = sessionsOn(widget.records, _selected);

    return ListView(
      // Always scrollable so pull-to-refresh works on a short day.
      physics: const AlwaysScrollableScrollPhysics(),
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
                value:
                    '${stats.daysCompleted} '
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
          today: today,
          trained: trained,
          planned: planned,
          onPrev: () => _shiftMonth(-1),
          onNext: () => _shiftMonth(1),
          onSelect: _select,
        ),
        const SizedBox(height: 24),
        _DailyPlanTitle(day: _selected, onAdd: _editable ? _add : null),
        const SizedBox(height: 12),
        for (final e in entries) ...[
          Builder(
            builder: (context) {
              final status = _statusOf(e.card, done, today);
              final card = PlanDayCard(
                card: e.card,
                status: status,
                onTap: () => _openDetails(e, status),
                onAction: (a) => _handle(e, a),
              );
              if (!_editable) return card;
              // Swipe left to delete (Undo in the snackbar).
              return Dismissible(
                key: ValueKey(
                  '${e.index}|${e.card['date']}|${e.card['exercise']}',
                ),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 24),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.error,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: const Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.white,
                  ),
                ),
                onDismissed: (_) => _delete(e),
                child: card,
              );
            },
          ),
          const SizedBox(height: 12),
        ],
        for (final r in done) ...[
          _DoneRow(record: r),
          const SizedBox(height: 10),
        ],
        if (entries.isEmpty && done.isEmpty)
          _EmptyDay(onAdd: _editable ? _add : null),
        const SizedBox(height: 22),
        _WhyThisPlan(text: coachNote),
      ],
    );
  }
}

// ── Stat cards ───────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

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
            for (final d in const [
              'Mon',
              'Tue',
              'Wed',
              'Thu',
              'Fri',
              'Sat',
              'Sun',
            ])
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
    final style = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: cs.onSurface.withValues(alpha: 0.6));
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
      children: [
        mark,
        const SizedBox(width: 6),
        Text(label, style: style),
      ],
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
  const _DailyPlanTitle({required this.day, required this.onAdd});

  final DateTime day;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Row(
      children: [
        Expanded(
          child: Text.rich(
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
          ),
        ),
        if (onAdd != null)
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: cs.primary),
            icon: const Icon(Icons.add_rounded, size: 20),
            label: const Text('Add'),
            onPressed: onAdd,
          ),
      ],
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
  const _EmptyDay({required this.onAdd});

  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.onSurface.withValues(alpha: 0.12)),
      ),
      child: Column(
        children: [
          Text(
            'Nothing planned for this day.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: cs.onSurface.withValues(alpha: 0.6),
            ),
          ),
          if (onAdd != null) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add a workout'),
              onPressed: onAdd,
            ),
          ],
        ],
      ),
    );
  }
}

// ── Why this plan ────────────────────────────────────────────────────────────

/// The coach note, kept to one short reason for this plan.
class _WhyThisPlan extends StatelessWidget {
  const _WhyThisPlan({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    if (text.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_outline_rounded, size: 20, color: cs.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Why this plan',
                  style: tt.labelMedium?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(text, style: tt.bodyMedium?.copyWith(height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
