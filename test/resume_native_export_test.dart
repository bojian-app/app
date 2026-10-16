import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:archive/archive.dart';
import 'package:bojian_mobile/app_store.dart';
import 'package:bojian_mobile/resume_document.dart';
import 'package:bojian_mobile/resume_native_export.dart';
import 'package:bojian_mobile/resume_market_document.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Uint8List regular, bold;
  setUpAll(() async {
    regular = (await rootBundle.load(resumeFontRegularAsset)).buffer
        .asUint8List();
    bold = (await rootBundle.load(resumeFontBoldAsset)).buffer.asUint8List();
    await (FontLoader(resumeDocumentFontFamily)
          ..addFont(Future.value(ByteData.sublistView(regular)))
          ..addFont(Future.value(ByteData.sublistView(bold))))
        .load();
  });

  test('Native PDF and Word preserve paginated selectable text and rich styles', () async {
    final description = List.generate(
      52,
      (i) =>
          '交付记录${i.toString().padLeft(2, '0')}：负责业务需求分析、产品设计和研发协作，持续提升项目交付质量。',
    ).join('\n');
    final draft = decodeResume({
      'id': 1,
      'photo_file_id': 7,
      'title': '原生文档验证',
      'content': {
        'personal_info': {
          'full_name': '林知远',
          'phone': '13800000000',
          'email': 'native@example.test',
        },
        'job_expectation': {
          'position': '产品经理',
          'city': '上海',
          'preference': '结合业务需求与用户反馈，推动产品落地。',
        },
        'work_experiences': [
          {
            'company': '示例科技公司',
            'position': '产品经理',
            'start_date': '2022-01',
            'end_date': '2025-06',
            'description': description,
          },
          {
            'company': '协作工作室',
            'position': '项目负责人',
            'description': '基础描述',
            'description_rich': {
              'blocks': [
                {
                  'kind': 'bullet',
                  'spans': [
                    {'text': '关键成果', 'bold': true},
                    {'text': ' English italic', 'italic': true},
                    {'text': ' 下划线文本', 'underline': true},
                    {'text': ' 划线文本', 'strikethrough': true},
                  ],
                },
              ],
            },
          },
        ],
        'projects': [
          {'name': '业务协作平台', 'role': '产品负责人', 'description': '完成需求调研、方案设计与验收。'},
        ],
        'educations': [
          {
            'institution': '示例大学',
            'degree': '本科',
            'field_of_study': '信息管理',
            'start_date': '2018-09',
            'end_date': '2022-06',
          },
        ],
        'skills': [
          {'name': '产品规划', 'description': '需求分析、沟通协作、项目管理'},
        ],
      },
    });
    final document = ResumeDocument(draft);
    addTearDown(document.dispose);
    expect(document.pages.length, greaterThan(1));
    final avatarRecorder = ui.PictureRecorder();
    final avatarCanvas = Canvas(avatarRecorder);
    avatarCanvas.drawRect(
      const Rect.fromLTWH(0, 0, 240, 300),
      Paint()..color = Colors.blue,
    );
    avatarCanvas.drawCircle(
      const Offset(120, 105),
      55,
      Paint()..color = const Color(0xFFFFD6B3),
    );
    avatarCanvas.drawRect(
      const Rect.fromLTWH(40, 180, 160, 120),
      Paint()..color = Colors.indigo,
    );
    final avatarPicture = avatarRecorder.endRecording();
    final avatar = await avatarPicture.toImage(240, 300);
    avatarPicture.dispose();
    addTearDown(avatar.dispose);
    final avatarBytes = (await avatar.toByteData(
      format: ui.ImageByteFormat.png,
    ))!.buffer.asUint8List();
    final layout = ResumeExportLayout([
      for (var i = 0; i < document.pages.length; i++)
        resumeExportSheet(document, i, portrait: i == 0 ? avatarBytes : null),
    ]);
    final spans = layout.pages
        .expand((p) => p.lines)
        .expand((l) => l.spans)
        .toList();
    final exportedText = spans.map((s) => s.text).join('');
    for (var i = 0; i < 52; i++) {
      expect(
        RegExp('交付记录${i.toString().padLeft(2, '0')}')
            .allMatches(exportedText)
            .length,
        1,
      );
    }
    expect(exportedText, contains('林知远'));
    expect(exportedText, contains('English italic'));
    expect(spans.any((s) => s.bold), isTrue);
    expect(spans.any((s) => s.italic), isTrue);
    expect(spans.any((s) => s.underline), isTrue);
    expect(spans.any((s) => s.strike), isTrue);
    final word = await encodeNativeResume(layout, 'DOCX', regular, bold);
    final zip = ZipDecoder().decodeBytes(word);
    final xml = utf8.decode(zip.findFile('word/document.xml')!.content);
    expect(xml, contains('<w:t xml:space="preserve">林知远</w:t>'));
    expect(xml, contains('<w:i/>'));
    expect(xml, contains('<w:u w:val="single"/>'));
    expect(
      RegExp('<w:pageBreakBefore/>').allMatches(xml).length,
      layout.pages.length - 1,
    );
    expect(zip.files.where((f) => f.name.startsWith('word/media/')).length, 1);
    expect(
      zip.files.any((f) => RegExp(r'page\d+\.png').hasMatch(f.name)),
      isFalse,
    );
    expect(zip.findFile('word/fonts/regular.odttf'), isNotNull);
    // A single-face family must keep its real name and let Word synthesize bold.
    expect(xml, contains('w:eastAsia="$resumeDocumentTypeface"'));
    final fontTable = utf8.decode(zip.findFile('word/fontTable.xml')!.content);
    expect(fontTable, contains('w:name="$resumeDocumentTypeface"'));
    expect(fontTable, contains('<w:embedRegular '));
    expect(fontTable, isNot(contains('<w:embedBold ')));
    expect(zip.findFile('word/fonts/bold.odttf'), isNull);
    final pdf = await encodeNativeResume(layout, 'PDF', regular, bold);
    expect(latin1.decode(pdf.take(5).toList()), '%PDF-');
    if (Platform.environment['BOJIAN_EXPORT_QA'] == '1') {
      final output = Directory('/tmp/bojian-native-export-qa');
      await output.create(recursive: true);
      await File('${output.path}/resume.docx').writeAsBytes(word);
      await File('${output.path}/resume.pdf').writeAsBytes(pdf);
      await File('${output.path}/layout.json').writeAsString(
        jsonEncode({
          'pages': layout.pages
              .map(
                (p) => {
                  'lines': p.lines
                      .map(
                        (l) => {
                          'top': l.top,
                          'baseline': l.baseline,
                          'height': l.height,
                          'spans': l.spans
                              .map(
                                (s) => {
                                  'text': s.text,
                                  'x': s.x,
                                  'width': s.width,
                                  'size': s.size,
                                },
                              )
                              .toList(),
                        },
                      )
                      .toList(),
                },
              )
              .toList(),
        }),
      );
      for (var i = 0; i < document.pages.length; i++) {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder)..scale(2);
        canvas.drawRect(
          Offset.zero & resumePaperSize,
          Paint()..color = Colors.white,
        );
        paintResumeSheet(canvas, document, i);
        final rect = document.pages[i].photo;
        if (i == 0 && rect != null) {
          canvas.drawImageRect(
            avatar,
            const Rect.fromLTWH(0, 0, 240, 300),
            rect,
            Paint(),
          );
        }
        final picture = recorder.endRecording();
        final image = await picture.toImage(
          (resumePaperSize.width * 2).round(),
          (resumePaperSize.height * 2).round(),
        );
        picture.dispose();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        await File('${output.path}/preview-${i + 1}.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
      }
      final marketHtml = marketDocumentHtml(
        dom: {
          'html': '<h1>{{name}}</h1><table><tr><td>{{position}}</td><td>{{city}}</td></tr></table><p><img alt="{{photo}}" style="width:75pt;height:90pt;object-fit:cover"></p><h2>工作经历</h2><p>{{#work_experiences}}</p><h3>{{title}}</h3><p><b>{{subtitle}}</b></p><p>{{detail}}</p><p>{{/work_experiences}}</p>',
          'css': '@page{margin:46pt} h1{font-size:24pt;color:#245EA8} h2{font-size:13pt;color:#245EA8;border-bottom:1px solid #245EA8}h3{font-size:12pt}p,td{font-size:10.5pt;line-height:1.5}table{width:100%;border-collapse:collapse}td{border:1px solid #ddd;padding:6px}',
        },
        resume: draft,
        photo: 'data:image/png;base64,${base64Encode(avatarBytes)}',
        captureScript: '',
        rendererScript: await rootBundle.loadString(
          'assets/templates/market_renderer.js',
        ),
        fontStyles: "@font-face{font-family:ResumeDocument;src:url('regular.ttf');font-weight:400}",
      );
      await File('${output.path}/market.html').writeAsString(marketHtml);
      await File('${output.path}/regular.ttf').writeAsBytes(regular);
      await File('${output.path}/bold.ttf').writeAsBytes(bold);
      debugPrint('NATIVE_QA_PAGES=${document.pages.length}');
    }
  });

  test('A text-only resume has no image parts in editable Word', () async {
    final doc = ResumeDocument(
      decodeResume({
        'content': {
          'personal_info': {'full_name': 'Text only'},
        },
      }),
    );
    addTearDown(doc.dispose);
    final word = await encodeNativeResume(
      ResumeExportLayout([resumeExportSheet(doc, 0)]),
      'DOCX',
      regular,
      bold,
    );
    final zip = ZipDecoder().decodeBytes(word);
    expect(zip.files.where((f) => f.name.startsWith('word/media/')), isEmpty);
    expect(
      utf8.decode(zip.findFile('word/document.xml')!.content),
      contains('Text only'),
    );
  });
  test(
    'Marketplace DOM layout exports native text and inline images',
    () async {
      final source = Platform.environment['BOJIAN_MARKET_EXPORT_QA'];
      if (source == null) return;
      final layout = marketExportLayout(
        jsonDecode(await File(source).readAsString()) as List,
      );
      expect(layout.pages.length, greaterThan(1));
      final text = layout.pages
          .expand((p) => p.lines)
          .expand((l) => l.spans)
          .map((s) => s.text)
          .join('');
      expect(text, contains('林知远'));
      for (var i = 0; i < 52; i++) {
        expect(
          RegExp('交付记录${i.toString().padLeft(2, '0')}').allMatches(text).length,
          1,
        );
      }
      for (final format in ['PDF', 'DOCX']) {
        final bytes = await encodeNativeResume(layout, format, regular, bold);
        await File(
          '/tmp/bojian-native-export-qa/market.${format.toLowerCase()}',
        ).writeAsBytes(bytes);
      }
    },
  );
}
