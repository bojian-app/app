import 'dart:async';

import 'package:bojian_mobile/api/bojian_api.dart';
import 'package:bojian_mobile/app_store.dart';
import 'package:bojian_mobile/design.dart';
import 'package:bojian_mobile/resume_pages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';
import 'support/resume_editor_helpers.dart';

class ProjectGenerationGateway extends FakeGateway {
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
    if (method == 'PostResumeProjectDescriptions' ||
        method == 'PostResumeProjectAchievements') {
      inputs.add(Map.of(body!));
      if (fail) throw const ApiFailure('生成失败，请重试');
      return pending == null
          ? ApiDocument({
              if (method == 'PostResumeProjectDescriptions')
                'description': '生成的项目描述',
              if (method == 'PostResumeProjectAchievements')
                'achievements': '1. 成果一\n\n2. 成果二\n\n3. 成果三',
            })
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
  Finder field(String name) => find.byKey(ValueKey('resume-projects-0-$name'));
  Finder button(String name) =>
      find.byKey(ValueKey('projects-0-$name-ai-generate'));
  Future<void> open(
    WidgetTester tester,
    ProjectGenerationGateway api, {
    String name = '项目',
    String role = '前端',
    String description = '原描述',
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 1000);
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
            'title': '项目简历',
            'content': {
              'projects': [
                {
                  'name': name,
                  'role': role,
                  'description': description,
                  'description_rich': richContent(description),
                  'achievements': '原成果',
                  'achievements_rich': richContent('原成果'),
                },
                {
                  'name': '另一项目',
                  'role': '产品',
                  'description': '另一描述',
                  'achievements': '另一成果',
                },
              ],
            },
          }),
        ),
      ),
    );
    await openResumeSection(tester, 4);
  }

  Future<void> generate(WidgetTester tester, String target) async {
    await tester.ensureVisible(button(target));
    await tester.pumpAndSettle();
    await tester.tap(button(target));
    await tester.pumpAndSettle();
  }

  Future<void> edit(WidgetTester tester, String target, String text) async {
    await tester.ensureVisible(field(target));
    await tester.pumpAndSettle();
    await tester.enterText(field(target), text);
    await tester.pumpAndSettle();
  }

  String value(WidgetTester tester, String target) =>
      tester.widget<TextFormField>(field(target)).controller!.text;

  testWidgets('Both buttons react to required fields including whitespace', (
    tester,
  ) async {
    final api = ProjectGenerationGateway();
    await open(tester, api, name: ' ', role: ' ', description: ' ');
    bool enabled(String target) =>
        tester.widget<TextButton>(button(target)).onPressed != null;
    expect(enabled('description'), false);
    expect(enabled('achievements'), false);
    await edit(tester, 'name', '项目');
    expect(enabled('description'), false);
    await edit(tester, 'role', '前端');
    expect(enabled('description'), true);
    expect(enabled('achievements'), false);
    await edit(tester, 'description', '背景');
    expect(enabled('achievements'), true);
    await edit(tester, 'name', '  ');
    expect(enabled('description'), false);
    expect(enabled('achievements'), false);
    expect(api.inputs, isEmpty);
    expect(tester.takeException(), isNull);
  });
  for (final target in ['description', 'achievements']) {
    testWidgets('$target sends only dependencies and saves only its target', (
      tester,
    ) async {
      final api = ProjectGenerationGateway();
      await open(tester, api);
      await generate(tester, target);
      expect(api.inputs.single, {
        'project_name': '项目',
        'role': '前端',
        if (target == 'achievements') 'description': '原描述',
      });
      final generated = value(tester, target);
      expect(generated, startsWith(target == 'description' ? '生成' : '1.'));
      await saveResumeSection(tester);
      final projects = api.lastMutationBody!['content']['projects'] as List;
      expect(projects[0][target], generated);
      expect(projects[0]['${target}_rich'], isNull);
      final other = target == 'description' ? 'achievements' : 'description';
      expect(projects[0][other], target == 'description' ? '原成果' : '原描述');
      expect(projects[1]['description'], '另一描述');
      expect(projects[1]['achievements'], '另一成果');
      expect(tester.takeException(), isNull);
    });
    testWidgets(
      '$target pending locks buttons and save, preserves manual edits',
      (tester) async {
        final api = ProjectGenerationGateway()
          ..pending = Completer<ApiDocument>();
        await open(tester, api);
        await generate(tester, target);
        expect(
          tester.widget<TextButton>(button('description')).onPressed,
          isNull,
        );
        expect(
          tester.widget<TextButton>(button('achievements')).onPressed,
          isNull,
        );
        expect(
          tester
              .widget<FilledButton>(
                find.byKey(const ValueKey('resume-section-save')),
              )
              .onPressed,
          isNull,
        );
        await edit(tester, target, '手动补充内容');
        api.pending!.complete(ApiDocument({target: '迟到结果'}));
        await tester.pumpAndSettle();
        expect(value(tester, target), '手动补充内容');
        expect(api.inputs, hasLength(1));
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'Changed generation inputs prevent stale achievements replacing original',
    (tester) async {
      final api = ProjectGenerationGateway()
        ..pending = Completer<ApiDocument>();
      await open(tester, api);
      await generate(tester, 'achievements');
      await edit(tester, 'description', '刚更新的业务背景');
      api.pending!.complete(ApiDocument({'achievements': '旧背景成果'}));
      await tester.pumpAndSettle();
      expect(value(tester, 'achievements'), '原成果');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Failure preserves results and retry succeeds', (tester) async {
    final api = ProjectGenerationGateway()..fail = true;
    await open(tester, api);
    await generate(tester, 'achievements');
    expect(value(tester, 'achievements'), '原成果');
    api.fail = false;
    await generate(tester, 'achievements');
    expect(value(tester, 'achievements'), startsWith('1.'));
    expect(tester.takeException(), isNull);
  });
  testWidgets('Leaving discards response without accessing disposed fields', (
    tester,
  ) async {
    final api = ProjectGenerationGateway()..pending = Completer<ApiDocument>();
    await open(tester, api);
    await generate(tester, 'achievements');
    await tester.pageBack();
    await tester.pumpAndSettle();
    api.pending!.complete(ApiDocument({'achievements': '迟到成果'}));
    await tester.pumpAndSettle();
    await openResumeSection(tester, 4);
    expect(value(tester, 'achievements'), '原成果');
    expect(tester.takeException(), isNull);
  });
}
