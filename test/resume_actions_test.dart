import 'package:bojian_mobile/app_store.dart';
import 'package:bojian_mobile/resume_pages.dart';
import 'package:bojian_mobile/resume_thumbnail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

void main() {
  testWidgets('Profile grid renders each resume on its own A4 page', (
    tester,
  ) async {
    final store = await testStore(authenticated: true);
    addTearDown(store.dispose);
    store.resumes
      ..clear()
      ..addAll([
        for (int id = 1; id <= 5; id++)
          ResumeDraft(id: id, title: '简历$id', name: '姓名$id', position: '岗位$id'),
      ]);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ResumeLibrary(store: store, embedded: true)),
      ),
    );
    await tester.pumpAndSettle();
    final pages = find.byType(ResumeSheetImage);
    expect(pages, findsNWidgets(5));
    for (var i = 0; i < 5; i++) {
      final page = tester.widget<ResumeSheetImage>(pages.at(i));
      expect(page.resume.name, '姓名${i + 1}');
      expect(page.resume.position, '岗位${i + 1}');
    }
    final first = tester.getTopLeft(pages.first);
    expect(tester.getTopLeft(pages.at(3)).dy, first.dy);
    expect(tester.getTopLeft(pages.at(4)).dy, greaterThan(first.dy));
  });

  testWidgets(
    'Every card area opens preview and actions are available in its bottom toolbar',
    (tester) async {
      final api = FakeGateway()
        ..documents['PostResumesIdCopies'] = {
          'id': 43,
          'title': '测试简历 副本',
          'content': <String, dynamic>{},
        };
      final store = await testStore(authenticated: true, api: api);
      addTearDown(store.dispose);
      store.resumes.add(ResumeDraft(id: 42, title: '测试简历'));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ResumeLibrary(store: store)),
        ),
      );
      await tester.pumpAndSettle();
      final card = find.byKey(const ValueKey('resume-card-42'));
      await tester.ensureVisible(card);
      final bounds = tester.getRect(card);
      for (final point in [
        tester.getCenter(find.text('测试简历')),
        tester.getCenter(find.byType(ResumeCardThumbnail)),
        bounds.bottomRight - const Offset(2, 20),
        bounds.topLeft + const Offset(20, 2),
      ]) {
        await tester.tapAt(point);
        await tester.pumpAndSettle();
        expect(find.byType(ResumePreview), findsOneWidget);
        expect(find.byTooltip('专注预览'), findsNothing);
        expect(find.textContaining('A4 · 共'), findsNothing);
        expect(find.textContaining('简历预览 ·'), findsNothing);
        await tester.pageBack();
        await tester.pumpAndSettle();
      }
      expect(find.byType(MenuAnchor), findsNothing);
      expect(find.text('删除'), findsNothing);
      expect(find.byTooltip('简历改名'), findsNothing);
      await tester.tap(card);
      await tester.pumpAndSettle();
      expect(
        tester.getCenter(find.text('切换简历')).dy,
        tester.getCenter(find.text('模板')).dy,
      );
      expect(find.text('AI 优化'), findsNothing);
      expect(find.text('分享'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('resume-toolbar-copy')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<ResumePreview>(find.byType(ResumePreview)).resumeId,
        43,
      );
      // 跳转到副本页后立即再点，应被共享锁拦截，不会生成副本的副本。
      await tester.tap(
        find.byKey(const ValueKey('resume-toolbar-copy')),
        warnIfMissed: false,
      );
      await tester.pump();
      expect(api.calls.where((c) => c == 'PostResumesIdCopies').length, 1);
      await tester.pump(const Duration(seconds: 2));
      expect(store.resumes.map((r) => r.id), containsAll([42, 43]));
      expect(tester.takeException(), isNull);
    },
  );
}
