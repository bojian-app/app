import 'package:bojian_mobile/article_photo.dart';
import 'package:bojian_mobile/article_rich_content.dart';
import 'package:bojian_mobile/app_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Reopening drafts preserves text formatting, empty lines and opaque image/table blocks', () {
    final content = {
      'blocks': [
        {
          'kind': 'heading2',
          'spans': [
            {'text': '小标题', 'bold': true},
          ],
          'align': 'center',
        },
        {'kind': 'paragraph', 'spans': []},
        {
          'kind': 'image',
          'image': {'url': 'https://example.com/image.png', 'alt': '原图'},
        },
        {
          'kind': 'table',
          'table': {'rows': []},
        },
        {
          'kind': 'paragraph',
          'spans': [
            {'text': '保留桌面格式', 'font_family': 'serif'},
          ],
        },
        {
          'kind': 'quote',
          'spans': [
            {'text': '引用', 'italic': true},
          ],
          'indent': 1,
        },
        {
          'kind': 'numbered',
          'spans': [
            {'text': '第一条'},
          ],
        },
        {
          'kind': 'bullet',
          'spans': [
            {'text': '重点', 'foregroundColor': '#3366FF'},
          ],
        },
      ],
    };
    expect(articleContentFromDelta(articleDeltaFromContent(content)), content);
  });

  test(
    'Formatted text preserves span boundaries and Mac-compatible blocks',
    () {
      final content = articleContentFromDelta([
        {'insert': '小标题'},
        {
          'insert': '\n',
          'attributes': {'header': 2},
        },
        {
          'insert': '重点',
          'attributes': {'bold': true, 'underline': true},
        },
        {
          'insert': '补充',
          'attributes': {'italic': true},
        },
        {'insert': '\n'},
        {'insert': '第一条'},
        {
          'insert': '\n',
          'attributes': {'list': 'ordered'},
        },
        {'insert': '第二条'},
        {
          'insert': '\n',
          'attributes': {'list': 'ordered'},
        },
        {'insert': '原话'},
        {
          'insert': '\n',
          'attributes': {'blockquote': true},
        },
      ]);
      final blocks = content['blocks'] as List;
      expect(blocks.map((b) => b['kind']), [
        'heading2',
        'paragraph',
        'numbered',
        'numbered',
        'quote',
      ]);
      expect(blocks[1]['spans'], [
        {'text': '重点', 'bold': true, 'underline': true},
        {'text': '补充', 'italic': true},
      ]);
      final story = decodeStory({'content': content});
      expect(story.content, content);
      expect(story.excerpt, '小标题\n重点补充\n第一条\n第二条\n原话');
    },
  );
  testWidgets(
    'Article reading renders formatted spans, headings and numbered lists',
    (tester) async {
      final content = articleContentFromDelta([
        {'insert': '标题'},
        {
          'insert': '\n',
          'attributes': {'header': 2},
        },
        {
          'insert': '加粗',
          'attributes': {'bold': true},
        },
        {'insert': '\n'},
        {
          'insert': '列表一\n列表二\n',
          'attributes': {'list': 'ordered'},
        },
      ]);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ArticleRichBody(content: content)),
        ),
      );
      final bold = tester.widget<Text>(find.text('加粗'));
      final span = (bold.textSpan! as TextSpan).children!.single as TextSpan;
      expect(span.style!.fontWeight, FontWeight.w700);
      expect(tester.widget<Text>(find.text('标题')).style!.fontSize, 19);
      expect(find.text('1.'), findsOneWidget);
      expect(find.text('2.'), findsOneWidget);
    },
  );
  testWidgets('Empty paragraph occupies exactly one normal text line', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ArticleRichBody(content: richContent('第一行\n\n第三行')),
        ),
      ),
    );
    final first = tester.getRect(find.text('第一行'));
    final third = tester.getRect(find.text('第三行'));
    expect(third.top - first.bottom, closeTo(first.height, .01));
  });

  testWidgets('Mac colors, table cells and paragraph alignment render', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ArticleRichBody(
            content: {
              'blocks': [
                {
                  'kind': 'paragraph',
                  'align': 'center',
                  'spans': [
                    {
                      'text': '居中',
                      'foreground_color': '#FF000080',
                      'underline': true,
                      'italic': true,
                    },
                  ],
                },
                {
                  'kind': 'table',
                  'table': {
                    'rows': [
                      {
                        'cells': [
                          {
                            'spans': [
                              {'text': '表头'},
                            ],
                          },
                        ],
                      },
                      {
                        'cells': [
                          {
                            'spans': [
                              {'text': '内容'},
                            ],
                          },
                        ],
                      },
                    ],
                  },
                },
              ],
            },
          ),
        ),
      ),
    );
    final centered = tester.widget<Text>(find.text('居中'));
    expect(centered.textAlign, TextAlign.center);
    final style =
        ((centered.textSpan as TextSpan).children!.single as TextSpan).style!;
    expect(style.color, const Color(0x80FF0000));
    expect(style.fontStyle, FontStyle.italic);
    expect(find.byType(Table), findsOneWidget);
    expect(find.text('内容'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Pictures and captions stand clear of what follows them', (
    tester,
  ) async {
    Map<String, dynamic> words(String text) => {
      'kind': 'paragraph',
      'spans': [
        if (text.isNotEmpty) {'text': text},
      ],
    };
    Map<String, dynamic> picture(String caption) => {
      'kind': 'image',
      'image': {'url': 'https://example.com/$caption.png', 'caption': caption},
    };
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ArticleRichBody(
              content: {
                'blocks': [
                  picture('甲'),
                  picture('乙'),
                  words('正文'),
                  words('下一段'),
                  picture('丙'),
                  words(''),
                  picture('丁'),
                ],
              },
            ),
          ),
        ),
      ),
    );
    final photos = find.byType(ArticleNetworkPhoto);
    double top(Finder f) => tester.getTopLeft(f).dy;
    double bottom(Finder f) => tester.getBottomLeft(f).dy;
    // The first starts the body, with nothing to stand clear of.
    expect(top(photos.at(0)), top(find.byType(ArticleRichBody)));
    expect(
      top(photos.at(1)) - bottom(find.text('甲')),
      ArticleRichBody.objectGap,
    );
    final first = find.text('正文', findRichText: true);
    final second = find.text('下一段', findRichText: true);
    expect(top(first) - bottom(find.text('乙')), ArticleRichBody.blockGap);
    expect(top(second), bottom(first));
    expect(top(photos.at(2)) - bottom(second), ArticleRichBody.blockGap);
    // An empty line is room enough: nothing is added around it.
    expect(
      top(photos.at(3)) - bottom(find.text('丙')),
      closeTo(15 * ArticleRichBody.lineHeight, 1),
    );
  });
}
