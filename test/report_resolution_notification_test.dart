import 'package:bojian_mobile/app_store.dart';
import 'package:bojian_mobile/content_moderation.dart';
import 'package:bojian_mobile/design.dart';
import 'package:bojian_mobile/messages_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';
import 'realtime_test.dart' show TestSocket;

void main() {
  for (final entry in {
    'REPORT_RESOLVED': '举报已成立',
    'REPORT_DISMISSED': '举报未成立',
    'REPORT_CONTENT_REMOVED': '内容已被撤回',
  }.entries) {
    testWidgets(
      '${entry.key} opens result even when the content is unavailable',
      (tester) async {
        final api = FakeGateway()..failing = 'GetArticlesId';
        api.documents['GetNotifications'] = {
          'unread_count': 1,
          'items': [
            {
              'id': 20,
              'type': entry.key,
              'subject_type': 'REPORT',
              'subject_id': 9,
              'payload': {'body': '经核查，相关内容已处理。处理说明：测试说明'},
              'created_at': '2026-10-23T07:00:00Z',
            },
          ],
        };
        final store = await testStore(authenticated: true, api: api);
        addTearDown(store.dispose);
        await tester.pumpWidget(
          MaterialApp(
            theme: appTheme,
            home: Scaffold(body: MessagesPage(store: store)),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(entry.value));
        await tester.pumpAndSettle();
        expect(find.text('举报处理结果'), findsOneWidget);
        expect(find.byType(SelectableText), findsOneWidget);
        expect(store.inbox.single.read, isTrue);
        expect(api.calls, isNot(contains('GetArticlesId')));
        expect(tester.takeException(), isNull);
      },
    );
  }
  test(
    'Withdrawal removes cached article; private share IDs do not collide',
    () async {
      final api = FakeGateway();
      api.documents['PostRealtimeToken'] = {
        'token': 'test',
        'websocket_path': '/api/v1/realtime',
      };
      final socket = TestSocket();
      final store = AppStore(
        api: api,
        storage: MemoryStorage(),
        realtimeConnector: (_) async => socket,
      );
      addTearDown(store.dispose);
      await store.initialize();
      await store.signIn('13812345678', '654321');
      await Future<void>.delayed(const Duration(milliseconds: 250));
      store.stories.add(decodeStory({'id': 8, 'title': '已撤回文章'}));
      socket.event('content.removed', 1, {
        'subject_type': 'ARTICLE',
        'subject_id': 8,
        'article_id': 8,
      });
      await Future<void>.delayed(const Duration(milliseconds: 250));
      expect(store.stories.where((story) => story.id == 8), isEmpty);
      final event = <String, dynamic>{
        'type': 'content.removed',
        'data': {'share_scope': 'NOTIFICATION', 'share_id': 8},
      };
      expect(guidanceRemovalAffects(event, 8, true), isTrue);
      expect(guidanceRemovalAffects(event, 8, false), isFalse);
      expect(guidanceRemovalAffects(event, 9, true), isFalse);
    },
  );
}
