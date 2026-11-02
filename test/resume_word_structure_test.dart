import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:bojian_mobile/resume_native_export.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('new declarative template exports complete fields without template-specific code', () async {
    final source = List.generate(30, (i) => '第$i段可连续编辑的内容。').join('\n');
    final rich = {
      'type': 'richText',
      'binding': r'$resume.detail_rich',
      'fallbackTextBinding': r'$resume.detail',
      'textStyle': 'body',
    };
    final layout = ResumeExportLayout(
      const [],
      requiresWordFlow: true,
      wordStructure: {
        'layout': {
          'page': {
            'size': {'width': 794, 'height': 1123},
            'contentPadding': {'left': 40, 'right': 40},
            'background': {'color': '#FFFFFF'},
          },
          'textStyles': {
            'body': {'fontSizePt': 11, 'lineHeight': 1.5},
          },
        },
        'fields': {'detail': source},
        'sections': [
          {
            'type': 'column',
            'children': [
              {
                'type': 'row',
                'children': [
                  {
                    'type': 'text',
                    'text': '没有日期的经历',
                    'textStyle': 'body',
                    'layout': {'basisFraction': 0, 'grow': 1},
                  },
                  {
                    'type': 'text',
                    'binding': r'$resume.missing_date',
                    'textStyle': 'body',
                  },
                ],
              },
              {
                'type': 'column',
                'margin': {'left': 32, 'right': 8},
                'padding': {'left': 16, 'right': 16, 'top': 12, 'bottom': 12},
                'background': {'color': '#f2f5ef'},
                'children': [
                  {
                    'type': 'column',
                    'margin': {'left': 4},
                    'children': [rich],
                  },
                ],
              },
            ],
          },
        ],
        'images': <String, Uint8List>{},
      },
    );
    final regular = (await rootBundle.load(resumeFontRegularAsset)).buffer
        .asUint8List();
    final bold = (await rootBundle.load(resumeFontBoldAsset)).buffer
        .asUint8List();
    final data = await encodeNativeResume(layout, 'DOCX', regular, bold);
    final zip = ZipDecoder().decodeBytes(data);
    final xml = utf8.decode(
      zip.findFile('word/document.xml')!.content as List<int>,
    );
    expect(RegExp('<w:sdt>').allMatches(xml).length, 1);
    expect(xml, isNot(contains('txbx')));
    expect(xml, isNot(contains('<w:br/>')));
    // Word measures table indentation from the first cell text edge.
    // Include cell padding so the painted edge follows the external margin.
    // External margins must not become padded, shaded cells. One panel cell
    // covers only its own width, offset by the declared left margin.
    expect(RegExp('<w:shd').allMatches(xml).length, 1);
    expect(RegExp('<w:tbl>').allMatches(xml).length, 2);
    expect(xml, contains('<w:ind w:left="60" w:right="0"'));
    expect(xml, contains('<w:tcMar>'));
    expect(xml, contains('<w:tblInd w:w="720" w:type="dxa"/>'));
    expect(xml, contains('<w:tblW w:w="10110" w:type="dxa"/>'));
    expect(xml, contains('<w:left w:w="240" w:type="dxa"/>'));
    for (final paragraph in source.split('\n')) {
      expect(RegExp(RegExp.escape(paragraph)).allMatches(xml).length, 1);
    }
  });
}
