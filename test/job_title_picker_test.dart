import 'dart:async';

import 'package:bojian_mobile/api/bojian_api.dart';
import 'package:bojian_mobile/app_store.dart';
import 'package:bojian_mobile/design.dart';
import 'package:bojian_mobile/job_title_picker.dart';
import 'package:bojian_mobile/resume_pages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';
import 'support/resume_editor_helpers.dart';

class JobTitleGateway extends FakeGateway {
  final queries = <String>[];
  final pending = <String, Completer<ApiDocument>>{};
  bool failSearch = false;

  @override
  Future<ApiDocument> call(
    String method, {
    Map<String, String> path = const {},
    Map<String, String> query = const {},
    Map<String, dynamic>? body,
    Map<String, String> headers = const {},
  }) async {
    if (method != 'GetJobTitles') {
      return super.call(
        method,
        path: path,
        query: query,
        body: body,
        headers: headers,
      );
    }
    final q = query['q'] ?? '';
    queries.add(q);
    if (failSearch) throw const ApiFailure('network unavailable');
    if (pending.containsKey(q)) return pending[q]!.future;
    return ApiDocument({
      'items': [
        if (q.isEmpty || q == '产品') ...[
          {'id': 'p1', 'name': '产品经理'},
          {'id': 'p2', 'name': '产品经理'},
        ],
      ],
    });
  }
}

void main() {
  testWidgets(
    'Remote selection saves canonical name and cancel keeps the previous value',
    (tester) async {
      final api = JobTitleGateway();
      final store = await testStore(authenticated: true, api: api);
      addTearDown(store.dispose);
      var saved = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: ResumeEditor(
            store: store,
            draft: ResumeDraft(id: 0, title: '新简历', position: '原职位'),
            onSaved: () => saved = true,
          ),
        ),
      );
      await openResumeSection(tester, 1);
      final field = find.byKey(const ValueKey('resume-position'));
      await tester.tap(field);
      await tester.pumpAndSettle();
      expect(api.queries.last, '原职位');
      await tester.enterText(
        find.byKey(const ValueKey('job-title-search')),
        '产品',
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(api.queries.last, '产品');
      expect(find.text('产品经理'), findsOneWidget);
      await tester.tap(find.text('产品经理'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextFormField>(field).controller!.text, '产品经理');
      await tester.tap(field);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('job-title-search')),
        '取消这次输入',
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(tester.widget<TextFormField>(field).controller!.text, '产品经理');
      await saveResumeSection(tester);
      await tester.tap(find.byKey(const ValueKey('resume-editor-save')));
      await tester.pumpAndSettle();
      expect(saved, isTrue);
      expect(
        api.lastMutationBody!['content']['job_expectation']['position'],
        '产品经理',
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final failed in [false, true]) {
    testWidgets(
      'Custom input is selectable with missing results or network failure ($failed)',
      (tester) async {
        final api = JobTitleGateway()..failSearch = failed;
        final store = await testStore(authenticated: true, api: api);
        addTearDown(store.dispose);
        String? selected;
        await tester.pumpWidget(
          MaterialApp(
            theme: appTheme,
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    selected = await showJobTitlePicker(context, store: store);
                  },
                  child: const Text('选择职位'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('选择职位'));
        await tester.pumpAndSettle();
        await enterJobTitleChoice(tester, '  新型职业体验师  ');
        expect(selected, '新型职业体验师');
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('Slower old responses never replace the latest search results', (
    tester,
  ) async {
    final api = JobTitleGateway();
    api.pending['旧'] = Completer<ApiDocument>();
    api.pending['新'] = Completer<ApiDocument>();
    final store = await testStore(authenticated: true, api: api);
    addTearDown(store.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: Scaffold(body: JobTitlePicker(store: store)),
      ),
    );
    await tester.pumpAndSettle();
    final search = find.byKey(const ValueKey('job-title-search'));
    await tester.enterText(search, '旧');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(search, '新');
    await tester.pump(const Duration(milliseconds: 300));
    api.pending['新']!.complete(
      ApiDocument({
        'items': [
          {'name': '新职位'},
        ],
      }),
    );
    await tester.pumpAndSettle();
    api.pending['旧']!.complete(
      ApiDocument({
        'items': [
          {'name': '旧职位'},
        ],
      }),
    );
    await tester.pumpAndSettle();
    expect(find.text('新职位'), findsOneWidget);
    expect(find.text('旧职位'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
