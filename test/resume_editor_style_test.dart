import 'package:bojian_mobile/app_store.dart';
import 'package:bojian_mobile/design.dart';
import 'package:bojian_mobile/resume_editor_progress.dart';
import 'package:bojian_mobile/resume_pages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

void main() {
  test('Missing name and school cannot produce a complete editor score', () {
    final fields = {
      'name': '姓名',
      'position': '开发工程师',
      'phone': '13812345678',
      'summary': '负责前端模块开发和上线交付',
    };
    final projects = [
      {'name': '订单流程改进', 'description': '负责结算流程与前端交付'},
    ];
    final schools = [
      {'institution': '学校名称', 'field_of_study': '计算机科学与技术'},
    ];
    final skills = [
      {'name': 'Flutter'},
    ];
    ResumeEditorProgress evaluate() => resumeEditorProgress(
      fields: fields,
      work: const [],
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
    'Completeness follows edits and bottom save validates distant fields',
    (tester) async {
      final api = FakeGateway();
      final store = await testStore(authenticated: true, api: api);
      addTearDown(store.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: ResumeEditor(
            store: store,
            draft: ResumeDraft(id: 0, title: '测试简历'),
          ),
        ),
      );
      expect(find.text('已填写 0/7 项基础内容'), findsOneWidget);
      expect(find.byKey(const ValueKey('resume-birth_date')), findsNothing);
      expect(
        find.byKey(const ValueKey('resume-birth_date'), skipOffstage: false),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('resume-title')), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('resume-name')), '李明');
      await tester.pump();
      expect(find.text('已填写 1/7 项基础内容'), findsOneWidget);
      await tester.ensureVisible(find.widgetWithText(ChoiceChip, '专业技能'));
      await tester.tap(find.widgetWithText(ChoiceChip, '专业技能'));
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.text('添加技能')).top,
        lessThan(tester.view.physicalSize.height),
      );
      await tester.tap(find.byKey(const ValueKey('resume-editor-save')));
      await tester.pumpAndSettle();
      expect(find.text('请填写意向职位'), findsOneWidget);
      expect(api.calls, isNot(contains('PostResumes')));
      expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('resume-name')))
            .controller!
            .text,
        '李明',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Short landscape uses toolbar save without overflowing behind the keyboard',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(640, 320);
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
                .copyWith(viewInsets: const EdgeInsets.only(bottom: 180)),
            child: child!,
          ),
          home: ResumeEditor(
            store: store,
            draft: ResumeDraft(id: 0, title: '测试简历'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ChoiceChip), findsNothing);
      final save = find.byKey(const ValueKey('resume-editor-save'));
      expect(save, findsOneWidget);
      expect(tester.getRect(save).bottom, lessThanOrEqualTo(140));
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(find.text('请填写姓名'), findsOneWidget);
      expect(find.text('请填写意向职位'), findsOneWidget);
      expect(api.calls, isNot(contains('PostResumes')));
      expect(tester.takeException(), isNull);
    },
  );

  for (final dark in [false, true]) {
    testWidgets(
      'Card editor scrolls with large text and keyboard on narrow screens (dark=$dark)',
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
            'job_expectation': {'position': '开发工程师'},
            'projects': [
              {
                'name': '订单核心流程与结算体验改进项目',
                'role': '前端开发',
                'start_date': '2024-01',
                'end_date': '2025-01',
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
        await tester.pumpAndSettle();
        final description = find.byKey(
          const ValueKey('resume-projects-0-description'),
        );
        await tester.ensureVisible(description);
        await tester.pumpAndSettle();
        await tester.enterText(description, '更新后的项目工作内容，保留其他字段');
        await tester.pump();
        expect(
          tester.widget<TextFormField>(description).controller!.text,
          '更新后的项目工作内容，保留其他字段',
        );
        expect(
          find.byKey(const ValueKey('resume-editor-save')),
          findsOneWidget,
        );
        expect(
          tester
              .getRect(find.byKey(const ValueKey('resume-editor-save')))
              .bottom,
          lessThanOrEqualTo(400),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
