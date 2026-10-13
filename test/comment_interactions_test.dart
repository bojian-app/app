import 'package:bojian_mobile/app_store.dart';
import 'package:bojian_mobile/discovery.dart';
import 'package:bojian_mobile/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

void main() {
  testWidgets(
    'Replies target the selected comment; reactions use server state and failures retain it',
    (tester) async {
      final api = FakeGateway();
      api.documents['GetArticlesIdComments'] = {
        'total': 1,
        'items': [
          {
            'id': 10,
            'author': {'id': 2, 'display_name': '阿明'},
            'content': '原评论',
            'reply_count': 1,
          },
        ],
      };
      api.documents['GetArticlesIdCommentsCommentIDReplies'] = {
        'items': [
          {
            'id': 11,
            'parent_id': 10,
            'author': {'id': 3, 'display_name': '小陈'},
            'reply_to': {'display_name': '阿明'},
            'content': '已有回复',
          },
        ],
      };
      api.documents['PutArticlesIdCommentsCommentIDLike'] = {
        'like_count': 3,
        'is_liked': true,
        'dislike_count': 0,
        'is_disliked': false,
      };
      api.documents['PutArticlesIdCommentsCommentIDDislike'] = {
        'like_count': 2,
        'is_liked': false,
        'dislike_count': 1,
        'is_disliked': true,
      };
      final store = await testStore(authenticated: true, api: api);
      final story = Story(
        id: 1,
        title: '测试文章',
        author: '作者',
        role: '',
        category: '',
        excerpt: '',
        paragraphs: [],
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: StoryDetail(story: story, store: store),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('comment-like-10')));
      await tester.tap(find.byKey(const ValueKey('comment-like-10')));
      await tester.pumpAndSettle();
      expect(story.comments.single.likes, 3);
      expect(story.comments.single.liked, true);
      expect(find.text('回复 阿明'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('comment-dislike-10')));
      await tester.pumpAndSettle();
      expect(story.comments.single.disliked, true);
      expect(story.comments.single.liked, false);
      api.failing = 'DeleteArticlesIdCommentsCommentIDDislike';
      await tester.tap(find.byKey(const ValueKey('comment-dislike-10')));
      await tester.pumpAndSettle();
      expect(story.comments.single.disliked, true);
      api.failing = null;
      await tester.ensureVisible(find.text('展开 1 条回复'));
      await tester.tap(find.text('展开 1 条回复'));
      await tester.pumpAndSettle();
      expect(find.text('已有回复'), findsOneWidget);
      expect(find.text('回复'), findsNWidgets(2));
      await tester.ensureVisible(find.text('原评论'));
      await tester.tap(find.text('原评论'));
      await tester.pumpAndSettle();
      expect(find.text('回复 阿明'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '我的回复');
      await tester.pump();
      api.failing = 'PostArticlesIdComments';
      await tester.tap(find.byTooltip('发送评论'));
      await tester.pumpAndSettle();
      expect(api.lastBody?['reply_to_id'], 10);
      expect(find.text('我的回复'), findsOneWidget);
      expect(find.text('回复 阿明'), findsOneWidget);
      await tester.tap(find.byTooltip('取消回复'));
      await tester.pumpAndSettle();
      expect(find.text('回复 阿明'), findsNothing);
      expect(find.text('我的回复'), findsOneWidget);
      await tester.ensureVisible(find.text('已有回复'));
      await tester.tap(find.text('已有回复'));
      await tester.pumpAndSettle();
      expect(find.text('回复 小陈'), findsOneWidget);
      await tester.tap(find.byTooltip('发送评论'));
      await tester.pumpAndSettle();
      expect(api.lastBody?['reply_to_id'], 11);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    },
  );
  testWidgets(
    'Compact article threads preserve reply targeting above the keyboard',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      final api = FakeGateway();
      api.documents['GetArticlesIdComments'] = {
        'total': 3,
        'items': [
          {
            'id': 10,
            'author': {'id': 2, 'display_name': '阿明'},
            'content': '原评论',
            'reply_count': 1,
          },
          {
            'id': 20,
            'author': {'id': 3, 'display_name': ''},
            'content': '另一条评论',
          },
        ],
      };
      api.documents['GetArticlesIdCommentsCommentIDReplies'] = {
        'items': [
          {
            'id': 11,
            'parent_id': 10,
            'author': {'id': 4, 'display_name': '小陈'},
            'reply_to': {'display_name': '阿明'},
            'content': '已有回复',
          },
        ],
      };
      final store = await testStore(authenticated: true, api: api);
      addTearDown(store.dispose);
      final story = Story(
        id: 1,
        title: '测试文章',
        author: '作者',
        role: '',
        category: '',
        excerpt: '',
        paragraphs: [],
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!,
          ),
          home: StoryDetail(story: story, store: store),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('评论（3）'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('article-comment-send')),
            )
            .onPressed,
        isNull,
      );
      expect(find.text('已有回复'), findsNothing);
      await tester.ensureVisible(find.text('展开 1 条回复'));
      await tester.tap(find.text('展开 1 条回复'));
      await tester.pumpAndSettle();
      final root = find.byKey(const ValueKey('comment-conversation-10'));
      final child = find.byKey(const ValueKey('comment-conversation-11'));
      expect(
        tester.getTopLeft(child).dx,
        greaterThan(tester.getTopLeft(root).dx),
      );
      expect(find.text('未设置用户昵称'), findsOneWidget);
      await tester.ensureVisible(child);
      await tester.tap(child);
      await tester.pumpAndSettle();
      expect(find.text('回复 小陈'), findsOneWidget);
      final field = find.byKey(const ValueKey('article-comment-input'));
      await tester.enterText(field, '多行回复内容\n第二行回复内容');
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      expect(tester.getRect(field).bottom, lessThanOrEqualTo(340));
      expect(
        tester
            .getRect(find.byKey(const ValueKey('article-comment-send')))
            .bottom,
        lessThanOrEqualTo(340),
      );
      expect(tester.takeException(), isNull);
      api.failing = 'PostArticlesIdComments';
      await tester.tap(find.byTooltip('发送评论'));
      await tester.pumpAndSettle();
      expect(api.lastBody?['reply_to_id'], 11);
      expect(find.text('发送失败，请重试'), findsOneWidget);
      expect(find.text('回复 小陈'), findsOneWidget);
      expect(
        tester.widget<TextField>(field).controller!.text,
        contains('第二行回复内容'),
      );
      tester.view.viewInsets = FakeViewPadding.zero;
      await tester.tap(find.byTooltip('取消回复'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('收起回复'));
      await tester.tap(find.text('收起回复'));
      await tester.pumpAndSettle();
      expect(find.text('已有回复'), findsNothing);
      final requestCount = api.calls
          .where((call) => call == 'GetArticlesIdCommentsCommentIDReplies')
          .length;
      await tester.ensureVisible(find.text('展开 1 条回复'));
      await tester.tap(find.text('展开 1 条回复'));
      await tester.pumpAndSettle();
      expect(find.text('已有回复'), findsOneWidget);
      expect(
        api.calls
            .where((call) => call == 'GetArticlesIdCommentsCommentIDReplies')
            .length,
        requestCount,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
