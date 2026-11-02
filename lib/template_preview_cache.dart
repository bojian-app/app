import 'dart:convert';

import 'api/bojian_api.dart';
import 'app_store.dart';
import 'template_dom_storage.dart';

final _caches = Expando<_TemplateDomCache>();

class _TemplateDomCache {
  _TemplateDomCache(this.store)
    : epoch = store.epoch,
      userID = store.userID,
      disk = TemplateDomStorage(store.userID);
  final AppStore store;
  final int epoch;
  final int userID;
  final TemplateDomStorage disk;
  final entries = <(int, int), ApiDocument>{};
  final pending = <(int, int), Future<ApiDocument>>{};
  final persisted = <(int, int)>{};
  final writes = <(int, int), Future<void>>{};
  int bytes = 0;
  void checkSession() {
    if (!store.alive ||
        !store.isAuthenticated ||
        store.epoch != epoch ||
        store.userID != userID) {
      throw const ApiFailure('登录状态已变化，请重试');
    }
  }

  int cost(ApiDocument document) => 2 * jsonEncode(document.data).length;

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
      final oldest = entries.keys.first;
      bytes -= cost(entries.remove(oldest)!);
      persisted.remove(oldest);
    }
  }

  Future<void> persist((int, int) key, ApiDocument document) async {
    if (key.$2 <= 0 || userID <= 0 || persisted.contains(key)) return;
    final existing = writes[key];
    if (existing != null) return existing;
    final write = () async {
      checkSession();
      if (await disk.write(key.$1, key.$2, document.data)) persisted.add(key);
    }();
    writes[key] = write;
    try {
      await write;
    } finally {
      if (identical(writes[key], write)) writes.remove(key);
    }
  }
}

/// Details/ownership stay live. Only immutable template assets are cached.
Future<ApiDocument> loadTemplatePreviewDOM(
  AppStore store,
  int id,
  int version, {
  bool refresh = false,
  bool persist = false,
  Future<ApiDocument> Function()? fetch,
}) async {
  if (!store.alive || !store.isAuthenticated) {
    throw const ApiFailure('请先登录');
  }
  var cache = _caches[store];
  if (cache == null ||
      cache.epoch != store.epoch ||
      cache.userID != store.userID) {
    _caches[store] = cache = _TemplateDomCache(store);
  }
  final current = cache;
  final key = (id, version);
  ApiDocument? result;
  if (!refresh && version > 0) {
    final cached = current.entries.remove(key);
    if (cached != null) {
      current.entries[key] = cached;
      result = cached;
    }
    final pending = result == null ? current.pending[key] : null;
    if (pending != null) result = await pending;
  }
  if (result != null) {
    current.checkSession();
    if (persist) await current.persist(key, result);
    current.checkSession();
    return result;
  }
  if (refresh) current.persisted.remove(key);
  late final Future<ApiDocument> request;
  request =
      Future<ApiDocument>(() async {
        if (!refresh && version > 0) {
          final stored = await current.disk.read(id, version);
          current.checkSession();
          if (stored != null) {
            final value = ApiDocument(stored);
            if (identical(current.pending[key], request)) {
              current.save(key, value);
              current.persisted.add(key);
            }
            return value;
          }
        }
        current.checkSession();
        final value =
            await (fetch?.call() ??
                store.request('GetTemplatesIdDom', path: {'id': '$id'}));
        current.checkSession();
        final actualVersion = integer(
          value.data['version'] ?? value.data['template_version'],
        );
        if (integer(value.data['template_id']) != id ||
            (version > 0 && actualVersion != version)) {
          throw const ApiFailure('模板已更新，请刷新详情');
        }
        if ((value.data['html'] as String? ?? '').trim().isEmpty) {
          throw const ApiFailure('模板预览正在准备，请稍后重试');
        }
        // Both DOM endpoints feed this cache; discard resume_data and URLs.
        final normalized = ApiDocument({
          'template_id': id,
          'version': actualVersion,
          'html': value.data['html'],
          'css': value.data['css'] ?? '',
          'schema': value.data['schema'] ?? value.data['manifest'],
        });
        if (version > 0 && identical(current.pending[key], request)) {
          current.save(key, normalized);
          current.persisted.remove(key);
        }
        return normalized;
      }).whenComplete(() {
        if (identical(current.pending[key], request)) {
          current.pending.remove(key);
        }
      });
  current.pending[key] = request;
  result = await request;
  current.checkSession();
  if (persist) await current.persist(key, result);
  current.checkSession();
  return result;
}

/// Acquisition is already confirmed. A failed predownload is retried on use.
Future<void> predownloadAcquiredTemplate(
  AppStore store,
  int id,
  int version,
) async {
  if (version <= 0) return;
  try {
    await loadTemplatePreviewDOM(store, id, version, persist: true);
  } catch (_) {
    /* Keep acquisition successful even if asset download fails. */
  }
}

/// Verify the current owned/authored version using metadata, then reuse the
/// same assets as acquisition and template switching. Existing bound resumes
/// retain the original endpoint as a fallback (including delisted templates).
Future<ApiDocument> loadResumeTemplateDOM(
  AppStore store,
  int resumeID,
  int templateID,
) async {
  final epoch = store.epoch;
  final userID = store.userID;
  ApiDocument? owned;
  try {
    owned = await store.request('GetMeTemplates');
  } on ApiFailure catch (error) {
    if (error.unauthenticated) rethrow;
  }
  if (!store.alive ||
      !store.isAuthenticated ||
      store.epoch != epoch ||
      store.userID != userID) {
    throw const ApiFailure('登录状态已变化，请重试');
  }
  final matching = items(owned?.data ?? {})
      .where((row) => integer(row['id']) == templateID);
  final version = matching.isEmpty ? 0 : integer(matching.first['version']);
  return loadTemplatePreviewDOM(
    store,
    templateID,
    version,
    persist: true,
    fetch: () =>
        store.request('GetResumesIdDomPreview', path: {'id': '$resumeID'}),
  );
}
