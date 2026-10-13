import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

abstract interface class RealtimeSocket {
  Stream<dynamic> get messages;
  Future<void> close();
}

typedef RealtimeConnector = Future<RealtimeSocket> Function(Uri uri);

class NativeRealtimeSocket implements RealtimeSocket {
  NativeRealtimeSocket(this.socket);
  final WebSocket socket;
  static Future<RealtimeSocket> connect(Uri uri) async {
    var timedOut = false;
    final pending = WebSocket.connect(uri.toString()).then((socket) {
      if (timedOut) unawaited(socket.close());
      return socket;
    });
    final socket = await pending.timeout(
      const Duration(seconds: 15),
      onTimeout: () {
        timedOut = true;
        throw TimeoutException('Realtime connection timed out');
      },
    );
    socket.pingInterval = const Duration(seconds: 25);
    return NativeRealtimeSocket(socket);
  }

  @override
  Stream<dynamic> get messages => socket;
  @override
  Future<void> close() async => socket.close();
}

class HttpRealtimeSocket implements RealtimeSocket {
  HttpRealtimeSocket(this.response, this.abort);
  final http.StreamedResponse response;
  final Completer<void> abort;

  static Future<RealtimeSocket> connect(
    http.Client client,
    Uri socketURI,
  ) async {
    final abort = Completer<void>();
    final uri = socketURI.replace(
      scheme: socketURI.scheme == 'ws' ? 'http' : 'https',
      path: '${socketURI.path}/events',
    );
    try {
      final request =
          http.AbortableRequest('GET', uri, abortTrigger: abort.future)
            ..followRedirects = false
            ..headers['accept'] = 'text/event-stream';
      final response = await client
          .send(request)
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200 ||
          !(response.headers['content-type'] ?? '').startsWith(
            'text/event-stream',
          )) {
        throw const FormatException('Invalid realtime event stream');
      }
      return HttpRealtimeSocket(response, abort);
    } catch (_) {
      if (!abort.isCompleted) abort.complete();
      rethrow;
    }
  }

  @override
  Stream<dynamic> get messages async* {
    final data = <String>[];
    var size = 0;
    try {
      await for (final line
          in response.stream
              .timeout(const Duration(seconds: 45))
              .transform(utf8.decoder)
              .transform(const LineSplitter())) {
        if (line.isEmpty) {
          if (data.isNotEmpty) yield data.join('\n');
          data.clear();
          size = 0;
        } else if (line.startsWith('data:')) {
          final value = line.substring(5).replaceFirst(RegExp(r'^ '), '');
          size += value.length;
          if (size > 1024 * 1024) {
            throw const FormatException('Realtime event too large');
          }
          data.add(value);
        }
      }
    } catch (_) {
      if (!abort.isCompleted) rethrow;
      // Native cancellation is expected on background/logout.
    }
  }

  @override
  Future<void> close() async {
    if (!abort.isCompleted) abort.complete();
  }
}

/// One foreground connection per login. Cursor survives transport reconnects;
/// stopping a login discards it so another account cannot reuse its history.
class RealtimeClient {
  RealtimeClient({
    required this.baseURL,
    required this.credentials,
    required this.onEvent,
    required this.onConnected,
    this.connect = NativeRealtimeSocket.connect,
    this.onFailure,
  });
  final Uri baseURL;
  final Future<Map<String, dynamic>> Function() credentials;
  final Future<void> Function(Map<String, dynamic>) onEvent;
  final void Function() onConnected;
  final RealtimeConnector connect;
  final void Function(Object)? onFailure;
  RealtimeSocket? socket;
  StreamSubscription<dynamic>? subscription;
  Timer? retry;
  int generation = 0, failures = 0;
  String cursor = '0';
  bool cursorInitialized = false;
  bool enabled = false, connecting = false;
  Future<void> queue = Future.value();

  void start() {
    if (enabled) return;
    enabled = true;
    unawaited(_open(generation));
  }

  Future<void> stop({bool resetCursor = false}) async {
    enabled = false;
    generation++;
    connecting = false;
    retry?.cancel();
    retry = null;
    final oldSubscription = subscription;
    final oldSocket = socket;
    subscription = null;
    socket = null;
    if (resetCursor) {
      cursor = '0';
      cursorInitialized = false;
      failures = 0;
    }
    await _closeTransport(oldSocket, oldSubscription);
  }

  Future<void> _closeTransport(
    RealtimeSocket? oldSocket,
    StreamSubscription<dynamic>? oldSubscription,
  ) async {
    try {
      await oldSocket?.close();
    } catch (_) {
      /* Closing is best effort. */
    }
    try {
      await oldSubscription?.cancel();
    } catch (_) {
      /* Expected native abort. */
    }
  }

  bool valid(int version) => enabled && version == generation;

  Future<void> _open(int version) async {
    if (!valid(version) || connecting) return;
    connecting = true;
    try {
      final ticket = await credentials();
      if (!valid(version)) return;
      final token = ticket['token'];
      final path = ticket['websocket_path'];
      if (token is! String || token.isEmpty || path != '/api/v1/realtime') {
        throw const FormatException('Invalid realtime ticket');
      }
      if (!cursorInitialized) {
        // The initial snapshot reconciles past changes. Start at the server's
        // watermark, then replay only changes missed by subsequent reconnects.
        final initial = int.tryParse('${ticket['cursor']}');
        cursor = initial != null && initial >= 0 ? '$initial' : '0';
        cursorInitialized = true;
      }
      final next = await connect(
        baseURL.replace(
          scheme: baseURL.scheme == 'http' ? 'ws' : 'wss',
          path: path,
          queryParameters: {'token': token, 'cursor': cursor},
        ),
      );
      if (!valid(version)) {
        await next.close();
        return;
      }
      socket = next;
      failures = 0;
      subscription = next.messages.listen(
        (raw) {
          queue = queue
              .catchError((_) {})
              .then((_) async {
                if (!valid(version)) return;
                Map<String, dynamic> event;
                try {
                  final decoded = jsonDecode(
                    raw is String ? raw : utf8.decode(raw as List<int>),
                  );
                  if (decoded is! Map<String, dynamic> ||
                      decoded['type'] is! String) {
                    return;
                  }
                  event = decoded;
                } catch (_) {
                  return;
                }
                final nextCursor = int.tryParse('${event['cursor']}');
                if (nextCursor != null &&
                    nextCursor <= (int.tryParse(cursor) ?? 0)) {
                  return;
                }
                await onEvent(event);
                if (valid(version) && nextCursor != null) {
                  cursor = '$nextCursor';
                }
              })
              .catchError((_) {
                _disconnected(version);
              });
        },
        // A server can send SESSION_INVALID and close immediately. Finish
        // already-received frames before invalidating this transport generation.
        onError: (_) =>
            unawaited(queue.whenComplete(() => _disconnected(version))),
        onDone: () =>
            unawaited(queue.whenComplete(() => _disconnected(version))),
        cancelOnError: true,
      );
      onConnected();
    } catch (error) {
      if (valid(version)) onFailure?.call(error);
      _disconnected(version);
    } finally {
      if (version == generation) connecting = false;
    }
  }

  void _disconnected(int version) {
    if (!valid(version) || retry != null) return;
    final nextVersion = ++generation;
    connecting = false;
    final old = socket;
    final oldSubscription = subscription;
    subscription = null;
    socket = null;
    unawaited(_closeTransport(old, oldSubscription));
    final seconds = 1 << failures.clamp(0, 5);
    failures++;
    retry = Timer(Duration(seconds: seconds.clamp(1, 30)), () {
      retry = null;
      unawaited(_open(nextVersion));
    });
  }
}
