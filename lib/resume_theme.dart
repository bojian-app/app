import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Format identifier of downloadable theme packages for the native typesetter.
const resumeThemeFormat = 'bojian-theme-v1';

bool isResumeThemeSchema(Object? schema) =>
    schema is Map && schema['format'] == resumeThemeFormat;

// Cached template documents are immutable, so every view of one version
// shares a single decoded theme and its artwork.
final _themes = Expando<Future<ResumeTheme>>();

Future<ResumeTheme> resumeThemeOf(int templateID, Map schema) {
  return _themes[schema] ??=
      ResumeTheme.load(
        'template-$templateID',
        schema['theme'] as Map? ?? const {},
        {
          for (final entry
              in (schema['theme_assets'] as Map? ?? const {}).entries)
            '${entry.key}': base64Decode(entry.value as String),
        },
      ).catchError((Object error, StackTrace stack) {
        _themes[schema] = null;
        Error.throwWithStackTrace(error, stack);
      });
}

/// Package artwork, decoded once. Vector art stays vector so previews remain
/// sharp at any zoom and exports rasterize it at their own resolution.
class ResumeThemeGraphic {
  ResumeThemeGraphic._(this.image, this.picture, this.size);
  final ui.Image? image;
  final ui.Picture? picture;
  final Size size;

  static Future<ResumeThemeGraphic> decode(String path, Uint8List bytes) async {
    if (path.toLowerCase().endsWith('.svg')) {
      final info = await vg.loadPicture(SvgBytesLoader(bytes), null);
      return ResumeThemeGraphic._(null, info.picture, info.size);
    }
    final codec = await ui.instantiateImageCodec(bytes);
    try {
      final frame = await codec.getNextFrame();
      final image = frame.image;
      return ResumeThemeGraphic._(
        image,
        null,
        Size(image.width.toDouble(), image.height.toDouble()),
      );
    } finally {
      codec.dispose();
    }
  }

  void paint(Canvas canvas, Rect rect) {
    if (size.isEmpty || rect.isEmpty) return;
    if (image case final ui.Image image) {
      canvas.drawImageRect(
        image,
        Offset.zero & size,
        rect,
        Paint()..filterQuality = FilterQuality.medium,
      );
      return;
    }
    canvas.save();
    canvas.translate(rect.left, rect.top);
    canvas.scale(rect.width / size.width, rect.height / size.height);
    canvas.drawPicture(picture!);
    canvas.restore();
  }

  void dispose() {
    image?.dispose();
    picture?.dispose();
  }
}

class ResumeThemeText {
  const ResumeThemeText({
    required this.size,
    this.color,
    this.weight = 400,
    this.height,
    this.letterSpacing = 0,
  });
  final double size;
  final Color? color;
  final int weight;
  final double? height;
  final double letterSpacing;

  ResumeThemeText merge(Map? spec) => spec == null
      ? this
      : ResumeThemeText(
          size: _number(spec['size'], size),
          color: _color(spec['color'], color),
          weight: _number(spec['weight'], weight.toDouble()).round(),
          height: _number(spec['line_height'], height ?? 0) > 0
              ? _number(spec['line_height'], height ?? 0)
              : height,
          letterSpacing: _number(spec['letter_spacing'], letterSpacing),
        );
}

class ResumeThemeRule {
  const ResumeThemeRule(this.color, this.width);
  final Color color;
  final double width;

  static ResumeThemeRule? parse(Object? spec, ResumeThemeRule? fallback) {
    if (spec is! Map) return null;
    return ResumeThemeRule(
      _color(spec['color'], fallback?.color) ?? const Color(0xFFDFE5EE),
      _number(spec['width'], fallback?.width ?? .6),
    );
  }
}

/// Every visual choice of the native typesetter. [standard] reproduces the
/// built-in template; packages override values and pick component styles.
class ResumeTheme {
  ResumeTheme._({
    required this.id,
    required this.margin,
    required this.background,
    required this.pageNumbers,
    required this.body,
    required this.muted,
    required this.paragraphGap,
    required this.iconHeader,
    required this.name,
    required this.contact,
    required this.contactIconSize,
    required this.contactGap,
    required this.contactTop,
    required this.photoSize,
    required this.photoRadius,
    required this.photoInset,
    required this.headerMinHeight,
    required this.headerRule,
    required this.heading,
    required this.headingBefore,
    required this.headingAfter,
    required this.headingIconSize,
    required this.headingIconGap,
    required this.headingRule,
    required this.headingRuleDot,
    required this.headingBrushPadding,
    required this.titles,
    required this.entryIndent,
    required this.entryGap,
    required this.entryTitle,
    required this.entrySubtitle,
    required this.entryAuxiliary,
    required this.entryDates,
    required this.datesWithTitle,
    required this.entryDivider,
    required this.expectationCards,
    required this.expectationFill,
    required this.expectationRadius,
    required this.expectationPadding,
    required this.expectationIconSize,
    required this.expectationLabel,
    required this.expectationValue,
    required this.expectationDivider,
    required this.skillsCard,
    required this.skillsFill,
    required this.skillsRadius,
    required this.skillsPadding,
    required this.skillName,
    required this.skillGap,
    required this.certificationColumns,
    required this.certificationColumnGap,
    required this.certificationRowGap,
    required this.certificationTitle,
    this.backgroundImage,
    this.contactIcons = const {},
    this.headingIcons = const {},
    this.headingBrush,
    this.expectationIcons = const {},
    this.ornaments = const [],
    this.sidebar,
    this.datesFirst = false,
    this.dateColumn = 0,
    this.summaryFill = Colors.transparent,
    this.summaryRadius = 0,
    this.summaryPadding = EdgeInsets.zero,
    this.splitHeader = false,
    this.subtitle,
    this.headerDivider,
    this.contactFields = const ['phone', 'email', 'birth', 'gender'],
    this.contactLabels = const {},
    this.contactLineGap = 3,
    this.expectationInHeader = false,
    this.inlineSupporting = false,
    this.supportingSeparator = ' | ',
    this.skillTags = false,
    this.tagFill = Colors.transparent,
    this.tagRadius = 0,
    this.tagPadding = EdgeInsets.zero,
    this.tagGap = 0,
    this.tagText,
    this.headingSubtitles = const {},
    this.headingSubtitle,
    this.headingRuleBelow = false,
    this.summaryQuotes = const [],
    this.summaryQuoteSize = 0,
    this.photoRect,
    this.headingRuleOffset,
    this.monthSeparator = '/',
    this.dateSeparator = ' ~ ',
  });

  final String id;
  final EdgeInsets margin;
  final Color background;
  final ResumeThemeGraphic? backgroundImage;
  final bool pageNumbers;
  final ResumeThemeText body;
  final Color muted;
  final double paragraphGap;
  final bool iconHeader;
  final ResumeThemeText name, contact;
  final double contactIconSize, contactGap, contactTop;
  final Map<String, ResumeThemeGraphic> contactIcons;
  final Size photoSize;
  final double photoRadius, photoInset, headerMinHeight;
  final ResumeThemeRule? headerRule;
  final ResumeThemeText heading;
  final double headingBefore, headingAfter, headingIconSize, headingIconGap;
  final Map<String, ResumeThemeGraphic> headingIcons;
  final ResumeThemeGraphic? headingBrush;
  final EdgeInsets headingBrushPadding;
  final ResumeThemeRule? headingRule;
  final Color? headingRuleDot;
  final Map<String, String> titles;
  final double entryIndent, entryGap;
  final ResumeThemeText entryTitle, entrySubtitle, entryAuxiliary, entryDates;
  final bool datesWithTitle;
  final ResumeThemeRule? entryDivider;
  final bool expectationCards;
  final Color expectationFill;
  final double expectationRadius, expectationIconSize;
  final EdgeInsets expectationPadding;
  final ResumeThemeText expectationLabel, expectationValue;
  final Color expectationDivider;
  final Map<String, ResumeThemeGraphic> expectationIcons;
  final bool skillsCard;
  final Color skillsFill;
  final double skillsRadius, skillGap;
  final EdgeInsets skillsPadding;
  final ResumeThemeText skillName;
  final int certificationColumns;
  final double certificationColumnGap, certificationRowGap;
  final ResumeThemeText certificationTitle;

  /// Artwork placed at fixed page coordinates.
  final List<({ResumeThemeGraphic art, Rect rect, bool firstPage})> ornaments;

  /// A full-height column at the left edge holding the photo and short
  /// sections; the page margin keeps the main column clear of it.
  final ResumeThemeSidebar? sidebar;

  /// Entry dates lead the title row in a fixed-width column.
  final bool datesFirst;
  final double dateColumn;

  /// Card behind the self evaluation; transparent means none.
  final Color summaryFill;
  final double summaryRadius;
  final EdgeInsets summaryPadding;

  /// Name and the desired position on the left; labelled contact lines in a
  /// column beside the photo.
  final bool splitHeader;
  final ResumeThemeText? subtitle;
  final ResumeThemeRule? headerDivider;
  final List<String> contactFields;
  final Map<String, String> contactLabels;
  final double contactLineGap;

  /// The job expectation lives in the header instead of its own section.
  final bool expectationInHeader;

  /// Entry title and its supporting fields share one line.
  final bool inlineSupporting;
  final String supportingSeparator;

  /// Skill names as chips when no skill has a description.
  final bool skillTags;
  final Color tagFill;
  final double tagRadius, tagGap;
  final EdgeInsets tagPadding;
  final ResumeThemeText? tagText;

  /// Secondary heading text, such as an English title, beside each heading.
  final Map<String, String> headingSubtitles;
  final ResumeThemeText? headingSubtitle;

  /// The heading rule runs under the whole heading row instead of beside it.
  final bool headingRuleBelow;

  /// Opening and closing marks around the self evaluation.
  final List<ResumeThemeGraphic> summaryQuotes;
  final double summaryQuoteSize;

  /// Fixed photo box on the first page; null places it in the layout flow.
  final Rect? photoRect;

  /// Distance from the heading row to a rule below it.
  final double? headingRuleOffset;

  /// Dates read `2023/06 ~ 2024/01` by default.
  final String monthSeparator, dateSeparator;

  bool get isStandard => identical(this, standard);

  /// Clip outline of a photo occupying [rect]; [scale] converts the theme's
  /// corner radius to the caller's units.
  Path photoPath(Rect rect, [double scale = 1]) => Path()
    ..addRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(photoRadius * scale)),
    );

  String title(String section, String fallback) => titles[section] ?? fallback;

  static final standard = ResumeTheme._(
    id: 'standard',
    margin: const EdgeInsets.fromLTRB(46, 46, 46, 50),
    background: Colors.white,
    pageNumbers: true,
    body: const ResumeThemeText(size: 10.5, color: Color(0xFF26292E)),
    muted: const Color(0xFF555555),
    paragraphGap: 7,
    iconHeader: false,
    name: const ResumeThemeText(size: 25, weight: 600),
    contact: const ResumeThemeText(size: 10.5),
    contactIconSize: 0,
    contactGap: 0,
    contactTop: 0,
    photoSize: const Size(75, 90),
    photoRadius: 0,
    photoInset: 0,
    headerMinHeight: 65,
    headerRule: const ResumeThemeRule(Color(0xFF245EA8), 1.5),
    heading: const ResumeThemeText(
      size: 12,
      weight: 600,
      color: Color(0xFF245EA8),
    ),
    headingBefore: 14,
    headingAfter: 8,
    headingIconSize: 0,
    headingIconGap: 0,
    headingRule: null,
    headingRuleDot: null,
    headingBrushPadding: EdgeInsets.zero,
    titles: const {},
    entryIndent: 0,
    entryGap: 0,
    entryTitle: const ResumeThemeText(size: 13, weight: 600),
    entrySubtitle: const ResumeThemeText(size: 9.5, color: Color(0xFF555555)),
    entryAuxiliary: const ResumeThemeText(size: 9.5, color: Color(0xFF555555)),
    entryDates: const ResumeThemeText(size: 9.5, color: Color(0xFF555555)),
    datesWithTitle: false,
    entryDivider: const ResumeThemeRule(Color(0xFFDFE5EE), .6),
    expectationCards: false,
    expectationFill: Colors.transparent,
    expectationRadius: 0,
    expectationPadding: EdgeInsets.zero,
    expectationIconSize: 0,
    expectationLabel: const ResumeThemeText(size: 10.5),
    expectationValue: const ResumeThemeText(size: 10.5),
    expectationDivider: Colors.transparent,
    skillsCard: false,
    skillsFill: Colors.transparent,
    skillsRadius: 0,
    skillsPadding: EdgeInsets.zero,
    skillName: const ResumeThemeText(size: 10.5, weight: 600),
    skillGap: 0,
    certificationColumns: 1,
    certificationColumnGap: 0,
    certificationRowGap: 0,
    certificationTitle: const ResumeThemeText(size: 11, weight: 600),
  );

  /// Builds a theme from a validated package. [assets] holds the package's
  /// files by relative path; artwork missing from it is simply not drawn.
  static Future<ResumeTheme> load(
    String id,
    Map spec,
    Map<String, Uint8List> assets,
  ) async {
    final graphics = <String, ResumeThemeGraphic>{};
    Future<ResumeThemeGraphic?> graphic(Object? path) async {
      if (path is! String) return null;
      final cached = graphics[path];
      if (cached != null) return cached;
      final bytes = assets[path];
      if (bytes == null) return null;
      return graphics[path] = await ResumeThemeGraphic.decode(path, bytes);
    }

    Future<Map<String, ResumeThemeGraphic>> icons(Object? spec) async => {
      if (spec is Map)
        for (final entry in spec.entries)
          if (await graphic(entry.value) case final ResumeThemeGraphic icon)
            '${entry.key}': icon,
    };

    try {
      final s = ResumeTheme.standard;
      final page = _map(spec['page']);
      final text = _map(spec['text']);
      final header = _map(spec['header']);
      final contact = _map(header['contact']);
      final photo = _map(header['photo']);
      final heading = _map(spec['heading']);
      final entry = _map(spec['entry']);
      final expectation = _map(spec['job_expectation']);
      final skills = _map(spec['skills']);
      final certifications = _map(spec['certifications']);
      final sidebar = _map(spec['sidebar']);
      final summary = _map(spec['self_evaluation']);
      final body = s.body.merge(text);
      final ink = body.color!;
      final theme = ResumeTheme._(
        id: id,
        // With a sidebar the left margin is measured from its edge.
        margin: _insets(page['margin'], s.margin).copyWith(
          left:
              _insets(page['margin'], s.margin).left +
              (spec['sidebar'] is Map ? _number(sidebar['width'], 150) : 0),
        ),
        background: _color(page['background'], s.background)!,
        backgroundImage: await graphic(page['background_image']),
        pageNumbers: page['page_numbers'] is bool
            ? page['page_numbers'] as bool
            : s.pageNumbers,
        body: body,
        muted: _color(text['muted'], s.muted)!,
        paragraphGap: _number(text['paragraph_gap'], s.paragraphGap),
        iconHeader: header['style'] == 'icons',
        name: s.name.merge(_map(header['name'])),
        contact: ResumeThemeText(
          size: body.size,
          color: ink,
          height: body.height,
        ).merge(contact),
        contactIconSize: _number(contact['icon_size'], s.contactIconSize),
        contactGap: _number(contact['gap'], s.contactGap),
        contactTop: _number(contact['top'], s.contactTop),
        contactIcons: await icons(contact['icons']),
        photoSize: Size(
          _number(photo['width'], s.photoSize.width),
          _number(photo['height'], s.photoSize.height),
        ),
        photoRadius: _number(photo['radius'], s.photoRadius),
        photoInset: _number(photo['inset'], s.photoInset),
        headerMinHeight: _number(header['min_height'], s.headerMinHeight),
        headerRule: header.containsKey('rule')
            ? ResumeThemeRule.parse(header['rule'], s.headerRule)
            : s.headerRule,
        heading: s.heading.merge(_map(heading['text'])),
        headingBefore: _number(heading['before'], s.headingBefore),
        headingAfter: _number(heading['after'], s.headingAfter),
        headingIconSize: _number(heading['icon_size'], s.headingIconSize),
        headingIconGap: _number(heading['icon_gap'], s.headingIconGap),
        headingIcons: await icons(heading['icons']),
        headingBrush: await graphic(heading['brush']),
        headingRule: ResumeThemeRule.parse(heading['rule'], null),
        headingRuleDot: _color(heading['rule_dot'], null),
        headingBrushPadding: _insets(heading['brush_padding'], EdgeInsets.zero),
        titles: {
          for (final entry in _map(heading['titles']).entries)
            if (entry.value is String && (entry.value as String).isNotEmpty)
              '${entry.key}': entry.value as String,
        },
        entryIndent: _number(entry['indent'], s.entryIndent),
        entryGap: _number(entry['gap'], s.entryGap),
        entryTitle: s.entryTitle.merge(_map(entry['title'])),
        entrySubtitle: s.entrySubtitle.merge(_map(entry['subtitle'])),
        entryAuxiliary: s.entryAuxiliary.merge(_map(entry['auxiliary'])),
        entryDates: s.entryDates.merge(_map(entry['dates'])),
        datesWithTitle: entry['dates_with_title'] == true,
        entryDivider: entry.containsKey('divider')
            ? ResumeThemeRule.parse(entry['divider'], s.entryDivider)
            : s.entryDivider,
        expectationCards: expectation['style'] == 'cards',
        expectationFill: _color(expectation['fill'], s.expectationFill)!,
        expectationRadius: _number(expectation['radius'], 0),
        expectationPadding: _insets(expectation['padding'], EdgeInsets.zero),
        expectationIconSize: _number(expectation['icon_size'], 0),
        expectationLabel: body.merge(_map(expectation['label'])),
        expectationValue: body.merge(_map(expectation['value'])),
        expectationDivider: _color(expectation['divider'], Colors.transparent)!,
        expectationIcons: await icons(expectation['icons']),
        skillsCard: skills['style'] == 'card',
        skillsFill: _color(skills['fill'], s.skillsFill)!,
        skillsRadius: _number(skills['radius'], 0),
        skillsPadding: _insets(skills['padding'], EdgeInsets.zero),
        skillName: body
            .merge(const {'weight': 600})
            .merge(_map(skills['name'])),
        skillGap: _number(skills['gap'], 0),
        certificationColumns: _number(
          certifications['columns'],
          1,
        ).round().clamp(1, 3),
        certificationColumnGap: _number(certifications['column_gap'], 0),
        certificationRowGap: _number(certifications['row_gap'], 0),
        certificationTitle: s.certificationTitle.merge(
          _map(certifications['title']),
        ),
        sidebar: spec['sidebar'] is Map
            ? ResumeThemeSidebar(
                width: _number(sidebar['width'], 150),
                fill: _color(sidebar['fill'], ink)!,
                padding: _insets(sidebar['padding'], const EdgeInsets.all(18)),
                sections: [
                  for (final section
                      in sidebar['sections'] is List
                          ? sidebar['sections'] as List
                          : const ['contact'])
                    if (section is String) section,
                ],
                text: body.merge(_map(sidebar['text'])),
                muted: body
                    .merge(_map(sidebar['text']))
                    .merge(_map(sidebar['muted'])),
                heading: s.heading
                    .merge(_map(heading['text']))
                    .merge(_map(sidebar['heading'])),
                icons: await icons(sidebar['icons']),
                iconSize: _number(sidebar['icon_size'], 16),
                rule: ResumeThemeRule.parse(sidebar['rule'], null),
                ring: _color(sidebar['photo_ring'], null),
                ringWidth: _number(sidebar['photo_ring_width'], 3),
                sectionGap: _number(sidebar['section_gap'], 16),
                header: sidebar['header'] == true,
                ruleAbove: sidebar['rule_position'] == 'above',
                subtitle: s.name
                    .merge(const {'size': 10, 'weight': 400})
                    .merge(_map(sidebar['subtitle'])),
              )
            : null,
        datesFirst: entry['dates_position'] == 'start',
        dateColumn: _number(entry['date_column'], 96),
        summaryFill: _color(summary['fill'], Colors.transparent)!,
        summaryRadius: _number(summary['radius'], 0),
        summaryPadding: _insets(summary['padding'], EdgeInsets.zero),
        ornaments: [
          for (final item
              in page['ornaments'] is List
                  ? page['ornaments'] as List
                  : const [])
            if (item is Map && _rect(item['rect']) != null)
              if (await graphic(item['asset'])
                  case final ResumeThemeGraphic art)
                (
                  art: art,
                  rect: _rect(item['rect'])!,
                  firstPage: item['pages'] == 'first',
                ),
        ],
        splitHeader: header['style'] == 'split',
        subtitle: header['subtitle'] is Map
            ? s.name
                  .merge(const {'size': 13, 'weight': 500})
                  .merge(header['subtitle'] as Map)
            : null,
        headerDivider: ResumeThemeRule.parse(header['divider'], null),
        contactFields: contact['fields'] is List
            ? [
                for (final field in contact['fields'] as List)
                  if (field is String) field,
              ]
            : const ['phone', 'email', 'birth', 'gender'],
        contactLabels: {
          for (final entry in _map(contact['labels']).entries)
            if (entry.value is String) '${entry.key}': entry.value as String,
        },
        contactLineGap: _number(contact['line_gap'], 3),
        expectationInHeader: expectation['style'] == 'header',
        inlineSupporting: entry['inline_supporting'] == true,
        supportingSeparator: entry['separator'] is String
            ? entry['separator'] as String
            : ' | ',
        skillTags: skills['style'] == 'tags',
        tagFill: _color(_map(skills['tag'])['fill'], Colors.transparent)!,
        tagRadius: _number(_map(skills['tag'])['radius'], 0),
        tagPadding: _insets(_map(skills['tag'])['padding'], EdgeInsets.zero),
        tagGap: _number(_map(skills['tag'])['gap'], 0),
        tagText: skills['tag'] is Map
            ? body.merge(_map(_map(skills['tag'])['text']))
            : null,
        headingSubtitles: {
          for (final entry in _map(heading['subtitles']).entries)
            if (entry.value is String && (entry.value as String).isNotEmpty)
              '${entry.key}': entry.value as String,
        },
        headingSubtitle: heading['subtitle'] is Map
            ? s.heading
                  .merge(_map(heading['text']))
                  .merge(heading['subtitle'] as Map)
            : null,
        headingRuleBelow: heading['rule_position'] == 'below',
        summaryQuotes: [
          if (summary['quotes'] case final List quotes when quotes.length == 2)
            for (final quote in quotes)
              if (await graphic(quote) case final ResumeThemeGraphic mark) mark,
        ],
        summaryQuoteSize: _number(summary['quote_size'], 12),
        photoRect: _rect(photo['rect']),
        headingRuleOffset: heading['rule_offset'] is num
            ? _number(heading['rule_offset'], 0)
            : null,
        monthSeparator: entry['month_separator'] is String
            ? entry['month_separator'] as String
            : '/',
        dateSeparator: entry['date_separator'] is String
            ? entry['date_separator'] as String
            : ' ~ ',
      );
      return theme;
    } catch (_) {
      for (final graphic in graphics.values) {
        graphic.dispose();
      }
      rethrow;
    }
  }
}

Map _map(Object? value) => value is Map ? value : const {};

double _number(Object? value, double fallback) =>
    value is num && value.isFinite ? value.toDouble() : fallback;

/// `[left, top, width, height]` in points.
Rect? _rect(Object? value) {
  if (value is! List || value.length != 4 || value.any((v) => v is! num)) {
    return null;
  }
  final v = value.cast<num>().map((n) => n.toDouble()).toList();
  return Rect.fromLTWH(v[0], v[1], v[2], v[3]);
}

/// CSS order: `#RRGGBB` or `#RRGGBBAA`.
Color? _color(Object? value, Color? fallback) {
  if (value is! String) return fallback;
  final match = RegExp(r'^#([0-9a-fA-F]{6})([0-9a-fA-F]{2})?$')
      .firstMatch(value);
  if (match == null) return fallback;
  final alpha = match.group(2) ?? 'FF';
  return Color(int.parse('$alpha${match.group(1)}', radix: 16));
}

/// `[top, right, bottom, left]`, matching CSS shorthand order.
EdgeInsets _insets(Object? value, EdgeInsets fallback) {
  if (value is! List || value.length != 4 || value.any((v) => v is! num)) {
    return fallback;
  }
  final v = value.cast<num>().map((n) => n.toDouble()).toList();
  return EdgeInsets.fromLTRB(v[3], v[0], v[1], v[2]);
}

/// Non-text page artwork. Painted under the text and exported as one
/// background layer, so resume text always stays selectable and editable.
sealed class ResumeDecoration {
  const ResumeDecoration();
  void paint(Canvas canvas);

  /// Painted area, so exports can keep the artwork with nearby text.
  Rect get bounds;
}

class ResumeGraphicDecoration extends ResumeDecoration {
  const ResumeGraphicDecoration(this.graphic, this.rect);
  final ResumeThemeGraphic graphic;
  final Rect rect;
  @override
  void paint(Canvas canvas) => graphic.paint(canvas, rect);
  @override
  Rect get bounds => rect;
}

class ResumeFillDecoration extends ResumeDecoration {
  const ResumeFillDecoration(this.rect, this.color, this.radius);
  final Rect rect;
  final Color color;
  final double radius;
  @override
  Rect get bounds => rect;
  @override
  void paint(Canvas canvas) => canvas.drawRRect(
    RRect.fromRectAndRadius(rect, Radius.circular(radius)),
    Paint()..color = color,
  );
}

class ResumeLineDecoration extends ResumeDecoration {
  const ResumeLineDecoration(this.from, this.to, this.rule);
  final Offset from, to;
  final ResumeThemeRule rule;
  @override
  Rect get bounds => Rect.fromPoints(from, to).inflate(rule.width / 2);
  @override
  void paint(Canvas canvas) => canvas.drawLine(
    from,
    to,
    Paint()
      ..color = rule.color
      ..strokeWidth = rule.width,
  );
}

class ResumeDotDecoration extends ResumeDecoration {
  const ResumeDotDecoration(this.center, this.radius, this.color);
  final Offset center;
  final double radius;
  final Color color;
  @override
  Rect get bounds => Rect.fromCircle(center: center, radius: radius);
  @override
  void paint(Canvas canvas) =>
      canvas.drawCircle(center, radius, Paint()..color = color);
}

class ResumeThemeSidebar {
  const ResumeThemeSidebar({
    required this.width,
    required this.fill,
    required this.padding,
    required this.sections,
    required this.text,
    required this.muted,
    required this.heading,
    required this.icons,
    required this.iconSize,
    required this.rule,
    required this.ring,
    required this.ringWidth,
    required this.sectionGap,
    this.header = false,
    this.ruleAbove = false,
    required this.subtitle,
  });
  final double width, iconSize, ringWidth, sectionGap;

  /// The name and desired position open the sidebar, above the photo.
  final bool header;
  final ResumeThemeText subtitle;

  /// The rule separates sections instead of underlining their headings.
  final bool ruleAbove;

  final Color fill;
  final Color? ring;
  final EdgeInsets padding;

  /// Sidebar modules in order: contact, skills or certifications.
  final List<String> sections;
  final ResumeThemeText text, muted, heading;
  final Map<String, ResumeThemeGraphic> icons;
  final ResumeThemeRule? rule;
}

/// Clips a widget to a theme's photo outline.
class ResumePhotoClipper extends CustomClipper<Path> {
  const ResumePhotoClipper(this.theme, this.scale);
  final ResumeTheme theme;
  final double scale;
  @override
  Path getClip(Size size) => theme.photoPath(Offset.zero & size, scale);
  @override
  bool shouldReclip(ResumePhotoClipper oldClipper) =>
      oldClipper.theme != theme || oldClipper.scale != scale;
}
