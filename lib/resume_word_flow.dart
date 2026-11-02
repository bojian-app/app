part of 'resume_native_export.dart';

// Default and V2 marketplace templates use editable Word document flow. Source fields are
// block-level rich-text controls, so explicit paragraphs and page continuations
// remain in the same editing region. New blocks retain template page starts.
class _WordFlowParagraph {
  _WordFlowParagraph(this.page, ResumeExportLine line)
    : endPage = page,
      lines = [line];
  final int page;
  int endPage;
  final List<ResumeExportLine> lines;
  ResumeExportLine get first => lines.first;
  double get top => first.top;
  double get bottom =>
      lines.last.paragraphBottom ?? lines.last.top + lines.last.height;
  List<ResumeExportSpan> get spans => _mergeWordSpans(
    lines
        .expand((line) => line.spans)
        .where((s) => s.text.isNotEmpty && s.color >> 24 != 0)
        .toList(),
  );
  String? get field {
    final path = first.paragraphField;
    if (path == null) return null;
    if (path.endsWith(".body")) return path;
    final project = RegExp(
      r'^((?:projects|work_experiences|educations|skills)\.\d+)\.(description|achievements|campus_experience|thesis_title|thesis_description)$',
    ).firstMatch(path);
    if (project != null) return '${project[1]}.body';
    return RegExp(
          r'\.(description|preference|campus_experience|thesis_title|thesis_description)$',
        ).hasMatch(path)
        ? path
        : null;
  }
}

String _flowWord(
  ResumeExportLayout layout,
  List<String> pictures,
  bool hasMedium,
  String Function(ResumeExportRule, double) inlineRule,
) {
  final paragraphs = <String, _WordFlowParagraph>{};
  final events =
      <
        ({
          int page,
          double top,
          _WordFlowParagraph? paragraph,
          ResumeExportRule? rule,
        })
      >[];
  for (var page = 0; page < layout.pages.length; page++) {
    final sheet = layout.pages[page];
    for (final line in sheet.lines) {
      // Page numbers belong in a real footer; native content always has an ID.
      final key = line.paragraphId;
      if (key == null || line.spans.isEmpty) continue;
      final previous = paragraphs[key];
      if (previous != null) {
        previous.lines.add(line);
        previous.endPage = page;
      } else {
        final paragraph = _WordFlowParagraph(page, line);
        paragraphs[key] = paragraph;
        events.add((
          page: page,
          top: line.top,
          paragraph: paragraph,
          rule: null,
        ));
      }
    }
    for (final rule in sheet.rules) {
      if (rule.width <= 0 ||
          (rule.height <= 0 && rule.thickness <= 0) ||
          rule.color >> 24 == 0) {
        continue;
      }
      events.add((
        page: page,
        top:
            rule.y +
            (rule.height > 0 ? rule.height / 2 : 0) -
            _wordRuleHeight(rule) / 2,
        paragraph: null,
        rule: rule,
      ));
    }
  }
  events.sort((a, b) {
    final page = a.page.compareTo(b.page);
    if (page != 0) return page;
    final top = a.top.compareTo(b.top);
    if (top != 0) return top;
    return (a.paragraph?.first.paragraphLeft ?? 0).compareTo(
      b.paragraph?.first.paragraphLeft ?? 0,
    );
  });
  String font(ResumeExportSpan span) =>
      hasMedium && span.fontWeight >= 500 && span.fontWeight < 700
      ? resumeWordMediumTypeface
      : resumeWordRegularTypeface;
  String run(ResumeExportSpan span) {
    if (span.wordTabStop != null) return '<w:r><w:tab/></w:r>';
    final family = font(span), size = (span.size * 2).round();
    return '<w:r><w:rPr><w:rFonts w:ascii="$family" w:hAnsi="$family" w:eastAsia="$family" w:cs="$family"/>${span.fontWeight >= 700 ? '<w:b/><w:bCs/>' : ''}${span.italic ? '<w:i/><w:iCs/>' : ''}${span.strike ? '<w:strike/>' : ''}<w:color w:val="${_rgb(span.color)}"/><w:sz w:val="$size"/><w:szCs w:val="$size"/>${span.underline ? '<w:u w:val="single"/>' : ''}<w:lang w:val="en-US" w:eastAsia="zh-CN"/></w:rPr><w:t xml:space="preserve">${resumeExportText(span.text).split("\n").map(_xml).join('</w:t><w:br/><w:t xml:space="preserve">')}</w:t></w:r>';
  }

  final result = StringBuffer();
  String? currentField;
  var fieldId = 1000;
  void field(String? next) {
    if (currentField == next) return;
    if (currentField != null) result.write('</w:sdtContent></w:sdt>');
    currentField = next;
    if (next != null) {
      final label = next.startsWith('projects.')
          ? '项目正文'
          : next.startsWith('work_experiences.')
          ? '工作内容与成果'
          : '简历正文';
      result.write(
        '<w:sdt><w:sdtPr><w:alias w:val="$label"/><w:tag w:val="${_xml(next)}"/><w:id w:val="${fieldId++}"/><w:richText/></w:sdtPr><w:sdtContent>',
      );
    }
  }

  var previousPage = 0;
  var previousBottom = layout.wordMargins["top"]!;
  final picturesWritten = <int>{};
  String pagePictures(int page) =>
      picturesWritten.add(page) && page < pictures.length ? pictures[page] : "";
  for (var i = 0; i < events.length; i++) {
    final event = events[i];
    // A source paragraph may span pages and has already been merged above.
    // Only a new block after its endPage needs a template page boundary.
    final startsPage = event.page > previousPage;
    final before = math.max(
      0.0,
      event.top - (startsPage ? layout.wordMargins['top']! : previousBottom),
    );
    final pageBreak = startsPage ? '<w:pageBreakBefore/>' : '';
    final rule = event.rule;
    if (rule != null) {
      field(null);
      final height = _wordRuleHeight(rule);
      final left = rule.x - layout.wordMargins['left']!;
      final right =
          layout.width - layout.wordMargins['right']! - rule.x - rule.width;
      // Image-only paragraphs lose their spacing-before in some readers.
      // Carry the measured gap inside the transparent image, so its visible
      // line stays at the template position even when that spacing is ignored.
      result.write(
        '<w:p><w:pPr><w:keepNext/>$pageBreak<w:snapToGrid w:val="0"/><w:spacing w:before="0" w:after="0" w:line="${_twip(before + height)}" w:lineRule="exact"/><w:ind w:left="${_twip(left)}" w:right="${_twip(right)}"/><w:rPr><w:sz w:val="2"/><w:szCs w:val="2"/></w:rPr></w:pPr>${inlineRule(rule, before)}</w:p>',
      );
      previousPage = event.page;
      previousBottom = event.top + height;
      continue;
    }
    final paragraph = event.paragraph!;
    final spans = paragraph.spans;
    if (spans.isEmpty) continue;
    field(paragraph.field);
    final first = spans.first;
    final heading = paragraph.field == null && first.fontWeight >= 500;
    _WordFlowParagraph? right;
    if (i + 1 < events.length) {
      final candidate = events[i + 1].paragraph;
      if (candidate != null &&
          candidate.page == paragraph.page &&
          candidate.first.paragraphAlignRight &&
          (candidate.first.baseline - paragraph.first.baseline).abs() < .5) {
        right = candidate;
        i++;
      }
    }
    if (right != null) {
      // Page-break-before on a paragraph inside a table is not portable.
      // Use a small leading paragraph and account for its height in the gap.
      if (startsPage) {
        result.write(
          '<w:p><w:pPr><w:keepNext/>$pageBreak<w:spacing w:before="0" w:after="0" w:line="20" w:lineRule="exact"/><w:rPr><w:sz w:val="2"/></w:rPr></w:pPr></w:p>',
        );
      }
      final rowBefore = startsPage ? math.max(0.0, before - 1) : before;
      final total = _twip(
        layout.width -
            layout.wordMargins["left"]! -
            layout.wordMargins["right"]!,
      );
      final dateWidth = _twip(
        math.min(
          total / 20 * .5,
          math.max(135.0, (right.first.paragraphWidth ?? 0) + 12),
        ),
      );
      String cell(_WordFlowParagraph value, int width, bool alignRight) {
        final lead = value.spans.first;
        return '<w:tc><w:tcPr><w:tcW w:w="$width" w:type="dxa"/>${alignRight ? '' : '<w:tcMar><w:right w:w="240" w:type="dxa"/></w:tcMar>'}</w:tcPr><w:p><w:pPr><w:keepNext/><w:autoSpaceDE w:val="0"/><w:autoSpaceDN w:val="0"/><w:snapToGrid w:val="0"/><w:spacing w:before="${_twip(rowBefore)}" w:after="0" w:line="${_twip(value.first.height)}" w:lineRule="atLeast"/>${alignRight ? '<w:jc w:val="right"/>' : ''}<w:rPr><w:rFonts w:ascii="${font(lead)}" w:hAnsi="${font(lead)}" w:eastAsia="${font(lead)}"/><w:sz w:val="${(lead.size * 2).round()}"/></w:rPr></w:pPr>${alignRight ? '' : pagePictures(event.page)}${value.spans.map(run).join()}</w:p></w:tc>';
      }

      result.write(
        '<w:tbl><w:tblPr><w:tblW w:w="$total" w:type="dxa"/><w:tblInd w:w="0" w:type="dxa"/><w:tblBorders><w:top w:val="nil"/><w:left w:val="nil"/><w:bottom w:val="nil"/><w:right w:val="nil"/><w:insideH w:val="nil"/><w:insideV w:val="nil"/></w:tblBorders><w:tblLayout w:type="fixed"/><w:tblCellMar><w:top w:w="0" w:type="dxa"/><w:left w:w="0" w:type="dxa"/><w:bottom w:w="0" w:type="dxa"/><w:right w:w="0" w:type="dxa"/></w:tblCellMar></w:tblPr><w:tblGrid><w:gridCol w:w="${total - dateWidth}"/><w:gridCol w:w="$dateWidth"/></w:tblGrid><w:tr><w:trPr><w:cantSplit/></w:trPr>${cell(paragraph, total - dateWidth, false)}${cell(right, dateWidth, true)}</w:tr></w:tbl>',
      );
      previousPage = paragraph.endPage;
      previousBottom = math.max(paragraph.bottom, right.bottom);
      continue;
    }
    final stops = spans.where((s) => s.wordTabStop != null).toList()
      ..sort((a, b) => a.wordTabStop!.compareTo(b.wordTabStop!));
    final tabs = stops.isEmpty
        ? ''
        : '<w:tabs>${stops.map((s) => '<w:tab w:val="${s.wordTabRight ? 'right' : 'left'}" w:pos="${_twip(s.wordTabStop! - layout.wordMargins['left']!)}"/>').join()}</w:tabs>';
    final family = font(first), size = (first.size * 2).round();
    // Metadata p elements in HTML flex rows have intrinsic text widths.
    // Word must use the available column, allowing a different font metric.
    final contentWidth =
        layout.width -
        layout.wordMargins['left']! -
        layout.wordMargins['right']!;
    var rightInset = paragraph.field != null
        ? math.max(
            0.0,
            contentWidth - (paragraph.first.paragraphWidth ?? contentWidth),
          )
        : 0.0;
    if (paragraph.field == null && paragraph.page == 0) {
      for (final picture in layout.pages.first.pictures) {
        if (picture.x > layout.width / 2 &&
            paragraph.top < picture.y + picture.height &&
            paragraph.bottom > picture.y) {
          rightInset = math.max(
            rightInset,
            layout.width - layout.wordMargins['right']! - picture.x + 12,
          );
        }
      }
    }
    final leftInset = layout.nativeFlowGeometry
        ? math.max(
            0.0,
            (paragraph.first.paragraphLeft ?? layout.wordMargins['left']!) -
                layout.wordMargins['left']!,
          )
        : 0.0;
    result.write(
      '<w:p><w:pPr>${heading ? '<w:keepNext/>' : ''}$pageBreak$tabs<w:widowControl/><w:autoSpaceDE w:val="0"/><w:autoSpaceDN w:val="0"/><w:snapToGrid w:val="0"/><w:spacing w:before="${_twip(before)}" w:after="0" w:line="${_twip(paragraph.first.height)}" w:lineRule="atLeast"/>${rightInset > .1 || leftInset > .1 ? '<w:ind w:left="${_twip(leftInset)}" w:right="${_twip(rightInset)}"/>' : ''}${paragraph.first.paragraphAlignRight ? '<w:jc w:val="right"/>' : ''}<w:rPr><w:rFonts w:ascii="$family" w:hAnsi="$family" w:eastAsia="$family" w:cs="$family"/><w:sz w:val="$size"/></w:rPr></w:pPr>',
    );
    result.write(pagePictures(event.page));
    for (final span in spans) {
      result.write(run(span));
    }
    result.write('</w:p>');
    previousPage = paragraph.endPage;
    previousBottom = paragraph.bottom;
  }
  field(null);
  return result.toString();
}
