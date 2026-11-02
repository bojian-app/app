import 'dart:async';

import 'package:bojian_mobile/api/bojian_api.dart';
import 'package:bojian_mobile/app_store.dart';
import 'package:bojian_mobile/resume_ai_optimization_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

class DelayedPollGateway extends FakeGateway {
  int polls = 0;
  late final pending = Completer<ApiDocument>();
  @override
  Future<ApiDocument> call(
    String method, {
    Map<String, String> path = const {},
    Map<String, String> query = const {},
    Map<String, dynamic>? body,
    Map<String, String> headers = const {},
  }) {
    if (method == 'GetPolishJobsId' && ++polls == 2) return pending.future;
    return super.call(
      method,
      path: path,
      query: query,
      body: body,
      headers: headers,
    );
  }
}

Map<String, dynamic> result() => {
  'status': 'WAITING_CONFIRMATION',
  'comparisons': {
    'summary': '优化表达',
    'changes': [
      {
        'path': 'projects.0.description',
        'before': '负责开发网站',
        'after': '负责网站开发',
        'reason': '表达清楚',
      },
      {
        'path': 'skills.0.description',
        'before': '使用 Vue 开发',
        'after': '使用 Vue 进行开发',
        'reason': '梳理表达',
      },
    ],
    'issues': [
      {
        'path': 'projects.0.end_date',
        'message': '结束时间为空',
        'question': '项目是否还在进行？',
      },
    ],
  },
};
Future<void> open(WidgetTester tester, AppStore store) async {
  await tester.pumpWidget(
    MaterialApp(
      home: ResumeAIOptimizationPage(
        store: store,
        resume: ResumeDraft(id: 42, title: '简历'),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'Diagnosis is shown first and reanalysis replaces only the pending task',
    (tester) async {
      final api = FakeGateway()
        ..documents['GetResumesIdPolishJobs'] = {'id': 12}
        ..documents['GetPolishJobsId'] = result();
      final store = await testStore(authenticated: true, api: api);
      addTearDown(store.dispose);
      await open(tester, store);
      expect(find.text('内容诊断'), findsOneWidget);
      expect(find.text('需要核对的内容问题'), findsOneWidget);
      api.documents['GetResumesIdPolishJobs'] = {'id': null};
      api.documents['PostResumesIdPolishJobs'] = {'id': 13, 'status': 'QUEUED'};
      final button = find.byKey(const ValueKey('resume-ai-reanalyze'));
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(
        api.calls.where((v) => v == 'PostPolishJobsIdDiscard'),
        hasLength(1),
      );
      expect(
        api.calls.where((v) => v == 'PostResumesIdPolishJobs'),
        hasLength(1),
      );
      expect(api.calls, isNot(contains('PostPolishJobsIdApply')));
    },
  );

  testWidgets(
    'Entering starts optimization once with server defaults and no form',
    (tester) async {
      final api = FakeGateway()
        ..documents['GetResumesIdPolishJobs'] = {'id': null}
        ..documents['PostResumesIdPolishJobs'] = {'id': 12, 'status': 'QUEUED'}
        ..documents['GetPolishJobsId'] = result();
      final store = await testStore(authenticated: true, api: api);
      addTearDown(store.dispose);
      await open(tester, store);
      expect(find.byType(TextField), findsNothing);
      expect(find.text('开始优化'), findsNothing);
      expect(
        api.calls.where((v) => v == 'PostResumesIdPolishJobs'),
        hasLength(1),
      );
      expect(api.lastMutationBody, isEmpty);
      store.changed();
      await tester.pumpAndSettle();
      expect(
        api.calls.where((v) => v == 'PostResumesIdPolishJobs'),
        hasLength(1),
      );
      expect(find.byKey(const ValueKey('resume-ai-apply')), findsOneWidget);
    },
  );

  testWidgets(
    'Failed task lookup waits for retry instead of blindly creating a task',
    (tester) async {
      final api = FakeGateway()..failing = 'GetResumesIdPolishJobs';
      final store = await testStore(authenticated: true, api: api);
      addTearDown(store.dispose);
      await open(tester, store);
      expect(api.calls, isNot(contains('PostResumesIdPolishJobs')));
      expect(find.byType(TextField), findsNothing);
      api.failing = null;
      api.documents['GetResumesIdPolishJobs'] = {'id': null};
      api.documents['PostResumesIdPolishJobs'] = {'id': 12, 'status': 'QUEUED'};
      api.documents['GetPolishJobsId'] = result();
      await tester.tap(find.byKey(const ValueKey('resume-ai-retry')));
      await tester.pumpAndSettle();
      expect(
        api.calls.where((v) => v == 'PostResumesIdPolishJobs'),
        hasLength(1),
      );
    },
  );

  testWidgets('Canceled task ignores a late running poll and stops polling', (
    tester,
  ) async {
    final api = DelayedPollGateway()
      ..documents['GetResumesIdPolishJobs'] = {'id': 12}
      ..documents['GetPolishJobsId'] = {'status': 'RUNNING'};
    final store = await testStore(authenticated: true, api: api);
    addTearDown(store.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: ResumeAIOptimizationPage(
          store: store,
          resume: ResumeDraft(id: 42, title: '简历'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 3));
    expect(api.polls, 2);
    await tester.tap(find.text('取消本次优化'));
    await tester.pump();
    api.pending.complete(ApiDocument(result()));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 10));
    expect(api.polls, 2);
    expect(find.byKey(const ValueKey('resume-ai-apply')), findsNothing);
    expect(api.calls, isNot(contains('PostPolishJobsIdApply')));
  });

  testWidgets(
    'Restores result, saves only checked changes and preserves choices after failure',
    (tester) async {
      final api = FakeGateway()
        ..documents['GetResumesId'] = {'id': 42, 'revision': 4, 'content': {}}
        ..documents['GetResumesIdPolishJobs'] = {'id': 12}
        ..documents['GetPolishJobsId'] = result();
      final store = await testStore(authenticated: true, api: api);
      addTearDown(store.dispose);
      await open(tester, store);
      expect(api.calls, isNot(contains('PostResumesIdPolishJobs')));
      final checkbox = find.byKey(
        const ValueKey('resume-ai-change-projects.0.description'),
      );
      await tester.scrollUntilVisible(
        checkbox,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await Scrollable.ensureVisible(tester.element(checkbox), alignment: 0.2);
      await tester.pumpAndSettle();
      await tester.tap(checkbox);
      await tester.pumpAndSettle();
      expect(find.text('采纳并保存 1 项'), findsOneWidget);
      api.failing = 'PostPolishJobsIdApply';
      await tester.tap(find.byKey(const ValueKey('resume-ai-apply')));
      await tester.pumpAndSettle();
      expect(find.text('采纳并保存 1 项'), findsOneWidget);
      api.failing = null;
      await tester.tap(find.byKey(const ValueKey('resume-ai-apply')));
      await tester.pumpAndSettle();
      expect(api.lastMutationBody!['decisions'], {
        'projects.0.description': false,
        'skills.0.description': true,
      });
      await tester.drag(find.byType(ListView), const Offset(0, 1600));
      await tester.pumpAndSettle();
      expect(find.text('已保存采纳的建议'), findsOneWidget);
    },
  );
  testWidgets('Account switch prevents adoption', (tester) async {
    final api = FakeGateway()
      ..documents['GetResumesIdPolishJobs'] = {'id': 12}
      ..documents['GetPolishJobsId'] = result();
    final store = await testStore(authenticated: true, api: api);
    addTearDown(store.dispose);
    await open(tester, store);
    await store.endSession(remote: false);
    await tester.pumpAndSettle();
    expect(find.text('账号已切换，请返回后重新进入'), findsOneWidget);
    expect(find.byKey(const ValueKey('resume-ai-apply')), findsNothing);
    expect(api.calls, isNot(contains('PostPolishJobsIdApply')));
  });
  testWidgets('Issues-only result never offers to overwrite the resume', (
    tester,
  ) async {
    final data = result();
    (data['comparisons'] as Map)['changes'] = [];
    final api = FakeGateway()
      ..documents['GetResumesIdPolishJobs'] = {'id': 12}
      ..documents['GetPolishJobsId'] = data;
    final store = await testStore(authenticated: true, api: api);
    addTearDown(store.dispose);
    await open(tester, store);
    expect(find.byKey(const ValueKey('resume-ai-apply')), findsNothing);
    expect(find.text('请先核对下方问题，信息不足的部分没有自动改写。'), findsOneWidget);
    final discard = find.text('放弃本次结果');
    await tester.ensureVisible(discard);
    await tester.tap(discard);
    await tester.pumpAndSettle();
    expect(api.calls, contains('PostPolishJobsIdDiscard'));
    expect(api.calls, isNot(contains('PostPolishJobsIdApply')));
  });
}
