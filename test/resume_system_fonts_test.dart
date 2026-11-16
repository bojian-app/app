import 'package:bojian_mobile/app_store.dart';
import 'package:bojian_mobile/resume_document.dart';
import 'package:bojian_mobile/resume_native_export.dart';
import 'package:bojian_mobile/resume_system_fonts.dart';
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
    'cached preview and thumbnail rebuild with device fonts without changing resume data',
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
      expect(fallback['bold'], {resumeDocumentFontFamily});
      expect(fallback['regular'], {null});
    },
  );
}
