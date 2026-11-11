import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../profile/models/user_profile_biometrics.dart';
import '../../profile/providers/profile_providers.dart';
import '../../progress/logic/streak.dart';
import '../../progress/providers/progress_providers.dart';
import '../logic/community_format.dart';
import '../providers/community_providers.dart';
import 'community_common.dart';
import 'share_card.dart';
import 'share_sheet.dart';

/// Home-screen community card: who has been posting, how many workouts were
/// shared today, the newest post, and a button to share your own workout.
/// Tapping the card opens the feed.
class CommunitySummaryCard extends ConsumerWidget {
  const CommunitySummaryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final online = ref.watch(isOnlineUserProvider);
    final muted = cs.onSurface.withValues(alpha: 0.6);

    final header = Row(
      children: [
        Icon(Icons.groups_rounded, size: 20, color: cs.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Community',
            style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        if (online)
          Text('See all', style: tt.labelLarge?.copyWith(color: cs.primary)),
      ],
    );

    if (!online) {
      return _Shell(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            const SizedBox(height: 12),
            const CommunitySignInNotice(compact: true),
          ],
        ),
      );
    }

    final posts = ref.watch(feedProvider).value?.posts ?? const [];
    final today = ref.watch(sharedTodayProvider).value;
    final authors = recentAuthors(posts);
    final latest = posts.firstOrNull;
    final records = ref.watch(sessionHistoryProvider).value ?? const [];

    return _Shell(
      onTap: () => context.push('/community'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          const SizedBox(height: 14),
          Row(
            children: [
              if (authors.isNotEmpty) ...[
                _AvatarStack(names: authors),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      today == null ? '–' : workoutsCount(today),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      today == 0
                          ? 'shared today. Be the first.'
                          : 'shared today',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.bodySmall?.copyWith(color: muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (latest != null) ...[
            Divider(height: 24, color: cs.onSurface.withValues(alpha: 0.08)),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: latest.authorName,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(
                    text:
                        '  ${latest.exerciseName} · ${latest.stats.reps} reps'
                        ' · ${timeAgo(latest.createdAt, DateTime.now())}',
                    style: TextStyle(color: muted),
                  ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tt.bodyMedium,
            ),
          ],
          const SizedBox(height: 14),
          FilledButton.tonalIcon(
            // Lime tint instead of the theme's secondary container colour.
            style: FilledButton.styleFrom(
              backgroundColor: cs.primary.withValues(alpha: 0.14),
              foregroundColor: cs.primary,
              minimumSize: const Size.fromHeight(44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: records.isEmpty
                ? () => context.go('/train')
                : () => _shareLatest(context, ref),
            icon: Icon(
              records.isEmpty
                  ? Icons.play_arrow_rounded
                  : Icons.ios_share_rounded,
              size: 18,
            ),
            label: Text(
              records.isEmpty ? 'Start a workout' : 'Share your last workout',
            ),
          ),
        ],
      ),
    );
  }

  /// Opens the share sheet for the newest workout in history.
  void _shareLatest(BuildContext context, WidgetRef ref) {
    final records = ref.read(sessionHistoryProvider).value ?? const [];
    if (records.isEmpty) return;
    final latest = records.last; // history is oldest first
    final now = DateTime.now();
    final weightKg =
        (ref.read(profileProvider).value ?? UserProfileBiometrics.defaults)
            .weightKg;
    showShareSheet(
      context,
      data: ShareCardData(
        exerciseName: latest.exerciseName,
        date: latest.date ?? now,
        streakDays: currentStreak(records.map((r) => r.date).nonNulls, now),
        stats: statsFromRecord(latest, weightKg: weightKg),
      ),
    );
  }
}

class _Shell extends StatelessWidget {
  const _Shell({required this.child, this.onTap});
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(padding: const EdgeInsets.all(16), child: child),
      ),
    );
  }
}

/// Up to three overlapping initials, newest poster in front.
class _AvatarStack extends StatelessWidget {
  const _AvatarStack({required this.names});
  final List<String> names;

  static const _size = 36.0;
  static const _step = 24.0;

  @override
  Widget build(BuildContext context) {
    final ring = Theme.of(context).colorScheme.surface;
    return SizedBox(
      width: _size + _step * (names.length - 1),
      height: _size,
      child: Stack(
        children: [
          // Drawn back to front so the first name sits on top.
          for (var i = names.length - 1; i >= 0; i--)
            Positioned(
              left: _step * i,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(color: ring, shape: BoxShape.circle),
                child: InitialAvatar(name: names[i], size: _size - 4),
              ),
            ),
        ],
      ),
    );
  }
}
