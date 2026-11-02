import 'package:bojian_mobile/app_store.dart';
import 'package:bojian_mobile/resume_document.dart';
import 'package:bojian_mobile/resume_pages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Preview distinguishes work, education and project entries with typography and rules', () {
    final draft = decodeResume({
      'content': {
        'personal_info': {'full_name': '测试姓名'},
        'educations': [
          {'institution': '第一所学校', 'campus_experience': '第一段在校内容'},
          {'institution': '第二所学校', 'campus_experience': '第二段在校内容'},
        ],
        'work_experiences': [
          {'company': '第一家公司', 'description': '第一段工作内容'},
          {'company': '第二家公司', 'description': '第二段工作内容'},
          {'company': '第三家公司', 'description': '第三段工作内容'},
        ],
        'projects': [
          {'name': '第一个项目', 'description': '第一段项目内容'},
          {'name': '第二个项目', 'description': '第二段项目内容'},
        ],
      },
    });
    final document = ResumeDocument(draft);
    addTearDown(document.dispose);
    final runs = document.pages.expand((page) => page.ink).toList();
    expect(runs.any((run) => run.text.text!.toPlainText() == '教育经历'), isTrue);
    expect(runs.any((run) => run.text.text!.toPlainText() == '工作经历'), isTrue);
    expect(runs.any((run) => run.text.text!.toPlainText() == '项目经历'), isTrue);
    expect(document.pages.expand((page) => page.entryDividers).length, 4);
    final project = runs.firstWhere(
      (run) => run.text.text!.toPlainText() == '第二个项目',
    );
    final projectBody = runs.firstWhere(
      (run) => run.text.text!.toPlainText() == '第二段项目内容',
    );
    expect(
      (project.text.text as TextSpan).style!.fontSize,
      greaterThan((projectBody.text.text as TextSpan).style!.fontSize!),
    );
    final company = runs.firstWhere(
      (run) => run.text.text!.toPlainText() == '第二家公司',
    );
    final body = runs.firstWhere(
      (run) => run.text.text!.toPlainText() == '第二段工作内容',
    );
    expect(
      (company.text.text as TextSpan).style!.fontSize,
      greaterThan((body.text.text as TextSpan).style!.fontSize!),
    );
    for (final page in document.pages) {
      for (final y in page.entryDividers) {
        expect(y, greaterThan(resumePaperMargin));
        expect(page.ink.any((run) => run.position.dy > y), isTrue);
      }
    }
  });

  test('Projects that fit one page keep title description and achievements together', () {
    final draft = decodeResume({
      'content': {
        'personal_info': {'full_name': '分页测试'},
        'work_experiences': [
          {
            'company': '前置工作',
            'description': List.filled(28, '前置工作正文').join('\n'),
          },
        ],
        'projects': [
          {
            'name': '完整项目',
            'role': '开发',
            'start_date': '2022-03',
            'end_date': '2023-12',
            'description': List.filled(5, '项目业务场景与建设目标').join('\n'),
            'achievements': List.filled(7, '项目成果正文').join('\n'),
          },
        ],
      },
    });
    final document = ResumeDocument(draft);
    addTearDown(document.dispose);
    final pages = <int>{};
    for (var i = 0; i < document.pages.length; i++) {
      for (final ink in document.pages[i].ink) {
        if (ink.fieldPath?.startsWith('projects.0.') ?? false) pages.add(i);
      }
    }
    expect(pages, hasLength(1));
    expect(pages.single, greaterThan(0));
    expect(
      document.pages[pages.single].ink.any(
        (ink) => ink.text.text!.toPlainText() == '项目经历',
      ),
      isTrue,
    );
    expect(document.pages[pages.single].entryDividers, isEmpty);
  });

  test(
    'Projects taller than a page continue without losing text or overflowing',
    () {
      final body = List.generate(160, (i) => '第$i行超长项目正文').join('\n');
      final document = ResumeDocument(
        decodeResume({
          'content': {
            'personal_info': {'full_name': '分页测试'},
            'projects': [
              {'name': '超长项目', 'description': body, 'achievements': '结尾成果'},
            ],
          },
        }),
      );
      addTearDown(document.dispose);
      expect(document.pages.length, greaterThan(2));
      final runs = document.pages
          .expand((p) => p.ink)
          .where((ink) => ink.fieldPath == 'projects.0.description')
          .toList();
      expect(runs.first.sourceTop, 0);
      for (var i = 1; i < runs.length; i++) {
        expect(
          runs[i].sourceTop,
          closeTo(runs[i - 1].sourceTop + runs[i - 1].height, .01),
        );
      }
      expect(
        runs.fold<double>(0, (sum, ink) => sum + ink.height),
        closeTo(runs.first.text.height, .1),
      );
      expect(
        document.pages.last.ink.any(
          (ink) => ink.text.text!.toPlainText() == '结尾成果',
        ),
        isTrue,
      );
    },
  );

  test('Stored photo keeps its A4 slot while its URL is being refreshed', () {
    final draft = decodeResume({
      'id': 1,
      'title': '简历',
      'photo_file_id': 9,
      'content': {
        'personal_info': {'full_name': '测试姓名'},
      },
    });
    final document = ResumeDocument(draft);
    addTearDown(document.dispose);
    expect(document.pages.first.photo, const Rect.fromLTWH(474.28, 46, 75, 90));
  });

  test('Long entries retain every measured line across A4 pages', () {
    final description = List.generate(
      150,
      (i) => '第 $i 条工作内容，完整保留长段落中的文字与标点。',
    ).join('\n');
    final draft = decodeResume({
      'title': '长简历',
      'content': {
        'personal_info': {'full_name': '测试姓名'},
        'work_experiences': [
          {'company': '第一家公司', 'description': description},
          {'company': '第二家公司', 'description': '结尾必须可见'},
        ],
      },
    });
    final document = ResumeDocument(draft);
    addTearDown(document.dispose);
    expect(document.pages.length, greaterThan(2));
    expect(document.pages.first.dividerY, isNotNull);
    expect(document.pages.skip(1).every((p) => p.dividerY == null), isTrue);
    final painter = document.painters.firstWhere(
      (p) => p.text!.toPlainText() == description,
    );
    final runs = document.pages
        .expand((p) => p.ink)
        .where((r) => identical(r.text, painter))
        .toList();
    expect(runs.length, greaterThan(2));
    var covered = 0.0;
    for (final run in runs) {
      expect(run.sourceTop, closeTo(covered, .01));
      covered += run.height;
    }
    expect(covered, closeTo(painter.height, .05));
    for (final run in document.pages.expand((p) => p.ink)) {
      expect(run.position.dy, greaterThanOrEqualTo(46));
      expect(
        run.position.dy + run.height,
        lessThanOrEqualTo(resumePaperSize.height - 50 + .01),
      );
    }
    expect(
      document.pages
          .expand((p) => p.ink)
          .any((r) => r.text.text!.toPlainText() == '结尾必须可见'),
      isTrue,
    );
  });

  test(
    'Structured records, dates and rich styles follow standard PDF sections',
    () {
      final draft = decodeResume({
        'content': {
          'personal_info': {'full_name': '测试姓名'},
          'job_expectation': {'position': '工程师', 'city': '广州'},
          'educations': [
            {
              'institution': '测试大学',
              'degree': '本科',
              'start_date': '2014.09',
              'end_date': '2018.06',
            },
          ],
          'work_experiences': [
            {
              'company': '测试公司',
              'position': '工程师',
              'current': true,
              'description': '旧文字',
              'description_rich': {
                'blocks': [
                  {
                    'kind': 'bullet',
                    'spans': [
                      {'text': '富文本贡献', 'bold': true},
                    ],
                  },
                ],
              },
            },
          ],
          'projects': [
            {'name': '测试项目', 'description': '项目职责', 'achievements': '项目成果'},
          ],
          'skills': [
            {'name': 'Flutter', 'description': '技能说明'},
          ],
          'certifications': [
            {'name': '测试证书', 'issuer': '发证机构', 'date': '2024.01'},
          ],
        },
      });
      final document = ResumeDocument(draft);
      addTearDown(document.dispose);
      expect(document.sectionTitles, [
        '求职期望',
        '工作经历',
        '项目经历',
        '教育经历',
        '技能',
        '证书',
      ]);
      final painted = document.pages
          .expand((p) => p.ink)
          .map((r) => r.text.text!.toPlainText())
          .join('\n');
      for (final text in [
        '测试大学',
        '2014/09 ~ 2018/06',
        '至今',
        '• 富文本贡献',
        '项目职责',
        '项目成果',
        'Flutter',
        '测试证书',
        '2024/01',
      ]) {
        expect(painted, contains(text));
      }
      expect(painted, isNot(contains('旧文字')));
      expect(painted, isNot(contains('等你来补充')));
    },
  );

  testWidgets('Preview removes labels, keeps A4 shape and edits from app bar', (
    tester,
  ) async {
    final store = await testStore(
      authenticated: true,
      api: FakeGateway(seeded: true),
    );
    await tester.pumpWidget(
      MaterialApp(home: ResumePreview(store: store, resumeId: 1)),
    );
    await tester.pumpAndSettle();
    expect(find.text('简历内容'), findsNothing);
    expect(find.text('内容预览'), findsNothing);
    final paper = tester.getSize(find.byKey(const ValueKey('resume-sheet-0')));
    expect(
      paper.width / paper.height,
      closeTo(resumePaperSize.aspectRatio, .001),
    );
    await tester.tap(find.text('编辑'));
    await tester.pumpAndSettle();
    expect(find.byType(ResumeEditor), findsOneWidget);
  });
}
