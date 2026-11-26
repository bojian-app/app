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
  ModerationGateway({this.rejection = rejectedDetails});

  final Map<String, dynamic> rejection;
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
        throw ApiFailure(
          '内容未通过审核',
          code: 'CONTENT_REJECTED',
          details: rejection,
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
    expect(
      () => submissionStatus({
        'status': 'REJECTED',
        ...rejectedDetails,
      }, fallback: SubmissionStatus.published),
      throwsA(
        isA<ApiFailure>().having(
          (e) => e.details,
          'rejection details',
          containsPair('moderation', rejectedDetails['moderation']),
        ),
      ),
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
      await tester.pump();
      await tester.tap(find.byTooltip('提交审核'));
      // The blocked editor remains busy while the reason dialog is open.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('侮辱、诽谤他人'), findsOneWidget);
      expect(find.textContaining('损害国家荣誉和利益'), findsOneWidget);
      expect(find.textContaining('审核结果未提供具体原句'), findsWidgets);
      expect(find.text('定位原文'), findsNothing);
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

  testWidgets('A moderation excerpt selects its sentence in the reported field', (
    tester,
  ) async {
    const titleSentence = '标题里的这一句。';
    const bodySentence = '正文里的这一句。';
    const ambiguous = '重复的观察。';
    const title = '🌤 天气记录。$titleSentence';
    const lastParagraphPrefix = '🌿 $bodySentence ';
    const body =
        '$bodySentence\n🌿 $ambiguous$ambiguous\n$lastParagraphPrefix$bodySentence';
    final gateway = ModerationGateway(
      rejection: {
        'moderation': {
          'status': 'REJECTED',
          'violations': [
            {
              'key': 'other_illegal_content',
              'message': '本地测试的审核原因',
              'excerpts': [
                {'field': 'title', 'text': titleSentence, 'match': '标题里'},
                {
                  'field': 'body',
                  'text': bodySentence,
                  'match': '正文里',
                  'block_index': 2,
                  'start_utf16': lastParagraphPrefix.length,
                },
                {'field': 'body', 'text': ambiguous, 'match': '观察'},
              ],
            },
          ],
        },
      },
    );
    final store = await testStore(authenticated: true, api: gateway);
    addTearDown(store.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: StoryComposer(store: store),
      ),
    );
    await tester.pumpAndSettle();
    final titleField = find.byKey(const ValueKey('composer-title'));
    await tester.enterText(titleField, title);
    final editor = tester.widget<quill.QuillEditor>(
      find.byKey(const ValueKey('composer-body')),
    );
    editor.controller.replaceText(
      0,
      0,
      body,
      const TextSelection.collapsed(offset: 0),
    );
    await tester.pump();

    for (final isTitle in [true, false]) {
      await tester.tap(find.byTooltip('提交审核'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final dialog = find.byType(AlertDialog);
      expect(
        find.descendant(of: dialog, matching: find.text('标题')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: dialog, matching: find.text('正文 · 第3段')),
        findsOneWidget,
      );
      for (final sentence in [titleSentence, bodySentence, ambiguous]) {
        expect(
          find.descendant(
            of: dialog,
            matching: find.textContaining(sentence, findRichText: true),
          ),
          findsWidgets,
        );
      }
      final locate = find.descendant(of: dialog, matching: find.text('定位原文'));
      expect(locate, findsNWidgets(2));
      final target = isTitle ? locate.first : locate.last;
      await tester.ensureVisible(target);
      await tester.tap(target);
      await tester.pumpAndSettle();
      expect(dialog, findsNothing);

      if (isTitle) {
        final input = tester.widget<EditableText>(
          find.descendant(of: titleField, matching: find.byType(EditableText)),
        );
        expect(input.focusNode.hasFocus, isTrue);
        expect(input.controller.selection.textInside(title), titleSentence);
      } else {
        expect(editor.focusNode.hasFocus, isTrue);
        expect(
          editor.controller.selection.start,
          body.lastIndexOf(bodySentence),
        );
        expect(editor.controller.selection.textInside(body), bodySentence);
        expect(editor.controller.document.toPlainText(), '$body\n');
        expect(editor.controller.readOnly, isFalse);
      }
    }
  });
}
