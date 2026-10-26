import 'api/bojian_api.dart';

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
