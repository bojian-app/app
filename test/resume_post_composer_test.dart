import 'dart:async';

import 'package:bojian_mobile/api/bojian_api.dart';
import 'package:bojian_mobile/app_store.dart';
import 'package:bojian_mobile/resume_post_composer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';
import 'resume_preview_menu_test.dart' show openPreview, action;

class PostGateway extends FakeGateway {
  final keys = <String>[];
  final bodies = <Map<String, dynamic>>[];
  Completer<ApiDocument>? pending;

  @override
  Future<ApiDocument> call(
    String method, {
    Map<String, String> path = const {},
    Map<String, String> query = const {},
    Map<String, dynamic>? body,
    Map<String, String> headers = const {},
  }) {
    if (method == 'PostResumesIdGuidance') {
      expectSync(path['id'], '42');
      keys.add(headers['idempotency-key']!);
      bodies.add(Map.of(body!));
      if (pending != null) return pending!.future;
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

final field = find.byKey(const ValueKey('resume-post-content'));
final submit = find.byKey(const ValueKey('resume-post-submit'));

Future<AppStore> mount(WidgetTester tester, PostGateway api) async {
  final store = await testStore(authenticated: true, api: api);
  addTearDown(store.dispose);
  store.resumes.add(ResumeDraft(id: 42, title: '我的简历'));
  await openPreview(tester, store);
  await action(tester, 'share-post');
  api.calls.clear();
  return store;
}

void main() {
  testWidgets(
    'Menu opens composer; default post attaches private snapshot and refreshes feed',
    (tester) async {
      final api = PostGateway();
      api.documents['PostResumesIdGuidance'] = {
        'id': 81,
        'status': 'PUBLISHED',
      };
      await mount(tester, api);
      expect(find.byType(ResumePostComposer), findsOneWidget);
      expect(find.text('发表动态'), findsOneWidget);
      expect(find.text('分享动态'), findsNothing);
      expect(api.keys, isEmpty);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(api.bodies.single, {
        'version': 2,
        'destination': 'CIRCLE',
        'question': ResumePostComposer.defaultText,
        'hidden_fields': [
          'personal_info',
          'photo',
          'projects.url',
          'educations.institution',
          'work_experiences.company',
          'certifications.issuer',
        ],
      });
      expect(api.calls, contains('GetFeed'));
      expect(find.byType(ResumePostComposer), findsNothing);
      expect(find.text('动态已发表'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Failure preserves text; retry reuses key and edits create a new key',
    (tester) async {
      final api = PostGateway()..failing = 'PostResumesIdGuidance';
      await mount(tester, api);
      await tester.enterText(field, '希望交流求职经验');
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(find.text('服务器暂不可用'), findsOneWidget);
      expect(tester.widget<TextField>(field).controller!.text, '希望交流求职经验');
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(api.keys[0], api.keys[1]);
      api.failing = null;
      api.documents['PostResumesIdGuidance'] = {
        'id': 82,
        'status': 'SUBMITTED',
      };
      await tester.enterText(field, '修改后的动态');
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(api.keys[2], isNot(api.keys[1]));
      expect(api.bodies.last['question'], '修改后的动态');
      expect(find.text('已提交审核，通过后展示在社区'), findsOneWidget);
      expect(find.text('动态已发表'), findsNothing);
    },
  );

  testWidgets(
    'In-flight post disables duplicate submission; rejected post stays editable',
    (tester) async {
      final api = PostGateway()..pending = Completer<ApiDocument>();
      await mount(tester, api);
      await tester.enterText(field, '测试动态');
      await tester.tap(submit);
      await tester.pump();
      expect(tester.widget<FilledButton>(submit).onPressed, isNull);
      expect(tester.widget<TextField>(field).enabled, isFalse);
      await tester.tap(submit);
      expect(api.keys.length, 1);
      api.pending!.complete(ApiDocument({'id': 83, 'status': 'REJECTED'}));
      await tester.pumpAndSettle();
      expect(find.byType(ResumePostComposer), findsOneWidget);
      expect(tester.widget<TextField>(field).enabled, isTrue);
      expect(find.text('内容未通过人工审核，请修改后重新提交'), findsOneWidget);
      expect(api.calls, isNot(contains('GetFeed')));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Account change prevents a post under a different session', (
    tester,
  ) async {
    final api = PostGateway();
    final store = await mount(tester, api);
    await store.endSession(remote: false);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(api.keys, isEmpty);
    expect(find.byType(ResumePostComposer), findsOneWidget);
    expect(find.text('账号已切换，请重试'), findsOneWidget);
  });

  testWidgets(
    'A rejected résumé post locates only a verified sentence in its editable text',
    (tester) async {
      const sentence = '这一句需要修改。';
      const text = '  🌿 分享感想。$sentence$sentence';
      final api = PostGateway();
      api.documents['PostResumesIdGuidance'] = {
        'status': 'REJECTED',
        'moderation': {
          'violations': [
            {
              'message': '本地测试的审核原因',
              'excerpts': [
                {
                  'field': 'body',
                  'text': sentence,
                  'match': '修改',
                  'start_utf16': text.trim().lastIndexOf(sentence),
                },
                {
                  'field': 'body',
                  'block_index': 2,
                  'text': sentence,
                  'start_utf16': text.trim().indexOf(sentence),
                },
                {'field': 'content', 'text': '快照里的另一句。'},
              ],
            },
          ],
        },
      };
      await mount(tester, api);
      await tester.enterText(field, text);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      final dialog = find.byType(AlertDialog);
      expect(
        find.descendant(
          of: dialog,
          matching: find.textContaining('快照里的另一句。', findRichText: true),
        ),
        findsWidgets,
      );
      final locate = find.descendant(of: dialog, matching: find.text('定位原文'));
      expect(locate, findsOneWidget);
      await tester.ensureVisible(locate);
      await tester.tap(locate);
      await tester.pumpAndSettle();
      expect(dialog, findsNothing);
      final input = tester.widget<TextField>(field);
      expect(input.focusNode!.hasFocus, isTrue);
      expect(input.controller!.text, text);
      expect(input.controller!.selection.start, text.lastIndexOf(sentence));
      expect(input.controller!.selection.textInside(text), sentence);
      expect(api.calls, isNot(contains('GetFeed')));
    },
  );
}
