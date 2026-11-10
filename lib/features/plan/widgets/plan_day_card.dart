import 'package:flutter/material.dart';

import '../../progress/logic/mascot_mood.dart';
import '../../train/models/exercise.dart';
import '../logic/plan_edits.dart';

enum PlanCardStatus { upcoming, done, missed, skipped }

/// What the user picked in the detail sheet.
enum PlanCardAction { play, toggleDone, edit, toggleSkip, delete }

// ── A1-A4: compact day card ──────────────────────────────────────────────────

class PlanDayCard extends StatelessWidget {
  const PlanDayCard({
    super.key,
    required this.card,
    required this.status,
    required this.onTap,
    required this.onAction,
  });

  final Map<String, dynamic> card;
  final PlanCardStatus status;
  final VoidCallback onTap;
  final ValueChanged<PlanCardAction> onAction;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final muted = cs.onSurface.withValues(alpha: 0.6);

    final exercise = card['exercise'] as String? ?? 'Workout';
    final target = exerciseForActionId(card['actionId'] as String?);
    final custom = card['custom'] == true;
    final skipped = status == PlanCardStatus.skipped;
    final (:sets, :reps) = setsRepsOf(card);
    final isRestCard = !skipped && isRestSession(card);

    return Material(
      color: cs.surface,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Opacity(
            opacity: skipped ? 0.55 : 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            skipped ? 'Rest day' : exercise,
                            style: tt.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            skipped
                                ? '$exercise skipped'
                                : [
                                    card['userAdded'] == true
                                        ? 'Your workout'
                                        : card['day'],
                                    card['date'],
                                  ].whereType<String>().join(' · '),
                            style: tt.bodySmall?.copyWith(color: muted),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    _StatusTag(status: status, card: card),
                  ],
                ),
                if (!skipped && !isRestCard) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _InfoChip(icon: Icons.layers_rounded, text: '$sets sets'),
                      _InfoChip(icon: Icons.repeat_rounded, text: '$reps reps'),
                      if (card['time'] is String)
                        _InfoChip(
                          icon: Icons.schedule_rounded,
                          text: card['time'] as String,
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 14),
                if (skipped)
                  _OneLineButton(
                    icon: Icons.undo_rounded,
                    label: 'Undo skip',
                    onPressed: () => onAction(PlanCardAction.toggleSkip),
                  )
                else if (target != null &&
                    !isRestCard &&
                    status != PlanCardStatus.done)
                  _PrimaryButton(
                    icon: Icons.play_circle_outline_rounded,
                    label: 'Play',
                    onPressed: () => onAction(PlanCardAction.play),
                  )
                else if (custom)
                  _PrimaryButton(
                    icon: status == PlanCardStatus.done
                        ? Icons.undo_rounded
                        : Icons.check_rounded,
                    label: status == PlanCardStatus.done
                        ? 'Undo done'
                        : 'Mark done',
                    outlined: status == PlanCardStatus.done,
                    onPressed: () => onAction(PlanCardAction.toggleDone),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.onSurface.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: cs.primary),
          const SizedBox(width: 5),
          Text(
            text,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _StatusTag extends StatelessWidget {
  const _StatusTag({required this.status, required this.card});
  final PlanCardStatus status;
  final Map<String, dynamic> card;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final muted = cs.onSurface.withValues(alpha: 0.55);
    final (String? text, Color color) = switch (status) {
      PlanCardStatus.done => ('Done', cs.primary),
      PlanCardStatus.missed => ('Missed', muted),
      PlanCardStatus.skipped => (null, muted),
      PlanCardStatus.upcoming when card['userAdded'] == true => (
        'Added',
        muted,
      ),
      PlanCardStatus.upcoming when card['edited'] == true => ('Edited', muted),
      PlanCardStatus.upcoming => (null, muted),
    };
    if (text == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Outlined icon + label that never wraps: the label scales down instead.
class _OneLineButton extends StatelessWidget {
  const _OneLineButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(46),
        padding: const EdgeInsets.symmetric(horizontal: 10),
      ),
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(label, maxLines: 1, softWrap: false),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.outlined = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(24),
    );
    if (outlined) {
      return OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(46),
          shape: shape,
        ),
        icon: Icon(icon, size: 20),
        label: Text(label),
        onPressed: onPressed,
      );
    }
    final cs = Theme.of(context).colorScheme;
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        minimumSize: const Size.fromHeight(46),
        shape: shape,
      ),
      icon: Icon(icon, size: 22),
      label: Text(label),
      onPressed: onPressed,
    );
  }
}

// ── A3: detail sheet ─────────────────────────────────────────────────────────

Future<PlanCardAction?> showPlanDetailSheet(
  BuildContext context, {
  required Map<String, dynamic> card,
  required PlanCardStatus status,
}) => showModalBottomSheet<PlanCardAction>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => _PlanDetailSheet(card: card, status: status),
);

class _PlanDetailSheet extends StatelessWidget {
  const _PlanDetailSheet({required this.card, required this.status});

  final Map<String, dynamic> card;
  final PlanCardStatus status;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final muted = cs.onSurface.withValues(alpha: 0.6);

    final custom = card['custom'] == true;
    final skipped = status == PlanCardStatus.skipped;
    // A recovery card can carry an actionId; it still gets no Play / volume.
    final target = !skipped && isRestSession(card)
        ? null
        : exerciseForActionId(card['actionId'] as String?);
    final done = status == PlanCardStatus.done;
    final (:sets, :reps) = setsRepsOf(card);
    void pick(PlanCardAction a) => Navigator.of(context).pop(a);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        card['exercise'] as String? ?? 'Workout',
                        style: tt.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        [
                          card['date'],
                          card['time'],
                        ].whereType<String>().join(' · '),
                        style: tt.bodyMedium?.copyWith(color: muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (target != null || custom)
              Text(
                volumeLabel(sets, reps),
                style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            if (target != null) ...[
              const SizedBox(height: 4),
              Text(
                'Works: ${_muscles(target)}',
                style: tt.bodyMedium?.copyWith(color: muted),
              ),
            ],
            if (custom) ...[
              const SizedBox(height: 4),
              Text(
                'Your own exercise. Not camera-tracked, tick it off when done.',
                style: tt.bodyMedium?.copyWith(color: muted),
              ),
            ],
            if (card['edited'] == true && card['aiVolume'] is String) ...[
              const SizedBox(height: 10),
              Text(
                'Coach suggested: ${card['aiExercise'] ?? ''} '
                '${card['aiVolume']}',
                style: tt.bodySmall?.copyWith(color: muted),
              ),
            ],
            const SizedBox(height: 20),
            if (!skipped && target != null && !done)
              _PrimaryButton(
                icon: Icons.play_circle_outline_rounded,
                label: 'Play',
                onPressed: () => pick(PlanCardAction.play),
              )
            else if (!skipped && custom)
              _PrimaryButton(
                icon: done ? Icons.undo_rounded : Icons.check_rounded,
                label: done ? 'Undo done' : 'Mark done',
                outlined: done,
                onPressed: () => pick(PlanCardAction.toggleDone),
              ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _OneLineButton(
                    icon: Icons.edit_rounded,
                    label: 'Edit',
                    onPressed: () => pick(PlanCardAction.edit),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _OneLineButton(
                    icon: skipped ? Icons.undo_rounded : Icons.bedtime_outlined,
                    label: skipped ? 'Undo skip' : 'Rest day',
                    onPressed: () => pick(PlanCardAction.toggleSkip),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.outlined(
                  tooltip: 'Delete',
                  icon: Icon(Icons.delete_outline_rounded, color: cs.error),
                  onPressed: () => pick(PlanCardAction.delete),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _muscles(Exercise e) => [
    ...e.primaryMuscles,
    ...e.secondaryMuscles,
  ].map((m) => m.label).join(', ');
}

// ── B1/B2/B4/B5/B6: edit or add sheet ────────────────────────────────────────

/// Opens the editor. [card] null = add a new workout on [date].
Future<SessionEdit?> showPlanEditSheet(
  BuildContext context, {
  Map<String, dynamic>? card,
  required DateTime date,
}) => showModalBottomSheet<SessionEdit>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => _PlanEditSheet(card: card, date: date),
);

class _PlanEditSheet extends StatefulWidget {
  const _PlanEditSheet({required this.card, required this.date});

  final Map<String, dynamic>? card;
  final DateTime date;

  @override
  State<_PlanEditSheet> createState() => _PlanEditSheetState();
}

class _PlanEditSheetState extends State<_PlanEditSheet> {
  late Exercise? _exercise; // null = own exercise
  late final TextEditingController _name;
  late int _sets;
  late int _reps;
  late TimeOfDay _time;
  late DateTime _date;

  @override
  void initState() {
    super.initState();
    final card = widget.card;
    final target = exerciseForActionId(card?['actionId'] as String?);
    final custom = card?['custom'] == true;
    _exercise = custom ? null : (target ?? Exercise.all.first);
    _name = TextEditingController(
      text: custom ? (card?['exercise'] as String?) ?? '' : '',
    );
    final sr = card == null ? (sets: 3, reps: 10) : setsRepsOf(card);
    _sets = sr.sets;
    _reps = sr.reps;
    final t = parsePlanTime(card?['time'] as String?);
    _time = t == null
        ? const TimeOfDay(hour: 8, minute: 0)
        : TimeOfDay(hour: t.hour, minute: t.minute);
    _date = widget.date;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool get _valid => _exercise != null || _name.text.trim().isNotEmpty;

  void _save() {
    final ex = _exercise;
    Navigator.of(context).pop(
      SessionEdit(
        exercise: ex?.name ?? _name.text.trim(),
        actionId: ex == null ? null : actionIdFor(ex),
        sets: _sets,
        reps: _reps,
        time: formatPlanTime(_time.hour, _time.minute),
        date: _date,
      ),
    );
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(context: context, initialTime: _time);
    if (t != null) setState(() => _time = t);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year, now.month, now.day - 30),
      lastDate: DateTime(now.year, now.month, now.day + 60),
    );
    if (d != null) setState(() => _date = d);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isAdd = widget.card == null;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isAdd ? 'Add workout' : 'Edit workout',
                style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              Text('Exercise', style: tt.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final e in Exercise.all)
                    _ExerciseChip(
                      label: e.name,
                      selected: _exercise == e,
                      onSelected: () => setState(() => _exercise = e),
                    ),
                  _ExerciseChip(
                    label: 'Own exercise',
                    selected: _exercise == null,
                    onSelected: () => setState(() => _exercise = null),
                  ),
                ],
              ),
              if (_exercise == null) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Exercise name',
                    hintText: 'e.g. Push-ups, Plank, Running',
                    helperText: 'Not camera-tracked. You tick it off yourself.',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ],
              const SizedBox(height: 18),
              _Stepper(
                label: 'Sets',
                value: _sets,
                min: 1,
                max: 10,
                onChanged: (v) => setState(() => _sets = v),
              ),
              const SizedBox(height: 8),
              _Stepper(
                label: 'Reps',
                value: _reps,
                min: 1,
                max: 50,
                onChanged: (v) => setState(() => _reps = v),
              ),
              const SizedBox(height: 8),
              _PickerTile(
                icon: Icons.calendar_today_rounded,
                label: 'Date',
                value: MaterialLocalizations.of(
                  context,
                ).formatMediumDate(_date),
                onTap: _pickDate,
              ),
              _PickerTile(
                icon: Icons.schedule_rounded,
                label: 'Time',
                value: formatPlanTime(_time.hour, _time.minute),
                onTap: _pickTime,
              ),
              const SizedBox(height: 18),
              FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _valid ? _save : null,
                child: Text(isAdd ? 'Add to plan' : 'Save changes'),
              ),
              if (!isAdd) ...[
                const SizedBox(height: 6),
                Text(
                  'Your changes are sent to the coach next time a plan is made.',
                  textAlign: TextAlign.center,
                  style: tt.bodySmall?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ExerciseChip extends StatelessWidget {
  const _ExerciseChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      selectedColor: cs.primary,
      labelStyle: TextStyle(
        color: selected ? cs.onPrimary : cs.onSurface,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
      onSelected: (_) => onSelected(),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Row(
      children: [
        Expanded(child: Text(label, style: tt.titleSmall)),
        IconButton.outlined(
          icon: const Icon(Icons.remove_rounded),
          onPressed: value > min ? () => onChanged(value - 1) : null,
        ),
        SizedBox(
          width: 48,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        IconButton.outlined(
          icon: const Icon(Icons.add_rounded),
          onPressed: value < max ? () => onChanged(value + 1) : null,
        ),
      ],
    );
  }
}

class _PickerTile extends StatelessWidget {
  const _PickerTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: cs.primary),
      title: Text(label),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
      onTap: onTap,
    );
  }
}
