import 'dart:convert';

import 'package:bojian_mobile/api/bojian_api.dart';
import 'package:bojian_mobile/design.dart';
import 'package:bojian_mobile/article_media_picker.dart';
import 'package:bojian_mobile/article_rich_content.dart';
import 'package:bojian_mobile/article_tags.dart';
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
    'A link card goes in at the cursor, a topic goes under the writing',
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
            {'text': '后'},
          ],
        },
      ]);
      // The topic is listed on its own, and picking it again adds nothing.
      expect(editor.document.toPlainText(), isNot(contains('#')));
      const chip = ValueKey('composer-tag-求职 / 复盘');
      expect(find.byKey(chip), findsOneWidget);
      await tester.tap(find.byTooltip('话题'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, '求职 / 复盘');
      await tester.pumpAndSettle();
      await tester.tap(find.text('完成'));
      await tester.pumpAndSettle();
      expect(find.byKey(chip), findsOneWidget);
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
      await tester.tap(find.byTooltip('移除话题'));
      await tester.pumpAndSettle();
      expect(find.byKey(chip), findsNothing);
      expect(editor.document.toPlainText(), contains('后'));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Tags are saved after the writing and reopen apart from it', (
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
    final editor = tester
        .widget<quill.QuillEditor>(find.byKey(const ValueKey('composer-body')))
        .controller;
    editor.replaceText(0, 0, '面试很顺利', const TextSelection.collapsed(offset: 5));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('话题'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '求职');
    await tester.pumpAndSettle();
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存草稿'));
    await tester.pumpAndSettle();
    final saved = api.article!['content'] as Map<String, dynamic>;
    expect(saved['blocks'], [
      {
        'kind': 'paragraph',
        'spans': [
          {'text': '面试很顺利'},
        ],
      },
      articleTagBlock(['求职']),
    ]);

    // An older draft holds its topic at the end of a sentence.
    await tester.pumpWidget(
      MaterialApp(
        key: const ValueKey('again'),
        theme: appTheme,
        home: StoryComposer(
          store: store,
          draft: const {
            'id': 7,
            'title': '',
            'content': {
              'blocks': [
                {
                  'kind': 'paragraph',
                  'spans': [
                    {'text': '面试很顺利 '},
                    {'text': '#求职#', 'topic': '求职'},
                    {'text': ' '},
                  ],
                },
              ],
            },
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    final reopened = tester
        .widget<quill.QuillEditor>(find.byKey(const ValueKey('composer-body')))
        .controller;
    expect(reopened.document.toPlainText(), '面试很顺利\n');
    expect(find.byKey(const ValueKey('composer-tag-求职')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

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

  testWidgets('A finished poll joins the writing and waits for publishing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final api = ComposerGateway();
    Map<String, dynamic> question(int id, String title) => {
      'kind': 'poll',
      'poll_id': id,
      'mode': 'question',
      'title': title,
    };
    api.documents['PostArticlePolls'] = question(31, '穆兰有几位大神师？');
    final store = await testStore(authenticated: true, api: api);
    addTearDown(store.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: StoryComposer(store: store),
      ),
    );
    await tester.pumpAndSettle();
    List<Map<String, dynamic>> placed() => [
      for (final op
          in tester
              .widget<quill.QuillEditor>(
                find.byKey(const ValueKey('composer-body')),
              )
              .controller
              .document
              .toDelta()
              .toJson())
        if (op['insert'] case final Map insert)
          jsonDecode(insert['bojian-block'] as String) as Map<String, dynamic>,
    ];
    Future<void> fill(String title) async {
      await tester.enterText(find.byType(TextField).first, title);
      await tester.enterText(find.byType(TextField).last, '4');
      await tester.pumpAndSettle();
      await tester.tap(find.text('完成'));
      await tester.pumpAndSettle();
    }

    await tester.tap(find.byTooltip('更多'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('投票'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('问答'));
    await tester.pumpAndSettle();
    await fill('穆兰有几位大神师？');
    // Back on the writing page with the question in it, and nothing sent.
    expect(find.byType(StoryComposer), findsOneWidget);
    expect(find.text('穆兰有几位大神师？'), findsOneWidget);
    expect(placed().single['poll_id'], 31);
    expect(api.calls, isNot(contains('PostArticles')));

    // Changing it puts the new one where the old one was.
    api.documents['PostArticlePolls'] = question(33, '改过的题目');
    await tester.ensureVisible(find.byTooltip('编辑问答'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('编辑问答'));
    await tester.pumpAndSettle();
    await fill('改过的题目');
    expect(placed().single['poll_id'], 33);
    expect(api.calls, isNot(contains('PostArticles')));

    await tester.tap(find.text('发布'));
    await tester.pumpAndSettle();
    final blocks = (api.article!['content'] as Map)['blocks'] as List;
    expect(
      blocks.whereType<Map>().where((b) => b['kind'] == 'poll').single,
      containsPair('poll_id', 33),
    );
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('A closed poll can be saved in a draft but not published', (
    tester,
  ) async {
    final api = ComposerGateway();
    final store = await testStore(authenticated: true, api: api);
    addTearDown(store.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: StoryComposer(
          store: store,
          draft: const {
            'title': '过期的投票',
            'content': {
              'blocks': [
                {
                  'kind': 'poll',
                  'poll_id': 5,
                  'mode': 'poll',
                  'title': '去哪',
                  'options': ['山', '海'],
                  'ends_at': '2020-01-01T00:00:00Z',
                },
              ],
            },
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('重新发布'));
    await tester.pump();
    expect(find.textContaining('已过截止时间'), findsOneWidget);
    expect(api.calls, isNot(contains('PostArticles')));
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpWidget(const SizedBox());
  });

  for (final pictures in [maxArticleMedia, maxArticleMedia + 1]) {
    testWidgets('A post holds no more than nine pictures ($pictures)', (
      tester,
    ) async {
      final api = ComposerGateway();
      final store = await testStore(authenticated: true, api: api);
      addTearDown(store.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: StoryComposer(
            store: store,
            draft: {
              'title': '很多图片',
              'content': {
                'blocks': [
                  for (var i = 0; i < pictures; i++)
                    {
                      'kind': 'image',
                      'image': {'url': 'https://example.com/$i.png'},
                    },
                ],
              },
            },
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.byTooltip('图片或视频'));
      await tester.pump();
      expect(find.text('一条动态最多添加 9 个图片或视频'), findsOneWidget);
      expect(find.byType(ArticleMediaPicker), findsNothing);
      // The pictures never arrive here, so nothing ever comes to rest: clear
      // the first message by hand.
      ScaffoldMessenger.of(tester.element(find.byType(StoryComposer)))
          .removeCurrentSnackBar();
      await tester.pump();
      await tester.tap(find.text('重新发布'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      if (pictures > maxArticleMedia) {
        expect(find.textContaining('请删掉 1 个'), findsOneWidget);
        expect(api.calls, isNot(contains('PostArticlesIdPublish')));
      } else {
        expect(api.calls, contains('PostArticlesIdPublish'));
      }
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpWidget(const SizedBox());
    });
  }

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
