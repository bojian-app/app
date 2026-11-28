import 'package:flutter/foundation.dart';

import 'api/bojian_api.dart';
import 'app_store.dart';
import 'profile_identity_data.dart';

/// Page-scoped public data, isolated from the signed-in user's own profile.
class PublicProfileController extends ChangeNotifier {
  PublicProfileController({required this.store, required this.userID})
    : viewerEpoch = store.epoch {
    store.addListener(viewerChanged);
  }

  final AppStore store;
  final int userID;
  ProfileIdentityData? profile;
  List<Story> articles = [];

  /// Where the next page of article summaries starts; empty at the end.
  String cursor = '';
  bool loading = true, loadingMore = false;
  String? profileError, articleError;

  /// The server withholds this profile; it does not say whether the owner made
  /// it private, blocked the viewer or left.
  bool unavailable = false;
  int generation = 0, viewerEpoch;
  bool disposed = false;
  bool? following;
  bool changingFollow = false;

  bool current(int request, int epoch) =>
      !disposed && request == generation && epoch == store.epoch;

  void viewerChanged() {
    if (viewerEpoch == store.epoch || disposed) return;
    viewerEpoch = store.epoch;
    generation++;
    profile = null;
    articles = [];
    loading = false;
    unavailable = false;
    profileError = '账号已变化，请重新打开该用户主页';
    notifyListeners();
  }

  Future<void> load() async {
    if (disposed) return;
    final request = ++generation;
    final epoch = store.epoch;
    loading = true;
    profileError = null;
    articleError = null;
    unavailable = false;
    notifyListeners();
    try {
      final result = await store.request(
        'GetUsersFirstSecond',
        path: {'first': '$userID', 'second': 'profile'},
      );
      if (!current(request, epoch)) return;
      if (integer(result.data['id']) != userID) {
        throw const ApiFailure('该用户主页暂不可见', code: 'USER_NOT_FOUND');
      }
      profile = ProfileIdentityData.fromJson(result.data);
      following = result.data['is_following'] as bool?;
      notifyListeners();
    } catch (error) {
      if (!current(request, epoch)) return;
      if (error is ApiFailure && error.code == 'USER_NOT_FOUND') {
        profile = null;
        articles = [];
        cursor = '';
        unavailable = true;
        profileError = '该用户主页暂不可见';
      } else {
        profileError = '主页加载失败，请稍后重试';
      }
      loading = false;
      notifyListeners();
      return;
    }
    try {
      articles = await _page(request, epoch) ?? articles;
    } catch (_) {
      if (current(request, epoch)) articleError = '文章加载失败，请稍后重试';
    } finally {
      if (current(request, epoch)) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> toggleFollow() async {
    if (disposed || changingFollow || following == null) return;
    final account = store.epoch;
    changingFollow = true;
    notifyListeners();
    try {
      final result = await store.request(
        following! ? 'DeleteUsersIdFollow' : 'PutUsersIdFollow',
        path: {'id': '$userID'},
        expectedEpoch: account,
      );
      if (!disposed && account == store.epoch) {
        following = result.data['following'] as bool;
      }
    } finally {
      if (!disposed) {
        changingFollow = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadMore() async {
    if (disposed || loading || loadingMore || cursor.isEmpty) return;
    final request = generation, epoch = store.epoch;
    loadingMore = true;
    articleError = null;
    notifyListeners();
    try {
      final page = await _page(request, epoch, after: cursor);
      if (page != null) {
        articles = [
          ...articles,
          ...page.where((s) => !articles.any((a) => a.id == s.id)),
        ];
      }
    } catch (_) {
      if (current(request, epoch)) articleError = '文章加载失败，请稍后重试';
    } finally {
      if (current(request, epoch)) {
        loadingMore = false;
        notifyListeners();
      }
    }
  }

  /// One page of the user's public articles with their full details, or
  /// null once the request is stale.
  Future<List<Story>?> _page(
    int request,
    int epoch, {
    String after = '',
  }) async {
    final response = await store.request(
      'GetUsersFirstSecond',
      path: {'first': '$userID', 'second': 'articles'},
      query: {'limit': '20', if (after.isNotEmpty) 'cursor': after},
    );
    if (!current(request, epoch)) return null;
    final rows = items(response.data);
    final loaded = <Story>[];
    var failed = false;
    final identity = profile!;
    // Summaries lack their body/type. Bounded batches preserve public order.
    for (var start = 0; start < rows.length; start += 4) {
      final batch = await Future.wait(
        rows.skip(start).take(4).map((row) async {
          final id = integer(row['id']);
          if (id <= 0) return null;
          try {
            final detail = await store.request(
              'GetArticlesId',
              path: {'id': '$id'},
            );
            if (!current(request, epoch)) return null;
            final data = detail.data;
            final author = data['author'] as Map? ?? {};
            if (integer(data['id']) != id ||
                integer(author['id'] ?? data['author_id']) != userID ||
                data['status'] != 'PUBLISHED' ||
                data['visibility'] != 'PUBLIC') {
              failed = true;
              return null;
            }
            return decodeStory({
              ...row,
              ...data,
              'author': {
                ...author,
                'display_name': identity.name,
                'avatar_url': identity.avatarURL,
                'city': identity.ipLocation,
              },
            });
          } catch (_) {
            failed = true;
            return null;
          }
        }),
      );
      if (!current(request, epoch)) return null;
      loaded.addAll(batch.whereType<Story>());
    }
    if (!current(request, epoch)) return null;
    cursor = response.nextCursor;
    if (failed) articleError = '部分动态加载失败，请稍后重试';
    return loaded;
  }

  @override
  void dispose() {
    disposed = true;
    generation++;
    store.removeListener(viewerChanged);
    super.dispose();
  }
}
