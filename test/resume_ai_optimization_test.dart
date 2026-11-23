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
    'diagnosis': {
      'score': 7,
      'overall': '项目职责清楚，但成果缺少依据',
      'problems': ['各项目重复通用流程职责', '两段任职之间相隔约 3 个月'],
    },
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
        'type': 'missing_information',
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
        resume: ResumeDraft(
          id: 42,
          title: '简历',
          source: {
            'projects': [
              {'name': '平台'},
            ],
          },
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> tapKey(WidgetTester tester, String key) async {
  final target = find.byKey(ValueKey(key));
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

final list = find
    .descendant(
      of: find.byKey(const ValueKey('resume-ai-list')),
      matching: find.byType(Scrollable),
    )
    .first;

void main() {
  testWidgets(
    'Result shows diagnosis, reasons, issues and supports reanalysis',
    (tester) async {
      final api = FakeGateway()
        ..documents['GetResumesIdPolishJobs'] = {'id': 12}
        ..documents['GetPolishJobsId'] = result();
      final store = await testStore(authenticated: true, api: api);
      addTearDown(store.dispose);
      await open(tester, store);
      expect(find.text('诊断结论'), findsOneWidget);
      expect(find.text('项目职责清楚，但成果缺少依据'), findsOneWidget);
      expect(find.byKey(const ValueKey('resume-ai-score')), findsOneWidget);
      expect(find.text('主要问题'), findsOneWidget);
      expect(find.text('各项目重复通用流程职责'), findsOneWidget);
      expect(find.text('两段任职之间相隔约 3 个月'), findsOneWidget);
      expect(find.text('岗位匹配度'), findsNothing);
      // Only the diagnosis shows until an entry is opened.
      expect(find.text('平台 · 项目介绍'), findsNothing);
      expect(find.byKey(const ValueKey('resume-ai-apply')), findsNothing);
      await tapKey(tester, 'resume-ai-stat-issues');
      expect(find.text('待补充信息'), findsOneWidget);
      expect(find.text('AI 简历优化'), findsNothing);
      expect(find.text('项目是否还在进行？'), findsOneWidget);
      // The reasoning stays folded until asked for.
      expect(find.text('结束时间为空'), findsNothing);
      await tapKey(tester, 'resume-ai-why-projects.0.end_date');
      expect(find.text('结束时间为空'), findsOneWidget);
      expect(find.textContaining('AI'), findsNothing);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('AI 简历优化'), findsOneWidget);
      expect(find.text('项目职责清楚，但成果缺少依据'), findsOneWidget);
      api.documents['GetResumesIdPolishJobs'] = {'id': null};
      api.documents['PostResumesIdPolishJobs'] = {'id': 13, 'status': 'QUEUED'};
      final button = find.byKey(const ValueKey('resume-ai-reanalyze'));
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
      expect(
        find.byKey(const ValueKey('resume-ai-stat-changes')),
        findsOneWidget,
      );
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
      await tapKey(tester, 'resume-ai-stat-changes');
      expect(find.text('修改建议 1/2'), findsOneWidget);
      // Deciding on a suggestion turns to the next one.
      await tapKey(tester, 'resume-ai-ignore-projects.0.description');
      expect(find.text('修改建议 2/2'), findsOneWidget);
      expect(api.calls, contains('PutPolishJobsIdDecisions'));
      expect(api.lastMutationBody!['decisions'], {
        'projects.0.description': false,
        'skills.0.description': true,
      });
      await tapKey(tester, 'resume-ai-adopt-skills.0.description');
      expect(find.text('采纳 1 处，忽略 1 处'), findsOneWidget);
      api.failing = 'PostPolishJobsIdApply';
      await tester.tap(find.byKey(const ValueKey('resume-ai-apply')));
      await tester.pumpAndSettle();
      expect(find.text('服务器暂不可用'), findsOneWidget);
      expect(find.text('采纳 1 处，忽略 1 处'), findsOneWidget);
      api.failing = null;
      await tester.tap(find.byKey(const ValueKey('resume-ai-apply')));
      await tester.pumpAndSettle();
      expect(api.lastMutationBody!['decisions'], {
        'projects.0.description': false,
        'skills.0.description': true,
      });
      expect(find.text('已保存'), findsOneWidget);
      expect(find.text('已写入 1 项修改'), findsOneWidget);
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
    await tapKey(tester, 'resume-ai-stat-issues');
    final discard = find.text('放弃本次结果');
    await tester.ensureVisible(discard);
    await tester.pumpAndSettle();
    await tester.tap(discard);
    await tester.pumpAndSettle();
    expect(api.calls, contains('PostPolishJobsIdDiscard'));
    expect(api.calls, isNot(contains('PostPolishJobsIdApply')));
  });

  testWidgets('Long rewrites fold unchanged lines around the edit', (
    tester,
  ) async {
    final lines = [for (var i = 1; i <= 12; i++) '$i). 负责模块$i的开发与维护'];
    final before = lines.join('\n');
    final after = [...lines.take(11), '12). 负责支付模块重构并完成回调容错'].join('\n');
    final data = result();
    (data['comparisons'] as Map)['changes'] = [
      {
        'path': 'projects.0.achievements',
        'before': before,
        'after': after,
        'reason': '补充个人负责的模块',
      },
    ];
    final api = FakeGateway()
      ..documents['GetResumesIdPolishJobs'] = {'id': 12}
      ..documents['GetPolishJobsId'] = data;
    final store = await testStore(authenticated: true, api: api);
    addTearDown(store.dispose);
    await open(tester, store);
    await tapKey(tester, 'resume-ai-stat-changes');
    final fold = find.byKey(
      const ValueKey('resume-ai-fold-projects.0.achievements'),
    );
    expect(fold, findsOneWidget);
    expect(find.text('展开 10 行未改动内容'), findsOneWidget);
    await tester.ensureVisible(fold);
    await tester.pumpAndSettle();
    await tester.tap(fold);
    await tester.pumpAndSettle();
    expect(fold, findsNothing);
  });

  testWidgets('Change links to open issues on the same experience', (
    tester,
  ) async {
    final api = FakeGateway()
      ..documents['GetResumesIdPolishJobs'] = {'id': 12}
      ..documents['GetPolishJobsId'] = result();
    final store = await testStore(authenticated: true, api: api);
    addTearDown(store.dispose);
    await open(tester, store);
    await tapKey(tester, 'resume-ai-stat-changes');
    final link = find.byKey(
      const ValueKey('resume-ai-related-projects.0.description'),
    );
    expect(find.text('这段经历还有 1 处待核对'), findsOneWidget);
    await tester.ensureVisible(link);
    await tester.pumpAndSettle();
    await tester.tap(link);
    await tester.pumpAndSettle();
    expect(find.text('待补充信息'), findsOneWidget);
    expect(find.text('项目是否还在进行？').hitTestable(), findsOneWidget);
    final edit = find.byKey(
      const ValueKey('resume-ai-edit-projects.0.end_date'),
    );
    await tester.ensureVisible(edit);
    await tester.pumpAndSettle();
    await tester.tap(edit);
    await tester.pumpAndSettle();
    expect(find.text('先保存已采纳的修改？'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(api.calls, isNot(contains('PostPolishJobsIdApply')));
  });

  testWidgets('One decision turns exactly one page', (tester) async {
    final data = result();
    (data['comparisons'] as Map)['changes'] = [
      for (var i = 0; i < 4; i++)
        {
          'path': 'projects.$i.description',
          'before': '负责开发网站$i',
          'after': '负责网站开发$i',
          'reason': '原因$i',
        },
    ];
    final api = FakeGateway()
      ..documents['GetResumesIdPolishJobs'] = {'id': 12}
      ..documents['GetPolishJobsId'] = data;
    final store = await testStore(authenticated: true, api: api);
    addTearDown(store.dispose);
    await open(tester, store);
    await tapKey(tester, 'resume-ai-stat-changes');
    expect(find.text('修改建议 1/4'), findsOneWidget);
    await tapKey(tester, 'resume-ai-adopt-projects.0.description');
    expect(find.text('修改建议 2/4'), findsOneWidget);
    expect(find.textContaining('原因1', findRichText: true), findsOneWidget);
  });
  testWidgets('Placeholder rewrite is adopted only with the user\'s facts', (
    tester,
  ) async {
    final data = result();
    (data['comparisons'] as Map)['changes'] = [
      {
        'path': 'projects.0.description',
        'before': '负责开发网站',
        'after': '负责【待补充：模块名称】的开发，上线后【待补充：效果】',
        'reason': '职责空泛；补充对象与结果',
      },
    ];
    final api = FakeGateway()
      ..documents['GetResumesId'] = {'id': 42, 'revision': 4, 'content': {}}
      ..documents['GetResumesIdPolishJobs'] = {'id': 12}
      ..documents['GetPolishJobsId'] = data;
    final store = await testStore(authenticated: true, api: api);
    addTearDown(store.dispose);
    await open(tester, store);
    await tapKey(tester, 'resume-ai-stat-changes');
    expect(find.text('需补充 2 处'), findsOneWidget);
    expect(find.text('补充真实信息'), findsOneWidget);
    // Adopting with facts missing only moves focus to the first empty field.
    await tapKey(tester, 'resume-ai-adopt-projects.0.description');
    expect(find.text('需补充 2 处'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('resume-ai-fill-projects.0.description-0')),
      '会员中心',
    );
    await tester.pump();
    expect(find.text('需补充 1 处'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('resume-ai-fill-projects.0.description-1')),
      '注册转化提升',
    );
    await tester.pump();
    expect(find.text('已补充'), findsOneWidget);
    await tapKey(tester, 'resume-ai-adopt-projects.0.description');
    await tester.pumpAndSettle();
    expect(find.text('采纳 1 处，忽略 0 处'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('resume-ai-apply')));
    await tester.pumpAndSettle();
    expect(api.lastMutationBody!['filled'], {
      'projects.0.description': '负责会员中心的开发，上线后注册转化提升',
    });
  });
}
