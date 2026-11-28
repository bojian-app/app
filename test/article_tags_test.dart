import 'package:bojian_mobile/app_store.dart';
import 'package:bojian_mobile/article_tags.dart';
import 'package:bojian_mobile/article_topic.dart';
import 'package:bojian_mobile/design.dart';
import 'package:bojian_mobile/discovery.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

Map<String, dynamic> paragraph(List<Map<String, dynamic>> spans) => {
  'kind': 'paragraph',
  'spans': spans,
};

Map<String, dynamic> tag(String name) => {'text': '#$name#', 'topic': name};

void main() {
  test('Tags leave the writing, except one that is part of a sentence', () {
    final split = splitArticleTags({
      'blocks': [
        paragraph([
          tag('开头'),
          {'text': ' 正文 '},
          tag('结尾'),
          {'text': ' '},
        ]),
        paragraph([
          {'text': ''},
        ]),
        paragraph([
          {'text': '聊聊'},
          tag('句中'),
          {'text': '的事'},
        ]),
        articleTagBlock(['结尾', '面试']),
      ],
    });
    expect(split.tags, ['开头', '结尾', '面试']);
    expect(split.body['blocks'], [
      paragraph([
        {'text': '正文'},
      ]),
      // A line the author left blank is kept.
      paragraph([
        {'text': ''},
      ]),
      paragraph([
        {'text': '聊聊'},
        tag('句中'),
        {'text': '的事'},
      ]),
    ]);
    expect(splitArticleTags({'text': '旧格式'}).tags, isEmpty);
  });

  testWidgets('A feed card and its post show tags apart from the writing', (
    tester,
  ) async {
    final content = {
      'blocks': [
        paragraph([
          {'text': '面试很顺利'},
        ]),
        articleTagBlock(['求职', '面试']),
      ],
    };
    final api = FakeGateway()
      ..documents['GetArticlesId'] = {
        'id': 5,
        'status': 'PUBLISHED',
        'content': content,
      };
    final store = await testStore(authenticated: true, api: api);
    addTearDown(store.dispose);
    final story = decodeStory({'id': 5, 'title': '', 'content': content});
    expect(story.tags, ['求职', '面试']);
    expect(story.excerpt, '面试很顺利');
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: Scaffold(
          body: SingleChildScrollView(
            child: StoryCard(story: story, store: store, flat: true),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('面试很顺利'), findsOneWidget);
    expect(find.textContaining('#求职#'), findsNothing);
    expect(find.text('# 求职'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('# 求职')).dy,
      greaterThan(tester.getBottomLeft(find.text('面试很顺利')).dy),
    );

    await tester.tap(find.text('面试很顺利'));
    await tester.pumpAndSettle();
    expect(find.byType(StoryDetail), findsOneWidget);
    expect(find.textContaining('#求职#'), findsNothing);
    expect(find.byKey(const ValueKey('article-tag-面试')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('article-tag-面试')));
    await tester.pumpAndSettle();
    expect(find.text('返回'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Stacked tags fan out on a tap and then open their topic', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 640);
    addTearDown(tester.view.reset);
    const names = ['新人加入', 'I人', '水土不服', '帅气逼人', '文质彬彬', '秋招', '很长很长的话题名称用来换行'];
    final api = FakeGateway();
    final store = await testStore(authenticated: true, api: api);
    addTearDown(store.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Align(
              alignment: Alignment.topLeft,
              child: ArticleTagRow(
                tags: names,
                store: store,
                collapsible: true,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // Signing in loads the home feed; only what the tags ask for counts.
    api.calls.clear();
    Rect place(String name) =>
        tester.getRect(find.byKey(ValueKey('article-tag-$name')));
    final row = find.byType(ArticleTagRow);
    final closed = tester.getSize(row).height;
    expect(find.textContaining('共'), findsNothing);
    expect(find.text('收起'), findsNothing);
    expect(find.text('# 新人加入'), findsOneWidget);
    // One line, each tag reaching a step past the one above it.
    for (var i = 1; i < 5; i++) {
      expect(place(names[i]).top, place(names[0]).top);
      expect(place(names[i]).right, greaterThan(place(names[i - 1]).right));
    }
    expect(place(names[6]).right, place(names[4]).right);
    expect(place(names[4]).right, lessThanOrEqualTo(360 - 16 + .5));

    // The first tap only opens the stack.
    await tester.tap(find.byKey(const ValueKey('article-tag-新人加入')));
    await tester.pumpAndSettle();
    expect(api.calls, isNot(contains('GetFeed')));
    expect(find.text('收起'), findsOneWidget);
    expect(tester.getSize(row).height, greaterThan(closed));
    for (var i = 0; i < names.length; i++) {
      expect(place(names[i]).right, lessThanOrEqualTo(360 - 16 + .5));
      for (var j = 0; j < i; j++) {
        expect(
          place(names[i]).overlaps(place(names[j])),
          isFalse,
          reason: '${names[i]} over ${names[j]}',
        );
      }
    }

    await tester.tap(find.text('收起'));
    await tester.pumpAndSettle();
    expect(tester.getSize(row).height, closed);
    await tester.tap(find.byKey(const ValueKey('article-tag-新人加入')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('article-tag-水土不服')));
    await tester.pumpAndSettle();
    expect(find.text('返回'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('A single tag opens its topic straight away', (tester) async {
    final store = await testStore(authenticated: true);
    addTearDown(store.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: Scaffold(
          body: ArticleTagRow(
            tags: const ['求职'],
            store: store,
            collapsible: true,
          ),
        ),
      ),
    );
    expect(find.byKey(const ValueKey('article-tags-toggle')), findsNothing);
    await tester.tap(find.text('# 求职'));
    await tester.pumpAndSettle();
    // The topic page is headed "返回", and the word itself goes back.
    await tester.tap(find.text('返回'));
    await tester.pumpAndSettle();
    expect(find.text('返回'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  test('A post of nothing but a poll stays one when it is tagged', () {
    final story = decodeStory({
      'id': 6,
      'title': '',
      'content': {
        'blocks': [
          {'kind': 'poll', 'poll_id': 3, 'title': '去哪'},
          articleTagBlock(['周末']),
        ],
      },
    });
    expect(story.feedPoll, isNotNull);
    expect(story.tags, ['周末']);
  });
}
