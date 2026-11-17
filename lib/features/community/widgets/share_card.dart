import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../logic/community_format.dart';
import '../models/post.dart';

enum ShareTemplate { stats, photo }

/// What a share card shows.
class ShareCardData {
  const ShareCardData({
    required this.exerciseName,
    required this.stats,
    required this.date,
    this.streakDays = 0,
  });

  final String exerciseName;
  final PostStats stats;
  final DateTime date;
  final int streakDays;
}

/// The shareable workout card, always laid out at [size] (4:5) and scaled
/// by the parent, so the exported PNG looks the same on every phone.
/// Colours are fixed (not the app theme): the card is an image for other
/// apps, it should look the same in light and dark mode.
class ShareCard extends StatelessWidget {
  const ShareCard({
    super.key,
    required this.data,
    required this.template,
    this.photo,
  });

  static const size = Size(320, 400);

  final ShareCardData data;
  final ShareTemplate template;

  /// Background for [ShareTemplate.photo]; without it the stats card shows.
  final File? photo;

  @override
  Widget build(BuildContext context) {
    final usePhoto = template == ShareTemplate.photo && photo != null;
    return SizedBox.fromSize(
      size: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: DefaultTextStyle(
          style: Theme.of(context).textTheme.bodyMedium!.copyWith(
            color: Colors.white,
            decoration: TextDecoration.none,
          ),
          child: usePhoto ? _PhotoLayout(data, photo!) : _StatsLayout(data),
        ),
      ),
    );
  }
}

const _lime = AppColors.accentLime;
const _muted = Color(0xB3FFFFFF); // white 70%

String _dateLabel(DateTime d) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[d.month - 1]} ${d.day}, ${d.year}';
}

/// "FITFORM" word mark + date.
class _Header extends StatelessWidget {
  const _Header(this.date);
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text(
          'FITFORM',
          style: TextStyle(
            color: _lime,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 2.4,
          ),
        ),
        const Spacer(),
        Text(
          _dateLabel(date),
          style: const TextStyle(color: _muted, fontSize: 12),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.value, this.label, {this.big = false});
  final String value;
  final String label;
  final bool big;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            maxLines: 1,
            style: TextStyle(
              color: Colors.white,
              fontSize: big ? 26 : 20,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: _muted,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }
}

List<(String, String)> _statItems(PostStats s) => [
  ('${s.reps}', 'Reps'),
  (s.avgFormPct == null ? '–' : '${s.avgFormPct}%', 'Avg form'),
  (formatDuration(s.durationMs), 'Time'),
  (s.kcal == null ? '–' : '${s.kcal}', 'kcal'),
];

class _StatsLayout extends StatelessWidget {
  const _StatsLayout(this.data);
  final ShareCardData data;

  @override
  Widget build(BuildContext context) {
    final items = _statItems(data.stats);
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E2127), Color(0xFF0A0B0D)],
        ),
      ),
      child: Stack(
        children: [
          // One faint lime ring as decoration, top right.
          Positioned(
            top: -95,
            right: -95,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: _lime.withValues(alpha: 0.25),
                  width: 18,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Header(data.date),
                const Spacer(),
                Text(
                  data.exerciseName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${data.stats.sets} ${data.stats.sets == 1 ? 'set' : 'sets'}'
                  ' completed',
                  style: const TextStyle(color: _muted, fontSize: 14),
                ),
                const SizedBox(height: 26),
                for (var row = 0; row < 2; row++) ...[
                  if (row > 0) const SizedBox(height: 18),
                  Row(
                    children: [
                      for (var col = 0; col < 2; col++)
                        Expanded(
                          child: _Stat(
                            items[row * 2 + col].$1,
                            items[row * 2 + col].$2,
                            big: true,
                          ),
                        ),
                    ],
                  ),
                ],
                if (data.streakDays >= 2) ...[
                  const SizedBox(height: 22),
                  _StreakPill(data.streakDays),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StreakPill extends StatelessWidget {
  const _StreakPill(this.days);
  final int days;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _lime,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$days-day streak',
        style: const TextStyle(
          color: Colors.black,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _PhotoLayout extends StatelessWidget {
  const _PhotoLayout(this.data, this.photo);
  final ShareCardData data;
  final File photo;

  @override
  Widget build(BuildContext context) {
    final items = _statItems(data.stats);
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.file(photo, fit: BoxFit.cover),
        // Darkens top and bottom so the text reads on any photo.
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0, 0.25, 0.5, 1],
              colors: [
                Color(0x99000000),
                Color(0x00000000),
                Color(0x00000000),
                Color(0xE6000000),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Header(data.date),
              const Spacer(),
              Text(
                data.exerciseName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  height: 1.05,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  for (final (i, (value, label)) in items.indexed) ...[
                    if (i > 0) const SizedBox(width: 10),
                    Expanded(child: _Stat(value, label)),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
