import 'dart:convert';

import 'package:flutter/material.dart';

import 'design.dart';
import 'app_store.dart';
import 'article_link.dart';
import 'article_photo.dart';
import 'article_poll.dart';
import 'article_topic.dart';

String articleTopicLink(String name) =>
    Uri(scheme: 'bojian-topic', pathSegments: [name]).toString();

String? articleTopicName(Object? link) {
  if (link is! String || !link.startsWith('bojian-topic:')) return null;
  final uri = Uri.tryParse(link);
  if (uri == null ||
      uri.pathSegments.length != 1 ||
      uri.pathSegments.first.isEmpty) {
    return null;
  }
  return uri.pathSegments.first;
}

final _fontLacksBold = <String?, bool>{};

/// Some phones apply a user-chosen system font with a single weight, where
/// `FontWeight.w700` draws exactly like regular text and Flutter does not
/// synthesize bold. Returns shadows that thicken glyphs in that case, or null
/// when the font has a real bold.
List<Shadow>? articleBoldShadows(
  BuildContext context,
  Color color, {
  double? size,
}) {
  final base = DefaultTextStyle.of(context).style;
  final lacksBold = _fontLacksBold.putIfAbsent(base.fontFamily, () {
    double width(FontWeight weight) {
      final painter = TextPainter(
        text: TextSpan(
          text: 'WMwmBold 中文加粗',
          style: base.copyWith(fontSize: 40, fontWeight: weight),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final result = painter.width;
      painter.dispose();
      return result;
    }

    return (width(FontWeight.w700) - width(FontWeight.w400)).abs() < .5;
  });
  if (!lacksBold) return null;
  // Large text needs a proportionally larger offset.
  final offset = size == null ? .4 : size * .026;
  return [
    Shadow(color: color, offset: Offset(offset, 0)),
    Shadow(color: color, offset: Offset(-offset, 0)),
  ];
}

/// Heading level (1-6) of a block kind such as `heading2` or `h3`; `heading`
/// alone is the legacy first level.
int? articleHeadingLevel(String kind) {
  final lower = kind.toLowerCase();
  if (lower == 'heading') return 1;
  final match = RegExp(r'^(?:heading|h)([1-6])$').firstMatch(lower);
  return match == null ? null : int.parse(match.group(1)!);
}

/// One heading of an article, for the table of contents.
class ArticleHeading {
  const ArticleHeading(this.blockIndex, this.level, this.text);
  final int blockIndex, level;
  final String text;
}

/// The non-empty headings of [content], in reading order.
List<ArticleHeading> articleHeadings(Map<String, dynamic> content) {
  final result = <ArticleHeading>[];
  final blocks = content['blocks'] as List? ?? [];
  for (var i = 0; i < blocks.length; i++) {
    final block = blocks[i];
    if (block is! Map) continue;
    final level = articleHeadingLevel('${block['kind']}');
    if (level == null) continue;
    final text = [
      for (final span in block['spans'] as List? ?? [])
        if (span is Map) '${span['text'] ?? ''}',
    ].join().trim();
    if (text.isNotEmpty) result.add(ArticleHeading(i, level, text));
  }
  return result;
}

/// Converts editor operations to the block/span format shared with the Mac app.
Map<String, dynamic> articleContentFromDelta(List<dynamic> operations) {
  final blocks = <Map<String, dynamic>>[];
  var spans = <Map<String, dynamic>>[];
  bool embeddedLine = false;
  void finish(Map attributes) {
    final header = attributes['header'];
    final list = attributes['list'];
    blocks.add({
      'kind': header is int && header >= 1 && header <= 6
          ? 'heading$header'
          : header != null
          ? 'heading2'
          : list == 'bullet'
          ? 'bullet'
          : list == 'ordered'
          ? 'numbered'
          : attributes['blockquote'] == true
          ? 'quote'
          : 'paragraph',
      'spans': spans,
      if (attributes['align'] != null) 'align': attributes['align'],
      if (attributes['indent'] != null) 'indent': attributes['indent'],
    });
    spans = [];
  }

  for (final operation in operations) {
    if (operation is! Map) continue;
    final insert = operation['insert'];
    if (insert is Map && insert['bojian-block'] is String) {
      if (spans.isNotEmpty) finish({});
      blocks.add(Map<String, dynamic>.from(jsonDecode(insert['bojian-block'])));
      embeddedLine = true;
      continue;
    }
    if (insert is! String) continue;
    final attributes = operation['attributes'] as Map? ?? {};
    final parts = insert.split('\n');
    for (var i = 0; i < parts.length; i++) {
      if (parts[i].isNotEmpty) {
        embeddedLine = false;
        spans.add({
          'text': parts[i],
          if (articleTopicName(attributes['link']) case final String name)
            'topic': name,
          if (attributes['link'] is String &&
              articleWebLink(attributes['link']) != null)
            'link': attributes['link'],
          for (final key in ['bold', 'italic', 'underline'])
            if (attributes[key] == true) key: true,
          if (attributes['strike'] == true) 'strikethrough': true,
          if (attributes['color'] != null)
            'foregroundColor': attributes['color'],
          if (attributes['background'] != null)
            'backgroundColor': attributes['background'],
          if (attributes['size'] != null) 'size': attributes['size'],
        });
      }
      if (i < parts.length - 1) {
        if (embeddedLine) {
          embeddedLine = false;
        } else {
          finish(attributes);
        }
      }
    }
  }
  if (spans.isNotEmpty) finish({});
  return {'blocks': blocks};
}

/// Unsupported blocks remain intact as selectable embeds. Reopening a draft
/// must not discard Mac images, tables or formatting the mobile toolbar lacks.
List<Map<String, dynamic>> articleDeltaFromContent(
  Map<String, dynamic> content,
) {
  const blockKeys = {'kind', 'spans', 'align', 'indent'};
  const spanKeys = {
    'text',
    'link',
    'topic',
    'bold',
    'italic',
    'underline',
    'strikethrough',
    'foregroundColor',
    'foreground_color',
    'backgroundColor',
    'background_color',
    'size',
  };
  const kinds = {
    'paragraph',
    'heading1',
    'heading2',
    'heading3',
    'heading4',
    'heading5',
    'heading6',
    'bullet',
    'numbered',
    'quote',
  };
  final operations = <Map<String, dynamic>>[];
  for (final block in (content['blocks'] as List? ?? []).whereType<Map>()) {
    final spans = (block['spans'] as List? ?? []).whereType<Map>();
    if (!kinds.contains(block['kind']) ||
        !block.keys.every(blockKeys.contains) ||
        !spans.every((span) => span.keys.every(spanKeys.contains))) {
      operations.add({
        'insert': {'bojian-block': jsonEncode(block)},
      });
      operations.add({'insert': '\n'});
      continue;
    }
    for (final span in spans) {
      final text = '${span['text'] ?? ''}';
      if (text.isEmpty) continue;
      final attributes = {
        for (final key in ['bold', 'italic', 'underline'])
          if (span[key] == true) key: true,
        if (span['strikethrough'] == true) 'strike': true,
        'color': ?(span['foregroundColor'] ?? span['foreground_color']),
        'background': ?(span['backgroundColor'] ?? span['background_color']),
        'size': ?span['size'],
        if (span['topic'] is String)
          'link': articleTopicLink(span['topic'])
        else if (span['link'] is String && articleWebLink(span['link']) != null)
          'link': span['link'],
      };
      operations.add({
        'insert': text,
        if (attributes.isNotEmpty) 'attributes': attributes,
      });
    }
    final attributes = {
      'header': ?articleHeadingLevel('${block['kind']}'),
      if (block['kind'] == 'bullet') 'list': 'bullet',
      if (block['kind'] == 'numbered') 'list': 'ordered',
      if (block['kind'] == 'quote') 'blockquote': true,
      'align': ?block['align'],
      'indent': ?block['indent'],
    };
    operations.add({
      'insert': '\n',
      if (attributes.isNotEmpty) 'attributes': attributes,
    });
  }
  return operations.isEmpty
      ? [
          {'insert': '\n'},
        ]
      : operations;
}

class ArticleRichBody extends StatelessWidget {
  const ArticleRichBody({
    super.key,
    required this.content,
    this.store,
    this.articleID,
    this.editing = false,
    this.headingKeys,
  });
  final AppStore? store;
  final int? articleID;
  final bool editing;

  /// Keys for heading blocks by block index, so a page can scroll to them.
  final Map<int, GlobalKey>? headingKeys;
  final Map<String, dynamic> content;
  static const lineHeight = 1.6;
  Color? color(dynamic value) {
    if (value is! String) return null;
    final hex = value.trim().replaceFirst('#', '');
    final parsed = int.tryParse(hex, radix: 16);
    if (parsed == null) return null;
    // The shared Mac document uses #RRGGBB and #RRGGBBAA.
    return switch (hex.length) {
      6 => Color(parsed | 0xff000000),
      8 => Color((parsed >> 8) | ((parsed & 0xff) << 24)),
      _ => null,
    };
  }

  Text text(
    BuildContext context,
    List spans, {
    double size = 15,
    bool bold = false,
    bool italic = false,
    TextAlign align = TextAlign.start,
  }) => Text.rich(
    TextSpan(
      children: [
        for (final span in spans)
          if (span is Map && span['topic'] is String && store != null)
            WidgetSpan(
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              child: InkWell(
                onTap: () => openArticleTopic(context, store!, span['topic']),
                child: Text(
                  '${span['text'] ?? ''}',
                  style: TextStyle(
                    color: context.colors.accent,
                    fontSize: size,
                    height: lineHeight,
                  ),
                ),
              ),
            )
          else if (span is Map &&
              span['link'] is String &&
              articleWebLink(span['link']) != null)
            WidgetSpan(
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              child: InkWell(
                onTap: () =>
                    openArticleLink(context, articleWebLink(span['link'])!),
                child: Text(
                  '${span['text'] ?? ''}',
                  style: TextStyle(
                    color: context.colors.accent,
                    fontSize: size,
                    height: lineHeight,
                  ),
                ),
              ),
            )
          else if (span is Map)
            TextSpan(
              text: '${span['text'] ?? ''}',
              style: TextStyle(
                fontSize: switch (span['size']) {
                  'small' => 12,
                  'large' => 19,
                  'huge' => 24,
                  _ => null,
                },
                fontWeight: span['bold'] == true || bold
                    ? FontWeight.w700
                    : FontWeight.w400,
                fontStyle: span['italic'] == true || italic
                    ? FontStyle.italic
                    : FontStyle.normal,
                decoration: TextDecoration.combine([
                  if (span['underline'] == true) TextDecoration.underline,
                  if (span['strikethrough'] == true) TextDecoration.lineThrough,
                ]),
                shadows: span['bold'] == true || bold
                    ? articleBoldShadows(
                        context,
                        color(
                              span['foreground_color'] ??
                                  span['foregroundColor'],
                            ) ??
                            context.colors.ink,
                        size: span['size'] == null ? size : null,
                      )
                    : null,
                color: color(
                  span['foreground_color'] ?? span['foregroundColor'],
                ),
                backgroundColor: color(
                  span['background_color'] ?? span['backgroundColor'],
                ),
              ),
            ),
      ],
    ),
    textAlign: align,
    style: TextStyle(
      fontSize: size,
      height: lineHeight,
      color: context.colors.ink,
    ),
  );

  Widget media(BuildContext context, Map block, String kind) {
    final data = block[kind] is Map ? block[kind] as Map : const {};
    final id = integer(data['file_id']);
    final declaration = content['declaration'];
    final mark = declaration is Map && declaration['watermark'] == true
        ? '${declaration['watermark_label'] ?? 'Z优简'}'
        : null;
    final url = Uri.tryParse('${data['url'] ?? ''}');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (id > 0 && store != null)
          ArticlePhoto(
            store: store!,
            fileID: id,
            articleID: articleID,
            video: kind == 'video',
            watermark: mark,
          )
        else if (kind == 'image' &&
            url != null &&
            ['https', 'http'].contains(url.scheme))
          ArticleNetworkPhoto(
            url: url.toString(),
            watermark: mark,
            alt: data['alt']?.toString(),
          ),
        if ('${data['caption'] ?? ''}'.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              '${data['caption']}',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: context.colors.muted),
            ),
          ),
      ],
    );
  }

  Widget table(BuildContext context, Map block) {
    final data = block['table'] is Map ? block['table'] as Map : const {};
    final rows = (data['rows'] as List? ?? []).whereType<Map>().toList();
    final count = rows.fold<int>(
      0,
      (n, row) => (row['cells'] as List? ?? []).length > n
          ? (row['cells'] as List).length
          : n,
    );
    if (count == 0) return const SizedBox.shrink();
    return Table(
      border: TableBorder.all(color: context.colors.border),
      children: [
        for (var i = 0; i < rows.length; i++)
          TableRow(
            decoration: i == 0
                ? BoxDecoration(color: context.colors.canvas)
                : null,
            children: [
              for (var j = 0; j < count; j++)
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: text(
                    context,
                    j < (rows[i]['cells'] as List).length
                        ? ((rows[i]['cells'] as List)[j] as Map)['spans']
                                  as List? ??
                              []
                        : [],
                    size: 13,
                    bold: i == 0,
                  ),
                ),
            ],
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    var number = 0;
    final children = <Widget>[];
    final blocks = content['blocks'] as List? ?? [];
    for (var index = 0; index < blocks.length; index++) {
      final block = blocks[index];
      if (block is! Map) continue;
      final kind = '${block['kind']}'.toLowerCase();
      final numbered = kind == 'numbered';
      number = numbered ? number + 1 : 0;
      final heading = articleHeadingLevel(kind);
      final quote = ['quote', 'blockquote'].contains(kind);
      final spans = block['spans'] as List? ?? [];
      final blank = spans.every(
        (s) => s is! Map || '${s['text'] ?? ''}'.isEmpty,
      );
      final align = switch (block['align']) {
        'center' => TextAlign.center,
        'right' => TextAlign.right,
        'justify' => TextAlign.justify,
        _ => TextAlign.start,
      };
      Widget child;
      if (kind == 'image' || kind == 'video') {
        child = media(context, block, kind);
      } else if (kind == 'poll') {
        child = ArticlePollCard(
          block: Map<String, dynamic>.from(block),
          store: store,
          articleID: editing ? null : articleID,
        );
      } else if (kind == 'link') {
        final uri = articleWebLink('${block['url'] ?? ''}');
        if (uri == null) continue;
        child = ArticleLinkCard(url: uri);
      } else if (kind == 'table') {
        child = table(context, block);
      } else if (blank) {
        // One explicit empty paragraph is exactly one body-text line.
        child = const Text(
          ' ',
          style: TextStyle(fontSize: 15, height: lineHeight),
        );
      } else {
        child = text(
          context,
          spans,
          size: switch (heading) {
            1 => 22,
            2 => 19,
            3 => 17.5,
            4 => 16,
            5 => 15,
            6 => 13.5,
            _ => 15,
          },
          bold: heading != null,
          italic: quote,
          align: align,
        );
        if (numbered || kind == 'bullet') {
          child = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 28,
                child: Text(
                  numbered ? '$number.' : '•',
                  style: TextStyle(
                    fontSize: 15,
                    height: lineHeight,
                    color: context.colors.accent,
                  ),
                ),
              ),
              Expanded(child: child),
            ],
          );
        }
        if (quote || kind == 'code') {
          child = Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: context.colors.canvas,
              border: quote
                  ? Border(
                      left: BorderSide(color: context.colors.accent, width: 3),
                    )
                  : null,
            ),
            child: child,
          );
        }
      }
      final headingKey = heading == null ? null : headingKeys?[index];
      children.add(
        Padding(
          key: headingKey,
          padding: EdgeInsets.only(
            top: heading != null ? 8 : 0,
            left: ((block['indent'] as num?)?.toDouble() ?? 0).clamp(0, 8) * 16,
          ),
          child: child,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}
