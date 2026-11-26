import 'dart:convert';

import 'package:bojian_mobile/app_store.dart';
import 'package:bojian_mobile/article_photo.dart';
import 'package:bojian_mobile/discovery.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

void main() {
  test('标题可空，列表摘要包含正文、图片、视频、投票、问答和链接', () {
    final story = decodeStory({
      'id': 7,
      'title': '',
      'content': {
        'blocks': [
          {
            'kind': 'paragraph',
            'spans': [
              {'text': '交流'},
            ],
          },
          {
            'kind': 'image',
            'image': {'file_id': 2, 'caption': '现场'},
          },
          {
            'kind': 'video',
            'video': {'file_id': 3},
          },
          {'kind': 'poll', 'poll_id': 5, 'title': '午餐'},
          {'kind': 'poll', 'poll_id': 7, 'mode': 'question', 'title': '哪一天'},
          {'kind': 'link', 'url': 'https://example.com/a'},
        ],
      },
    });
    expect(story.title, isEmpty);
    expect(
      story.excerpt,
      '交流\n[图片] 现场\n[视频]\n[投票] 午餐\n[问答] 哪一天\n[链接] https://example.com/a',
    );
    expect(articleListLabel({'content': story.content}), story.excerpt);
  });

  testWidgets('回复权限由服务端更新，旁观者可以阅读已有评论', (tester) async {
    final api = FakeGateway();
    final store = await testStore(authenticated: true, api: api);
    addTearDown(store.dispose);
    final post = {'id': 86, 'title': '', 'content': richContent('无标题动态正文')};
    final story = decodeStory(post);
    api.documents['GetArticlesId'] = {...post, 'can_comment': false};
    api.documents['GetArticlesIdComments'] = {
      'can_comment': false,
      'items': [
        {
          'id': 12,
          'author': {'id': 5, 'display_name': '读者'},
          'content': '既有回复',
        },
      ],
    };
    await tester.pumpWidget(
      MaterialApp(
        home: StoryDetail(store: store, story: story),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('无标题动态正文'), findsOneWidget);
    expect(find.text('既有回复'), findsOneWidget);
    expect(find.text('仅作者关注的人可以回复'), findsOneWidget);
    expect(find.byKey(const ValueKey('article-comment-input')), findsNothing);
    expect(find.text('回复'), findsNothing);
    api.documents['GetArticlesIdComments'] = {'can_comment': true, 'items': []};
    await store.article(story);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('article-comment-input')), findsOneWidget);
    expect(find.text('仅作者关注的人可以回复'), findsNothing);
  });

  testWidgets('已设置水印的旧图片点开放大后仍显示水印', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 300,
            height: 200,
            child: ArticleNetworkPhoto(
              url: 'https://image.example/img.png',
              imageProvider: MemoryImage(
                base64Decode(
                  'iVBORw0KGgoAAAANSUhEUgAAAAQAAAAECAIAAAAmkwkpAAAAEUlEQVR4nGNwmHAAjhiI4wAAglIZAaTN9MkAAAAASUVORK5CYII=',
                ),
              ),
              watermark: '作者小简',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('作者小简'), findsOneWidget);
    await tester.tap(find.text('作者小简'));
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.text('作者小简'), findsOneWidget);
  });
}
