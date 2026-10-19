import 'dart:async';

import 'package:bojian_mobile/api/bojian_api.dart';
import 'package:bojian_mobile/design.dart';
import 'package:bojian_mobile/messages_page.dart';
import 'package:bojian_mobile/resume_add_sheet.dart';
import 'package:bojian_mobile/resume_assistance_page.dart';
import 'package:bojian_mobile/resume_creation.dart';
import 'package:bojian_mobile/resume_pages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

class CreationGateway extends FakeGateway {
  final submissions = <Map<String, dynamic>>[];
  Completer<ApiDocument>? response;
  bool fail = false;
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
    return super.call(
      method,
      path: path,
      query: query,
      body: body,
      headers: headers,
    );
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
    'Assistance opens from the bottom sheet; failed submit retains text and retry returns',
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
      for (final text in ['协助添加', '手动添加', '从微信导入', '从手机文件导入']) {
        expect(find.text(text), findsOneWidget);
      }
      await tester.tap(find.text('协助添加'));
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
      await tester.tap(find.byKey(const ValueKey('resume-assistance-submit')));
      await tester.pumpAndSettle();
      expect(find.byType(ResumeAssistancePage), findsNothing);
      expect(api.submissions, hasLength(2));
      expect(api.calls, isNot(contains('GetResumeCreationJobsId')));
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
