import 'package:bojian_mobile/date_wheel_picker.dart';
import 'package:bojian_mobile/design.dart';
import 'package:bojian_mobile/resume_pages.dart';
import 'package:bojian_mobile/app_store.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';
import 'support/resume_editor_helpers.dart';

void main() {
  testWidgets('Wheel changes commit only on confirmation and fit landscape', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(780, 360);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    DateTime? result;
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async => result = await showDateWheelPicker(
                context,
                title: '选择时间',
                initialDate: DateTime(2020, 6),
                firstDate: DateTime(1900),
                lastDate: DateTime(2040, 12),
                monthOnly: true,
              ),
              child: const Text('选择'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('选择'));
    await tester.pumpAndSettle();
    final wheel = tester.widget<CupertinoDatePicker>(
      find.byType(CupertinoDatePicker),
    );
    expect(wheel.mode, CupertinoDatePickerMode.monthYear);
    final labels = CupertinoLocalizations.of(
      tester.element(find.byType(CupertinoDatePicker)),
    );
    for (var month = 1; month <= 12; month++) {
      expect(labels.datePickerMonth(month), '$month月');
      expect(labels.datePickerStandaloneMonth(month), '$month月');
    }
    wheel.onDateTimeChanged(DateTime(2022, 9));
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(result, isNull);
    await tester.tap(find.text('选择'));
    await tester.pumpAndSettle();
    tester
        .widget<CupertinoDatePicker>(find.byType(CupertinoDatePicker))
        .onDateTimeChanged(DateTime(2022, 9));
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(result, DateTime(2022, 9));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Resume birth date clears inside the field and all dates use wheels',
    (tester) async {
      final store = await testStore(authenticated: true);
      addTearDown(store.dispose);
      final draft = decodeResume({
        'id': 0,
        'title': '测试简历',
        'content': {
          'personal_info': {'full_name': '测试', 'birth_date': '2000-02-29'},
          'job_expectation': {'position': '工程师'},
          'work_experiences': [
            {'start_date': '2020-01', 'current': true},
          ],
          'educations': [
            {'start_date': '2016-09'},
          ],
          'projects': [
            {'start_date': '2021-01'},
          ],
          'certifications': [
            {'date': '2022-03'},
          ],
        },
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: ResumeEditor(store: store, draft: draft),
        ),
      );
      await tester.pumpAndSettle();
      await openResumeSection(tester, 0);
      await tester.ensureVisible(find.text('更多基本信息'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('更多基本信息'));
      await tester.pumpAndSettle();
      final birth = find.byKey(const ValueKey('resume-birth_date'));
      await tester.ensureVisible(birth);
      await tester.pumpAndSettle();
      expect(find.text('清除出生日期'), findsNothing);
      final clear = find.descendant(
        of: birth,
        matching: find.byTooltip('清除出生日期'),
      );
      expect(clear, findsOneWidget);
      await tester.tap(clear);
      await tester.pumpAndSettle();
      expect(tester.widget<TextFormField>(birth).controller!.text, isEmpty);
      await tester.tap(birth);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<CupertinoDatePicker>(find.byType(CupertinoDatePicker))
            .mode,
        CupertinoDatePickerMode.date,
      );
      tester
          .widget<CupertinoDatePicker>(find.byType(CupertinoDatePicker))
          .onDateTimeChanged(DateTime(2000, 2, 29));
      await tester.tap(find.text('确定'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextFormField>(birth).controller!.text,
        '2000-02-29',
      );
      await saveResumeSection(tester);
      for (final (key, section) in [
        ('work-0-start_date', 3),
        ('education-0-start_date', 5),
        ('projects-0-start_date', 4),
        ('certifications-0-date', 7),
      ]) {
        await openResumeSection(tester, section);
        final field = find.byKey(ValueKey('resume-$key'));
        await tester.ensureVisible(field);
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<TextField>(
                find.descendant(of: field, matching: find.byType(TextField)),
              )
              .readOnly,
          true,
        );
        await tester.tap(field);
        await tester.pumpAndSettle();
        final picker = tester.widget<CupertinoDatePicker>(
          find.byType(CupertinoDatePicker),
        );
        expect(picker.mode, CupertinoDatePickerMode.monthYear);
        picker.onDateTimeChanged(DateTime(2023, 7));
        await tester.tap(find.text('确定'));
        await tester.pumpAndSettle();
        expect(tester.widget<TextFormField>(field).controller!.text, '2023-07');
        await saveResumeSection(tester);
      }
      expect(tester.takeException(), isNull);
    },
  );
}
