import 'package:bojian_mobile/app_store.dart';
import 'package:bojian_mobile/resume_additional_fields.dart';
import 'package:bojian_mobile/resume_pages.dart';
import 'package:bojian_mobile/resume_document.dart';
import 'package:bojian_mobile/resume_market_document.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';
import 'support/resume_editor_helpers.dart';

void main() {
  test('Age respects birthday, invalid dates and partial imported dates', () {
    final now = DateTime(2026, 10, 8);
    expect(resumeAge('2000-10-09', now: now), 25);
    expect(resumeAge('2000-10-08', now: now), 26);
    expect(resumeAge('2000.10.08', now: now), 26);
    for (final value in ['2000-10', '2000-02-30', '2027-01-01', '']) {
      expect(resumeAge(value, now: now), isNull);
    }
    expect(
      resumeBirthLabel({
        'birth_date': '2000-10-08',
        'birth_date_display_mode': 'age',
      }, now: now),
      '26 岁',
    );
    expect(
      resumeBirthLabel({
        'birth_date': '2000-10',
        'birth_date_display_mode': 'age',
      }, now: now),
      '2000-10',
    );
  });

  test(
    'Project and skill edits preserve unchanged rich text and unknown metadata',
    () {
      final row = ResumeEntryFields(
        {
          'name': '原项目',
          'custom': '保留',
          'description_rich': richContent('原描述'),
          'achievements_rich': richContent('原成果'),
        },
        ['name', 'description', 'achievements'],
        richKeys: ['description', 'achievements'],
      );
      addTearDown(row.dispose);
      row.fields['name']!.text = '新项目';
      expect(row.toJson()['description'], '原描述');
      expect(row.toJson()['description_rich'], isNotNull);
      row.fields['description']!.text = '修改描述';
      expect(row.toJson()['description_rich'], isNull);
      expect(row.toJson()['achievements_rich'], isNotNull);
      expect(row.toJson()['custom'], '保留');
    },
  );

  test('Standard and market previews display age and Chinese gender', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    final draft = decodeResume({
      'content': {
        'personal_info': {
          'full_name': '姓名',
          'birth_date': '2000-01-01',
          'birth_date_display_mode': 'age',
          'gender': 'female',
        },
      },
    });
    final document = ResumeDocument(draft);
    addTearDown(document.dispose);
    final printed = document.pages
        .expand((page) => page.ink)
        .map((run) => run.text.text!.toPlainText())
        .join('\n');
    expect(printed, contains('岁'));
    expect(printed, contains('女'));
    final fields = marketResumeFields(draft);
    expect(fields['birth_date'], contains('岁'));
    expect(fields['gender'], '女');
  });

  testWidgets(
    'Editor saves missing Mac fields and reordered structured entries',
    (tester) async {
      final api = FakeGateway();
      final store = await testStore(authenticated: true, api: api);
      addTearDown(store.dispose);
      final draft = decodeResume({
        'id': 1,
        'revision': 3,
        'title': '简历',
        'content': {
          'personal_info': {
            'full_name': '姓名',
            'birth_date': '2000-01-01',
            'gender': 'female',
            'birth_date_display_mode': 'age',
            'custom': '保留',
          },
          'job_expectation': {
            'position': '工程师',
            'industry': '互联网',
            'salary': '20K',
          },
          'projects': [
            {
              'name': '项目一',
              'description_rich': richContent('描述一'),
              'achievements_rich': richContent('成果一'),
            },
            {'name': '项目二', 'description': '描述二', 'url': 'https://example.com'},
          ],
          'skills': [
            {'name': 'Flutter', 'description': '熟练'},
            {'name': 'Dart', 'description': '掌握'},
          ],
          'certifications': [
            {'name': '证书', 'issuer': '机构', 'date': '2024-06'},
          ],
        },
      });
      await tester.pumpWidget(
        MaterialApp(
          home: ResumeEditor(store: store, draft: draft),
        ),
      );
      await tester.pumpAndSettle();
      await openResumeSection(tester, 0);
      await tester.ensureVisible(find.text('更多基本信息'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('更多基本信息'));
      await tester.pumpAndSettle();
      expect(find.text('性别'), findsOneWidget);
      expect(find.text('年龄：${resumeAge('2000-01-01')} 岁'), findsNothing);
      await saveResumeSection(tester);
      await openResumeSection(tester, 4);
      final project = find.byKey(
        const ValueKey('resume-projects-0-description'),
      );
      await tester.ensureVisible(project);
      await tester.pumpAndSettle();
      await tester.enterText(project, '修改项目描述');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      final down = find.byTooltip('下移项目经历').first;
      await Scrollable.ensureVisible(tester.element(down), alignment: .3);
      await tester.pumpAndSettle();
      await tester.tap(down);
      await tester.pumpAndSettle();
      await saveResumeSection(tester);
      await openResumeSection(tester, 1);
      final salary = find.byKey(const ValueKey('resume-salary'));
      await tester.ensureVisible(salary);
      await tester.pumpAndSettle();
      await tester.enterText(salary, '25K');
      FocusManager.instance.primaryFocus?.unfocus();
      await saveResumeSection(tester);
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      final content =
          api.documents['GetResumes']!['items'][0]['content'] as Map;
      expect(content['personal_info']['gender'], 'female');
      expect(content['personal_info']['birth_date_display_mode'], 'age');
      expect(content['personal_info']['custom'], '保留');
      expect(content['job_expectation']['salary'], '25K');
      expect(content['job_expectation']['industry'], '互联网');
      expect((content['projects'] as List).map((row) => row['name']), [
        '项目二',
        '项目一',
      ]);
      expect(content['projects'][1]['description'], '修改项目描述');
      expect(content['projects'][1]['description_rich'], isNull);
      expect(content['projects'][1]['achievements_rich'], isNotNull);
      expect((content['skills'] as List).length, 2);
      expect(content['skills'][1]['name'], 'Dart');
      expect(content['certifications'][0]['issuer'], '机构');
    },
  );
}
