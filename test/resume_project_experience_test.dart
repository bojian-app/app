import 'package:bojian_mobile/app_store.dart';
import 'package:bojian_mobile/design.dart';
import 'package:bojian_mobile/resume_pages.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';
import 'support/resume_editor_helpers.dart';

Future<void> projectAction(WidgetTester tester, String action) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('resume-more')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ValueKey('project-action-$action')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'Project entry navigation, add, delete and cancel retain the right records',
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
              'title': '项目简历',
              'content': {
                'projects': [
                  {'name': '第一项目', 'description': '第一段背景', 'custom': 'keep'},
                  {'name': '第二项目', 'description': '第二段背景'},
                ],
              },
            }),
          ),
        ),
      );
      await tester.scrollUntilVisible(
        find.text('第二项目'),
        250,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('resume-modules')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.ensureVisible(find.text('第二项目'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('第二项目'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<PageView>(find.byType(PageView)).controller!.page,
        1,
      );
      expect(
        find.byKey(const ValueKey('resume-projects-1-name')).hitTestable(),
        findsOneWidget,
      );
      expect(find.byTooltip('上移项目经历'), findsNothing);
      await tester.enterText(
        find.byKey(const ValueKey('resume-projects-1-name')),
        '更新第二项目',
      );
      await projectAction(tester, 'add');
      expect(
        tester.widget<PageView>(find.byType(PageView)).controller!.page,
        2,
      );
      await tester.enterText(
        find.byKey(const ValueKey('resume-projects-2-name')),
        '第三项目',
      );
      final previous = find.byKey(const ValueKey('project-previous-2'));
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await Scrollable.ensureVisible(tester.element(previous), alignment: .5);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<IconButton>(find.byKey(const ValueKey('project-next-2')))
            .onPressed,
        isNull,
      );
      await tester.tap(previous);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('resume-projects-1-name')),
            )
            .controller!
            .text,
        '更新第二项目',
      );
      await projectAction(tester, 'delete');
      await tester.tap(find.text('删除').last);
      await tester.pumpAndSettle();
      await saveResumeSection(tester);
      final projects = api.lastMutationBody!['content']['projects'] as List;
      expect(projects.map((e) => e['name']), ['第一项目', '第三项目']);
      expect(projects.first['custom'], 'keep');
      await openResumeSection(tester, 4);
      await projectAction(tester, 'add');
      await tester.enterText(
        find.byKey(const ValueKey('resume-projects-2-name')),
        '放弃新增',
      );
      await tester.tap(find.byKey(const ValueKey('resume-close')));
      await tester.pumpAndSettle();
      expect(find.text('放弃新增'), findsNothing);
      await openResumeSection(tester, 4);
      await tester.drag(find.byType(PageView), const Offset(-650, 0));
      await tester.pumpAndSettle();
      expect(
        tester.widget<PageView>(find.byType(PageView)).controller!.page,
        1,
      );
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('resume-projects-1-name')),
            )
            .controller!
            .text,
        '第三项目',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Project dates use full dates, reject invalid ranges and save partial entries',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = FakeGateway();
      final store = await testStore(authenticated: true, api: api);
      addTearDown(store.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: ResumeEditor(
            store: store,
            draft: ResumeDraft(id: 0, title: '项目简历'),
          ),
        ),
      );
      await openResumeSection(tester, 4);
      await projectAction(tester, 'add');
      final start = find.byKey(const ValueKey('resume-projects-0-start_date'));
      final end = find.byKey(const ValueKey('resume-projects-0-end_date'));
      expect(tester.getRect(start).top, tester.getRect(end).top);
      Future<void> choose(Finder field, DateTime date) async {
        await tester.ensureVisible(field);
        await tester.pumpAndSettle();
        await tester.tap(field);
        await tester.pumpAndSettle();
        final picker = tester.widget<CupertinoDatePicker>(
          find.byType(CupertinoDatePicker),
        );
        expect(picker.mode, CupertinoDatePickerMode.date);
        picker.onDateTimeChanged(date);
        await tester.tap(find.text('确定'));
        await tester.pumpAndSettle();
      }

      await choose(start, DateTime(2022, 5, 10));
      await choose(end, DateTime(2022, 5, 10));
      expect(tester.widget<TextFormField>(end).controller!.text, isEmpty);
      await choose(end, DateTime.now());
      expect(tester.widget<TextFormField>(end).controller!.text, '至今');
      await saveResumeSection(tester);
      final project = api.lastMutationBody!['content']['projects'][0];
      expect(project['start_date'], '2022-05-10');
      expect(project['end_date'], '至今');
      expect(project['name'], isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}
