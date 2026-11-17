import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/app_log.dart';
import '../../plan/logic/plan_sync.dart';
import '../models/post.dart';

/// Supabase access for the Community feature: `posts`, `post_likes`,
/// `profiles.full_name` and the `community-posts` Storage bucket.
/// Every call needs a signed-in user (the screens check that first).
class CommunityRepository {
  CommunityRepository(this._client);

  final SupabaseClient _client;

  static const pageSize = 20;
  static const _bucket = 'community-posts';

  String get _uid {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw StateError('Community needs a signed-in user');
    return id;
  }

  /// Newest posts first; [before] loads the page after the last post shown.
  Future<List<Post>> fetchFeed({DateTime? before}) async {
    var query = _client.from('posts').select('*, post_likes(count)');
    if (before != null) {
      query = query.lt('created_at', before.toUtc().toIso8601String());
    }
    final rows = await query
        .order('created_at', ascending: false)
        .limit(pageSize);
    final ids = [for (final r in rows) r['id']];
    final liked = ids.isEmpty
        ? const <String>{}
        : {
            for (final r
                in await _client
                    .from('post_likes')
                    .select('post_id')
                    .eq('user_id', _uid)
                    .inFilter('post_id', ids))
              r['post_id'] as String,
          };
    return [
      for (final r in rows)
        ?Post.fromJson(r, likedByMe: liked.contains(r['id'])),
    ];
  }

  /// How many posts were made since [since] (e.g. the start of today).
  Future<int> countSince(DateTime since) => _client
      .from('posts')
      .count(CountOption.exact)
      .gte('created_at', since.toUtc().toIso8601String());

  /// Uploads the card image (when given), then inserts the post.
  Future<Post> createPost({
    required String authorName,
    required String exerciseName,
    required PostStats stats,
    String? caption,
    Uint8List? imagePng,
    String? workoutSessionId,
  }) async {
    final uid = _uid;
    final id = newCardId();
    String? imageUrl;
    if (imagePng != null) {
      final path = '$uid/$id.png';
      await _client.storage
          .from(_bucket)
          .uploadBinary(
            path,
            imagePng,
            fileOptions: const FileOptions(contentType: 'image/png'),
          );
      imageUrl = _client.storage.from(_bucket).getPublicUrl(path);
    }
    final row = await _client
        .from('posts')
        .insert({
          'id': id,
          'user_id': uid,
          'author_name': authorName,
          'exercise_name': exerciseName,
          'stats': stats.toJson(),
          'caption': ?caption,
          'image_url': ?imageUrl,
          'workout_session_id': ?workoutSessionId,
        })
        .select('*, post_likes(count)')
        .single();
    AppLog.ok('Community', 'Posted $exerciseName');
    return Post.fromJson(row)!;
  }

  /// Deletes the post (likes go with it) and its image.
  Future<void> deletePost(Post post) async {
    await _client.from('posts').delete().eq('id', post.id);
    if (post.imageUrl != null) {
      try {
        await _client.storage.from(_bucket).remove(['$_uid/${post.id}.png']);
      } catch (e) {
        AppLog.warn('Community', 'Post image not removed: $e');
      }
    }
  }

  Future<void> setLike(String postId, {required bool liked}) async {
    if (liked) {
      await _client.from('post_likes').upsert({
        'post_id': postId,
        'user_id': _uid,
      }, onConflict: 'post_id,user_id');
    } else {
      await _client
          .from('post_likes')
          .delete()
          .eq('post_id', postId)
          .eq('user_id', _uid);
    }
  }

  /// `profiles.full_name` of the signed-in user, null when not set.
  Future<String?> fetchDisplayName() async {
    final rows = await _client
        .from('profiles')
        .select('full_name')
        .eq('id', _uid)
        .limit(1);
    final name = rows.isEmpty ? null : rows.first['full_name'] as String?;
    return name?.trim().isEmpty ?? true ? null : name!.trim();
  }

  Future<void> saveDisplayName(String name) async {
    await _client.from('profiles').upsert({
      'id': _uid,
      'full_name': name,
    }, onConflict: 'id');
  }
}
