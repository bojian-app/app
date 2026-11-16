import 'dart:async';

import 'package:flutter/foundation.dart';

import 'api/bojian_api.dart';
import 'app_store.dart';
import 'template_preview_cache.dart';

enum TemplateMarketFilter {
  all('全部', ''),
  free('免费', 'FREE'),
  paid('会员', 'PAID'),
  owned('我的', '');

  const TemplateMarketFilter(this.label, this.pricing);
  final String label, pricing;
}

class TemplateMarketStore extends ChangeNotifier {
  TemplateMarketStore(this.store) : epoch = store.epoch {
    store.addListener(accountChanged);
  }
  final AppStore store;
  final int epoch;
  bool alive = true, loading = false, loadingMore = false, loadingOwned = false;
  String query = '', cursor = '';
  String? error, ownedError;
  TemplateMarketFilter filter = TemplateMarketFilter.all;
  List<Map<String, dynamic>> templates = [], owned = [];
  int generation = 0;
  Timer? debounce;
  bool get valid => alive && store.alive && store.epoch == epoch;
  Set<int> get ownedIDs => owned.map((row) => integer(row['id'])).toSet();
  List<Map<String, dynamic>> get visible => filter == TemplateMarketFilter.owned
      ? owned
            .where(
              (row) => '${row['name'] ?? ''}'.toLowerCase().contains(
                query.toLowerCase(),
              ),
            )
            .toList()
      : templates;

  void accountChanged() {
    if (alive && store.epoch != epoch) {
      generation++;
      debounce?.cancel();
      templates = [];
      owned = [];
      cursor = '';
      loading = false;
      loadingOwned = false;
      loadingMore = false;
      error = '登录状态已变化，请返回后重试';
      ownedError = error;
      notifyListeners();
    }
  }

  void search(String value, {bool immediately = false}) {
    query = value.trim();
    debounce?.cancel();
    generation++;
    cursor = '';
    templates = [];
    error = null;
    notifyListeners();
    if (filter == TemplateMarketFilter.owned) return;
    if (immediately) {
      unawaited(load());
    } else {
      debounce = Timer(const Duration(milliseconds: 300), load);
    }
  }

  void select(TemplateMarketFilter value) {
    if (value == filter) return;
    filter = value;
    debounce?.cancel();
    generation++;
    cursor = '';
    templates = [];
    error = null;
    loading = false;
    loadingMore = false;
    notifyListeners();
    if (value == TemplateMarketFilter.owned) {
      unawaited(loadOwned());
    } else {
      unawaited(load());
    }
  }

  Future<void> refresh() async {
    debounce?.cancel();
    await Future.wait([
      if (filter != TemplateMarketFilter.owned) load(),
      loadOwned(),
    ]);
  }

  Future<void> load({bool more = false}) async {
    if (!valid ||
        filter == TemplateMarketFilter.owned ||
        (more && (loading || loadingMore || cursor.isEmpty))) {
      return;
    }
    final version = more ? generation : ++generation;
    final querySnapshot = query, pricing = filter.pricing;
    if (more) {
      loadingMore = true;
    } else {
      loading = true;
      loadingMore = false;
      templates = [];
      cursor = '';
    }
    error = null;
    notifyListeners();
    try {
      final result = await store.request(
        'GetTemplates',
        query: {
          'limit': '24',
          if (querySnapshot.isNotEmpty) 'query': querySnapshot,
          if (pricing.isNotEmpty) 'pricing': pricing,
          if (more) 'cursor': cursor,
        },
      );
      if (!valid || version != generation) return;
      final seen = <int>{};
      templates = [if (more) ...templates, ...items(result.data)]
          .where(
            (row) => integer(row['id']) > 0 && seen.add(integer(row['id'])),
          )
          .toList();
      cursor = result.nextCursor;
    } catch (e) {
      if (valid && version == generation) {
        error = e is ApiFailure ? e.message : '模板加载失败，请重试';
      }
    } finally {
      if (valid && version == generation) {
        loading = false;
        loadingMore = false;
        notifyListeners();
      }
    }
  }

  int ownershipGeneration = 0;
  Future<void> loadOwned() async {
    if (!valid) return;
    final version = ++ownershipGeneration;
    loadingOwned = true;
    ownedError = null;
    notifyListeners();
    try {
      final result = await store.request('GetMeTemplates');
      if (!valid || version != ownershipGeneration) return;
      final seen = <int>{};
      owned = items(result.data)
          .where(
            (row) =>
                row['source'] == 'ACQUIRED' &&
                integer(row['id']) > 0 &&
                seen.add(integer(row['id'])),
          )
          .toList();
    } catch (e) {
      if (valid && version == ownershipGeneration) {
        ownedError = e is ApiFailure ? e.message : '购买记录加载失败';
      }
    } finally {
      if (valid && version == ownershipGeneration) {
        loadingOwned = false;
        notifyListeners();
      }
    }
  }

  Future<void> acquire({required int id, required int quotedRevision}) async {
    if (!valid) throw const ApiFailure('登录状态已变化，请重试');
    await loadOwned();
    if (!valid) throw const ApiFailure('登录状态已变化，请重试');
    if (ownedError != null) throw ApiFailure(ownedError!);
    if (ownedIDs.contains(id)) {
      final template = owned.firstWhere((row) => integer(row['id']) == id);
      unawaited(
        predownloadAcquiredTemplate(store, id, integer(template['version'])),
      );
      return;
    }
    final detail = await store.request('GetTemplatesId', path: {'id': '$id'});
    if (!valid) throw const ApiFailure('登录状态已变化，请重试');
    if (integer(detail.data['revision']) != quotedRevision) {
      throw const ApiFailure('模板信息已更新，请刷新详情后重试');
    }
    if (detail.data['compatible'] != true ||
        detail.data['status'] != 'PUBLISHED') {
      throw const ApiFailure('模板暂不可用');
    }
    await store.request(
      'PostTemplatesIdAcquisitions',
      path: {'id': '$id'},
      body: {},
    );
    if (!valid) return;
    unawaited(
      predownloadAcquiredTemplate(store, id, integer(detail.data['version'])),
    );
    await loadOwned();
  }

  @override
  void dispose() {
    alive = false;
    generation++;
    debounce?.cancel();
    store.removeListener(accountChanged);
    super.dispose();
  }
}
