import 'dart:convert';
import 'dart:ui' as ui;

import 'package:bojian_native_layout/native_layout.dart' as native;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'api/bojian_api.dart';
import 'resume_native_export.dart';

// A cached immutable DOM shares decoded asset bytes across its thumbnail and
// detail. Weak keys release this map when the DOM leaves the bounded cache.
final _nativeAssetBytes = Expando<Map<String, Uint8List>>();

class NativeMarketDocument {
  NativeMarketDocument(this.renderer, this.document);
  final native.NativeLayoutRenderer renderer;
  final native.NativeDocument document;
  bool _disposed = false;

  static Future<NativeMarketDocument> load(
    Map payload,
    Map<String, dynamic> fields,
    Uint8List? photo, {
    bool useSystemFont = true,
  }) async {
    final layout = Map<String, dynamic>.from(payload['layout'] as Map);
    native.validateNativeLayout(layout);
    final bytes = _nativeAssetBytes[payload] ??= <String, Uint8List>{
      for (final e in (payload['assets'] as Map).entries)
        e.key as String: base64Decode(e.value as String),
    };
    final renderer = native.NativeLayoutRenderer(
      layout,
      fields,
      bytes,
      photoBytes: photo,
      useSystemFont: useSystemFont,
    );
    try {
      if (!useSystemFont) {
        await native.NativeLayoutRenderer.loadFonts(rootBundle);
      }
      await renderer.prepare();
      return NativeMarketDocument(renderer, renderer.buildDocument());
    } catch (_) {
      renderer.dispose();
      rethrow;
    }
  }

  Future<ResumeExportLayout> export({
    required bool Function() isCancelled,
    required ValueChanged<String> onProgress,
  }) async {
    if (renderer.useSystemFont) {
      if (_disposed || isCancelled()) throw const ApiFailure('导出已取消');
      await native.NativeLayoutRenderer.loadFonts(rootBundle);
      final exportRenderer = native.NativeLayoutRenderer(
        renderer.layout,
        renderer.fields,
        renderer.assetBytes,
        photoBytes: renderer.photoBytes,
      );
      NativeMarketDocument? value;
      try {
        await exportRenderer.prepare();
        value = NativeMarketDocument(
          exportRenderer,
          exportRenderer.buildDocument(),
        );
        return await value.export(
          isCancelled: isCancelled,
          onProgress: onProgress,
        );
      } finally {
        if (value != null) {
          value.dispose();
        } else {
          exportRenderer.dispose();
        }
      }
    }
    final size = document.size;
    const pw = 595.28, ph = 841.89;
    final sx = pw / size.width, sy = ph / size.height;
    final padding = renderer.pagePadding;
    final left = native.number(padding['left']),
        top = native.number(padding['top']);
    final pages = <ResumeExportPage>[];
    final runs = (document.report['textRuns'] as List).cast<Map>();
    final stats = (document.report['pages'] as List).cast<Map>();
    void check() {
      if (_disposed || isCancelled()) throw const ApiFailure('导出已取消');
    }

    for (var i = 0; i < stats.length; i++) {
      check();
      onProgress('正在生成第 ${i + 1}/${stats.length} 页…');
      final from = native.number(stats[i]['fromY']),
          to = native.number(stats[i]['toY']);
      final lines = <ResumeExportLine>[];
      for (var r = 0; r < runs.length; r++) {
        final run = runs[r];
        final x = native.number(run['x']) + left, y = native.number(run['y']);
        for (final line in (run['exportLines'] as List).cast<Map>()) {
          final ly = y + native.number(line['top']);
          if (ly < from - .05 || ly >= to - .05) continue;
          lines.add(
            ResumeExportLine(
              top: (top + ly - from) * sy,
              height: native.number(line['height']) * sy,
              baseline: (top + y + native.number(line['baseline']) - from) * sy,
              paragraphId: 'native-$r',
              paragraphLeft: x * sx,
              paragraphWidth: native.number(line['width']) * sx,
              spans: [
                for (final span in (line['spans'] as List).cast<Map>())
                  ResumeExportSpan(
                    text: span['text'] as String,
                    x: (x + native.number(span['x'])) * sx,
                    width: native.number(span['width']) * sx,
                    size: native.number(span['size']) * sx,
                    color: span['color'] as int,
                    weight: span['weight'] as int,
                    italic: span['italic'] == true,
                    underline: span['underline'] == true,
                    strike: span['strike'] == true,
                  ),
              ],
            ),
          );
        }
      }
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder)..scale(2);
      canvas.drawPicture(document.backgrounds[i]);
      final picture = recorder.endRecording();
      final image = await picture.toImage(
        (size.width * 2).round(),
        (size.height * 2).round(),
      );
      picture.dispose();
      Uint8List png;
      try {
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        if (data == null) throw const ApiFailure('模板装饰层导出失败');
        png = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      } finally {
        image.dispose();
      }
      check();
      pages.add(
        ResumeExportPage(
          lines: lines,
          background: ResumeExportPicture(png, 0, 0, pw, ph),
        ),
      );
    }
    final images = <String, Uint8List>{};
    for (final entry in renderer.images.entries) {
      check();
      final data = await entry.value.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw const ApiFailure('模板素材导出失败');
      images[entry.key] = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
    }
    for (final entry in renderer.pictures.entries) {
      check();
      final info = entry.value;
      final rec = ui.PictureRecorder();
      Canvas(rec)
        ..scale(2)
        ..drawPicture(info.picture);
      final pic = rec.endRecording();
      final image = await pic.toImage(
        (info.size.width * 2).ceil(),
        (info.size.height * 2).ceil(),
      );
      pic.dispose();
      try {
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        if (data == null) throw const ApiFailure('模板图标导出失败');
        images[entry.key] = data.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        );
      } finally {
        image.dispose();
      }
    }
    final headingArt = <String, dynamic>{};
    Future<void> collectHeading(dynamic value) async {
      if (value is List) {
        for (final child in value) {
          await collectHeading(child);
        }
        return;
      }
      if (value is! Map) return;
      if (value['type'] == 'sectionHeading') {
        final node = native.map(value);
        final key =
            '${node['iconAsset']}|${node['decoration']}|${node['text']}';
        if (headingArt.containsKey(key)) return;
        final width =
            renderer.pageW -
            native.number(padding['left']) -
            native.number(padding['right']);
        final box = renderer.heading(node, width);
        final rec = ui.PictureRecorder();
        final canvas = Canvas(rec)..scale(2);
        renderer.paintText = false;
        try {
          for (final draw in box.draws) {
            draw(canvas);
          }
        } finally {
          renderer.paintText = true;
        }
        final pic = rec.endRecording();
        final image = await pic.toImage(
          (width * 2).ceil(),
          (box.height * 2).ceil(),
        );
        pic.dispose();
        final id = 'heading-art-${headingArt.length}';
        try {
          final data = (await image.toByteData(
            format: ui.ImageByteFormat.png,
          ))!;
          images[id] = data.buffer.asUint8List(
            data.offsetInBytes,
            data.lengthInBytes,
          );
        } finally {
          image.dispose();
        }
        final decoration = native.map(
          native.map(renderer.layout['decorations'])[node['decoration']],
        );
        headingArt[key] = {
          'asset': id,
          'width': width,
          'height': box.height,
          'indent':
              native.number(native.map(decoration['iconSize'])['width']) +
              native.number(decoration['gap']),
        };
      }
      for (final child in value.values) {
        await collectHeading(child);
      }
    }

    await collectHeading(renderer.layout['sections']);
    final sections = (renderer.layout['sections'] as List)
        .map(native.map)
        .toList();
    final order = <String>{
      'personal_info',
      ...(renderer.fields['section_order'] as List? ?? []).whereType<String>(),
      ...sections.map((s) => s['id'] as String),
    };
    final ordered = order
        .map((id) => sections.where((s) => s['id'] == id).firstOrNull)
        .whereType<Map<String, dynamic>>()
        .where(
          (node) => native.nativeSectionHasContent(
            node['id'] as String,
            renderer.fields,
            hasPhoto: renderer.images.containsKey('photo'),
          ),
        )
        .toList();
    final margins = {
      for (final key in ['top', 'right', 'bottom', 'left'])
        key: native.number(padding[key]) * sx,
    };
    return ResumeExportLayout(
      pages,
      wordLayout: ResumeExportLayout(
        pages,
        requiresWordFlow: true,
        wordMargins: margins,
        wordStructure: {
          'layout': renderer.layout,
          'fields': renderer.fields,
          'sections': ordered,
          'images': images,
          'headingArt': headingArt,
        },
      ),
      requiresWordFlow: true,
    );
  }

  Future<List<Uint8List>> capture({
    required bool Function() isCancelled,
    required ValueChanged<String> onProgress,
  }) async {
    final output = <Uint8List>[];
    for (var i = 0; i < document.pages.length; i++) {
      if (_disposed || isCancelled()) throw const ApiFailure('导出已取消');
      onProgress('正在生成第 ${i + 1}/${document.pages.length} 页…');
      final image = await document.pages[i].toImage(
        document.size.width.round(),
        document.size.height.round(),
      );
      try {
        final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
        output.add(bytes.buffer.asUint8List());
      } finally {
        image.dispose();
      }
    }
    return output;
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    document.dispose();
    renderer.dispose();
  }
}

class NativeMarketPages extends StatelessWidget {
  const NativeMarketPages({
    super.key,
    required this.value,
    this.thumbnail = false,
    this.watermark,
  });
  final NativeMarketDocument value;
  final bool thumbnail;
  final String? watermark;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final doc = value.document;
      final width = constraints.maxWidth - (thumbnail ? 0 : 24);
      Widget page(int index) => SizedBox(
        width: width,
        height: width * doc.size.height / doc.size.width,
        child: RepaintBoundary(
          child: CustomPaint(
            isComplex: true,
            painter: _NativePagePainter(
              doc.pages[index],
              doc.size,
              watermark: watermark,
            ),
          ),
        ),
      );
      if (thumbnail) {
        return ClipRect(
          child: Align(alignment: Alignment.topCenter, child: page(0)),
        );
      }
      // One gesture owner for the entire document. A scrollable nested inside
      // InteractiveViewer competes with its pan/scale recognizer and transforms
      // only the viewport instead of the full document bounds.
      final documentHeight =
          doc.pages.length * width * doc.size.height / doc.size.width +
          (doc.pages.length - 1) * 12 +
          24;
      return InteractiveViewer(
        key: ObjectKey(doc),
        alignment: Alignment.topLeft,
        constrained: false,
        minScale: 1,
        maxScale: 4,
        child: SizedBox(
          width: constraints.maxWidth,
          height: documentHeight < constraints.maxHeight
              ? constraints.maxHeight
              : documentHeight,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < doc.pages.length; i++) ...[
                  if (i > 0) const SizedBox(height: 12),
                  page(i),
                ],
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _NativePagePainter extends CustomPainter {
  _NativePagePainter(this.picture, this.source, {this.watermark});
  final String? watermark;
  final ui.Picture picture;
  final Size source;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    // Picture drawColor fills the current clip, not its nominal page bounds.
    // Keep later pages from painting over earlier ListView children.
    canvas.clipRect(Offset.zero & size);
    canvas.scale(size.width / source.width);
    canvas.drawPicture(picture);
    if (watermark != null) {
      final text = TextPainter(
        text: TextSpan(
          text: '© $watermark',
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w500,
            color: Color(0x24334155),
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: 230);
      for (double y = 90; y < source.height + 180; y += 180) {
        for (double x = 130; x < source.width + 260; x += 260) {
          canvas.save();
          canvas.translate(x, y);
          canvas.rotate(-0.4487989505);
          text.paint(canvas, Offset(-text.width / 2, -text.height / 2));
          canvas.restore();
        }
      }
      text.dispose();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_NativePagePainter old) =>
      old.picture != picture || old.watermark != watermark;
}
