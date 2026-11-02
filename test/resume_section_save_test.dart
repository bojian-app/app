import 'dart:async';

import 'package:bojian_mobile/api/bojian_api.dart';
import 'package:bojian_mobile/app_store.dart';
import 'package:bojian_mobile/design.dart';
import 'package:bojian_mobile/resume_pages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';
import 'support/resume_editor_helpers.dart';

class DelayedResumeGateway extends FakeGateway {
  final gate = Completer<void>();
  int creates = 0;

  @override
  Future<ApiDocument> call(
    String method, {
    Map<String, String> path = const {},
    Map<String, String> query = const {},
    Map<String, dynamic>? body,
    Map<String, String> headers = const {},
  }) async {
    if (method == 'PostResumes') {
      creates++;
      await gate.future;
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

void main() {
  Future<void> openEditor(WidgetTester tester, FakeGateway api) async {
    final store = await testStore(authenticated: true, api: api);
    addTearDown(store.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: ResumeEditor(
          store: store,
          draft: ResumeDraft(id: 0, title: '保存测试'),
        ),
      ),
    );
    expect(find.byKey(const ValueKey('resume-editor-save')), findsNothing);
  }

  testWidgets('Failed section save keeps input and can retry successfully', (
    tester,
  ) async {
    final api = FakeGateway()..failing = 'PostResumes';
    await openEditor(tester, api);
    await openResumeSection(tester, 0);
    final name = find.byKey(const ValueKey('resume-name'));
    await tester.enterText(name, '保留输入');
    await saveResumeSection(tester);
    expect(find.byKey(const ValueKey('resume-section-save')), findsOneWidget);
    expect(tester.widget<TextFormField>(name).controller!.text, '保留输入');
    expect(find.text('服务器暂不可用'), findsOneWidget);
    api.failing = null;
    await saveResumeSection(tester);
    expect(find.byKey(const ValueKey('resume-section-save')), findsNothing);
    expect(find.text('保留输入'), findsOneWidget);
    expect(
      api.lastMutationBody!['content']['personal_info']['full_name'],
      '保留输入',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Pending save blocks duplicate requests and back; next save updates same resume',
    (tester) async {
      final api = DelayedResumeGateway();
      await openEditor(tester, api);
      await openResumeSection(tester, 0);
      await tester.enterText(find.byKey(const ValueKey('resume-name')), '测试姓名');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      final save = find.byKey(const ValueKey('resume-section-save'));
      await tester.tap(save);
      await tester.pump();
      await tester.tap(save);
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(api.creates, 1);
      expect(find.text('保存中…'), findsOneWidget);
      api.gate.complete();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('resume-section-save')), findsNothing);
      await openResumeSection(tester, 2);
      await tester.enterText(
        find.byKey(const ValueKey('resume-summary')),
        '补充简介',
      );
      await saveResumeSection(tester);
      expect(api.creates, 1);
      expect(api.calls.where((c) => c == 'PatchResumesId'), hasLength(1));
      expect(
        api.lastMutationBody!['content']['job_expectation']['preference'],
        '补充简介',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Work capsule close cancels new entry and empty menu has no delete',
    (tester) async {
      final api = FakeGateway();
      await openEditor(tester, api);
      await openResumeSection(tester, 3);
      expect(
        find.byKey(const ValueKey('resume-actions-capsule')),
        findsOneWidget,
      );
      expect(find.text('添加工作经历'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('resume-more')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('work-action-delete')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('work-action-add')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('resume-work-0-company')),
        '未保存公司',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('resume-close')));
      await tester.pumpAndSettle();
      await openResumeSection(tester, 3);
      expect(find.byKey(const ValueKey('resume-work-0-company')), findsNothing);
      expect(api.calls, isNot(contains('PostResumes')));
      expect(tester.takeException(), isNull);
    },
  );
}
