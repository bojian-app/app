import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:path_provider/path_provider.dart';

// Query parameters that only authorise a download. Storage objects never change
// behind one path, so dropping them gives every signature of an image one key.
const _signatureParameters = {
  'expires',
  'signature',
  'ossaccesskeyid',
  'security-token',
  'auth_key',
  'sign',
  'q-sign-algorithm',
  'q-ak',
  'q-sign-time',
  'q-key-time',
  'q-header-list',
  'q-url-param-list',
  'q-signature',
};

/// The identity of a remote image, independent of its download signature.
String stableImageKey(String url) {
  final uri = Uri.tryParse(url.trim());
  if (uri == null || !uri.hasScheme) return url.trim();
  final names = uri.queryParametersAll.keys.toSet();
  // Qiniu private links carry `e` (expiry) together with `token`.
  final qiniu = names.contains('e') && names.contains('token');
  final kept = <String, List<String>>{
    for (final entry in uri.queryParametersAll.entries)
      if (!_signatureParameters.contains(entry.key.toLowerCase()) &&
          !entry.key.toLowerCase().startsWith('x-amz-') &&
          !(qiniu && (entry.key == 'e' || entry.key == 'token')))
        entry.key: entry.value,
  };
  final base = uri.removeFragment();
  return (kept.isEmpty
          ? base.replace(query: '')
          : base.replace(queryParameters: kept))
      .toString()
      .replaceFirst(RegExp(r'[?#]+$'), '');
}

/// Disk-backed bytes for remote images, keyed by [stableImageKey].
class NetworkImageStore {
  NetworkImageStore({
    Future<Directory?> Function()? directory,
    Future<Uint8List> Function(Uri url)? download,
    this.maxBytes = 200 * 1024 * 1024,
  }) : _directory = directory ?? _defaultDirectory,
       _download = download ?? _httpDownload;

  static NetworkImageStore instance = NetworkImageStore();

  final Future<Directory?> Function() _directory;
  final Future<Uint8List> Function(Uri url) _download;
  final int maxBytes;
  final _pending = <String, Future<Uint8List>>{};
  Future<Directory?>? _root;
  var _writesSincePrune = 0;

  static Future<Directory?> _defaultDirectory() async {
    try {
      final base = await getApplicationCacheDirectory();
      return Directory('${base.path}/bojian-images-v1');
    } catch (_) {
      return null;
    }
  }

  static final _client = HttpClient()
    ..autoUncompress = false
    ..connectionTimeout = const Duration(seconds: 15);

  static Future<Uint8List> _httpDownload(Uri url) async {
    final request = await _client.getUrl(url);
    final response = await request.close();
    if (response.statusCode != HttpStatus.ok) {
      await response.drain<void>();
      throw NetworkImageLoadException(
        statusCode: response.statusCode,
        uri: url,
      );
    }
    final bytes = await consolidateHttpClientResponseBytes(response);
    if (bytes.isEmpty) throw Exception('Empty image: $url');
    return bytes;
  }

  Future<Directory?> _cacheRoot() => _root ??= () async {
    final directory = await _directory();
    if (directory == null) return null;
    try {
      await directory.create(recursive: true);
      unawaited(_prune(directory));
      return directory;
    } catch (_) {
      return null;
    }
  }();

  static String _fileName(String key) {
    // FNV-1a over the key; the length suffix makes collisions practically impossible.
    var hash = 0xcbf29ce484222325;
    final bytes = utf8.encode(key);
    for (final byte in bytes) {
      hash = (hash ^ byte) * 0x100000001b3;
    }
    return '${hash.toUnsigned(64).toRadixString(16)}-${bytes.length}';
  }

  /// Returns cached bytes for [key], downloading from [url] only on a miss.
  Future<Uint8List> load(String url, String key) {
    final existing = _pending[key];
    if (existing != null) return existing;
    final future = _load(url, key).whenComplete(() {
      _pending.remove(key);
    });
    _pending[key] = future;
    return future;
  }

  Future<Uint8List> _load(String url, String key) async {
    final cached = await read(key);
    if (cached != null) return cached;
    final bytes = await _download(Uri.parse(url));
    await _write(key, bytes);
    return bytes;
  }

  Future<Uint8List?> read(String key) async {
    final root = await _cacheRoot();
    if (root == null) return null;
    final file = File('${root.path}/${_fileName(key)}');
    try {
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) return null;
      // Track recency so pruning drops images that have not been shown lately.
      unawaited(file.setLastModified(DateTime.now()).catchError((_) {}));
      return bytes;
    } catch (_) {
      return null;
    }
  }

  Future<void> evict(String key) async {
    final root = await _cacheRoot();
    if (root == null) return;
    try {
      await File('${root.path}/${_fileName(key)}').delete();
    } catch (_) {}
  }

  Future<void> _write(String key, Uint8List bytes) async {
    final root = await _cacheRoot();
    if (root == null) return;
    final target = File('${root.path}/${_fileName(key)}');
    final temporary = File(
      '${target.path}.${DateTime.now().microsecondsSinceEpoch}.part',
    );
    try {
      await temporary.writeAsBytes(bytes, flush: true);
      await temporary.rename(target.path);
    } catch (_) {
      try {
        await temporary.delete();
      } catch (_) {}
      return;
    }
    if (++_writesSincePrune >= 20) {
      _writesSincePrune = 0;
      unawaited(_prune(root));
    }
  }

  Future<void> _prune(Directory root) async {
    try {
      final files = <(File, FileStat)>[];
      await for (final entity in root.list()) {
        if (entity is File) files.add((entity, await entity.stat()));
      }
      var total = files.fold<int>(0, (sum, item) => sum + item.$2.size);
      if (total <= maxBytes) return;
      files.sort((a, b) => a.$2.modified.compareTo(b.$2.modified));
      for (final (file, stat) in files) {
        if (total <= maxBytes * 0.8) break;
        try {
          await file.delete();
          total -= stat.size;
        } catch (_) {}
      }
    } catch (_) {}
  }

  Future<int> diskBytes() async {
    final root = await _cacheRoot();
    if (root == null) return 0;
    var total = 0;
    try {
      await for (final entity in root.list()) {
        if (entity is File) total += (await entity.stat()).size;
      }
    } catch (_) {}
    return total;
  }

  Future<void> clear() async {
    final root = await _cacheRoot();
    if (root == null) return;
    try {
      await for (final entity in root.list()) {
        await entity.delete(recursive: true);
      }
    } catch (_) {}
  }
}

/// A network image cached in memory and on disk under a stable key, so a new
/// download signature for the same object neither refetches nor flickers.
class CachedNetworkImage extends ImageProvider<CachedNetworkImage> {
  const CachedNetworkImage(this.url, {this.variant = '', this.fallback = ''});
  final String url;

  /// Tried when [url] cannot be had, as when a smaller rendition of a picture
  /// cannot be made.
  final String fallback;

  /// Distinguishes different images served from one fixed URL.
  final String variant;

  String get cacheKey {
    final key = stableImageKey(url);
    return variant.isEmpty ? key : '$key#$variant';
  }

  @override
  Future<CachedNetworkImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(
    CachedNetworkImage key,
    ImageDecoderCallback decode,
  ) => MultiFrameImageStreamCompleter(
    codec: _codec(key, decode),
    scale: 1,
    debugLabel: key.cacheKey,
    informationCollector: () => [
      DiagnosticsProperty('Image key', key.cacheKey),
    ],
  );

  static Future<ui.Codec> _codec(
    CachedNetworkImage key,
    ImageDecoderCallback decode,
  ) async {
    try {
      return await _stored(key.url, key.cacheKey, decode);
    } catch (_) {
      if (key.fallback.isEmpty) rethrow;
      return _stored(key.fallback, stableImageKey(key.fallback), decode);
    }
  }

  static Future<ui.Codec> _stored(
    String url,
    String cacheKey,
    ImageDecoderCallback decode,
  ) async {
    final store = NetworkImageStore.instance;
    final bytes = await store.load(url, cacheKey);
    try {
      return await decode(await ui.ImmutableBuffer.fromUint8List(bytes));
    } catch (_) {
      // A corrupt or non-image response must not be served from disk again.
      await store.evict(cacheKey);
      rethrow;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is CachedNetworkImage && other.cacheKey == cacheKey;

  @override
  int get hashCode => cacheKey.hashCode;

  @override
  String toString() => 'CachedNetworkImage("$cacheKey")';
}
