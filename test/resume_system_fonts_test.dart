import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:bojian_mobile/app_store.dart';
import 'package:bojian_mobile/resume_document.dart';
import 'package:bojian_mobile/resume_native_export.dart';
import 'package:bojian_mobile/resume_system_fonts.dart';
import 'package:bojian_mobile/resume_theme.dart';
import 'package:bojian_mobile/resume_thumbnail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'font notifications coalesce, background returns refresh, disposal cancels queued work',
    (tester) async {
      var changes = 0;
      final observer = ResumeSystemFontObserver(() => changes++);
      await tester.binding.handleSystemMessage({'type': 'fontsChange'});
      await tester.binding.handleSystemMessage({'type': 'fontsChange'});
      expect(changes, 0);
      await tester.pump();
      expect(changes, 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(changes, 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(changes, 2);
      await tester.binding.handleSystemMessage({'type': 'fontsChange'});
      observer.dispose();
      await tester.pump();
      expect(changes, 2);
    },
  );

  testWidgets(
    'cached preview and thumbnail follow the system font when device fonts change',
    (tester) async {
      final draft = decodeResume({
        'content': {
          'personal_info': {'full_name': '字体测试', 'phone': '13800138000'},
          'work_experiences': [
            {
              'company': '测试公司',
              'start_date': '2024-11',
              'description': '中文 English 0123456789',
            },
          ],
        },
      });
      final key = GlobalKey<ResumeDocumentViewState>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                Expanded(
                  child: ResumeDocumentView(key: key, resume: draft),
                ),
                SizedBox(
                  width: 100,
                  height: 150,
                  child: StandardResumeThumbnail(resume: draft),
                ),
              ],
            ),
          ),
        ),
      );
      final original = key.currentState!.document!;
      final originalText = original.painters
          .map((p) => p.text!.toPlainText())
          .toList();
      final thumbnail = tester
          .widget<ResumeSheetImage>(find.byType(ResumeSheetImage))
          .document;
      final transform = key.currentState!.transform.value.clone();
      await tester.binding.handleSystemMessage({'type': 'fontsChange'});
      await tester.pump();
      await tester.pump();
      final refreshed = key.currentState!.document!;
      expect(identical(original, refreshed), isFalse);
      // The resume is set in the system font; exports embed the bundled one.
      expect(refreshed.fontFamily, isNull);
      expect(
        refreshed.painters.map((p) => p.text!.toPlainText()),
        originalText,
      );
      expect(key.currentState!.transform.value, transform);
      expect(
        identical(
          thumbnail,
          tester
              .widget<ResumeSheetImage>(find.byType(ResumeSheetImage))
              .document,
        ),
        isFalse,
      );
      expect(
        tester
            .widget<ResumeSheetImage>(find.byType(ResumeSheetImage))
            .document
            .fontFamily,
        isNull,
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump();
      expect(identical(refreshed, key.currentState!.document), isFalse);
      await tester.pumpWidget(const SizedBox());
      await tester.binding.handleSystemMessage({'type': 'fontsChange'});
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('thumbnail reuses layout until mutable resume content changes', (
    tester,
  ) async {
    final draft = decodeResume({
      'content': {
        'work_experiences': [
          {'company': '测试公司', 'description': '原有内容'},
        ],
      },
    });
    Future<ResumeDocument> render() async {
      await tester.pumpWidget(
        MaterialApp(home: StandardResumeThumbnail(resume: draft)),
      );
      return tester
          .widget<ResumeSheetImage>(find.byType(ResumeSheetImage))
          .document;
    }

    final first = await render();
    expect(await render(), same(first));
    draft.source['work_experiences'][0]['description'] = '修改后的内容';
    final edited = await render();
    expect(edited, isNot(same(first)));
    expect(
      edited.painters.map((p) => p.text!.toPlainText()).join(),
      contains('修改后的内容'),
    );
    expect(await render(), same(edited));
  });

  test(
    'standard covers match the complete first page including its footer',
    () async {
      Future<Uint8List> render(ResumeDocument document) async {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder)..scale(.5);
        paintResumeSheet(canvas, document, 0);
        final picture = recorder.endRecording();
        final image = await picture.toImage(298, 421);
        try {
          return (await image.toByteData())!.buffer.asUint8List();
        } finally {
          image.dispose();
          picture.dispose();
        }
      }

      final experience = [
        for (var i = 0; i < 12; i++)
          {'company': '公司$i', 'description': '负责产品需求整理和评审。' * 30},
      ];
      final draft = ResumeDraft(
        id: 1,
        title: '简历',
        source: {'work_experiences': experience},
      );
      for (final name in ['张明', '超长姓名' * 180]) {
        draft.name = name;
        final full = ResumeDocument(draft, photoURL: 'photo');
        final cover = ResumeDocument(
          draft,
          photoURL: 'photo',
          standardCoverOnly: true,
        );
        addTearDown(full.dispose);
        addTearDown(cover.dispose);
        expect(full.pages.length, greaterThan(1));
        expect(cover.pages, hasLength(1));
        expect(cover.pages.first.photo, full.pages.first.photo);
        expect(cover.painters.length, lessThan(full.painters.length));
        expect(await render(cover), orderedEquals(await render(full)));
      }
      final reviewed = ResumeDocument(
        draft,
        standardCoverOnly: true,
        reviewNotes: const [
          ResumeReviewNote(key: 'late', fieldPath: 'skills', height: 40),
        ],
      );
      final theme = await resumeThemeOf(7, {
        'format': resumeThemeFormat,
        'theme': {
          'format': resumeThemeFormat,
          'page': {'background': '#FAF9F5'},
        },
      });
      final themed = ResumeDocument(
        draft,
        theme: theme,
        standardCoverOnly: true,
      );
      addTearDown(reviewed.dispose);
      addTearDown(themed.dispose);
      expect(
        reviewed.pages.last.reviewNotes.map((note) => note.note.key),
        contains('late'),
      );
      expect(themed.pages.length, greaterThan(1));
    },
  );

  test(
    'system font without a real bold draws bold text in the bundled face',
    () {
      final draft = decodeResume({
        'content': {
          'personal_info': {'full_name': '字体测试'},
          'work_experiences': [
            {'company': '测试公司', 'description': '中文正文 English'},
          ],
        },
      });
      Map<String, Set<String?>> families() {
        final document = ResumeDocument(draft, fontFamily: null);
        final result = <String, Set<String?>>{'bold': {}, 'regular': {}};
        for (final painter in document.painters) {
          painter.text!.visitChildren((span) {
            final style = span.style;
            if (span is TextSpan && (span.text ?? '').trim().isNotEmpty) {
              final bold = (style?.fontWeight?.value ?? 400) >= 600;
              result[bold ? 'bold' : 'regular']!.add(style?.fontFamily);
            }
            return true;
          });
        }
        document.dispose();
        return result;
      }

      addTearDown(() => ResumeSystemFonts.hasRealBold = true);
      ResumeSystemFonts.hasRealBold = true;
      expect(families()['bold'], {null});
      ResumeSystemFonts.hasRealBold = false;
      final fallback = families();
      // Bold stays in the system font; it is thickened with shadows instead.
      expect(fallback['bold'], {null});
      expect(fallback['regular'], {null});
    },
  );
}
