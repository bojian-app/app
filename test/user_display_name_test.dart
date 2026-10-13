import 'package:bojian_mobile/app_store.dart';
import 'package:bojian_mobile/user_display_name.dart';
import 'package:bojian_mobile/resume_guidance_review.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Missing nicknames share a display fallback while real nicknames remain intact', () {
    for (final value in [null, '', '  ', '\n\t']) {
      expect(userDisplayName(value), '未设置用户昵称');
    }
    expect(userDisplayName(' 小简 '), '小简');
    expect(userDisplayName('用户'), '用户');
  });
  test(
    'Article authors and reply targets use fallback without inventing a reply',
    () {
      final row = <String, dynamic>{
        'author': {'display_name': ' '},
        'content': '测试',
      };
      expect(ArticleComment.fromJson(row).author, '未设置用户昵称');
      expect(ArticleComment.fromJson(row).replyToName, isEmpty);
      expect(
        ArticleComment.fromJson({
          ...row,
          'reply_to': {'id': 5, 'display_name': ''},
        }).replyToName,
        '未设置用户昵称',
      );
      expect(
        decodeStory({
          'author': {'display_name': ''},
          'content': {},
        }).author,
        '未设置用户昵称',
      );
      expect((row['author'] as Map)['display_name'], ' ');
    },
  );
  test('Unnamed guidance participants keep distinct identities', () {
    final a = {'id': 1, 'reviewer_id': 10, 'reviewer_name': ''};
    final b = {'id': 2, 'reviewer_id': 20, 'reviewer_name': ' '};
    expect(GuidanceParticipant(guidanceReviewerKey(a), [a]).name, '未设置用户昵称');
    expect(GuidanceParticipant(guidanceReviewerKey(b), [b]).name, '未设置用户昵称');
    expect(guidanceReviewerKey(a), isNot(guidanceReviewerKey(b)));
  });
}
