import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/friendly_error.dart';
import '../models/post.dart';
import '../providers/community_providers.dart';
import '../widgets/community_common.dart';
import '../widgets/post_card.dart';

/// Community feed: every user's shared workouts, newest first. Pull to
/// refresh; older posts load when scrolling near the end.
class CommunityView extends ConsumerWidget {
  const CommunityView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = ref.watch(isOnlineUserProvider);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/home'),
        ),
        title: const Text('Community'),
        centerTitle: true,
      ),
      body: online ? const _Feed() : const CommunitySignInNotice(),
    );
  }
}

class _Feed extends ConsumerWidget {
  const _Feed();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(feedProvider);
    final myId = Supabase.instance.client.auth.currentUser?.id;
    final notifier = ref.read(feedProvider.notifier);

    return RefreshIndicator(
      onRefresh: notifier.refresh,
      child: feed.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _Scrollable(
          child: _Message(
            icon: Icons.wifi_off_rounded,
            title: 'Could not load the feed',
            body: friendlyError(e),
            action: TextButton(
              onPressed: notifier.refresh,
              child: const Text('Try again'),
            ),
          ),
        ),
        data: (state) => state.posts.isEmpty
            ? const _Scrollable(
                child: _Message(
                  icon: Icons.groups_outlined,
                  title: 'No posts yet',
                  body:
                      'Finish a workout and tap Share on the summary page '
                      'to post the first one.',
                ),
              )
            : NotificationListener<ScrollNotification>(
                onNotification: (n) {
                  if (n.metrics.extentAfter < 600) notifier.loadMore();
                  return false;
                },
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  itemCount: state.posts.length + (state.hasMore ? 1 : 0),
                  separatorBuilder: (_, _) => const SizedBox(height: 14),
                  itemBuilder: (context, i) {
                    if (i == state.posts.length) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      );
                    }
                    final post = state.posts[i];
                    return PostCard(
                      post: post,
                      isMine: post.userId == myId,
                      onLike: () => _like(context, ref, post),
                      onDelete: () => _delete(context, ref, post),
                    );
                  },
                ),
              ),
      ),
    );
  }

  Future<void> _like(BuildContext context, WidgetRef ref, Post post) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(feedProvider.notifier).toggleLike(post);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Post post) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete post?'),
        content: const Text('It will be removed from the community feed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              'Delete',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(feedProvider.notifier).delete(post);
      messenger.showSnackBar(const SnackBar(content: Text('Post deleted')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }
}

/// Lets pull-to-refresh work on the empty and error states.
class _Scrollable extends StatelessWidget {
  const _Scrollable({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    required this.body,
    this.action,
  });

  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final muted = cs.onSurface.withValues(alpha: 0.6);
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: muted),
          const SizedBox(height: 16),
          Text(title, style: tt.titleMedium, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            body,
            textAlign: TextAlign.center,
            style: tt.bodyMedium?.copyWith(color: muted, height: 1.4),
          ),
          if (action != null) ...[const SizedBox(height: 12), action!],
        ],
      ),
    );
  }
}
