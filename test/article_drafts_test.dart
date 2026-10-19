import 'dart:async';

import 'package:bojian_mobile/api/bojian_api.dart';
import 'package:bojian_mobile/app_store.dart';
import 'package:bojian_mobile/design.dart';
import 'package:bojian_mobile/my_articles_page.dart';
import 'package:bojian_mobile/story_composer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

class DraftGateway extends FakeGateway {
  final queries = <Map<String, String>>[];
  final mutations = <(String, String, Map<String, dynamic>)>[];
  bool submitted = false;
  Completer<void>? saving;
  Map<String, dynamic> draft = {
    'id': 8,
    'title': '求职复盘',
    'status': 'DRAFT',
    'review_reason': '请补充具体项目成果',
    'content': richContent('原有内容'),
  };

  @override
  Future<ApiDocument> call(
    String method, {
    Map<String, String> path = const {},
    Map<String, String> query = const {},
    Map<String, dynamic>? body,
    Map<String, String> headers = const {},
  }) async {
    if (method == 'GetMeArticles') {
      calls.add(method);
      queries.add({...query});
      return ApiDocument({
        'items': [
          if (!submitted) {...draft},
          // A non-draft must never appear in this entry even if cached by an API.
          {'id': 9, 'title': '已发布内容', 'status': 'PUBLISHED'},
        ],
      });
    }
    if (method == 'GetArticlesId') {
      calls.add(method);
      return ApiDocument({...draft});
    }
    if (method == 'PatchArticlesId' || method == 'PostArticlesIdPublish') {
      calls.add(method);
      mutations.add((method, path['id']!, {...body!}));
      if (method == 'PatchArticlesId') await saving?.future;
      if (failing == method) throw const ApiFailure('网络暂不可用');
      if (method == 'PatchArticlesId') {
        draft = {...draft, ...body};
      } else {
        submitted = true;
      }
      return ApiDocument({'id': 8});
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

Future<AppStore> mount(
  WidgetTester tester,
  DraftGateway api, {
  bool large = false,
}) async {
  tester.view.physicalSize = large
      ? const Size(320, 640)
      : const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final store = await testStore(authenticated: true, api: api);
  addTearDown(store.dispose);
  await tester.pumpWidget(
    MaterialApp(
      theme: large ? appDarkTheme : appTheme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(large ? 2 : 1)),
        child: child!,
      ),
      home: MyArticlesPage(store: store, draftsOnly: true),
    ),
  );
  await tester.pumpAndSettle();
  return store;
}

quill.QuillEditor bodyEditor(WidgetTester tester) => tester
    .widget<quill.QuillEditor>(find.byKey(const ValueKey('composer-body')));

void main() {
  testWidgets(
    'Draft box only lists drafts and reopens unchanged content without a discard prompt',
    (tester) async {
      final api = DraftGateway();
      await mount(tester, api);
      expect(find.text('草稿箱'), findsOneWidget);
      expect(api.queries.single['status'], 'DRAFT');
      expect(find.byKey(const ValueKey('articles-SUBMITTED')), findsNothing);
      expect(find.text('写文章'), findsNothing);
      expect(find.text('已发布内容'), findsNothing);
      await tester.tap(find.text('求职复盘'));
      await tester.pumpAndSettle();
      expect(find.byType(StoryComposer), findsOneWidget);
      expect(bodyEditor(tester).controller.document.toPlainText(), '原有内容\n');
      expect(find.text('审核意见：请补充具体项目成果'), findsOneWidget);
      await tester.tap(find.byTooltip('关闭'));
      await tester.pumpAndSettle();
      expect(find.byType(StoryComposer), findsNothing);
      expect(find.text('放弃本次修改？'), findsNothing);
      expect(api.mutations, isEmpty);
    },
  );

  testWidgets('Save updates the original draft and refreshes the draft box', (
    tester,
  ) async {
    final api = DraftGateway();
    await mount(tester, api);
    await tester.tap(find.text('求职复盘'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('composer-title')),
      '修改后的复盘',
    );
    final editor = bodyEditor(tester);
    editor.controller.replaceText(
      0,
      4,
      '具体项目成果',
      const TextSelection.collapsed(offset: 6),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.byType(StoryComposer), findsNothing);
    expect(find.text('修改后的复盘'), findsOneWidget);
    expect(api.mutations.single.$1, 'PatchArticlesId');
    expect(api.mutations.single.$2, '8');
    expect(api.mutations.single.$3['content'], richContent('具体项目成果'));
    expect(api.draft['review_reason'], '请补充具体项目成果');
    expect(api.calls, isNot(contains('PostArticles')));
    expect(api.queries, hasLength(2));
  });

  testWidgets(
    'Failed resubmission retains edits and retries the same draft ID',
    (tester) async {
      final api = DraftGateway()..failing = 'PostArticlesIdPublish';
      await mount(tester, api);
      await tester.tap(find.text('求职复盘'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('composer-title')),
        '补充成果后的复盘',
      );
      await tester.tap(find.byTooltip('提交审核'));
      await tester.pumpAndSettle();
      expect(find.byType(StoryComposer), findsOneWidget);
      expect(find.text('补充成果后的复盘'), findsOneWidget);
      expect(bodyEditor(tester).controller.readOnly, isFalse);
      api.failing = null;
      await tester.tap(find.byTooltip('提交审核'));
      await tester.pumpAndSettle();
      expect(find.byType(StoryComposer), findsNothing);
      expect(find.text('暂无草稿的文章'), findsOneWidget);
      expect(api.mutations.map((entry) => entry.$2), everyElement('8'));
      expect(api.mutations.map((entry) => entry.$1), [
        'PatchArticlesId',
        'PostArticlesIdPublish',
        'PatchArticlesId',
        'PostArticlesIdPublish',
      ]);
      expect(api.calls, isNot(contains('PostArticles')));
    },
  );

  testWidgets(
    'Failed saving preserves guidance question, snapshot and source without publishing',
    (tester) async {
      final api = DraftGateway()..failing = 'PatchArticlesId';
      final original = {
        'kind': 'RESUME_GUIDANCE',
        'question': '原问题',
        'source_resume_id': 17,
        'snapshot': {
          'skills': ['Flutter'],
        },
        'photo_file_id': 29,
        'blocks': richContent('简历原快照')['blocks'],
      };
      api.draft['content'] = original;
      await mount(tester, api);
      await tester.tap(find.text('求职复盘'));
      await tester.pumpAndSettle();
      final editor = bodyEditor(tester);
      expect(editor.controller.document.toPlainText(), '原问题\n');
      expect(find.byTooltip('粗体'), findsNothing);
      editor.controller.replaceText(
        0,
        3,
        '请帮我看看项目经历',
        const TextSelection.collapsed(offset: 9),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(editor.controller.readOnly, isFalse);
      expect(editor.controller.document.toPlainText(), '请帮我看看项目经历\n');
      expect(api.mutations.single.$3['content'], {
        ...original,
        'question': '请帮我看看项目经历',
      });
      expect(api.calls, isNot(contains('PostArticlesIdPublish')));
      api.failing = null;
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(api.draft['content'], {...original, 'question': '请帮我看看项目经历'});
    },
  );

  testWidgets(
    'Imported tables and inline formatting survive editing adjacent text',
    (tester) async {
      final api = DraftGateway();
      final table = {
        'kind': 'table',
        'table': {
          'rows': [
            {
              'cells': [
                {
                  'spans': [
                    {'text': '保留表格'},
                  ],
                },
              ],
            },
          ],
        },
      };
      api.draft['content'] = {
        'schema_version': 2,
        'blocks': [
          {
            'kind': 'paragraph',
            'spans': [
              {'text': '原文', 'bold': true},
            ],
          },
          table,
        ],
      };
      await mount(tester, api);
      await tester.tap(find.text('求职复盘'));
      await tester.pumpAndSettle();
      expect(find.text('保留表格'), findsOneWidget);
      final editor = bodyEditor(tester);
      editor.controller.replaceText(
        0,
        0,
        '补充',
        const TextSelection.collapsed(offset: 2),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      final content = api.mutations.single.$3['content'] as Map;
      expect(content['schema_version'], 2);
      expect((content['blocks'] as List).last, table);
      expect((content['blocks'] as List).first['spans'], [
        {'text': '补充原文', 'bold': true},
      ]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Account switch after saving cannot submit under the new account',
    (tester) async {
      final api = DraftGateway()..saving = Completer<void>();
      final store = await mount(tester, api);
      await tester.tap(find.text('求职复盘'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('提交审核'));
      await tester.pump();
      await store.endSession(remote: false);
      api.saving!.complete();
      await tester.pumpAndSettle();
      expect(api.calls, isNot(contains('PostArticlesIdPublish')));
    },
  );

  testWidgets(
    'Long review reasons and editor actions fit small dark screens at double text size',
    (tester) async {
      final api = DraftGateway();
      api.draft['review_reason'] = List.filled(20, '请补充项目成果和数据。').join();
      await mount(tester, api, large: true);
      await tester.tap(find.text('求职复盘'));
      await tester.pumpAndSettle();
      expect(find.text('保存'), findsOneWidget);
      expect(
        tester.getRect(find.byTooltip('提交审核')).right,
        lessThanOrEqualTo(320),
      );
      expect(tester.takeException(), isNull);
      await tester.drag(
        find.byKey(const ValueKey('composer-page')),
        const Offset(0, -500),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
