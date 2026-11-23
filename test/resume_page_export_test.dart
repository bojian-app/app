import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:bojian_mobile/api/bojian_api.dart';
import 'package:bojian_mobile/app_store.dart';
import 'package:bojian_mobile/resume_document.dart';
import 'package:bojian_mobile/resume_guidance_review.dart';
import 'package:bojian_mobile/resume_native_export.dart';
import 'package:bojian_mobile/resume_theme.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Word honors the theme page-number setting', (tester) async {
    final regular = (await rootBundle.load(resumeFontRegularAsset)).buffer
        .asUint8List();
    final bold = (await rootBundle.load(resumeFontBoldAsset)).buffer
        .asUint8List();
    for (final enabled in [false, true]) {
      final theme = await ResumeTheme.load('page-numbers-$enabled', {
        'page': {'page_numbers': enabled},
      }, {});
      final key = GlobalKey<ResumeDocumentViewState>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ResumeDocumentView(
              key: key,
              resume: ResumeDraft(id: 0, title: '页码检查', name: '林知远'),
              theme: theme,
            ),
          ),
        ),
      );
      await tester.runAsync(() async {
        final layout = await key.currentState!.captureLayout(
          isCancelled: () => false,
          onProgress: (_) {},
        );
        expect(layout.wordLayout!.wordPageNumbers, enabled);
        final archive = ZipDecoder().decodeBytes(
          await encodeNativeResume(layout, 'DOCX', regular, bold),
        );
        expect(archive.findFile('word/footer.xml') != null, enabled);
        final documentXml = utf8.decode(
          archive.findFile('word/document.xml')!.content,
        );
        expect(
          documentXml,
          contains('<w:headerReference w:type="first" r:id="firstPage"/>'),
        );
        expect(
          documentXml,
          contains('<w:headerReference w:type="default" r:id="continuation"/>'),
        );
        expect(documentXml, contains('<w:titlePg/>'));
        for (final name in ['firstPage', 'continuation']) {
          expect(archive.findFile('word/$name.xml'), isNotNull);
          expect(archive.findFile('word/_rels/$name.xml.rels'), isNotNull);
          expect(archive.findFile('word/media/$name.png'), isNotNull);
        }
        for (final name in [
          'word/document.xml',
          'word/_rels/document.xml.rels',
          '[Content_Types].xml',
        ]) {
          final xml = utf8.decode(archive.findFile(name)!.content);
          expect(
            xml.contains(
              name == 'word/document.xml' ? 'footerReference' : 'footer.xml',
            ),
            enabled,
            reason: name,
          );
        }
      });
    }
  });
  testWidgets(
    'Native preview pages retain A4 size and every page in both formats',
    (tester) async {
      final draft = decodeResume({
        'title': '分页验证',
        'content': {
          'personal_info': {'full_name': '预览一致性'},
          'work_experiences': [
            {
              'company': '分页验证',
              'description': List.generate(
                70,
                (i) => '工作内容 $i：原生排版与导出使用相同页面。',
              ).join('\n'),
            },
          ],
        },
      });
      final key = GlobalKey<ResumeDocumentViewState>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ResumeDocumentView(key: key, resume: draft),
          ),
        ),
      );
      final document = ResumeDocument(draft);
      addTearDown(document.dispose);
      expect(document.pages.length, greaterThan(1));
      await tester.runAsync(() async {
        final pages = await key.currentState!.capturePages(
          isCancelled: () => false,
          onProgress: (_) {},
        );
        expect(pages.length, document.pages.length);
        for (final page in pages) {
          final header = ByteData.sublistView(page);
          expect(header.getUint32(16), 2381);
          expect(header.getUint32(20), 3368);
        }
        final layout = await key.currentState!.captureLayout(
          isCancelled: () => false,
          onProgress: (_) {},
        );
        final regular = (await rootBundle.load(resumeFontRegularAsset)).buffer
            .asUint8List();
        final bold = (await rootBundle.load(resumeFontBoldAsset)).buffer
            .asUint8List();
        final word = await encodeNativeResume(layout, 'DOCX', regular, bold);
        final archive = ZipDecoder().decodeBytes(word);
        final xml = utf8.decode(archive.findFile('word/document.xml')!.content);
        // Word receives flowing text and paginates it itself, so every line
        // is present without fixed page breaks or zero margins.
        expect(xml, contains('<w:footerReference'));
        expect(xml, contains('工作内容 69'));
        // Pages stay text; the only pictures are section divider rules.
        expect(
          archive.files
              .where((f) => f.name.startsWith('word/media/'))
              .map((f) => f.name),
          everyElement(startsWith('word/media/rule')),
        );
        expect(xml, contains('预览一致性'));
        final pdf = await encodeNativeResume(layout, 'PDF', regular, bold);
        final pdfText = latin1.decode(pdf);
        expect(pdfText.startsWith('%PDF'), isTrue);
        expect(
          RegExp(r'/Type\s*/Page\b').allMatches(pdfText).length,
          pages.length,
        );
        // Optional artifacts allow QA in a real Word-compatible renderer.
        if (Platform.environment['BOJIAN_EXPORT_QA'] == '1') {
          await File('/tmp/bojian-fixed-pages.docx').writeAsBytes(word);
          await File('/tmp/bojian-fixed-pages.pdf').writeAsBytes(pdf);
          for (var i = 0; i < pages.length; i++) {
            await File('/tmp/bojian-fixed-page-${i + 1}.png')
                .writeAsBytes(pages[i]);
          }
        }
      });
    },
  );

  testWidgets(
    'Review waves, comments and their extra spacing stay out of export',
    (tester) async {
      const field = 'work_experiences.0.description';
      const quote = '负责网站开发';
      final resume = decodeResume({
        'title': '纯净导出验证',
        'content': {
          'personal_info': {'full_name': '测试作者'},
          'work_experiences': [
            {'company': '测试公司', 'description': '$quote\n后续交付内容完整保留。'},
          ],
        },
      });
      final key = GlobalKey<ResumeDocumentViewState>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ResumeDocumentView(
              key: key,
              resume: resume,
              reviewNotes: const [
                ResumeReviewNote(
                  key: 'export-note',
                  fieldPath: field,
                  selectedText: quote,
                  height: 700,
                ),
              ],
              reviewHighlights: const [
                ResumeReviewHighlight(
                  key: 'export-note',
                  fieldPath: field,
                  text: quote,
                  label: '评论',
                  color: guidanceCommentColor,
                  isWavy: true,
                ),
              ],
              reviewNoteBuilder: (_, _) => const Text('这一条评论不应进入导出'),
            ),
          ),
        ),
      );
      expect(key.currentState!.document!.pages.length, greaterThan(1));
      final withReview = await tester.runAsync(
        () => key.currentState!.capturePages(
          isCancelled: () => false,
          onProgress: (_) {},
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ResumeDocumentView(key: key, resume: resume),
          ),
        ),
      );
      final withoutReview = await tester.runAsync(
        () => key.currentState!.capturePages(
          isCancelled: () => false,
          onProgress: (_) {},
        ),
      );
      expect(withReview, hasLength(1));
      expect(withoutReview, hasLength(1));
      expect(withReview!.single, orderedEquals(withoutReview!.single));
      expect(tester.takeException(), isNull);
    },
  );

  test('Cancellation after capture prevents file generation', () async {
    var cancelled = false;
    await expectLater(
      exportNativeResume(
        capture: ({required isCancelled, required onProgress}) async {
          cancelled = true;
          return const ResumeExportLayout([]);
        },
        title: '简历',
        format: 'PDF',
        isCancelled: () => cancelled,
        onProgress: (_) {},
      ),
      throwsA(isA<ApiFailure>().having((e) => e.message, 'message', '导出已取消')),
    );
  });
}
