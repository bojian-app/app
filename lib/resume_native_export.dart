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
const resumeDocumentTypeface = '阿里巴巴普惠体 3.0';
// Word resolves embedded fonts by the legacy family name (name ID 1).
const resumeWordRegularTypeface = '阿里巴巴普惠体 3.0 55 Regular';
const resumeWordMediumTypeface = '阿里巴巴普惠体 3.0 65 Medium';
const resumeFontRegularAsset = 'assets/fonts/alibaba-puhuiti-3-regular.ttf';
const resumeFontMediumAsset = 'assets/fonts/alibaba-puhuiti-3-medium.ttf';
const resumeFontBoldAsset = 'assets/fonts/alibaba-puhuiti-3-bold.ttf';
const resumeDocumentFontAssets = {
  'regular.ttf': resumeFontRegularAsset,
  'medium.ttf': resumeFontMediumAsset,
  'bold.ttf': resumeFontBoldAsset,
};
const resumeDocumentFontStyles = """
@font-face{font-family:ResumeDocument;src:url('regular.ttf') format('truetype');font-weight:400;font-style:normal}
@font-face{font-family:ResumeDocument;src:url('medium.ttf') format('truetype');font-weight:500 600;font-style:normal}
@font-face{font-family:ResumeDocument;src:url('bold.ttf') format('truetype');font-weight:700 900;font-style:normal}
""";

// PDF imports can contain Unicode radicals in place of ordinary Han letters.
// Normalize only these visual equivalents, without changing user punctuation.
String resumeExportText(String text) {
  const kangxi =
      '一丨丶丿乙亅二亠人儿入八冂冖冫几凵刀力勹匕匚匸十卜卩厂厶又口囗土士夂夊夕大女子宀寸小尢尸屮山巛工己巾干幺广廴廾弋弓彐彡彳心戈戶手支攴文斗斤方无日曰月木欠止歹殳毋比毛氏气水火爪父爻爿片牙牛犬玄玉瓜瓦甘生用田疋疒癶白皮皿目矛矢石示禸禾穴立竹米糸缶网羊羽老而耒耳聿肉臣自至臼舌舛舟艮色艸虍虫血行衣襾見角言谷豆豕豸貝赤走足身車辛辰辵邑酉釆里金長門阜隶隹雨靑非面革韋韭音頁風飛食首香馬骨高髟鬥鬯鬲鬼魚鳥鹵鹿麥麻黃黍黑黹黽鼎鼓鼠鼻齊齒龍龜龠';
  const supplement = {0x2ec5: '见', 0x2ed3: '长', 0x2ed4: '门', 0x2eda: '页'};
  return String.fromCharCodes(
    text.runes.map((rune) {
      if (rune >= 0x2f00 && rune < 0x2f00 + kangxi.length) {
        return kangxi.codeUnitAt(rune - 0x2f00);
      }
      return supplement[rune]?.codeUnitAt(0) ?? rune;
    }),
  );
}

class ResumeExportSpan {
  const ResumeExportSpan({
    required this.text,
    required this.x,
    required this.width,
    required this.size,
    this.color = 0xFF26292E,
    this.bold = false,
    this.weight,
    this.italic = false,
    this.underline = false,
    this.strike = false,
  });
  final String text;
  final double x, width, size;
  final int color;
  final bool bold, italic, underline, strike;
  final int? weight;
  int get fontWeight => weight ?? (bold ? 700 : 400);
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
    this.background,
  });
  final List<ResumeExportLine> lines;
  final List<ResumeExportRule> rules;
  final List<ResumeExportPicture> pictures;
  // HTML's decorative paint layer only; all resume text stays native.
  final ResumeExportPicture? background;
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
  final medium = (await rootBundle.load(resumeFontMediumAsset)).buffer
      .asUint8List();
  final bytes = await Isolate.run(
    () => encodeNativeResume(layout, format, regular, bold, medium: medium),
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
  Uint8List bold, {
  Uint8List? medium,
}) async {
  if (format == 'PDF') return _pdf(layout, regular, bold, medium);
  if (format == 'DOCX') return _word(layout, regular, bold, medium);
  throw const ApiFailure('请选择 Word 或 PDF');
}

PdfColor _color(int argb) => PdfColor.fromInt(argb & 0xFFFFFF);

// Some CJK cmap entries alias one glyph (for example · and •). The PDF
// subset writer must not assign two Unicode CIDs to the same glyph in a font.
// Keep aliases in separate subsets, preserving both appearance and ToUnicode.
class _PdfTypeface {
  _PdfTypeface(this.document, this.bytes, Set<int> characters) {
    final base = PdfTtfFont(document, ByteData.sublistView(bytes));
    fonts[0] = base;
    final cmap = base.font.charToGlyphIndexMap;
    final replacement = cmap[0x25a1] ?? cmap[0xfffd] ?? cmap[0x3f]!;
    for (final rune in characters) {
      if ((cmap[rune] ?? 0) == 0) {
        aliases[rune] = replacement;
        cmap[rune] = replacement;
      }
    }
    final counts = <int, int>{};
    final entries = cmap.entries.toList()
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
  final aliases = <int, int>{};
  PdfTtfFont font(int rank) => fonts.putIfAbsent(
    rank,
    () =>
        PdfTtfFont(document, ByteData.sublistView(bytes))
          ..font.charToGlyphIndexMap.addAll(aliases),
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
  Uint8List? medium,
) async {
  final document = PdfDocument();
  final synthesizeBold = listEquals(regular, bold);
  final characters = layout.pages
      .expand((page) => page.lines)
      .expand((line) => line.spans)
      .expand((span) => resumeExportText(span.text).runes)
      .toSet();
  final regularTypeface = _PdfTypeface(document, regular, characters);
  final fonts = [
    regularTypeface,
    medium == null
        ? regularTypeface
        : _PdfTypeface(document, medium, characters),
    synthesizeBold ? regularTypeface : _PdfTypeface(document, bold, characters),
  ];
  for (final sheet in layout.pages) {
    final page = PdfPage(
      document,
      pageFormat: PdfPageFormat(layout.width, layout.height),
    );
    final canvas = page.getGraphics();
    final background = sheet.background;
    if (background != null) {
      canvas.drawImage(
        PdfImage.file(document, bytes: background.bytes),
        background.x,
        layout.height - background.y - background.height,
        background.width,
        background.height,
      );
    }
    for (final rule
        in background == null ? sheet.rules : <ResumeExportRule>[]) {
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
        final text = resumeExportText(span.text);
        final weight = span.fontWeight;
        final typeface = fonts[weight >= 700 ? 2 : (weight >= 500 ? 1 : 0)];
        final advance =
            typeface.font(0).stringMetrics(text).advanceWidth * span.size;
        final scale = advance > 0 && span.width > 0
            ? span.width / advance
            : 1.0;
        canvas.setColor(_color(span.color));
        final strokeBold = weight >= 700 && synthesizeBold;
        if (strokeBold) {
          canvas.saveContext();
          canvas.setLineWidth(span.size * .025);
        }
        var x = span.x;
        final baseline = layout.height - line.baseline;
        for (final piece in typeface.pieces(text)) {
          final font = typeface.font(piece.rank);
          if (span.italic) {
            canvas.saveContext();
            canvas.setTransform(
              vm.Matrix4.identity()
                ..setEntry(0, 1, .2)
                ..setEntry(0, 3, x)
                ..setEntry(1, 3, baseline),
            );
          }
          canvas.drawString(
            font,
            span.size,
            piece.text,
            span.italic ? 0 : x,
            span.italic ? 0 : baseline,
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

Uint8List _word(
  ResumeExportLayout layout,
  Uint8List regular,
  Uint8List bold,
  Uint8List? medium,
) {
  final zip = Archive();
  void add(String name, Uint8List bytes) =>
      zip.addFile(ArchiveFile(name, bytes.length, bytes));
  void text(String name, String value) =>
      add(name, Uint8List.fromList(utf8.encode(value)));
  const ns = 'http://schemas.openxmlformats.org/';
  const rel =
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships/';
  final body = StringBuffer(
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><w:document xmlns:w="${ns}wordprocessingml/2006/main" xmlns:r="${ns}officeDocument/2006/relationships" xmlns:wp="${ns}drawingml/2006/wordprocessingDrawing" xmlns:a="${ns}drawingml/2006/main" xmlns:pic="${ns}drawingml/2006/picture" xmlns:wps="http://schemas.microsoft.com/office/word/2010/wordprocessingShape" xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006" mc:Ignorable="wps" xmlns:v="urn:schemas-microsoft-com:vml" xmlns:o="urn:schemas-microsoft-com:office:office" xmlns:w10="urn:schemas-microsoft-com:office:word"><w:body>',
  );
  final relations = StringBuffer(
    '<?xml version="1.0" encoding="UTF-8"?><Relationships xmlns="${ns}package/2006/relationships"><Relationship Id="fonts" Type="${rel}fontTable" Target="fontTable.xml"/><Relationship Id="settings" Type="${rel}settings" Target="settings.xml"/>',
  );
  var id = 1;
  int emu(double value) => (value * 12700).round();
  String anchor(
    int current,
    String content,
    String uri,
    double x,
    double y,
    double width,
    double height, {
    bool background = false,
  }) {
    return '<w:drawing><wp:anchor distT="0" distB="0" distL="0" distR="0" simplePos="0" relativeHeight="$current" behindDoc="${background ? 1 : 0}" locked="0" layoutInCell="1" allowOverlap="1"><wp:simplePos x="0" y="0"/><wp:positionH relativeFrom="page"><wp:posOffset>${emu(x)}</wp:posOffset></wp:positionH><wp:positionV relativeFrom="page"><wp:posOffset>${emu(y)}</wp:posOffset></wp:positionV><wp:extent cx="${emu(width)}" cy="${emu(height)}"/><wp:effectExtent l="0" t="0" r="0" b="0"/><wp:wrapNone/><wp:docPr id="$current" name="Resume object $current"/><wp:cNvGraphicFramePr/><a:graphic><a:graphicData uri="$uri">$content</a:graphicData></a:graphic></wp:anchor></w:drawing>';
  }

  // Both text and its background need a modern shape AND a legacy fallback.
  // A reader chooses one complete branch; neither branch depends on the other.
  String rectangle(
    double x,
    double y,
    double width,
    double height, {
    int? fill,
    String? textContent,
  }) {
    final current = id++;
    final background = textContent == null;
    final shape =
        '<wps:wsp><wps:cNvSpPr${background ? '' : ' txBox="1"'}/><wps:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="${emu(width)}" cy="${emu(height)}"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom>${fill == null ? '<a:noFill/>' : '<a:solidFill><a:srgbClr val="${_rgb(fill)}"/></a:solidFill>'}<a:ln><a:noFill/></a:ln></wps:spPr>${textContent == null ? '' : '<wps:txbx>$textContent</wps:txbx>'}<wps:bodyPr wrap="none" lIns="0" tIns="0" rIns="0" bIns="0" anchor="t" vertOverflow="overflow" horzOverflow="overflow"><a:spAutoFit/></wps:bodyPr></wps:wsp>';
    final drawing = anchor(
      current,
      shape,
      'http://schemas.microsoft.com/office/word/2010/wordprocessingShape',
      x,
      y,
      width,
      height,
      background: background,
    );
    final legacy =
        '<w:pict><v:rect id="ResumeObject$current" o:spid="_x0000_s${1024 + current}" style="position:absolute;margin-left:${x.toStringAsFixed(3)}pt;margin-top:${y.toStringAsFixed(3)}pt;width:${width.toStringAsFixed(3)}pt;height:${height.toStringAsFixed(3)}pt;z-index:${background ? current - 100000 : current};mso-position-horizontal-relative:page;mso-position-vertical-relative:page;mso-wrap-style:none" filled="${fill == null ? 'f' : 't'}"${fill == null ? '' : ' fillcolor="#${_rgb(fill)}"'} stroked="f" o:allowincell="f">${textContent == null ? '' : '<v:textbox inset="0,0,0,0" style="mso-wrap-style:none;mso-fit-shape-to-text:t">$textContent</v:textbox>'}<w10:wrap type="none" anchorx="page" anchory="page"/></v:rect></w:pict>';
    return '<w:r><mc:AlternateContent><mc:Choice Requires="wps">$drawing</mc:Choice><mc:Fallback>$legacy</mc:Fallback></mc:AlternateContent></w:r>';
  }

  // Do not rely on fitText alone: a substituted font can be wider in readers
  // that ignore it. Give each transparent box spare horizontal room, disable
  // wrapping and allow it to grow vertically instead of clipping the text.
  final metricDocument = PdfDocument();
  final metrics = [
    PdfTtfFont(metricDocument, ByteData.sublistView(regular)),
    PdfTtfFont(metricDocument, ByteData.sublistView(medium ?? regular)),
    PdfTtfFont(metricDocument, ByteData.sublistView(bold)),
  ];
  for (var page = 0; page < layout.pages.length; page++) {
    final sheet = layout.pages[page];
    // A page has one small anchor paragraph. Every text fragment retains its
    // own page coordinates, so independent columns never advance each other.
    final drawings = StringBuffer();
    for (final rule
        in sheet.background == null ? sheet.rules : <ResumeExportRule>[]) {
      final height = rule.height > 0
          ? rule.height
          : math.max(rule.thickness, .1);
      final width = math.max(rule.width, .1);
      drawings.write(
        rectangle(
          rule.x,
          rule.height > 0 ? rule.y : rule.y - height / 2,
          width,
          height,
          fill: rule.color,
        ),
      );
    }
    for (final picture in [
      if (sheet.background != null) sheet.background!,
      ...sheet.pictures,
    ]) {
      final imageId = 'image${id++}';
      add('word/media/$imageId.png', picture.bytes);
      relations.write(
        '<Relationship Id="$imageId" Type="${rel}image" Target="media/$imageId.png"/>',
      );
      final pictureXml =
          '<pic:pic><pic:nvPicPr><pic:cNvPr id="$id" name="头像"/><pic:cNvPicPr/></pic:nvPicPr><pic:blipFill><a:blip r:embed="$imageId"/><a:stretch><a:fillRect/></a:stretch></pic:blipFill><pic:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="${emu(picture.width)}" cy="${emu(picture.height)}"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></pic:spPr></pic:pic>';
      drawings.write('<w:r>');
      drawings.write(
        anchor(
          id++,
          pictureXml,
          '${ns}drawingml/2006/picture',
          picture.x,
          picture.y,
          picture.width,
          picture.height,
          // All text is floating above this first image by relativeHeight.
          // behindDoc would turn page art into a faded watermark in QuickLook.
        ),
      );
      drawings.write('</w:r>');
    }
    if (page > 0) {
      body.write(
        '<w:p><w:pPr><w:spacing w:before="0" w:after="0" w:line="20" w:lineRule="exact"/></w:pPr><w:r><w:br w:type="page"/></w:r></w:p>',
      );
    }
    body.write(
      '<w:p><w:pPr><w:widowControl w:val="0"/><w:spacing w:before="0" w:after="0" w:line="20" w:lineRule="exact"/></w:pPr>',
    );
    body.write(drawings);
    for (final line in sheet.lines) {
      for (final span in line.spans) {
        if (span.text.isEmpty || (span.color >> 24) == 0) continue;
        final weight = span.fontWeight;
        final isBold = weight >= 700;
        final isMedium = weight >= 500 && !isBold && medium != null;
        final family = isMedium
            ? resumeWordMediumTypeface
            : resumeWordRegularTypeface;
        final text = resumeExportText(span.text);
        final size = (span.size * 2).round();
        final face = metrics[isBold ? 2 : (isMedium ? 1 : 0)];
        final height = math.max(line.height, size / 2 * 1.5);
        final width = math.max(
          .1,
          math.min(
            layout.width - span.x,
            math.max(span.width * 1.15, span.width + span.size * 2),
          ),
        );
        // Use the measured baseline and font ascender, rather than the DOM ink
        // box, for vertical placement (all packaged faces have a 1.06 em ascent).
        final top = line.baseline - size / 2 * face.ascent;
        final content =
            '<w:txbxContent><w:p><w:pPr><w:widowControl w:val="0"/><w:autoSpaceDE w:val="0"/><w:autoSpaceDN w:val="0"/><w:snapToGrid w:val="0"/><w:spacing w:before="0" w:after="0" w:line="240" w:lineRule="auto"/><w:rPr><w:rFonts w:ascii="$family" w:hAnsi="$family" w:eastAsia="$family" w:cs="$family"/><w:sz w:val="$size"/></w:rPr></w:pPr><w:r><w:rPr><w:rFonts w:ascii="$family" w:hAnsi="$family" w:eastAsia="$family" w:cs="$family"/>${isBold ? '<w:b/><w:bCs/>' : ''}${span.italic ? '<w:i/><w:iCs/>' : ''}${span.strike ? '<w:strike/>' : ''}<w:color w:val="${_rgb(span.color)}"/><w:sz w:val="$size"/><w:szCs w:val="$size"/>${span.underline ? '<w:u w:val="single"/>' : ''}<w:fitText w:val="${math.max(1, _twip(span.width))}" w:id="$id"/><w:lang w:val="en-US" w:eastAsia="zh-CN"/></w:rPr><w:t xml:space="preserve">${_xml(text)}</w:t></w:r></w:p></w:txbxContent>';
        body.write(rectangle(span.x, top, width, height, textContent: content));
      }
    }
    body.write('</w:p>');
  }
  body.write(
    '<w:sectPr><w:pgSz w:w="${_twip(layout.width)}" w:h="${_twip(layout.height)}"/><w:pgMar w:top="0" w:right="0" w:bottom="0" w:left="0" w:header="0" w:footer="0" w:gutter="0"/></w:sectPr></w:body></w:document>',
  );
  relations.write('</Relationships>');
  text('word/document.xml', body.toString());
  text('word/_rels/document.xml.rels', relations.toString());
  text(
    '[Content_Types].xml',
    '<?xml version="1.0"?><Types xmlns="${ns}package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Default Extension="png" ContentType="image/png"/><Default Extension="odttf" ContentType="application/vnd.openxmlformats-officedocument.obfuscatedFont"/><Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/><Override PartName="/word/fontTable.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.fontTable+xml"/><Override PartName="/word/settings.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.settings+xml"/></Types>',
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
  if (medium != null) {
    add('word/fonts/medium.odttf', _obfuscated(medium, keyBytes));
  }
  text(
    'word/fontTable.xml',
    '<?xml version="1.0"?><w:fonts xmlns:w="${ns}wordprocessingml/2006/main" xmlns:r="${ns}officeDocument/2006/relationships"><w:font w:name="$resumeWordRegularTypeface"><w:family w:val="swiss"/><w:embedRegular r:id="regular" w:fontKey="$key"/>${hasBoldFace ? '<w:embedBold r:id="bold" w:fontKey="$key"/>' : ''}</w:font>${medium == null ? '' : '<w:font w:name="$resumeWordMediumTypeface"><w:family w:val="swiss"/><w:embedRegular r:id="medium" w:fontKey="$key"/></w:font>'}</w:fonts>',
  );
  text(
    'word/_rels/fontTable.xml.rels',
    '<?xml version="1.0"?><Relationships xmlns="${ns}package/2006/relationships"><Relationship Id="regular" Type="${rel}font" Target="fonts/regular.odttf"/>${hasBoldFace ? '<Relationship Id="bold" Type="${rel}font" Target="fonts/bold.odttf"/>' : ''}${medium == null ? '' : '<Relationship Id="medium" Type="${rel}font" Target="fonts/medium.odttf"/>'}</Relationships>',
  );
  text(
    'word/settings.xml',
    '<?xml version="1.0"?><w:settings xmlns:w="${ns}wordprocessingml/2006/main"><w:embedTrueTypeFonts/><w:saveSubsetFonts w:val="0"/><w:compat><w:compatSetting w:name="compatibilityMode" w:uri="http://schemas.microsoft.com/office/word" w:val="15"/></w:compat></w:settings>',
  );
  return Uint8List.fromList(ZipEncoder().encode(zip));
}
