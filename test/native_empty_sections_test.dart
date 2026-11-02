import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:bojian_native_layout/native_layout.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final blankRich = {
    'blocks': [
      {
        'kind': 'paragraph',
        'spans': [
          {'text': '  \n', 'bold': true},
        ],
      },
    ],
  };
  test('section visibility uses content, not formatting metadata', () {
    expect(nativeSectionHasContent('self_evaluation', {}), false);
    expect(
      nativeSectionHasContent('self_evaluation', {
        'preference_rich': blankRich,
      }),
      false,
    );
    expect(
      nativeSectionHasContent('self_evaluation', {
        'preference': '实际内容',
        'preference_rich': blankRich,
      }),
      true,
    );
    expect(
      nativeSectionHasContent('self_evaluation', {
        'preference_rich': {
          'blocks': [
            {
              'spans': [
                {'text': '富文本内容'},
              ],
            },
          ],
        },
      }),
      true,
    );
    for (final key in nativeArrayFields) {
      final fields = {
        key: [
          {'id': 123, 'detail_rich': blankRich},
          {'title': '保留条目'},
        ],
      };
      expect((normalizeNativeFields(fields)[key] as List).length, 1);
      expect(
        nativeSectionHasContent(key, {
          key: [
            {'id': 123, 'detail_rich': blankRich},
          ],
        }),
        false,
      );
      expect(nativeSectionHasContent(key, fields), true);
    }
    expect(
      nativeSectionHasContent('job_expectation', {'preference': '评价'}),
      false,
    );
    expect(nativeSectionHasContent('personal_info', {}, hasPhoto: true), true);
  });
  test('empty sections create neither heading nor spacing; empty resume keeps one paper', () async {
    final renderer = NativeLayoutRenderer(
      {
        'page': {
          'size': {'width': 794, 'height': 1123},
          'contentPadding': {'top': 20, 'bottom': 20, 'left': 20, 'right': 20},
          'background': {'color': '#FFFFFF', 'asset': 'paper', 'fit': 'fill'},
        },
        'assets': {
          'paper': {'type': 'svg'},
        },
        'textStyles': {
          'body': {'fontSizePt': 10, 'lineHeight': 1.5, 'color': '#000000'},
        },
        'sections': [
          {
            'id': 'self_evaluation',
            'type': 'column',
            'margin': {'top': 50},
            'children': [
              {'type': 'text', 'text': '自我评价', 'textStyle': 'body'},
            ],
          },
        ],
      },
      {'preference_rich': blankRich},
      {
        'paper': Uint8List.fromList(
          utf8.encode(
            '<svg xmlns="http://www.w3.org/2000/svg" width="1" height="1"><rect width="1" height="1" fill="white"/></svg>',
          ),
        ),
      },
    );
    await renderer.prepare();
    final document = renderer.buildDocument();
    expect(document.pages.length, 1);
    expect(document.report['flowHeight'], 0);
    expect(document.report['textRuns'], isEmpty);
    document.dispose();
    renderer.dispose();
  });
}
