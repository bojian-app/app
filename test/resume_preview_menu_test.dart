import 'package:bojian_mobile/app_store.dart';
import 'package:bojian_mobile/resume_pages.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

Future<void> openPreview(WidgetTester tester, AppStore store) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => ResumePreview(store: store, resumeId: 42),
              ),
            ),
            child: const Text('简历列表'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('简历列表'));
  await tester.pumpAndSettle();
}

Future<void> action(WidgetTester tester, String name) async {
  if (name == 'copy') {
    await tester.tap(find.byKey(const ValueKey('resume-toolbar-copy')));
  } else if (name == 'switch') {
    await tester.tap(find.byKey(const ValueKey('resume-toolbar-switch')));
  } else {
    await tester.tap(find.byKey(const ValueKey('resume-more')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('resume-action-$name')));
  }
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'Copy opens independent resume and preserves original; failure stays',
    (tester) async {
      final api = FakeGateway();
      api.documents['PostResumesIdCopies'] = {
        'id': 43,
        'revision': 1,
        'title': '原简历 副本',
        'content': {
          'personal_info': {'full_name': '测试姓名'},
        },
      };
      final store = await testStore(authenticated: true, api: api);
      addTearDown(store.dispose);
      final original = ResumeDraft(id: 42, title: '原简历');
      store.resumes.add(original);
      await openPreview(tester, store);
      api.failing = 'PostResumesIdCopies';
      await action(tester, 'copy');
      expect(store.resumes.single, same(original));
      expect(
        tester.widget<ResumePreview>(find.byType(ResumePreview)).resumeId,
        42,
      );
      api.failing = null;
      await action(tester, 'copy');
      expect(store.resumes.length, 2);
      expect(store.resumes.last, same(original));
      expect(
        tester.widget<ResumePreview>(find.byType(ResumePreview)).resumeId,
        43,
      );
      expect(store.resumes.first.name, '测试姓名');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Switching keeps current selection and deletes only the newly selected resume',
    (tester) async {
      final api = FakeGateway();
      final store = await testStore(authenticated: true, api: api);
      addTearDown(store.dispose);
      store.resumes.addAll([
        ResumeDraft(id: 42, title: '护士简历'),
        ResumeDraft(id: 43, title: '另一份简历'),
      ]);
      await openPreview(tester, store);
      await action(tester, 'switch');
      expect(find.text('当前简历'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('resume-switch-42')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<ResumePreview>(find.byType(ResumePreview)).resumeId,
        42,
      );
      await action(tester, 'switch');
      await tester.tap(find.byKey(const ValueKey('resume-switch-43')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<ResumePreview>(find.byType(ResumePreview)).resumeId,
        43,
      );
      expect(find.text('另一份简历'), findsOneWidget);
      await action(tester, 'delete');
      expect(find.text('“另一份简历”将从简历库移除。'), findsOneWidget);
      await tester.tap(find.widgetWithText(CupertinoDialogAction, '删除'));
      await tester.pumpAndSettle();
      expect(store.resumes.single.id, 42);
      expect(find.byType(ResumePreview), findsNothing);
      expect(find.text('简历列表'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Menu cancel and switching then closing preserve navigation depth',
    (tester) async {
      final store = await testStore(authenticated: true);
      addTearDown(store.dispose);
      store.resumes.addAll([
        ResumeDraft(id: 42, title: '护士简历'),
        ResumeDraft(id: 43, title: '另一份简历'),
      ]);
      await openPreview(tester, store);
      await tester.tap(find.byKey(const ValueKey('resume-more')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('resume-menu-cancel')));
      await tester.pumpAndSettle();
      expect(find.byType(ResumePreview), findsOneWidget);
      await action(tester, 'switch');
      await tester.tap(find.byKey(const ValueKey('resume-switch-43')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('resume-close')));
      await tester.pumpAndSettle();
      expect(find.byType(ResumePreview), findsNothing);
      expect(find.text('简历列表'), findsOneWidget);
      expect(store.resumes.length, 2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Power action returns without mutating or logging out', (
    tester,
  ) async {
    final api = FakeGateway();
    final store = await testStore(authenticated: true, api: api);
    addTearDown(store.dispose);
    store.resumes.add(ResumeDraft(id: 42, title: '护士简历'));
    await openPreview(tester, store);
    await tester.tap(find.byKey(const ValueKey('resume-close')));
    await tester.pumpAndSettle();
    expect(find.byType(ResumePreview), findsNothing);
    expect(store.resumes.single.id, 42);
    expect(store.isAuthenticated, isTrue);
    expect(api.calls, isNot(contains('DeleteResumesId')));
  });

  testWidgets(
    'Rename validates, preserves failure, then updates preview title',
    (tester) async {
      final api = FakeGateway();
      api.documents['GetResumesId'] = {
        'id': 42,
        'revision': 3,
        'title': '护士简历',
      };
      final store = await testStore(authenticated: true, api: api);
      addTearDown(store.dispose);
      store.resumes.add(ResumeDraft(id: 42, title: '护士简历'));
      await openPreview(tester, store);
      await action(tester, 'rename');
      final input = find.byKey(const ValueKey('resume-rename-dialog-input'));
      await tester.enterText(input, ' ');
      await tester.tap(find.widgetWithText(CupertinoDialogAction, '保存'));
      await tester.pumpAndSettle();
      expect(api.calls, isNot(contains('PatchResumesId')));
      await tester.enterText(input, '新的护士简历');
      api.failing = 'PatchResumesId';
      await tester.tap(find.widgetWithText(CupertinoDialogAction, '保存'));
      await tester.pumpAndSettle();
      expect(find.text('服务器暂不可用'), findsOneWidget);
      expect(store.resumes.single.title, '护士简历');
      api.failing = null;
      await tester.tap(find.widgetWithText(CupertinoDialogAction, '保存'));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoAlertDialog), findsNothing);
      expect(store.resumes.single.title, '新的护士简历');
      expect(find.text('新的护士简历'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Delete cancel and failure stay in preview; success returns to list',
    (tester) async {
      final api = FakeGateway();
      final store = await testStore(authenticated: true, api: api);
      addTearDown(store.dispose);
      store.resumes.addAll([
        ResumeDraft(id: 42, title: '护士简历'),
        ResumeDraft(id: 43, title: '保留简历'),
      ]);
      await openPreview(tester, store);
      await action(tester, 'delete');
      await tester.tap(find.widgetWithText(CupertinoDialogAction, '取消'));
      await tester.pumpAndSettle();
      expect(api.calls, isNot(contains('DeleteResumesId')));
      expect(find.byType(ResumePreview), findsOneWidget);
      await action(tester, 'delete');
      api.failing = 'DeleteResumesId';
      await tester.tap(find.widgetWithText(CupertinoDialogAction, '删除'));
      await tester.pumpAndSettle();
      expect(store.resumes.length, 2);
      expect(find.text('服务器暂不可用'), findsOneWidget);
      api.failing = null;
      await tester.tap(find.widgetWithText(CupertinoDialogAction, '删除'));
      await tester.pumpAndSettle();
      expect(find.byType(ResumePreview), findsNothing);
      expect(store.resumes.single.id, 43);
      expect(tester.takeException(), isNull);
    },
  );
}
