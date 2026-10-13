import 'dart:async';

import 'package:bojian_mobile/api/bojian_api.dart';
import 'package:bojian_mobile/app_store.dart';
import 'package:bojian_mobile/resume_pages.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

class DeleteGateway extends FakeGateway {
  Map<String, String>? deletedPath;
  Completer<ApiDocument>? pending;
  @override
  Future<ApiDocument> call(
    String method, {
    Map<String, String> path = const {},
    Map<String, String> query = const {},
    Map<String, dynamic>? body,
    Map<String, String> headers = const {},
  }) {
    if (method == 'DeleteResumesId') {
      deletedPath = path;
      if (pending != null) {
        calls.add(method);
        return pending!.future;
      }
    }
    return super.call(
      method,
      path: path,
      query: query,
      body: body,
      headers: headers,
    );
  }
}

Future<void> showLibrary(WidgetTester tester, AppStore store) async {
  await tester.pumpWidget(
    MaterialApp(
      home: AnimatedBuilder(
        animation: store,
        builder: (_, _) => Scaffold(body: ResumeLibrary(store: store)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'Delete requires confirmation, preserves failed cards and removes only the chosen resume',
    (tester) async {
      final api = DeleteGateway();
      final store = await testStore(authenticated: true, api: api);
      addTearDown(store.dispose);
      store.resumes.addAll([
        ResumeDraft(id: 42, title: '待删除简历'),
        ResumeDraft(id: 43, title: '保留简历'),
      ]);
      await showLibrary(tester, store);
      final target = find.byKey(const ValueKey('resume-delete-42'));
      await tester.ensureVisible(target);
      await tester.tap(target);
      await tester.pumpAndSettle();
      expect(find.text('“待删除简历”将从简历库移除。'), findsOneWidget);
      expect(find.byType(ResumePreview), findsNothing);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(api.calls, isNot(contains('DeleteResumesId')));
      await tester.tap(target);
      await tester.pumpAndSettle();
      api.failing = 'DeleteResumesId';
      await tester.tap(find.widgetWithText(CupertinoDialogAction, '删除'));
      await tester.pumpAndSettle();
      expect(store.resumes.map((r) => r.id), [42, 43]);
      expect(find.text('服务器暂不可用'), findsOneWidget);
      expect(find.byType(CupertinoAlertDialog), findsOneWidget);
      api.failing = null;
      await tester.tap(find.widgetWithText(CupertinoDialogAction, '删除'));
      await tester.pumpAndSettle();
      expect(api.deletedPath, {'id': '42'});
      expect(store.resumes.map((r) => r.id), [43]);
      expect(find.text('待删除简历'), findsNothing);
      expect(find.text('1 份'), findsOneWidget);
      expect(find.byType(CupertinoAlertDialog), findsNothing);
    },
  );

  testWidgets(
    'Pending deletion cannot be submitted twice and deleting the last resume shows empty state',
    (tester) async {
      final api = DeleteGateway();
      final store = await testStore(authenticated: true, api: api);
      addTearDown(store.dispose);
      store.resumes.add(ResumeDraft(id: 42, title: '最后一份'));
      await showLibrary(tester, store);
      final target = find.byKey(const ValueKey('resume-delete-42'));
      await tester.ensureVisible(target);
      await tester.tap(target);
      await tester.pumpAndSettle();
      api.pending = Completer<ApiDocument>();
      await tester.tap(find.widgetWithText(CupertinoDialogAction, '删除'));
      await tester.pump();
      await tester.tap(find.text('删除中…'));
      await tester.pump();
      expect(
        api.calls.where((method) => method == 'DeleteResumesId'),
        hasLength(1),
      );
      expect(store.resumes, hasLength(1));
      api.pending!.complete(ApiDocument({}));
      await tester.pumpAndSettle();
      expect(store.resumes, isEmpty);
      expect(find.text('0 份'), findsOneWidget);
      expect(find.text('创建你的第一份简历'), findsOneWidget);
    },
  );

  test(
    'A late deletion response cannot remove another account’s local resume',
    () async {
      final api = DeleteGateway();
      final store = await testStore(authenticated: true, api: api);
      addTearDown(store.dispose);
      api.pending = Completer<ApiDocument>();
      final deleting = store.deleteResume(42);
      store.epoch++;
      store.resumes.add(ResumeDraft(id: 42, title: '新账号数据'));
      api.pending!.complete(ApiDocument({}));
      await deleting;
      expect(store.resumes.single.title, '新账号数据');
    },
  );
}
