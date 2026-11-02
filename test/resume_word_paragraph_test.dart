import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:bojian_mobile/api/bojian_api.dart';
import 'package:bojian_mobile/app_store.dart';
import 'package:bojian_mobile/resume_document.dart';
import 'package:bojian_mobile/resume_market_document.dart';
import 'package:bojian_mobile/resume_native_export.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Uint8List regular, medium, bold;
  setUpAll(() async {
    regular = (await rootBundle.load(resumeFontRegularAsset)).buffer
        .asUint8List();
    bold = (await rootBundle.load(resumeFontBoldAsset)).buffer.asUint8List();
    medium = (await rootBundle.load(resumeFontMediumAsset)).buffer
        .asUint8List();
    await (FontLoader(resumeDocumentFontFamily)
          ..addFont(Future.value(ByteData.sublistView(regular)))
          ..addFont(Future.value(ByteData.sublistView(medium)))
          ..addFont(Future.value(ByteData.sublistView(bold))))
        .load();
  });

  Future<String> word(ResumeExportLayout layout, String name) async {
    final bytes = await encodeNativeResume(
      layout,
      'DOCX',
      regular,
      bold,
      medium: medium,
    );
    final output = Platform.environment['BOJIAN_WORD_PARAGRAPH_QA'];
    if (output != null) await File('$output/$name.docx').writeAsBytes(bytes);
    return utf8.decode(
      ZipDecoder().decodeBytes(bytes).findFile('word/document.xml')!.content,
    );
  }

  test(
    'V2 capture without Word structure cannot fall back to text boxes',
    () async {
      final layout = marketExportLayout([
        {'lines': [], 'rules': [], 'pictures': []},
      ], requiresWordFlow: true);
      await expectLater(
        word(layout, 'missing-word-model'),
        throwsA(isA<ApiFailure>()),
      );
      // The independent PDF layout remains usable.
      final pdf = await encodeNativeResume(layout, 'PDF', regular, bold);
      expect(ascii.decode(pdf.take(4).toList()), '%PDF');
    },
  );

  test(
    'Mixed semantic and positioned pages cannot downgrade Word export',
    () async {
      final layout = ResumeExportLayout([
        ResumeExportPage(lines: [], rules: [], pictures: [], wordFlow: true),
        ResumeExportPage(lines: [], rules: [], pictures: []),
      ]);
      await expectLater(
        word(layout, 'mixed-layout'),
        throwsA(isA<ApiFailure>()),
      );
    },
  );

  ResumeExportLine paragraph(
    String id,
    String text,
    double top, {
    bool heading = false,
    String? field,
  }) => ResumeExportLine(
    top: top,
    height: 16,
    baseline: top + 12,
    paragraphId: id,
    paragraphLeft: 46,
    paragraphWidth: 503.28,
    paragraphField: field,
    spans: [
      ResumeExportSpan(
        text: text,
        x: 46,
        width: 100,
        size: 12,
        weight: heading ? 600 : 400,
      ),
    ],
  );

  test(
    'A module starting on the next template page keeps its break and top gap',
    () async {
      final xml = await word(
        ResumeExportLayout([
          ResumeExportPage(
            wordFlow: true,
            lines: [paragraph('work', '上一段工作经历正文', 650)],
          ),
          ResumeExportPage(
            wordFlow: true,
            lines: [
              paragraph('projects-heading', '项目经历', 60, heading: true),
              paragraph('project-name', '核心交易项目', 84, heading: true),
              paragraph(
                'project-body',
                '项目正文',
                110,
                field: 'projects.0.description',
              ),
            ],
          ),
        ]),
        'module-page-break',
      );
      final heading = RegExp(r'<w:p>.*?</w:p>')
          .allMatches(xml)
          .singleWhere((match) => match[0]!.contains('项目经历'))[0]!;
      expect(heading, contains('<w:pageBreakBefore/>'));
      expect(heading, contains('<w:keepNext/>'));
      expect(heading, contains('w:before="280"'));
      expect(RegExp('<w:pageBreakBefore/>').allMatches(xml), hasLength(1));
    },
  );

  test('A continuing source paragraph is not broken into page-sized editing blocks', () async {
    final xml = await word(
      ResumeExportLayout([
        ResumeExportPage(
          wordFlow: true,
          lines: [
            paragraph(
              'long-body',
              '跨页正文开头',
              720,
              field: 'projects.0.description',
            ),
          ],
        ),
        ResumeExportPage(
          wordFlow: true,
          lines: [
            paragraph(
              'long-body',
              '跨页正文续文',
              46,
              field: 'projects.0.description',
            ),
            paragraph('next-heading', '后续项目', 90, heading: true),
          ],
        ),
      ]),
      'continued-paragraph',
    );
    expect(xml, contains('跨页正文开头跨页正文续文'));
    expect(xml, isNot(contains('<w:pageBreakBefore/>')));
    final heading = RegExp(r'<w:p>.*?</w:p>')
        .allMatches(xml)
        .singleWhere((match) => match[0]!.contains('后续项目'))[0]!;
    expect(heading, contains('w:before="560"'));
  });

  final repairSource = Platform.environment['BOJIAN_WORD_REPAIR_LAYOUT'];
  test(
    'Repair original exported file using the continuous Word writer',
    () async {
      final pages = (jsonDecode(
        await File(repairSource!).readAsString(),
      ) as List).cast<Map>();
      final layout = ResumeExportLayout([
        for (final page in pages)
          marketExportLayout([page], wordModel: page).wordLayout!.pages.single,
      ]);
      final xml = await word(layout, 'repaired-original');
      expect(xml, isNot(contains('<wps:txbx>')));
      expect(xml, isNot(contains('w:type="page"')));
      expect(xml, contains('2021/05 ~ 至今'));
      final projectHeading = RegExp(r'<w:p>.*?</w:p>')
          .allMatches(xml)
          .singleWhere((match) => match[0]!.contains('>项目经历</w:t>'))[0]!;
      expect(projectHeading, contains('<w:pageBreakBefore/>'));
      expect(projectHeading, isNot(contains('w:before="0"')));
      for (final page in pages) {
        for (final line in (page['lines'] as List).cast<Map>()) {
          final text = (line['spans'] as List)
              .cast<Map>()
              .map((span) => span['text'] as String)
              .join();
          expect(
            xml,
            contains(
              text
                  .replaceAll('&', '&amp;')
                  .replaceAll('<', '&lt;')
                  .replaceAll('>', '&gt;'),
            ),
          );
        }
      }
      final groups = RegExp(r'<w:sdt>(.*?)</w:sdt>')
          .allMatches(xml)
          .map((m) => m[1]!)
          .toList();
      expect(groups.where((g) => g.contains('projects.0.body')), hasLength(1));
    },
    skip: repairSource == null,
  );

  test(
    'Default project body stays continuous across pages and source fields',
    () async {
      final description = List.filled(120, '这是完整项目正文，换行和跨页不能拆开编辑区域。').join();
      final document = ResumeDocument(
        decodeResume({
          'content': {
            'projects': [
              {
                'name': '长项目',
                'role': '开发',
                'start_date': '2021-05-01',
                'current': true,
                'description': description,
                'achievements': '项目成果末尾',
              },
              {'name': '后续项目', 'description': '后续项目正文'},
            ],
          },
        }),
      );
      addTearDown(document.dispose);
      expect(document.pages.length, greaterThan(1));
      final xml = await word(
        ResumeExportLayout([
          for (var i = 0; i < document.pages.length; i++)
            resumeExportSheet(document, i),
        ]),
        'default-long-project',
      );
      expect(xml, isNot(contains('<wps:txbx>')));
      expect(xml, isNot(contains('w:type="page"')));
      final group = RegExp(r'<w:sdt>(.*?)</w:sdt>')
          .allMatches(xml)
          .singleWhere((m) => m[1]!.contains('projects.0.body'))[1]!;
      expect(group, contains(description));
      expect(group, contains('项目成果末尾'));
      expect(group, isNot(contains('后续项目正文')));
      expect(xml, contains('2021/05 ~ 至今'));
    },
  );

  final v2Capture = Platform.environment['BOJIAN_V2_CAPTURE'];
  test(
    'V2 browser model exports one editable project body across pages',
    () async {
      final data = jsonDecode(await File(v2Capture!).readAsString()) as Map;
      final layout = marketExportLayout(
        data['pages'] as List,
        wordModel: data['word_model'] as Map,
      );
      expect(layout.pages.length, greaterThan(1));
      final xml = await word(layout, 'v2-continuous-body');
      expect(xml, isNot(contains('<wps:txbx>')));
      expect(xml, isNot(contains('w:type="page"')));
      final groups = RegExp(r'<w:sdt>(.*?)</w:sdt>')
          .allMatches(xml)
          .map((m) => m[1]!)
          .toList();
      final project = groups.singleWhere((g) => g.contains('projects.0.body'));
      expect(project, contains('成果结尾'));
      expect(RegExp('维护页面与用户交互').allMatches(project), hasLength(120));
      expect(RegExp(r'<w:p>').allMatches(project), hasLength(2));
      expect(project, contains('<w:b/>'));
      expect(project, contains('<w:i/>'));
      expect(project, contains('<w:u w:val="single"/>'));
      expect(project, contains('<w:strike/>'));
      expect(xml.indexOf('项目经历'), lessThan(xml.indexOf('工作经历')));
      expect(xml, contains('w:footerReference'));
      expect(xml, contains('<w:gridCol w:w="2700"/>'));
      final contact = RegExp(r'<w:p>.*?电话：.*?</w:p>').firstMatch(xml)![0]!;
      expect(contact, isNot(contains('<w:ind w:right=')));
    },
    skip: v2Capture == null,
  );

  final browserCapture = Platform.environment['BOJIAN_MARKET_PARAGRAPH_QA'];
  test(
    'Native Word uses column widths for headings, body and paired metadata',
    () async {
      final document = ResumeDocument(
        decodeResume({
          'title': '排版回归',
          'photo_file_id': 1,
          'content': {
            'personal_info': {'full_name': '陈小雨', 'phone': '13800000000'},
            'work_experiences': [
              {
                'company': '广州示例信息科技有限公司',
                'position': '前端开发',
                'industry': '软件开发',
                'start_date': '2022-05-10',
                'end_date': '2025-12-10',
                'description': '1. 负责业务页面开发与团队协作。\n2. 维护业务组件，完善页面体验。',
              },
            ],
          },
        }),
      );
      addTearDown(document.dispose);
      final layout = ResumeExportLayout([resumeExportSheet(document, 0)]);
      final lines = layout.pages.single.lines;
      ResumeExportLine find(String text) => lines.singleWhere(
        (line) => line.spans.map((span) => span.text).join().contains(text),
      );
      expect(find('陈小雨').paragraphWidth, closeTo(403.28, .01));
      expect(find('广州示例').paragraphWidth, closeTo(503.28, .01));
      expect(find('1. 负责').paragraphWidth, closeTo(503.28, .01));
      final left = find('前端开发');
      final dates = find('2022/05');
      expect(dates.paragraphAlignRight, isTrue);
      expect(
        dates.paragraphLeft! + dates.paragraphWidth!,
        closeTo(549.28, .01),
      );
      expect(
        left.paragraphLeft! + left.paragraphWidth!,
        lessThanOrEqualTo(dates.paragraphLeft! - 12),
      );
      final xml = await word(layout, 'column-widths');
      expect(xml, contains('<w:jc w:val="right"/>'));
      expect(xml, contains('<w:tbl>'));
      expect(xml, isNot(contains('<wps:txbx>')));
      expect(xml, contains('2022/05 ~ 2025/12'));
    },
  );

  test(
    'Real browser paragraphs reach Word with spaces and inline styles intact',
    () async {
      final layout = marketExportLayout(
        jsonDecode(await File(browserCapture!).readAsString()) as List,
      );
      final xml = await word(layout, 'browser-paragraphs');
      final boxes = RegExp(r'<wps:txbx>(.*?)</wps:txbx>')
          .allMatches(xml)
          .map((m) => m.group(1)!)
          .toList();
      expect(boxes, hasLength(8));
      expect(
        RegExp('frontend delivery coordination').allMatches(boxes.first),
        hasLength(6),
      );
      final rich = boxes.singleWhere((box) => box.contains('RICH_START'));
      expect(rich, contains('styled words'));
      expect(rich, contains('<w:b/>'));
      expect(rich, contains('<w:i/>'));
      expect(RegExp(r'<w:p>').allMatches(rich), hasLength(1));
    },
    skip: browserCapture == null,
  );

  test('Word preserves whole source paragraphs instead of visual-line textboxes', () async {
    final first =
        '1. ${List.filled(12, '负责业务页面开发与团队协作，提升交付质量，支持 frontend delivery coordination。').join()}';
    const second = '2. 第二条职责必须单独保留，不与上一段合并。';
    final document = ResumeDocument(
      decodeResume({
        'content': {
          'work_experiences': [
            {'company': '段落测试', 'description': '$first\n$second'},
          ],
        },
      }),
    );
    addTearDown(document.dispose);
    final layout = ResumeExportLayout([
      for (var i = 0; i < document.pages.length; i++)
        resumeExportSheet(document, i),
    ]);
    expect(
      layout.pages.first.lines
          .where((line) => line.spans.any((span) => span.text.contains('交付质量')))
          .length,
      greaterThan(1),
    );
    final xml = await word(layout, 'paragraphs');
    expect(xml, isNot(contains('<wps:txbx>')));
    expect(xml, isNot(contains('w:type="page"')));
    final body = RegExp(r'<w:sdt>(.*?)</w:sdt>')
        .allMatches(xml)
        .singleWhere((m) => m[1]!.contains('work_experiences.0.body'))[1]!;
    expect(body, contains('<w:t xml:space="preserve">$first</w:t>'));
    expect(body, contains(second));
    expect(RegExp(r'<w:p>').allMatches(body), hasLength(2));
    expect(body, isNot(contains('w:fitText')));
  });

  test('Marketplace paragraph groups preserve rich runs without joining independent columns', () async {
    Map<String, dynamic> line(
      String text,
      String id,
      double left,
      double top, {
      bool bold = false,
    }) => {
      'paragraph_id': id,
      'paragraph_left': left,
      'paragraph_width': 220,
      'top': top,
      'height': 15,
      'baseline': top + 11,
      'spans': [
        {
          'text': text,
          'x': left,
          'width': 100,
          'size': 10,
          'color': 0xFF26292E,
          'bold': bold,
        },
      ],
    };
    final layout = marketExportLayout([
      {
        'lines': [
          line('左栏开头', 'left', 40, 100, bold: true),
          line('右栏开头', 'right', 320, 100),
          line('左栏续文', 'left', 40, 115),
          line('右栏续文', 'right', 320, 115),
        ],
        'rules': [],
        'pictures': [],
      },
    ]);
    final xml = await word(layout, 'columns');
    final boxes = RegExp(r'<wps:txbx>(.*?)</wps:txbx>')
        .allMatches(xml)
        .map((m) => m.group(1)!)
        .toList();
    expect(boxes, hasLength(2));
    expect(boxes.first, contains('左栏开头'));
    expect(boxes.first, contains('左栏续文'));
    expect(boxes.first, contains('<w:b/>'));
    expect(boxes.first, isNot(contains('右栏')));
    expect(RegExp(r'<w:p>').allMatches(boxes.first), hasLength(1));
    expect(boxes.last, contains('右栏开头右栏续文'));
    expect(xml, contains('margin-left:320.000pt'));
  });
}
