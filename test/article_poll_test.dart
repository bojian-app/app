import 'package:bojian_mobile/app_store.dart';
import 'package:bojian_mobile/article_poll.dart';
import 'package:bojian_mobile/discovery.dart';
import 'package:bojian_mobile/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

void main() {
  testWidgets('Question saves privately and returns a public article block', (
    tester,
  ) async {
    final api = FakeGateway();
    const block = {
      'kind': 'poll',
      'poll_id': 9,
      'title': '今天的练习',
      'mode': 'question',
      'has_correct_answer': true,
    };
    api.documents['PostArticlePolls'] = block;
    final store = await testStore(api: api, authenticated: true);
    addTearDown(store.dispose);
    Map<String, dynamic>? returned;
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                returned = await openArticlePollComposer(context, store);
              },
              child: const Text('插入投票'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('插入投票'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('问答'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '今天的练习');
    await tester.enterText(find.byType(TextField).last, '测试答案');
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('确定退出编辑吗？'), findsOneWidget);
    await tester.tap(find.text('继续编辑'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();
    expect(returned, block);
    expect(api.lastMutationBody?['answer'], '测试答案');
    expect(api.lastMutationBody?['request_key'], isNotEmpty);
    expect(returned?.containsKey('answer'), false);
  });
  testWidgets(
    'Read-only preview does not vote and published card displays actual results',
    (tester) async {
      final api = FakeGateway();
      const block = {
        'kind': 'poll',
        'mode': 'poll',
        'poll_id': 7,
        'title': '选一个',
        'options': ['甲', '乙'],
      };
      api.documents['GetArticlesIdPollsPollID'] = {
        'responded': false,
        'closed': false,
        'participants': 0,
      };
      api.documents['PostArticlesIdPollsPollID'] = {
        'responded': true,
        'closed': false,
        'participants': 1,
        'counts': [0, 1],
        'selections': [1],
      };
      final store = await testStore(authenticated: true, api: api);
      addTearDown(store.dispose);
      Widget card(int? id) => MaterialApp(
        theme: appTheme,
        home: Scaffold(
          body: ArticlePollCard(store: store, articleID: id, block: block),
        ),
      );
      await tester.pumpWidget(card(null));
      await tester.pumpAndSettle();
      expect(api.calls, isNot(contains('GetArticlesIdPollsPollID')));
      await tester.pumpWidget(card(1));
      await tester.pumpAndSettle();
      await tester.tap(find.text('乙'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('投票'));
      await tester.pumpAndSettle();
      expect(api.lastMutationBody?['selections'], [1]);
      expect(find.text('1人参与'), findsOneWidget);
      expect(find.text('1 (100.0%)'), findsOneWidget);
      expect(find.text('已投票'), findsOneWidget);
      expect(find.text('投票'), findsNothing);
    },
  );

  testWidgets('A poll-only post is voted on in the feed without reactions', (
    tester,
  ) async {
    final api = FakeGateway();
    const poll = {
      'kind': 'poll',
      'mode': 'poll',
      'poll_id': 7,
      'title': '选一个',
      'options': ['甲', '乙'],
      'ends_at': '2099-12-02T13:31:00+08:00',
    };
    api.documents['GetArticlesIdPollsPollID'] = {
      'responded': false,
      'closed': false,
      'participants': 0,
    };
    api.documents['PostArticlesIdPollsPollID'] = {
      'responded': true,
      'closed': false,
      'participants': 1,
      'counts': [0, 1],
      'selections': [1],
    };
    final store = await testStore(authenticated: true, api: api);
    addTearDown(store.dispose);
    Story story(List<Map<String, dynamic>> blocks) => Story(
      id: 5,
      title: '',
      author: '作者',
      role: '',
      category: '',
      excerpt: '[投票] 选一个',
      paragraphs: const [],
      content: {'blocks': blocks},
    );
    Widget feed(Story value) => MaterialApp(
      theme: appTheme,
      home: Scaffold(
        body: SingleChildScrollView(
          child: StoryCard(story: value, store: store, flat: true),
        ),
      ),
    );
    await tester.pumpWidget(
      feed(
        story([
          {
            'kind': 'paragraph',
            'spans': [
              {'text': ''},
            ],
          },
          poll,
        ]),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('story-like-5')), findsNothing);
    expect(find.byKey(const ValueKey('story-bookmark-5')), findsNothing);
    expect(find.byIcon(Icons.mode_comment_outlined), findsNothing);
    expect(find.text('投票'), findsNothing);
    await tester.tap(find.text('乙'));
    await tester.pumpAndSettle();
    expect(api.lastMutationBody?['selections'], [1]);
    expect(find.text('100%'), findsOneWidget);
    expect(find.text('0%'), findsOneWidget);
    expect(find.byType(StoryDetail), findsNothing);
    expect(find.text('单选投票'), findsNothing);
    expect(find.textContaining('人参与'), findsNothing);
    expect(find.textContaining('截止'), findsOneWidget);
    await tester.tap(find.text('[投票] 选一个'));
    await tester.pumpAndSettle();
    expect(find.byType(StoryDetail), findsNothing);

    await tester.pumpWidget(
      feed(
        story([
          {
            'kind': 'paragraph',
            'spans': [
              {'text': '正文'},
            ],
          },
          poll,
        ]),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('story-like-5')), findsOneWidget);
    expect(find.byKey(const ValueKey('story-bookmark-5')), findsOneWidget);
  });

  testWidgets('The poll composer keeps the page gutters on both sides', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final store = await testStore(authenticated: true);
    addTearDown(store.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => openArticlePollComposer(context, store),
              child: const Text('插入投票'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('插入投票'));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('取消')).dx, appPageHorizontalPadding);
    expect(
      tester.getTopRight(find.text('完成')).dx,
      360 - appPageHorizontalPadding,
    );
    // The form below starts on the same gutter.
    expect(
      tester.getTopLeft(find.text('投票').first).dx,
      greaterThanOrEqualTo(appPageHorizontalPadding),
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
  });

  testWidgets('A wrong answer is told what the correct one was', (
    tester,
  ) async {
    final api = FakeGateway();
    const block = {
      'kind': 'poll',
      'mode': 'question',
      'poll_id': 3,
      'title': '穆兰有几位大神师？',
    };
    api.documents['GetArticlesIdPollsPollID'] = {
      'responded': true,
      'closed': false,
      'participants': 1,
      'correct': false,
      'correct_answer': '4',
    };
    final store = await testStore(authenticated: true, api: api);
    addTearDown(store.dispose);
    for (final embedded in [true, false]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: Scaffold(
            body: ArticlePollCard(
              store: store,
              articleID: 1,
              block: block,
              embedded: embedded,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('回答错啦！正确答案是：4'), findsOneWidget);
      expect(find.text('回答错误'), findsNothing);
    }
    // A right answer is congratulated, with the answer.
    api.documents['GetArticlesIdPollsPollID'] = {
      'responded': true,
      'closed': false,
      'participants': 1,
      'correct': true,
      'correct_answer': '4',
    };
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: Scaffold(
          body: ArticlePollCard(store: store, articleID: 1, block: block),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('恭喜你，答对啦！正确答案是：4'), findsOneWidget);
    // Servers that do not reveal it still read naturally.
    api.documents['GetArticlesIdPollsPollID'] = {
      'responded': true,
      'closed': false,
      'participants': 1,
      'correct': false,
    };
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: Scaffold(
          body: ArticlePollCard(store: store, articleID: 1, block: block),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('回答错啦！'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
