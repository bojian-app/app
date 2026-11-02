import 'package:bojian_mobile/api/bojian_api.dart';
import 'package:bojian_mobile/app_store.dart';
import 'package:bojian_mobile/design.dart';
import 'package:bojian_mobile/resume_option_picker.dart';
import 'package:bojian_mobile/resume_pages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';
import 'support/resume_editor_helpers.dart';

class OptionGateway extends FakeGateway {
  final queries = <(String, String)>[];
  bool failSearch = false;
  @override
  Future<ApiDocument> call(
    String method, {
    Map<String, String> path = const {},
    Map<String, String> query = const {},
    Map<String, dynamic>? body,
    Map<String, String> headers = const {},
  }) async {
    if (!['GetIndustries', 'GetCities', 'GetJobTitles'].contains(method)) {
      return super.call(
        method,
        path: path,
        query: query,
        body: body,
        headers: headers,
      );
    }
    final q = query['q'] ?? '';
    queries.add((method, q));
    if (failSearch) throw const ApiFailure('network unavailable');
    return ApiDocument({
      'items': [
        if (method == 'GetJobTitles' && (q.isEmpty || q == '前端'))
          {'id': 'j1', 'name': '前端开发工程师'},
        if (method == 'GetIndustries' && (q.isEmpty || q == '软件'))
          {'id': 'i1', 'name': '软件开发', 'parentName': '信息技术服务业'},
        if (method == 'GetCities' && (q.isEmpty || q == '杭州'))
          {'id': 'c1', 'name': '杭州市', 'province': '浙江省'},
      ],
    });
  }
}

void main() {
  testWidgets(
    'Work position supports remote choice, custom input, cancel and clear',
    (tester) async {
      final api = OptionGateway();
      final store = await testStore(authenticated: true, api: api);
      addTearDown(store.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: ResumeEditor(
            store: store,
            draft: ResumeDraft(id: 0, title: '职位测试'),
          ),
        ),
      );
      await openResumeSection(tester, 3);
      await workMenuAction(tester, 'add');
      final field = find.byKey(const ValueKey('resume-work-0-position'));
      await tester.tap(field);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('job-title-search')),
        '前端',
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(api.queries.last, ('GetJobTitles', '前端'));
      await tester.tap(find.text('前端开发工程师'));
      await tester.pumpAndSettle();
      await saveResumeSection(tester);
      expect(
        api.lastMutationBody!['content']['work_experiences'][0]['position'],
        '前端开发工程师',
      );
      await openResumeSection(tester, 3);
      await tester.tap(field);
      await tester.pumpAndSettle();
      await enterJobTitleChoice(tester, '自定义前端助理');
      await tester.tap(field);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('job-title-search')),
        '未确认输入',
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(tester.widget<TextFormField>(field).controller!.text, '自定义前端助理');
      await saveResumeSection(tester);
      expect(
        api.lastMutationBody!['content']['work_experiences'][0]['position'],
        '自定义前端助理',
      );
      await openResumeSection(tester, 3);
      await tester.tap(find.byTooltip('清除职位'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextFormField>(field).controller!.text, isEmpty);
      expect(find.byKey(const ValueKey('job-title-search')), findsNothing);
      await saveResumeSection(tester);
      expect(
        api.lastMutationBody!['content']['work_experiences'][0]['position'],
        isEmpty,
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final (kind, field, query, chosen) in [
    (ResumeOptionKind.industry, 'industry', '软件', '软件开发'),
    (ResumeOptionKind.city, 'city', '杭州', '杭州市'),
  ]) {
    testWidgets(
      '${kind.name} remote choice is persisted and cancellation keeps it',
      (tester) async {
        final api = OptionGateway();
        final store = await testStore(authenticated: true, api: api);
        addTearDown(store.dispose);
        var saved = false;
        await tester.pumpWidget(
          MaterialApp(
            theme: appTheme,
            home: ResumeEditor(
              store: store,
              draft: ResumeDraft(id: 0, title: '新简历'),
              onSaved: () => saved = true,
            ),
          ),
        );
        await openResumeSection(tester, 1);
        final input = find.byKey(ValueKey('resume-$field'));
        await tester.ensureVisible(input);
        await tester.tap(input);
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(ValueKey('${kind.keyPrefix}-search')),
          query,
        );
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();
        expect(api.queries.last, (kind.method, query));
        await tester.tap(find.text(chosen));
        await tester.pumpAndSettle();
        expect(tester.widget<TextFormField>(input).controller!.text, chosen);
        await tester.tap(input);
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(ValueKey('${kind.keyPrefix}-search')),
          '未确认的输入',
        );
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(tester.widget<TextFormField>(input).controller!.text, chosen);
        await saveResumeSection(tester);
        expect(saved, isTrue);
        expect(
          api.lastMutationBody!['content']['job_expectation'][field],
          chosen,
        );
        expect(tester.takeException(), isNull);
      },
    );

    for (final failed in [false, true]) {
      testWidgets(
        '${kind.name} custom input works with no matches or failed network ($failed)',
        (tester) async {
          final api = OptionGateway()..failSearch = failed;
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
                      selected = await showResumeOptionPicker(
                        context,
                        store: store,
                        kind: kind,
                      );
                    },
                    child: const Text('打开选择'),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('打开选择'));
          await tester.pumpAndSettle();
          await enterResumeOptionChoice(
            tester,
            '  自定义${kind.label}  ',
            keyPrefix: kind.keyPrefix,
          );
          expect(selected, '自定义${kind.label}');
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'Work experience industry uses the shared catalogue and saves with partial details',
    (tester) async {
      final api = OptionGateway();
      final store = await testStore(authenticated: true, api: api);
      addTearDown(store.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: ResumeEditor(
            store: store,
            draft: ResumeDraft(id: 0, title: '新简历'),
            onSaved: () {},
          ),
        ),
      );
      await openResumeSection(tester, 3);
      await workMenuAction(tester, 'add');
      final field = find.byKey(const ValueKey('resume-work-0-industry'));
      await tester.ensureVisible(field);
      await tester.tap(field);
      await tester.pumpAndSettle();
      expect(api.queries.last.$1, 'GetIndustries');
      await tester.tap(find.text('软件开发'));
      await tester.pumpAndSettle();
      await saveResumeSection(tester);
      expect(
        api.lastMutationBody!['content']['work_experiences'][0]['industry'],
        '软件开发',
      );
      expect(tester.takeException(), isNull);
    },
  );
}
