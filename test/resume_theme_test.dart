import 'dart:convert';
import 'dart:ui' show Rect;

import 'package:bojian_mobile/app_store.dart';
import 'package:bojian_mobile/resume_document.dart';
import 'package:bojian_mobile/resume_theme.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final icon = utf8.encode(
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 2 2"><circle cx="1" cy="1" r="1" fill="#103e2e"/></svg>',
  );
  final resume = ResumeDraft(
    id: 1,
    title: '示例',
    name: '林清和',
    position: '产品经理',
    city: '杭州',
    phone: '13800001234',
    source: {
      'job_expectation': {'salary': '30K'},
      'work_experiences': [
        for (var i = 0; i < 6; i++)
          {
            'company': '公司$i',
            'position': '产品经理',
            'start_date': '2020-01',
            'end_date': '2021-01',
            'description': List.filled(8, '负责会员增长与私域运营产品线。').join('\n'),
          },
      ],
      'skills': [
        {'name': '产品规划', 'description': '需求分析、用户研究'},
      ],
      'certifications': [
        {'name': 'PMP', 'issuer': 'PMI', 'date': '2020-06'},
        {'name': '英语六级', 'date': '2013-12'},
      ],
    },
  );

  test('Theme packages restyle the typesetter and keep text native', () async {
    final theme = await resumeThemeOf(7, {
      'format': resumeThemeFormat,
      'theme': {
        'format': resumeThemeFormat,
        'page': {
          'margin': [28, 33, 30, 37.5],
          'background': '#FAF9F5',
          'page_numbers': false,
        },
        'header': {'rule': null},
        'heading': {
          'icon_size': 20,
          'icons': {'work_experiences': 'assets/icon.svg'},
          'titles': {'skills': '专业技能'},
        },
        'job_expectation': {'style': 'cards', 'fill': '#E8EDE29E'},
        'skills': {
          'style': 'card',
          'fill': '#E8EDE28F',
          'padding': [9, 12, 9, 12],
        },
        'certifications': {'columns': 2},
      },
      'theme_assets': {'assets/icon.svg': base64Encode(icon)},
    });
    expect(theme.isStandard, isFalse);
    final document = ResumeDocument(resume, fontFamily: null, theme: theme);
    addTearDown(document.dispose);
    expect(document.pages.length, greaterThan(1));
    expect(document.sectionTitles, contains('专业技能'));
    for (final page in document.pages) {
      expect(page.dividerY, isNull);
      for (final ink in page.ink) {
        expect(ink.position.dx, greaterThanOrEqualTo(37.5 - .01));
        expect(
          ink.position.dy + ink.height,
          lessThanOrEqualTo(resumePaperSize.height - 30 + .01),
        );
      }
    }
    final decorations = document.pages.expand((page) => page.decorations);
    expect(decorations.whereType<ResumeGraphicDecoration>(), isNotEmpty);
    expect(decorations.whereType<ResumeFillDecoration>().length, 2);
    final backdrop = await resumeExportBackdrop(document, 0);
    final sheet = resumeExportSheet(document, 0, backdrop: backdrop);
    expect(sheet.background, isNotNull);
    expect(sheet.wordFlow, isFalse);
    expect(sheet.rules, isEmpty);
    expect(
      sheet.lines.expand((line) => line.spans).map((span) => span.text),
      isNot(contains('1')),
    );
  });

  test('The standard template keeps its paper and rules', () async {
    final document = ResumeDocument(resume, fontFamily: null);
    addTearDown(document.dispose);
    expect(document.theme.isStandard, isTrue);
    expect(await resumeExportBackdrop(document, 0), isNull);
    expect(resumeExportSheet(document, 0).wordFlow, isTrue);
    expect(document.pages.first.dividerY, isNotNull);
    expect(document.pages.expand((page) => page.decorations), isEmpty);
  });

  test('Split headers and skill tags come from the theme', () async {
    final theme = await resumeThemeOf(8, {
      'format': resumeThemeFormat,
      'theme': {
        'format': resumeThemeFormat,
        'header': {
          'style': 'split',
          'subtitle': {'size': 13},
          'contact': {
            'fields': ['phone', 'city'],
          },
        },
        'job_expectation': {'style': 'header'},
        'entry': {'inline_supporting': true},
        'skills': {
          'style': 'tags',
          'tag': {'fill': '#E6ECF4', 'gap': 8},
        },
      },
    });
    final document = ResumeDocument(
      ResumeDraft(
        id: 2,
        title: '示例',
        name: '张晨',
        position: '产品经理',
        city: '上海',
        phone: '13800001234',
        source: {
          'job_expectation': {'salary': '30K'},
          'work_experiences': [
            {
              'company': '某某科技',
              'position': '高级产品经理',
              'description': '• 负责需求分析\n• 推动增长',
            },
          ],
          'skills': [
            {'name': 'SQL'},
            {'name': '用户研究'},
          ],
        },
      ),
      fontFamily: null,
      theme: theme,
    );
    final page = document.pages.first;
    final text = [for (final ink in page.ink) ink.text.plainText];
    expect(document.sectionTitles, isNot(contains('求职意向')));
    expect(text, containsAll(['产品经理', '电话：13800001234', '期望城市：上海']));
    expect(text, contains('某某科技 | 高级产品经理'));
    expect(text, containsAll(['SQL', '用户研究']));
    expect(page.decorations.whereType<ResumeFillDecoration>(), hasLength(2));
    document.dispose();
  });

  test(
    'A sidebar holds contacts and short sections beside the main column',
    () async {
      final theme = await resumeThemeOf(9, {
        'format': resumeThemeFormat,
        'theme': {
          'format': resumeThemeFormat,
          'page': {
            'margin': [28, 24, 34, 18],
          },
          'sidebar': {
            'width': 156,
            'fill': '#1B2A47',
            'sections': ['contact', 'skills', 'certifications'],
          },
          'header': {'style': 'sidebar'},
          'job_expectation': {'style': 'header'},
          'entry': {'dates_position': 'start', 'date_column': 180},
        },
      });
      final document = ResumeDocument(resume, fontFamily: null, theme: theme);
      final page = document.pages.first;
      final sidebar = page.ink.where((ink) => ink.position.dx < 156).toList();
      expect(theme.margin.left, 174);
      expect(
        sidebar.map((ink) => ink.text.plainText),
        containsAll(['电话：13800001234', '城市：杭州', '产品规划', 'PMP', 'PMI  2020/06']),
      );
      expect(document.sectionTitles, isNot(contains('求职意向')));
      expect(document.sectionTitles, isNot(contains('专业技能')));
      final dates = page.ink.firstWhere(
        (ink) => ink.text.plainText == '2020/01 ~ 2021/01',
      );
      final company = page.ink.firstWhere(
        (ink) => ink.text.plainText.startsWith('公司0'),
      );
      expect(dates.position.dx, 174);
      expect(company.position.dx, 354);
      document.dispose();
    },
  );

  test('A sidebar can open with the photo above the name', () async {
    final theme = await resumeThemeOf(10, {
      'format': resumeThemeFormat,
      'theme': {
        'format': resumeThemeFormat,
        'sidebar': {
          'width': 190,
          'header': true,
          'rule_position': 'above',
          'sections': ['contact', 'certifications'],
        },
        'header': {
          'style': 'sidebar',
          'contact': {
            'labels': {'phone': ''},
          },
          'photo': {
            'width': 100,
            'height': 120,
            'radius': 6,
            'rect': [29, 40, 100, 120],
          },
        },
        'heading': {
          'subtitle': {'size': 8},
          'subtitles': {'work_experiences': 'EXPERIENCE'},
          'rule': {'color': '#BFC9D4'},
          'rule_position': 'below',
        },
        'self_evaluation': {
          'quotes': ['assets/icon.svg', 'assets/icon.svg'],
        },
        'job_expectation': {'style': 'header'},
        'entry': {'month_separator': '.', 'date_separator': ' – '},
      },
      'theme_assets': {'assets/icon.svg': base64Encode(icon)},
    });
    final draft = ResumeDraft(
      id: 3,
      title: '示例',
      name: '林清和',
      position: '产品经理',
      phone: '13800001234',
      summary: '专注用户增长。',
      source: {
        ...resume.source,
        'work_experiences': [
          {
            'company': '某某科技',
            'start_date': '2020-01',
            'current': true,
            'description': '• 负责需求分析\n2. 推动增长\n3.8 分以上',
          },
        ],
      },
    );
    final document = ResumeDocument(
      draft,
      fontFamily: null,
      theme: theme,
      photoURL: 'x',
    );
    addTearDown(document.dispose);
    final page = document.pages.first;
    final text = [for (final ink in page.ink) ink.text.plainText];
    final name = page.ink.firstWhere((ink) => ink.text.plainText == '林清和');
    expect(page.photo, const Rect.fromLTWH(29, 40, 100, 120));
    expect(name.position.dy, greaterThan(page.photo!.bottom));
    expect(text, containsAll(['13800001234', 'PMP', '产品经理', 'EXPERIENCE']));
    // Dates follow the theme, and the user's own list markers stay.
    expect(text, containsAll(['2020.01 – 至今', '• 负责需求分析\n2. 推动增长\n3.8 分以上']));
    final outline = theme.photoPath(page.photo!);
    expect(
      outline.contains(page.photo!.topLeft + const Offset(.5, .5)),
      isFalse,
    );
    expect(outline.contains(page.photo!.center), isTrue);
    // Without a photo, the name opens the sidebar instead of leaving a gap.
    final bare = ResumeDocument(draft, fontFamily: null, theme: theme);
    addTearDown(bare.dispose);
    final bareName = bare.pages.first.ink.firstWhere(
      (ink) => ink.text.plainText == '林清和',
    );
    expect(bare.pages.first.photo, isNull);
    expect(bareName.position.dy, lessThan(page.photo!.top));
    // Every heading has a rule below it.
    final lines = page.decorations.whereType<ResumeLineDecoration>().where(
      (line) => line.from.dx >= theme.margin.left,
    );
    expect(lines.length, document.sectionTitles.length);
  });

  test('Photo-less resumes skip photo artwork and use their own top', () async {
    final theme = await resumeThemeOf(11, {
      'format': resumeThemeFormat,
      'theme': {
        'format': resumeThemeFormat,
        'page': {
          'ornaments': [
            {
              'asset': 'assets/icon.svg',
              'rect': [0, 0, 156, 65],
              'photo': false,
            },
            {
              'asset': 'assets/icon.svg',
              'rect': [0, 0, 156, 150],
              'photo': true,
            },
            {
              'asset': 'assets/icon.svg',
              'rect': [0, 0, 10, 10],
            },
          ],
        },
        'sidebar': {
          'width': 156,
          'padding': [34, 12, 40, 12],
          'top_without_photo': 82,
          'sections': ['contact'],
        },
        'header': {'style': 'sidebar'},
      },
      'theme_assets': {'assets/icon.svg': base64Encode(icon)},
    });
    expect([for (final o in theme.ornaments) o.photo], [false, true, null]);
    double sidebarTop(String photoURL) {
      final document = ResumeDocument(
        resume,
        fontFamily: null,
        theme: theme,
        photoURL: photoURL,
      );
      addTearDown(document.dispose);
      return document.pages.first.ink
          .where((ink) => ink.position.dx < 156)
          .map((ink) => ink.position.dy)
          .reduce((a, b) => a < b ? a : b);
    }

    expect(sidebarTop(''), greaterThanOrEqualTo(82));
    expect(sidebarTop('x'), greaterThan(34 + theme.photoSize.height));
  });
}
