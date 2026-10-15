import 'dart:async';
import 'dart:convert';

import 'package:bojian_mobile/api/bojian_api.dart';
import 'package:bojian_mobile/app_store.dart';
import 'package:bojian_mobile/resume_polish.dart';
import 'package:bojian_mobile/resume_polish_page.dart';
import 'package:bojian_mobile/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

Map<String, dynamic> clone(Map value) =>
    Map<String, dynamic>.from(jsonDecode(jsonEncode(value)) as Map);
Map<String, dynamic> original() => {
  'personal_info': {'full_name': '测试用户', 'phone': '13812345678'},
  'job_expectation': {'position': '产品经理', 'preference': '做过需求分析'},
  'work_experiences': [
    {
      'company': '测试公司',
      'position': '产品经理',
      'start_date': '2024-01',
      'description': '负责功能设计',
      'description_rich': richContent('负责功能设计'),
      'custom_flag': true,
    },
  ],
  'projects': [],
  'educations': [],
  'skills': [],
  'app_layout': 'market',
  'app_template_name': '测试模板',
  'unknown_metadata': {
    'keep': ['unchanged'],
  },
};
Map<String, dynamic> proposal() {
  final value = original();
  (value['job_expectation'] as Map)['preference'] = '具备需求分析经验';
  (value['work_experiences'] as List).first['description'] = '负责产品功能方案设计';
  return value;
}

class PolishGateway extends FakeGateway {
  Map<String, dynamic> resume = {
    'id': 42,
    'title': '我的简历',
    'revision': 9,
    'template_id': 31,
    'photo_file_id': 71,
    'photo_url': 'https://example.test/photo.png',
    'content': original(),
  };
  Map<String, dynamic> output = proposal();
  String status = 'WAITING_CONFIRMATION';
  int creates = 0, patches = 0, polls = 0;
  bool loseSaveResponse = false, failPoll = false, mutateAfterCreate = false;
  Map<String, String>? saveHeaders;
  @override
  Future<ApiDocument> call(
    String method, {
    Map<String, String> path = const {},
    Map<String, String> query = const {},
    Map<String, dynamic>? body,
    Map<String, String> headers = const {},
  }) async {
    if (method == 'GetResumesId') return ApiDocument(clone(resume));
    if (method == 'PostResumesIdPolishJobs') {
      creates++;
      if (mutateAfterCreate) resume['revision'] = 10;
      return ApiDocument({'id': 88, 'status': 'QUEUED'});
    }
    if (method == 'GetPolishJobsId') {
      polls++;
      if (failPoll) throw const ApiFailure('网络中断');
      return ApiDocument({
        'id': 88,
        'resume_id': 42,
        'status': status,
        'comparisons': clone(output),
      });
    }
    if (method == 'PostPolishJobsIdDiscard') {
      status = 'CANCELED';
      return ApiDocument({'id': 88, 'status': status});
    }
    if (method == 'PatchResumesId') {
      if (headers['if-match'] != '"revision-${resume['revision']}"') {
        throw const ApiFailure('简历已更新', code: 'REVISION_MISMATCH');
      }
      patches++;
      saveHeaders = headers;
      resume = {
        ...resume,
        'content': clone(body!['content'] as Map),
        'revision': (resume['revision'] as int) + 1,
      };
      if (loseSaveResponse) {
        loseSaveResponse = false;
        throw const ApiFailure('网络中断');
      }
      return ApiDocument(clone(resume));
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
  test(
    'Only narrative fields change; unselected rich text and metadata survive',
    () {
      final output = proposal();
      (output['personal_info'] as Map)['phone'] = 'bad';
      output['app_layout'] = 'standard';
      output.remove('unknown_metadata');
      final changes = resumePolishChanges(original(), output);
      expect(changes.length, 2);
      final content = applyResumePolishChanges(original(), changes, {
        'job_expectation.preference',
      });
      expect(content['personal_info'], original()['personal_info']);
      expect(content['work_experiences'], original()['work_experiences']);
      expect(content['app_layout'], 'market');
      expect(content['unknown_metadata'], original()['unknown_metadata']);
      final all = applyResumePolishChanges(
        original(),
        changes,
        changes.map((c) => c.path).toSet(),
      );
      expect(
        (all['work_experiences'] as List).first['description_rich'],
        isNull,
      );
      expect((all['work_experiences'] as List).first['custom_flag'], true);
      expect(
        (original()['work_experiences'] as List).first['description_rich'],
        isNotNull,
      );
    },
  );
  test('Rejects reordered or renamed entries, and never adds invented empty fields', () {
    final output = proposal();
    (output['work_experiences'] as List).first['company'] = '别的公司';
    expect(
      () => resumePolishChanges(original(), output),
      throwsA(isA<ApiFailure>()),
    );
    final blank = original();
    (blank['job_expectation'] as Map)['preference'] = '';
    final result = resumePolishChanges(blank, proposal());
    expect(result.any((c) => c.path == 'job_expectation.preference'), false);
  });
  test('Rich-only result is used when plain text is unchanged', () {
    final output = original();
    (output['work_experiences'] as List).first['description_rich'] =
        richContent('负责产品功能方案设计');
    final changes = resumePolishChanges(original(), output);
    expect(changes.single.after, '负责产品功能方案设计');
  });

  test('Creates a real job, saves selected fields with revision guard and preserves assets', () async {
    final api = PolishGateway();
    final store = await testStore(authenticated: true, api: api);
    final model = ResumePolishController(store, 42);
    addTearDown(() {
      model.dispose();
      store.dispose();
    });
    await model.start('精简表达');
    expect(model.error, isNull);
    expect(model.phase, ResumePolishPhase.review);
    expect(api.patches, 0);
    await model.select('work_experiences.0.description', false);
    await model.save();
    expect(model.phase, ResumePolishPhase.saved);
    expect(api.patches, 1);
    expect(api.saveHeaders!['if-match'], '"revision-9"');
    final saved = store.resumes.single;
    expect(saved.summary, '具备需求分析经验');
    expect(saved.source['work_experiences'], original()['work_experiences']);
    expect(saved.marketTemplateID, 31);
    expect(saved.photoFileID, 71);
    expect(saved.photoURL, 'https://example.test/photo.png');
  });
  test(
    'Reopening resumes the same job and its selection without regenerating',
    () async {
      final api = PolishGateway();
      final store = await testStore(authenticated: true, api: api);
      addTearDown(store.dispose);
      final first = ResumePolishController(store, 42);
      await first.start('精简');
      await first.select('work_experiences.0.description', false);
      first.dispose();
      final next = ResumePolishController(store, 42);
      addTearDown(next.dispose);
      await next.initialize();
      expect(next.phase, ResumePolishPhase.review);
      expect(next.selected, {'job_expectation.preference'});
      expect(api.creates, 1);
    },
  );
  test('Concurrent edits cannot be overwritten', () async {
    final api = PolishGateway();
    final store = await testStore(authenticated: true, api: api);
    final model = ResumePolishController(store, 42);
    addTearDown(() {
      model.dispose();
      store.dispose();
    });
    await model.start('');
    api.resume['revision'] = 10;
    await model.save();
    expect(model.conflict, true);
    expect(api.patches, 0);
    expect(model.error, contains('未被覆盖'));
  });
  test(
    'Changes during job creation are detected before showing proposals',
    () async {
      final api = PolishGateway()..mutateAfterCreate = true;
      final store = await testStore(authenticated: true, api: api);
      final model = ResumePolishController(store, 42);
      addTearDown(() {
        model.dispose();
        store.dispose();
      });
      await model.start('');
      expect(model.conflict, true);
      expect(api.polls, 0);
    },
  );
  test(
    'Lost save response is reconciled on reopening, not applied twice',
    () async {
      final api = PolishGateway()..loseSaveResponse = true;
      final store = await testStore(authenticated: true, api: api);
      addTearDown(store.dispose);
      final first = ResumePolishController(store, 42);
      await first.start('');
      await first.save();
      expect(first.error, isNotNull);
      first.dispose();
      final next = ResumePolishController(store, 42);
      addTearDown(next.dispose);
      await next.initialize();
      expect(next.phase, ResumePolishPhase.saved);
      expect(api.patches, 1);
    },
  );
  test(
    'Polling network failures retry the known job, never create another',
    () async {
      final api = PolishGateway()..failPoll = true;
      final store = await testStore(authenticated: true, api: api);
      final model = ResumePolishController(store, 42);
      addTearDown(() {
        model.dispose();
        store.dispose();
      });
      await model.start('');
      expect(model.jobID, 88);
      expect(model.error, '网络中断');
      api.failPoll = false;
      await model.refresh();
      expect(model.phase, ResumePolishPhase.review);
      expect(api.creates, 1);
    },
  );
  test(
    'A bounded running task remains recoverable and can be discarded',
    () async {
      final api = PolishGateway()..status = 'RUNNING';
      final store = await testStore(authenticated: true, api: api);
      final model = ResumePolishController(
        store,
        42,
        maxPolls: 1,
        wait: (_) async {},
      );
      addTearDown(() {
        model.dispose();
        store.dispose();
      });
      await model.start('');
      expect(model.error, contains('仍在处理中'));
      expect(model.jobID, 88);
      await model.discard();
      expect(model.phase, ResumePolishPhase.setup);
      expect(model.jobID, isNull);
      expect(api.status, 'CANCELED');
    },
  );
  test('Cancel during polling stops the remote task without saving', () async {
    final api = PolishGateway()..status = 'RUNNING';
    final store = await testStore(authenticated: true, api: api);
    final waiting = Completer<void>();
    final release = Completer<void>();
    final model = ResumePolishController(
      store,
      42,
      wait: (_) {
        waiting.complete();
        return release.future;
      },
    );
    addTearDown(() {
      model.dispose();
      store.dispose();
    });
    final running = model.start('');
    await waiting.future;
    await model.discard();
    expect(model.cancelRequested, true);
    release.complete();
    await running;
    expect(model.phase, ResumePolishPhase.setup);
    expect(api.status, 'CANCELED');
    expect(api.patches, 0);
  });

  test(
    'Failed and malformed jobs do not expose writable suggestions',
    () async {
      final api = PolishGateway()..status = 'FAILED';
      final store = await testStore(authenticated: true, api: api);
      final model = ResumePolishController(store, 42);
      addTearDown(() {
        model.dispose();
        store.dispose();
      });
      await model.start('');
      expect(model.error, contains('未完成'));
      expect(model.changes, isEmpty);
      api.status = 'WAITING_CONFIRMATION';
      api.output = {};
      await model.refresh();
      expect(model.error, contains('有效内容'));
      await model.save();
      expect(api.patches, 0);
    },
  );

  test('Discard reconciles a save whose response was lost', () async {
    final api = PolishGateway()..loseSaveResponse = true;
    final store = await testStore(authenticated: true, api: api);
    final model = ResumePolishController(store, 42);
    addTearDown(() {
      model.dispose();
      store.dispose();
    });
    await model.start('');
    await model.save();
    await model.discard();
    expect(model.phase, ResumePolishPhase.saved);
    expect(api.patches, 1);
  });

  test('No content to optimize does not consume an AI request', () async {
    final api = PolishGateway();
    api.resume['content'] = {
      'personal_info': {'full_name': '测试用户'},
    };
    final store = await testStore(authenticated: true, api: api);
    final model = ResumePolishController(store, 42);
    addTearDown(() {
      model.dispose();
      store.dispose();
    });
    await model.start('');
    expect(api.creates, 0);
    expect(model.error, contains('请先填写'));
  });
  test(
    'Changing account clears displayed content and prevents saves',
    () async {
      final api = PolishGateway();
      final store = await testStore(authenticated: true, api: api);
      final model = ResumePolishController(store, 42);
      addTearDown(() {
        model.dispose();
        store.dispose();
      });
      await model.start('');
      store.userID = 99;
      store.changed();
      expect(model.changes, isEmpty);
      expect(model.baseline, isNull);
      await model.save();
      expect(api.patches, 0);
    },
  );

  testWidgets(
    'Mobile flow shows comparisons, supports deselection, and saves',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = PolishGateway();
      final store = await testStore(authenticated: true, api: api);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: ResumePolishPage(
            store: store,
            resume: decodeResume(api.resume),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('polish-start')));
      await tester.pumpAndSettle();
      expect(find.text('逐项确认修改'), findsOneWidget);
      expect(api.patches, 0);
      final checkbox = find.byType(CheckboxListTile).first;
      await tester.tap(checkbox);
      await tester.pumpAndSettle();
      expect(find.text('保存 1 项修改'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('polish-save')));
      await tester.pumpAndSettle();
      expect(find.text('优化已保存'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    },
  );
}
