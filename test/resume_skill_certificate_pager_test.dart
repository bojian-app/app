import 'package:bojian_mobile/app_store.dart';
import 'package:bojian_mobile/design.dart';
import 'package:bojian_mobile/resume_pages.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';
import 'support/resume_editor_helpers.dart';

Future<void> entryAction(
  WidgetTester tester,
  String kind,
  String action,
) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('resume-more')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ValueKey('$kind-action-$action')));
  await tester.pumpAndSettle();
}

void main() {
  for (final (key, kind, section) in [
    ('skills', 'skill', 6),
    ('certifications', 'certificate', 7),
  ]) {
    testWidgets(
      '$key pager preserves records through add, delete, save and cancel',
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
              draft: decodeResume({
                'title': '测试简历',
                'content': {
                  key: [
                    {
                      'name': '第一条',
                      'custom': 'keep',
                      if (key == 'skills')
                        'description_rich': richContent('保留内容'),
                    },
                    {'name': '第二条'},
                  ],
                },
              }),
            ),
          ),
        );
        final second = find.byKey(ValueKey('resume-overview-$kind-1'));
        await tester.scrollUntilVisible(
          second,
          250,
          scrollable: find
              .descendant(
                of: find.byKey(const ValueKey('resume-modules')),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.ensureVisible(second);
        await tester.pumpAndSettle();
        await tester.tap(second);
        await tester.pumpAndSettle();
        expect(
          tester.widget<PageView>(find.byType(PageView)).controller!.page,
          1,
        );
        await tester.enterText(
          find.byKey(ValueKey('resume-$key-1-name')),
          '修改第二条',
        );
        await entryAction(tester, kind, 'add');
        expect(
          tester.widget<PageView>(find.byType(PageView)).controller!.page,
          2,
        );
        await tester.enterText(
          find.byKey(ValueKey('resume-$key-2-name')),
          '第三条',
        );
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        final previous = find.byKey(ValueKey('$kind-previous-2'));
        await tester.ensureVisible(previous);
        await tester.pumpAndSettle();
        await tester.tap(previous);
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<TextFormField>(find.byKey(ValueKey('resume-$key-1-name')))
              .controller!
              .text,
          '修改第二条',
        );
        await entryAction(tester, kind, 'delete');
        await tester.tap(find.text('删除').last);
        await tester.pumpAndSettle();
        await saveResumeSection(tester);
        final records = api.lastMutationBody!['content'][key] as List;
        expect(records.map((e) => e['name']), ['第一条', '第三条']);
        expect(records.first['custom'], 'keep');
        if (key == 'skills') {
          expect(records.first['description_rich'], isNotNull);
        }
        await openResumeSection(tester, section);
        await entryAction(tester, kind, 'add');
        await tester.enterText(
          find.byKey(ValueKey('resume-$key-2-name')),
          '放弃新增',
        );
        await tester.tap(find.byKey(const ValueKey('resume-close')));
        await tester.pumpAndSettle();
        expect(find.text('放弃新增'), findsNothing);
        await openResumeSection(tester, section);
        await tester.dragFrom(
          tester.getTopRight(find.byType(PageView)) + const Offset(-8, 70),
          const Offset(-350, 0),
        );
        await tester.pumpAndSettle();
        expect(
          tester.widget<PageView>(find.byType(PageView)).controller!.page,
          1,
        );
        expect(
          tester
              .widget<TextFormField>(find.byKey(ValueKey('resume-$key-1-name')))
              .controller!
              .text,
          '第三条',
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('$key empty state and last-entry deletion stay usable', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = await testStore(authenticated: true);
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
      await openResumeSection(tester, section);
      await entryAction(tester, kind, 'add');
      expect(find.byKey(ValueKey('resume-$key-0-name')), findsOneWidget);
      if (key == 'certifications') {
        final issuer = find.byKey(
          const ValueKey('resume-certifications-0-issuer'),
        );
        final date = find.byKey(const ValueKey('resume-certifications-0-date'));
        expect(tester.getRect(issuer).top, tester.getRect(date).top);
        await tester.tap(date);
        await tester.pumpAndSettle();
        final picker = tester.widget<CupertinoDatePicker>(
          find.byType(CupertinoDatePicker),
        );
        expect(picker.mode, CupertinoDatePickerMode.monthYear);
        picker.onDateTimeChanged(DateTime(2024, 6));
        await tester.tap(find.text('确定'));
        await tester.pumpAndSettle();
        expect(tester.widget<TextFormField>(date).controller!.text, '2024-06');
      }
      await entryAction(tester, kind, 'delete');
      await tester.tap(find.text('删除').last);
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('resume-$key-0-name')), findsNothing);
      await entryAction(tester, kind, 'add');
      expect(find.byKey(ValueKey('resume-$key-0-name')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
