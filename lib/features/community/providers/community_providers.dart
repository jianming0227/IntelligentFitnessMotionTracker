import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers/demo_mode_provider.dart';
import '../../../core/utils/app_log.dart';
import '../../auth/providers/auth_providers.dart';
import '../data/community_repository.dart';
import '../models/post.dart';

/// Community needs a real account: signed in and not offline demo mode.
bool canUseCommunity({required bool signedIn, required bool demoMode}) =>
    signedIn && !demoMode;

final isOnlineUserProvider = Provider<bool>((ref) {
  ref.watch(authStateStreamProvider); // re-check on sign-in / sign-out
  return canUseCommunity(
    signedIn: Supabase.instance.client.auth.currentSession != null,
    demoMode: ref.watch(demoModeProvider),
  );
});

final communityRepositoryProvider = Provider<CommunityRepository>(
  (_) => CommunityRepository(Supabase.instance.client),
);

/// Loaded feed pages.
class FeedState {
  const FeedState({required this.posts, required this.hasMore});

  final List<Post> posts;
  final bool hasMore;

  FeedState copyWith({List<Post>? posts, bool? hasMore}) =>
      FeedState(posts: posts ?? this.posts, hasMore: hasMore ?? this.hasMore);
}

class FeedController extends AsyncNotifier<FeedState> {
  bool _loadingMore = false;

  CommunityRepository get _repo => ref.read(communityRepositoryProvider);

  @override
  Future<FeedState> build() async {
    if (!ref.watch(isOnlineUserProvider)) {
      return const FeedState(posts: [], hasMore: false);
    }
    final posts = await _repo.fetchFeed();
    return FeedState(
      posts: posts,
      hasMore: posts.length == CommunityRepository.pageSize,
    );
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(build);
  }

  /// Next page, appended. No-op while loading or at the end.
  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore || _loadingMore) return;
    _loadingMore = true;
    try {
      final more = await _repo.fetchFeed(before: current.posts.last.createdAt);
      state = AsyncValue.data(
        current.copyWith(
          posts: [...current.posts, ...more],
          hasMore: more.length == CommunityRepository.pageSize,
        ),
      );
    } catch (e) {
      AppLog.warn('Community', 'Load more failed: $e');
    } finally {
      _loadingMore = false;
    }
  }

  /// A post just created: shown first without a reload.
  void prepend(Post post) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncValue.data(current.copyWith(posts: [post, ...current.posts]));
  }

  /// Optimistic like: the heart flips at once, and flips back if the request
  /// fails.
  Future<void> toggleLike(Post post) async {
    final liked = !post.likedByMe;
    _replace(post.withLike(liked));
    try {
      await _repo.setLike(post.id, liked: liked);
    } catch (e) {
      AppLog.warn('Community', 'Like failed: $e');
      _replace(post); // back to how it was
      rethrow;
    }
  }

  Future<void> delete(Post post) async {
    await _repo.deletePost(post);
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncValue.data(
      current.copyWith(
        posts: [
          for (final p in current.posts)
            if (p.id != post.id) p,
        ],
      ),
    );
  }

  void _replace(Post post) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncValue.data(
      current.copyWith(
        posts: [for (final p in current.posts) p.id == post.id ? post : p],
      ),
    );
  }
}

final feedProvider = AsyncNotifierProvider<FeedController, FeedState>(
  FeedController.new,
);

/// Posts shared since midnight (Home summary card). Reloads with the feed,
/// so a new post or a pull-to-refresh updates it too.
final sharedTodayProvider = FutureProvider<int>((ref) async {
  ref.watch(feedProvider);
  if (!ref.watch(isOnlineUserProvider)) return 0;
  final now = DateTime.now();
  return ref
      .read(communityRepositoryProvider)
      .countSince(DateTime(now.year, now.month, now.day));
});

/// The signed-in user's display name (`profiles.full_name`), null if unset.
class DisplayNameController extends AsyncNotifier<String?> {
  @override
  Future<String?> build() async {
    if (!ref.watch(isOnlineUserProvider)) return null;
    try {
      return await ref.read(communityRepositoryProvider).fetchDisplayName();
    } catch (e) {
      AppLog.warn('Community', 'Display name fetch failed: $e');
      return null;
    }
  }

  Future<void> save(String name) async {
    await ref.read(communityRepositoryProvider).saveDisplayName(name);
    state = AsyncValue.data(name);
  }
}

final displayNameProvider =
    AsyncNotifierProvider<DisplayNameController, String?>(
      DisplayNameController.new,
    );
