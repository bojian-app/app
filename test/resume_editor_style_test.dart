import 'package:bojian_mobile/app_store.dart';
import 'package:bojian_mobile/design.dart';
import 'package:bojian_mobile/resume_editor_progress.dart';
import 'package:bojian_mobile/resume_pages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';
import 'support/resume_editor_helpers.dart';

void main() {
  test('All six groups are needed for a complete editor score', () {
    final fields = {
      'name': '姓名',
      'position': '开发工程师',
      'city': '杭州',
      'phone': '13812345678',
      'summary': '负责前端模块开发和上线交付',
    };
    final projects = [
      {
        'name': '订单流程改进',
        'role': '开发',
        'start_date': '2023-01',
        'end_date': '2024-01',
        'description': '负责结算流程与前端交付',
        'achievements': '交付流程',
      },
    ];
    final schools = [
      {
        'institution': '学校名称',
        'field_of_study': '计算机科学与技术',
        'start_date': '2018-09',
        'end_date': '2022-06',
        'campus_experience': '课程实践',
      },
    ];
    final skills = [
      {'name': 'Flutter', 'description': '应用开发'},
    ];
    ResumeEditorProgress evaluate() => resumeEditorProgress(
      fields: fields,
      work: const [
        {
          'company': '测试公司',
          'position': '开发',
          'start_date': '2022-01',
          'end_date': '2025-01',
          'description': '开发工作',
        },
      ],
      projects: projects,
      education: schools,
      skills: skills,
    );
    expect(evaluate().percent, lessThan(100));
    fields['name'] = '李明';
    schools.single['institution'] = '测试大学';
    expect(evaluate().percent, 100);
  });

  testWidgets(
    'Overview opens only the selected section and keeps saved edits',
    (tester) async {
      final api = FakeGateway();
      final store = await testStore(authenticated: true, api: api);
      addTearDown(store.dispose);
      var saved = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: ResumeEditor(
            store: store,
            draft: ResumeDraft(id: 0, title: '测试简历'),
            onSaved: () => saved = true,
          ),
        ),
      );
      expect(find.byType(TextFormField), findsNothing);
      expect(find.byType(ChoiceChip), findsNothing);
      expect(
        find.byKey(const ValueKey('resume-overview-section-0')),
        findsOneWidget,
      );
      expect(find.text('0%'), findsOneWidget);
      await openResumeSection(tester, 0);
      expect(find.byKey(const ValueKey('resume-position')), findsNothing);
      expect(find.byKey(const ValueKey('resume-birth_date')), findsNothing);
      expect(
        find.byKey(const ValueKey('resume-birth_date'), skipOffstage: false),
        findsOneWidget,
      );
      await tester.enterText(find.byKey(const ValueKey('resume-name')), '李明');
      await saveResumeSection(tester);
      expect(find.text('李明'), findsOneWidget);
      expect(find.text('0%'), findsOneWidget);
      expect(api.calls.where((c) => c == 'PostResumes'), hasLength(1));
      await openResumeSection(tester, 1);
      await tester.tap(find.byKey(const ValueKey('resume-position')));
      await tester.pumpAndSettle();
      await enterJobTitleChoice(tester, '工程师');
      await tester.tap(find.byKey(const ValueKey('resume-city')));
      await tester.pumpAndSettle();
      await enterResumeOptionChoice(tester, '杭州', keyPrefix: 'city');
      await saveResumeSection(tester);
      expect(find.text('工程师'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('resume-editor-completeness-percent')),
        -250,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('resume-modules')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      expect(find.text('17%'), findsOneWidget);
      expect(store.resumes.single.progress, closeTo(1 / 6, .0001));
      expect(find.textContaining('意向城市：杭州'), findsNothing);
      expect(api.calls.where((c) => c == 'PostResumes'), hasLength(1));
      expect(api.calls, contains('PatchResumesId'));
      expect(saved, isTrue);
      expect(api.calls, contains('PostResumes'));
      expect(api.lastMutationBody!['content']['job_expectation']['city'], '杭州');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Back discards section text and removed or reordered entries', (
    tester,
  ) async {
    final api = FakeGateway();
    final store = await testStore(authenticated: true, api: api);
    addTearDown(store.dispose);
    final draft = decodeResume({
      'title': '测试简历',
      'content': {
        'personal_info': {'full_name': '原姓名'},
        'job_expectation': {'position': '工程师'},
        'work_experiences': [
          {
            'company': '甲公司',
            'description': '原描述',
            'custom': 'preserved',
            'description_rich': richContent('原描述'),
          },
          {'company': '乙公司', 'description': '第二段'},
        ],
      },
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: ResumeEditor(store: store, draft: draft),
      ),
    );
    await openResumeSection(tester, 0);
    await tester.enterText(find.byKey(const ValueKey('resume-name')), '未保存姓名');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('原姓名'), findsOneWidget);
    expect(find.text('未保存姓名'), findsNothing);
    await openResumeSection(tester, 3);
    final description = find.byKey(const ValueKey('resume-work-0-description'));
    await tester.ensureVisible(description);
    await tester.pumpAndSettle();
    await tester.enterText(description, '未保存描述');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await workMenuAction(tester, 'delete');
    await tester.tap(find.text('删除').last);
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await openResumeSection(tester, 3);
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const ValueKey('resume-work-0-company')),
          )
          .controller!
          .text,
      '甲公司',
    );
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const ValueKey('resume-work-0-description')),
          )
          .controller!
          .text,
      '原描述',
    );
    final pager = find.byKey(const ValueKey('resume-work-pager'));
    await tester.dragFrom(
      tester.getTopRight(pager) + const Offset(-12, 100),
      const Offset(-600, 0),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const ValueKey('resume-work-1-company')),
          )
          .controller!
          .text,
      '乙公司',
    );
    await saveResumeSection(tester);
    final work =
        api.documents['GetResumes']!['items'][0]['content']['work_experiences']
            as List;
    expect(work[0]['custom'], 'preserved');
    expect(work[0]['description_rich'], isNotNull);
    expect(tester.takeException(), isNull);
  });

  for (final id in [0, 7]) {
    for (final (section, field, value) in [
      (0, 'email', 'candidate@example.com'),
      (1, 'city', '杭州'),
      (3, 'work-0-description', '参与订单模块开发'),
    ]) {
      testWidgets(
        'Partial section $section saves without name or position (id=$id)',
        (tester) async {
          final api = FakeGateway();
          final store = await testStore(authenticated: true, api: api);
          addTearDown(store.dispose);
          var saved = false;
          await tester.pumpWidget(
            MaterialApp(
              theme: appTheme,
              home: ResumeEditor(
                store: store,
                draft: ResumeDraft(
                  id: id,
                  revision: id == 0 ? 0 : 3,
                  title: '',
                ),
                onSaved: () => saved = true,
              ),
            ),
          );
          await openResumeSection(tester, section);
          if (section == 3) {
            await workMenuAction(tester, 'add');
          }
          final input = find.byKey(ValueKey('resume-$field'));
          await tester.ensureVisible(input);
          if (field == 'city') {
            await tester.tap(input);
            await tester.pumpAndSettle();
            await enterResumeOptionChoice(tester, value, keyPrefix: 'city');
          } else {
            await tester.enterText(input, value);
          }
          await saveResumeSection(tester);
          expect(
            find.byKey(const ValueKey('resume-section-save')),
            findsNothing,
          );
          expect(find.text('请填写姓名'), findsNothing);
          expect(find.text('请填写意向职位'), findsNothing);
          final mutation = id == 0 ? 'PostResumes' : 'PatchResumesId';
          expect(
            find.byKey(const ValueKey('resume-editor-save')),
            findsNothing,
          );
          expect(saved, isTrue);
          expect(api.calls.where((call) => call == mutation), hasLength(1));
          final row =
              (api.documents['GetResumes']!['items'] as List).single as Map;
          expect(row['title'], '未命名简历');
          final content = row['content'] as Map;
          expect(content['personal_info']['full_name'], isEmpty);
          expect(content['job_expectation']['position'], isEmpty);
          switch (section) {
            case 0:
              expect(content['personal_info']['email'], value);
            case 1:
              expect(content['job_expectation']['city'], value);
            case 3:
              final work = (content['work_experiences'] as List).single as Map;
              expect(work['description'], value);
              expect(work['company'], isEmpty);
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'Section toolbar save fits a short landscape above the keyboard',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(640, 320);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final inset = ValueNotifier(0.0);
      addTearDown(inset.dispose);
      final store = await testStore(authenticated: true);
      addTearDown(store.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          builder: (context, child) => ValueListenableBuilder<double>(
            valueListenable: inset,
            builder: (context, value, _) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(viewInsets: EdgeInsets.only(bottom: value)),
              child: child!,
            ),
          ),
          home: ResumeEditor(
            store: store,
            draft: ResumeDraft(id: 0, title: '测试简历'),
          ),
        ),
      );
      await openResumeSection(tester, 0);
      inset.value = 180;
      await tester.pumpAndSettle();
      final save = find.byKey(const ValueKey('resume-section-save'));
      expect(tester.getRect(save).bottom, lessThanOrEqualTo(140));
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(find.text('请填写姓名'), findsNothing);
      expect(find.byKey(const ValueKey('resume-section-save')), findsNothing);
      expect(find.byKey(const ValueKey('resume-editor-save')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final dark in [false, true]) {
    testWidgets(
      'Independent editor fits narrow screens with large text (dark=$dark)',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(320, 640);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final store = await testStore(authenticated: true);
        addTearDown(store.dispose);
        final draft = decodeResume({
          'title': '测试简历',
          'content': {
            'personal_info': {'full_name': '李明'},
            'job_expectation': {'position': '工程师'},
            'projects': [
              {
                'name': '订单核心流程与结算体验改进项目',
                'role': '前端开发',
                'description': '负责结算页面开发与交付',
              },
            ],
          },
        });
        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? appDarkTheme : appTheme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(2),
                viewInsets: const EdgeInsets.only(bottom: 240),
              ),
              child: child!,
            ),
            home: ResumeEditor(store: store, draft: draft),
          ),
        );
        await openResumeSection(tester, 4);
        final description = find.byKey(
          const ValueKey('resume-projects-0-description'),
        );
        await tester.ensureVisible(description);
        await tester.pumpAndSettle();
        await tester.enterText(description, '更新后的项目工作内容，保留其他字段');
        expect(
          tester
              .getRect(find.byKey(const ValueKey('resume-section-save')))
              .bottom,
          lessThanOrEqualTo(400),
        );
        await saveResumeSection(tester);
        expect(find.text('更新后的项目工作内容，保留其他字段'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
