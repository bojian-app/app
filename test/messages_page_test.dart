import 'package:bojian_mobile/api/bojian_api.dart';
import 'package:bojian_mobile/design.dart';
import 'package:bojian_mobile/messages_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

Map<String, dynamic> notification(int id, {String type = 'SYSTEM'}) => {
  'id': id,
  'type': type,
  'payload': {'title': '通知 $id', 'body': '内容 $id'},
  'created_at': '2026-10-08T05:50:00Z',
  'read_at': null,
};

/// Serves notifications 40..1 in pages of 20.
class PagedGateway extends FakeGateway {
  final pages = <String>[];
  @override
  Future<ApiDocument> call(
    String method, {
    Map<String, String> path = const {},
    Map<String, String> query = const {},
    Map<String, dynamic>? body,
    Map<String, String> headers = const {},
  }) async {
    if (method == 'GetNotifications') {
      calls.add(method);
      final cursor = query['cursor'] ?? '';
      pages.add(cursor);
      final first = cursor.isEmpty ? 40 : 20;
      return ApiDocument({
        'unread_count': 0,
        'items': [
          for (var id = first; id > first - 20; id--)
            {...notification(id), 'read_at': '2026-10-08T05:50:00Z'},
        ],
      }, nextCursor: cursor.isEmpty ? '20' : '');
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
  testWidgets('Messages list only system notifications, including landscape', (
    tester,
  ) async {
    final api = FakeGateway();
    api.documents['GetNotifications'] = {
      'unread_count': 1,
      'items': [
        {
          ...notification(5),
          'payload': {'title': '导出已完成', 'body': '你的文件已准备好'},
        },
      ],
    };
    final store = await testStore(authenticated: true, api: api);
    addTearDown(store.dispose);
    await store.load('messages');
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: Scaffold(body: MessagesPage(store: store)),
      ),
    );
    expect(find.text('导出已完成'), findsOneWidget);
    expect(find.text('你的文件已准备好'), findsOneWidget);
    expect(find.text('聊天记录'), findsNothing);
    expect(find.text('系统通知'), findsNothing);
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'A notification with nothing to open shows its full text, opens no sheet and reads itself',
    (tester) async {
      final api = FakeGateway();
      api.documents['GetNotifications'] = {
        'unread_count': 1,
        'items': [
          {
            ...notification(5, type: 'LOGIN_SUCCEEDED'),
            'payload': {'title': '官网登录成功', 'body': '你的博简账号已通过 App 扫码登录官网。' * 4},
          },
        ],
      };
      final store = await testStore(authenticated: true, api: api);
      addTearDown(store.dispose);
      await store.load('messages');
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: Scaffold(body: MessagesPage(store: store)),
        ),
      );
      await tester.pumpAndSettle();
      final body = tester.widget<Text>(
        find.textContaining('你的博简账号已通过 App 扫码登录官网。'),
      );
      expect(body.maxLines, isNull);
      expect(
        find.ancestor(of: find.text('官网登录成功'), matching: find.byType(InkWell)),
        findsNothing,
      );
      await tester.tap(find.text('官网登录成功'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(api.calls, contains('PostNotificationsRead'));
      expect(store.inbox.single.read, isTrue);
    },
  );

  testWidgets('Scrolling near the end loads the next page by itself', (
    tester,
  ) async {
    final api = PagedGateway();
    final store = await testStore(authenticated: true, api: api);
    addTearDown(store.dispose);
    await store.load('messages');
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: Scaffold(body: MessagesPage(store: store)),
      ),
    );
    await tester.pumpAndSettle();
    api.pages.clear();
    expect(find.text('加载更多'), findsNothing);
    expect(store.inbox, hasLength(20));
    await tester.fling(find.byType(ListView), const Offset(0, -3000), 3000);
    await tester.pumpAndSettle();
    expect(api.pages, ['20']);
    expect(store.inbox, hasLength(40));
    await tester.fling(find.byType(ListView), const Offset(0, -6000), 3000);
    await tester.pumpAndSettle();
    expect(api.pages, ['20']);
  });

  testWidgets('Empty notifications stay truthful and errors offer retry', (
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
    await store.load('messages');
    await tester.pumpAndSettle();
    expect(find.text('暂无系统通知'), findsOneWidget);
    api.failing = 'GetNotifications';
    await store.load('messages');
    await tester.pumpAndSettle();
    expect(find.text('服务器暂不可用'), findsOneWidget);
    expect(find.text('重新加载'), findsOneWidget);
    expect(find.text('暂无系统通知'), findsNothing);
  });
}
