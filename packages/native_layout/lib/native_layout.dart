import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:vector_graphics/vector_graphics.dart' as vg;

typedef J = Map<String, dynamic>;
typedef Draw = void Function(ui.Canvas);
double number(dynamic v, [double fallback = 0]) =>
    v is num ? v.toDouble() : fallback;
J map(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : {};
ui.Color color(String s, [double opacity = 1]) =>
    ui.Color(int.parse('ff${s.substring(1)}', radix: 16))
        .withValues(alpha: opacity);

class Box {
  Box(this.width, this.height);
  double width, height;
  double? firstBaseline;
  final draws = <Draw>[];
  final breaks = <double>[];
  final protected = <(double, double)>[];
  final markers = <J>[];
  final decorations = <J>[];
  void add(Box child, double x, double y) {
    decorations.addAll(
      child.decorations.map(
        (d) => {...d, 'rect': (d['rect'] as ui.Rect).shift(ui.Offset(x, y))},
      ),
    );
    firstBaseline ??= child.firstBaseline == null
        ? null
        : child.firstBaseline! + y;
    draws.add((c) {
      c.save();
      c.translate(x, y);
      for (final draw in child.draws) {
        draw(c);
      }
      c.restore();
    });
    breaks.addAll(child.breaks.map((b) => b + y));
    protected.addAll(child.protected.map((p) => (p.$1 + y, p.$2 + y)));
    markers.addAll(
      child.markers.map(
        (m) => {...m, 'x': number(m['x']) + x, 'y': number(m['y']) + y},
      ),
    );
  }
}

// Ignore formatting metadata, IDs and empty rich-text paragraphs when deciding
// whether a resume section contains user content.
String nativeRichText(dynamic value) => value is Map && value['blocks'] is List
    ? (value['blocks'] as List)
          .whereType<Map>()
          .map(
            (block) =>
                (block['spans'] is List ? block['spans'] as List : const [])
                    .whereType<Map>()
                    .map((span) => span['text'] is String ? span['text'] : '')
                    .join(),
          )
          .join('\n')
    : '';

bool nativeFieldHasContent(Map fields, String key) =>
    (fields[key] is String && (fields[key] as String).trim().isNotEmpty) ||
    nativeRichText(fields['${key}_rich']).trim().isNotEmpty;

const nativeEntryFields = [
  'title',
  'name',
  'subtitle',
  'auxiliary',
  'start_date',
  'end_date',
  'detail',
  'secondary_detail',
];
const nativeArrayFields = [
  'educations',
  'work_experiences',
  'projects',
  'certifications',
  'skills',
];

J normalizeNativeFields(J fields) => {
  ...fields,
  for (final key in nativeArrayFields)
    key: (fields[key] is List ? fields[key] as List : const [])
        .whereType<Map>()
        .where(
          (row) =>
              nativeEntryFields.any((key) => nativeFieldHasContent(row, key)),
        )
        .map(map)
        .toList(),
};

bool nativeSectionHasContent(String id, J fields, {bool hasPhoto = false}) {
  if (id == 'personal_info') {
    return hasPhoto ||
        [
          'name',
          'phone',
          'email',
          'birth_date',
          'gender',
        ].any((key) => nativeFieldHasContent(fields, key));
  }
  if (id == 'job_expectation') {
    return [
      'position',
      'city',
      'industry',
      'salary',
    ].any((key) => nativeFieldHasContent(fields, key));
  }
  if (id == 'self_evaluation') {
    return nativeFieldHasContent(fields, 'preference');
  }
  if (nativeArrayFields.contains(id)) {
    return (fields[id] is List ? fields[id] as List : const [])
        .whereType<Map>()
        .any(
          (row) =>
              nativeEntryFields.any((key) => nativeFieldHasContent(row, key)),
        );
  }
  return false;
}

class NativeLayoutRenderer {
  NativeLayoutRenderer(
    this.layout,
    J fields,
    this.assetBytes, {
    this.photoBytes,
    this.useSystemFont = false,
  }) : fields = normalizeNativeFields(fields);
  final J layout, fields;
  final Map<String, Uint8List> assetBytes;
  final Uint8List? photoBytes;
  final bool useSystemFont;
  static Future<void>? _fonts;
  bool paintText = true;
  static Future<void> loadFonts(AssetBundle bundle) => _fonts ??=
      () async {
        for (final face in ['regular', 'medium', 'bold']) {
          final loader = FontLoader('Resume-$face');
          loader.addFont(
            bundle.load('assets/fonts/alibaba-puhuiti-3-$face.ttf'),
          );
          await loader.load();
        }
      }().catchError((Object e, StackTrace st) {
        _fonts = null;
        Error.throwWithStackTrace(e, st);
      });
  final pictures = <String, vg.PictureInfo>{};
  final images = <String, ui.Image>{};
  final painters = <TextPainter>[];
  final warnings = <String>{};
  late final double pageW = number(layout['page']['size']['width']);
  late final double pageH = number(layout['page']['size']['height']);
  late final J pagePadding = map(layout['page']['contentPadding']);
  late final double contentH =
      pageH - number(pagePadding['top']) - number(pagePadding['bottom']);
  Future<void> prepare() async {
    for (final entry in map(layout['assets']).entries) {
      final asset = map(entry.value);
      final bytes = assetBytes[entry.key];
      if (bytes == null) throw FormatException('缺少素材 ${entry.key}');
      if (asset['type'] == 'svg') {
        pictures[entry.key] = await vg.vg.loadPicture(
          SvgStringLoader(utf8.decode(bytes)),
          null,
        );
      } else {
        // MemoryImage uses Flutter's bounded image cache. Shared immutable
        // asset bytes keep the same key, while each renderer owns its clone.
        final stream = MemoryImage(bytes).resolve(ImageConfiguration.empty);
        final ready = Completer<ui.Image>();
        late ImageStreamListener listener;
        listener = ImageStreamListener(
          (info, _) {
            if (!ready.isCompleted) ready.complete(info.image.clone());
          },
          onError: (Object error, StackTrace? stack) {
            if (!ready.isCompleted) ready.completeError(error, stack);
          },
        );
        stream.addListener(listener);
        try {
          images[entry.key] = await ready.future;
        } finally {
          stream.removeListener(listener);
        }
      }
    }
    if (photoBytes != null && photoBytes!.isNotEmpty) {
      final codec = await ui.instantiateImageCodec(photoBytes!);
      images['photo'] = (await codec.getNextFrame()).image;
      codec.dispose();
    }
  }

  dynamic resolve(dynamic binding, J item) {
    if (binding is! String) return null;
    if (binding == r'$media.photo') {
      return images.containsKey('photo') ? 'photo' : null;
    }
    if (binding.startsWith(r'$resume.')) return fields[binding.substring(8)];
    if (binding.startsWith(r'$item.')) return item[binding.substring(6)];
    throw StateError('Unknown binding: $binding');
  }

  bool meaningful(dynamic v) {
    if (v == null) return false;
    if (v is String) return v.trim().isNotEmpty;
    if (v is List) return v.any(meaningful);
    if (v is Map) return v.values.any(meaningful);
    return true;
  }

  TextStyle textStyle(String name, [J overrides = const {}]) {
    final s = {...map(layout['textStyles'][name]), ...overrides};
    final weight = number(s['fontWeight'], 400);
    return TextStyle(
      fontFamily: useSystemFont
          ? null
          : 'Resume-${weight >= 700
                ? 'bold'
                : weight >= 500
                ? 'medium'
                : 'regular'}',
      fontSize: number(s['fontSizePt'], 8.5) * 96 / 72,
      fontWeight: useSystemFont
          ? FontWeight.values[((weight / 100).round() - 1).clamp(0, 8)]
          : FontWeight.normal,
      height: number(s['lineHeight'], 1.75),
      letterSpacing: number(s['letterSpacing']),
      color: color(s['color'] ?? '#262B27'),
      leadingDistribution: TextLeadingDistribution.even,
    );
  }

  Box paragraph(
    String value,
    String name,
    double maxW, {
    J overrides = const {},
    List<InlineSpan>? spans,
    bool split = false,
  }) {
    if (value.isEmpty && spans == null) return Box(0, 0);
    final style = textStyle(name, overrides);
    final tp = TextPainter(
      text: TextSpan(
        text: spans == null ? value : null,
        children: spans,
        style: style,
      ),
      textDirection: TextDirection.ltr,
      textScaler: TextScaler.noScaling,
      textWidthBasis: TextWidthBasis.longestLine,
      textHeightBehavior: const TextHeightBehavior(
        applyHeightToFirstAscent: true,
        applyHeightToLastDescent: true,
      ),
    )..layout(maxWidth: math.max(1, maxW));
    painters.add(tp);
    final b = Box(tp.width, tp.height);
    b.draws.add((c) {
      if (paintText) tp.paint(c, ui.Offset.zero);
    });
    final lines = tp.computeLineMetrics();
    b.firstBaseline = lines.isEmpty ? null : lines.first.baseline;
    if (split) {
      for (var i = 1; i < lines.length; i++) {
        if (i >= 2 && lines.length - i >= 2) {
          b.breaks.add(lines[i].baseline - lines[i].ascent);
        }
      }
    }
    b.breaks.add(b.height);
    b.markers.add({
      'kind': 'text',
      'text': value.isNotEmpty ? value : tp.text!.toPlainText(),
      'x': 0,
      'y': 0,
      'width': b.width,
      'height': b.height,
      'lines': lines.length,
      'exportLines': exportTextLines(tp, style, maxW),
      'lineBoxes': lines
          .map(
            (line) => {
              'top': line.baseline - line.ascent,
              'bottom': line.baseline + line.descent,
            },
          )
          .toList(),
    });
    return b;
  }

  Box asset(
    String id,
    double width,
    double height, {
    String fit = 'fill',
    double radius = 0,
  }) {
    final b = Box(width, height);
    b.draws.add((c) {
      c.save();
      final rect = ui.Rect.fromLTWH(0, 0, width, height);
      c.clipRRect(ui.RRect.fromRectAndRadius(rect, ui.Radius.circular(radius)));
      if (pictures.containsKey(id)) {
        final p = pictures[id]!;
        final scale = fit == 'contain'
            ? math.min(width / p.size.width, height / p.size.height)
            : null;
        final sx = scale ?? width / p.size.width,
            sy = scale ?? height / p.size.height;
        c.translate(
          (width - p.size.width * sx) / 2,
          (height - p.size.height * sy) / 2,
        );
        c.scale(sx, sy);
        c.drawPicture(p.picture);
      } else {
        final image = images[id];
        if (image == null) throw StateError('Missing asset $id');
        final sz = ui.Size(image.width.toDouble(), image.height.toDouble());
        final fitted = applyBoxFit(
          fit == 'cover'
              ? BoxFit.cover
              : fit == 'contain'
              ? BoxFit.contain
              : BoxFit.fill,
          sz,
          ui.Size(width, height),
        );
        c.drawImageRect(
          image,
          Alignment.center.inscribe(fitted.source, ui.Offset.zero & sz),
          Alignment.center.inscribe(fitted.destination, rect),
          ui.Paint()..filterQuality = ui.FilterQuality.high,
        );
      }
      c.restore();
    });
    b.protected.add((0, height));
    b.breaks.add(height);
    return b;
  }

  Box render(J node, double width, [J item = const {}]) {
    if (node['visibleWhen'] != null &&
        !meaningful(resolve(node['visibleWhen']['nonEmpty'], item))) {
      return Box(0, 0);
    }
    final m = map(node['margin']), p = map(node['padding']);
    final ml = number(m['left']),
        mr = number(m['right']),
        mt = number(m['top']),
        mb = number(m['bottom']);
    final pl = number(p['left']),
        pr = number(p['right']),
        pt = number(p['top']),
        pb = number(p['bottom']);
    final innerW = math.max(1.0, width - ml - mr - pl - pr);
    Box b;
    switch (node['type']) {
      case 'text':
        String value;
        if (node['format'] == 'dateRange') {
          final args = map(node['bindings']);
          final a = '${resolve(args['start'], item) ?? ''}'.trim(),
              z = '${resolve(args['end'], item) ?? ''}'.trim();
          value = a.isNotEmpty && z.isNotEmpty && a != z
              ? '$a — $z'
              : a.isNotEmpty
              ? a
              : z;
        } else {
          value = '${node['text'] ?? resolve(node['binding'], item) ?? ''}';
        }
        if (node['hideWhenEmpty'] == true && value.trim().isEmpty) {
          return Box(0, 0);
        }
        b = paragraph(
          value,
          node['textStyle'] ?? 'body',
          innerW,
          overrides: {if (node['color'] != null) 'color': node['color']},
        );
      case 'svg':
      case 'image':
        final id = node['asset'] ?? resolve(node['binding'], item);
        if (id == null && node['hideWhenEmpty'] == true) return Box(0, 0);
        b = asset(
          id,
          number(node['width'], innerW),
          number(node['height']),
          fit: node['fit'] ?? 'contain',
          radius: number(node['borderRadius']),
        );
      case 'column':
        b = vertical(
          (node['children'] as List? ?? []).map(map).toList(),
          innerW,
          item,
        );
      case 'row':
      case 'wrap':
        b = horizontal(node, innerW, item);
      case 'richText':
        b = rich(node, innerW, item);
      case 'sectionHeading':
        b = heading(node, innerW);
      case 'section':
        b = vertical(
          [map(node['heading']), map(node['content'])],
          innerW,
          item,
        );
        final headingBottom = render(map(node['heading']), innerW, item).height;
        b.protected.add((0, math.min(b.height, headingBottom + 25)));
        b.markers.add({
          'kind': 'section',
          'id': node['id'],
          'x': 0,
          'y': 0,
          'width': innerW,
          'height': b.height,
        });
      case 'repeat':
      case 'gridRepeat':
        final rows = (resolve(node['binding'], item) as List? ?? [])
            .where(meaningful)
            .map(map)
            .toList();
        if (node['type'] == 'gridRepeat') {
          b = Box(innerW, 0);
          final weights = (node['columnWeights'] as List)
              .map((v) => number(v))
              .toList();
          final gap = number(node['columnGap']);
          final sum = weights.reduce((a, b) => a + b);
          for (var start = 0; start < rows.length; start += weights.length) {
            var x = 0.0, h = 0.0;
            final y = b.height;
            for (
              var col = 0;
              col < weights.length && start + col < rows.length;
              col++
            ) {
              final w =
                  (innerW - gap * (weights.length - 1)) * weights[col] / sum;
              final child = render(map(node['item']), w, rows[start + col]);
              b.add(child, x, y);
              h = math.max(h, child.height);
              x += w + gap;
            }
            if (h <= contentH) b.protected.add((y, y + h));
            b.height += h;
            b.breaks.add(b.height);
            if (start + weights.length < rows.length) {
              b.height += number(node['rowGap']);
            }
          }
        } else {
          b = Box(innerW, 0);
          for (final row in rows) {
            final child = render(map(node['item']), innerW, row);
            if (child.height == 0) continue;
            if (b.height > 0) b.height += number(node['itemGap']);
            b.add(child, 0, b.height);
            b.height += child.height;
            b.breaks.add(b.height);
          }
        }
      case 'intentionCell':
        final icon = map(node['icon']);
        final iconW = number(icon['columnWidth']);
        final gap = number(node['columnGap']);
        final value = render(map(node['value']), innerW - iconW - gap, item);
        final label = paragraph(
          node['label']['text'],
          node['label']['textStyle'],
          innerW - iconW - gap,
        );
        b = Box(
          innerW,
          math.max(
            number(icon['height']),
            label.height + number(node['rowGap']) + value.height,
          ),
        );
        b.add(
          asset(
            icon['asset'],
            number(icon['width']),
            number(icon['height']),
            fit: 'contain',
          ),
          0,
          0,
        );
        b.add(label, iconW + gap, 0);
        b.add(value, iconW + gap, label.height + number(node['rowGap']));
        if (node['trailingBorder'] != null && node['_lastVisible'] != true) {
          final border = map(node['trailingBorder']);
          b.draws.add(
            (c) => c.drawLine(
              ui.Offset(innerW + pr, 0),
              ui.Offset(innerW + pr, b.height),
              ui.Paint()
                ..color = color(border['color'])
                ..strokeWidth = number(border['width']),
            ),
          );
        }
      default:
        throw StateError('Unsupported node ${node['type']}');
    }
    if (node['hideWhenEmpty'] == true && b.height == 0) return Box(0, 0);
    final outer = Box(
      b.width + pl + pr + ml + mr,
      math.max(number(node['minHeight']), b.height + pt + pb) + mt + mb,
    );
    final background = map(node['background']);
    if (background.isNotEmpty) {
      final rect = ui.Rect.fromLTWH(
        ml,
        mt,
        innerW + pl + pr,
        outer.height - mt - mb,
      );
      outer.decorations.add({
        'rect': rect,
        'radius': number(node['borderRadius']),
        'color': color(background['color'], number(background['opacity'], 1)),
        'fragment': node['pagination']?['decorationOnEachFragment'] == true,
      });
    }
    outer.add(b, ml + pl, mt + pt);
    outer.breaks.add(outer.height);
    final keep = node['pagination']?['keepTogether'];
    if ((keep == true || keep == 'ifFitsPage') && outer.height <= contentH) {
      outer.protected.add((0, outer.height));
    }
    return outer;
  }

  Box vertical(List<J> nodes, double width, J item) {
    final b = Box(width, 0);
    for (final node in nodes) {
      final child = render(node, width, item);
      if (child.height == 0) continue;
      b.add(child, 0, b.height);
      b.height += child.height;
      b.breaks.add(b.height);
    }
    return b;
  }

  Box horizontal(J node, double width, J item) {
    final children = (node['children'] as List? ?? [])
        .map(map)
        .where(
          (n) =>
              n['visibleWhen'] == null ||
              meaningful(resolve(n['visibleWhen']['nonEmpty'], item)),
        )
        .toList();
    final entries = <(J, Box, double)>[];
    final gap = number(node['gap']), runGap = number(node['runGap']);
    for (var i = 0; i < children.length; i++) {
      final n = {
        ...children[i],
        if (i == children.length - 1) '_lastVisible': true,
      };
      final l = map(n['layout']);
      final natural = render(n, width, item);
      if (natural.height == 0) continue;
      final basis = l['basisFraction'] == null
          ? null
          : width * number(l['basisFraction']);
      final max = width * number(l['maxWidthFraction'], 1);
      final w = math.min(
        max,
        math.max(number(l['minWidth']), basis ?? natural.width),
      );
      entries.add((n, natural, w));
    }
    final rows = <(List<(J, Box, double)>, double)>[];
    var row = <(J, Box, double)>[];
    var used = 0.0;
    for (final e in entries) {
      // A grow title and trailing date share a row; width is resolved below.
      final hasGrow = row.any((v) => number(v.$1['layout']?['grow']) > 0);
      if (node['type'] == 'wrap' &&
          row.isNotEmpty &&
          !hasGrow &&
          used + gap + e.$3 > width + 0.001) {
        rows.add((row, used));
        row = [];
        used = 0;
      }
      if (row.isNotEmpty) used += gap;
      used += e.$3;
      row.add(e);
    }
    if (row.isNotEmpty) rows.add((row, used));
    final b = Box(node['type'] == 'row' ? 0 : width, 0);
    for (final data in rows) {
      final r = data.$1;
      final flexible = r
          .where((e) => number(e.$1['layout']?['grow']) > 0)
          .toList();
      final fixed = r
          .where((e) => number(e.$1['layout']?['grow']) <= 0)
          .fold(0.0, (a, e) => a + e.$3);
      final sumGrow = flexible.fold(
        0.0,
        (a, e) => a + number(e.$1['layout']?['grow']),
      );
      final allBasis =
          flexible.isNotEmpty &&
          flexible.every((e) => e.$1['layout']?['basisFraction'] != null);
      final free = width - fixed - gap * math.max(0, r.length - 1);
      final boxes = <(Box, double)>[];
      for (final e in r) {
        final grow = number(e.$1['layout']?['grow']);
        double w = e.$3;
        if (grow > 0) {
          w = allBasis
              ? e.$3 + (width - data.$2) * grow / sumGrow
              : math.max(1, free * grow / sumGrow);
        }
        final child = render(e.$1, math.max(1, w), item);
        boxes.add((child, w));
      }
      var h = boxes.fold(0.0, (a, e) => math.max(a, e.$1.height));
      var x = 0.0;
      final y = b.height;
      // Baseline alignment uses text font ascent, including wrapped metadata.
      double baseline(Box box) => box.firstBaseline ?? box.height;
      final base = boxes.fold(0.0, (a, e) => math.max(a, baseline(e.$1)));
      for (final pair in boxes) {
        final child = pair.$1;
        final offset = node['crossAxisAlignment'] == 'center'
            ? (h - child.height) / 2
            : node['crossAxisAlignment'] == 'baseline'
            ? base - baseline(child)
            : 0.0;
        b.add(child, x, y + offset);
        h = math.max(h, child.height + offset);
        x += pair.$2 + gap;
      }
      b.width = math.max(b.width, math.max(0, x - gap));
      b.height += h;
      b.breaks.add(b.height);
      if (h <= contentH) b.protected.add((y, y + h));
      if (data != rows.last) b.height += runGap;
    }
    return b;
  }

  Box rich(J n, double width, J item) {
    final value = map(resolve(n['binding'], item));
    final fallback = '${resolve(n['fallbackTextBinding'], item) ?? ''}';
    final blocks = nativeRichText(value).trim().isNotEmpty
        ? (value['blocks'] as List? ?? []).map(map).toList()
        : fallback.isEmpty
        ? <J>[]
        : fallback
              .split(RegExp(r'\r\n|\r|\n'))
              .map(
                (s) => <String, dynamic>{
                  'kind': 'paragraph',
                  'spans': [
                    {'text': s},
                  ],
                },
              )
              .toList();
    final b = Box(width, 0);
    var count = 0;
    String last = '';
    for (final block in blocks) {
      final kind = block['kind'];
      if (kind != last) count = 0;
      final marker = kind == 'bullet'
          ? '• '
          : kind == 'numbered'
          ? '${++count}. '
          : '';
      last = '$kind';
      final spans = <InlineSpan>[if (marker.isNotEmpty) TextSpan(text: marker)];
      var plain = marker;
      for (final span in (block['spans'] as List? ?? []).map(map)) {
        final value = '${span['text'] ?? ''}';
        plain += value;
        spans.add(
          TextSpan(
            text: value,
            style: TextStyle(
              fontFamily: !useSystemFont && span['bold'] == true
                  ? 'Resume-bold'
                  : null,
              fontWeight: useSystemFont && span['bold'] == true
                  ? FontWeight.bold
                  : null,
              fontStyle: span['italic'] == true ? FontStyle.italic : null,
              decoration: TextDecoration.combine([
                if (span['underline'] == true) TextDecoration.underline,
                if (span['strikethrough'] == true) TextDecoration.lineThrough,
              ]),
            ),
          ),
        );
      }
      final part = paragraph(
        plain.isEmpty ? ' ' : plain,
        n['textStyle'] ?? 'body',
        width,
        spans: spans,
        split: true,
      );
      b.add(part, 0, b.height);
      b.height += part.height;
      b.breaks.add(b.height);
      if (block != blocks.last) {
        b.height += number(
          kind == 'paragraph' ? n['paragraphGap'] : n['listItemGap'],
        );
      }
    }
    return b;
  }

  Box heading(J node, double width) {
    final d = map(layout['decorations'][node['decoration']]);
    final icon = map(d['iconSize']);
    final gap = number(d['gap']);
    final bg = map(d['titleBackground']), p = map(bg['padding']);
    final tp = paragraph(
      node['text'],
      d['textStyle'],
      width - number(icon['width']) - gap,
    );
    final titleW = tp.width + number(p['left']) + number(p['right']);
    final titleH = tp.height + number(p['top']) + number(p['bottom']);
    final h = math.max(number(icon['height']), titleH);
    final b = Box(width, h);
    b.add(
      asset(
        node['iconAsset'],
        number(icon['width']),
        number(icon['height']),
        fit: 'contain',
      ),
      0,
      (h - number(icon['height'])) / 2,
    );
    final x = number(icon['width']) + gap;
    b.add(asset(bg['asset'], titleW, titleH, fit: 'fill'), x, (h - titleH) / 2);
    b.add(tp, x + number(p['left']), (h - titleH) / 2 + number(p['top']));
    final rule = map(d['trailingRule']),
        line = map(rule['line']),
        dot = map(rule['endDot']);
    b.draws.add((c) {
      c.drawLine(
        ui.Offset(x + titleW + gap, h / 2),
        ui.Offset(width, h / 2),
        ui.Paint()
          ..color = color(line['color'])
          ..strokeWidth = number(line['width']),
      );
      c.drawCircle(
        ui.Offset(width - number(dot['insetRight']), h / 2),
        number(dot['radius']),
        ui.Paint()..color = color(dot['color']),
      );
    });
    b.breaks.add(h);
    b.protected.add((0, h));
    return b;
  }

  NativeDocument buildDocument() {
    final timer = Stopwatch()..start();
    final sections = (layout['sections'] as List).map(map).toList();
    final requested = (fields['section_order'] as List? ?? [])
        .whereType<String>()
        .toList();
    final order = <String>{
      'personal_info',
      ...requested,
      ...sections.map((s) => s['id'] as String),
    };
    final nodes = order
        .map((id) => sections.where((s) => s['id'] == id).firstOrNull)
        .whereType<J>()
        .where(
          (node) => nativeSectionHasContent(
            node['id'] as String,
            fields,
            hasPhoto: images.containsKey('photo'),
          ),
        )
        .toList();
    final flow = vertical(
      nodes,
      pageW - number(pagePadding['left']) - number(pagePadding['right']),
      {},
    );
    final layoutMs = timer.elapsedMicroseconds / 1000;
    final cuts = <double>[0];
    while (cuts.last < flow.height - 0.01) {
      final start = cuts.last, limit = math.min(flow.height, start + contentH);
      final valid =
          flow.breaks
              .where(
                (v) =>
                    v > start + 0.01 &&
                    v <= limit + 0.01 &&
                    !flow.protected.any(
                      (p) => v > p.$1 + 0.01 && v < p.$2 - 0.01,
                    ),
              )
              .toList()
            ..sort();
      final end = limit >= flow.height
          ? flow.height
          : valid.isNotEmpty
          ? valid.last
          : throw StateError('No safe page break after $start');
      cuts.add(end);
      if (cuts.length > 31) throw StateError('Too many pages');
    }
    // An entirely empty resume remains a single blank paper, without headings.
    if (cuts.length == 1) cuts.add(0);
    for (final mark in flow.markers.where((m) => m['kind'] == 'text')) {
      for (final line in (mark['lineBoxes'] as List)) {
        final top = number(mark['y']) + number(line['top']),
            bottom = number(mark['y']) + number(line['bottom']);
        if (cuts.any((cut) => cut > top + 0.05 && cut < bottom - 0.05)) {
          throw StateError('Page break clips text: ${mark['text']}');
        }
      }
    }
    final pageStats = <J>[];
    final output = <ui.Picture>[];
    final backgrounds = <ui.Picture>[];
    for (var i = 0; i < cuts.length - 1; i++) {
      for (final textLayer in [true, false]) {
        paintText = textLayer;
        final rec = ui.PictureRecorder();
        final c = ui.Canvas(rec);
        final bg = map(layout['page']['background']);
        c.drawColor(color(bg['color']), ui.BlendMode.src);
        for (final draw in asset(
          bg['asset'],
          pageW,
          pageH,
          fit: bg['fit'],
        ).draws) {
          draw(c);
        }
        c.save();
        c.translate(number(pagePadding['left']), number(pagePadding['top']));
        c.save();
        c.clipRect(
          ui.Rect.fromLTWH(
            0,
            0,
            pageW - number(pagePadding['left']) - number(pagePadding['right']),
            contentH,
          ),
        );
        final decorationStats = <J>[];
        for (final d in flow.decorations) {
          final r = d['rect'] as ui.Rect;
          final start = cuts[i], end = cuts[i + 1];
          if (r.bottom <= start || r.top >= end) continue;
          final continuationAbove = r.top < start;
          final continuationBelow = r.bottom > end;
          final fragment = d['fragment'] == true;
          final top = math.max(0.0, r.top - start);
          final bottom = fragment && continuationBelow
              ? contentH
              : math.min(contentH, r.bottom - start);
          final rect = ui.Rect.fromLTRB(r.left, top, r.right, bottom);
          final radius = ui.Radius.circular(number(d['radius']));
          c.drawRRect(
            ui.RRect.fromRectAndCorners(
              rect,
              topLeft: continuationAbove ? ui.Radius.zero : radius,
              topRight: continuationAbove ? ui.Radius.zero : radius,
              bottomLeft: continuationBelow ? ui.Radius.zero : radius,
              bottomRight: continuationBelow ? ui.Radius.zero : radius,
            ),
            ui.Paint()..color = d['color'],
          );
          decorationStats.add({
            'top': top,
            'bottom': bottom,
            'continues': continuationBelow,
            'fragment': fragment,
          });
        }
        c.restore();
        c.clipRect(
          ui.Rect.fromLTWH(
            0,
            0,
            pageW - number(pagePadding['left']) - number(pagePadding['right']),
            cuts[i + 1] - cuts[i],
          ),
        );
        c.translate(0, -cuts[i]);
        for (final draw in flow.draws) {
          draw(c);
        }
        c.restore();
        (textLayer ? output : backgrounds).add(rec.endRecording());
        if (!textLayer) continue;
        pageStats.add({
          'page': i + 1,
          'decorations': decorationStats,
          'fromY': cuts[i],
          'toY': cuts[i + 1],
          'usedHeight': cuts[i + 1] - cuts[i],
          'sections': flow.markers
              .where(
                (m) =>
                    m['kind'] == 'section' &&
                    number(m['y']) >= cuts[i] - 0.01 &&
                    number(m['y']) < cuts[i + 1] - 0.01,
              )
              .map(
                (m) => {
                  ...m,
                  'x': number(m['x']) + number(pagePadding['left']),
                  'y': number(m['y']) - cuts[i] + number(pagePadding['top']),
                },
              )
              .toList(),
        });
      }
    }
    paintText = true;
    return NativeDocument(ui.Size(pageW, pageH), output, backgrounds, {
      'renderer': 'Flutter Canvas + TextPainter + SVG pictures; layout.json read at runtime',
      'layoutMs': layoutMs,
      'pages': pageStats,
      'flowHeight': flow.height,
      'warnings': warnings.toList(),
      'textRuns': flow.markers.where((m) => m['kind'] == 'text').toList(),
    });
  }

  void dispose() {
    for (final p in painters) {
      p.dispose();
    }
    for (final p in pictures.values) {
      p.picture.dispose();
    }
    for (final i in images.values) {
      i.dispose();
    }
  }
}

class NativeDocument {
  NativeDocument(this.size, this.pages, this.backgrounds, this.report);
  final ui.Size size;
  final List<ui.Picture> pages, backgrounds;
  final J report;
  void dispose() {
    for (final page in [...pages, ...backgrounds]) {
      page.dispose();
    }
  }
}

// Geometry and text are measured by the same TextPainter used for preview.
// Export backgrounds intentionally omit text so PDF text remains selectable.
List<J> exportTextLines(TextPainter painter, TextStyle base, double width) {
  final runs = <({int start, int end, TextStyle style})>[];
  var offset = 0;
  void visit(InlineSpan span, TextStyle inherited) {
    final style = inherited.merge(span.style);
    if (span is! TextSpan) {
      throw const FormatException('Unsupported inline content');
    }
    final text = span.text ?? '';
    if (text.isNotEmpty) {
      runs.add((start: offset, end: offset + text.length, style: style));
      offset += text.length;
    }
    for (final child in span.children ?? <InlineSpan>[]) {
      visit(child, style);
    }
  }

  visit(painter.text!, base);
  final plain = painter.text!.toPlainText();
  final result = <J>[];
  var start = 0;
  for (final line in painter.computeLineMetrics()) {
    final boundary = painter.getLineBoundary(TextPosition(offset: start));
    final end = boundary.end;
    final spans = <J>[];
    for (final run in runs) {
      final a = math.max(start, run.start), b = math.min(end, run.end);
      if (a >= b) continue;
      final boxes = painter.getBoxesForSelection(
        TextSelection(baseOffset: a, extentOffset: b),
      );
      final x = boxes.isEmpty ? line.left : boxes.first.left;
      final right = boxes.isEmpty ? x : boxes.last.right;
      final family = run.style.fontFamily ?? '';
      spans.add({
        'text': plain.substring(a, b).replaceAll('\n', ''),
        'x': x,
        'width': math.max(0.0, right - x),
        'size': run.style.fontSize ?? 12,
        'color': (run.style.color ?? const ui.Color(0xff262b27)).toARGB32(),
        'weight': family.endsWith('bold')
            ? 700
            : family.endsWith('medium')
            ? 500
            : 400,
        'italic': run.style.fontStyle == FontStyle.italic,
        'underline':
            run.style.decoration?.contains(TextDecoration.underline) == true,
        'strike':
            run.style.decoration?.contains(TextDecoration.lineThrough) == true,
      });
    }
    result.add({
      'top': line.baseline - line.ascent,
      'height': line.height,
      'baseline': line.baseline,
      'width': width,
      'spans': spans,
    });
    start = end;
    if (start < plain.length && plain.codeUnitAt(start) == 10) start++;
  }
  return result;
}

/// Strict version dispatch. Never silently interpret a newer layout as v1.
void validateNativeLayout(J layout) {
  if (layout['format'] != 'bojian-native-layout' ||
      layout['schemaVersion'] != '1.0') {
    throw const FormatException('模板布局版本不受支持，请升级 App');
  }
  final size = map(map(layout['page'])['size']);
  if (number(size['width']) != 794 || number(size['height']) != 1123) {
    throw const FormatException('原生模板须使用 A4 画布');
  }
  final nodes = <String>{
    'text',
    'svg',
    'image',
    'column',
    'row',
    'wrap',
    'richText',
    'sectionHeading',
    'section',
    'repeat',
    'gridRepeat',
    'intentionCell',
  };
  var count = 0;
  void walk(dynamic v, int depth) {
    if (depth > 32 || ++count > 12000) throw const FormatException('模板过于复杂');
    if (v is Map) {
      if (v['type'] != null &&
          !nodes.contains(v['type']) &&
          !['png', 'svg'].contains(v['type'])) {
        throw FormatException('模板组件不受支持：${v['type']}');
      }
      for (final child in v.values) {
        walk(child, depth + 1);
      }
    } else if (v is List) {
      for (final child in v) {
        walk(child, depth + 1);
      }
    } else if (v is num && (!v.isFinite || v.abs() > 10000)) {
      throw const FormatException('模板数值超出范围');
    }
  }

  walk(layout['sections'], 0);
  if (layout['sections'] is! List || (layout['sections'] as List).length != 8) {
    throw const FormatException('模板必须包含全部八个简历模块');
  }
}
