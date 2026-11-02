import 'dart:async';

import 'package:bojian_mobile/api/bojian_api.dart';
import 'package:bojian_mobile/app_store.dart';
import 'package:bojian_mobile/design.dart';
import 'package:bojian_mobile/resume_pages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';
import 'support/resume_editor_helpers.dart';

const generated =
    '1. 根据业务需求完成页面开发与维护。\n\n2. 配合团队排查问题并完善交互体验。\n\n3. 整理开发文档，支持功能交付与迭代。';

class WorkGenerationGateway extends FakeGateway {
  final inputs = <Map<String, dynamic>>[];
  Completer<ApiDocument>? pending;
  bool fail = false;
  @override
  Future<ApiDocument> call(
    String method, {
    Map<String, String> path = const {},
    Map<String, String> query = const {},
    Map<String, dynamic>? body,
    Map<String, String> headers = const {},
  }) async {
    if (method == 'PostResumeWorkDescriptions') {
      inputs.add(Map.of(body!));
      if (fail) throw const ApiFailure('生成失败，请重试');
      return pending == null
          ? ApiDocument({'description': generated})
          : await pending!.future;
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
  Future<void> open(
    WidgetTester tester,
    WorkGenerationGateway api, {
    String role = '前端开发工程师',
    bool second = false,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final store = await testStore(authenticated: true, api: api);
    addTearDown(store.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: ResumeEditor(
          store: store,
          draft: decodeResume({
            'title': '工作简历',
            'content': {
              'work_experiences': [
                {
                  'company': '示例公司',
                  'position': role,
                  'industry': '软件开发',
                  'start_date': '2022-05-10',
                  'current': true,
                  'description': '原工作内容',
                  'description_rich': richContent('原工作内容'),
                },
                if (second)
                  {
                    'company': '第二家公司',
                    'position': '产品经理',
                    'description': '第二段内容',
                  },
              ],
            },
          }),
        ),
      ),
    );
    await openResumeSection(tester, 3);
  }

  Future<void> generate(WidgetTester tester) async {
    final button = find.byKey(const ValueKey('work-0-ai-generate'));
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Missing role prevents request; tag is at right of description label',
    (tester) async {
      final api = WorkGenerationGateway();
      await open(tester, api, role: '  ');
      final label = find.text('工作内容与成果');
      final button = find.byKey(const ValueKey('work-0-ai-generate'));
      expect(
        tester.getRect(button).left,
        greaterThan(tester.getRect(label).right),
      );
      await generate(tester);
      expect(find.text('请先填写职位'), findsOneWidget);
      expect(api.inputs, isEmpty);
    },
  );

  testWidgets(
    'Uploads only five fields and saves generated text into current entry',
    (tester) async {
      final api = WorkGenerationGateway();
      await open(tester, api, second: true);
      await generate(tester);
      expect(api.inputs.single, {
        'company_name': '示例公司',
        'job_title': '前端开发工程师',
        'industry': '软件开发',
        'start_date': '2022-05-10',
        'end_date': '至今',
      });
      final field = find.byKey(const ValueKey('resume-work-0-description'));
      expect(tester.widget<TextFormField>(field).controller!.text, generated);
      await saveResumeSection(tester);
      final entries =
          api.lastMutationBody!['content']['work_experiences'] as List;
      expect(entries[0]['description'], generated);
      expect(entries[0]['description_rich'], isNull);
      expect(entries[1]['description'], '第二段内容');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Pending generation blocks duplicates and does not overwrite new edits',
    (tester) async {
      final api = WorkGenerationGateway()..pending = Completer<ApiDocument>();
      await open(tester, api);
      await generate(tester);
      final button = find.byKey(const ValueKey('work-0-ai-generate'));
      expect(tester.widget<TextButton>(button).onPressed, isNull);
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('resume-section-save')),
            )
            .onPressed,
        isNull,
      );
      final field = find.byKey(const ValueKey('resume-work-0-description'));
      await tester.enterText(field, '刚补充的真实工作内容');
      api.pending!.complete(ApiDocument({'description': generated}));
      await tester.pumpAndSettle();
      expect(api.inputs, hasLength(1));
      expect(
        tester.widget<TextFormField>(field).controller!.text,
        '刚补充的真实工作内容',
      );
      expect(find.text('内容已修改，未覆盖当前输入，请重新生成'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Failure retains content and allows retry', (tester) async {
    final api = WorkGenerationGateway()..fail = true;
    await open(tester, api);
    await generate(tester);
    final field = find.byKey(const ValueKey('resume-work-0-description'));
    expect(tester.widget<TextFormField>(field).controller!.text, '原工作内容');
    expect(find.text('生成失败，请重试'), findsOneWidget);
    api.fail = false;
    await generate(tester);
    expect(tester.widget<TextFormField>(field).controller!.text, generated);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Leaving discards a late result without accessing disposed fields',
    (tester) async {
      final api = WorkGenerationGateway()..pending = Completer<ApiDocument>();
      await open(tester, api);
      await generate(tester);
      await tester.pageBack();
      await tester.pumpAndSettle();
      api.pending!.complete(ApiDocument({'description': generated}));
      await tester.pumpAndSettle();
      await openResumeSection(tester, 3);
      final field = find.byKey(const ValueKey('resume-work-0-description'));
      expect(tester.widget<TextFormField>(field).controller!.text, '原工作内容');
      expect(tester.takeException(), isNull);
    },
  );
}
