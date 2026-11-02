import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Disposable, account-scoped template assets. Never stores resume content,
/// user photos, credentials or signed preview URLs.
class TemplateDomStorage {
  TemplateDomStorage(this.userID);
  final int userID;
  static const maxFileBytes = 16 * 1024 * 1024;
  static const maxAccountBytes = 64 * 1024 * 1024;
  static const maxEntries = 24;

  Future<Directory?> _directory() async {
    if (userID <= 0) return null;
    const origin = String.fromEnvironment(
      'BOJIAN_API_BASE_URL',
      defaultValue: 'https://bojian.kelance.cn/api/v1',
    );
    final base = await getApplicationCacheDirectory();
    final scope = base64Url.encode(utf8.encode(origin)).replaceAll('=', '');
    return Directory('${base.path}/bojian-template-dom-v1/$scope/$userID');
  }

  Future<Map<String, dynamic>?> read(int id, int version) async {
    try {
      final directory = await _directory();
      if (directory == null) return null;
      final file = File('${directory.path}/$id-$version.json');
      if (!await file.exists()) return null;
      if (await file.length() > maxFileBytes) {
        await file.delete();
        return null;
      }
      final data = jsonDecode(await file.readAsString());
      if (data is! Map<String, dynamic> ||
          data['template_id'] != id ||
          data['version'] != version ||
          data['html'] is! String ||
          (data['html'] as String).trim().isEmpty ||
          data['css'] is! String) {
        await file.delete();
        return null;
      }
      await file.setLastModified(DateTime.now());
      return data;
    } catch (_) {
      // Missing, evicted or corrupt caches fall back to the live DOM endpoint.
      return null;
    }
  }

  Future<bool> write(int id, int version, Map<String, dynamic> data) async {
    File? pending;
    try {
      final directory = await _directory();
      if (directory == null) return false;
      final bytes = utf8.encode(jsonEncode(data));
      if (bytes.length > maxFileBytes) return false;
      await directory.create(recursive: true);
      pending = File(
        '${directory.path}/$id-$version-$pid-${DateTime.now().microsecondsSinceEpoch}.pending',
      );
      await pending.writeAsBytes(bytes, flush: true);
      await pending.rename('${directory.path}/$id-$version.json');
      pending = null;
      final files = <(File, FileStat)>[];
      await for (final item in directory.list(followLinks: false)) {
        if (item is! File) continue;
        final stat = await item.stat();
        if (item.path.endsWith('.pending')) {
          if (DateTime.now().difference(stat.modified) >
              const Duration(days: 1)) {
            await item.delete();
          }
        } else if (item.path.endsWith('.json')) {
          files.add((item, stat));
        }
      }
      files.sort((a, b) => b.$2.modified.compareTo(a.$2.modified));
      var total = 0;
      for (var index = 0; index < files.length; index++) {
        final (file, stat) = files[index];
        total += stat.size;
        if (index >= maxEntries || total > maxAccountBytes) await file.delete();
      }
      return true;
    } catch (_) {
      // A full disk must not turn a confirmed acquisition into a failure.
      return false;
    } finally {
      if (pending != null) {
        try {
          await pending.delete();
        } catch (_) {}
      }
    }
  }
}
