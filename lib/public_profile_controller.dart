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
  bool loading = true;
  String? profileError, articleError;
  int generation = 0, viewerEpoch;
  bool disposed = false;

  bool current(int request, int epoch) =>
      !disposed && request == generation && epoch == store.epoch;

  void viewerChanged() {
    if (viewerEpoch == store.epoch || disposed) return;
    viewerEpoch = store.epoch;
    generation++;
    profile = null;
    articles = [];
    loading = false;
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
      notifyListeners();
    } catch (error) {
      if (!current(request, epoch)) return;
      if (error is ApiFailure && error.code == 'USER_NOT_FOUND') {
        profile = null;
        articles = [];
        profileError = '该用户主页暂不可见';
      } else {
        profileError = '主页加载失败，请稍后重试';
      }
      loading = false;
      notifyListeners();
      return;
    }
    try {
      final response = await store.request(
        'GetUsersFirstSecond',
        path: {'first': '$userID', 'second': 'articles'},
      );
      if (!current(request, epoch)) return;
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
        if (!current(request, epoch)) return;
        loaded.addAll(batch.whereType<Story>());
      }
      if (!current(request, epoch)) return;
      articles = loaded;
      if (failed) articleError = '部分动态加载失败，请稍后重试';
    } catch (_) {
      if (current(request, epoch)) articleError = '文章加载失败，请稍后重试';
    } finally {
      if (current(request, epoch)) {
        loading = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    disposed = true;
    generation++;
    store.removeListener(viewerChanged);
    super.dispose();
  }
}
