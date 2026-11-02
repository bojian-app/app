import 'dart:async';

import 'package:bojian_mobile/api/bojian_api.dart';
import 'package:bojian_mobile/app_store.dart';
import 'package:bojian_mobile/design.dart';
import 'package:bojian_mobile/profile_avatar.dart';
import 'package:bojian_mobile/resume_user_share.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

class SearchGateway extends FakeGateway {
  final searches = <String>[];
  final pending = <String, Completer<ApiDocument>>{};
  final shareHeaders = <Map<String, String>>[];

  @override
  Future<ApiDocument> call(
    String method, {
    Map<String, String> path = const {},
    Map<String, String> query = const {},
    Map<String, dynamic>? body,
    Map<String, String> headers = const {},
  }) {
    if (method == 'GetUsersSearch') {
      expectSync(query['mode'], 'recipient');
      searches.add(query['query']!);
      return (pending[query['query']!] = Completer<ApiDocument>()).future;
    }
    if (method == 'PostResumesIdGuidance') {
      shareHeaders.add(Map.of(headers));
      expectSync(path['id'], '42');
    }
    return super.call(
      method,
      path: path,
      query: query,
      body: body,
      headers: headers,
    );
  }

  void complete(String query, int id, {String avatarURL = ''}) =>
      pending[query]!.complete(
        ApiDocument({
          'items': [
            {
              'id': id,
              'public_id': query,
              'display_name': '用户$id',
              'relationship': 'NONE',
              'avatar_url': avatarURL,
            },
          ],
        }),
      );
}

Future<void> mount(WidgetTester tester, SearchGateway api) async {
  final store = await testStore(authenticated: true, api: api);
  addTearDown(store.dispose);
  await tester.pumpWidget(
    MaterialApp(
      theme: appTheme,
      home: ResumeUserShare(
        store: store,
        resume: ResumeDraft(id: 42, title: '我的简历'),
      ),
    ),
  );
}

final idField = find.byKey(const ValueKey('resume-share-user-id'));
final remarkField = find.byKey(const ValueKey('resume-share-remark'));
final submit = find.byKey(const ValueKey('resume-user-share-submit'));

void main() {
  testWidgets(
    'Chinese IME composition is preserved and searched only after commit',
    (tester) async {
      final api = SearchGateway();
      await mount(tester, api);
      await tester.enterText(idField, 'old');
      await tester.pump(const Duration(milliseconds: 350));
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: 'xiao',
          selection: TextSelection.collapsed(offset: 4),
          composing: TextRange(start: 0, end: 4),
        ),
      );
      api.complete('old', 9);
      await tester.pump(const Duration(milliseconds: 500));
      expect(api.searches, ['old']);
      expect(find.text('用户9'), findsNothing);
      expect(
        tester.widget<TextField>(idField).controller!.value.composing,
        const TextRange(start: 0, end: 4),
      );
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: '小王',
          selection: TextSelection.collapsed(offset: 2),
          composing: TextRange(start: 0, end: 2),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(api.searches, ['old']);
      expect(tester.widget<TextField>(idField).controller!.text, '小王');
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: '小王',
          selection: TextSelection.collapsed(offset: 2),
        ),
      );
      await tester.pump();
      expect(
        tester.widget<TextField>(idField).controller!.value.composing,
        TextRange.empty,
      );
      await tester.pump(const Duration(milliseconds: 350));
      expect(api.searches, ['old', '小王']);
      api.complete('小王', 2);
      await tester.pumpAndSettle();
      expect(find.text('用户2'), findsOneWidget);
    },
  );

  testWidgets('Mixed Chinese, Latin, numbers and symbols remain unchanged', (
    tester,
  ) async {
    final api = SearchGateway();
    await mount(tester, api);
    const query = '小王 Alex_123·😊';
    await tester.enterText(idField, query);
    await tester.pump(const Duration(milliseconds: 350));
    expect(tester.widget<TextField>(idField).controller!.text, query);
    expect(api.searches, [query]);
    api.complete(query, 2);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('resume-share-user-2')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('resume-share-selected-user')),
      findsOneWidget,
    );
    expect(tester.widget<TextField>(idField).controller!.text, isEmpty);
    expect(api.searches, [query]);
    await tester.tap(find.byTooltip('取消选择'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(idField).controller!.text, isEmpty);
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);
  });

  testWidgets(
    'Nickname search keeps the real avatar after selecting a recipient',
    (tester) async {
      final api = SearchGateway();
      await mount(tester, api);
      await tester.enterText(idField, '小王');
      await tester.pump(const Duration(milliseconds: 350));
      expect(api.searches, ['小王']);
      const avatarURL = 'https://storage.example/users/2/avatar.png';
      api.complete('小王', 2, avatarURL: avatarURL);
      await tester.pumpAndSettle();
      expect(
        tester.widget<ProfileAvatar>(find.byType(ProfileAvatar)).url,
        avatarURL,
      );
      await tester.tap(find.byKey(const ValueKey('resume-share-user-2')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('resume-share-selected-user')),
        findsOneWidget,
      );
      expect(
        tester.widget<ProfileAvatar>(find.byType(ProfileAvatar)).url,
        avatarURL,
      );
    },
  );

  testWidgets('Debounces input, rejects stale results and clears selection', (
    tester,
  ) async {
    final api = SearchGateway();
    await mount(tester, api);
    await tester.enterText(idField, 'b');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.enterText(idField, 'bj-old');
    await tester.pump(const Duration(milliseconds: 350));
    expect(api.searches, ['bj-old']);
    await tester.enterText(idField, 'bj-new');
    await tester.pump(const Duration(milliseconds: 350));
    api.complete('bj-new', 3);
    await tester.pumpAndSettle();
    api.complete('bj-old', 2);
    await tester.pumpAndSettle();
    expect(find.text('用户3'), findsOneWidget);
    expect(find.text('用户2'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('resume-share-user-3')));
    await tester.pump();
    expect(tester.widget<FilledButton>(submit).onPressed, isNotNull);
    await tester.enterText(idField, 'another');
    await tester.pump();
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);
    expect(find.text('用户3'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 400));
  });

  testWidgets(
    'Selection survives clearing search and empty remarks send the displayed default',
    (tester) async {
      final api = SearchGateway()..failing = 'PostResumesIdGuidance';
      await mount(tester, api);
      await tester.enterText(idField, 'bj-user');
      await tester.pump(const Duration(milliseconds: 350));
      api.complete('bj-user', 2);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('resume-share-user-2')));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(idField).controller!.text, isEmpty);
      expect(
        find.byKey(const ValueKey('resume-share-selected-user')),
        findsOneWidget,
      );
      final defaultText = tester
          .widget<TextField>(remarkField)
          .decoration!
          .hintText;
      expect(defaultText, '你好，这是我的简历，请查收。');
      for (final text in ['', '   ']) {
        await tester.enterText(remarkField, text);
        await tester.tap(submit);
        await tester.pumpAndSettle();
        expect(api.lastMutationBody!['user_ids'], [2]);
        expect(api.lastMutationBody!['question'], defaultText);
      }
      await tester.tap(find.byTooltip('取消选择'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('resume-share-selected-user')),
        findsNothing,
      );
      expect(tester.widget<FilledButton>(submit).onPressed, isNull);
    },
  );

  testWidgets(
    'Failure preserves remark and retries the same private share safely',
    (tester) async {
      final api = SearchGateway()..failing = 'PostResumesIdGuidance';
      await mount(tester, api);
      await tester.enterText(idField, 'bj-user');
      await tester.pump(const Duration(milliseconds: 350));
      api.complete('bj-user', 2);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('resume-share-user-2')));
      await tester.enterText(remarkField, ' 请帮我看看项目经历 ');
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(api.lastMutationBody!['destination'], 'USERS');
      expect(api.lastMutationBody!['user_ids'], [2]);
      expect(api.lastMutationBody!['question'], '请帮我看看项目经历');
      expect(api.lastMutationBody!['hidden_fields'], contains('personal_info'));
      expect(
        tester.widget<TextField>(remarkField).controller!.text,
        ' 请帮我看看项目经历 ',
      );
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(
        api.shareHeaders[0]['idempotency-key'],
        api.shareHeaders[1]['idempotency-key'],
      );
      expect(tester.widget<FilledButton>(submit).onPressed, isNotNull);
    },
  );

  testWidgets(
    'Leaving cancels pending debounce and in-flight results are harmless',
    (tester) async {
      final api = SearchGateway();
      await mount(tester, api);
      await tester.enterText(idField, 'pending');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 400));
      expect(api.searches, isEmpty);
      await mount(tester, api);
      await tester.enterText(idField, 'started');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpWidget(const SizedBox());
      api.complete('started', 2);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
