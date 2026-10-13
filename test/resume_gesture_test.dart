import 'package:bojian_mobile/app_store.dart';
import 'package:bojian_mobile/design.dart';
import 'package:bojian_mobile/resume_document.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> mountDocument(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: appTheme,
      home: Scaffold(
        body: ResumeDocumentView(
          resume: ResumeDraft(
            id: 0,
            title: '简历',
            source: {
              'work_experiences': [
                {
                  'company': '公司',
                  'description': List.generate(
                    120,
                    (i) => '正文$i：负责前端研发，并优化页面交互体验与渲染性能。',
                  ).join('\n'),
                },
              ],
            },
          ),
          onAnnotate: (_, text, replace) {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder get bodyText => find
    .byWidgetPredicate(
      (widget) =>
          widget is Semantics &&
          (widget.properties.label ?? '').startsWith('选中区域：正文'),
    )
    .first;
Future<void> pinch(
  WidgetTester tester,
  Offset point, {
  bool delayedSecond = false,
}) async {
  final left = await tester.startGesture(point, pointer: 1);
  if (delayedSecond) {
    await left.moveBy(const Offset(0, -28));
    await tester.pump(const Duration(milliseconds: 30));
    point -= const Offset(0, 28);
  }
  final right = await tester.startGesture(
    point + const Offset(60, 0),
    pointer: 2,
  );
  await tester.pump();
  await left.moveBy(const Offset(-30, 0));
  await right.moveBy(const Offset(30, 0));
  await tester.pump();
  await left.moveBy(const Offset(-30, 0));
  await right.moveBy(const Offset(30, 0));
  await tester.pump();
  await left.up();
  await right.up();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'Single finger scrolls on tappable body; pinch still works after first finger starts scrolling',
    (tester) async {
      await mountDocument(tester);
      final state = tester.state<ResumeDocumentViewState>(
        find.byType(ResumeDocumentView),
      );
      final point = tester.getTopLeft(bodyText) + const Offset(30, 12);
      final finger = await tester.startGesture(point);
      await finger.moveBy(const Offset(0, -40));
      await tester.pump();
      await finger.moveBy(const Offset(0, -40));
      await tester.pump();
      await finger.up();
      await tester.pumpAndSettle();
      expect(state.pageScroll.offset, greaterThan(20));
      expect(state.selectedRegion, isNull);
      expect(find.byKey(const ValueKey('resume-region-actions')), findsNothing);
      state.pageScroll.jumpTo(0);
      await tester.pumpAndSettle();
      await pinch(tester, point, delayedSecond: true);
      expect(state.transform.value.getMaxScaleOnAxis(), greaterThan(2));
      final center = tester.getCenter(
        find.byKey(const ValueKey('resume-gesture-viewport')),
      );
      final first = await tester.startGesture(
        center - const Offset(80, 0),
        pointer: 3,
      );
      final second = await tester.startGesture(
        center + const Offset(80, 0),
        pointer: 4,
      );
      await tester.pump();
      await first.moveBy(const Offset(60, 0));
      await second.moveBy(const Offset(-60, 0));
      await tester.pump();
      await first.up();
      await second.up();
      await tester.pumpAndSettle();
      expect(state.transform.value.getMaxScaleOnAxis(), 1);
      final before = state.pageScroll.offset;
      await tester.dragFrom(point, const Offset(0, -150));
      await tester.pumpAndSettle();
      expect(state.pageScroll.offset, greaterThan(before));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Zoomed one-finger panning continues into later pages; tap still selects an annotation region',
    (tester) async {
      await mountDocument(tester);
      final state = tester.state<ResumeDocumentViewState>(
        find.byType(ResumeDocumentView),
      );
      final point = tester.getTopLeft(bodyText) + const Offset(30, 12);
      await pinch(tester, point);
      final box = tester.getRect(
        find.byKey(const ValueKey('resume-gesture-viewport')),
      );
      for (var i = 0; i < 4; i++) {
        final finger = await tester.startGesture(box.center);
        await finger.moveBy(const Offset(0, -200));
        await tester.pump(const Duration(milliseconds: 400));
        await finger.up();
        await tester.pumpAndSettle();
      }
      expect(state.pageScroll.offset, greaterThan(0));
      state.resetZoom();
      state.pageScroll.jumpTo(0);
      await tester.pumpAndSettle();
      await tester.tapAt(point);
      await tester.pumpAndSettle();
      expect(state.selectedRegion, isNotNull);
      expect(find.byType(Dialog), findsNothing);
      expect(state.selectedRegion!.text.text!.toPlainText(), contains('正文119'));
      expect(find.byType(SelectableText), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
