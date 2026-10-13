import 'dart:async';
import 'dart:convert';

import 'package:bojian_mobile/realtime_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('native stream abortion is consumed during intentional close', () async {
    final chunks = StreamController<List<int>>();
    final abort = Completer<void>();
    final socket = HttpRealtimeSocket(
      http.StreamedResponse(chunks.stream, 200),
      abort,
    );
    final completion = socket.messages.toList();
    unawaited(
      abort.future.then((_) {
        chunks.addError(
          http.RequestAbortedException(Uri.parse('https://example.com')),
        );
        unawaited(chunks.close());
      }),
    );
    await socket.close();
    expect(await completion, isEmpty);
  });

  test(
    'event stream decodes fragmented UTF8, skips heartbeats and aborts',
    () async {
      final chunks = StreamController<List<int>>();
      final abort = Completer<void>();
      final socket = HttpRealtimeSocket(
        http.StreamedResponse(chunks.stream, 200),
        abort,
      );
      final events = socket.messages.toList();
      final bytes = utf8.encode(
        ': connected\r\n\r\ndata: {"type":"message.created","cursor":"1","data":{"title":"你好"}}\r\n\r\n: keepalive\n\ndata: {"type":"SESSION_INVALID"}\n\n',
      );
      for (final byte in bytes) {
        chunks.add([byte]);
      }
      await chunks.close();
      final received = await events;
      expect(received.length, 2);
      expect(jsonDecode(received.first)['data']['title'], '你好');
      expect(jsonDecode(received.last)['type'], 'SESSION_INVALID');
      await socket.close();
      expect(abort.isCompleted, true);
    },
  );

  test(
    'event stream uses same origin, token and cursor and rejects HTML',
    () async {
      final client = MockClient((request) async {
        expect(
          request.url.toString(),
          'https://example.com/api/v1/realtime/events?token=fixture&cursor=42',
        );
        expect(request.headers['accept'], 'text/event-stream');
        expect(request.followRedirects, false);
        return http.Response(
          'not an event stream',
          200,
          headers: {'content-type': 'text/html'},
        );
      });
      addTearDown(client.close);
      await expectLater(
        HttpRealtimeSocket.connect(
          client,
          Uri.parse(
            'wss://example.com/api/v1/realtime?token=fixture&cursor=42',
          ),
        ),
        throwsFormatException,
      );
    },
  );
}
