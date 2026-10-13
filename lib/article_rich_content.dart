import 'package:flutter/material.dart';

import 'design.dart';

/// Converts editor operations to the block/span format shared with the Mac app.
Map<String, dynamic> articleContentFromDelta(List<dynamic> operations) {
  final blocks = <Map<String, dynamic>>[];
  var spans = <Map<String, dynamic>>[];
  void finish(Map attributes) {
    final header = attributes['header'];
    final list = attributes['list'];
    blocks.add({
      'kind': header == 1
          ? 'heading1'
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
    if (operation is! Map || operation['insert'] is! String) continue;
    final attributes = operation['attributes'] as Map? ?? {};
    final parts = (operation['insert'] as String).split('\n');
    for (var i = 0; i < parts.length; i++) {
      if (parts[i].isNotEmpty) {
        spans.add({
          'text': parts[i],
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
      if (i < parts.length - 1) finish(attributes);
    }
  }
  if (spans.isNotEmpty) finish({});
  return {'blocks': blocks};
}

class ArticleRichBody extends StatelessWidget {
  const ArticleRichBody({super.key, required this.content});
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
    List spans, {
    double size = 15,
    bool bold = false,
    bool italic = false,
    TextAlign align = TextAlign.start,
  }) => Text.rich(
    TextSpan(
      children: [
        for (final span in spans)
          if (span is Map)
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
    style: TextStyle(fontSize: size, height: lineHeight, color: ink),
  );

  Widget image(Map block) {
    final data = block['image'] is Map ? block['image'] as Map : const {};
    final url = Uri.tryParse('${data['url'] ?? ''}');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (url != null && ['https', 'http'].contains(url.scheme))
          Image.network(
            url.toString(),
            fit: BoxFit.contain,
            semanticLabel: '${data['alt'] ?? ''}',
            errorBuilder: (_, _, _) => Text(
              '${data['alt'] ?? '图片暂时无法显示'}',
              style: const TextStyle(color: muted),
            ),
          ),
        if ('${data['caption'] ?? ''}'.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              '${data['caption']}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: muted),
            ),
          ),
      ],
    );
  }

  Widget table(Map block) {
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
      border: TableBorder.all(color: borderColor),
      children: [
        for (var i = 0; i < rows.length; i++)
          TableRow(
            decoration: i == 0 ? const BoxDecoration(color: canvasColor) : null,
            children: [
              for (var j = 0; j < count; j++)
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: text(
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
    for (final block in content['blocks'] as List? ?? []) {
      if (block is! Map) continue;
      final kind = '${block['kind']}'.toLowerCase();
      final numbered = kind == 'numbered';
      number = numbered ? number + 1 : 0;
      final heading1 = ['heading', 'heading1', 'h1'].contains(kind);
      final heading2 = ['heading2', 'h2'].contains(kind);
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
      if (kind == 'image') {
        child = image(block);
      } else if (kind == 'table') {
        child = table(block);
      } else if (blank) {
        // One explicit empty paragraph is exactly one body-text line.
        child = const Text(
          ' ',
          style: TextStyle(fontSize: 15, height: lineHeight),
        );
      } else {
        child = text(
          spans,
          size: heading1
              ? 22
              : heading2
              ? 19
              : 15,
          bold: heading1 || heading2,
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
                  style: const TextStyle(
                    fontSize: 15,
                    height: lineHeight,
                    color: blue,
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
              color: canvasColor,
              border: quote
                  ? const Border(left: BorderSide(color: blue, width: 3))
                  : null,
            ),
            child: child,
          );
        }
      }
      children.add(
        Padding(
          padding: EdgeInsets.only(
            top: heading1 || heading2 ? 8 : 0,
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
