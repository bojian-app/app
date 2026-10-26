import 'dart:async';

import 'package:bojian_mobile/api/bojian_api.dart';
import 'package:bojian_mobile/app_store.dart';
import 'package:bojian_mobile/design.dart';
import 'package:bojian_mobile/discovery.dart';
import 'package:bojian_mobile/messages_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

class DelayedSubmissionGateway extends FakeGateway {
  Completer<ApiDocument> response = Completer();
  final keys = <String>[];
  @override
  Future<ApiDocument> call(
    String method, {
    Map<String, String> path = const {},
    Map<String, String> query = const {},
    Map<String, dynamic>? body,
    Map<String, String> headers = const {},
  }) {
    if (method == 'PostArticlesIdComments') {
      keys.add(headers['idempotency-key']!);
      return response.future;
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
  testWidgets(
    'Sending feedback is immediate; failure retains text and retries the same request',
    (tester) async {
      final api = DelayedSubmissionGateway();
      final store = await testStore(authenticated: true, api: api);
      final story = decodeStory({
        'id': 8,
        'title': '测试文章',
        'content': richContent('正文'),
        'comment_count': 0,
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: StoryDetail(store: store, story: story),
        ),
      );
      await tester.pumpAndSettle();
      final input = find.byKey(const ValueKey('article-comment-input'));
      await tester.enterText(input, '我提交的评论');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('article-comment-send')));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(input).controller!.text, isEmpty);
      expect(find.text('我提交的评论'), findsOneWidget);
      expect(find.text('发送中…'), findsOneWidget);
      expect(story.commentCount, 0);
      api.response.completeError(const ApiFailure('网络暂不可用'));
      await tester.pumpAndSettle();
      expect(find.text('发送失败'), findsOneWidget);
      expect(find.text('我提交的评论'), findsOneWidget);
      api.response = Completer();
      await tester.tap(find.text('重试'));
      await tester.pumpAndSettle();
      expect(api.keys.length, 2);
      expect(api.keys[0], api.keys[1]);
      api.response.complete(ApiDocument({'id': 21, 'status': 'QUEUED'}));
      await tester.pumpAndSettle();
      expect(find.text('审核中 · 仅自己可见'), findsOneWidget);
      api.documents['GetArticlesIdComments'] = {
        'total': 0,
        'items': [
          {
            'id': 21,
            'status': 'REJECTED',
            'content': '我提交的评论',
            'author': {'id': store.userID, 'display_name': '我'},
            'review_reason': '侮辱、诽谤他人',
          },
        ],
      };
      await store.article(story);
      await tester.pumpAndSettle();
      expect(store.contentSubmissions, isEmpty);
      expect(find.text('未通过审核 · 仅自己可见'), findsOneWidget);
      expect(find.text('侮辱、诽谤他人'), findsOneWidget);
      await tester.tap(find.text('修改后重发'));
      await tester.pump();
      expect(tester.widget<TextField>(input).controller!.text, '我提交的评论');
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    },
  );
  test('Unacknowledged submission survives navigation/restart and never crosses accounts', () async {
    final api = DelayedSubmissionGateway();
    final store = await testStore(authenticated: true, api: api);
    store.enqueueContent('PostArticlesIdComments', 8, {'content': '重试草稿'});
    await store.contentWrites;
    final key = store.contentSubmissions.single['request_key'];
    store.contentSubmissions.clear();
    await store.restoreContentSubmissions();
    expect(store.contentSubmissions.single['moderation_status'], 'FAILED');
    expect(store.contentSubmissions.single['content'], '重试草稿');
    expect(store.contentSubmissions.single['request_key'], key);
    await store.endSession(remote: false);
    expect(store.contentSubmissions, isEmpty);
    api.response.complete(ApiDocument({'id': 21, 'status': 'QUEUED'}));
    await Future<void>.delayed(Duration.zero);
    expect(store.contentSubmissions, isEmpty);
    store.dispose();
  });
  testWidgets(
    'A rejection notification displays the reason and opens its article',
    (tester) async {
      final api = FakeGateway();
      api.documents['GetNotifications'] = {
        'unread_count': 1,
        'items': [
          {
            'id': 80,
            'type': 'CONTENT_REJECTED',
            'subject_type': 'ARTICLE',
            'subject_id': 8,
            'payload': {
              'title': '内容未通过审核',
              'body': '侮辱、诽谤他人',
              'review_reason': '侮辱、诽谤他人',
            },
          },
        ],
      };
      api.documents['GetArticlesId'] = {
        'id': 8,
        'title': '测试文章',
        'content': richContent('正文'),
      };
      final store = await testStore(authenticated: true, api: api);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: Scaffold(body: MessagesPage(store: store)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('侮辱、诽谤他人'), findsOneWidget);
      await tester.tap(find.text('内容未通过审核'));
      await tester.pumpAndSettle();
      expect(find.byType(StoryDetail), findsOneWidget);
      expect(store.inbox.single.read, isTrue);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    },
  );
}
