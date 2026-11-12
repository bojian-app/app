import 'dart:async';
import 'dart:convert';

import 'package:bojian_mobile/api/bojian_api.dart';
import 'package:bojian_mobile/app_store.dart';
import 'package:bojian_mobile/realtime_client.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

class TestSocket implements RealtimeSocket {
  final input = StreamController<dynamic>();
  bool closed = false;
  @override
  Stream<dynamic> get messages => input.stream;
  void event(String type, int cursor, [Map<String, dynamic> data = const {}]) =>
      input.add(jsonEncode({'type': type, 'cursor': '$cursor', 'data': data}));
  @override
  Future<void> close() async {
    if (closed) return;
    closed = true;
    unawaited(input.close());
  }
}

Future<void> flush() => Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  test(
    'ordered delivery, malformed frames, cursor dedup and reconnect',
    () async {
      final sockets = <TestSocket>[];
      final uris = <Uri>[];
      final received = <int>[];
      final client = RealtimeClient(
        baseURL: Uri.parse('https://example.com/api/v1'),
        credentials: () async => {
          'token': 'fixture',
          'websocket_path': '/api/v1/realtime',
        },
        connect: (uri) async {
          uris.add(uri);
          final s = TestSocket();
          sockets.add(s);
          return s;
        },
        onConnected: () {},
        onEvent: (event) async {
          await flush();
          received.add(int.parse(event['cursor']));
        },
      );
      addTearDown(() => client.stop());
      client.start();
      await flush();
      expect(uris.single.scheme, 'wss');
      expect(uris.single.queryParameters['token'], 'fixture');
      sockets.single.input.add('malformed');
      sockets.single.event('message.created', 1);
      sockets.single.event('message.created', 1);
      sockets.single.event('message.created', 2);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(received, [1, 2]);
      await sockets.single.close();
      await Future<void>.delayed(const Duration(milliseconds: 1150));
      expect(sockets.length, 2);
      expect(uris.last.queryParameters['cursor'], '2');
      sockets.last.event('message.created', 2);
      sockets.last.event('message.created', 3);
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(received, [1, 2, 3]);
      await client.stop(resetCursor: true);
      expect(client.cursor, '0');
      expect(sockets.last.closed, true);
    },
  );

  test(
    'first connection uses ticket watermark; reconnect keeps its own cursor',
    () async {
      var watermark = '100';
      final sockets = <TestSocket>[];
      final uris = <Uri>[];
      final client = RealtimeClient(
        baseURL: Uri.parse('https://example.com'),
        credentials: () async => {
          'token': 'test',
          'websocket_path': '/api/v1/realtime',
          'cursor': watermark,
        },
        connect: (uri) async {
          uris.add(uri);
          final socket = TestSocket();
          sockets.add(socket);
          return socket;
        },
        onConnected: () {},
        onEvent: (_) async {},
      );
      addTearDown(() => client.stop());
      client.start();
      await flush();
      expect(uris.last.queryParameters['cursor'], '100');
      sockets.last.event('message.created', 101);
      await flush();
      await client.stop();
      watermark = '200';
      client.start();
      await flush();
      expect(uris.last.queryParameters['cursor'], '101');
    },
  );

  test(
    'SESSION_INVALID is delivered before an immediately closed socket',
    () async {
      final socket = TestSocket();
      final received = <String>[];
      final client = RealtimeClient(
        baseURL: Uri.parse('https://example.com'),
        credentials: () async => {
          'token': 'test',
          'websocket_path': '/api/v1/realtime',
        },
        connect: (_) async => socket,
        onConnected: () {},
        onEvent: (event) async {
          await flush();
          received.add(event['type']);
        },
      );
      addTearDown(() => client.stop());
      client.start();
      await flush();
      socket.input.add(jsonEncode({'type': 'SESSION_INVALID', 'title': '已下线'}));
      await socket.close();
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(received, ['SESSION_INVALID']);
    },
  );

  test('a late connection from a previous login is closed', () async {
    final pending = Completer<RealtimeSocket>();
    final client = RealtimeClient(
      baseURL: Uri.parse('https://example.com'),
      credentials: () async => {
        'token': 'test',
        'websocket_path': '/api/v1/realtime',
      },
      connect: (_) => pending.future,
      onConnected: () {},
      onEvent: (_) async {},
    );
    client.start();
    await flush();
    await client.stop(resetCursor: true);
    final late = TestSocket();
    pending.complete(late);
    await flush();
    expect(late.closed, true);
    expect(client.socket, isNull);
  });

  test(
    'store coalesces unread updates, pauses and clears revoked login',
    () async {
      final api = FakeGateway();
      api.documents['PostRealtimeToken'] = {
        'token': 'test',
        'websocket_path': '/api/v1/realtime',
      };
      final sockets = <TestSocket>[];
      final store = AppStore(
        api: api,
        storage: MemoryStorage(),
        realtimeConnector: (_) async {
          final s = TestSocket();
          sockets.add(s);
          return s;
        },
      );
      addTearDown(store.dispose);
      await store.initialize();
      await store.signIn('13812345678', '654321');
      await Future<void>.delayed(const Duration(milliseconds: 250));
      api.calls.clear();
      api.documents['GetNotifications'] = {
        'unread_count': 3,
        'items': [
          {
            'id': 7,
            'type': 'SYSTEM',
            'payload': {'title': '通知'},
          },
        ],
      };
      for (var i = 1; i <= 20; i++) {
        sockets.last.event('notification.created', i, {});
      }
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(api.calls.where((value) => value == 'GetNotifications').length, 1);
      expect(store.notificationUnreadCount, 3);
      sockets.last.event('SYSTEM_NOTIFICATION', 21, {'notification_id': 55});
      await Future<void>.delayed(const Duration(milliseconds: 250));
      expect(api.calls, contains('PostNotificationsIdDelivery'));
      store.setForeground(false);
      await flush();
      expect(sockets.last.closed, true);
      store.setForeground(true);
      await flush();
      expect(sockets.length, 2);
      sockets.last.input.add(
        jsonEncode({
          'type': 'SESSION_INVALID',
          'title': '已下线',
          'message': '测试原因',
        }),
      );
      await sockets.last.close();
      await flush();
      expect(store.isAuthenticated, false);
      expect(store.sessionNotice?['message'], '测试原因');
      expect(store.inbox, isEmpty);
    },
  );

  test(
    'job updates wake polling and logout releases pending waiters',
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
      await flush();
      var fallback = false;
      final waiting = store.waitForJobUpdate('RESUME_EXPORT', 7, (_) async {
        fallback = true;
      });
      socket.event('job.updated', 1, {
        'job_type': 'RESUME_EXPORT',
        'job_id': 7,
      });
      await waiting;
      expect(fallback, false);
      final next = store.waitForJobUpdate('RESUME_EXPORT', 8, (_) async {});
      final expectation = expectLater(next, throwsA(isA<ApiFailure>()));
      await store.endSession(remote: false);
      await expectation;
    },
  );
}
