import 'dart:async';

import 'package:bojian_mobile/api/bojian_api.dart';
import 'package:bojian_mobile/chat_history.dart';
import 'package:bojian_mobile/design.dart';
import 'package:bojian_mobile/messages_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

class ChatGateway extends FakeGateway {
  bool failSend = false;
  Completer<ApiDocument>? delayedHistory;
  final sentIDs = <String>[];
  final sentHeaders = <String>[];
  final historyQueries = <Map<String, String>>[];
  ChatGateway() {
    documents['GetNotifications'] = {
      'unread_count': 1,
      'items': [
        {
          'id': 5,
          'type': 'SYSTEM',
          'payload': {'title': '导出已完成', 'body': '你的文件已准备好'},
          'created_at': '2026-10-08T05:50:00Z',
          'read_at': null,
        },
      ],
    };
    documents['GetConversations'] = {
      'items': [
        {
          'id': 7,
          'peer': {'id': 2, 'display_name': '测试同事'},
          'last_message_id': 10,
          'last_message_type': 'TEXT',
          'last_message_payload': {'text': '简历已收到'},
          'last_message_at': '2026-10-08T05:50:00Z',
          'unread_count': 2,
        },
      ],
    };
  }
  @override
  Future<ApiDocument> call(
    String method, {
    Map<String, String> path = const {},
    Map<String, String> query = const {},
    Map<String, dynamic>? body,
    Map<String, String> headers = const {},
  }) async {
    if (method == 'GetConversationsIdMessages') {
      calls.add(method);
      historyQueries.add(Map.of(query));
      if (delayedHistory != null) return delayedHistory!.future;
      final more = query['cursor'] == '9';
      return ApiDocument({
        'items': more
            ? [
                {
                  'id': 8,
                  'sender_id': 2,
                  'type': 'TEXT',
                  'payload': {'text': '更早消息'},
                },
              ]
            : [
                {
                  'id': 10,
                  'sender_id': 2,
                  'type': 'TEXT',
                  'payload': {'text': '最新消息'},
                },
                {
                  'id': 9,
                  'sender_id': 1,
                  'type': 'TEXT',
                  'payload': {'text': '之前消息'},
                },
              ],
      }, nextCursor: more ? '' : '9');
    }
    if (method == 'PostConversationsIdMessages') {
      calls.add(method);
      sentIDs.add(body!['client_message_id'] as String);
      sentHeaders.add(headers['idempotency-key']!);
      if (failSend) throw const ApiFailure('发送失败');
      return ApiDocument({'id': 11, 'type': 'TEXT'});
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
  test('Notification and chat loading are independent and use actual conversation records', () async {
    final api = ChatGateway();
    final store = await testStore(authenticated: true, api: api);
    addTearDown(store.dispose);
    await store.load('messages');
    await store.load('chats');
    expect(store.unread, 3);
    expect(api.calls, isNot(contains('GetFriends')));
    expect(api.calls, isNot(contains('GetFriendRequests')));
    await store.markAllRead();
    expect(store.unread, 2);
    api.failing = 'GetNotifications';
    await store.load('messages');
    await store.load('chats');
    expect(store.errors['messages'], isNotNull);
    expect(store.errors['chats'], isNull);
    expect(store.conversations.single['peer']['display_name'], '测试同事');
  });

  test('History paginates without duplicates and marks only loaded conversation read', () async {
    final api = ChatGateway();
    final store = await testStore(authenticated: true, api: api);
    addTearDown(store.dispose);
    await store.load('chats');
    final history = ChatHistory(store, 7);
    addTearDown(history.dispose);
    await history.load();
    expect(history.messages.map((row) => row['id']), [9, 10]);
    expect(store.conversations.single['unread_count'], 0);
    await history.load(more: true);
    expect(history.messages.map((row) => row['id']), [8, 9, 10]);
    expect(api.historyQueries.last['cursor'], '9');
    expect(history.cursor, '');
  });

  test(
    'Retry preserves idempotency and failed send does not invent a message',
    () async {
      final api = ChatGateway();
      final store = await testStore(authenticated: true, api: api);
      addTearDown(store.dispose);
      final history = ChatHistory(store, 7);
      addTearDown(history.dispose);
      await history.load();
      api.failSend = true;
      expect(await history.send('用户输入的消息'), isFalse);
      expect(history.messages.length, 2);
      api.failSend = false;
      expect(await history.send('用户输入的消息'), isTrue);
      expect(api.sentIDs[0], api.sentIDs[1]);
      expect(api.sentHeaders[0], api.sentHeaders[1]);
      expect(history.messages.last['id'], 11);
      expect(chatMessageText(history.messages.last), '用户输入的消息');
    },
  );

  test(
    'Late history after logout cannot repopulate private messages',
    () async {
      final api = ChatGateway();
      final store = await testStore(authenticated: true, api: api);
      addTearDown(store.dispose);
      final history = ChatHistory(store, 7);
      addTearDown(history.dispose);
      api.delayedHistory = Completer<ApiDocument>();
      final request = history.load();
      await store.endSession();
      api.delayedHistory!.complete(
        ApiDocument({
          'items': [
            {
              'id': 10,
              'sender_id': 2,
              'type': 'TEXT',
              'payload': {'text': '私密消息'},
            },
          ],
        }),
      );
      await request;
      expect(history.messages, isEmpty);
      expect(await history.send('不能发送'), isFalse);
      expect(api.sentIDs, isEmpty);
    },
  );

  testWidgets(
    'Messages contain only system notifications and chat history, including landscape',
    (tester) async {
      final api = ChatGateway();
      final store = await testStore(authenticated: true, api: api);
      addTearDown(store.dispose);
      await store.load('messages');
      await store.load('chats');
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: Scaffold(body: MessagesPage(store: store)),
        ),
      );
      expect(find.text('系统通知'), findsOneWidget);
      expect(find.text('聊天记录'), findsOneWidget);
      expect(find.text('好友'), findsNothing);
      expect(find.text('添加好友'), findsNothing);
      expect(find.text('导出已完成'), findsOneWidget);
      await tester.tap(find.text('聊天记录'));
      await tester.pumpAndSettle();
      expect(find.text('测试同事'), findsOneWidget);
      expect(find.text('简历已收到'), findsOneWidget);
      await tester.tap(find.text('测试同事'));
      await tester.pumpAndSettle();
      expect(find.text('最新消息'), findsOneWidget);
      expect(find.text('之前消息'), findsOneWidget);
      expect(find.text('输入消息'), findsOneWidget);
      tester.view.physicalSize = const Size(844, 390);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Empty chat history stays truthful and errors offer retry', (
    tester,
  ) async {
    final api = FakeGateway();
    final store = await testStore(authenticated: true, api: api);
    addTearDown(store.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: Scaffold(body: MessagesPage(store: store)),
      ),
    );
    await tester.tap(find.text('聊天记录'));
    await tester.pumpAndSettle();
    expect(find.text('暂无聊天记录'), findsOneWidget);
    api.failing = 'GetConversations';
    await store.load('chats');
    await tester.pumpAndSettle();
    expect(find.text('服务器暂不可用'), findsOneWidget);
    expect(find.text('重新加载'), findsOneWidget);
    expect(find.text('暂无聊天记录'), findsNothing);
  });
}
