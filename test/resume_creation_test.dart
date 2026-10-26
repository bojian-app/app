import 'dart:async';

import 'package:bojian_mobile/api/bojian_api.dart';
import 'package:bojian_mobile/design.dart';
import 'package:bojian_mobile/app_store.dart';
import 'package:bojian_mobile/resume_importer.dart';
import 'package:file_selector/file_selector.dart';
import 'package:bojian_mobile/messages_page.dart';
import 'package:bojian_mobile/resume_add_sheet.dart';
import 'package:bojian_mobile/resume_assistance_page.dart';
import 'package:bojian_mobile/resume_creation.dart';
import 'package:bojian_mobile/resume_creation_answers.dart';
import 'package:bojian_mobile/resume_document.dart';
import 'package:bojian_mobile/resume_pages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

class CreationGateway extends FakeGateway {
  final submissions = <Map<String, dynamic>>[];
  Completer<ApiDocument>? response;
  bool fail = false;
  String taskStatus = 'RUNNING';
  bool failStatus = false;
  @override
  Future<ApiDocument> call(
    String method, {
    Map<String, String> path = const {},
    Map<String, String> query = const {},
    Map<String, dynamic>? body,
    Map<String, String> headers = const {},
  }) async {
    if (method == 'PostResumeCreationJobs') {
      calls.add(method);
      submissions.add(Map.of(body!));
      if (fail) throw const ApiFailure('网络暂不可用');
      return response == null
          ? ApiDocument({'id': 31, 'status': 'QUEUED'})
          : response!.future;
    }
    if (method == 'GetResumeCreationJobsId') {
      calls.add(method);
      if (failStatus) throw const ApiFailure('进度读取失败');
      return ApiDocument({
        'id': 31,
        'status': taskStatus,
        'resume_id': taskStatus == 'SUCCEEDED' ? 8 : null,
      });
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

class MemoryReferenceFile extends XFile {
  MemoryReferenceFile() : super('/tmp/reference.pdf');
  @override
  Future<int> length() async => 2;
}

class ReferenceImporter extends ResumeImporter {
  ReferenceImporter(AppStore store, this.content) : super(store: store);
  final Map<String, dynamic> content;
  int reads = 0;
  @override
  Future<ResumeDraft> importFile(
    XFile file, {
    required void Function(String) onProgress,
    required bool Function() isCancelled,
    void Function(ResumeImportPhase)? onPhase,
  }) async {
    reads++;
    onProgress('正在解析参考文件');
    if (isCancelled()) throw const ImportCancelled();
    return decodeResume({'content': content});
  }
}

const experience = '我有三年前端开发经验，熟悉Flutter，负责电商应用开发。';

void main() {
  test(
    'Lost-response retry reuses key; edited description gets a new key',
    () async {
      final api = CreationGateway()..fail = true;
      final store = await testStore(authenticated: true, api: api);
      addTearDown(store.dispose);
      final controller = ResumeCreationController(store);
      addTearDown(controller.dispose);
      await expectLater(controller.submit('短'), throwsA(isA<ApiFailure>()));
      expect(api.submissions, isEmpty);
      await expectLater(
        controller.submit(experience),
        throwsA(isA<ApiFailure>()),
      );
      api.fail = false;
      expect(await controller.submit(experience), 31);
      expect(
        api.submissions[0]['request_key'],
        api.submissions[1]['request_key'],
      );
      expect(await controller.submit('$experience 也有项目管理经验。'), 31);
      expect(
        api.submissions[2]['request_key'],
        isNot(api.submissions[1]['request_key']),
      );
    },
  );

  test(
    'Duplicate tap is ignored and session change discards late results',
    () async {
      final api = CreationGateway()..response = Completer<ApiDocument>();
      final store = await testStore(authenticated: true, api: api);
      addTearDown(store.dispose);
      final controller = ResumeCreationController(store);
      addTearDown(controller.dispose);
      final pending = controller.submit(experience);
      expect(await controller.submit(experience), isNull);
      expect(api.submissions, hasLength(1));
      await store.endSession(remote: false);
      api.response!.complete(ApiDocument({'id': 31, 'status': 'QUEUED'}));
      expect(await pending, isNull);
    },
  );

  testWidgets(
    'AI creation keeps failed input and shows the saved result without another creation',
    (tester) async {
      final api = CreationGateway()..fail = true;
      final store = await testStore(authenticated: true, api: api);
      addTearDown(store.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: Scaffold(body: ResumeLibrary(store: store, embedded: true)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('profile-add-resume')));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      for (final text in ['AI生成简历', '手动添加', '从微信导入', '从手机文件导入']) {
        expect(find.text(text), findsOneWidget);
      }
      await tester.tap(find.text('AI生成简历'));
      await tester.pumpAndSettle();
      expect(find.byType(ResumeAssistancePage), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('resume-assistance-submit')),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.byKey(const ValueKey('resume-mode-quick')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('resume-assistance-description')),
        experience,
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('resume-assistance-submit')));
      await tester.pumpAndSettle();
      expect(find.text('网络暂不可用'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('resume-assistance-description')),
            )
            .controller!
            .text,
        experience,
      );
      api.fail = false;
      api.taskStatus = 'SUCCEEDED';
      api.documents['GetResumesId'] = {
        'id': 8,
        'title': 'AI生成的简历',
        'content': {
          'personal_info': {'full_name': '测试用户'},
          'projects': [
            {
              'name': '岗位示例：电商应用体验改进',
              'description': '项目背景：改进购物体验。\n主要工作：负责Flutter前端。',
              'achievements': '完成所负责模块交付',
            },
          ],
        },
      };
      await tester.tap(find.byKey(const ValueKey('resume-assistance-submit')));
      await tester.pumpAndSettle();
      expect(find.byType(ResumeDocumentView), findsOneWidget);
      expect(find.text('编辑简历'), findsOneWidget);
      expect(find.text('岗位示例已保存，请按真实经历修改后使用'), findsOneWidget);
      expect(api.submissions, hasLength(2));
      expect(
        api.submissions[0]['request_key'],
        api.submissions[1]['request_key'],
      );
      expect(api.calls, contains('GetResumeCreationJobsId'));
      expect(api.calls, isNot(contains('PostResumes')));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Seven questions preserve facts, support skips, and submit selected skills',
    (tester) async {
      final api = CreationGateway()..fail = true;
      final store = await testStore(authenticated: true, api: api);
      addTearDown(store.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: ResumeAssistancePage(store: store),
        ),
      );
      Future<void> tapText(String text) async {
        final target = find.text(text).last;
        await tester.ensureVisible(target);
        await tester.pumpAndSettle();
        await tester.tap(target);
        await tester.pumpAndSettle();
      }

      await tapText('职场人');
      await tapText('中级[3–5年]');
      await tapText('新媒体运营');
      await tapText('电子商务');
      await tapText('＋ 团队协作');
      await tapText('确认');
      await tapText('跳过');
      await tester.enterText(
        find.byKey(const ValueKey('resume-assistance-additional')),
        '负责公众号内容策划，发布120篇内容，粉丝从5000增长到20000。',
      );
      await tester.tap(find.byKey(const ValueKey('resume-assistance-submit')));
      await tester.pumpAndSettle();
      final brief = api.submissions.single['description'] as String;
      for (final fact in [
        '身份：职场人',
        '工作年限：中级[3–5年]',
        '意向岗位：新媒体运营',
        '所学专业：电子商务',
        '软技能：团队协作',
        '发布120篇内容',
      ]) {
        expect(brief, contains(fact));
      }
      expect(brief, isNot(contains('资格证书：')));
      expect(find.text('网络暂不可用'), findsOneWidget);
      await tapText('✓ 团队协作');
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('resume-assistance-submit')),
            )
            .onPressed,
        isNull,
      );
      await tester.ensureVisible(find.text('确认').first);
      await tester.tap(find.text('确认').first);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('resume-assistance-submit')),
            )
            .onPressed,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'A failed status read resumes the same job without duplicate submission',
    (tester) async {
      final api = CreationGateway()..failStatus = true;
      final store = await testStore(authenticated: true, api: api);
      addTearDown(store.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: ResumeAssistancePage(store: store),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('resume-mode-quick')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('resume-assistance-description')),
        experience,
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('resume-assistance-submit')));
      await tester.pumpAndSettle();
      expect(find.text('进度读取失败'), findsOneWidget);
      api.failStatus = false;
      api.taskStatus = 'FAILED';
      await tester.tap(find.text('继续查看生成结果'));
      await tester.pumpAndSettle();
      expect(api.submissions, hasLength(1));
      await tester.tap(find.text('返回修改或重试'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('resume-assistance-description')),
            )
            .controller!
            .text,
        experience,
      );
      api.fail = true;
      await tester.tap(find.byKey(const ValueKey('resume-assistance-submit')));
      await tester.pumpAndSettle();
      expect(api.submissions, hasLength(2));
      expect(
        api.submissions[0]['request_key'],
        isNot(api.submissions[1]['request_key']),
      );
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'Question brief fits the API limit and never supplies missing credentials',
    () {
      final answers = ResumeCreationAnswers()
        ..identity = '职场人'
        ..years = '中级[3–5年]'
        ..position = '产品经理';
      final brief = answers.describe('负责需求分析和上线交付');
      expect(brief.runes.length, lessThanOrEqualTo(5000));
      expect(brief, isNot(contains('学校：')));
      expect(brief, isNot(contains('资格证书：')));
      expect(brief, contains('优先融入本人补充或参考文件中的真实经历'));
      expect(brief, contains('生成完整、具体、可编辑的岗位示例'));
      expect(brief, contains('未知的个人资料、公司、学校、日期及量化指标保持空白'));
      expect(brief, isNot(contains('待本人补充')));
    },
  );

  testWidgets(
    'Reference parsing adds editable facts without confirming or creating a resume',
    (tester) async {
      final api = CreationGateway()..fail = true;
      final store = await testStore(authenticated: true, api: api);
      addTearDown(store.dispose);
      final importer = ReferenceImporter(store, {
        'personal_info': {'full_name': '参考用户'},
        'projects': [
          {
            'name': '订单流程优化',
            'description': '梳理结算流程并实现前端模块',
            'achievements': '完成验收交付',
          },
        ],
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: ResumeAssistancePage(
            store: store,
            referenceImporter: importer,
            pickReferenceFile: () async => XFile('/tmp/reference-resume.pdf'),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('resume-mode-quick')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('resume-reference-pick')),
      );
      await tester.tap(find.byKey(const ValueKey('resume-reference-pick')));
      await tester.pumpAndSettle();
      expect(importer.reads, 1);
      expect(find.text('已解析：reference-resume.pdf'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('resume-assistance-submit')));
      await tester.pumpAndSettle();
      expect(api.submissions.single['description'], contains('订单流程优化'));
      expect(api.submissions.single['description'], contains('参考用户'));
      expect(api.calls, isNot(contains('PostResumes')));
      expect(api.calls, isNot(contains('PostResumeImportsIdConfirm')));
      await tester.ensureVisible(find.text('移除'));
      await tester.tap(find.text('移除'));
      await tester.pumpAndSettle();
      expect(find.text('已解析：reference-resume.pdf'), findsNothing);
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('resume-assistance-submit')),
            )
            .onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Canceling reference selection keeps typed experience', (
    tester,
  ) async {
    final store = await testStore(authenticated: true);
    addTearDown(store.dispose);
    var picks = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: ResumeAssistancePage(
          store: store,
          pickReferenceFile: () async {
            picks++;
            return null;
          },
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('resume-mode-quick')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('resume-assistance-description')),
      experience,
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('resume-reference-pick')),
    );
    await tester.tap(find.byKey(const ValueKey('resume-reference-pick')));
    await tester.pumpAndSettle();
    expect(picks, 1);
    expect(
      tester
          .widget<TextField>(
            find.byKey(const ValueKey('resume-assistance-description')),
          )
          .controller!
          .text,
      experience,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('resume-assistance-submit')),
          )
          .onPressed,
      isNotNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Oversized reference stays intact and must be edited before generation',
    (tester) async {
      final store = await testStore(authenticated: true);
      addTearDown(store.dispose);
      final importer = ReferenceImporter(store, {
        'raw_text': List.filled(5100, '简').join(),
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: ResumeAssistancePage(
            store: store,
            referenceImporter: importer,
            pickReferenceFile: () async => XFile('/tmp/long-reference.pdf'),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('resume-mode-quick')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('resume-reference-pick')),
      );
      await tester.tap(find.byKey(const ValueKey('resume-reference-pick')));
      await tester.pumpAndSettle();
      expect(find.textContaining('请编辑精简至5000字以内'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('resume-assistance-submit')),
            )
            .onPressed,
        isNull,
      );
      await tester.ensureVisible(find.text('查看与编辑'));
      await tester.tap(find.text('查看与编辑'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byType(TextField).last)
            .controller!
            .text
            .length,
        5100,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Custom position selection scrolls on a short screen with the keyboard open',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(640, 320);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = await testStore(authenticated: true);
      addTearDown(store.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(1.5),
              viewInsets: const EdgeInsets.only(bottom: 140),
            ),
            child: child!,
          ),
          home: ResumeAssistancePage(store: store),
        ),
      );
      Future<void> pick(Finder finder) async {
        await tester.ensureVisible(finder);
        await tester.pumpAndSettle();
        await tester.tap(finder);
        await tester.pumpAndSettle();
      }

      await pick(find.text('职场人'));
      await pick(find.text('中级[3–5年]'));
      await pick(find.byKey(const ValueKey('resume-position-search')));
      await tester.enterText(find.byType(TextField).last, '数据产品经理');
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('使用“数据产品经理”'),
        80,
        scrollable: find.ancestor(
          of: find.text('选择意向岗位'),
          matching: find.byType(Scrollable),
        ),
      );
      await pick(find.text('使用“数据产品经理”'));
      expect(find.text('我想要找数据产品经理方向相关的工作'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final identity in ['在校生', '应届生']) {
    testWidgets(
      '$identity uses its observed seven-question branch and clears tags on identity changes',
      (tester) async {
        final api = CreationGateway()..fail = true;
        final store = await testStore(authenticated: true, api: api);
        addTearDown(store.dispose);
        await tester.pumpWidget(
          MaterialApp(
            theme: appTheme,
            home: ResumeAssistancePage(store: store),
          ),
        );
        Future<void> pick(String text) async {
          final target = find.text(text).last;
          await tester.ensureVisible(target);
          await tester.pumpAndSettle();
          await tester.tap(target);
          await tester.pumpAndSettle();
        }

        final student = identity == '在校生';
        await pick(identity);
        expect(find.text(student ? '选择你所学的专业' : '选择你的意向岗位'), findsOneWidget);
        expect(find.text('请选择你的工作年限'), findsNothing);
        expect(find.text('跳过'), findsNothing);
        if (student) {
          await pick('电子商务');
          await pick('新媒体运营');
        } else {
          await pick('新媒体运营');
          expect(find.text('跳过'), findsNothing);
          await pick('电子商务');
        }
        final category = student ? '学生会' : '产品推广方案';
        await pick('＋ $category');
        expect(
          find.text(student ? '请选择符合你的性格特征（多选）' : '请选择符合你的软技能（多选）'),
          findsNothing,
        );
        await pick('确认');
        await pick(student ? '＋ 责任感强' : '＋ 学习能力');
        await pick('确认');
        await pick('跳过');
        await tester.enterText(
          find.byKey(const ValueKey('resume-assistance-additional')),
          '测试资料：负责梳理需求和准备项目材料。',
        );
        await tester.tap(
          find.byKey(const ValueKey('resume-assistance-submit')),
        );
        await tester.pumpAndSettle();
        final brief = api.submissions.single['description'] as String;
        expect(brief, contains(student ? '校园活动标签：学生会' : '参与项目类别：产品推广方案'));
        expect(
          brief,
          contains('选中的${student ? '校园活动' : '项目'}主题，可结合目标岗位生成完整示例'),
        );
        expect(brief, isNot(contains('待本人补充')));
        expect(brief, contains(student ? '性格特征：责任感强' : '软技能：学习能力'));
        expect(brief, isNot(contains('工作年限：')));
        await pick('职场人');
        expect(find.text('请选择你的工作年限'), findsOneWidget);
        expect(find.textContaining(category), findsNothing);
        await pick('中级[3–5年]');
        await pick('新媒体运营');
        await pick('电子商务');
        await pick('跳过');
        await pick('跳过');
        await tester.tap(
          find.byKey(const ValueKey('resume-assistance-submit')),
        );
        await tester.pumpAndSettle();
        expect(api.submissions.last['description'], isNot(contains(category)));
        expect(
          api.submissions.last['description'],
          isNot(contains(student ? '性格特征：' : '软技能：学习能力')),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'A real parsed reference retains source facts omitted from structured fields',
    (tester) async {
      final api = CreationGateway()..fail = true;
      const originalText = '姓名：参考用户。未结构化事实：曾带领志愿者完成无障碍活动改进。';
      api.documents['PostFilesUploads'] = {'id': 9};
      api.documents['PostFilesUploadsIdComplete'] = {};
      api.documents['PostResumeImports'] = {'id': 11};
      api.documents['GetResumeImportsId'] = {
        'id': 11,
        'status': 'WAITING_CONFIRMATION',
        'parsed_content': {
          'personal_info': {'full_name': '参考用户'},
        },
        'unresolved_source_text': originalText,
      };
      final store = await testStore(authenticated: true, api: api);
      addTearDown(store.dispose);
      final importer = ResumeImporter(
        store: store,
        upload: (_, _, _) async {},
        delay: (_) async {},
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: ResumeAssistancePage(
            store: store,
            referenceImporter: importer,
            pickReferenceFile: () async => MemoryReferenceFile(),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('resume-mode-quick')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('resume-reference-pick')),
      );
      await tester.tap(find.byKey(const ValueKey('resume-reference-pick')));
      await tester.pumpAndSettle();
      expect(find.text('已解析：reference.pdf'), findsOneWidget);
      expect(
        api.calls.where((call) => call == 'GetResumeImportsId'),
        hasLength(2),
      );
      await tester.tap(find.byKey(const ValueKey('resume-assistance-submit')));
      await tester.pumpAndSettle();
      expect(api.submissions.single['description'], contains(originalText));
      expect(api.calls, isNot(contains('PostResumeImportsIdConfirm')));
      expect(api.calls, isNot(contains('PostResumes')));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Created notification opens the saved resume and marks it read', (
    tester,
  ) async {
    final api = FakeGateway();
    api.documents['GetNotifications'] = {
      'unread_count': 1,
      'items': [
        {
          'id': 20,
          'type': 'RESUME_CREATED',
          'subject_type': 'RESUME',
          'subject_id': 8,
          'payload': {'title': '简历已创建', 'body': '你的简历已整理完成'},
        },
      ],
    };
    api.documents['GetResumesId'] = {
      'id': 8,
      'title': '协助创建的简历',
      'content': {
        'personal_info': {'full_name': '小林'},
      },
    };
    final store = await testStore(authenticated: true, api: api);
    addTearDown(store.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: Scaffold(body: MessagesPage(store: store)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('简历已创建'));
    await tester.pumpAndSettle();
    expect(find.byType(ResumeEditor), findsOneWidget);
    expect(store.inbox.single.read, isTrue);
    expect(api.calls, contains('PostNotificationsRead'));
  });

  testWidgets(
    'Local import enters file selection once; canceled selection remains usable',
    (tester) async {
      final store = await testStore(authenticated: true);
      addTearDown(store.dispose);
      var picks = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: ImportResume(
            store: store,
            initialSource: ResumeImportSource.local,
            pickFile: () async {
              picks++;
              return null;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(picks, 1);
      expect(find.text('从本机文件上传'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final dark in [false, true]) {
    testWidgets('Sheet and editor fit narrow large-text screens (dark=$dark)', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 640);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = await testStore(authenticated: true);
      addTearDown(store.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: dark ? appDarkTheme : appTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(2)),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showResumeAddSheet(context),
                child: const Text('添加'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('添加'));
      await tester.pumpAndSettle();
      expect(find.text('从手机文件导入'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(
        MaterialApp(
          theme: dark ? appDarkTheme : appTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(2),
              viewInsets: const EdgeInsets.only(bottom: 240),
            ),
            child: child!,
          ),
          home: ResumeAssistancePage(store: store),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
