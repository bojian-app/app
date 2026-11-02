part of 'resume_native_export.dart';

// Declarative templates become ordinary Word paragraphs, tables and field
// content controls. No template names, line frames or screenshot coordinates.
class _StructuredWord {
  _StructuredWord(this.model, this.picture, this.measure);
  final double Function(String, Map) measure;
  final Map<String, dynamic> model;
  final String Function(
    String asset,
    double width,
    double height, {
    bool behindParagraph,
  })
  picture;
  int control = 4000;
  Map<String, dynamic> m(dynamic v) =>
      v is Map ? Map<String, dynamic>.from(v) : {};
  double n(dynamic v, [double fallback = 0]) =>
      v is num ? v.toDouble() : fallback;
  late final Map<String, dynamic> layout = m(model['layout']);
  late final Map<String, dynamic> fields = m(model['fields']);
  String richPlain(dynamic v) => (m(v)['blocks'] as List? ?? [])
      .map(
        (b) => (m(b)['spans'] as List? ?? [])
            .map((s) => m(s)['text'] ?? '')
            .join(),
      )
      .join('\n');
  bool meaningful(dynamic v) => v is String
      ? v.trim().isNotEmpty
      : v is List
      ? v.any(meaningful)
      : v is Map
      ? (v.containsKey('blocks')
            ? richPlain(v).trim().isNotEmpty
            : v.values.any(meaningful))
      : v != null;
  dynamic resolve(dynamic key, Map item) {
    if (key == '\$media.photo') {
      return model['images'] is Map &&
              (model['images'] as Map).containsKey('photo')
          ? 'photo'
          : null;
    }
    if (key is! String) return null;
    if (key.startsWith('\$resume.')) return fields[key.substring(8)];
    if (key.startsWith('\$item.')) return item[key.substring(6)];
    return null;
  }

  String value(Map node, Map item) {
    if (node['format'] == 'dateRange') {
      final args = m(node['bindings']);
      final a = '${resolve(args['start'], item) ?? ''}'.trim(),
          b = '${resolve(args['end'], item) ?? ''}'.trim();
      return a.isNotEmpty && b.isNotEmpty && a != b
          ? '$a — $b'
          : a.isNotEmpty
          ? a
          : b;
    }
    return '${node['text'] ?? resolve(node['binding'], item) ?? ''}';
  }

  Map<String, dynamic> style(dynamic key) => m(m(layout['textStyles'])[key]);
  String run(String text, Map style, [Map span = const {}]) {
    final weight = n(style['fontWeight'], 400);
    final family = weight >= 500 && weight < 700
        ? resumeWordMediumTypeface
        : resumeWordRegularTypeface;
    final size = (n(style['fontSizePt'], 8.5) * 2).round();
    final color = '${style['color'] ?? '#262B27'}'.replaceFirst('#', '');
    return '<w:r><w:rPr><w:rFonts w:ascii="${_xml(family)}" w:hAnsi="${_xml(family)}" w:eastAsia="${_xml(family)}"/>'
        '${span['bold'] == true || weight >= 700 ? '<w:b/>' : ''}${span['italic'] == true ? '<w:i/>' : ''}${span['underline'] == true ? '<w:u w:val="single"/>' : ''}${span['strikethrough'] == true ? '<w:strike/>' : ''}'
        '<w:spacing w:val="${_twip(n(style['letterSpacing']) * .75)}"/><w:color w:val="$color"/><w:sz w:val="$size"/><w:szCs w:val="$size"/></w:rPr><w:t xml:space="preserve">${_xml(text).replaceAll('\n', '</w:t><w:br/><w:t xml:space="preserve">')}</w:t></w:r>';
  }

  String paragraph(
    String runs,
    Map style, {
    double before = 0,
    double after = 0,
    bool keep = false,
    String align = 'left',
  }) =>
      '<w:p><w:pPr>${keep ? '<w:keepNext/>' : ''}<w:widowControl/><w:jc w:val="$align"/><w:autoSpaceDE w:val="0"/><w:autoSpaceDN w:val="0"/><w:snapToGrid w:val="0"/>'
      '<w:spacing w:before="${_twip(before * .75)}" w:after="${_twip(after * .75)}" w:line="${_twip(n(style['fontSizePt'], 8.5) * n(style['lineHeight'], 1.5))}" w:lineRule="atLeast"/><w:rPr><w:rFonts w:ascii="$resumeWordRegularTypeface" w:hAnsi="$resumeWordRegularTypeface" w:eastAsia="$resumeWordRegularTypeface"/><w:sz w:val="${(n(style['fontSizePt'], 8.5) * 2).round()}"/></w:rPr></w:pPr>$runs</w:p>';
  String empty() =>
      '<w:p><w:pPr><w:spacing w:before="0" w:after="0" w:line="1" w:lineRule="exact"/><w:rPr><w:sz w:val="2"/></w:rPr></w:pPr></w:p>';
  String spacer(double height) =>
      '<w:p><w:pPr><w:keepNext/><w:spacing w:before="0" w:after="0" w:line="${_twip(height * .75)}" w:lineRule="exact"/><w:rPr><w:sz w:val="2"/></w:rPr></w:pPr></w:p>';
  String field(String key, String content) =>
      '<w:sdt><w:sdtPr><w:alias w:val="简历字段"/><w:tag w:val="${_xml(key)}"/><w:id w:val="${control++}"/><w:richText/></w:sdtPr><w:sdtContent>$content</w:sdtContent></w:sdt>';
  String table(
    List<String> cells,
    List<double> widths, {
    Map padding = const {},
    String? fill,
    double indent = 0,
  }) {
    final total = widths.fold<double>(0, (a, b) => a + b);
    return '<w:tbl><w:tblPr><w:tblW w:w="${_twip(total * .75)}" w:type="dxa"/><w:tblInd w:w="${_twip((indent + n(padding['left'])) * .75)}" w:type="dxa"/>'
        '<w:tblBorders>${['top', 'left', 'bottom', 'right', 'insideH', 'insideV'].map((k) => '<w:$k w:val="nil"/>').join()}</w:tblBorders><w:tblLayout w:type="fixed"/><w:tblCellMar>'
        '${['top', 'left', 'bottom', 'right'].map((k) => '<w:$k w:w="${_twip(n(padding[k]) * .75)}" w:type="dxa"/>').join()}'
        '</w:tblCellMar></w:tblPr><w:tblGrid>'
        '${widths.map((w) => '<w:gridCol w:w="${_twip(w * .75)}"/>').join()}</w:tblGrid><w:tr>'
        '${List.generate(cells.length, (i) => '<w:tc><w:tcPr><w:tcW w:w="${_twip(widths[i] * .75)}" w:type="dxa"/>${fill == null ? '' : '<w:shd w:fill="$fill"/>'}<w:tcMar>${['top', 'left', 'bottom', 'right'].map((k) => '<w:$k w:w="${_twip(n(padding[k]) * .75)}" w:type="dxa"/>').join()}</w:tcMar><w:vAlign w:val="top"/></w:tcPr>${cells[i]}${empty()}</w:tc>').join()}'
        '</w:tr></w:tbl>${empty()}';
  }

  // Flowing blocks use paragraph indents, not one-cell wrapper tables. Some
  // mobile readers paginate nested tables as oversized indivisible rows.
  String insetFlow(String content, double left, double right) {
    if (left == 0 && right == 0) return content;
    final root = ox.XmlDocument.parse('<root>$content</root>').rootElement;
    ox.XmlElement ensure(ox.XmlElement parent, String name) {
      final existing = parent.childElements
          .where((e) => e.name.qualified == name)
          .firstOrNull;
      if (existing != null) return existing;
      final value = ox.XmlElement(ox.XmlName.qualified(name));
      parent.children.insert(0, value);
      return value;
    }

    void add(ox.XmlElement node, String key, double value) {
      node.setAttribute(
        key,
        '${(int.tryParse(node.getAttribute(key) ?? '') ?? 0) + _twip(value * .75)}',
      );
    }

    void visit(ox.XmlElement parent) {
      for (final node in parent.childElements) {
        switch (node.name.qualified) {
          case 'w:p':
            final indent = ensure(ensure(node, 'w:pPr'), 'w:ind');
            add(indent, 'w:left', left);
            add(indent, 'w:right', right);
          case 'w:tbl':
            final indent = ensure(ensure(node, 'w:tblPr'), 'w:tblInd');
            add(indent, 'w:w', left);
            indent.setAttribute('w:type', 'dxa');
          case 'w:sdt':
            for (final body in node.childElements.where(
              (e) => e.name.qualified == 'w:sdtContent',
            )) {
              visit(body);
            }
        }
      }
    }

    visit(root);
    return root.children.map((e) => e.toXmlString()).join();
  }

  double preferred(Map node, double width, Map item) {
    final l = m(node['layout']);
    if (l['basisFraction'] != null) return width * n(l['basisFraction']);
    if (node['width'] != null) return n(node['width']);
    if (node['type'] == 'column' &&
        (node['children'] as List? ?? []).length == 1) {
      return preferred(m((node['children'] as List).first), width, item);
    }
    if (node['type'] == 'text') {
      return math.min(
        width,
        measure(value(node, item), style(node['textStyle'])) * 1.25 + 8,
      );
    }
    final children = (node['children'] as List? ?? []).map(m).toList();
    if (children.isNotEmpty) {
      final sizes = children.map((c) => preferred(c, width, item)).toList();
      final content = node['type'] == 'row' || node['type'] == 'wrap'
          ? sizes.fold<double>(0, (a, b) => a + b) +
                n(node['gap']) * (sizes.length - 1)
          : sizes.reduce(math.max);
      final pad = m(node['padding']), margin = m(node['margin']);
      return math.min(
        width,
        content +
            n(pad['left']) +
            n(pad['right']) +
            n(margin['left']) +
            n(margin['right']),
      );
    }
    return width / 2;
  }

  String emit(
    Map node,
    double width,
    Map item,
    String scope, {
    bool decorated = true,
  }) {
    final condition = m(node['visibleWhen'])['nonEmpty'];
    if (condition != null && !meaningful(resolve(condition, item))) return '';
    final margin = m(node['margin']), pad = m(node['padding']);
    final inner = math.max(
      1.0,
      width -
          n(margin['left']) -
          n(margin['right']) -
          n(pad['left']) -
          n(pad['right']),
    );
    final st = style(node['textStyle']);
    String result;
    switch (node['type']) {
      case 'text':
        final text = value(node, item);
        if (text.trim().isEmpty) return '';
        result = paragraph(
          run(text, st),
          st,
          before: n(margin['top']),
          after: n(margin['bottom']),
          keep:
              node['pagination'] is Map &&
              m(node['pagination'])['keepWithNext'] == true,
          align: node['format'] == 'dateRange' ? 'right' : 'left',
        );
      case 'image':
      case 'svg':
        final id = node['asset'] ?? resolve(node['binding'], item);
        if (id == null) return '';
        result = paragraph(
          picture(
            '$id',
            n(node['width'], 100) * .75,
            n(node['height'], 100) * .75,
          ),
          st,
        );
      case 'richText':
        final rich = m(resolve(node['binding'], item));
        final fallback = '${resolve(node['fallbackTextBinding'], item) ?? ''}';
        final blocks = richPlain(rich).trim().isNotEmpty
            ? (rich['blocks'] as List).map(m).toList()
            : fallback.trim().isEmpty
            ? <Map<String, dynamic>>[]
            : fallback
                  .split('\n')
                  .map(
                    (s) => <String, dynamic>{
                      'kind': 'paragraph',
                      'spans': [
                        {'text': s},
                      ],
                    },
                  )
                  .toList();
        if (blocks.isEmpty) return '';
        var count = 0;
        final out = StringBuffer();
        for (final block in blocks) {
          final kind = block['kind'];
          if (kind != 'numbered') count = 0;
          final prefix = kind == 'bullet'
              ? '• '
              : kind == 'numbered'
              ? '${++count}. '
              : '';
          final spans = (block['spans'] as List? ?? []).map(m);
          out.write(
            paragraph(
              run(prefix, st) +
                  spans.map((s) => run('${s['text'] ?? ''}', st, s)).join(),
              st,
              after: n(
                kind == 'paragraph'
                    ? node['paragraphGap']
                    : node['listItemGap'],
              ),
            ),
          );
        }
        result = field('$scope.${node['fallbackTextBinding']}', out.toString());
      case 'column':
        final children = (node['children'] as List? ?? []).map(m).toList();
        result = List.generate(children.length, (index) {
          final child = children[index];
          return emit(
            {
              ...child,
              if (child['type'] == 'text' && index + 1 < children.length)
                'pagination': {...m(child['pagination']), 'keepWithNext': true},
            },
            inner,
            item,
            scope,
          );
        }).join();
      case 'row':
      case 'wrap':
        final children = (node['children'] as List? ?? [])
            .map(m)
            .where(
              (c) =>
                  m(c['visibleWhen'])['nonEmpty'] == null ||
                  meaningful(resolve(m(c['visibleWhen'])['nonEmpty'], item)),
            )
            .where(
              (c) => c['type'] != 'text' || value(c, item).trim().isNotEmpty,
            )
            .toList();
        if (children.isEmpty) return '';
        final gap = n(node['gap']),
            available = math.max(1.0, inner - gap * (children.length - 1));
        final grow = children.fold<double>(
          0,
          (v, c) => v + n(m(c['layout'])['grow']),
        );
        final allBasis = children.every(
          (c) => m(c['layout'])['basisFraction'] != null,
        );
        var widths = children
            .map((c) => preferred(c, available, item))
            .toList();
        if (node['type'] == 'wrap' &&
            grow == 0 &&
            !allBasis &&
            widths.fold<double>(0, (a, b) => a + b) > available) {
          final lines = <List<Map<String, dynamic>>>[];
          var line = <Map<String, dynamic>>[];
          var used = 0.0;
          for (var i = 0; i < children.length; i++) {
            final next = widths[i] + (line.isEmpty ? 0 : gap);
            if (line.isNotEmpty && used + next > inner) {
              lines.add(line);
              line = [];
              used = 0;
            }
            used += widths[i] + (line.isEmpty ? 0 : gap);
            line.add(children[i]);
          }
          if (line.isNotEmpty) lines.add(line);
          result = lines
              .map(
                (line) => emit(
                  {'type': 'row', 'children': line, 'gap': gap},
                  inner,
                  item,
                  scope,
                ),
              )
              .join(n(node['runGap']) > 0 ? spacer(n(node['runGap'])) : '');
          break;
        }
        // A missing optional column can leave only flex-basis: 0 children.
        // Distribute their grow weights instead of normalizing a zero total.
        final basisTotal = widths.fold<double>(0, (a, b) => a + b);
        if (allBasis && basisTotal > 0) {
          widths = widths.map((w) => available * w / basisTotal).toList();
        } else if (grow > 0) {
          final fixed = List.generate(
            children.length,
            (i) => n(m(children[i]['layout'])['grow']) == 0 ? widths[i] : 0.0,
          ).fold<double>(0, (a, b) => a + b);
          for (var i = 0; i < children.length; i++) {
            final g = n(m(children[i]['layout'])['grow']);
            if (g > 0) widths[i] = math.max(1, (available - fixed) * g / grow);
          }
        } else {
          final sum = widths.fold<double>(0, (a, b) => a + b);
          if (sum == 0) {
            widths = List.filled(children.length, available / children.length);
          } else if (sum > available) {
            widths = widths.map((w) => available * w / sum).toList();
          }
        }
        final cells = <String>[], cols = <double>[];
        for (var i = 0; i < children.length; i++) {
          if (i > 0 && gap > 0) {
            cells.add(empty());
            cols.add(gap);
          }
          cells.add(emit(children[i], widths[i], item, scope));
          cols.add(widths[i]);
        }
        result = table(cells, cols);
      case 'repeat':
      case 'gridRepeat':
        final rows = (resolve(node['binding'], item) as List? ?? [])
            .map(m)
            .toList();
        final out = StringBuffer();
        if (node['type'] == 'gridRepeat') {
          final weights = (node['columnWeights'] as List)
              .map((v) => n(v))
              .toList();
          final sum = weights.fold<double>(0, (a, b) => a + b);
          final gap = n(node['columnGap']);
          for (var i = 0; i < rows.length; i += weights.length) {
            final cells = <String>[], cols = <double>[];
            for (var j = 0; j < weights.length; j++) {
              if (j > 0) {
                cells.add(empty());
                cols.add(gap);
              }
              final w = (inner - gap * (weights.length - 1)) * weights[j] / sum;
              cols.add(w);
              cells.add(
                i + j < rows.length
                    ? emit(
                        m(node['item']),
                        w,
                        rows[i + j],
                        '${node['binding']}.${i + j}',
                      )
                    : empty(),
              );
            }
            out.write(table(cells, cols));
          }
        } else {
          for (var i = 0; i < rows.length; i++) {
            out.write(
              emit(m(node['item']), inner, rows[i], '${node['binding']}.$i'),
            );
            if (i + 1 < rows.length && n(node['itemGap']) > 0) {
              out.write(spacer(n(node['itemGap'])));
            }
          }
        }
        result = out.toString();
      case 'section':
        result =
            emit(m(node['heading']), inner, item, scope) +
            emit(m(node['content']), inner, item, scope);
      case 'sectionHeading':
        final d = m(m(layout['decorations'])[node['decoration']]);
        final titleStyle = style(d['textStyle']);
        final key =
            '${node['iconAsset']}|${node['decoration']}|${node['text']}';
        final art = m(m(model['headingArt'])[key]);
        if (art.isEmpty) throw const ApiFailure('模板标题装饰缺失');
        final indent = n(art['indent']) * .75;
        final height = n(art['height']) * inner / n(art['width']);
        result =
            '<w:p><w:pPr><w:keepNext/><w:snapToGrid w:val="0"/><w:tabs><w:tab w:val="left" w:pos="${_twip(indent)}"/></w:tabs><w:spacing w:before="0" w:after="0" w:line="${_twip(height * .75)}" w:lineRule="atLeast"/></w:pPr>'
            '${picture('${art['asset']}', inner * .75, height * .75, behindParagraph: true)}<w:r><w:tab/></w:r>${run('${node['text']}', titleStyle)}</w:p>';
      case 'intentionCell':
        final v = m(node['value']),
            icon = m(node['icon']),
            label = m(node['label']);
        final iconWidth = n(icon['columnWidth']) + n(node['columnGap']);
        result = table(
          [
            paragraph(
              picture(
                '${icon['asset']}',
                n(icon['width']) * .75,
                n(icon['height']) * .75,
              ),
              st,
            ),
            paragraph(
                  run('${label['text']}', style(label['textStyle'])),
                  style(label['textStyle']),
                  after: n(node['rowGap']),
                ) +
                emit(v, inner - iconWidth, item, scope),
          ],
          [iconWidth, math.max(1, inner - iconWidth)],
        );
      default:
        throw const ApiFailure('模板包含未支持的 Word 布局组件');
    }
    if (result.isEmpty) return '';
    if (decorated &&
        (node['background'] != null ||
            pad.isNotEmpty ||
            n(margin['left']) > 0 ||
            n(margin['right']) > 0)) {
      final bg = m(node['background']);
      String? fill;
      if (bg['color'] is String) {
        final color = int.parse(
          (bg['color'] as String).substring(1),
          radix: 16,
        );
        final alpha = n(bg['opacity'], 1);
        fill = [16, 8, 0]
            .map(
              (shift) => (((color >> shift) & 255) * alpha + 255 * (1 - alpha))
                  .round()
                  .toRadixString(16)
                  .padLeft(2, '0'),
            )
            .join();
      }
      // Margin is outside the painted box. A spacer cell would inherit the
      // panel's shading and padding and shift the content in Word readers.
      if (fill == null) {
        result = insetFlow(
          result,
          n(margin['left']) + n(pad['left']),
          n(margin['right']) + n(pad['right']),
        );
        if (n(pad['top']) > 0) result = spacer(n(pad['top'])) + result;
        if (n(pad['bottom']) > 0) result += spacer(n(pad['bottom']));
      } else {
        result = table(
          [result],
          [width - n(margin['left']) - n(margin['right'])],
          padding: pad,
          fill: fill,
          indent: n(margin['left']),
        );
      }
    }
    if (node['type'] != 'text' && n(margin['top']) > 0) {
      result = spacer(n(margin['top'])) + result;
    }
    if (node['type'] != 'text' && n(margin['bottom']) > 0) {
      result += spacer(n(margin['bottom']));
    }
    return result;
  }

  String build() {
    final pad = m(m(layout['page'])['contentPadding']);
    final width =
        n(m(m(layout['page'])['size'])['width'], 794) -
        n(pad['left']) -
        n(pad['right']);
    return (model['sections'] as List)
        .map((s) => emit(m(s), width, {}, 'resume'))
        .join();
  }
}
