import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../logic/community_format.dart';
import '../models/post.dart';
import '../providers/community_providers.dart';
import 'community_common.dart';

/// Progress-tab card: the two newest community posts and a way into the feed.
class CommunityPreviewCard extends ConsumerWidget {
  const CommunityPreviewCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final online = ref.watch(isOnlineUserProvider);
    final muted = cs.onSurface.withValues(alpha: 0.6);

    Widget body;
    if (!online) {
      body = const CommunitySignInNotice(compact: true);
    } else {
      body = ref
          .watch(feedProvider)
          .when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
            error: (_, _) => Text(
              'Could not load posts. Open Community to try again.',
              style: tt.bodyMedium?.copyWith(color: muted),
            ),
            data: (state) => state.posts.isEmpty
                ? Text(
                    'No posts yet. Share a workout from its summary page.',
                    style: tt.bodyMedium?.copyWith(color: muted),
                  )
                : Column(
                    children: [
                      for (final (i, post) in state.posts.take(2).indexed) ...[
                        if (i > 0) const Divider(height: 20),
                        _PostLine(post: post),
                      ],
                    ],
                  ),
          );
    }

    return Material(
      color: cs.surface,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: online ? () => context.push('/community') : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.groups_rounded, size: 20, color: cs.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Community',
                      style: tt.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (online)
                    Text(
                      'See all',
                      style: tt.labelLarge?.copyWith(color: cs.primary),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              body,
            ],
          ),
        ),
      ),
    );
  }
}

class _PostLine extends StatelessWidget {
  const _PostLine({required this.post});
  final Post post;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final muted = cs.onSurface.withValues(alpha: 0.6);
    return Row(
      children: [
        InitialAvatar(name: post.authorName, size: 34),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                post.authorName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                '${post.exerciseName} · ${post.stats.reps} reps · '
                '${timeAgo(post.createdAt, DateTime.now())}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tt.bodySmall?.copyWith(color: muted),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Icon(
          post.likedByMe
              ? Icons.favorite_rounded
              : Icons.favorite_border_rounded,
          size: 16,
          color: post.likedByMe ? cs.primary : muted,
        ),
        const SizedBox(width: 4),
        Text('${post.likeCount}', style: tt.bodySmall?.copyWith(color: muted)),
      ],
    );
  }
}
