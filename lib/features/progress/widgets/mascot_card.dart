import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../plan/controllers/plan_controller.dart';
import '../logic/mascot_mood.dart';
import '../logic/progress_stats.dart';
import '../providers/progress_providers.dart';
import 'flick_sheet.dart';
import 'mascot/flick_mascot.dart';

/// "This week" card at the top of the Progress tab: Flick on the left, the
/// week's KPIs as a 2x2 grid on the right ([kpis]). Flick's mood comes from
/// the plan + session history; a finished plan or a PR set today plays the
/// celebration once (the key is remembered per account).
///
/// Tap Flick: he wiggles and a sheet explains his mood with a "keep Flick
/// happy" checklist. First visit: a one-time hint strip introduces him.
/// Debug builds: long-press Flick to cycle moods (handy for demos).
class MascotCard extends ConsumerStatefulWidget {
  const MascotCard({super.key, required this.kpis});

  /// Usually a 2x2 KPI grid; fills the space to the right of Flick.
  final Widget kpis;

  @override
  ConsumerState<MascotCard> createState() => _MascotCardState();
}

class _MascotCardState extends ConsumerState<MascotCard> {
  String? _celebrateToken;
  String? _checkedKey;
  MascotMood? _debugMood;
  bool _showHint = false;

  String get _uid => Supabase.instance.client.auth.currentUser?.id ?? 'demo';
  String get _prefsKey => '${_uid}_mascot_celebrated';
  String get _hintKey => '${_uid}_flick_hint_seen';

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((prefs) {
      if (mounted && !(prefs.getBool(_hintKey) ?? false)) {
        setState(() => _showHint = true);
      }
    });
  }

  Future<void> _dismissHint() async {
    if (!_showHint) return;
    setState(() => _showHint = false);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hintKey, true);
  }

  void _openSheet(MascotStatus status) {
    _dismissHint();
    showFlickSheet(
      context,
      status: status,
      onPreviewCelebration: kDebugMode
          ? () => setState(
                () => _celebrateToken = 'debug-${DateTime.now().millisecondsSinceEpoch}',
              )
          : null,
    );
  }

  /// Plays the celebration if [key] hasn't been celebrated before.
  Future<void> _maybeCelebrate(String? key) async {
    if (key == null || key == _checkedKey) return;
    _checkedKey = key;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_prefsKey) == key) return;
    await prefs.setString(_prefsKey, key);
    if (mounted) setState(() => _celebrateToken = key);
  }

  @override
  Widget build(BuildContext context) {
    final records = ref.watch(sessionHistoryProvider).value ?? const [];
    final plan = ref.watch(planProvider).value;
    final now = DateTime.now();
    final dates = [for (final r in records) ?r.date];

    final realStatus = mascotStatusFor(plan: plan, sessionDates: dates, now: now);
    final mood = _debugMood ?? realStatus.mood;
    // A debug mood override keeps the real checklist but shows the forced mood.
    final status = _debugMood == null
        ? realStatus
        : MascotStatus(
            mood: _debugMood!,
            headline: '${realStatus.headline} (debug: ${_debugMood!.name})',
            reason: realStatus.reason,
            checklist: realStatus.checklist,
          );
    final prs = personalRecords(records);
    final key = celebrationKey(
      plan: plan,
      sessionDates: dates,
      now: now,
      mostRepsRecord: prs.mostRepsInSet == null
          ? null
          : (value: prs.mostRepsInSet!.value, date: prs.mostRepsInSet!.date),
      bestFormRecord: prs.bestFormSession == null
          ? null
          : (value: prs.bestFormSession!.value, date: prs.bestFormSession!.date),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeCelebrate(key));

    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 12, 12, 12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              GestureDetector(
                onLongPress: kDebugMode
                    ? () => setState(() {
                          _debugMood = MascotMood
                              .values[(mood.index + 1) % MascotMood.values.length];
                        })
                    : null,
                child: FlickMascot(
                  mood: mood,
                  size: 124,
                  celebrateToken: _celebrateToken,
                  onTap: () => _openSheet(status),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(child: widget.kpis),
            ],
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            child: !_showHint
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.fromLTRB(8, 10, 0, 0),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: cs.primary.withValues(alpha: 0.45)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.touch_app_rounded, size: 20, color: cs.primary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Meet Flick! He reacts to your training plan. '
                              'Tap him to see how to keep him happy.',
                              style: tt.bodyMedium?.copyWith(fontSize: 13),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Dismiss',
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.close_rounded, size: 18),
                            onPressed: _dismissHint,
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
