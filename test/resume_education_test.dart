import 'package:bojian_mobile/app_store.dart';
import 'package:bojian_mobile/resume_pages.dart';
import 'package:bojian_mobile/resume_education.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';
import 'support/resume_editor_helpers.dart';

void main() {
  test(
    'Editing one field retains metadata and unchanged rich campus_experience',
    () {
      final entry = EducationFields({
        'institution': '原学校',
        'campus_experience': '原内容',
        'campus_experience_rich': {
          'blocks': [
            {'text': '原内容'},
          ],
        },
        'external_id': 'preserve',
      });
      addTearDown(entry.dispose);
      entry.fields['institution']!.text = '新学校';
      expect(entry.toJson()['campus_experience_rich'], isNotNull);
      expect(entry.toJson()['external_id'], 'preserve');
      entry.fields['campus_experience']!.text = '更新内容';
      expect(entry.toJson()['campus_experience_rich'], isNull);
    },
  );

  test(
    'Rich-only imported campus_experience stays visible and retains formatting',
    () {
      final entry = EducationFields({
        'campus_experience_rich': richContent('原始工作内容'),
      });
      addTearDown(entry.dispose);
      expect(entry.fields['campus_experience']!.text, '原始工作内容');
      expect(entry.toJson()['campus_experience_rich'], isNotNull);
    },
  );

  test('Changing campus experience preserves unchanged thesis formatting', () {
    final entry = EducationFields({
      'campus_experience': '在校经历',
      'campus_experience_rich': richContent('在校经历'),
      'thesis_description_rich': richContent('论文内容'),
    });
    addTearDown(entry.dispose);
    entry.fields['campus_experience']!.text = '更新在校经历';
    final saved = entry.toJson();
    expect(saved['campus_experience_rich'], isNull);
    expect(saved['thesis_description_rich'], isNotNull);
    expect(saved['thesis_description'], '论文内容');
  });

  testWidgets(
    'Reordering and editing separate experiences persists both entries in order',
    (tester) async {
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
          'educations': [
            {
              'institution': '第一所学校',
              'degree': '原职位',
              'campus_experience': '第一段内容',
              'start_date': '2020-01',
              'custom': 'keep-first',
            },
            {
              'institution': '第二所学校',
              'degree': '第二职位',
              'campus_experience': '第二段内容',
              'start_date': '2023-06',
              'campus_experience_rich': {'blocks': []},
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
      await openResumeSection(tester, 5);
      final campusExperience = find.byKey(
        const ValueKey('resume-education-0-campus_experience'),
      );
      await tester.ensureVisible(campusExperience);
      await tester.pumpAndSettle();
      await tester.enterText(campusExperience, '修改第一段内容');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      final down = find.byTooltip('下移').first;
      await tester.ensureVisible(down);
      await tester.pumpAndSettle();
      await tester.tap(down);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('resume-education-0-institution')),
            )
            .controller!
            .text,
        '第二所学校',
      );
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(
                const ValueKey('resume-education-1-campus_experience'),
              ),
            )
            .controller!
            .text,
        '修改第一段内容',
      );
      await saveResumeSection(tester);
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      final saved =
          api.documents['GetResumes']!['items'][0]['content']['educations']
              as List;
      expect(saved.map((v) => v['institution']), ['第二所学校', '第一所学校']);
      expect(saved[0]['campus_experience'], '第二段内容');
      expect(saved[0]['campus_experience_rich'], isNotNull);
      expect(saved[1]['campus_experience'], '修改第一段内容');
      expect(saved[1]['custom'], 'keep-first');
      expect(saved[0]['custom'], 'keep-second');
    },
  );

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
    await openResumeSection(tester, 5);
    final add = find.text('添加教育经历');
    await tester.ensureVisible(add);
    await tester.pumpAndSettle();
    await tester.tap(add);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('resume-education-0-institution')),
      findsOneWidget,
    );
    final remove = find.byTooltip('删除经历');
    await tester.ensureVisible(remove);
    await tester.pumpAndSettle();
    await tester.tap(remove);
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除').last);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('resume-education-0-institution')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });
}
