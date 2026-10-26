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

  test('Word mobile branches retain white text, its background and an unclipped line', () async {
    final bytes = await encodeNativeResume(
      const ResumeExportLayout([
        ResumeExportPage(
          rules: [ResumeExportRule(30, 40, 220, 0, 0xFFCC4400, height: 50)],
          lines: [
            ResumeExportLine(
              top: 42,
              height: 9,
              baseline: 54,
              spans: [
                ResumeExportSpan(
                  text: '中等字重 English：行尾不能消失',
                  x: 36,
                  width: 200,
                  size: 10,
                  weight: 600,
                  color: 0xFFFFFFFF,
                ),
              ],
            ),
          ],
        ),
      ]),
      'DOCX',
      regular,
      bold,
      medium: medium,
    );
    final zip = ZipDecoder().decodeBytes(bytes);
    final xml = utf8.decode(zip.findFile('word/document.xml')!.content);
    final blocks = RegExp(r'<mc:AlternateContent>(.*?)</mc:AlternateContent>')
        .allMatches(xml)
        .map((m) => m.group(1)!)
        .toList();
    expect(blocks, hasLength(2));
    expect(blocks.first, contains('<a:srgbClr val="CC4400"/>'));
    expect(blocks.first, contains('fillcolor="#CC4400"'));
    final text = blocks.last;
    expect(RegExp('行尾不能消失').allMatches(text), hasLength(2));
    expect(text, contains('wrap="none"'));
    expect(text, contains('mso-wrap-style:none'));
    expect(text, contains('mso-fit-shape-to-text:t'));
    expect(text, isNot(contains('w:lineRule="exact"')));
    expect(text, isNot(contains('<w:b/>')));
    expect(text, contains(resumeWordMediumTypeface));
    expect(text, contains('margin-top:43.400pt'));
    final table = utf8.decode(zip.findFile('word/fontTable.xml')!.content);
    expect(table, contains('w:name="$resumeWordMediumTypeface"'));
    // The embedded face must be the original font, rather than a mislabeled
    // regular/bold face. Deobfuscation is symmetric over the first 32 bytes.
    final embedded = Uint8List.fromList(
      zip.findFile('word/fonts/medium.odttf')!.content,
    );
    for (var i = 0; i < 32; i++) {
      embedded[i] ^= (15 - i % 16) * 17;
    }
    expect(embedded, medium);
  });

  test(
    'PDF exports imported radical characters and unsupported symbols',
    () async {
      final samples = Platform.environment['BOJIAN_EXPORT_SAMPLE_TEXT'];
      final texts = samples == null
          ? ['⼦⼴⼯⼤⼭⽬⼈ ⻅⻓⻔⻚ · • □ ? 😀 🚀']
          : (jsonDecode(await File(samples).readAsString()) as List)
                .cast<String>();
      for (final text in texts) {
        final pdf = await encodeNativeResume(
          ResumeExportLayout([
            ResumeExportPage(
              lines: [
                ResumeExportLine(
                  top: 40,
                  height: 14,
                  baseline: 51,
                  spans: [
                    ResumeExportSpan(text: text, x: 40, width: 500, size: 10),
                  ],
                ),
              ],
            ),
          ]),
          'PDF',
          regular,
          bold,
        );
        expect(latin1.decode(pdf.take(5).toList()), '%PDF-');
      }
    },
  );

  test(
    'Word keeps overlapping column rows at their template coordinates',
    () async {
      final layout = ResumeExportLayout([
        ResumeExportPage(
          lines: [
            for (final (text, x, top) in [
              ('左栏第一行', 40.0, 100.0),
              ('右栏第一行', 320.0, 104.0),
              ('左栏第二行', 40.0, 114.0),
              ('⼴州⼯程师', 320.0, 118.0),
            ])
              ResumeExportLine(
                top: top,
                height: 12,
                baseline: top + 10,
                spans: [
                  ResumeExportSpan(text: text, x: x, width: 100, size: 10),
                ],
              ),
          ],
        ),
        const ResumeExportPage(
          lines: [
            ResumeExportLine(
              top: 40,
              height: 12,
              baseline: 50,
              spans: [
                ResumeExportSpan(text: '第二页', x: 40, width: 60, size: 10),
              ],
            ),
          ],
        ),
      ]);
      final bytes = await encodeNativeResume(layout, 'DOCX', regular, bold);
      final zip = ZipDecoder().decodeBytes(bytes);
      final xml = utf8.decode(zip.findFile('word/document.xml')!.content);
      expect(xml, contains('margin-left:320.000pt;margin-top:103.400pt'));
      expect(xml, contains('margin-left:40.000pt;margin-top:113.400pt'));
      expect(xml, contains('广州工程师'));
      expect(xml, isNot(contains('<w:tab')));
      // Only one of the equivalent modern/legacy branches is displayed.
      expect(RegExp('<w:txbxContent>').allMatches(xml).length, 10);
      expect(RegExp('<w:br w:type="page"/>').allMatches(xml).length, 1);
      expect(xml, contains('<w:fitText '));
    },
  );

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
    final word = await encodeNativeResume(
      layout,
      'DOCX',
      regular,
      bold,
      medium: medium,
    );
    final zip = ZipDecoder().decodeBytes(word);
    final xml = utf8.decode(zip.findFile('word/document.xml')!.content);
    expect(xml, contains('<w:t xml:space="preserve">林知远</w:t>'));
    expect(xml, contains('<w:i/>'));
    expect(xml, contains('<w:u w:val="single"/>'));
    expect(
      RegExp('<w:br w:type="page"/>').allMatches(xml).length,
      layout.pages.length - 1,
    );
    expect(zip.files.where((f) => f.name.startsWith('word/media/')).length, 1);
    expect(
      zip.files.any((f) => RegExp(r'page\d+\.png').hasMatch(f.name)),
      isFalse,
    );
    expect(zip.findFile('word/fonts/regular.odttf'), isNotNull);
    // Embed both real faces so printing does not depend on installed fonts.
    expect(xml, contains('w:eastAsia="$resumeWordRegularTypeface"'));
    final fontTable = utf8.decode(zip.findFile('word/fontTable.xml')!.content);
    expect(fontTable, contains('w:name="$resumeWordRegularTypeface"'));
    expect(fontTable, contains('w:name="$resumeWordMediumTypeface"'));
    expect(fontTable, contains('<w:embedRegular '));
    expect(fontTable, contains('<w:embedBold '));
    expect(zip.findFile('word/fonts/bold.odttf'), isNotNull);
    expect(zip.findFile('word/fonts/medium.odttf'), isNotNull);
    final pdf = await encodeNativeResume(
      layout,
      'PDF',
      regular,
      bold,
      medium: medium,
    );
    expect(latin1.decode(pdf.take(5).toList()), '%PDF-');
    if (Platform.environment['BOJIAN_EXPORT_QA'] == '1') {
      final output = Directory(
        Platform.environment['BOJIAN_EXPORT_QA_DIR'] ??
            '/tmp/bojian-native-export-qa',
      );
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
        fontStyles: resumeDocumentFontStyles,
      );
      await File('${output.path}/market.html').writeAsString(marketHtml);
      await File('${output.path}/regular.ttf').writeAsBytes(regular);
      await File('${output.path}/bold.ttf').writeAsBytes(bold);
      await File('${output.path}/medium.ttf').writeAsBytes(
        (await rootBundle.load(resumeFontMediumAsset)).buffer.asUint8List(),
      );
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
      final expectedName =
          Platform.environment['BOJIAN_MARKET_QA_NAME'] ?? '林知远';
      final recordPrefix =
          Platform.environment['BOJIAN_MARKET_QA_PREFIX'] ?? '交付记录';
      final recordCount = int.parse(
        Platform.environment['BOJIAN_MARKET_QA_COUNT'] ?? '52',
      );
      expect(text, contains(expectedName));
      for (var i = 0; i < recordCount; i++) {
        expect(
          RegExp('$recordPrefix${i.toString().padLeft(2, '0')}')
              .allMatches(text)
              .length,
          1,
        );
      }
      if ((jsonDecode(await File(source).readAsString()) as List).any(
        (page) => page['background'] is String,
      )) {
        expect(layout.pages.every((page) => page.background != null), isTrue);
      }
      final output = Directory(
        Platform.environment['BOJIAN_EXPORT_QA_DIR'] ??
            '/tmp/bojian-native-export-qa',
      );
      await output.create(recursive: true);
      for (final format in ['PDF', 'DOCX']) {
        final bytes = await encodeNativeResume(
          layout,
          format,
          regular,
          bold,
          medium: medium,
        );
        await File('${output.path}/market.${format.toLowerCase()}')
            .writeAsBytes(bytes);
      }
    },
  );
}
