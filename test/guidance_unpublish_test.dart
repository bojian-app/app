import 'package:bojian_mobile/api/bojian_api.dart';
import 'package:bojian_mobile/design.dart';
import 'package:bojian_mobile/resume_guidance_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

class DeletedResumeGateway extends FakeGateway {
  DeletedResumeGateway() : super(seeded: true) {
    documents['GetArticlesIdGuidance'] = {
      'id': 1,
      'is_owner': true,
      'source_resume_id': 42,
      'title': '已发表的简历求助',
      'snapshot': {
        'work_experiences': [
          {'company': '原公司', 'position': '前端开发', 'description': '发表时的工作内容'},
        ],
      },
    };
    documents['PostArticlesIdUnpublish'] = {'id': 1, 'status': 'WITHDRAWN'};
  }
  @override
  Future<ApiDocument> call(
    String method, {
    Map<String, String> path = const {},
    Map<String, String> query = const {},
    Map<String, dynamic>? body,
    Map<String, String> headers = const {},
  }) async {
    if (method == 'GetResumesId') {
      calls.add(method);
      throw const ApiFailure('简历不存在', code: 'RESUME_NOT_FOUND');
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

void main() {
  testWidgets(
    'Deleted source resume still exposes its published snapshot and withdrawal action',
    (tester) async {
      final api = DeletedResumeGateway();
      final store = await testStore(authenticated: true, api: api);
      addTearDown(store.dispose);
      await store.load('feed');
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: ResumeGuidanceView(store: store, id: 1),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('重新加载'), findsNothing);
      expect(find.text('简历详情'), findsOneWidget);
      expect(api.calls, contains('GetResumesId'));
      final event = store.realtimeEvents.firstWhere(
        (event) => event['type'] == 'article.updated',
      );
      await tester.tap(find.byKey(const ValueKey('article-owner-actions-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('下架'));
      await tester.pumpAndSettle();
      expect(
        api.calls.where((call) => call == 'PostArticlesIdUnpublish').length,
        1,
      );
      expect((await event)['data'], {'article_id': 1, 'status': 'WITHDRAWN'});
      expect(store.stories.any((story) => story.id == 1), isFalse);
      expect(find.text('求助已下架'), findsOneWidget);
      expect(find.textContaining('退回草稿箱'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
