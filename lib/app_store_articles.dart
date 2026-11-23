part of 'app_store.dart';

/// Article and comment interactions.
extension AppStoreArticles on AppStore {
  int get unread => notificationUnreadCount;
  Future<T?> perform<T>(String key, Future<T> Function() action) async {
    if (pending.contains(key)) return null;
    pending.add(key);
    changed();
    final version = epoch;
    try {
      return await action();
    } finally {
      if (version == epoch) {
        pending.remove(key);
        changed();
      }
    }
  }

  void _syncReaction(Story story, {required bool like}) {
    for (final entry in stories) {
      if (entry.id == story.id) {
        if (like) {
          entry.liked = story.liked;
          entry.likes = story.likes;
        } else {
          entry.saved = story.saved;
          entry.favorites = story.favorites;
        }
      }
    }
    changed();
  }

  Future<void> like(Story story) async => perform('like-${story.id}', () async {
    final version = epoch;
    final previous = story.liked;
    final previousCount = story.likes;
    final desired = !previous;
    story.liked = desired;
    story.likes = (previousCount + (desired ? 1 : -1)).clamp(0, 1 << 31);
    _syncReaction(story, like: true);
    try {
      final v = await request(
        desired ? 'PutArticlesIdLike' : 'DeleteArticlesIdLike',
        path: {'id': '${story.id}'},
        body: {},
      );
      if (!alive || version != epoch) return;
      story.liked = (v.data['is_liked'] ?? v.data['active'] ?? desired) == true;
      story.likes = v.data.containsKey('like_count')
          ? integer(v.data['like_count'])
          : (previousCount +
                    (story.liked == previous
                        ? 0
                        : story.liked
                        ? 1
                        : -1))
                .clamp(0, 1 << 31);
      _syncReaction(story, like: true);
    } catch (_) {
      if (alive && version == epoch) {
        story.liked = previous;
        story.likes = previousCount;
        _syncReaction(story, like: true);
      }
      rethrow;
    }
  });
  Future<void> bookmark(Story story) async =>
      perform('bookmark-${story.id}', () async {
        final version = epoch;
        final previous = story.saved;
        final previousCount = story.favorites;
        final desired = !previous;
        story.setBookmark(desired);
        _syncReaction(story, like: false);
        try {
          final v = await request(
            desired ? 'PutArticlesIdFavorite' : 'DeleteArticlesIdFavorite',
            path: {'id': '${story.id}'},
            body: {},
          );
          if (!alive || version != epoch) return;
          story.setBookmark(
            (v.data['is_favorited'] ?? v.data['active'] ?? desired) == true,
          );
          story.readBookmarkMetrics(v.data);
          _syncReaction(story, like: false);
        } catch (_) {
          if (alive && version == epoch) {
            story.saved = previous;
            story.favorites = previousCount;
            _syncReaction(story, like: false);
          }
          rethrow;
        }
      });
  Future<void> refreshArticleMetrics(int id) async {
    final version = epoch;
    try {
      final response = await request('GetArticlesId', path: {'id': '$id'});
      if (!alive || version != epoch) return;
      for (final story in stories.where((story) => story.id == id)) {
        if (response.data.containsKey('comment_count')) {
          story.commentCount = integer(response.data['comment_count']);
        }
        if (!pending.contains('bookmark-$id'))
          story.readBookmarkMetrics(response.data);
        if (!pending.contains('like-$id')) {
          if (response.data.containsKey('like_count')) {
            story.likes = integer(response.data['like_count']);
          }
          if (response.data.containsKey('is_liked')) {
            story.liked = response.data['is_liked'] == true;
          }
        }
      }
      changed();
    } catch (_) {
      // Keep the existing counts on temporary failures; pull-to-refresh retries.
    }
  }

  Future<void> article(Story story, {bool more = false}) async {
    final version = epoch;
    final cursor = more ? story.commentsCursor : '';
    if (more && cursor.isEmpty) return;
    final v = await request(
      'GetArticlesIdComments',
      path: {'id': '${story.id}'},
      query: {'limit': '30', if (cursor.isNotEmpty) 'cursor': cursor},
    );
    if (!alive || version != epoch) return;
    mergeContent('PostArticlesIdComments', story.id, items(v.data));
    final page = items(v.data).map(ArticleComment.fromJson);
    story.comments = more
        ? [
            ...story.comments,
            ...page.where((c) => !story.comments.any((v) => v.id == c.id)),
          ]
        : page.toList();
    story.commentsCursor = v.nextCursor;
    story.commentCount = v.data.containsKey('total')
        ? integer(v.data['total'])
        : story.comments.fold<int>(
            0,
            (sum, c) => sum + (c.deleted ? 0 : 1) + c.replyCount,
          );
    for (final entry in stories) {
      if (entry.id == story.id) entry.commentCount = story.commentCount;
    }
    changed();
  }

  Future<ArticleComment?> reactToComment(
    Story story,
    ArticleComment comment, {
    required bool dislike,
  }) => perform("comment-reaction-${story.id}-${comment.id}", () async {
    final remove = dislike ? comment.disliked : comment.liked;
    final result = await request(
      "${remove ? 'Delete' : 'Put'}ArticlesIdCommentsCommentID${dislike ? 'Dislike' : 'Like'}",
      path: {"id": "${story.id}", "commentID": "${comment.id}"},
      body: {},
    );
    final updated = comment.withReaction(result.data);
    story.comments = story.comments
        .map((c) => c.id == updated.id ? updated : c)
        .toList();
    changed();
    return updated;
  });
}
