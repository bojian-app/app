import 'package:bojian_mobile/api/bojian_api.dart';
import 'package:bojian_mobile/design.dart';
import 'package:bojian_mobile/article_rich_content.dart';
import 'package:bojian_mobile/story_composer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

class ComposerGateway extends FakeGateway {
  Map<String, dynamic>? article;
  @override
  Future<ApiDocument> call(
    String method, {
    Map<String, String> path = const {},
    Map<String, String> query = const {},
    Map<String, dynamic>? body,
    Map<String, String> headers = const {},
  }) async {
    if (method == 'PostArticles') {
      article = body;
      if (failing == method) throw const ApiFailure('提交失败');
      return ApiDocument({'id': 99});
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
  testWidgets('A title-only draft can be saved without submission', (
    tester,
  ) async {
    final api = ComposerGateway();
    final store = await testStore(authenticated: true, api: api);
    addTearDown(store.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: StoryComposer(store: store),
      ),
    );
    await tester.enterText(
      find.byKey(const ValueKey('composer-title')),
      '稍后补正文',
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, '发布'))
          .onPressed,
      isNull,
    );
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存草稿'));
    await tester.pumpAndSettle();
    expect(api.article?['title'], '稍后补正文');
    expect(api.calls, isNot(contains('PostArticlesIdPublish')));
  });

  testWidgets(
    'A link card and a topic insert at the cursor and survive reopening',
    (tester) async {
      final api = ComposerGateway();
      final store = await testStore(authenticated: true, api: api);
      addTearDown(store.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: StoryComposer(store: store),
        ),
      );
      final editor = tester
          .widget<quill.QuillEditor>(
            find.byKey(const ValueKey('composer-body')),
          )
          .controller;
      editor.replaceText(0, 0, '前后', const TextSelection.collapsed(offset: 1));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('更多'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('链接'));
      await tester.pumpAndSettle();
      final link = find.widgetWithText(TextField, '输入链接');
      await tester.enterText(link, 'invalid');
      await tester.tap(find.text('添加'));
      await tester.pumpAndSettle();
      expect(find.text('请输入完整的 http 或 https 链接'), findsOneWidget);
      await tester.enterText(link, 'https://example.org/jobs');
      await tester.tap(find.text('添加'));
      await tester.pumpAndSettle();
      expect(find.text('example.org'), findsOneWidget);
      await tester.tap(find.byTooltip('话题'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, '求职 / 复盘');
      await tester.pumpAndSettle();
      await tester.tap(find.text('完成'));
      await tester.pumpAndSettle();
      final doc = articleContentFromDelta(editor.document.toDelta().toJson());
      expect(doc['blocks'], [
        {
          'kind': 'paragraph',
          'spans': [
            {'text': '前'},
          ],
        },
        {'kind': 'link', 'url': 'https://example.org/jobs'},
        {
          'kind': 'paragraph',
          'spans': [
            {'text': '#求职 / 复盘#', 'topic': '求职 / 复盘'},
            {'text': ' 后'},
          ],
        },
      ]);
      expect(articleContentFromDelta(articleDeltaFromContent(doc)), doc);
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, '发布'))
            .onPressed,
        isNotNull,
      );
      await tester.tap(find.byTooltip('移除卡片'));
      await tester.pumpAndSettle();
      expect(find.text('example.org'), findsNothing);
      expect(editor.document.toPlainText(), contains('#求职 / 复盘# 后'));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Formatting applies to selected text and failed submissions preserve content',
    (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = ComposerGateway()..failing = 'PostArticles';
      final store = await testStore(authenticated: true, api: api);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: StoryComposer(store: store),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('composer-title')),
        '我的面试复盘',
      );
      final editor = tester.widget<quill.QuillEditor>(
        find.byKey(const ValueKey('composer-body')),
      );
      editor.controller.replaceText(
        0,
        0,
        '第一段\n第二段',
        const TextSelection(baseOffset: 0, extentOffset: 3),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('文字格式'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('粗体'));
      await tester.pumpAndSettle();
      expect(
        editor.controller.document.toDelta().toJson().first['attributes'],
        {'bold': true},
      );
      expect(editor.focusNode.hasFocus, true);
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.byTooltip('粗体')).bottom,
        lessThanOrEqualTo(480),
      );
      await tester.tap(find.widgetWithText(TextButton, '发布'));
      await tester.pumpAndSettle();
      expect(api.article!['title'], '我的面试复盘');
      final blocks = (api.article!['content'] as Map)['blocks'] as List;
      expect(blocks.first['spans'], [
        {'text': '第一段', 'bold': true},
      ]);
      expect(editor.controller.document.toPlainText(), '第一段\n第二段\n');
      expect(editor.controller.readOnly, false);
      expect(find.text('我的面试复盘'), findsOneWidget);
      tester.view.viewInsets = FakeViewPadding.zero;
      tester.view.physicalSize = const Size(780, 360);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('返回'));
      await tester.pumpAndSettle();
      expect(find.text('要保存草稿吗？'), findsOneWidget);
      await tester.tap(find.text('继续编辑'));
      await tester.pumpAndSettle();
      expect(editor.controller.document.toPlainText(), '第一段\n第二段\n');
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    },
  );

  testWidgets('The heading button offers H2 to H6 instead of applying one', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = await testStore(authenticated: true);
    addTearDown(store.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: StoryComposer(store: store),
      ),
    );
    await tester.pumpAndSettle();
    final editor = tester.widget<quill.QuillEditor>(
      find.byKey(const ValueKey('composer-body')),
    );
    editor.controller.replaceText(
      0,
      0,
      '章节',
      const TextSelection.collapsed(offset: 1),
    );
    await tester.tap(find.byTooltip('文字格式'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('标题'));
    await tester.pumpAndSettle();
    expect(
      editor.controller.document.toDelta().toJson().last['attributes'],
      isNull,
    );
    for (final level in [2, 3, 4, 5, 6]) {
      expect(find.byKey(ValueKey('composer-heading-$level')), findsOneWidget);
    }
    expect(find.byKey(const ValueKey('composer-heading-1')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('composer-heading-4')));
    await tester.pumpAndSettle();
    expect(editor.controller.document.toDelta().toJson().last['attributes'], {
      'header': 4,
    });
    expect(find.byKey(const ValueKey('composer-heading-levels')), findsNothing);
    expect(
      articleContentFromDelta(
        editor.controller.document.toDelta().toJson(),
      )['blocks'],
      [
        {
          'kind': 'heading4',
          'spans': [
            {'text': '章节'},
          ],
        },
      ],
    );
    expect(
      articleDeltaFromContent({
        'blocks': [
          {
            'kind': 'heading5',
            'spans': [
              {'text': '五'},
            ],
          },
        ],
      }).last['attributes'],
      {'header': 5},
    );
    await tester.tap(find.byTooltip('标题'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('composer-heading-4')));
    await tester.pumpAndSettle();
    expect(
      editor.controller.document.toDelta().toJson().last['attributes'],
      isNull,
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Finishing a poll publishes the post at once', (tester) async {
    tester.view.physicalSize = const Size(390, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final api = ComposerGateway();
    api.documents['PostArticlePolls'] = {
      'kind': 'poll',
      'poll_id': 31,
      'mode': 'question',
      'title': '穆兰有几位大神师？',
    };
    final store = await testStore(authenticated: true, api: api);
    addTearDown(store.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => StoryComposer(store: store),
                ),
              ),
              child: const Text('写动态'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('写动态'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('更多'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('投票'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('问答'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '穆兰有几位大神师？');
    await tester.enterText(find.byType(TextField).last, '4');
    await tester.pumpAndSettle();
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();
    // The writing page is gone; the poll was not left in an editor.
    expect(find.byType(StoryComposer), findsNothing);
    expect(api.calls, contains('PostArticlePolls'));
    final blocks = (api.article!['content'] as Map)['blocks'] as List;
    expect(blocks.last, containsPair('poll_id', 31));
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('A poll that fails to publish stays in the editor', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final api = ComposerGateway()..failing = 'PostArticles';
    api.documents['PostArticlePolls'] = {
      'kind': 'poll',
      'poll_id': 32,
      'mode': 'question',
      'title': '失败重试',
    };
    final store = await testStore(authenticated: true, api: api);
    addTearDown(store.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: StoryComposer(store: store),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('更多'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('投票'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('问答'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '失败重试');
    await tester.enterText(find.byType(TextField).last, '答案');
    await tester.pumpAndSettle();
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();
    final editor = tester.widget<quill.QuillEditor>(
      find.byKey(const ValueKey('composer-body')),
    );
    expect(
      editor.controller.document.toDelta().toJson().any(
        (op) => op['insert'] is Map,
      ),
      isTrue,
    );
    expect(editor.controller.readOnly, isFalse);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'Selections survive outside touches and the format bar keeps the keyboard',
    (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = await testStore(authenticated: true);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          scrollBehavior: const MaterialScrollBehavior().copyWith(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          ),
          home: StoryComposer(store: store),
        ),
      );
      await tester.pumpAndSettle();
      final editor = tester.widget<quill.QuillEditor>(
        find.byKey(const ValueKey('composer-body')),
      );
      final focus = editor.focusNode;
      focus.requestFocus();
      editor.controller.replaceText(
        0,
        0,
        '第一段文字',
        const TextSelection(baseOffset: 0, extentOffset: 3),
      );
      await tester.pumpAndSettle();
      // A touch outside the editor, e.g. on a selection handle.
      await tester.tapAt(const Offset(180, 60));
      await tester.pumpAndSettle();
      expect(focus.hasFocus, isTrue);
      expect(editor.controller.selection.extentOffset, 3);
      await tester.tap(find.byTooltip('文字格式'));
      await tester.pumpAndSettle();
      final bar = tester.widget<SingleChildScrollView>(
        find.byKey(const ValueKey('composer-format-bar')),
      );
      expect(
        bar.keyboardDismissBehavior,
        ScrollViewKeyboardDismissBehavior.manual,
      );
      editor.controller.updateSelection(
        const TextSelection.collapsed(offset: 2),
        quill.ChangeSource.local,
      );
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(180, 60));
      await tester.pumpAndSettle();
      expect(focus.hasFocus, isFalse);
    },
  );
}
