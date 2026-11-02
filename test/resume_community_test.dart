import 'package:bojian_mobile/guidance_hot_comment.dart';
import 'package:bojian_mobile/resume_photo_image.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

void main() {
  test('Replacing a photo refreshes cache without changing its address', () {
    const a = ResumePhotoImage(
      'https://example/resumes/1/photo/token',
      fileID: 1,
    );
    const b = ResumePhotoImage(
      'https://example/resumes/1/photo/token',
      fileID: 2,
    );
    const same = ResumePhotoImage(
      'https://example/resumes/1/photo/token',
      fileID: 1,
    );
    expect(a, same);
    expect(a, isNot(b));
    expect(a.url, b.url);
  });
  test('Popular comment uses real likes and excludes hidden or replacement content', () {
    final rows = <Map<String, dynamic>>[
      {
        'id': 1,
        'suggestion': '普通评论',
        'like_count': 1,
        'moderation_status': 'VISIBLE',
      },
      {
        'id': 2,
        'suggestion': '热门评论',
        'like_count': 4,
        'moderation_status': 'VISIBLE',
      },
      {
        'id': 3,
        'suggestion': '不可见',
        'like_count': 9,
        'moderation_status': 'REJECTED',
      },
      {'id': 4, 'suggestion': '改写', 'replacement': '改写内容', 'like_count': 10},
    ];
    expect(popularGuidanceComment(rows)?['id'], 2);
    expect(popularGuidanceComment([]), isNull);
  });
  test('Unpublish failure preserves feed; success removes it and notifies draft lists', () async {
    final api = FakeGateway(seeded: true);
    final store = await testStore(authenticated: true, api: api);
    addTearDown(store.dispose);
    await store.load('feed');
    expect(store.stories.any((v) => v.id == 1), isTrue);
    api.failing = 'PostArticlesIdUnpublish';
    await expectLater(store.unpublishArticle(1), throwsA(anything));
    expect(store.stories.any((v) => v.id == 1), isTrue);
    api.failing = null;
    final changed = store.realtimeEvents.firstWhere(
      (e) => e['type'] == 'article.updated',
    );
    await store.unpublishArticle(1);
    expect(store.stories.any((v) => v.id == 1), isFalse);
    expect((await changed)['data'], {'article_id': 1, 'status': 'DRAFT'});
  });
}
