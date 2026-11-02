import 'package:bojian_mobile/app_store.dart';
import 'package:bojian_mobile/design.dart';
import 'package:bojian_mobile/resume_pages.dart';
import 'package:bojian_mobile/resume_work_experience.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';
import 'support/resume_editor_helpers.dart';

void main() {
  testWidgets(
    'Tapping each overview entry opens that work page and saves only its edits',
    (tester) async {
      final api = FakeGateway();
      final store = await testStore(authenticated: true, api: api);
      addTearDown(store.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: ResumeEditor(
            store: store,
            draft: decodeResume({
              'title': '定位经历',
              'content': {
                'work_experiences': [
                  for (var i = 0; i < 3; i++)
                    {'company': '公司$i', 'description': '第$i段职责'},
                ],
              },
            }),
          ),
        ),
      );
      for (final i in [2, 0, 1]) {
        final target = find.text(i == 1 ? '第1段职责' : '公司$i');
        await tester.ensureVisible(target);
        await tester.pumpAndSettle();
        await tester.tap(target);
        await tester.pumpAndSettle();
        final company = find.byKey(ValueKey('resume-work-$i-company'));
        expect(company.hitTestable(), findsOneWidget);
        expect(tester.widget<TextFormField>(company).controller!.text, '公司$i');
        expect(
          tester.widget<PageView>(find.byType(PageView)).controller!.page,
          i,
        );
        if (i == 1) {
          await tester.enterText(company, '修改第二家公司');
          await saveResumeSection(tester);
        } else {
          await tester.pageBack();
          await tester.pumpAndSettle();
        }
      }
      final entries =
          api.lastMutationBody!['content']['work_experiences'] as List;
      expect(entries.map((entry) => entry['company']), [
        '公司0',
        '修改第二家公司',
        '公司2',
      ]);
      expect(tester.takeException(), isNull);
    },
  );

  test('Editing one field retains metadata and unchanged rich description', () {
    final entry = WorkExperienceFields({
      'company': '原公司',
      'description': '原内容',
      'description_rich': {
        'blocks': [
          {'text': '原内容'},
        ],
      },
      'external_id': 'preserve',
      'current': true,
    });
    addTearDown(entry.dispose);
    entry.fields['company']!.text = '新公司';
    expect(entry.toJson()['description_rich'], isNotNull);
    expect(entry.toJson()['external_id'], 'preserve');
    entry.fields['description']!.text = '更新内容';
    expect(entry.toJson()['description_rich'], isNull);
  });

  test(
    'Rich-only imported description stays visible and retains formatting',
    () {
      final entry = WorkExperienceFields({
        'description_rich': richContent('原始工作内容'),
      });
      addTearDown(entry.dispose);
      expect(entry.fields['description']!.text, '原始工作内容');
      expect(entry.toJson()['description_rich'], isNotNull);
    },
  );

  testWidgets('Editing separate experiences preserves their original order', (
    tester,
  ) async {
    final api = FakeGateway();
    final store = AppStore(api: api, storage: MemoryStorage());
    await store.initialize();
    store.session = {'access_token': 'test'};
    addTearDown(store.dispose);
    final draft = decodeResume({
      'id': 0,
      'title': '测试简历',
      'content': {
        'personal_info': {'full_name': '测试姓名'},
        'job_expectation': {'position': '工程师'},
        'work_experiences': [
          {
            'company': '第一家公司',
            'position': '原职位',
            'description': '第一段内容',
            'start_date': '2020-01',
            'custom': 'keep-first',
          },
          {
            'company': '第二家公司',
            'position': '第二职位',
            'description': '第二段内容',
            'start_date': '2023-06',
            'current': true,
            'description_rich': {'blocks': []},
            'custom': 'keep-second',
          },
        ],
      },
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ResumeEditor(store: store, draft: draft),
                ),
              ),
              child: const Text('编辑'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('编辑'));
    await tester.pumpAndSettle();
    await openResumeSection(tester, 3);
    final description = find.byKey(const ValueKey('resume-work-0-description'));
    await tester.ensureVisible(description);
    await tester.pumpAndSettle();
    await tester.enterText(description, '修改第一段内容');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    expect(find.byTooltip('上移'), findsNothing);
    expect(find.byTooltip('下移'), findsNothing);
    final next = find.byKey(const ValueKey('work-next-0'));
    expect(
      tester
          .widget<IconButton>(find.byKey(const ValueKey('work-previous-0')))
          .onPressed,
      isNull,
    );
    expect(tester.widget<IconButton>(next).onPressed, isNotNull);
    expect(find.text('1 / 2  ·  左右滑动切换'), findsNothing);
    await tester.ensureVisible(next);
    await tester.pumpAndSettle();
    await tester.tap(next);
    await tester.pumpAndSettle();
    final second = find.byKey(const ValueKey('resume-work-1-company'));
    expect(tester.widget<PageView>(find.byType(PageView)).controller!.page, 1);
    expect(second.hitTestable(), findsOneWidget);
    await tester.enterText(second, '修改第二家公司');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    final previous = find.byKey(const ValueKey('work-previous-1'));
    expect(
      tester
          .widget<IconButton>(find.byKey(const ValueKey('work-next-1')))
          .onPressed,
      isNull,
    );
    expect(tester.widget<IconButton>(previous).onPressed, isNotNull);
    await tester.ensureVisible(previous);
    await tester.pumpAndSettle();
    await tester.tap(previous);
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextFormField>(description).controller!.text,
      '修改第一段内容',
    );
    await saveResumeSection(tester);
    final saved =
        api.documents['GetResumes']!['items'][0]['content']['work_experiences']
            as List;
    expect(saved.map((v) => v['company']), ['第一家公司', '修改第二家公司']);
    expect(saved[1]['description'], '第二段内容');
    expect(saved[1]['description_rich'], isNotNull);
    expect(saved[1]['current'], true);
    expect(saved[0]['description'], '修改第一段内容');
    expect(saved[0]['custom'], 'keep-first');
    expect(saved[1]['custom'], 'keep-second');
  });

  test(
    'Present end date retains API semantics and can be changed or cleared',
    () {
      final entry = WorkExperienceFields({
        'current': true,
        'end_date': '2025-01',
      });
      addTearDown(entry.dispose);
      expect(entry.fields['end_date']!.text, '至今');
      expect(entry.toJson()['current'], isTrue);
      expect(entry.toJson()['end_date'], '');
      entry.fields['end_date']!.text = '2026-06';
      expect(entry.toJson()['current'], isFalse);
      expect(entry.toJson()['end_date'], '2026-06');
      entry.fields['end_date']!.text = '至今';
      entry.fields['end_date']!.clear();
      expect(entry.toJson()['current'], isFalse);
      expect(entry.toJson()['end_date'], '');
    },
  );

  test('Date range is strictly ordered and incomplete dates stay optional', () {
    final entry = WorkExperienceFields({});
    addTearDown(entry.dispose);
    final today = DateTime(2026, 10, 29);
    for (final (start, end, valid) in [
      ('', '', true),
      ('2026-10-29', '', true),
      ('', '至今', true),
      ('2026-10-28', '至今', true),
      ('2026-10-29', '至今', false),
      ('2026-10-30', '至今', false),
      ('2024-02-29', '2024-03-01', true),
      ('2024-03-01', '2024-03-01', false),
      ('2024-03-02', '2024-03-01', false),
      ('2025-02-29', '2025-03-01', false),
      ('2020-01', '2020-02', true),
    ]) {
      entry.fields['start_date']!.text = start;
      entry.fields['end_date']!.text = end;
      expect(
        entry.dateRangeError(today: today) == null,
        valid,
        reason: '$start -> $end',
      );
    }
  });

  testWidgets('Existing invalid date range cannot be saved', (tester) async {
    final api = FakeGateway();
    final store = await testStore(authenticated: true, api: api);
    addTearDown(store.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: ResumeEditor(
          store: store,
          draft: decodeResume({
            'title': '旧简历',
            'content': {
              'work_experiences': [
                {'start_date': '2026-01-02', 'end_date': '2026-01-01'},
              ],
            },
          }),
        ),
      ),
    );
    await openResumeSection(tester, 3);
    await saveResumeSection(tester);
    expect(find.byKey(const ValueKey('resume-section-save')), findsOneWidget);
    expect(find.text('结束时间必须晚于开始时间'), findsOneWidget);
    await saveResumeSection(tester);
    expect(find.byKey(const ValueKey('resume-section-save')), findsOneWidget);
    expect(api.calls, isNot(contains('PostResumes')));
    expect(tester.takeException(), isNull);
  });

  for (final (width, scale) in [(360.0, 1.0), (320.0, 2.0)]) {
    testWidgets(
      'Work fields adapt and present end date saves ($width/$scale)',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 800);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final api = FakeGateway();
        final store = await testStore(authenticated: true, api: api);
        addTearDown(store.dispose);
        await tester.pumpWidget(
          MaterialApp(
            theme: appTheme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: ResumeEditor(
              store: store,
              draft: decodeResume({
                'title': '工作简历',
                'content': {
                  'work_experiences': [
                    {'company': '测试公司', 'position': '前端工程师'},
                  ],
                },
              }),
            ),
          ),
        );
        await openResumeSection(tester, 3);
        expect(find.text('目前仍在职'), findsNothing);
        final start = find.byKey(const ValueKey('resume-work-0-start_date'));
        final end = find.byKey(const ValueKey('resume-work-0-end_date'));
        final startRect = tester.getRect(start);
        final endRect = tester.getRect(end);
        if (scale == 1) {
          final position = find.byKey(const ValueKey('resume-work-0-position'));
          final industry = find.byKey(const ValueKey('resume-work-0-industry'));
          expect(
            tester.getRect(position).bottom,
            tester.getRect(industry).bottom,
          );
          final positionText = find.descendant(
            of: position,
            matching: find.byType(EditableText),
          );
          final industryText = find.descendant(
            of: industry,
            matching: find.byType(EditableText),
          );
          expect(
            tester.getTopLeft(positionText).dy,
            closeTo(tester.getTopLeft(industryText).dy, 0.5),
          );
          expect(startRect.top, endRect.top);
          expect(startRect.right, lessThan(endRect.left));
        } else {
          expect(startRect.bottom, lessThan(endRect.top));
        }
        Future<void> choose(Finder field, DateTime date) async {
          await tester.ensureVisible(field);
          await tester.tap(field);
          await tester.pumpAndSettle();
          final wheel = tester.widget<CupertinoDatePicker>(
            find.byType(CupertinoDatePicker),
          );
          expect(wheel.mode, CupertinoDatePickerMode.date);
          wheel.onDateTimeChanged(date);
          await tester.tap(find.text('确定'));
          await tester.pumpAndSettle();
        }

        await choose(start, DateTime(2020, 2, 29));
        expect(
          tester.widget<TextFormField>(start).controller!.text,
          '2020-02-29',
        );
        await choose(end, DateTime(2020, 2, 29));
        expect(tester.widget<TextFormField>(end).controller!.text, isEmpty);
        await choose(end, DateTime(2020, 2, 28));
        expect(tester.widget<TextFormField>(end).controller!.text, isEmpty);
        await choose(end, DateTime(2020, 3, 1));
        expect(
          tester.widget<TextFormField>(end).controller!.text,
          '2020-03-01',
        );
        await choose(start, DateTime(2020, 3, 1));
        expect(
          tester.widget<TextFormField>(start).controller!.text,
          '2020-02-29',
        );
        await tester.ensureVisible(end);
        await tester.tap(end);
        await tester.pumpAndSettle();
        expect(find.widgetWithText(ActionChip, '至今'), findsNothing);
        expect(
          tester
              .widget<CupertinoDatePicker>(find.byType(CupertinoDatePicker))
              .mode,
          CupertinoDatePickerMode.date,
        );
        tester
            .widget<CupertinoDatePicker>(find.byType(CupertinoDatePicker))
            .onDateTimeChanged(DateTime.now());
        await tester.tap(find.text('确定'));
        await tester.pumpAndSettle();
        expect(tester.widget<TextFormField>(end).controller!.text, '至今');
        await tester.tap(end);
        await tester.pumpAndSettle();
        await tester.tap(find.text('取消'));
        await tester.pumpAndSettle();
        expect(tester.widget<TextFormField>(end).controller!.text, '至今');
        await saveResumeSection(tester);
        final work = api.lastMutationBody!['content']['work_experiences'][0];
        expect(work['current'], isTrue);
        expect(work['end_date'], '');
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('New entries can be added and removed before saving', (
    tester,
  ) async {
    final store = AppStore(api: FakeGateway(), storage: MemoryStorage());
    await store.initialize();
    addTearDown(store.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: ResumeEditor(
          store: store,
          draft: ResumeDraft(id: 0, title: '新简历'),
        ),
      ),
    );
    await openResumeSection(tester, 3);
    await workMenuAction(tester, 'add');
    expect(find.byKey(const ValueKey('resume-work-0-company')), findsOneWidget);
    await workMenuAction(tester, 'delete');
    await tester.tap(find.text('删除').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('resume-work-0-company')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Adding opens a new page; swiping and deleting preserve edits', (
    tester,
  ) async {
    final api = FakeGateway();
    final store = await testStore(authenticated: true, api: api);
    addTearDown(store.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: ResumeEditor(
          store: store,
          draft: ResumeDraft(id: 0, title: '分页简历'),
        ),
      ),
    );
    await openResumeSection(tester, 3);
    for (var i = 0; i < 3; i++) {
      await workMenuAction(tester, 'add');
      final company = find.byKey(ValueKey('resume-work-$i-company'));
      expect(company.hitTestable(), findsOneWidget);
      expect(tester.widget<TextFormField>(company).controller!.text, isEmpty);
      await tester.enterText(company, '公司$i');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
    }
    final pager = find.byKey(const ValueKey('resume-work-pager'));
    await tester.drag(pager, const Offset(600, 0));
    await tester.pumpAndSettle();
    final middle = find.byKey(const ValueKey('resume-work-1-company'));
    await tester.ensureVisible(middle);
    expect(tester.widget<TextFormField>(middle).controller!.text, '公司1');
    await workMenuAction(tester, 'delete');
    await tester.tap(find.text('删除').last);
    await tester.pumpAndSettle();
    expect(tester.widget<TextFormField>(middle).controller!.text, '公司2');
    await tester.drag(pager, const Offset(600, 0));
    await tester.pumpAndSettle();
    final first = find.byKey(const ValueKey('resume-work-0-company'));
    expect(tester.widget<TextFormField>(first).controller!.text, '公司0');
    await saveResumeSection(tester);
    final saved = api.lastMutationBody!['content']['work_experiences'] as List;
    expect(saved.map((e) => e['company']), ['公司0', '公司2']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Saving finds invalid dates on an unmounted page', (
    tester,
  ) async {
    final store = await testStore(authenticated: true);
    addTearDown(store.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: ResumeEditor(
          store: store,
          draft: decodeResume({
            'title': '旧简历',
            'content': {
              'work_experiences': [
                {'company': '第一家公司'},
                {'company': '第二家公司'},
                {
                  'company': '日期错误公司',
                  'start_date': '2026-02-02',
                  'end_date': '2026-02-01',
                },
              ],
            },
          }),
        ),
      ),
    );
    await openResumeSection(tester, 3);
    expect(
      find.byKey(const ValueKey('resume-work-0-company')).hitTestable(),
      findsOneWidget,
    );
    await saveResumeSection(tester);
    expect(find.byKey(const ValueKey('resume-section-save')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('resume-work-2-company')).hitTestable(),
      findsOneWidget,
    );
    expect(find.text('结束时间必须晚于开始时间'), findsOneWidget);
    // Leaving without saving rolls back all section edits, including new entries.
    await tester.pageBack();
    await tester.pumpAndSettle();
    await openResumeSection(tester, 3);
    expect(
      find.byKey(const ValueKey('resume-work-0-company')).hitTestable(),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
