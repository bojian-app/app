import 'package:bojian_mobile/app_store.dart';
import 'package:bojian_mobile/resume_pages.dart';
import 'package:bojian_mobile/resume_rename.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

void main() {
  testWidgets('Losing focus closes all rename controls without saving', (
    tester,
  ) async {
    final api = FakeGateway();
    final store = await testStore(authenticated: true, api: api);
    addTearDown(store.dispose);
    final resume = ResumeDraft(id: 42, title: '原名称');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              ResumeInlineName(store: store, resume: resume),
              const TextField(key: ValueKey('other-input')),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.text('原名称'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('resume-rename-input')),
      '未保存',
    );
    await tester.tap(find.byKey(const ValueKey('other-input')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('resume-rename-input')), findsNothing);
    expect(find.byTooltip('保存名称'), findsNothing);
    expect(find.byTooltip('取消改名'), findsNothing);
    expect(find.text('原名称'), findsOneWidget);
    expect(api.calls, isNot(contains('PatchResumesId')));
  });

  testWidgets(
    'Rename rejects blank names, preserves input on failure and patches only title with latest revision',
    (tester) async {
      final api = FakeGateway();
      api.documents['GetResumesId'] = {
        'id': 42,
        'revision': 7,
        'title': '旧名称',
        'content': {
          'personal_info': {'full_name': '测试'},
        },
      };
      final store = await testStore(authenticated: true, api: api);
      addTearDown(store.dispose);
      final resume = ResumeDraft(id: 42, title: '旧名称');
      store.resumes.add(resume);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ResumeLibrary(store: store)),
        ),
      );
      await tester.ensureVisible(find.byKey(const ValueKey('resume-arrow-42')));
      await tester.tap(find.byKey(const ValueKey('resume-arrow-42')));
      await tester.pumpAndSettle();
      expect(find.byType(ResumeEditor), findsNothing);
      expect(find.byType(ResumePreview), findsNothing);
      await tester.tap(find.text('旧名称'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '  ');
      await tester.tap(find.byTooltip('保存名称'));
      await tester.pumpAndSettle();
      expect(find.text('请输入 1–160 个字的简历名称'), findsOneWidget);
      expect(api.calls, isNot(contains('PatchResumesId')));
      api.failing = 'PatchResumesId';
      await tester.enterText(find.byType(TextField), ' 新名称 ');
      await tester.tap(find.byTooltip('保存名称'));
      await tester.pumpAndSettle();
      expect(find.text('服务器暂不可用'), findsOneWidget);
      expect(find.widgetWithText(TextField, ' 新名称 '), findsOneWidget);
      expect(store.resumes.last.title, '旧名称');
      api.failing = null;
      await tester.tap(find.byTooltip('保存名称'));
      await tester.pumpAndSettle();
      expect(api.lastBody, {'title': '新名称'});
      expect(api.lastHeaders?['if-match'], '"revision-7"');
      expect(store.resumes.last.title, '新名称');
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('新名称'), findsOneWidget);
      await tester.tap(find.text('新名称'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '不保存的名称');
      await tester.tap(find.byTooltip('取消改名'));
      await tester.pumpAndSettle();
      expect(find.text('新名称'), findsOneWidget);
      expect(store.resumes.last.title, '新名称');
    },
  );
}
