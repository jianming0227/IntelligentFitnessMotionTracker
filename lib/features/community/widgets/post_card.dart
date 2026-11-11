import 'package:flutter/material.dart';

import '../logic/community_format.dart';
import '../models/post.dart';
import 'community_common.dart';

/// One post in the feed: author, time, caption, card image, likes.
class PostCard extends StatelessWidget {
  const PostCard({
    super.key,
    required this.post,
    required this.isMine,
    required this.onLike,
    this.onDelete,
    this.now,
  });

  final Post post;
  final bool isMine;
  final VoidCallback onLike;
  final VoidCallback? onDelete;

  /// For tests; defaults to the current time.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final muted = cs.onSurface.withValues(alpha: 0.6);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              InitialAvatar(name: post.authorName),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.authorName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${post.exerciseName} · '
                      '${timeAgo(post.createdAt, now ?? DateTime.now())}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.bodySmall?.copyWith(color: muted),
                    ),
                  ],
                ),
              ),
              if (isMine && onDelete != null)
                // onSelected runs after the menu closes, so the confirm
                // dialog it opens isn't popped along with the menu.
                PopupMenuButton<String>(
                  tooltip: 'More',
                  icon: Icon(Icons.more_horiz_rounded, color: muted),
                  onSelected: (_) => onDelete!(),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'delete', child: Text('Delete post')),
                  ],
                )
              else
                const SizedBox(width: 8),
            ],
          ),
          if (post.caption != null) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                post.caption!,
                style: tt.bodyMedium?.copyWith(height: 1.4),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: post.imageUrl == null
                ? _StatsStrip(stats: post.stats)
                : ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: AspectRatio(
                      aspectRatio: 4 / 5,
                      child: Image.network(
                        post.imageUrl!,
                        fit: BoxFit.cover,
                        loadingBuilder: (_, child, progress) => progress == null
                            ? child
                            : ColoredBox(
                                color: cs.onSurface.withValues(alpha: 0.06),
                              ),
                        errorBuilder: (_, _, _) =>
                            _StatsStrip(stats: post.stats),
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              IconButton(
                tooltip: post.likedByMe ? 'Unlike' : 'Like',
                onPressed: onLike,
                icon: Icon(
                  post.likedByMe
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: post.likedByMe ? cs.primary : muted,
                ),
              ),
              Text(
                post.likeCount == 1 ? '1 like' : '${post.likeCount} likes',
                style: tt.bodySmall?.copyWith(color: muted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Reps / form / time / kcal in one row; used when a post has no image.
class _StatsStrip extends StatelessWidget {
  const _StatsStrip({required this.stats});
  final PostStats stats;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final items = [
      ('${stats.reps}', 'Reps'),
      (stats.avgFormPct == null ? '–' : '${stats.avgFormPct}%', 'Form'),
      (formatDuration(stats.durationMs), 'Time'),
      (stats.kcal == null ? '–' : '${stats.kcal}', 'kcal'),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: cs.onSurface.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          for (final (value, label) in items)
            Expanded(
              child: Column(
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      value,
                      style: tt.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    label,
                    style: tt.bodySmall?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
