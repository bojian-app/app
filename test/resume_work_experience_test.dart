import 'package:bojian_mobile/app_store.dart';
import 'package:bojian_mobile/resume_pages.dart';
import 'package:bojian_mobile/resume_work_experience.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';
import 'support/resume_editor_helpers.dart';

void main() {
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
      final description = find.byKey(
        const ValueKey('resume-work-0-description'),
      );
      await tester.ensureVisible(description);
      await tester.pumpAndSettle();
      await tester.enterText(description, '修改第一段内容');
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
              find.byKey(const ValueKey('resume-work-0-company')),
            )
            .controller!
            .text,
        '第二家公司',
      );
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('resume-work-1-description')),
            )
            .controller!
            .text,
        '修改第一段内容',
      );
      await saveResumeSection(tester);
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      final saved =
          api.documents['GetResumes']!['items'][0]['content']['work_experiences']
              as List;
      expect(saved.map((v) => v['company']), ['第二家公司', '第一家公司']);
      expect(saved[0]['description'], '第二段内容');
      expect(saved[0]['description_rich'], isNotNull);
      expect(saved[0]['current'], true);
      expect(saved[1]['description'], '修改第一段内容');
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
    await openResumeSection(tester, 3);
    final add = find.text('添加工作经历');
    await tester.ensureVisible(add);
    await tester.pumpAndSettle();
    await tester.tap(add);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('resume-work-0-company')), findsOneWidget);
    final remove = find.byTooltip('删除经历');
    await tester.ensureVisible(remove);
    await tester.pumpAndSettle();
    await tester.tap(remove);
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('resume-work-0-company')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
