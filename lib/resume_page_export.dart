import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import 'api/bojian_api.dart';

// Both formats retain the exact page composition produced by Flutter.
typedef CaptureResumePages = Future<List<Uint8List>> Function({
  required bool Function() isCancelled,
  required ValueChanged<String> onProgress,
});

Future<XFile> exportPreviewPages({
  required CaptureResumePages capture,
  required String title,
  required String format,
  required bool Function() isCancelled,
  required ValueChanged<String> onProgress,
}) async {
  final pages = await capture(isCancelled: isCancelled, onProgress: onProgress);
  if (isCancelled()) throw const ApiFailure('导出已取消');
  if (pages.isEmpty) throw const ApiFailure('简历预览暂不可用');
  onProgress('正在打包${format == 'PDF' ? ' PDF' : ' Word'}文件…');
  final bytes = await Isolate.run(() => encodePreviewPages(pages, format));
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

Future<Uint8List> encodePreviewPages(
  List<Uint8List> pages,
  String format,
) async {
  if (format == 'PDF') {
    final document = pw.Document();
    for (final page in pages) {
      document.addPage(
        pw.Page(
          pageFormat: const PdfPageFormat(595.28, 841.89, marginAll: 0),
          build: (_) => pw.Image(
            pw.MemoryImage(page),
            width: 595.28,
            height: 841.89,
            fit: pw.BoxFit.fill,
          ),
        ),
      );
    }
    return document.save();
  }
  if (format != 'DOCX') throw const ApiFailure('请选择 Word 或 PDF');
  final archive = Archive();
  void text(String name, String value) {
    final bytes = Uint8List.fromList(value.codeUnits);
    archive.addFile(ArchiveFile(name, bytes.length, bytes));
  }

  text(
    '[Content_Types].xml',
    '<?xml version="1.0" encoding="UTF-8"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Default Extension="png" ContentType="image/png"/><Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/></Types>',
  );
  text(
    '_rels/.rels',
    '<?xml version="1.0" encoding="UTF-8"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/></Relationships>',
  );
  final content = StringBuffer(
    '<?xml version="1.0" encoding="UTF-8"?><w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture"><w:body>',
  );
  final relations = StringBuffer(
    '<?xml version="1.0" encoding="UTF-8"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">',
  );
  for (var i = 0; i < pages.length; i++) {
    final id = i + 1;
    final image = pages[i];
    archive.addFile(ArchiveFile('word/media/page$id.png', image.length, image));
    relations.write(
      '<Relationship Id="rId$id" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/page$id.png"/>',
    );
    content.write(
      '<w:p><w:pPr>${i == 0 ? '' : '<w:pageBreakBefore/>'}<w:spacing w:before="0" w:after="0" w:line="1" w:lineRule="exact"/></w:pPr><w:r><w:drawing><wp:anchor distT="0" distB="0" distL="0" distR="0" simplePos="0" relativeHeight="0" behindDoc="1" locked="0" layoutInCell="0" allowOverlap="1"><wp:simplePos x="0" y="0"/><wp:positionH relativeFrom="page"><wp:posOffset>0</wp:posOffset></wp:positionH><wp:positionV relativeFrom="page"><wp:posOffset>0</wp:posOffset></wp:positionV><wp:extent cx="7560310" cy="10692130"/><wp:effectExtent l="0" t="0" r="0" b="0"/><wp:wrapNone/><wp:docPr id="$id" name="Page $id"/><wp:cNvGraphicFramePr/><a:graphic><a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture"><pic:pic><pic:nvPicPr><pic:cNvPr id="$id" name="page$id.png"/><pic:cNvPicPr/></pic:nvPicPr><pic:blipFill><a:blip r:embed="rId$id"/><a:stretch><a:fillRect/></a:stretch></pic:blipFill><pic:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="7560310" cy="10692130"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></pic:spPr></pic:pic></a:graphicData></a:graphic></wp:anchor></w:drawing></w:r></w:p>',
    );
  }
  content.write(
    '<w:sectPr><w:pgSz w:w="11906" w:h="16838"/><w:pgMar w:top="0" w:right="0" w:bottom="0" w:left="0" w:header="0" w:footer="0" w:gutter="0"/></w:sectPr></w:body></w:document>',
  );
  relations.write('</Relationships>');
  text('word/document.xml', content.toString());
  text('word/_rels/document.xml.rels', relations.toString());
  return Uint8List.fromList(ZipEncoder().encode(archive));
}
