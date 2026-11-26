import 'package:bojian_mobile/api/bojian_api.dart';
import 'package:bojian_mobile/app_store.dart';
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

class _CountedNotification extends InboxItem {
  _CountedNotification(int id)
    : super('通知 $id', '通知正文', '2026-10-08T05:50:00Z', 0, id: id, read: true);

  int timeReads = 0;

  @override
  String get time {
    timeReads++;
    return super.time;
  }
}

void main() {
  testWidgets('长通知列表只格式化视口附近的通知，滚动后加载其余行', (tester) async {
    final store = await testStore(authenticated: true);
    addTearDown(store.dispose);
    final entries = List.generate(500, _CountedNotification.new);
    store.inbox.addAll(entries);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: MessagesPage(store: store)),
      ),
    );
    await tester.pumpAndSettle();
    final built = entries.where((item) => item.timeReads > 0).length;
    expect(built, inExclusiveRange(0, 40));
    expect(entries.last.timeReads, 0);
    final list = Scrollable.of(tester.element(find.text('通知 0'))).position;
    list.jumpTo(list.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(find.text('通知 499'), findsOneWidget);
  });

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
            ...notification(5, type: 'RESUME_CREATION_FAILED'),
            'subject_type': 'RESUME_CREATION_JOB',
            'payload': {'title': 'AI简历生成未完成', 'body': '本次生成暂未成功，请重新生成简历。' * 4},
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
        find.textContaining('本次生成暂未成功，请重新生成简历。'),
      );
      expect(body.maxLines, isNull);
      expect(
        find.ancestor(
          of: find.text('AI简历生成未完成'),
          matching: find.byType(InkWell),
        ),
        findsNothing,
      );
      await tester.tap(find.text('AI简历生成未完成'));
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
