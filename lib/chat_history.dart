import 'dart:async';

import 'package:flutter/material.dart';

import 'api/bojian_api.dart';
import 'app_store.dart';

String chatMessageText(Map row) {
  final payload = row['payload'] is Map ? row['payload'] as Map : const {};
  final type = row['type']?.toString() ?? '';
  return switch (type) {
    'TEXT' =>
      payload['text']?.toString() ?? payload['content']?.toString() ?? '',
    'EMOJI' =>
      payload['emoji']?.toString() ?? payload['text']?.toString() ?? '[表情]',
    'IMAGE' => '[图片]',
    'ARTICLE_LINK' => payload['title']?.toString() ?? '[文章]',
    _ => '[暂不支持的消息]',
  };
}

class ChatHistory extends ChangeNotifier {
  ChatHistory(this.store, this.conversationID) : sessionEpoch = store.epoch {
    store.addListener(_sessionChanged);
    realtime = store.realtimeEvents.listen((event) {
      final data = event['data'] is Map ? event['data'] as Map : const {};
      if (event['type'] == 'connection.ready' ||
          event['type'] == 'message.created' &&
              integer(data['conversation_id']) == conversationID) {
        if (loading) {
          refreshPending = true;
        } else {
          unawaited(load(incremental: true));
        }
      }
    });
  }
  late final StreamSubscription<Map<String, dynamic>> realtime;
  bool refreshPending = false, syncing = false;
  final AppStore store;
  final int conversationID, sessionEpoch;
  final messages = <Map<String, dynamic>>[];
  bool alive = true, loading = false, sending = false;
  String cursor = '';
  String? error, readError;
  int generation = 0;
  String? pendingText, pendingID;
  bool get valid =>
      alive &&
      store.alive &&
      store.epoch == sessionEpoch &&
      store.isAuthenticated;

  void _sessionChanged() {
    if (alive && !valid) {
      generation++;
      messages.clear();
      pendingText = pendingID = null;
      error = '登录状态已失效';
      loading = sending = false;
      notifyListeners();
    }
  }

  Future<void> load({bool more = false, bool incremental = false}) async {
    if (!valid || loading || more && cursor.isEmpty) return;
    final token = ++generation;
    loading = true;
    syncing = incremental;
    error = null;
    notifyListeners();
    try {
      var response = await store.request(
        'GetConversationsIdMessages',
        path: {'id': '$conversationID'},
        query: {'limit': '40', if (more) 'cursor': cursor},
      );
      if (!valid || token != generation) return;
      final collected = items(response.data).toList();
      final previousNewest = messages.isEmpty
          ? 0
          : integer(messages.last['id']);
      final initialCursor = response.nextCursor;
      // Walk backwards until we overlap the known tail. A reconnect can bring
      // more than one page of new messages; fetching just the head leaves a gap.
      if (incremental && previousNewest > 0) {
        var next = response.nextCursor;
        final visited = <String>{};
        while (next.isNotEmpty &&
            visited.add(next) &&
            collected.isNotEmpty &&
            !collected.any((row) => integer(row['id']) <= previousNewest)) {
          response = await store.request(
            'GetConversationsIdMessages',
            path: {'id': '$conversationID'},
            query: {'limit': '40', 'cursor': next},
          );
          if (!valid || token != generation) return;
          final page = items(response.data);
          if (page.isEmpty) break;
          collected.addAll(page);
          next = response.nextCursor;
        }
      }
      if (!more && !incremental) messages.clear();
      for (final row in collected) {
        final index = messages.indexWhere(
          (value) => integer(value['id']) == integer(row['id']),
        );
        if (index < 0) {
          messages.add(row);
        } else {
          messages[index] = row;
        }
      }
      messages.sort((a, b) => integer(a['id']).compareTo(integer(b['id'])));
      if (!incremental || previousNewest == 0) cursor = initialCursor;
      notifyListeners();
      if (!more && messages.isNotEmpty) {
        try {
          await store.readConversation(
            conversationID,
            integer(messages.last['id']),
          );
          if (valid) readError = null;
        } catch (failure) {
          if (valid) readError = '$failure';
        }
      }
    } catch (failure) {
      if (valid && token == generation) error = '$failure';
    } finally {
      if (valid && token == generation) {
        loading = false;
        syncing = false;
        notifyListeners();
        if (refreshPending) {
          refreshPending = false;
          unawaited(load(incremental: true));
        }
      }
    }
  }

  Future<bool> send(String text) async {
    text = text.trim();
    if (!valid || loading && !syncing || sending || text.isEmpty) return false;
    if (text.length > 4000) {
      error = '消息不能超过 4000 字';
      notifyListeners();
      return false;
    }
    if (pendingText != text || pendingID == null) {
      pendingText = text;
      pendingID = newDeviceID();
    }
    final clientID = pendingID!;
    sending = true;
    error = null;
    notifyListeners();
    try {
      final response = await store.request(
        'PostConversationsIdMessages',
        path: {'id': '$conversationID'},
        body: {
          'client_message_id': clientID,
          'type': 'TEXT',
          'payload': {'text': text},
        },
        extra: {'idempotency-key': clientID},
      );
      if (!valid) return false;
      final id = integer(response.data['id']);
      if (id <= 0) throw const ApiFailure('服务器未确认消息，请重试');
      if (!messages.any((row) => integer(row['id']) == id)) {
        messages.add({
          'id': id,
          'sender_id': store.userID,
          'client_message_id': clientID,
          'type': 'TEXT',
          'payload': {'text': text},
          'created_at':
              response.data['created_at'] ??
              DateTime.now().toUtc().toIso8601String(),
        });
        messages.sort((a, b) => integer(a['id']).compareTo(integer(b['id'])));
      }
      pendingText = pendingID = null;
      for (final row in store.conversations) {
        if (integer(row['id']) == conversationID) {
          row['last_message_id'] = id;
          row['last_message_type'] = 'TEXT';
          row['last_message_payload'] = {'text': text};
          row['last_message_at'] = messages.last['created_at'];
        }
      }
      store.changed();
      return true;
    } catch (failure) {
      if (valid) error = '$failure';
      return false;
    } finally {
      if (valid) {
        sending = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    alive = false;
    generation++;
    store.removeListener(_sessionChanged);
    unawaited(realtime.cancel());
    super.dispose();
  }
}
