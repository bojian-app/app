import 'dart:convert';

import 'package:bojian_mobile/api/bojian_api.dart';
import 'package:bojian_mobile/app_store.dart';
import 'package:bojian_mobile/content_moderation.dart';
import 'package:bojian_mobile/design.dart';
import 'package:bojian_mobile/story_composer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/fake_gateway.dart';

const rejectedDetails = {
  'moderation': {
    'status': 'REJECTED',
    'answers': {'insult_defamation': 'yes', 'national_security': 'uncertain'},
    'violations': [
      {'key': 'insult_defamation', 'message': '侮辱、诽谤他人或侵害他人合法权益'},
      {'key': 'national_honor', 'message': '损害国家荣誉和利益'},
    ],
  },
};

class ModerationGateway extends FakeGateway {
  bool reject = true;
  int created = 0;
  int saved = 0;
  @override
  Future<ApiDocument> call(
    String method, {
    Map<String, String> path = const {},
    Map<String, String> query = const {},
    Map<String, dynamic>? body,
    Map<String, String> headers = const {},
  }) async {
    if (method == 'PostArticles') {
      created++;
      return ApiDocument({'id': 99});
    }
    if (method == 'PatchArticlesId') saved++;
    if (method == 'PostArticlesIdPublish') {
      if (reject) {
        throw const ApiFailure(
          '内容未通过审核',
          code: 'CONTENT_REJECTED',
          details: rejectedDetails,
        );
      }
      return ApiDocument({'id': 99, 'status': 'PUBLISHED'});
    }
    if (method == 'PostArticlesIdComments') {
      return ApiDocument({
        'id': 9,
        'status': 'PENDING',
        'moderation': {'status': 'PENDING'},
      });
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
  test('HTTP rejection retains every reason for the editor', () async {
    final api = BojianApi(
      client: MockClient(
        (_) async => http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'error': {
                'code': 'CONTENT_REJECTED',
                'message': '内容未通过审核',
                'details': rejectedDetails,
              },
            }),
          ),
          422,
        ),
      ),
    );
    addTearDown(api.close);
    await expectLater(
      api.call(
        'PostArticlesIdComments',
        path: {'id': '1'},
        body: {'content': '评论'},
      ),
      throwsA(
        isA<ApiFailure>().having(
          (e) => e.violationMessages.length,
          'all reasons',
          2,
        ),
      ),
    );
  });

  test('Rejection wins; human approval supersedes uncertain AI metadata', () {
    expect(
      () => submissionStatus(
        rejectedDetails,
        fallback: SubmissionStatus.published,
      ),
      throwsA(isA<ApiFailure>()),
    );
    expect(
      submissionStatus({
        'status': 'VISIBLE',
        'moderation': {
          'status': 'PENDING',
          'answers': {'insult_defamation': 'uncertain'},
        },
      }, fallback: SubmissionStatus.pending),
      SubmissionStatus.published,
    );
    expect(
      () => submissionStatus({
        'status': 'REJECTED',
      }, fallback: SubmissionStatus.published),
      throwsA(isA<ApiFailure>()),
    );
  });

  test(
    'Pending comments do not refresh public comments or increment totals',
    () async {
      final gateway = ModerationGateway();
      final store = await testStore(authenticated: true, api: gateway);
      addTearDown(store.dispose);
      final story = decodeStory({'id': 1, 'comment_count': 4});
      gateway.calls.clear();
      expect(
        await store.comment(story, '待审核', replyToID: 3),
        SubmissionStatus.queued,
      );
      expect(story.commentCount, 4);
      expect(story.comments, isEmpty);
      expect(gateway.calls, isNot(contains('GetArticlesIdComments')));
    },
  );

  testWidgets(
    'Rejected article retains text and reuses the saved draft on retry',
    (tester) async {
      final gateway = ModerationGateway();
      final store = await testStore(authenticated: true, api: gateway);
      addTearDown(store.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => StoryComposer(store: store),
                  ),
                ),
                child: const Text('写文章'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('写文章'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('composer-title')),
        '审核标题',
      );
      final editor = tester.widget<quill.QuillEditor>(
        find.byKey(const ValueKey('composer-body')),
      );
      editor.controller.replaceText(
        0,
        0,
        '保留原文',
        const TextSelection.collapsed(offset: 4),
      );
      await tester.tap(find.byTooltip('提交审核'));
      // The blocked editor remains busy while the reason dialog is open.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('侮辱、诽谤他人'), findsOneWidget);
      expect(find.textContaining('损害国家荣誉和利益'), findsOneWidget);
      await tester.tap(find.text('返回修改'));
      await tester.pumpAndSettle();
      expect(editor.controller.document.toPlainText().trim(), '保留原文');
      expect(editor.controller.readOnly, false);
      gateway.reject = false;
      await tester.tap(find.byTooltip('提交审核'));
      await tester.pumpAndSettle();
      expect(gateway.created, 1);
      expect(gateway.saved, 1);
      expect(find.text('文章已发布'), findsOneWidget);
    },
  );
}
