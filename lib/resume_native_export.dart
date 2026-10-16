import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:vector_math/vector_math_64.dart' as vm;
import 'package:share_plus/share_plus.dart';

import 'api/bojian_api.dart';

const resumeDocumentFontFamily = 'ResumeDocument';
const resumeDocumentTypeface = '寒蝉全圆体';
const resumeFontRegularAsset = 'assets/fonts/chill-round-f.ttf';
// Upstream supplies a regular face; renderers synthesize emphasized text.
const resumeFontBoldAsset = resumeFontRegularAsset;

class ResumeExportSpan {
  const ResumeExportSpan({
    required this.text,
    required this.x,
    required this.width,
    required this.size,
    this.color = 0xFF26292E,
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.strike = false,
  });
  final String text;
  final double x, width, size;
  final int color;
  final bool bold, italic, underline, strike;
}

class ResumeExportLine {
  const ResumeExportLine({
    required this.top,
    required this.height,
    required this.baseline,
    required this.spans,
  });
  final double top, height, baseline;
  final List<ResumeExportSpan> spans;
}

class ResumeExportRule {
  const ResumeExportRule(
    this.x,
    this.y,
    this.width,
    this.thickness,
    this.color, {
    this.height = 0,
  });
  final double x, y, width, thickness, height;
  final int color;
}

class ResumeExportPicture {
  const ResumeExportPicture(
    this.bytes,
    this.x,
    this.y,
    this.width,
    this.height,
  );
  final Uint8List bytes;
  final double x, y, width, height;
}

class ResumeExportPage {
  const ResumeExportPage({
    this.lines = const [],
    this.rules = const [],
    this.pictures = const [],
  });
  final List<ResumeExportLine> lines;
  final List<ResumeExportRule> rules;
  final List<ResumeExportPicture> pictures;
}

class ResumeExportLayout {
  const ResumeExportLayout(
    this.pages, {
    this.width = 595.28,
    this.height = 841.89,
  });
  final List<ResumeExportPage> pages;
  final double width, height;
}

typedef CaptureResumeLayout = Future<ResumeExportLayout> Function({
  required bool Function() isCancelled,
  required void Function(String) onProgress,
});

Future<XFile> exportNativeResume({
  required CaptureResumeLayout capture,
  required String title,
  required String format,
  required bool Function() isCancelled,
  required void Function(String) onProgress,
}) async {
  if (format != 'PDF' && format != 'DOCX') {
    throw const ApiFailure('请选择 Word 或 PDF');
  }
  final layout = await capture(
    isCancelled: isCancelled,
    onProgress: onProgress,
  );
  if (isCancelled()) throw const ApiFailure('导出已取消');
  if (layout.pages.isEmpty) throw const ApiFailure('简历预览暂不可用');
  onProgress('正在生成可${format == 'PDF' ? '复制的 PDF' : '编辑的 Word'}…');
  final regular = (await rootBundle.load(resumeFontRegularAsset)).buffer
      .asUint8List();
  final bold = (await rootBundle.load(resumeFontBoldAsset)).buffer
      .asUint8List();
  final bytes = await Isolate.run(
    () => encodeNativeResume(layout, format, regular, bold),
  );
  if (isCancelled()) throw const ApiFailure('导出已取消');
  if (bytes.length > 30 * 1024 * 1024) {
    throw const ApiFailure('导出文件过大，请减少简历页数后重试');
  }
  var name = title.replaceAll(RegExp(r'[\x00-\x1f/\\:*?"<>|]'), '_').trim();
  name = String.fromCharCodes(name.runes.take(80));
  if (name.isEmpty || name == '.' || name == '..') name = '我的简历';
  final directory = await Directory.systemTemp.createTemp(
    'bojian-resume-export-',
  );
  try {
    final file = File('${directory.path}/$name.${format.toLowerCase()}');
    await file.writeAsBytes(bytes, flush: true);
    if (isCancelled()) throw const ApiFailure('导出已取消');
    return XFile(
      file.path,
      mimeType: format == 'PDF' ? 'application/pdf' : 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    );
  } catch (_) {
    await directory.delete(recursive: true);
    rethrow;
  }
}

Future<Uint8List> encodeNativeResume(
  ResumeExportLayout layout,
  String format,
  Uint8List regular,
  Uint8List bold,
) async {
  if (format == 'PDF') return _pdf(layout, regular, bold);
  if (format == 'DOCX') return _word(layout, regular, bold);
  throw const ApiFailure('请选择 Word 或 PDF');
}

PdfColor _color(int argb) => PdfColor.fromInt(argb & 0xFFFFFF);

// Some CJK cmap entries alias one glyph (for example · and •). The PDF
// subset writer must not assign two Unicode CIDs to the same glyph in a font.
// Keep aliases in separate subsets, preserving both appearance and ToUnicode.
class _PdfTypeface {
  _PdfTypeface(this.document, this.bytes) {
    final base = PdfTtfFont(document, ByteData.sublistView(bytes));
    fonts[0] = base;
    final counts = <int, int>{};
    final entries = base.font.charToGlyphIndexMap.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    for (final entry in entries) {
      if (entry.value == 0) continue;
      final rank = counts[entry.value] ?? 0;
      ranks[entry.key] = rank;
      counts[entry.value] = rank + 1;
    }
  }
  final PdfDocument document;
  final Uint8List bytes;
  final fonts = <int, PdfTtfFont>{};
  final ranks = <int, int>{};
  PdfTtfFont font(int rank) => fonts.putIfAbsent(
    rank,
    () => PdfTtfFont(document, ByteData.sublistView(bytes)),
  );
  Iterable<({int rank, String text})> pieces(String text) sync* {
    var current = -1;
    var buffer = StringBuffer();
    for (final rune in text.runes) {
      final rank = ranks[rune] ?? 0;
      if (rank != current && buffer.isNotEmpty) {
        yield (rank: current, text: buffer.toString());
        buffer = StringBuffer();
      }
      current = rank;
      buffer.writeCharCode(rune);
    }
    if (buffer.isNotEmpty) yield (rank: current, text: buffer.toString());
  }
}

Future<Uint8List> _pdf(
  ResumeExportLayout layout,
  Uint8List regular,
  Uint8List bold,
) async {
  final document = PdfDocument();
  final synthesizeBold = listEquals(regular, bold);
  final regularTypeface = _PdfTypeface(document, regular);
  final fonts = [
    regularTypeface,
    synthesizeBold ? regularTypeface : _PdfTypeface(document, bold),
  ];
  for (final sheet in layout.pages) {
    final page = PdfPage(
      document,
      pageFormat: PdfPageFormat(layout.width, layout.height),
    );
    final canvas = page.getGraphics();
    for (final rule in sheet.rules) {
      canvas.setColor(_color(rule.color));
      if (rule.height > 0) {
        canvas.drawRect(
          rule.x,
          layout.height - rule.y - rule.height,
          rule.width,
          rule.height,
        );
        canvas.fillPath();
      } else {
        canvas.setLineWidth(rule.thickness);
        canvas.drawLine(
          rule.x,
          layout.height - rule.y,
          rule.x + rule.width,
          layout.height - rule.y,
        );
        canvas.strokePath();
      }
    }
    for (final line in sheet.lines) {
      for (final span in line.spans) {
        if (span.text.isEmpty || (span.color >> 24) == 0) continue;
        final typeface = fonts[span.bold ? 1 : 0];
        final advance =
            typeface.font(0).stringMetrics(span.text).advanceWidth * span.size;
        final scale = advance > 0 && span.width > 0
            ? span.width / advance
            : 1.0;
        canvas.setColor(_color(span.color));
        final strokeBold = span.bold && synthesizeBold;
        if (strokeBold) {
          canvas.saveContext();
          canvas.setLineWidth(span.size * .025);
        }
        var x = span.x;
        for (final piece in typeface.pieces(span.text)) {
          final font = typeface.font(piece.rank);
          if (span.italic) {
            canvas.saveContext();
            canvas.setTransform(
              vm.Matrix4.identity()
                ..setEntry(0, 1, .2)
                ..setEntry(0, 3, x)
                ..setEntry(1, 3, layout.height - line.baseline),
            );
          }
          canvas.drawString(
            font,
            span.size,
            piece.text,
            span.italic ? 0 : x,
            span.italic ? 0 : layout.height - line.baseline,
            scale: scale,
            mode: strokeBold
                ? PdfTextRenderingMode.fillAndStroke
                : PdfTextRenderingMode.fill,
          );
          if (span.italic) canvas.restoreContext();
          x += font.stringMetrics(piece.text).advanceWidth * span.size * scale;
        }
        if (strokeBold) canvas.restoreContext();
        if (span.underline || span.strike) {
          canvas.setLineWidth(math.max(.5, span.size / 18));
          for (final y in [
            if (span.underline) line.baseline + span.size * .12,
            if (span.strike) line.baseline - span.size * .3,
          ]) {
            canvas.drawLine(
              span.x,
              layout.height - y,
              span.x + span.width,
              layout.height - y,
            );
            canvas.strokePath();
          }
        }
      }
    }
    for (final picture in sheet.pictures) {
      final image = PdfImage.file(document, bytes: picture.bytes);
      canvas.drawImage(
        image,
        picture.x,
        layout.height - picture.y - picture.height,
        picture.width,
        picture.height,
      );
    }
  }
  return document.save();
}

String _xml(String value) => value
    .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '')
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&apos;');
String _rgb(int color) =>
    (color & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase();
int _twip(double value) => (value * 20).round();

Uint8List _obfuscated(Uint8List bytes, List<int> key) {
  final result = Uint8List.fromList(bytes);
  for (var i = 0; i < 32; i++) {
    result[i] ^= key[15 - i % 16];
  }
  return result;
}

Uint8List _word(ResumeExportLayout layout, Uint8List regular, Uint8List bold) {
  final zip = Archive();
  void add(String name, Uint8List bytes) =>
      zip.addFile(ArchiveFile(name, bytes.length, bytes));
  void text(String name, String value) =>
      add(name, Uint8List.fromList(utf8.encode(value)));
  const ns = 'http://schemas.openxmlformats.org/';
  const rel =
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships/';
  final body = StringBuffer(
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><w:document xmlns:w="${ns}wordprocessingml/2006/main" xmlns:r="${ns}officeDocument/2006/relationships" xmlns:wp="${ns}drawingml/2006/wordprocessingDrawing" xmlns:a="${ns}drawingml/2006/main" xmlns:pic="${ns}drawingml/2006/picture" xmlns:wps="http://schemas.microsoft.com/office/word/2010/wordprocessingShape"><w:body>',
  );
  final relations = StringBuffer(
    '<?xml version="1.0" encoding="UTF-8"?><Relationships xmlns="${ns}package/2006/relationships"><Relationship Id="fonts" Type="${rel}fontTable" Target="fontTable.xml"/>',
  );
  var id = 1;
  int emu(double value) => (value * 12700).round();
  String anchor(
    String content,
    String uri,
    double x,
    double y,
    double width,
    double height, {
    bool background = false,
  }) {
    final current = id++;
    return '<w:r><w:drawing><wp:anchor distT="0" distB="0" distL="0" distR="0" simplePos="0" relativeHeight="$current" behindDoc="${background ? 1 : 0}" locked="0" layoutInCell="1" allowOverlap="1"><wp:simplePos x="0" y="0"/><wp:positionH relativeFrom="page"><wp:posOffset>${emu(x)}</wp:posOffset></wp:positionH><wp:positionV relativeFrom="page"><wp:posOffset>${emu(y)}</wp:posOffset></wp:positionV><wp:extent cx="${emu(width)}" cy="${emu(height)}"/><wp:effectExtent l="0" t="0" r="0" b="0"/><wp:wrapNone/><wp:docPr id="$current" name="Resume object $current"/><wp:cNvGraphicFramePr/><a:graphic><a:graphicData uri="$uri">$content</a:graphicData></a:graphic></wp:anchor></w:drawing></w:r>';
  }

  for (var page = 0; page < layout.pages.length; page++) {
    final sheet = layout.pages[page];
    final sorted = List<ResumeExportLine>.of(sheet.lines)
      ..sort(
        (a, b) => (a.top - b.top).abs() < .35
            ? a.spans.first.x.compareTo(b.spans.first.x)
            : a.top.compareTo(b.top),
      );
    final rows = <List<ResumeExportLine>>[];
    for (final line in sorted) {
      if (line.spans.isEmpty) continue;
      if (rows.isNotEmpty && (rows.last.first.top - line.top).abs() < .35) {
        rows.last.add(line);
      } else {
        rows.add([line]);
      }
    }
    if (rows.isEmpty) {
      rows.add([
        const ResumeExportLine(top: 0, height: 1, baseline: 1, spans: []),
      ]);
    }
    final drawings = StringBuffer();
    for (final rule in sheet.rules) {
      final height = rule.height > 0
          ? rule.height
          : math.max(rule.thickness, .1);
      final width = math.max(rule.width, .1);
      final shape =
          '<wps:wsp><wps:cNvSpPr/><wps:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="${emu(width)}" cy="${emu(height)}"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom><a:solidFill><a:srgbClr val="${_rgb(rule.color)}"/></a:solidFill><a:ln><a:noFill/></a:ln></wps:spPr><wps:bodyPr/></wps:wsp>';
      drawings.write(
        anchor(
          shape,
          'http://schemas.microsoft.com/office/word/2010/wordprocessingShape',
          rule.x,
          rule.height > 0 ? rule.y : rule.y - height / 2,
          width,
          height,
          background: true,
        ),
      );
    }
    for (final picture in sheet.pictures) {
      final imageId = 'image${id++}';
      add('word/media/$imageId.png', picture.bytes);
      relations.write(
        '<Relationship Id="$imageId" Type="${rel}image" Target="media/$imageId.png"/>',
      );
      final pictureXml =
          '<pic:pic><pic:nvPicPr><pic:cNvPr id="$id" name="头像"/><pic:cNvPicPr/></pic:nvPicPr><pic:blipFill><a:blip r:embed="$imageId"/><a:stretch><a:fillRect/></a:stretch></pic:blipFill><pic:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="${emu(picture.width)}" cy="${emu(picture.height)}"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></pic:spPr></pic:pic>';
      drawings.write(
        anchor(
          pictureXml,
          '${ns}drawingml/2006/picture',
          picture.x,
          picture.y,
          picture.width,
          picture.height,
        ),
      );
    }
    var previousBottom = 0.0;
    for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) {
      final row = rows[rowIndex];
      final height = row.map((l) => l.height).reduce(math.max);
      final top = row.map((l) => l.top).reduce(math.min);
      final spans =
          row.expand((l) => l.spans).where((s) => (s.color >> 24) != 0).toList()
            ..sort((a, b) => a.x.compareTo(b.x));
      final left = spans.isEmpty ? 0.0 : spans.first.x;
      final gap = math.max(0.0, top - previousBottom);
      final tabs = <double>[];
      var right = left;
      for (final span in spans) {
        if (span.x > right + .75) tabs.add(span.x);
        right = span.x + span.width;
      }
      body.write(
        '<w:p><w:pPr>${page > 0 && rowIndex == 0 ? '<w:pageBreakBefore/>' : ''}<w:spacing w:before="${_twip(gap)}" w:after="0" w:line="${_twip(height)}" w:lineRule="exact"/><w:ind w:left="${_twip(left)}" w:right="0"/><w:autoSpaceDE w:val="0"/><w:autoSpaceDN w:val="0"/><w:snapToGrid w:val="0"/><w:widowControl w:val="0"/>${tabs.isEmpty ? '' : '<w:tabs>${tabs.map((x) => '<w:tab w:val="left" w:pos="${_twip(x)}"/>').join()}</w:tabs>'}</w:pPr>',
      );
      if (rowIndex == 0) body.write(drawings);
      right = left;
      for (final span in spans) {
        if (span.x > right + .75) body.write('<w:r><w:tab/></w:r>');
        body.write(
          '<w:r><w:rPr><w:rFonts w:ascii="$resumeDocumentTypeface" w:hAnsi="$resumeDocumentTypeface" w:eastAsia="$resumeDocumentTypeface" w:cs="$resumeDocumentTypeface"/><w:sz w:val="${(span.size * 2).round()}"/><w:szCs w:val="${(span.size * 2).round()}"/><w:color w:val="${_rgb(span.color)}"/>${span.bold ? '<w:b/><w:bCs/>' : ''}${span.italic ? '<w:i/><w:iCs/>' : ''}${span.underline ? '<w:u w:val="single"/>' : ''}${span.strike ? '<w:strike/>' : ''}</w:rPr><w:t xml:space="preserve">${_xml(span.text)}</w:t></w:r>',
        );
        right = span.x + span.width;
      }
      body.write('</w:p>');
      previousBottom = top + height;
    }
  }
  body.write(
    '<w:sectPr><w:pgSz w:w="${_twip(layout.width)}" w:h="${_twip(layout.height)}"/><w:pgMar w:top="0" w:right="0" w:bottom="0" w:left="0" w:header="0" w:footer="0" w:gutter="0"/></w:sectPr></w:body></w:document>',
  );
  relations.write('</Relationships>');
  text('word/document.xml', body.toString());
  text('word/_rels/document.xml.rels', relations.toString());
  text(
    '[Content_Types].xml',
    '<?xml version="1.0"?><Types xmlns="${ns}package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Default Extension="png" ContentType="image/png"/><Default Extension="odttf" ContentType="application/vnd.openxmlformats-officedocument.obfuscatedFont"/><Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/><Override PartName="/word/fontTable.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.fontTable+xml"/></Types>',
  );
  text(
    '_rels/.rels',
    '<?xml version="1.0"?><Relationships xmlns="${ns}package/2006/relationships"><Relationship Id="document" Type="${rel}officeDocument" Target="word/document.xml"/></Relationships>',
  );
  const key = '{00112233-4455-6677-8899-AABBCCDDEEFF}';
  final keyBytes = List<int>.generate(16, (i) => i * 17);
  final hasBoldFace = !listEquals(regular, bold);
  add('word/fonts/regular.odttf', _obfuscated(regular, keyBytes));
  if (hasBoldFace) add('word/fonts/bold.odttf', _obfuscated(bold, keyBytes));
  text(
    'word/fontTable.xml',
    '<?xml version="1.0"?><w:fonts xmlns:w="${ns}wordprocessingml/2006/main" xmlns:r="${ns}officeDocument/2006/relationships"><w:font w:name="$resumeDocumentTypeface"><w:family w:val="swiss"/><w:embedRegular r:id="regular" w:fontKey="$key"/>${hasBoldFace ? '<w:embedBold r:id="bold" w:fontKey="$key"/>' : ''}</w:font></w:fonts>',
  );
  text(
    'word/_rels/fontTable.xml.rels',
    '<?xml version="1.0"?><Relationships xmlns="${ns}package/2006/relationships"><Relationship Id="regular" Type="${rel}font" Target="fonts/regular.odttf"/>${hasBoldFace ? '<Relationship Id="bold" Type="${rel}font" Target="fonts/bold.odttf"/>' : ''}</Relationships>',
  );
  return Uint8List.fromList(ZipEncoder().encode(zip));
}
