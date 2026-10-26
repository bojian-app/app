import 'api/bojian_api.dart';
import 'app_store.dart';

final _caches = Expando<_TemplateDomCache>();

class _TemplateDomCache {
  _TemplateDomCache(this.epoch);
  final int epoch;
  final entries = <(int, int), ApiDocument>{};
  final pending = <(int, int), Future<ApiDocument>>{};
  int bytes = 0;
  int cost(ApiDocument document) =>
      2 *
      ('${document.data['html']}'.length + '${document.data['css']}'.length);

  void save((int, int) key, ApiDocument document) {
    final old = entries.remove(key);
    if (old != null) bytes -= cost(old);
    final size = cost(document);
    if (size > 16 * 1024 * 1024) return;
    entries[key] = ApiDocument(
      Map<String, dynamic>.unmodifiable(document.data),
      nextCursor: document.nextCursor,
    );
    bytes += size;
    while (entries.length > 4 || bytes > 16 * 1024 * 1024) {
      bytes -= cost(entries.remove(entries.keys.first)!);
    }
  }
}

/// Versioned, bounded memory cache scoped to this account session. Details and
/// purchase checks stay live; only the immutable preview DOM is reused.
Future<ApiDocument> loadTemplatePreviewDOM(
  AppStore store,
  int id,
  int version, {
  bool refresh = false,
}) {
  if (!store.alive || !store.isAuthenticated) {
    return Future.error(const ApiFailure('请先登录'));
  }
  var cache = _caches[store];
  if (cache == null || cache.epoch != store.epoch) {
    _caches[store] = cache = _TemplateDomCache(store.epoch);
  }
  final current = cache;
  final key = (id, version);
  if (!refresh && version > 0) {
    final cached = current.entries.remove(key);
    if (cached != null) {
      current.entries[key] = cached;
      return Future.value(cached);
    }
    final pending = current.pending[key];
    if (pending != null) return pending;
  }
  late final Future<ApiDocument> request;
  request = store
      .request('GetTemplatesIdDom', path: {'id': '$id'})
      .then((value) {
        if (integer(value.data['template_id']) != id ||
            (version > 0 && integer(value.data['version']) != version)) {
          throw const ApiFailure('模板已更新，请刷新详情');
        }
        if ((value.data['html'] as String? ?? '').trim().isEmpty) {
          throw const ApiFailure('模板预览正在准备，请稍后重试');
        }
        if (version > 0 &&
            store.epoch == current.epoch &&
            identical(current.pending[key], request)) {
          current.save(key, value);
        }
        return value;
      })
      .whenComplete(() {
        if (identical(current.pending[key], request)) {
          current.pending.remove(key);
        }
      });
  current.pending[key] = request;
  return request;
}
