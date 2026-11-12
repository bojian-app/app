part of 'app_store.dart';

/// Queued article, comment and reply submissions.
extension AppStoreContent on AppStore {
  Future<void> saveContentSubmissions() {
    final uid = userID;
    final value = jsonEncode(contentSubmissions);
    return contentWrites = contentWrites
        .catchError((_) {})
        .then((_) => storage.write('bojian.content-outbox.$uid', value));
  }

  Future<void> restoreContentSubmissions() async {
    final version = epoch;
    try {
      final raw = await storage.read('bojian.content-outbox.$userID');
      if (version != epoch || !alive || raw == null) return;
      contentSubmissions.clear();
      for (final row in (jsonDecode(raw) as List).whereType<Map>()) {
        final item = Map<String, dynamic>.from(row);
        if (item['moderation_status'] == 'SENDING') {
          item['moderation_status'] = 'FAILED';
        }
        contentSubmissions.add(item);
      }
      changed();
    } catch (_) {
      /* Server-accepted submissions are also loaded from lists. */
    }
  }

  Map<String, dynamic> enqueueContent(
    String method,
    int id,
    Map<String, dynamic> body, {
    Map<String, dynamic> display = const {},
  }) {
    final now = DateTime.now();
    final row = <String, dynamic>{
      ...body,
      ...display,
      'id': -now.microsecondsSinceEpoch,
      'created_at': now.toUtc().toIso8601String(),
      'reviewer_id': userID,
      'reviewer_name': name,
      'reviewer_avatar_url': avatarURL,
      'author': {'id': userID, 'display_name': name, 'avatar_url': avatarURL},
      '_method': method,
      '_scope_id': id,
      '_body': body,
      'request_key': newDeviceID(),
      'moderation_status': 'SENDING',
      'status': 'PENDING',
    };
    contentSubmissions.add(row);
    changed();
    unawaited(sendContent(row));
    return row;
  }

  Future<void> sendContent(Map<String, dynamic> row) async {
    final version = epoch;
    row['moderation_status'] = 'SENDING';
    changed();
    try {
      await saveContentSubmissions();
      if (version != epoch || !alive) return;
      final response = await request(
        '${row['_method']}',
        path: {'id': '${row['_scope_id']}'},
        body: Map<String, dynamic>.from(row['_body'] as Map),
        extra: {'idempotency-key': '${row['request_key']}'},
        expectedEpoch: version,
      );
      if (version != epoch || !alive) return;
      row['id'] = response.data['id'] ?? row['id'];
      row['moderation_status'] = response.data['status'] ?? 'QUEUED';
      row['moderation'] = response.data['moderation'];
      row['review_reason'] = response.data['review_reason'];
    } catch (e) {
      if (version != epoch || !alive) return;
      row['moderation_status'] = 'FAILED';
      row['review_reason'] = '$e';
    }
    if (version != epoch || !alive) return;
    unawaited(saveContentSubmissions().catchError((Object _) {}));
    changed();
  }

  List<Map<String, dynamic>> mergeContent(
    String method,
    int id,
    List<Map<String, dynamic>> remote,
  ) {
    final local = contentSubmissions
        .where((v) => v['_method'] == method && v['_scope_id'] == id)
        .toList();
    final acknowledged = local
        .where(
          (v) => remote.any(
            (r) =>
                (integer(v['id']) > 0 && r['id'] == v['id']) ||
                (r['request_key'] != null &&
                    r['request_key'] == v['request_key']),
          ),
        )
        .toList();
    if (acknowledged.isNotEmpty) {
      contentSubmissions.removeWhere(acknowledged.contains);
      unawaited(saveContentSubmissions().catchError((Object _) {}));
    }
    return [
      ...local.where((v) => !acknowledged.contains(v)).toList().reversed,
      ...remote,
    ];
  }

  List<Map<String, dynamic>> localContent(String method, int id) =>
      contentSubmissions
          .where((v) => v['_method'] == method && v['_scope_id'] == id)
          .toList();
  Future<SubmissionStatus?> comment(
    Story story,
    String text, {
    int? replyToID,
  }) async {
    enqueueContent('PostArticlesIdComments', story.id, {
      'content': text,
      'reply_to_id': ?replyToID,
    });
    return SubmissionStatus.queued;
  }
}
