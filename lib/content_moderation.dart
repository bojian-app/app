import 'dart:async';

import 'package:flutter/material.dart';

import 'api/bojian_api.dart';
import 'app_store.dart';
import 'design.dart';

enum SubmissionStatus { published, pending, queued }

// The server owns moderation and persistence; the client only renders its result.
SubmissionStatus submissionStatus(
  Map<String, dynamic> data, {
  required SubmissionStatus fallback,
}) {
  if (data['status'] == 'REJECTED') {
    throw ApiFailure(
      '${data['review_reason'] ?? '内容未通过人工审核，请修改后重新提交'}',
      code: 'CONTENT_REJECTED',
    );
  }
  final moderation = data['moderation'];
  if (moderation is Map) {
    final answers = moderation['answers'];
    if (moderation['status'] == 'REJECTED' ||
        (answers is Map && answers.values.contains('yes'))) {
      throw ApiFailure(
        '内容未通过审核，请修改后重试',
        code: 'CONTENT_REJECTED',
        details: {'moderation': moderation},
      );
    }
    // A later human approval supersedes the original uncertain AI result.
    if (data['status'] == 'PUBLISHED' || data['status'] == 'VISIBLE') {
      return SubmissionStatus.published;
    }
    if (moderation['status'] == 'PENDING' ||
        (answers is Map && answers.values.contains('uncertain'))) {
      return SubmissionStatus.pending;
    }
  }
  return switch (data['status']) {
    'QUEUED' => SubmissionStatus.queued,
    'SUBMITTED' || 'PENDING' => SubmissionStatus.pending,
    'PUBLISHED' || 'VISIBLE' => SubmissionStatus.published,
    _ => fallback,
  };
}

String articleSubmissionMessage(SubmissionStatus status) =>
    status == SubmissionStatus.pending ? '已提交人工审核，审核通过后发布' : '文章已发布';

String moderationLabel(String status) => switch (status) {
  'SENDING' => '发送中…',
  'QUEUED' => '审核中 · 仅自己可见',
  'PENDING' => '待人工审核 · 仅自己可见',
  'REJECTED' => '未通过审核 · 仅自己可见',
  'FAILED' => '发送失败',
  _ => '',
};
String contentStatus(Map row) => '${row['moderation_status'] ?? 'VISIBLE'}';
bool contentVisible(Map row) => contentStatus(row) == 'VISIBLE';

// Match a withdrawal event to the currently displayed community/friend share.
bool guidanceRemovalAffects(
  Map<String, dynamic> event,
  int id,
  bool notification,
) {
  if (event['type'] != 'content.removed') return false;
  final data = event['data'];
  if (data is! Map) return false;
  if (data['share_id'] == id &&
      data['share_scope'] == (notification ? 'NOTIFICATION' : 'ARTICLE')) {
    return true;
  }
  return !notification && data['article_id'] == id;
}

/// Status line, review reason and retry action for a comment or annotation
/// that is not yet visible to others.
class ModerationStatusNote extends StatelessWidget {
  const ModerationStatusNote({
    super.key,
    required this.item,
    required this.onRetry,
    this.spacing = 6,
  });

  final Map item;

  /// Resends a FAILED item or reopens a REJECTED one for editing.
  final VoidCallback onRetry;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final status = contentStatus(item);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: spacing),
        Text(
          moderationLabel(status),
          style: TextStyle(fontSize: 12, color: context.colors.muted),
        ),
        if ({'REJECTED', 'FAILED'}.contains(status)) ...[
          Text(
            '${item['review_reason'] ?? ''}',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.error,
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: Text(status == 'FAILED' ? '重试' : '修改后重发'),
          ),
        ],
      ],
    );
  }
}

/// Reloads guidance comments when the share is withdrawn, and every 3s
/// while any shown item is still being sent or reviewed.
mixin GuidanceLiveReload<T extends StatefulWidget> on State<T> {
  Timer? _moderationTimer;
  StreamSubscription<Map<String, dynamic>>? _removalSubscription;

  void watchGuidance({
    required AppStore store,
    required int id,
    required bool notification,
    required Iterable<Map> Function() items,
    required VoidCallback reload,
  }) {
    _removalSubscription = store.realtimeEvents.listen((event) {
      if (mounted && guidanceRemovalAffects(event, id, notification)) reload();
    });
    _moderationTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted &&
          store.foreground &&
          ModalRoute.of(context)?.isCurrent == true &&
          items().any(
            (r) => {'SENDING', 'QUEUED', 'PENDING'}.contains(contentStatus(r)),
          )) {
        reload();
      }
    });
  }

  @override
  void dispose() {
    _moderationTimer?.cancel();
    unawaited(_removalSubscription?.cancel());
    super.dispose();
  }
}
