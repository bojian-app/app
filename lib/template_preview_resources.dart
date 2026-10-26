import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import 'template_preview_document.dart';

/// Immutable bundled resources shared by previews; individual HTML documents
/// still have separate lifetimes. Keep them beside the fonts so iOS file read
/// access stays inside the document's directory.
class TemplatePreviewResources {
  TemplatePreviewResources._(
    this.directory,
    this.renderer,
    this.preview,
    this.portrait,
  );

  final Directory directory;
  final String renderer, preview, portrait;
  int _nextDocument = 0;
  Future<void>? _preparingFonts;
  static Future<TemplatePreviewResources>? _loading;

  static Future<TemplatePreviewResources> load() async {
    final resources = await (_loading ??= _prepare().catchError((
      Object error,
      StackTrace stack,
    ) {
      _loading = null;
      Error.throwWithStackTrace(error, stack);
    }));
    // The OS may evict temporary files while the app is in the background.
    // Only missing files are restored; concurrent previews share the same work.
    await (resources._preparingFonts ??= resources._prepareFonts().whenComplete(
      () => resources._preparingFonts = null,
    ));
    return resources;
  }

  static Future<void> warm() async {
    try {
      await load();
    } catch (_) {
      // Opening a preview retries preparation and can display the actual error.
    }
  }

  static Future<TemplatePreviewResources> _prepare() async {
    // Fingerprints of the bundled Regular/Medium/Bold fonts. Change the cache
    // key when changing those assets, so app upgrades cannot reuse older faces.
    final directory = Directory(
      '${Directory.systemTemp.path}/bojian-template-resources-be33bc8d-d92b378a-d50f483f',
    );
    await directory.create(recursive: true);
    // Remove abandoned documents after a day. Another engine/process may still
    // be showing a recent document from this shared immutable resource folder.
    final staleBefore = DateTime.now().subtract(const Duration(days: 1));
    await for (final entry in directory.list()) {
      final name = entry.uri.pathSegments.last;
      if (entry is File &&
          name.startsWith('preview-') &&
          name.endsWith('.html') &&
          (await entry.lastModified()).isBefore(staleBefore)) {
        await entry.delete();
      }
    }
    final assets = await Future.wait([
      rootBundle.loadString('assets/templates/market_renderer.js'),
      rootBundle.loadString('assets/templates/market_preview.js'),
    ]);
    final image = await rootBundle.load(
      'assets/templates/preview_portrait.png',
    );
    return TemplatePreviewResources._(
      directory,
      assets[0],
      assets[1],
      'data:image/png;base64,${base64Encode(image.buffer.asUint8List(image.offsetInBytes, image.lengthInBytes))}',
    );
  }

  Future<void> _prepareFonts() async {
    await directory.create(recursive: true);
    await Future.wait(
      templatePreviewFontAssets.entries.map((entry) async {
        final file = File('${directory.path}/${entry.key}');
        if (await file.exists()) return;
        final bytes = await rootBundle.load(entry.value);
        final pending = File(
          '${file.path}.$pid-${DateTime.now().microsecondsSinceEpoch}.pending',
        );
        try {
          await pending.writeAsBytes(
            bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
          );
          await pending.rename(file.path);
        } finally {
          if (await pending.exists()) await pending.delete();
        }
      }),
    );
  }

  Future<File> createDocument(String html) async {
    final file = File(
      '${directory.path}/preview-${DateTime.now().microsecondsSinceEpoch}-${_nextDocument++}.html',
    );
    try {
      await file.writeAsString(html);
      return file;
    } catch (_) {
      if (await file.exists()) await file.delete();
      rethrow;
    }
  }
}
