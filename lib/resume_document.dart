import 'resume_module_order.dart';
import 'resume_photo_image.dart';
import 'resume_preview_trace.dart';
import 'resume_system_fonts.dart';

import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'design.dart' show appPageHorizontalPadding;

import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/physics.dart';

import 'app_store.dart';
import 'guidance_help.dart';
import 'resume_templates.dart';
import 'resume_theme.dart';
import 'resume_native_export.dart';
import 'resume_additional_fields.dart';
import 'resume_work_experience.dart';
import 'api/bojian_api.dart';
import 'resume_guidance_privacy.dart';

// Point dimensions and typography mirror the macOS standard PDF template.
/// The paper keeps the same side gutters as every other page.
const resumeSheetInset = appPageHorizontalPadding * 2;

const resumePaperSize = Size(595.28, 841.89);
const resumePaperMargin = 46.0;
const resumePaperInk = Color(0xFF26292E);

class ResumeInk {
  ResumeInk(
    this.text,
    this.position,
    this.height, {
    this.sourceTop = 0,
    this.fieldPath,
    this.wordLeft,
    this.wordWidth,
    this.wordAlignRight = false,
  });
  final String? fieldPath;
  final TextPainter text;
  final Offset position;
  final double height;
  final double sourceTop;
  final double? wordLeft, wordWidth;
  final bool wordAlignRight;
  bool get privacyMasked =>
      text.text!.toPlainText().contains(resumePrivacyMask) &&
      (fieldPath == null ||
          RegExp(
            r'^(personal_info\.|educations\.\d+\.institution$|work_experiences\.\d+\.company$|certifications\.\d+\.issuer$)',
          ).hasMatch(fieldPath!));
  String get visibleText {
    final value = text.text!.toPlainText();
    final start = text.getPositionForOffset(Offset(0, sourceTop)).offset;
    final end = text
        .getPositionForOffset(Offset(text.width, sourceTop + height - .001))
        .offset;
    final visible = value.substring(start, end);
    return privacyMasked
        ? visible.replaceAll(resumePrivacyMask, '隐私信息已隐藏')
        : visible;
  }
}

class ResumeSheet {
  final ink = <ResumeInk>[];
  final decorations = <ResumeDecoration>[];
  final entryDividers = <double>[];
  final reviewNotes = <ResumeReviewPlacement>[];
  double? dividerY;
  Rect? photo;
}

class ResumeReviewChange {
  const ResumeReviewChange({
    required this.key,
    required this.fieldPath,
    required this.original,
    required this.replacement,
    this.accepted = false,
    this.appendReplacement = true,
    this.previewOnly = false,
  });
  final String key, fieldPath, original, replacement;
  final bool accepted, appendReplacement, previewOnly;
}

// Slice styled text without losing existing rich-text runs.
InlineSpan _reviewSlice(
  InlineSpan root,
  int start,
  int end, {
  bool strike = false,
}) {
  var offset = 0;
  final pieces = <InlineSpan>[];
  void visit(InlineSpan span, TextStyle inherited) {
    if (span is! TextSpan) return;
    final style = inherited.merge(span.style);
    final value = span.text ?? '';
    final left = math.max(0, start - offset);
    final right = math.min(value.length, end - offset);
    if (left < right) {
      pieces.add(
        TextSpan(
          text: value.substring(left, right),
          style: strike
              ? style.copyWith(
                  color: const Color(0xFF89909D),
                  decoration: TextDecoration.combine([
                    if (style.decoration != null) style.decoration!,
                    TextDecoration.lineThrough,
                  ]),
                )
              : style,
        ),
      );
    }
    offset += value.length;
    for (final child in span.children ?? <InlineSpan>[]) {
      visit(child, style);
    }
  }

  visit(root, const TextStyle());
  return TextSpan(children: pieces);
}

InlineSpan resumeReviewComparison(InlineSpan text, ResumeReviewChange change) {
  var value = text.toPlainText();
  var start = value.indexOf(change.original);
  if (change.previewOnly && start >= 0) {
    final selected =
        _reviewSlice(text, start, start + change.original.length) as TextSpan;
    final style = selected.children?.firstOrNull?.style;
    return TextSpan(
      children: [
        _reviewSlice(text, 0, start),
        TextSpan(text: change.replacement, style: style),
        _reviewSlice(text, start + change.original.length, value.length),
      ],
    );
  }
  if (change.accepted && value.contains(change.replacement)) {
    final replacementStart = value.indexOf(change.replacement);
    text = TextSpan(
      style: text.style,
      children: [
        _reviewSlice(text, 0, replacementStart),
        TextSpan(text: change.original),
        _reviewSlice(
          text,
          replacementStart + change.replacement.length,
          value.length,
        ),
      ],
    );
    value = text.toPlainText();
    start = value.indexOf(change.original, replacementStart);
  }
  if (start < 0 || change.original.isEmpty) return text;
  return TextSpan(
    style: text.style,
    children: [
      _reviewSlice(text, 0, start),
      _reviewSlice(text, start, start + change.original.length, strike: true),
      _reviewSlice(text, start + change.original.length, value.length),
      if (change.appendReplacement)
        TextSpan(
          text: '\n${change.replacement}',
          style: const TextStyle(color: Color(0xFF7964A4)),
        ),
    ],
  );
}

class ResumeReviewNote {
  const ResumeReviewNote({
    required this.key,
    required this.fieldPath,
    required this.height,
    this.selectedText = '',
  });
  final String key, fieldPath;
  final double height;
  final String selectedText;
}

class ResumeReviewPlacement {
  const ResumeReviewPlacement(this.note, this.rect);
  final ResumeReviewNote note;
  final Rect rect;
}

class ResumeDocument {
  ResumeDocument(
    ResumeDraft resume, {
    // Null is the device's system font; exports pass the bundled family.
    this.fontFamily,
    String photoURL = '',
    List<ResumeReviewChange> reviewChanges = const [],
    List<ResumeReviewNote> reviewNotes = const [],
    ResumeTheme? theme,
    bool standardCoverOnly = false,
  }) : theme = theme ?? ResumeTheme.standard,
       layout = ResumeLayout.resolve(
         resume.source['app_layout'] ?? resume.template,
       ) {
    final builder = _ResumeTypesetter(
      this,
      fontFamily,
      reviewChanges,
      reviewNotes,
      stopAfterFirstPage:
          standardCoverOnly &&
          this.theme.isStandard &&
          reviewChanges.isEmpty &&
          reviewNotes.isEmpty,
    );
    builder.compose(
      resume,
      photoURL.isNotEmpty ||
          resume.photoFileID > 0 ||
          resume.source['app_privacy_photo'] == true,
    );
  }
  // Drafts can be edited in place, including nested rich-text spans.
  static String layoutKey(
    ResumeDraft resume, {
    required String photoURL,
    ResumeTheme? theme,
    List<ResumeReviewNote> reviewNotes = const [],
    List<ResumeReviewChange> reviewChanges = const [],
  }) => jsonEncode([
    resume.source,
    resume.template,
    resume.name,
    resume.title,
    resume.position,
    resume.city,
    resume.phone,
    resume.email,
    resume.summary,
    resume.education,
    resume.experience,
    resume.skills,
    photoURL,
    resume.photoFileID,
    identityHashCode(theme),
    reviewNotes
        .map((v) => [v.key, v.fieldPath, v.height, v.selectedText])
        .toList(),
    reviewChanges
        .map(
          (v) => [
            v.key,
            v.fieldPath,
            v.original,
            v.replacement,
            v.accepted,
            v.appendReplacement,
            v.previewOnly,
          ],
        )
        .toList(),
  ]);

  final String? fontFamily;
  final ResumeLayout layout;
  final ResumeTheme theme;
  final pages = <ResumeSheet>[];
  final painters = <TextPainter>[];
  // TextPainter.width is the ink width for short text, not the column width.
  final paragraphWidths = <TextPainter, double>{};
  final sectionTitles = <String>[];

  void dispose() {
    for (final painter in painters) {
      painter.dispose();
    }
  }
}

class _StandardCoverComplete implements Exception {
  const _StandardCoverComplete();
}

class _ResumeTypesetter {
  _ResumeTypesetter(
    this.document,
    this.fontFamily,
    this.reviewChanges,
    this.reviewNotes, {
    required this.stopAfterFirstPage,
  }) {
    page = ResumeSheet();
    document.pages.add(page);
  }
  final ResumeDocument document;
  final bool stopAfterFirstPage;
  final String? fontFamily;
  final List<ResumeReviewChange> reviewChanges;
  final appliedChanges = <String>{};
  final List<ResumeReviewNote> reviewNotes;
  final placedNotes = <String>{};
  final anchorOccurrences = <String, Map<String, int>>{};
  late ResumeSheet page;
  ResumeTheme get theme => document.theme;
  double get left => theme.margin.left;
  late final double width = resumePaperSize.width - theme.margin.horizontal;
  late final double bottom = resumePaperSize.height - theme.margin.bottom;
  late double y = theme.margin.top;
  // Paragraph column; themes indent entries without moving section headings.
  late double x = left, column = width;
  _ResumeBox? box;

  // A system font without a real bold face keeps drawing in the same font; the
  // glyphs are thickened with thin same-colour copies instead, as in articles.
  // The offset follows the font size so it survives scaling the paper.
  List<Shadow>? boldShadows(FontWeight weight, double size, Color? color) {
    if (fontFamily != null ||
        !ResumeSystemFonts.needsBundledBold(weight.value)) {
      return null;
    }
    final offset = size * .026;
    final ink = color ?? resumePaperInk;
    return [
      Shadow(color: ink, offset: Offset(offset, 0)),
      Shadow(color: ink, offset: Offset(-offset, 0)),
    ];
  }

  TextStyle style(double size, {bool bold = false, Color? color}) {
    final weight = bold ? FontWeight.w600 : FontWeight.w400;
    final ink = color ?? theme.body.color;
    return TextStyle(
      fontFamily: fontFamily,
      fontSize: size,
      height: theme.body.height ?? (size + 4) / size,
      fontWeight: weight,
      color: ink,
      shadows: boldShadows(weight, size, ink),
    );
  }

  TextStyle themed(ResumeThemeText text, {Color? color}) {
    final weight = FontWeight.values[(text.weight ~/ 100 - 1).clamp(0, 8)];
    final ink = color ?? text.color ?? theme.body.color;
    return TextStyle(
      fontFamily: fontFamily,
      fontSize: text.size,
      height: text.height ?? theme.body.height ?? (text.size + 4) / text.size,
      fontWeight: weight,
      letterSpacing: text.letterSpacing,
      color: ink,
      shadows: boldShadows(weight, text.size, ink),
    );
  }

  TextPainter measure(InlineSpan text, [double? available]) {
    available ??= column;
    final painter = TextPainter(
      text: text,
      textDirection: TextDirection.ltr,
      textScaler: TextScaler.noScaling,
    )..layout(maxWidth: available);
    document.painters.add(painter);
    document.paragraphWidths[painter] = available;
    return painter;
  }

  void nextPage() {
    // The standard footer prints only the current page number. Once pagination
    // crosses this boundary, no subsequent content modifies the cover.
    if (stopAfterFirstPage) throw const _StandardCoverComplete();
    final open = box;
    if (open != null) open.close(page, y + open.padding.bottom);
    page = ResumeSheet();
    document.pages.add(page);
    y = theme.margin.top;
    if (open != null) {
      open.top = y;
      y += open.padding.top;
    }
  }

  void ensure(double height) {
    if (y + height > bottom &&
        (page.ink.isNotEmpty || page.reviewNotes.isNotEmpty)) {
      nextPage();
    }
  }

  InlineSpan applyReviewChanges(InlineSpan text, String? fieldPath) {
    for (final change in reviewChanges) {
      if (change.fieldPath != fieldPath ||
          appliedChanges.contains(change.key)) {
        continue;
      }
      final value = text.toPlainText();
      if (change.original.isNotEmpty &&
          (value.contains(change.original) ||
              change.accepted && value.contains(change.replacement))) {
        text = resumeReviewComparison(text, change);
        appliedChanges.add(change.key);
      }
    }
    return text;
  }

  void registerAnchorOccurrences(String? path, Iterable<InlineSpan> texts) {
    if (path == null) return;
    final values = texts.map((span) => span.toPlainText()).toList();
    anchorOccurrences[path] = {
      for (final note in reviewNotes)
        if (note.fieldPath == path && note.selectedText.isNotEmpty)
          note.selectedText: values.fold(0, (count, value) {
            var cursor = 0;
            while (cursor <= value.length - note.selectedText.length) {
              final start = value.indexOf(note.selectedText, cursor);
              if (start < 0) break;
              count++;
              cursor = start + 1;
            }
            return count;
          }),
    };
  }

  void placeReviewNote(
    ResumeReviewNote note, {
    double before = 0,
    double after = 10,
  }) {
    ensure(before + note.height);
    y += before;
    page.reviewNotes.add(
      ResumeReviewPlacement(note, Rect.fromLTWH(x, y, column, note.height)),
    );
    placedNotes.add(note.key);
    y += note.height + after;
  }

  void paragraph(
    InlineSpan text, {
    double before = 0,
    double? after,
    String? fieldPath,
    bool changesApplied = false,
  }) {
    after ??= theme.paragraphGap;
    if (!changesApplied) {
      text = applyReviewChanges(text, fieldPath);
      registerAnchorOccurrences(fieldPath, [text]);
    }
    final painter = measure(text);
    final lines = painter.computeLineMetrics();
    if (lines.isEmpty) return;
    final notesAfterLine = <int, List<ResumeReviewNote>>{};
    final value = painter.text!.toPlainText();
    // A quote may span several visual lines, but its comment belongs after
    // the final one. Ambiguous or stale quotes stay visible at the field end.
    if (!value.contains(resumePrivacyMask)) {
      for (final note in reviewNotes) {
        if (note.fieldPath != fieldPath ||
            placedNotes.contains(note.key) ||
            note.selectedText.isEmpty ||
            anchorOccurrences[fieldPath]?[note.selectedText] != 1) {
          continue;
        }
        final quoteStart = value.indexOf(note.selectedText);
        if (quoteStart < 0) continue;
        final boxes = painter.getBoxesForSelection(
          TextSelection(
            baseOffset: quoteStart,
            extentOffset: quoteStart + note.selectedText.length,
          ),
        );
        if (boxes.isEmpty) continue;
        final quoteBottom = boxes.fold<double>(
          0,
          (height, box) => math.max(height, box.bottom),
        );
        var lineBottom = 0.0;
        for (var index = 0; index < lines.length; index++) {
          lineBottom += lines[index].height;
          if (quoteBottom <= lineBottom + .001) {
            (notesAfterLine[index] ??= []).add(note);
            break;
          }
        }
      }
    }
    ensure(before + lines.first.height);
    y += before;
    var start = 0;
    var sourceTop = 0.0;
    while (start < lines.length) {
      var stop = lines.length;
      for (final line in notesAfterLine.keys) {
        if (line >= start) stop = math.min(stop, line + 1);
      }
      final notes = notesAfterLine[stop - 1];
      // Keep a quote's final line with at least its first comment whenever
      // both can fit on one page, rather than stranding the comment alone.
      final noteReserve = notes == null || notes.isEmpty
          ? 0.0
          : 4 + notes.first.height;
      final reserveFits =
          lines[stop - 1].height + noteReserve <= bottom - theme.margin.top;
      ensure(
        lines[start].height +
            (start == stop - 1 && reserveFits ? noteReserve : 0),
      );
      var height = 0.0;
      var end = start;
      while (end < stop &&
          y +
                  height +
                  lines[end].height +
                  (end == stop - 1 && reserveFits ? noteReserve : 0) <=
              bottom) {
        height += lines[end++].height;
      }
      // Font sizes are bounded, so at least one whole line always fits a page.
      if (end == start) {
        nextPage();
        continue;
      }
      page.ink.add(
        ResumeInk(
          painter,
          Offset(x, y),
          height,
          sourceTop: sourceTop,
          fieldPath: fieldPath,
        ),
      );
      y += height;
      sourceTop += height;
      start = end;
      if (end == stop && notes != null) {
        for (var index = 0; index < notes.length; index++) {
          placeReviewNote(notes[index], before: index == 0 ? 4 : 0, after: 7);
        }
      }
    }
    y += after;
  }

  void placeReviewNotes(String? path) {
    for (final note in reviewNotes) {
      if (path != note.fieldPath || placedNotes.contains(note.key)) continue;
      placeReviewNote(note);
    }
  }

  void text(
    String value, {
    double? size,
    bool bold = false,
    Color? color,
    double before = 0,
    double? after,
    String? fieldPath,
    TextStyle? textStyle,
  }) {
    size ??= theme.body.size;
    after ??= theme.paragraphGap;
    if (value.trim().isEmpty) {
      placeReviewNotes(fieldPath);
      return;
    }
    paragraph(
      TextSpan(
        text: value,
        style: textStyle ?? style(size, bold: bold, color: color),
      ),
      before: before,
      after: after,
      fieldPath: fieldPath,
    );
    placeReviewNotes(fieldPath);
  }

  String value(Map source, String key) =>
      source[key] is String ? (source[key] as String).trim() : '';
  List<Map> entries(dynamic data) =>
      data is List ? data.whereType<Map>().toList() : [];

  void section(String title) {
    ensure(14 + 20 + 8 + 32);
    document.sectionTitles.add(title);
    text(
      title,
      size: 12,
      bold: true,
      color: document.layout.accent,
      before: 14,
      after: 8,
    );
  }

  List<InlineSpan> richSpans(Map block) => entries(block['spans'])
      .map(
        (span) => TextSpan(
          text: span['text'] as String? ?? '',
          style: style(theme.body.size, bold: span['bold'] == true).copyWith(
            fontStyle: span['italic'] == true
                ? FontStyle.italic
                : FontStyle.normal,
            decoration: TextDecoration.combine([
              if (span['underline'] == true) TextDecoration.underline,
              if (span['strikethrough'] == true) TextDecoration.lineThrough,
            ]),
          ),
        ),
      )
      .toList();

  void detail(Map entry, String key, {String? fieldPath}) {
    final rich = entry['${key}_rich'];
    final blocks = rich is Map ? entries(rich['blocks']) : <Map>[];
    if (blocks.isEmpty) {
      final body = value(entry, key);
      text(body, fieldPath: fieldPath);
      return;
    }
    var number = 0;
    final paragraphs = <InlineSpan>[];
    for (final block in blocks) {
      final kind = block['kind'];
      final prefix = kind == 'bullet'
          ? '• '
          : kind == 'numbered'
          ? '${++number}. '
          : '';
      if (kind != 'numbered') number = 0;
      final spans = richSpans(block);
      if (spans.isEmpty) continue;
      paragraphs.add(
        applyReviewChanges(
          TextSpan(
            style: style(theme.body.size),
            children: [
              if (prefix.isNotEmpty) TextSpan(text: prefix),
              ...spans,
            ],
          ),
          fieldPath,
        ),
      );
    }
    registerAnchorOccurrences(fieldPath, paragraphs);
    for (final text in paragraphs) {
      paragraph(text, fieldPath: fieldPath, changesApplied: true);
    }
    placeReviewNotes(fieldPath);
  }

  bool meaningful(Map entry) => entry.values.any(
    (v) =>
        v is String && v.trim().isNotEmpty ||
        v is Map &&
            entries(v['blocks']).any(
              (b) =>
                  entries(b['spans']).any((s) => value(s, 'text').isNotEmpty),
            ),
  );

  void metadata(String label, String dates) {
    final left = measure(
      TextSpan(
        text: label,
        style: style(9.5, color: const Color(0xFF555555)),
      ),
    );
    final right = measure(
      TextSpan(
        text: dates,
        style: style(9.5, color: const Color(0xFF555555)),
      ),
    );
    final leftWidth = left.computeLineMetrics().fold<double>(
      0,
      (a, b) => math.max(a, b.width),
    );
    final rightWidth = right.computeLineMetrics().fold<double>(
      0,
      (a, b) => math.max(a, b.width),
    );
    if (label.isNotEmpty &&
        dates.isNotEmpty &&
        leftWidth + rightWidth + 24 <= column) {
      final height = math.max(left.height, right.height);
      ensure(height);
      // Give dates rounding/fallback-font room on their left while keeping
      // their right edge and a clear gap from the supporting information.
      final dateWidth = rightWidth + 12;
      page.ink.add(
        ResumeInk(
          left,
          Offset(x, y),
          height,
          wordWidth: column - dateWidth - 12,
        ),
      );
      page.ink.add(
        ResumeInk(
          right,
          Offset(x + column - rightWidth, y),
          height,
          wordLeft: x + column - dateWidth,
          wordWidth: dateWidth,
          wordAlignRight: true,
        ),
      );
      y += height + 8;
    } else {
      text(label, size: 9.5, color: const Color(0xFF555555));
      text(dates, size: 9.5, color: const Color(0xFF555555));
    }
  }

  // Keep a project together when its real typeset height fits a fresh page.
  // Oversized projects retain normal flow instead of overflowing or looping.
  double projectHeight(Map entry) {
    double heightOf(InlineSpan span) {
      final painter = TextPainter(
        text: span,
        textDirection: TextDirection.ltr,
        textScaler: TextScaler.noScaling,
      )..layout(maxWidth: width);
      final height = painter.height;
      painter.dispose();
      return height;
    }

    var height =
        heightOf(
          TextSpan(text: value(entry, 'name'), style: style(13, bold: true)),
        ) +
        5;
    final label = [
      'role',
      'url',
    ].map((key) => value(entry, key)).where((v) => v.isNotEmpty).join(' ');
    final dates = ['start_date', 'end_date']
        .map((key) => formatResumeMonth(value(entry, key)))
        .where((v) => v.isNotEmpty)
        .join(' ~ ');
    // Conservatively reserve separate metadata rows when the text is long.
    final meta = style(9.5, color: const Color(0xFF555555));
    final combined = heightOf(TextSpan(text: '$label    $dates', style: meta));
    height += combined <= 13.5
        ? combined + 8
        : heightOf(TextSpan(text: label, style: meta)) +
              heightOf(TextSpan(text: dates, style: meta)) +
              14;
    for (final key in ['description', 'achievements']) {
      final rich = entry['${key}_rich'];
      final blocks = rich is Map ? entries(rich['blocks']) : <Map>[];
      if (blocks.isEmpty) {
        final body = value(entry, key);
        if (body.isNotEmpty) {
          height += heightOf(TextSpan(text: body, style: style(10.5))) + 7;
        }
      } else {
        var number = 0;
        for (final block in blocks) {
          final kind = block['kind'];
          final prefix = kind == 'bullet'
              ? '• '
              : kind == 'numbered'
              ? '${++number}. '
              : '';
          if (kind != 'numbered') number = 0;
          final spans = richSpans(block);
          if (spans.isNotEmpty) {
            height +=
                heightOf(
                  TextSpan(
                    style: style(10.5),
                    children: [
                      TextSpan(text: prefix),
                      ...spans,
                    ],
                  ),
                ) +
                7;
          }
        }
      }
    }
    return height + 5;
  }

  void entrySection(
    Map source,
    String key,
    String title,
    String heading,
    List<String> supporting,
    List<String> details, {
    String fallback = '',
  }) {
    final values = entries(source[key]);
    if (!values.any(meaningful)) {
      if (fallback.trim().isNotEmpty) {
        section(title);
        text(fallback);
      }
      return;
    }
    final distinguishEntries =
        key == 'work_experiences' || key == 'educations' || key == 'projects';
    var renderedEntries = 0;
    for (var index = 0; index < values.length; index++) {
      final entry = values[index];
      if (!meaningful(entry)) continue;
      if (key == 'projects' && reviewNotes.isEmpty && reviewChanges.isEmpty) {
        final height = projectHeight(entry) + (renderedEntries == 0 ? 38 : 18);
        if (height <= bottom - theme.margin.top) ensure(height);
      }
      if (renderedEntries == 0) {
        if (key == 'projects') ensure(118);
        section(title);
      }
      if (distinguishEntries && renderedEntries > 0) {
        final previousPage = page;
        ensure(80);
        // A page boundary already separates entries; keep rules off page tops.
        if (identical(page, previousPage) && y > theme.margin.top) {
          y += 5;
          page.entryDividers.add(y);
          y += 13;
        }
      }
      ensure(key == 'projects' ? 80 : 48);
      text(
        value(entry, heading),
        size: distinguishEntries ? 13 : 11,
        bold: true,
        after: distinguishEntries ? 5 : 7,
        fieldPath: '$key.$index.$heading',
      );
      final dates = [
        formatResumeMonth(
          value(entry, key == 'certifications' ? 'date' : 'start_date'),
        ),
        entry['current'] == true
            ? '至今'
            : formatResumeMonth(value(entry, 'end_date')),
      ].where((s) => s.isNotEmpty).join(' ~ ');
      metadata(
        supporting
            .map((key) => value(entry, key))
            .where((s) => s.isNotEmpty)
            .join(' '),
        dates,
      );
      for (final field in details) {
        detail(entry, field, fieldPath: '$key.$index.$field');
      }
      renderedEntries++;
      if (distinguishEntries) y += 5;
    }
  }

  void compose(ResumeDraft resume, bool hasPhoto) {
    if (theme.isStandard) {
      try {
        composeStandard(resume, hasPhoto);
      } on _StandardCoverComplete {
        return;
      }
    } else {
      composeThemed(resume, hasPhoto);
    }
    // Historical comments still belong to this review even if their entire
    // source entry has since been removed from the resume.
    for (final note in reviewNotes) {
      if (!placedNotes.contains(note.key)) placeReviewNote(note);
    }
  }

  void composeStandard(ResumeDraft resume, bool hasPhoto) {
    final source = resume.source;
    final personal = source['personal_info'] is Map
        ? source['personal_info'] as Map
        : <String, dynamic>{};
    final job = source['job_expectation'] is Map
        ? source['job_expectation'] as Map
        : <String, dynamic>{};
    final gender = switch (value(personal, 'gender').toLowerCase()) {
      'male' || '男' => '男',
      'female' || '女' => '女',
      _ => '',
    };
    const metadataGap = '\u2003\u2003';
    final birth = resumeBirthLabel(personal);
    final birthPrefix =
        personal['birth_date_display_mode'] == 'age' &&
            resumeAge(value(personal, 'birth_date')) != null
        ? '年龄'
        : '出生日期';
    final demographics = [
      if (birth.isNotEmpty) '$birthPrefix: $birth',
      if (gender.isNotEmpty) '性别: $gender',
    ].join(metadataGap);
    final personalDetails = [
      if (resume.phone.isNotEmpty) '电话: ${resume.phone}',
      if (resume.email.isNotEmpty) '邮箱: ${resume.email}',
      if (demographics.isNotEmpty) demographics,
    ];
    final header = [
      measure(
        TextSpan(
          text: resume.name.isEmpty ? resume.title : resume.name,
          style: style(25, bold: true, color: document.layout.accent),
        ),
        hasPhoto ? width - 100 : width,
      ),
      for (final line in personalDetails)
        measure(
          TextSpan(text: line, style: style(10.5)),
          hasPhoto ? width - 100 : width,
        ),
    ];
    final height = math.max(
      hasPhoto ? 97.0 : 65.0,
      header.fold<double>(0, (h, p) => h + p.height + 7),
    );
    if (height <= 180) {
      for (final painter in header) {
        page.ink.add(ResumeInk(painter, Offset(left, y), painter.height));
        y += painter.height + 7;
      }
      if (hasPhoto) page.photo = photoRect;
      y = theme.margin.top + height + 10;
      page.dividerY = y;
      y += 8;
    } else {
      text(
        resume.name.isEmpty ? resume.title : resume.name,
        size: 25,
        bold: true,
      );
      for (final line in personalDetails) {
        text(line);
      }
    }
    final expectations = [
      if (resume.position.isNotEmpty) '期望职位: ${resume.position}',
      if (resume.city.isNotEmpty) '期望城市: ${resume.city}',
      if (value(job, 'industry').isNotEmpty) '期望行业: ${value(job, 'industry')}',
      if (value(job, 'salary').isNotEmpty) '期望薪资: ${value(job, 'salary')}',
    ].join(metadataGap);
    for (final module in resumeModuleOrder(source)) {
      switch (module) {
        case 'job_expectation':
          if (expectations.isNotEmpty) {
            section('求职期望');
            text(expectations);
          }
        case 'self_evaluation':
          if (resume.summary.isNotEmpty ||
              meaningful({'rich': job['preference_rich']})) {
            section('自我评价');
            detail(
              {...job, 'preference': resume.summary},
              'preference',
              fieldPath: 'job_expectation.preference',
            );
          }
        case 'educations':
          entrySection(
            source,
            'educations',
            '教育经历',
            'institution',
            ['degree', 'field_of_study'],
            ['campus_experience', 'thesis_title', 'thesis_description'],
            fallback: resume.education,
          );
        case 'work_experiences':
          entrySection(
            source,
            'work_experiences',
            '工作经历',
            'company',
            ['position', 'industry'],
            ['description'],
            fallback: resume.experience,
          );
        case 'projects':
          entrySection(
            source,
            'projects',
            '项目经历',
            'name',
            ['role', 'url'],
            ['description', 'achievements'],
          );
        case 'skills':
          final skills = entries(source['skills']);
          if (skills.any(meaningful)) {
            section('技能');
            for (var index = 0; index < skills.length; index++) {
              final skill = skills[index];
              if (!meaningful(skill)) continue;
              text(
                value(skill, 'name'),
                bold: true,
                fieldPath: 'skills.$index.name',
              );
              detail(
                skill,
                'description',
                fieldPath: 'skills.$index.description',
              );
            }
          } else if (resume.skills.isNotEmpty) {
            section('技能');
            text(resume.skills);
          }
        case 'certifications':
          entrySection(source, 'certifications', '证书', 'name', ['issuer'], []);
      }
    }
  }

  Rect get photoRect => Rect.fromLTWH(
    resumePaperSize.width -
        theme.margin.right -
        theme.photoInset -
        theme.photoSize.width,
    theme.margin.top,
    theme.photoSize.width,
    theme.photoSize.height,
  );

  double inkWidth(TextPainter painter) => painter.computeLineMetrics().fold(
    0.0,
    (widest, line) => math.max(widest, line.width),
  );

  /// Places a measured block that the caller has already kept on this page.
  void place(
    TextPainter painter,
    double dx,
    double top, {
    String? fieldPath,
    double? wordLeft,
    double? wordWidth,
    bool alignRight = false,
  }) => page.ink.add(
    ResumeInk(
      painter,
      Offset(dx, top),
      painter.height,
      fieldPath: fieldPath,
      wordLeft: wordLeft,
      wordWidth: wordWidth,
      wordAlignRight: alignRight,
    ),
  );

  void graphic(ResumeThemeGraphic? graphic, Rect rect) {
    if (graphic != null) {
      page.decorations.add(ResumeGraphicDecoration(graphic, rect));
    }
  }

  void indented(double indent, VoidCallback body) {
    final previousX = x, previousColumn = column;
    x = left + indent;
    column = width - indent;
    try {
      body();
    } finally {
      x = previousX;
      column = previousColumn;
    }
  }

  String gender(Map personal) =>
      switch (value(personal, 'gender').toLowerCase()) {
        'male' || '男' => '男',
        'female' || '女' => '女',
        _ => '',
      };

  /// Fills the first page's sidebar and returns the modules it holds. A
  /// module that would run past the page stays in the main column.
  Set<String> sidebar(
    ResumeDraft resume,
    Map personal,
    Map source,
    bool hasPhoto,
  ) {
    final bar = theme.sidebar!;
    final pad = bar.padding;
    final inner = bar.width - pad.horizontal;
    final icon = bar.iconSize;
    var cy = hasPhoto ? pad.top : bar.topWithoutPhoto ?? pad.top;
    TextPainter line(String value, ResumeThemeText style, double width) =>
        measure(TextSpan(text: value, style: themed(style)), width);
    if (hasPhoto) {
      final size = theme.photoSize;
      final rect =
          theme.photoRect ??
          Rect.fromLTWH(
            (bar.width - size.width) / 2,
            cy,
            size.width,
            size.height,
          );
      page.photo = rect;
      if (bar.ring case final Color ring) {
        page.decorations.add(
          ResumeDotDecoration(
            rect.center,
            size.shortestSide / 2 + bar.ringWidth,
            ring,
          ),
        );
      }
      cy = math.max(cy, rect.bottom) + bar.ringWidth + bar.sectionGap;
    }
    if (bar.header) {
      final name = line(
        resume.name.isEmpty ? resume.title : resume.name,
        theme.name,
        inner,
      );
      place(name, pad.left, cy);
      cy += name.height + theme.contactTop;
      final job = source['job_expectation'] is Map
          ? source['job_expectation'] as Map
          : const {};
      final wanted = [
        resume.position,
        value(job, 'industry'),
      ].where((part) => part.isNotEmpty).join(' · ');
      if (wanted.isNotEmpty) {
        final painter = line(wanted, bar.subtitle, inner);
        place(painter, pad.left, cy, fieldPath: 'job_expectation.position');
        cy += painter.height;
      }
      cy += bar.sectionGap;
    }
    final skills = entries(source['skills']);
    final certifications = entries(source['certifications']);
    final birthLabel =
        personal['birth_date_display_mode'] == 'age' &&
            resumeAge(value(personal, 'birth_date')) != null
        ? '年龄'
        : '出生日期';
    final contacts = [
      ('phone', theme.contactLabels['phone'] ?? '电话', resume.phone),
      ('email', theme.contactLabels['email'] ?? '邮箱', resume.email),
      ('city', theme.contactLabels['city'] ?? '城市', resume.city),
      (
        'birth',
        theme.contactLabels['birth'] ?? birthLabel,
        resumeBirthLabel(personal),
      ),
      ('gender', theme.contactLabels['gender'] ?? '性别', gender(personal)),
    ].where((item) => item.$3.isNotEmpty);
    final placed = <String>{};
    var shown = 0;
    for (final section in bar.sections) {
      // Each row: painter, left inset, field path and optional icon key.
      final rows = <(TextPainter, double, String?, String?)>[];
      final key = section == 'contact' ? 'contact' : section;
      switch (section) {
        case 'contact':
          for (final (field, label, text) in contacts) {
            rows.add((
              line(
                label.isEmpty ? text : '$label：$text',
                bar.text,
                inner - icon * .8 - 5,
              ),
              icon * .8 + 5,
              null,
              field,
            ));
          }
        case 'skills':
          for (var index = 0; index < skills.length; index++) {
            if (!meaningful(skills[index])) continue;
            final name = value(skills[index], 'name');
            final about = value(skills[index], 'description');
            if (name.isNotEmpty) {
              rows.add((
                line(name, bar.text, inner),
                0,
                'skills.$index.name',
                null,
              ));
            }
            if (about.isNotEmpty) {
              rows.add((
                line(about, bar.muted, inner),
                0,
                'skills.$index.description',
                null,
              ));
            }
          }
          if (rows.isEmpty && resume.skills.trim().isNotEmpty) {
            rows.add((
              line(resume.skills.trim(), bar.muted, inner),
              0,
              null,
              null,
            ));
          }
        case 'certifications':
          for (var index = 0; index < certifications.length; index++) {
            if (!meaningful(certifications[index])) continue;
            final name = value(certifications[index], 'name');
            final meta = [
              value(certifications[index], 'issuer'),
              formatResumeMonth(value(certifications[index], 'date'))
                  .replaceAll('/', theme.monthSeparator),
            ].where((part) => part.isNotEmpty).join('  ');
            if (name.isNotEmpty) {
              rows.add((
                line(name, bar.text, inner),
                0,
                'certifications.$index.name',
                null,
              ));
            }
            if (meta.isNotEmpty) {
              rows.add((
                line(meta, bar.muted, inner),
                0,
                'certifications.$index.issuer',
                null,
              ));
            }
          }
      }
      if (rows.isEmpty) {
        // Nothing to show, and nothing for the main column to show either.
        if (section != 'contact') placed.add(section);
        continue;
      }
      final headIcon = bar.icons[key] == null ? 0.0 : icon;
      final iconSpace = headIcon > 0 ? headIcon + 6 : 0.0;
      final title = line(
        theme.title(
          key,
          const {
                'contact': '联系方式',
                'skills': '技能特长',
                'certifications': '获奖情况',
              }[key] ??
              key,
        ),
        bar.heading,
        inner - iconSpace,
      );
      final headHeight = math.max(headIcon, title.height) + 9;
      final height = rows.fold(
        headHeight,
        (sum, row) =>
            sum + math.max(row.$4 == null ? 0 : icon, row.$1.height) + 4,
      );
      if (cy + height > resumePaperSize.height - pad.bottom &&
          section != 'contact') {
        continue;
      }
      if (bar.rule case final ResumeThemeRule rule
          when bar.ruleAbove && shown > 0) {
        final ruleY = cy - bar.sectionGap / 2;
        page.decorations.add(
          ResumeLineDecoration(
            Offset(pad.left, ruleY),
            Offset(pad.left + inner, ruleY),
            rule,
          ),
        );
      }
      shown++;
      final headTop = cy;
      final headRow = math.max(headIcon, title.height);
      graphic(
        bar.icons[key],
        Rect.fromLTWH(pad.left, headTop + (headRow - icon) / 2, icon, icon),
      );
      place(
        title,
        pad.left + iconSpace,
        headTop + (headRow - title.height) / 2,
      );
      cy += headRow + 3;
      if (bar.rule case final ResumeThemeRule rule when !bar.ruleAbove) {
        page.decorations.add(
          ResumeLineDecoration(
            Offset(pad.left, cy),
            Offset(pad.left + inner, cy),
            rule,
          ),
        );
      }
      cy += 6;
      for (final (painter, inset, fieldPath, iconKey) in rows) {
        final rowHeight = math.max(
          iconKey == null ? 0.0 : icon,
          painter.height,
        );
        if (iconKey != null) {
          graphic(
            theme.contactIcons[iconKey],
            Rect.fromLTWH(
              pad.left,
              cy + (rowHeight - icon * .8) / 2,
              icon * .8,
              icon * .8,
            ),
          );
        }
        place(
          painter,
          pad.left + inset,
          cy + (rowHeight - painter.height) / 2,
          fieldPath: fieldPath,
        );
        cy += rowHeight + 4;
      }
      cy += bar.sectionGap;
      placed.add(section);
    }
    return placed;
  }

  /// Main-column header beside a sidebar: the name, then the job
  /// expectation, which therefore has no section of its own.
  void sidebarHeader(ResumeDraft resume, Map job) {
    final name = measure(
      TextSpan(
        text: resume.name.isEmpty ? resume.title : resume.name,
        style: themed(
          theme.name,
          color: theme.name.color ?? document.layout.accent,
        ),
      ),
    );
    place(name, x, y);
    y += name.height + theme.contactTop;
    final wanted = [
      resume.position,
      value(job, 'industry'),
      value(job, 'salary'),
    ].where((part) => part.isNotEmpty).join(' · ');
    if (wanted.isNotEmpty) {
      final line = measure(
        TextSpan(text: '求职意向：$wanted', style: themed(theme.contact)),
      );
      place(line, x, y, fieldPath: 'job_expectation.position');
      y += line.height;
    }
    y = math.max(y, theme.margin.top + theme.headerMinHeight);
  }

  void splitHeader(ResumeDraft resume, Map personal, Map job, bool hasPhoto) {
    final top = theme.margin.top;
    final available =
        width -
        (hasPhoto ? theme.photoSize.width + theme.photoInset + 13.5 : 0);
    final gap = theme.contactGap;
    final name = measure(
      TextSpan(
        text: resume.name.isEmpty ? resume.title : resume.name,
        style: themed(
          theme.name,
          color: theme.name.color ?? document.layout.accent,
        ),
      ),
      available * .45,
    );
    final subtitle = theme.subtitle == null || resume.position.isEmpty
        ? null
        : measure(
            TextSpan(text: resume.position, style: themed(theme.subtitle!)),
            available * .45,
          );
    final leftWidth = math.max(
      inkWidth(name),
      subtitle == null ? 0.0 : inkWidth(subtitle),
    );
    final leftHeight =
        name.height +
        (subtitle == null ? 0 : theme.contactTop + subtitle.height);
    final birthLabel =
        personal['birth_date_display_mode'] == 'age' &&
            resumeAge(value(personal, 'birth_date')) != null
        ? '年龄'
        : '出生日期';
    const labels = {
      'phone': '电话',
      'email': '邮箱',
      'gender': '性别',
      'position': '期望职位',
      'city': '期望城市',
      'industry': '期望行业',
      'salary': '期望薪资',
    };
    final values = {
      'phone': resume.phone,
      'email': resume.email,
      'birth': resumeBirthLabel(personal),
      'gender': gender(personal),
      'position': resume.position,
      'city': resume.city,
      'industry': value(job, 'industry'),
      'salary': value(job, 'salary'),
    };
    final contactX = left + leftWidth + gap * 2;
    final icon = theme.contactIconSize;
    final textX = contactX + (icon > 0 ? icon + 6 : 0);
    final rows = [
      for (final key in theme.contactFields)
        if ((values[key] ?? '').isNotEmpty)
          (
            key: key,
            painter: measure(
              TextSpan(
                text: [
                  theme.contactLabels[key] ??
                      (key == 'birth' ? birthLabel : labels[key] ?? ''),
                  values[key]!,
                ].where((part) => part.isNotEmpty).join('：'),
                style: themed(theme.contact),
              ),
              math.max(1, left + available - textX),
            ),
          ),
    ];
    final contactsHeight = rows.isEmpty
        ? 0.0
        : rows.fold(
                0.0,
                (sum, row) =>
                    sum +
                    math.max(icon, row.painter.height) +
                    theme.contactLineGap,
              ) -
              theme.contactLineGap;
    final height = [
      theme.headerMinHeight,
      if (hasPhoto) theme.photoSize.height,
      leftHeight,
      contactsHeight,
    ].reduce(math.max);
    var cursor = top + (height - leftHeight) / 2;
    place(name, left, cursor);
    cursor += name.height + theme.contactTop;
    if (subtitle != null) place(subtitle, left, cursor);
    if (theme.headerDivider case final ResumeThemeRule divider
        when rows.isNotEmpty) {
      final dividerX = left + leftWidth + gap;
      page.decorations.add(
        ResumeLineDecoration(
          Offset(dividerX, top + (height - contactsHeight) / 2),
          Offset(dividerX, top + (height + contactsHeight) / 2),
          divider,
        ),
      );
    }
    cursor = top + (height - contactsHeight) / 2;
    for (final row in rows) {
      final rowHeight = math.max(icon, row.painter.height);
      graphic(
        theme.contactIcons[row.key],
        Rect.fromLTWH(contactX, cursor + (rowHeight - icon) / 2, icon, icon),
      );
      place(row.painter, textX, cursor + (rowHeight - row.painter.height) / 2);
      cursor += rowHeight + theme.contactLineGap;
    }
    if (hasPhoto) page.photo = photoRect;
    y = top + height;
    if (theme.headerRule != null) {
      y += 10;
      page.dividerY = y;
      y += 8;
    }
  }

  void themedHeader(ResumeDraft resume, Map personal, bool hasPhoto) {
    final top = theme.margin.top;
    final available =
        width -
        (hasPhoto ? theme.photoSize.width + theme.photoInset + 13.5 : 0);
    final name = measure(
      TextSpan(
        text: resume.name.isEmpty ? resume.title : resume.name,
        style: themed(
          theme.name,
          color: theme.name.color ?? document.layout.accent,
        ),
      ),
      available,
    );
    var cursor = top + 3;
    place(name, left, cursor);
    cursor += name.height + theme.contactTop;
    final icon = theme.contactIconSize;
    final row = <({ResumeThemeGraphic? art, TextPainter text, double dx})>[];
    void flush() {
      if (row.isEmpty) return;
      final height = row.fold<double>(
        icon,
        (tallest, item) => math.max(tallest, item.text.height),
      );
      for (final item in row) {
        var textX = item.dx;
        if (item.art != null) {
          graphic(
            item.art,
            Rect.fromLTWH(item.dx, cursor + (height - icon) / 2, icon, icon),
          );
          textX += icon + 4.5;
        }
        place(item.text, textX, cursor + (height - item.text.height) / 2);
      }
      cursor += height + 3;
      row.clear();
    }

    var rowX = left;
    for (final (key, label) in [
      ('phone', resume.phone),
      ('email', resume.email),
      ('birth', resumeBirthLabel(personal)),
      ('gender', gender(personal)),
    ]) {
      if (label.isEmpty) continue;
      final art = theme.contactIcons[key];
      final reserved = art == null ? 0.0 : icon + 4.5;
      final painter = measure(
        TextSpan(text: label, style: themed(theme.contact)),
        math.max(1, available - reserved),
      );
      final itemWidth = reserved + inkWidth(painter);
      if (row.isNotEmpty && rowX + itemWidth > left + available) {
        flush();
        rowX = left;
      }
      row.add((art: art, text: painter, dx: rowX));
      rowX += itemWidth + theme.contactGap;
    }
    flush();
    final height = [
      theme.headerMinHeight,
      if (hasPhoto) theme.photoSize.height,
      cursor - 3 - top,
    ].reduce(math.max);
    if (hasPhoto) page.photo = photoRect;
    y = top + height;
    if (theme.headerRule != null) {
      y += 10;
      page.dividerY = y;
      y += 8;
    }
  }

  void themedSection(String key, String fallback) {
    final title = theme.title(key, fallback);
    final painter = measure(
      TextSpan(text: title, style: themed(theme.heading)),
      width,
    );
    final icon = theme.headingIconSize;
    final rowHeight = math.max(icon, painter.height);
    ensure(theme.headingBefore + rowHeight + theme.headingAfter + 32);
    // A sidebar inks the page first, so position tells whether the heading
    // follows other main-column content.
    final follows = y > theme.margin.top + .5;
    if (follows) y += theme.headingBefore;
    document.sectionTitles.add(title);
    final textX = left + (icon > 0 ? icon + theme.headingIconGap : 0);
    final textTop = y + (rowHeight - painter.height) / 2;
    graphic(
      theme.headingIcons[key],
      Rect.fromLTWH(left, y + (rowHeight - icon) / 2, icon, icon),
    );
    var end = textX + inkWidth(painter);
    if (theme.headingBrush != null) {
      final brush = theme.headingBrushPadding;
      final rect = Rect.fromLTRB(
        textX - brush.left,
        textTop - brush.top,
        end + brush.right,
        textTop + painter.height + brush.bottom,
      );
      graphic(theme.headingBrush, rect);
      end = rect.right;
    }
    place(painter, textX, textTop);
    if ((theme.headingSubtitles[key], theme.headingSubtitle) case (
      final String text,
      final ResumeThemeText style,
    )) {
      final subtitle = measure(TextSpan(text: text, style: themed(style)));
      final gap = theme.headingIconGap > 0 ? theme.headingIconGap : 10.0;
      place(
        subtitle,
        end + gap,
        textTop +
            painter.computeDistanceToActualBaseline(TextBaseline.alphabetic) -
            subtitle.computeDistanceToActualBaseline(TextBaseline.alphabetic),
      );
      end += gap + inkWidth(subtitle);
    }
    if (theme.headingRule case final ResumeThemeRule rule
        when theme.headingRuleBelow) {
      final ruleY =
          y + rowHeight + (theme.headingRuleOffset ?? theme.headingAfter / 2);
      page.decorations.add(
        ResumeLineDecoration(
          Offset(left, ruleY),
          Offset(left + width, ruleY),
          rule,
        ),
      );
    } else if (theme.headingRule case final ResumeThemeRule rule) {
      final ruleY = y + rowHeight / 2;
      final from = end + theme.headingIconGap, to = left + width;
      if (to > from) {
        page.decorations.add(
          ResumeLineDecoration(Offset(from, ruleY), Offset(to, ruleY), rule),
        );
        if (theme.headingRuleDot case final Color dot) {
          page.decorations.add(
            ResumeDotDecoration(Offset(to - 1.5, ruleY), 1.3, dot),
          );
        }
      }
    }
    y += rowHeight + theme.headingAfter;
  }

  void themedExpectations(ResumeDraft resume, Map job) {
    const basis = {'position': 34.0, 'city': 22.0, 'industry': 26.0};
    final items = [
      ('position', '期望职位', resume.position),
      ('city', '期望城市', resume.city),
      ('industry', '期望行业', value(job, 'industry')),
      ('salary', '期望薪资', value(job, 'salary')),
    ].where((item) => item.$3.isNotEmpty).toList();
    if (items.isEmpty) return;
    themedSection('job_expectation', '求职期望');
    if (!theme.expectationCards) {
      indented(
        theme.entryIndent,
        () => text(
          items.map((item) => '${item.$2}: ${item.$3}').join('\u2003\u2003'),
        ),
      );
      return;
    }
    final pad = theme.expectationPadding;
    final icon = theme.expectationIconSize;
    final inner = width - pad.horizontal;
    final total = items.fold(0.0, (sum, item) => sum + (basis[item.$1] ?? 18));
    final cells =
        <
          ({
            String key,
            double dx,
            double cellWidth,
            double textX,
            TextPainter label,
            TextPainter content,
          })
        >[];
    var cellX = left + pad.left;
    for (final (key, label, content) in items) {
      final cellWidth = inner * (basis[key] ?? 18) / total;
      final textX = cellX + 7.5 + (icon > 0 ? icon + 5.25 : 0);
      final textWidth = math.max(1.0, cellX + cellWidth - 7.5 - textX);
      cells.add((
        key: key,
        dx: cellX,
        cellWidth: cellWidth,
        textX: textX,
        label: measure(
          TextSpan(text: label, style: themed(theme.expectationLabel)),
          textWidth,
        ),
        content: measure(
          TextSpan(text: content, style: themed(theme.expectationValue)),
          textWidth,
        ),
      ));
      cellX += cellWidth;
    }
    final contentHeight = cells.fold<double>(
      icon,
      (tallest, cell) =>
          math.max(tallest, cell.label.height + 3 + cell.content.height),
    );
    final height = pad.vertical + contentHeight;
    ensure(height);
    final top = y, contentTop = y + pad.top;
    page.decorations.add(
      ResumeFillDecoration(
        Rect.fromLTWH(left, top, width, height),
        theme.expectationFill,
        theme.expectationRadius,
      ),
    );
    for (var index = 0; index < cells.length; index++) {
      final cell = cells[index];
      graphic(
        theme.expectationIcons[cell.key],
        Rect.fromLTWH(cell.dx + 7.5, contentTop, icon, icon),
      );
      place(cell.label, cell.textX, contentTop);
      place(cell.content, cell.textX, contentTop + cell.label.height + 3);
      if (index < cells.length - 1) {
        final dividerX = cell.dx + cell.cellWidth;
        page.decorations.add(
          ResumeLineDecoration(
            Offset(dividerX, contentTop),
            Offset(dividerX, contentTop + contentHeight),
            ResumeThemeRule(theme.expectationDivider, .75),
          ),
        );
      }
    }
    y = top + height;
  }

  void entryHead(
    Map entry,
    String key,
    int index,
    String heading,
    List<String> supporting,
  ) {
    final dates = [
      formatResumeMonth(
        value(entry, key == 'certifications' ? 'date' : 'start_date'),
      ).replaceAll('/', theme.monthSeparator),
      entry['current'] == true
          ? '至今'
          : formatResumeMonth(value(entry, 'end_date'))
                .replaceAll('/', theme.monthSeparator),
    ].where((s) => s.isNotEmpty).join(theme.dateSeparator);
    final datePainter = dates.isEmpty
        ? null
        : measure(TextSpan(text: dates, style: themed(theme.entryDates)));
    final dateWidth = datePainter == null ? 0.0 : inkWidth(datePainter);
    final leading =
        theme.datesFirst &&
        datePainter != null &&
        dateWidth <= theme.dateColumn - 6;
    final sideBySide =
        !leading &&
        theme.datesWithTitle &&
        datePainter != null &&
        dateWidth <= column * .4;
    TextSpan titleSpan(List<String> inline) => TextSpan(
      style: themed(theme.entryTitle),
      children: [
        TextSpan(text: value(entry, heading)),
        for (final part in inline)
          TextSpan(
            text: '${theme.supportingSeparator}$part',
            style: themed(theme.entrySubtitle),
          ),
      ],
    );
    var title = titleSpan(const []);
    if (theme.inlineSupporting) {
      final inline = [
        for (final field in supporting)
          if (value(entry, field).isNotEmpty) value(entry, field),
      ];
      final titleWidth = leading
          ? column - theme.dateColumn
          : sideBySide
          ? column - dateWidth - 18
          : column;
      // Details join the title only while it all fits on one line; otherwise
      // they take their own line below it.
      final joined = titleSpan(inline);
      if (measure(joined, titleWidth).computeLineMetrics().length <= 1) {
        title = joined;
        supporting = const [];
      }
    }
    void writeTitle() =>
        paragraph(title, after: 0, fieldPath: '$key.$index.$heading');
    // Dates beside a larger title share its first baseline.
    double dateShift(TextPainter dates) => math.max(
      0,
      measure(title).computeDistanceToActualBaseline(TextBaseline.alphabetic) -
          dates.computeDistanceToActualBaseline(TextBaseline.alphabetic),
    );
    if (leading) {
      ensure(datePainter.height);
      final rowPage = page, rowTop = y;
      final fullX = x, fullColumn = column;
      x += theme.dateColumn;
      column -= theme.dateColumn;
      try {
        writeTitle();
      } finally {
        x = fullX;
        column = fullColumn;
      }
      final dateTop =
          (identical(rowPage, page) ? rowTop : theme.margin.top) +
          dateShift(datePainter);
      place(datePainter, x, dateTop);
      y = math.max(y, dateTop + datePainter.height);
    } else if (sideBySide) {
      ensure(datePainter.height);
      final rowPage = page, rowTop = y, fullColumn = column;
      column = fullColumn - dateWidth - 18;
      try {
        writeTitle();
      } finally {
        column = fullColumn;
      }
      // A title that starts on the next page takes its dates along.
      final dateTop =
          (identical(rowPage, page) ? rowTop : theme.margin.top) +
          dateShift(datePainter);
      place(
        datePainter,
        x + column - dateWidth,
        dateTop,
        wordLeft: x + column - dateWidth - 12,
        wordWidth: dateWidth + 12,
        alignRight: true,
      );
      y = math.max(y, dateTop + datePainter.height);
    } else {
      writeTitle();
      if (datePainter != null) {
        text(dates, textStyle: themed(theme.entryDates), after: 0);
      }
    }
    final meta = [
      for (final (index, field) in supporting.indexed)
        if (value(entry, field).isNotEmpty)
          (
            field,
            measure(
              TextSpan(
                text: value(entry, field),
                style: themed(
                  index == 0 ? theme.entrySubtitle : theme.entryAuxiliary,
                ),
              ),
            ),
          ),
    ];
    if (meta.isEmpty) return;
    y += 2.25;
    final combined =
        meta.fold(0.0, (sum, item) => sum + inkWidth(item.$2)) +
        10.5 * (meta.length - 1);
    if (combined <= column) {
      final height = meta.fold<double>(
        0,
        (tallest, item) => math.max(tallest, item.$2.height),
      );
      ensure(height);
      var dx = x;
      for (final (field, painter) in meta) {
        place(painter, dx, y, fieldPath: '$key.$index.$field');
        dx += inkWidth(painter) + 10.5;
      }
      y += height;
    } else {
      for (final (field, painter) in meta) {
        text(
          painter.text!.toPlainText(),
          textStyle: painter.text!.style,
          after: 0,
          fieldPath: '$key.$index.$field',
        );
      }
    }
  }

  void themedEntries(
    Map source,
    String key,
    String title,
    String heading,
    List<String> supporting,
    List<String> details, {
    String fallback = '',
  }) {
    final values = entries(source[key]);
    if (!values.any(meaningful)) {
      if (fallback.trim().isNotEmpty) {
        themedSection(key, title);
        indented(theme.entryIndent, () => text(fallback));
      }
      return;
    }
    themedSection(key, title);
    indented(theme.entryIndent, () {
      var rendered = 0;
      for (var index = 0; index < values.length; index++) {
        final entry = values[index];
        if (!meaningful(entry)) continue;
        if (rendered > 0) {
          final previous = page;
          ensure(48);
          if (identical(previous, page)) {
            if (theme.entryDivider case final ResumeThemeRule rule) {
              y += theme.entryGap / 2;
              page.decorations.add(
                ResumeLineDecoration(Offset(x, y), Offset(x + column, y), rule),
              );
              y += theme.entryGap / 2;
            } else {
              y += theme.entryGap;
            }
          }
        }
        ensure(40);
        entryHead(entry, key, index, heading, supporting);
        if (details.isNotEmpty) y += 3;
        for (final field in details) {
          detail(entry, field, fieldPath: '$key.$index.$field');
        }
        rendered++;
      }
    });
  }

  void themedSkills(ResumeDraft resume, List<Map> skills) {
    final listed = skills.any(meaningful);
    if (!listed && resume.skills.isEmpty) return;
    themedSection('skills', '技能');
    if (theme.skillTags &&
        listed &&
        !skills.any(
          (skill) => meaningful({...skill, 'name': '', 'level': ''}),
        )) {
      indented(theme.entryIndent, () => skillTags(skills));
      return;
    }
    void body() {
      if (!listed) {
        text(resume.skills);
        return;
      }
      var first = true;
      for (var index = 0; index < skills.length; index++) {
        final skill = skills[index];
        if (!meaningful(skill)) continue;
        if (!first) y += theme.skillGap;
        first = false;
        text(
          value(skill, 'name'),
          textStyle: themed(theme.skillName),
          after: 2.25,
          fieldPath: 'skills.$index.name',
        );
        detail(skill, 'description', fieldPath: 'skills.$index.description');
      }
    }

    if (!theme.skillsCard) {
      indented(theme.entryIndent, body);
      return;
    }
    card(theme.skillsFill, theme.skillsRadius, theme.skillsPadding, body);
  }

  void card(Color fill, double radius, EdgeInsets pad, VoidCallback body) {
    final cardLeft = left + theme.entryIndent;
    final cardWidth = width - theme.entryIndent;
    ensure(pad.top + 40);
    final open = box = _ResumeBox(cardLeft, cardWidth, fill, radius, pad, y);
    y += pad.top;
    final previousX = x, previousColumn = column;
    x = cardLeft + pad.left;
    column = cardWidth - pad.horizontal;
    try {
      body();
    } finally {
      x = previousX;
      column = previousColumn;
      box = null;
    }
    // Paragraph spacing already separates the last line from the card edge.
    y += math.max(0, pad.bottom - theme.paragraphGap);
    open.close(page, y);
  }

  void skillTags(List<Map> skills) {
    final pad = theme.tagPadding;
    final style = themed(theme.tagText ?? theme.body);
    var rowX = x;
    double? rowHeight;
    for (var index = 0; index < skills.length; index++) {
      final name = value(skills[index], 'name');
      if (name.isEmpty) continue;
      final painter = measure(
        TextSpan(text: name, style: style),
        math.max(1, column - pad.horizontal),
      );
      final chip = Size(
        inkWidth(painter) + pad.horizontal,
        painter.height + pad.vertical,
      );
      if (rowHeight != null && rowX + chip.width > x + column) {
        y += rowHeight + theme.tagGap;
        rowX = x;
        rowHeight = null;
      }
      if (rowHeight == null) ensure(chip.height);
      page.decorations.add(
        ResumeFillDecoration(
          Offset(rowX, y) & chip,
          theme.tagFill,
          theme.tagRadius,
        ),
      );
      place(
        painter,
        rowX + pad.left,
        y + pad.top,
        fieldPath: 'skills.$index.name',
      );
      rowX += chip.width + theme.tagGap;
      rowHeight = math.max(rowHeight ?? 0, chip.height);
    }
    if (rowHeight != null) y += rowHeight + theme.paragraphGap;
  }

  void themedCertifications(Map source) {
    final columns = theme.certificationColumns;
    if (columns == 1) {
      themedEntries(source, 'certifications', '证书', 'name', ['issuer'], []);
      return;
    }
    final values = entries(source['certifications']);
    final shown = [
      for (var index = 0; index < values.length; index++)
        if (meaningful(values[index])) index,
    ];
    if (shown.isEmpty) return;
    themedSection('certifications', '证书');
    indented(theme.entryIndent, () {
      final gap = theme.certificationColumnGap;
      final cellWidth = (column - gap * (columns - 1)) / columns;
      final meta = themed(theme.entryDates, color: theme.muted);
      for (var start = 0; start < shown.length; start += columns) {
        final row = [
          for (final index in shown.skip(start).take(columns))
            (
              index: index,
              title: measure(
                TextSpan(
                  text: value(values[index], 'name'),
                  style: themed(theme.certificationTitle),
                ),
                cellWidth,
              ),
              meta: measure(
                TextSpan(
                  text: [
                    value(values[index], 'issuer'),
                    formatResumeMonth(value(values[index], 'date')),
                  ].where((part) => part.isNotEmpty).join('\u2003'),
                  style: meta,
                ),
                math.max(1, cellWidth - 9),
              ),
            ),
        ];
        final height = row.fold<double>(
          0,
          (tallest, cell) =>
              math.max(tallest, cell.title.height + 2.25 + cell.meta.height),
        );
        ensure(height);
        for (final (slot, cell) in row.indexed) {
          final dx = x + slot * (cellWidth + gap);
          place(
            cell.title,
            dx,
            y,
            fieldPath: 'certifications.${cell.index}.name',
          );
          place(cell.meta, dx + 9, y + cell.title.height + 2.25);
        }
        y += height + theme.certificationRowGap;
      }
    });
  }

  void composeThemed(ResumeDraft resume, bool hasPhoto) {
    final source = resume.source;
    final personal = source['personal_info'] is Map
        ? source['personal_info'] as Map
        : <String, dynamic>{};
    final job = source['job_expectation'] is Map
        ? source['job_expectation'] as Map
        : <String, dynamic>{};
    final aside = <String>{};
    if (theme.sidebar != null) {
      aside.addAll(sidebar(resume, personal, source, hasPhoto));
      if (!theme.sidebar!.header) sidebarHeader(resume, job);
    } else if (theme.splitHeader) {
      splitHeader(resume, personal, job, hasPhoto);
    } else {
      themedHeader(resume, personal, hasPhoto);
    }
    for (final module in resumeModuleOrder(source)) {
      switch (module) {
        case _ when aside.contains(module):
          break;
        case 'job_expectation' when theme.expectationInHeader:
          break;
        case 'job_expectation':
          themedExpectations(resume, job);
        case 'self_evaluation':
          if (resume.summary.isNotEmpty ||
              meaningful({'rich': job['preference_rich']})) {
            themedSection('self_evaluation', '自我评价');
            void summary() => detail(
              {...job, 'preference': resume.summary},
              'preference',
              fieldPath: 'job_expectation.preference',
            );
            final quotes = theme.summaryQuotes;
            if (theme.summaryFill.a > 0 || quotes.isNotEmpty) {
              final startPage = page, top = y;
              card(
                theme.summaryFill,
                theme.summaryRadius,
                theme.summaryPadding,
                summary,
              );
              if (quotes.isNotEmpty) {
                final size = theme.summaryQuoteSize;
                if (identical(page, startPage)) {
                  graphic(
                    quotes.first,
                    Rect.fromLTWH(left + theme.entryIndent, top, size, size),
                  );
                }
                graphic(
                  quotes.last,
                  Rect.fromLTWH(left + width - size, y - size, size, size),
                );
              }
            } else {
              indented(theme.entryIndent, summary);
            }
          }
        case 'educations':
          themedEntries(
            source,
            'educations',
            '教育经历',
            'institution',
            ['degree', 'field_of_study'],
            ['campus_experience', 'thesis_title', 'thesis_description'],
            fallback: resume.education,
          );
        case 'work_experiences':
          themedEntries(
            source,
            'work_experiences',
            '工作经历',
            'company',
            ['position', 'industry'],
            ['description'],
            fallback: resume.experience,
          );
        case 'projects':
          themedEntries(
            source,
            'projects',
            '项目经历',
            'name',
            ['role', 'url'],
            ['description', 'achievements'],
          );
        case 'skills':
          themedSkills(resume, entries(source['skills']));
        case 'certifications':
          themedCertifications(source);
      }
    }
  }
}

/// A filled card that may continue across pages; each page gets its own
/// segment so the fill never covers the page margins.
class _ResumeBox {
  _ResumeBox(
    this.left,
    this.width,
    this.color,
    this.radius,
    this.padding,
    this.top,
  );
  final double left, width, radius;
  final Color color;
  final EdgeInsets padding;
  double top;

  void close(ResumeSheet page, double bottom) {
    if (bottom <= top || color.a == 0) return;
    page.decorations.insert(
      0,
      ResumeFillDecoration(
        Rect.fromLTRB(left, top, left + width, bottom),
        color,
        radius,
      ),
    );
  }
}

class ResumeReviewHighlight {
  const ResumeReviewHighlight({
    required this.key,
    required this.fieldPath,
    required this.text,
    required this.color,
    required this.label,
    this.isWavy = false,
    this.colorText = false,
    this.originalText,
    this.sourceText,
    this.statusLabel,
    this.commentCount = 0,
  });
  final String key, fieldPath, text, label;
  final Color color;
  final bool isWavy;
  final bool colorText;
  final String? originalText, sourceText, statusLabel;

  ResumeReviewHighlight copyWith({String? text, Color? color}) =>
      ResumeReviewHighlight(
        key: key,
        fieldPath: fieldPath,
        text: text ?? this.text,
        color: color ?? this.color,
        label: label,
        isWavy: isWavy,
        colorText: colorText,
        originalText: originalText,
        sourceText: sourceText,
        statusLabel: statusLabel,
        commentCount: commentCount,
      );
  final int commentCount;
}

class ResumeReviewRegion {
  ResumeReviewRegion(this.rect, this.highlights, {List<Rect>? waveRects})
    : waveRects = waveRects ?? [];
  Rect rect;
  final List<ResumeReviewHighlight> highlights;
  // Keep each selected line's bounds separate from the larger hit target.
  final List<Rect> waveRects;
}

List<Rect> _mergeReviewLineRects(Iterable<Rect> rects) {
  final sorted = rects.toList()
    ..sort((a, b) {
      final line = a.top.compareTo(b.top);
      return line == 0 ? a.left.compareTo(b.left) : line;
    });
  final merged = <Rect>[];
  for (final rect in sorted) {
    if (merged.isNotEmpty) {
      final previous = merged.last;
      if ((previous.top - rect.top).abs() < .01 &&
          (previous.bottom - rect.bottom).abs() < .01 &&
          rect.left <= previous.right + .01) {
        merged[merged.length - 1] = previous.expandToInclude(rect);
        continue;
      }
    }
    merged.add(rect);
  }
  return merged;
}

List<List<ResumeReviewRegion>> resumeReviewRegions(
  ResumeDocument document,
  List<ResumeReviewHighlight> highlights, {
  bool fallbackToField = true,
}) {
  final pages = List.generate(
    document.pages.length,
    (_) => <ResumeReviewRegion>[],
  );
  for (final highlight in highlights) {
    // Underlines [boxes] of [run], clipped to the run's visible slice.
    void addWaves(int index, ResumeInk run, Iterable<TextBox> boxes) {
      final area = Rect.fromLTWH(
        run.position.dx,
        run.position.dy,
        run.text.width,
        run.height,
      );
      for (final box in boxes) {
        final rect = box.toRect().shift(
          run.position - Offset(0, run.sourceTop),
        );
        if (!rect.overlaps(area)) continue;
        final clipped = rect.intersect(area);
        if (clipped.isEmpty) continue;
        pages[index].add(
          ResumeReviewRegion(
            clipped.inflate(2),
            [highlight],
            waveRects: [clipped],
          ),
        );
      }
    }

    final matches = <(int, ResumeInk)>[];
    for (var p = 0; p < document.pages.length; p++) {
      for (final run in document.pages[p].ink) {
        if (run.fieldPath == highlight.fieldPath && !run.privacyMasked) {
          matches.add((p, run));
        }
      }
    }
    var found = false;
    if (highlight.isWavy || highlight.colorText) {
      // Historical feedback identifies a whole field rather than a quote.
      // Underline its rendered text, including rich blocks and page clips.
      if (highlight.text.trim().isEmpty) {
        for (final (index, run) in matches) {
          final length = run.text.text!.toPlainText().length;
          addWaves(
            index,
            run,
            run.text.getBoxesForSelection(
              TextSelection(baseOffset: 0, extentOffset: length),
              boxHeightStyle: highlight.colorText
                  ? ui.BoxHeightStyle.tight
                  : ui.BoxHeightStyle.max,
            ),
          );
        }
        continue;
      }
      TextPainter? matchedPainter;
      var matchedStart = -1;
      var occurrenceCount = 0;
      final counted = <TextPainter>{};
      for (final (_, run) in matches) {
        if (!counted.add(run.text)) continue;
        final text = run.text.text!.toPlainText();
        var cursor = 0;
        while (cursor <= text.length - highlight.text.length) {
          final start = text.indexOf(highlight.text, cursor);
          if (start < 0) break;
          occurrenceCount++;
          matchedPainter = run.text;
          matchedStart = start;
          cursor = start + 1;
        }
      }
      // Never assign one comment to an arbitrary repeated sentence.
      if (occurrenceCount != 1 || matchedPainter == null) continue;
      final boxes = matchedPainter.getBoxesForSelection(
        TextSelection(
          baseOffset: matchedStart,
          extentOffset: matchedStart + highlight.text.length,
        ),
        // Font fallback and rich spans can produce several boxes on one line.
        // Use the line's height so every wave segment shares its baseline.
        boxHeightStyle: highlight.colorText
            ? ui.BoxHeightStyle.tight
            : ui.BoxHeightStyle.max,
      );
      for (final (index, run) in matches) {
        if (!identical(run.text, matchedPainter)) continue;
        addWaves(index, run, boxes);
      }
      continue;
    }
    for (final (index, run) in matches) {
      final text = run.text.text!.toPlainText();
      final parts = text.contains(highlight.text) && highlight.text.isNotEmpty
          ? [highlight.text]
          : highlight.text
                .split('\n')
                .where((v) => v.trim().isNotEmpty)
                .toList();
      final area = Rect.fromLTWH(
        run.position.dx,
        run.position.dy,
        run.text.width,
        run.height,
      );
      for (final part in parts) {
        if (part.isEmpty) continue;
        var start = text.indexOf(part);
        while (start >= 0) {
          for (final box in run.text.getBoxesForSelection(
            TextSelection(baseOffset: start, extentOffset: start + part.length),
          )) {
            final rect = box.toRect().shift(
              run.position - Offset(0, run.sourceTop),
            );
            if (rect.overlaps(area)) {
              final clipped = rect.intersect(area);
              if (!clipped.isEmpty) {
                pages[index].add(
                  ResumeReviewRegion(clipped.inflate(2), [highlight]),
                );
                found = true;
              }
            }
          }
          start = text.indexOf(part, start + part.length);
        }
      }
    }
    if (!found && fallbackToField) {
      // Keep changed or historical text reviewable without highlighting another field.
      for (final (index, run) in matches) {
        pages[index].add(
          ResumeReviewRegion(
            Rect.fromLTWH(
              run.position.dx,
              run.position.dy,
              run.text.width,
              run.height,
            ).inflate(2),
            [highlight],
          ),
        );
      }
    }
  }
  for (final regions in pages) {
    for (var i = 0; i < regions.length; i++) {
      for (var j = i + 1; j < regions.length;) {
        final a = regions[i], b = regions[j];
        final bothWavy = a.waveRects.isNotEmpty && b.waveRects.isNotEmpty;
        final samePaint =
            bothWavy &&
                a.highlights.first.colorText == b.highlights.first.colorText &&
                a.highlights.first.color == b.highlights.first.color ||
            a.waveRects.isEmpty && b.waveRects.isEmpty;
        // Accepted edits remain independent press targets, even when adjacent.
        final sameAcceptedEdit =
            !a.highlights.first.colorText ||
            a.highlights.first.key == b.highlights.first.key;
        if (samePaint &&
            sameAcceptedEdit &&
            a.rect.overlaps(b.rect) &&
            ((a.rect.center.dy - b.rect.center.dy).abs() < 4 ||
                a.rect.contains(b.rect.center) ||
                b.rect.contains(a.rect.center))) {
          a.rect = a.rect.expandToInclude(b.rect);
          for (final mark in b.highlights) {
            if (!a.highlights.any((v) => v.key == mark.key)) {
              a.highlights.add(mark);
            }
          }
          for (final rect in b.waveRects) {
            if (!a.waveRects.contains(rect)) a.waveRects.add(rect);
          }
          regions.removeAt(j);
        } else {
          j++;
        }
      }
    }
    for (final region in regions) {
      if (region.highlights.first.colorText) continue;
      final lines = _mergeReviewLineRects(region.waveRects);
      region.waveRects
        ..clear()
        ..addAll(lines);
    }
  }
  return pages;
}

void paintResumeReviewWash(Canvas canvas, ResumeReviewRegion region) {
  if (region.waveRects.isNotEmpty) return;
  final r = region.rect;
  final color = region.highlights.first.color;
  final path = Path()
    ..moveTo(r.left - 1, r.top + 2)
    ..quadraticBezierTo(r.left + r.width * .2, r.top - 1, r.center.dx, r.top)
    ..quadraticBezierTo(r.right - 2, r.top - 1, r.right + 1, r.top + 3)
    ..lineTo(r.right + 1, r.bottom - 2)
    ..quadraticBezierTo(r.right - 1, r.bottom + 1, r.center.dx, r.bottom)
    ..quadraticBezierTo(r.left + 2, r.bottom + 2, r.left - 1, r.bottom - 2)
    ..close();
  canvas.drawPath(
    path,
    Paint()
      ..color = color.withValues(alpha: .2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2),
  );
  canvas.drawPath(
    path,
    Paint()
      ..shader = ui.Gradient.linear(
        r.topLeft,
        r.bottomRight,
        [
          color.withValues(alpha: .26),
          color.withValues(alpha: .14),
          color.withValues(alpha: .23),
        ],
        [.0, .55, 1],
      ),
  );
}

void paintResumeReviewWave(Canvas canvas, ResumeReviewRegion region) {
  if (region.waveRects.isEmpty || region.highlights.first.colorText) return;
  final paint = Paint()
    ..color = region.highlights.first.color
    ..style = PaintingStyle.stroke
    ..strokeWidth = .9
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  for (final rect in region.waveRects) {
    final baseline = rect.bottom + 1.2;
    final path = Path()..moveTo(rect.left, baseline);
    var x = rect.left;
    var direction = 1.0;
    while (x < rect.right) {
      final end = math.min(x + 2.5, rect.right);
      path.quadraticBezierTo(
        (x + end) / 2,
        baseline + direction * 1.5,
        end,
        baseline,
      );
      x = end;
      direction = -direction;
    }
    canvas.drawPath(path, paint);
  }
}

// A small visual badge sits after the quote, with the page gutter as a
// fallback when the following text leaves no room. Hit padding is separate.
Rect resumeCommentBadgeRect({
  required ResumeSheet page,
  required Rect anchor,
  required double scale,
  required double width,
  required int count,
  double? labelWidth,
  List<Rect> occupied = const [],
}) {
  final badgeWidth =
      labelWidth ??
      (count > 99
          ? 24.0
          : count > 9
          ? 19.0
          : 14.0);
  const height = 14.0;
  final obstacles = <Rect>[];
  for (final run in page.ink) {
    final clip = Rect.fromLTWH(
      run.position.dx,
      run.position.dy,
      run.text.width,
      run.height,
    );
    for (final box in run.text.getBoxesForSelection(
      TextSelection(
        baseOffset: 0,
        extentOffset: run.text.text!.toPlainText().length,
      ),
    )) {
      final rect = box.toRect().shift(run.position - Offset(0, run.sourceTop));
      if (!rect.overlaps(clip)) continue;
      final visible = rect.intersect(clip);
      obstacles.add(
        Rect.fromLTRB(
          visible.left * scale,
          visible.top * scale,
          visible.right * scale,
          visible.bottom * scale,
        ),
      );
    }
  }
  final y = (anchor.center.dy * scale - height / 2).clamp(
    0.0,
    resumePaperSize.height * scale - height,
  );
  bool fits(Rect rect) =>
      rect.left >= 0 &&
      rect.right <= width &&
      !obstacles.any((ink) => ink.overlaps(rect.inflate(1))) &&
      !occupied.any((other) => other.inflate(2).overlaps(rect));
  var inline = Rect.fromLTWH(anchor.right * scale + 3, y, badgeWidth, height);
  // Keep adjacent comment counts and rewrite statuses together when the
  // line has room; otherwise use the text-safe page gutter.
  while (occupied.any((other) => other.inflate(2).overlaps(inline))) {
    final collision = occupied.firstWhere(
      (other) => other.inflate(2).overlaps(inline),
    );
    inline = Rect.fromLTWH(
      collision.right + 3,
      inline.top,
      inline.width,
      inline.height,
    );
  }
  if (fits(inline)) return inline;
  final gutter = Rect.fromLTWH(width - badgeWidth - 3, y, badgeWidth, height);
  if (fits(gutter)) return gutter;
  for (
    var distance = 16.0;
    distance < resumePaperSize.height * scale;
    distance += 16
  ) {
    for (final offset in [distance, -distance]) {
      final candidate = gutter.shift(Offset(0, offset));
      if (candidate.top >= 0 &&
          candidate.bottom <= resumePaperSize.height * scale &&
          fits(candidate)) {
        return candidate;
      }
    }
  }
  return gutter;
}

class ResumeDocumentView extends StatefulWidget {
  const ResumeDocumentView({
    super.key,
    required this.resume,
    this.store,
    this.onAnnotate,
    this.onAnnotationSelected,
    this.onOriginalShown,
    this.reviewHighlights = const [],
    this.reviewChanges = const [],
    this.reviewNotes = const [],
    this.reviewNoteBuilder,
    this.onReviewTap,
    this.theme,
  });
  final void Function(String fieldPath, String selectedText, bool replace)?
  onAnnotate;
  final ResumeTheme? theme;
  final VoidCallback? onAnnotationSelected, onOriginalShown;
  final ResumeDraft resume;
  final AppStore? store;
  final List<ResumeReviewHighlight> reviewHighlights;
  final List<ResumeReviewChange> reviewChanges;
  final List<ResumeReviewNote> reviewNotes;
  final Widget Function(BuildContext, String)? reviewNoteBuilder;
  final ValueChanged<List<ResumeReviewHighlight>>? onReviewTap;
  @override
  State<ResumeDocumentView> createState() => ResumeDocumentViewState();
}

class ResumeDocumentViewState extends State<ResumeDocumentView>
    with SingleTickerProviderStateMixin {
  late final ResumeSystemFontObserver systemFonts;
  final transform = TransformationController();
  ResumeDocument? document;
  ResumeDocument? originalPreview;
  ResumeDocument? get displayedDocument => originalPreview ?? document;
  int? originalPointer;
  ResumeReviewHighlight? originalMark;

  void showOriginal(PointerDownEvent event, List<ResumeReviewHighlight> marks) {
    if (originalPointer != null || pinching || pointers.isNotEmpty) return;
    final mark = marks.where((mark) => mark.originalText != null).firstOrNull;
    if (mark == null) return;
    setState(() {
      originalPointer = event.pointer;
      originalMark = mark;
      originalPreview = ResumeDocument(
        widget.resume,
        photoURL: photoURL,
        theme: widget.theme,
        reviewNotes: widget.reviewNotes,
        reviewChanges: [
          ...widget.reviewChanges,
          ResumeReviewChange(
            key: mark.key,
            fieldPath: mark.fieldPath,
            original: mark.text,
            replacement: mark.originalText!,
            previewOnly: true,
          ),
        ],
      );
    });
    widget.onOriginalShown?.call();
  }

  void hideOriginal() {
    if (originalPointer == null) return;
    setState(() {
      originalPointer = null;
      originalMark = null;
      originalPreview?.dispose();
      originalPreview = null;
    });
  }

  String? cacheKey;
  String photoURL = '';
  bool zoomed = false;
  Offset doubleTapPoint = Offset.zero;
  final pageScroll = ScrollController();
  final pointers = <int, Offset>{};
  Matrix4 pinchTransform = Matrix4.identity();
  Offset pinchFocal = Offset.zero;
  double pinchDistance = 1;
  bool pinching = false;
  bool panning = false;
  ResumeInk? selectedRegion;
  Rect? annotationAnchor;
  Offset pointerOrigin = Offset.zero;
  ScrollHoldController? scrollHold;
  VelocityTracker? velocity;
  late final AnimationController inertia;
  Offset flingVelocity = Offset.zero;
  double flingPosition = 0;
  bool guidanceScrollLocked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    guidanceScrollLocked = GuidanceScrollLock.isLocked(context);
    if (guidanceScrollLocked) {
      inertia.stop();
      scrollHold?.cancel();
      scrollHold = null;
      pointers.clear();
      pinching = panning = false;
      velocity = null;
    }
  }

  Future<void> selectAnnotationRegion(ResumeInk run) async {
    if (pinching || panning || run.privacyMasked || widget.onAnnotate == null) {
      return;
    }
    final text = run.text.text!.toPlainText().trim();
    if (text.isEmpty) return;
    setState(() => selectedRegion = run);
    widget.onAnnotationSelected?.call();
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final origin = overlay.localToGlobal(Offset.zero);
    final anchor =
        (annotationAnchor ??
                Rect.fromCenter(
                  center: overlay.size.center(origin),
                  width: 1,
                  height: 1,
                ))
            .shift(-origin);
    final choice = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '取消选中',
      barrierColor: Colors.transparent,
      transitionDuration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 160),
      transitionBuilder: (_, animation, secondaryAnimation, child) =>
          FadeTransition(opacity: animation, child: child),
      pageBuilder: (context, animation, secondaryAnimation) =>
          _AnnotationBubble(anchor: anchor, animation: animation),
    );
    if (!mounted) return;
    final valid = identical(selectedRegion, run);
    clearAnnotationSelection();
    if (choice != null && valid) {
      widget.onAnnotate?.call(run.fieldPath!, text, choice);
    }
  }

  void clearAnnotationSelection() {
    if (selectedRegion == null) return;
    setState(() => selectedRegion = null);
  }

  Size get viewportSize => (context.findRenderObject() as RenderBox).size;

  /// Resolve paper coordinates before a distant page has been built lazily.
  /// Record keys distinguish identical quotes and different reviewers.
  bool focusReview(String key, {double alignment = .18}) {
    final current = document;
    if (current == null || !pageScroll.hasClients) return false;
    (int, Rect)? target;
    for (var page = 0; page < current.pages.length; page++) {
      final note = current.pages[page].reviewNotes
          .where((note) => note.note.key == key)
          .firstOrNull;
      if (note != null) {
        target = (page, note.rect);
        break;
      }
    }
    if (target == null) {
      final regions = resumeReviewRegions(
        current,
        widget.reviewHighlights,
        fallbackToField: widget.reviewNotes.isEmpty,
      );
      for (var page = 0; page < regions.length; page++) {
        final region = regions[page]
            .where((region) => region.highlights.any((mark) => mark.key == key))
            .firstOrNull;
        if (region != null) {
          target = (page, region.rect);
          break;
        }
      }
    }
    if (target == null) return false;
    inertia.stop();
    if (zoomed) resetZoom();
    final scale =
        math.min(680.0, viewportSize.width - resumeSheetInset) /
        resumePaperSize.width;
    final position = pageScroll.position;
    final offset =
        16 +
        target.$1 * (resumePaperSize.height * scale + 16) +
        target.$2.top * scale -
        position.viewportDimension * alignment;
    pageScroll.jumpTo(
      offset.clamp(position.minScrollExtent, position.maxScrollExtent),
    );
    return true;
  }

  void setTransform(double scale, Offset translation) {
    final size = viewportSize;
    final x = translation.dx.clamp(size.width * (1 - scale), 0.0);
    final y = translation.dy.clamp(size.height * (1 - scale), 0.0);
    transform.value = Matrix4.diagonal3Values(scale, scale, 1)
      ..setTranslationRaw(x, y, 0);
    final nextZoomed = scale > 1.001;
    if (zoomed != nextZoomed) setState(() => zoomed = nextZoomed);
  }

  void panDocument(Offset delta) {
    final matrix = transform.value;
    final scale = matrix.getMaxScaleOnAxis();
    final target = Offset(matrix.storage[12], matrix.storage[13]) + delta;
    final y = target.dy.clamp(viewportSize.height * (1 - scale), 0.0);
    final overflow = target.dy - y;
    if (overflow != 0 && pageScroll.hasClients) {
      final position = pageScroll.position;
      final offset = (position.pixels - overflow / scale).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );
      if (offset != position.pixels) pageScroll.jumpTo(offset);
    }
    setTransform(scale, Offset(target.dx, y));
  }

  void pointerDown(PointerDownEvent event) {
    inertia.stop();
    if (guidanceScrollLocked) return;
    pointers[event.pointer] = event.localPosition;
    if (pointers.length == 1) {
      pointerOrigin = event.localPosition;
      panning = false;
      FocusManager.instance.primaryFocus?.unfocus();
      velocity = VelocityTracker.withKind(event.kind)
        ..addPosition(event.timeStamp, event.localPosition);
    } else if (pointers.length == 2 && originalPointer == null) {
      pinching = true;
      FocusManager.instance.primaryFocus?.unfocus();
      final points = pointers.values.toList();
      pinchDistance = math.max(1.0, (points[0] - points[1]).distance);
      pinchFocal = (points[0] + points[1]) / 2;
      pinchTransform = Matrix4.copy(transform.value);
      if (pageScroll.hasClients) {
        scrollHold = pageScroll.position.hold(() => scrollHold = null);
      }
      setState(() {});
    }
  }

  void pointerMove(PointerMoveEvent event) {
    if (guidanceScrollLocked) return;
    final previous = pointers[event.pointer];
    if (previous == null) return;
    pointers[event.pointer] = event.localPosition;
    // A held preview follows the initiating pointer until up/cancel, even
    // outside the text. Keep the document still while the finger moves aside.
    if (originalPointer != null) return;
    if (pointers.length >= 2) {
      final points = pointers.values.take(2).toList();
      final focal = (points[0] + points[1]) / 2;
      final oldScale = pinchTransform.getMaxScaleOnAxis();
      final next = (oldScale * (points[0] - points[1]).distance / pinchDistance)
          .clamp(1.0, 4.0);
      final ratio = next / oldScale;
      setTransform(
        next,
        Offset(
          focal.dx + (pinchTransform.storage[12] - pinchFocal.dx) * ratio,
          focal.dy + (pinchTransform.storage[13] - pinchFocal.dy) * ratio,
        ),
      );
    } else if (!pinching && zoomed) {
      velocity?.addPosition(event.timeStamp, event.localPosition);
      if (!panning &&
          (event.localPosition - pointerOrigin).distance > kTouchSlop) {
        panning = true;
      }
      if (panning) panDocument(event.localPosition - previous);
    }
  }

  void pointerEnd(PointerEvent event) {
    if (event.pointer == originalPointer) hideOriginal();
    pointers.remove(event.pointer);
    if (pointers.isNotEmpty) return;
    scrollHold?.cancel();
    scrollHold = null;
    if (!pinching && panning && event is PointerUpEvent) {
      final speed = velocity?.getVelocity().pixelsPerSecond ?? Offset.zero;
      if (speed.distance > 100) {
        flingVelocity = speed;
        flingPosition = 0;
        inertia.value = 0;
        inertia.animateWith(FrictionSimulation(.135, 0, 1));
      }
    }
    if (pinching) setState(() => pinching = false);
    panning = false;
    velocity = null;
  }

  void changeZoom(double factor, {Offset? focalPoint}) {
    final current = transform.value;
    final oldScale = current.getMaxScaleOnAxis();
    final next = (oldScale * factor).clamp(1.0, 4.0);
    if (next == 1) {
      resetZoom();
      return;
    }
    final box = context.findRenderObject() as RenderBox?;
    final focal = focalPoint ?? (box?.size.center(Offset.zero) ?? Offset.zero);
    final ratio = next / oldScale;
    setTransform(
      next,
      Offset(
        focal.dx + (current.storage[12] - focal.dx) * ratio,
        focal.dy + (current.storage[13] - focal.dy) * ratio,
      ),
    );
  }

  void resetZoom() {
    inertia.stop();
    transform.value = Matrix4.identity();
    setState(() => zoomed = false);
  }

  @override
  void initState() {
    super.initState();
    systemFonts = ResumeSystemFontObserver(() {
      hideOriginal();
      setState(() => cacheKey = null);
    });
    inertia = AnimationController.unbounded(vsync: this)
      ..addListener(() {
        final distance = inertia.value - flingPosition;
        flingPosition = inertia.value;
        if (distance != 0) panDocument(flingVelocity * distance);
      });
    photoURL = widget.resume.photoURL;
    loadPhoto();
  }

  Future<void> loadPhoto() async {
    final store = widget.store;
    if (store == null || widget.resume.id <= 0) return;
    final epoch = store.epoch;
    final id = widget.resume.id;
    final revision = widget.resume.revision;
    try {
      final response = await store.request('GetResumesId', path: {'id': '$id'});
      final url = response.data['photo_url'];
      if (mounted &&
          store.epoch == epoch &&
          widget.resume.id == id &&
          widget.resume.revision == revision &&
          url is String &&
          Uri.tryParse(url)?.scheme == 'https') {
        setState(() {
          photoURL = url;
        });
      }
    } catch (_) {
      // Preserve existing photo metadata; its loading error offers a retry.
    }
  }

  @override
  void didUpdateWidget(covariant ResumeDocumentView oldWidget) {
    super.didUpdateWidget(oldWidget);
    hideOriginal();
    if (oldWidget.resume.id != widget.resume.id ||
        oldWidget.resume.revision != widget.resume.revision ||
        oldWidget.resume.photoURL != widget.resume.photoURL) {
      photoURL = widget.resume.photoURL;
      loadPhoto();
    }
  }

  @override
  void dispose() {
    systemFonts.dispose();
    inertia.dispose();
    scrollHold?.cancel();
    pageScroll.dispose();
    document?.dispose();
    originalPreview?.dispose();
    transform.dispose();
    super.dispose();
  }

  /// Downloads the resume photo and lays out a fresh export document, then
  /// hands both to [build]. Both are disposed afterwards. [build] must call
  /// `check` between steps so cancellation stops the export.
  Future<T> _withExportDocument<T>({
    required bool Function() isCancelled,
    required ValueChanged<String> onProgress,
    required Future<T> Function(
      ResumeDocument exportDocument,
      ui.Image? photo,
      void Function() check,
    )
    build,
  }) async {
    final resume = widget.resume.copy();
    final store = widget.store;
    final epoch = store?.epoch;
    const font = resumeDocumentFontFamily;
    void check() {
      if (!mounted || isCancelled() || store?.epoch != epoch) {
        throw const ApiFailure('导出已取消');
      }
    }

    check();
    ui.Image? photo;
    ResumeDocument? exportDocument;
    try {
      var url = photoURL;
      if (resume.photoFileID > 0 || url.isNotEmpty) {
        onProgress('正在准备简历照片…');
        if (store != null && resume.id > 0) {
          final response = await store.request(
            'GetResumesId',
            path: {'id': '${resume.id}'},
          );
          check();
          if (response.data['photo_file_id'] != null &&
              integer(response.data['photo_file_id']) != resume.photoFileID) {
            throw const ApiFailure('简历照片已更新，请刷新预览后导出');
          }
          url = response.data['photo_url'] as String? ?? url;
        }
        if (Uri.tryParse(url)?.scheme != 'https') {
          throw const ApiFailure('简历照片暂不可用，请重试');
        }
        final ready = Completer<ui.Image>();
        final stream = ResumePhotoImage(
          url,
          fileID: resume.photoFileID,
        ).resolve(ImageConfiguration.empty);
        late ImageStreamListener listener;
        listener = ImageStreamListener(
          (info, _) {
            if (!ready.isCompleted) ready.complete(info.image.clone());
          },
          onError: (_, _) {
            if (!ready.isCompleted) {
              ready.completeError(const ApiFailure('简历照片下载失败，请重试'));
            }
          },
        );
        stream.addListener(listener);
        try {
          photo = await ready.future.timeout(const Duration(seconds: 30));
        } finally {
          stream.removeListener(listener);
        }
        check();
      }
      exportDocument = ResumeDocument(
        resume,
        fontFamily: font,
        photoURL: url,
        theme: widget.theme,
      );
      return await build(exportDocument, photo, check);
    } finally {
      photo?.dispose();
      exportDocument?.dispose();
    }
  }

  Future<ResumeExportLayout> captureLayout({
    required bool Function() isCancelled,
    required ValueChanged<String> onProgress,
  }) => _withExportDocument(
    isCancelled: isCancelled,
    onProgress: onProgress,
    build: (exportDocument, photo, check) async {
      final pages = <ResumeExportPage>[];
      final wordPages = <ResumeExportPage>[];
      for (var index = 0; index < exportDocument.pages.length; index++) {
        check();
        onProgress('正在准备第 ${index + 1}/${exportDocument.pages.length} 页文字…');
        Uint8List? portrait;
        final rect = exportDocument.pages[index].photo;
        if (photo != null && rect != null) {
          final recorder = ui.PictureRecorder();
          final canvas = Canvas(recorder)..scale(3);
          canvas.clipPath(
            exportDocument.theme.photoPath(Offset.zero & rect.size),
          );
          paintImage(
            canvas: canvas,
            rect: Offset.zero & rect.size,
            image: photo,
            fit: BoxFit.cover,
            alignment: const Alignment(0, -.35),
          );
          final picture = recorder.endRecording();
          final image = await picture.toImage(
            (rect.width * 3).round(),
            (rect.height * 3).round(),
          );
          picture.dispose();
          try {
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            if (bytes == null) throw const ApiFailure('头像导出失败，请重试');
            portrait = bytes.buffer.asUint8List(
              bytes.offsetInBytes,
              bytes.lengthInBytes,
            );
          } finally {
            image.dispose();
          }
        }
        pages.add(
          resumeExportSheet(
            exportDocument,
            index,
            portrait: portrait,
            backdrop: await resumeExportBackdrop(exportDocument, index),
          ),
        );
        if (!exportDocument.theme.isStandard) {
          wordPages.add(
            await resumeExportWordSheet(
              exportDocument,
              index,
              portrait: portrait,
            ),
          );
        }
        await Future<void>.delayed(Duration.zero);
      }
      check();
      final margin = exportDocument.theme.margin;
      return ResumeExportLayout(
        pages,
        wordPageNumbers: exportDocument.theme.pageNumbers,
        requiresWordFlow: exportDocument.theme.isStandard,
        // Themes flow in Word like the default template; PDF keeps the
        // pages exactly as previewed.
        wordLayout: wordPages.isEmpty
            ? null
            : ResumeExportLayout(
                wordPages,
                requiresWordFlow: true,
                nativeFlowGeometry: true,
                wordRows: true,
                wordPageNumbers: exportDocument.theme.pageNumbers,
                wordContinuationBackground: await _resumeRaster(
                  resumePaperSize,
                  (canvas) => paintResumePaper(canvas, exportDocument, 1),
                ),
                wordMargins: {
                  'top': margin.top,
                  'right': margin.right,
                  'bottom': margin.bottom,
                  'left': margin.left,
                },
              ),
      );
    },
  );

  Future<List<Uint8List>> capturePages({
    required bool Function() isCancelled,
    required ValueChanged<String> onProgress,
  }) => _withExportDocument(
    isCancelled: isCancelled,
    onProgress: onProgress,
    build: (exportDocument, photo, check) async {
      final pages = <Uint8List>[];
      // 288 dpi: paint the same text, clips, photo and footer as the preview.
      const scale = 4.0;
      for (var index = 0; index < exportDocument.pages.length; index++) {
        check();
        onProgress('正在生成第 ${index + 1}/${exportDocument.pages.length} 页…');
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder)..scale(scale);
        canvas.drawRect(
          Offset.zero & resumePaperSize,
          Paint()..color = Colors.white,
        );
        paintResumeSheet(
          canvas,
          exportDocument,
          index,
          layer: ResumeSheetLayer.paper,
        );
        final rect = exportDocument.pages[index].photo;
        if (photo != null && rect != null) {
          canvas.save();
          canvas.clipPath(exportDocument.theme.photoPath(rect));
          paintImage(
            canvas: canvas,
            rect: rect,
            image: photo,
            fit: BoxFit.cover,
            alignment: const Alignment(0, -.35),
          );
          canvas.restore();
        }
        paintResumeSheet(
          canvas,
          exportDocument,
          index,
          layer: ResumeSheetLayer.ink,
        );
        final picture = recorder.endRecording();
        final raster = await picture.toImage(
          (resumePaperSize.width * scale).round(),
          (resumePaperSize.height * scale).round(),
        );
        picture.dispose();
        try {
          final data = await raster.toByteData(format: ui.ImageByteFormat.png);
          if (data == null) throw const ApiFailure('页面生成失败，请重试');
          pages.add(
            data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
          );
        } finally {
          raster.dispose();
        }
        await Future<void>.delayed(Duration.zero);
      }
      check();
      return pages;
    },
  );

  @override
  Widget build(BuildContext context) {
    final resume = widget.resume;
    // On screen the resume is set in the system font.
    const String? font = null;
    final key = ResumeDocument.layoutKey(
      resume,
      photoURL: photoURL,
      theme: widget.theme,
      reviewNotes: widget.reviewNotes,
      reviewChanges: widget.reviewChanges,
    );
    if (key != cacheKey) {
      selectedRegion = null;
      document?.dispose();
      final layoutTimer = Stopwatch()..start();
      document = ResumeDocument(
        resume,
        fontFamily: font,
        photoURL: photoURL,
        reviewChanges: widget.reviewChanges,
        reviewNotes: widget.reviewNotes,
        theme: widget.theme,
      );
      if (traceResumePreview) {
        debugPrint(
          'BOJIAN_RESUME id=${resume.id} stage=standard-layout elapsed_us=${layoutTimer.elapsedMicroseconds}',
        );
      }
      cacheKey = key;
    }
    final displayed = displayedDocument!;
    final pages = displayed.pages;
    final reviewRegions = resumeReviewRegions(
      document!,
      widget.reviewHighlights,
      fallbackToField: widget.reviewNotes.isEmpty,
    );
    while (reviewRegions.length < pages.length) {
      reviewRegions.add([]);
    }
    // Re-anchor every annotation to the displayed text; only the pressed
    // passage changes. Keep unrelated accepted colors, waves and badges.
    final displayedHighlights = [
      for (final mark in widget.reviewHighlights)
        if (mark.key == originalMark?.key)
          mark.copyWith(text: mark.originalText!, color: resumePaperInk)
        else if (mark.commentCount > 0 &&
            originalMark != null &&
            mark.fieldPath == originalMark!.fieldPath &&
            originalMark!.text.allMatches(mark.text).length == 1)
          mark.copyWith(
            text: mark.text.replaceFirst(
              originalMark!.text,
              originalMark!.originalText!,
            ),
          )
        else
          mark,
    ];
    final paintedRegions = originalPreview == null
        ? reviewRegions
        : resumeReviewRegions(
            displayed,
            displayedHighlights,
            fallbackToField: widget.reviewNotes.isEmpty,
          );
    final badges = <int, List<(ResumeReviewHighlight, Rect)>>{};
    for (final mark in [
      ...displayedHighlights.where(
        (mark) =>
            mark.commentCount > 0 &&
            !widget.reviewNotes.any((note) => note.key == mark.key),
      ),
      ...displayedHighlights.where((mark) => mark.statusLabel != null),
    ]) {
      for (var page = 0; page < paintedRegions.length; page++) {
        final regions = paintedRegions[page].where(
          (region) => region.highlights.any((v) => v.key == mark.key),
        );
        if (regions.isEmpty) continue;
        final quoteRects =
            regions
                .expand(
                  (region) => region.waveRects.isEmpty
                      ? [region.rect]
                      : region.waveRects,
                )
                .toList()
              ..sort(
                (a, b) => a.top == b.top
                    ? a.left.compareTo(b.left)
                    : a.top.compareTo(b.top),
              );
        badges.putIfAbsent(page, () => []).add((mark, quoteRects.last));
        break;
      }
    }
    return ColoredBox(
      color: context.colors.canvas,
      child: Listener(
        key: const ValueKey('resume-gesture-viewport'),
        behavior: HitTestBehavior.opaque,
        onPointerDown: pointerDown,
        onPointerMove: pointerMove,
        onPointerUp: pointerEnd,
        onPointerCancel: pointerEnd,
        child: GestureDetector(
          onTap: widget.onAnnotate == null ? null : clearAnnotationSelection,
          onDoubleTapDown:
              widget.onReviewTap == null && widget.onAnnotate == null
              ? (details) => doubleTapPoint = details.localPosition
              : null,
          onDoubleTap: widget.onReviewTap == null && widget.onAnnotate == null
              ? () {
                  if (zoomed) {
                    resetZoom();
                  } else {
                    changeZoom(2, focalPoint: doubleTapPoint);
                  }
                }
              : null,
          child: ClipRect(
            child: AnimatedBuilder(
              animation: transform,
              builder: (_, child) => Transform(
                transform: transform.value,
                alignment: Alignment.topLeft,
                child: child,
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = math.min(
                    680.0,
                    constraints.maxWidth - resumeSheetInset,
                  );
                  final scale = width / resumePaperSize.width;
                  final placedBadges =
                      <int, List<(ResumeReviewHighlight, Rect)>>{};
                  for (final page in badges.entries) {
                    final placed = <(ResumeReviewHighlight, Rect)>[];
                    for (final badge in page.value) {
                      final rect = resumeCommentBadgeRect(
                        page: pages[page.key],
                        anchor: badge.$2,
                        scale: scale,
                        width: width,
                        count: badge.$1.commentCount,
                        labelWidth: badge.$1.statusLabel == null ? null : 36,
                        occupied: placed.map((value) => value.$2).toList(),
                      );
                      placed.add((badge.$1, rect));
                    }
                    placedBadges[page.key] = placed;
                  }
                  return ListView.builder(
                    controller: pageScroll,
                    physics:
                        guidanceScrollLocked ||
                            zoomed ||
                            pinching ||
                            originalPointer != null
                        ? const NeverScrollableScrollPhysics()
                        : null,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    itemCount: pages.length,
                    itemExtent: resumePaperSize.height * scale + 16,
                    itemBuilder: (context, index) => Center(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Semantics(
                          label:
                              '简历第 ${index + 1} 页，共 ${pages.length} 页\n${pages[index].ink.map((run) => run.visibleText).join('\n')}',
                          child: Container(
                            key: ValueKey('resume-sheet-$index'),
                            width: width,
                            height: resumePaperSize.height * scale,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: Color(0x16000000),
                                  blurRadius: 6,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: RepaintBoundary(
                                    child: CustomPaint(
                                      painter: _SheetPainter(
                                        displayed,
                                        index,
                                        paintedRegions[index],
                                        ResumeSheetLayer.paper,
                                      ),
                                    ),
                                  ),
                                ),
                                if (widget.onReviewTap != null)
                                  for (
                                    var markIndex = 0;
                                    markIndex < reviewRegions[index].length;
                                    markIndex++
                                  )
                                    if (reviewRegions[index][markIndex]
                                        .highlights
                                        .any((mark) => mark.commentCount == 0))
                                      Positioned.fromRect(
                                        rect: Rect.fromLTRB(
                                          reviewRegions[index][markIndex]
                                                  .rect
                                                  .left *
                                              scale,
                                          reviewRegions[index][markIndex]
                                                  .rect
                                                  .top *
                                              scale,
                                          reviewRegions[index][markIndex]
                                                  .rect
                                                  .right *
                                              scale,
                                          reviewRegions[index][markIndex]
                                                  .rect
                                                  .bottom *
                                              scale,
                                        ),
                                        child: Semantics(
                                          button: true,
                                          label:
                                              reviewRegions[index][markIndex]
                                                  .highlights
                                                  .any(
                                                    (mark) =>
                                                        mark.originalText !=
                                                        null,
                                                  )
                                              ? '按住查看原文，松开恢复'
                                              : '查看${reviewRegions[index][markIndex].highlights.where((v) => v.commentCount == 0).map((v) => v.label).toSet().join('与')}',
                                          child: Listener(
                                            key:
                                                reviewRegions[index][markIndex]
                                                    .highlights
                                                    .any(
                                                      (mark) =>
                                                          mark.originalText !=
                                                          null,
                                                    )
                                                ? ValueKey(
                                                    'guidance-compare-region-$index-$markIndex',
                                                  )
                                                : null,
                                            onPointerDown: (event) =>
                                                showOriginal(
                                                  event,
                                                  reviewRegions[index][markIndex]
                                                      .highlights,
                                                ),
                                            child: GestureDetector(
                                              key: ValueKey(
                                                'resume-review-region-$index-$markIndex',
                                              ),
                                              behavior: HitTestBehavior.opaque,
                                              onTap:
                                                  reviewRegions[index][markIndex]
                                                      .highlights
                                                      .any(
                                                        (mark) =>
                                                            mark.originalText !=
                                                            null,
                                                      )
                                                  ? null
                                                  : () => widget.onReviewTap!(
                                                      reviewRegions[index][markIndex]
                                                          .highlights
                                                          .where(
                                                            (mark) =>
                                                                mark.commentCount ==
                                                                0,
                                                          )
                                                          .toList(),
                                                    ),
                                              child: const SizedBox.expand(),
                                            ),
                                          ),
                                        ),
                                      ),
                                if (widget.reviewNoteBuilder != null)
                                  for (final placement
                                      in pages[index].reviewNotes)
                                    Positioned.fromRect(
                                      rect: Rect.fromLTRB(
                                        placement.rect.left * scale,
                                        placement.rect.top * scale,
                                        placement.rect.right * scale,
                                        placement.rect.bottom * scale,
                                      ),
                                      child: widget.reviewNoteBuilder!(
                                        context,
                                        placement.note.key,
                                      ),
                                    ),
                                if (widget.onAnnotate != null &&
                                    index < document!.pages.length)
                                  for (final run in document!.pages[index].ink)
                                    if (run.fieldPath != null &&
                                        !run.privacyMasked)
                                      Positioned(
                                        left: run.position.dx * scale,
                                        top: run.position.dy * scale,
                                        width: run.text.width * scale,
                                        height: run.height * scale,
                                        child: Semantics(
                                          container: true,
                                          button: true,
                                          selected: identical(
                                            selectedRegion?.text,
                                            run.text,
                                          ),
                                          label: '选中区域：${run.visibleText}',
                                          child: Listener(
                                            onPointerDown: (event) {
                                              final point =
                                                  run.position +
                                                  event.localPosition / scale;
                                              showOriginal(
                                                event,
                                                reviewRegions[index]
                                                    .where(
                                                      (region) => region.rect
                                                          .contains(point),
                                                    )
                                                    .expand(
                                                      (region) =>
                                                          region.highlights,
                                                    )
                                                    .toList(),
                                              );
                                            },
                                            child: GestureDetector(
                                              key: ValueKey(
                                                'resume-annotation-region-$index-${document!.pages[index].ink.indexOf(run)}',
                                              ),
                                              behavior: HitTestBehavior.opaque,
                                              onTapDown: (details) {
                                                final zoom = transform.value
                                                    .getMaxScaleOnAxis();
                                                final origin =
                                                    details.globalPosition -
                                                    details.localPosition *
                                                        zoom;
                                                annotationAnchor =
                                                    origin &
                                                    Size(
                                                      run.text.width *
                                                          scale *
                                                          zoom,
                                                      run.height * scale * zoom,
                                                    );
                                              },
                                              onTap: pinching
                                                  ? null
                                                  : () =>
                                                        selectAnnotationRegion(
                                                          run,
                                                        ),
                                              child: DecoratedBox(
                                                decoration: BoxDecoration(
                                                  color:
                                                      identical(
                                                        selectedRegion?.text,
                                                        run.text,
                                                      )
                                                      ? const Color(0x1A007AFF)
                                                      : Colors.transparent,
                                                  borderRadius:
                                                      BorderRadius.circular(3),
                                                  border:
                                                      identical(
                                                        selectedRegion?.text,
                                                        run.text,
                                                      )
                                                      ? Border.all(
                                                          color: const Color(
                                                            0x4D007AFF,
                                                          ),
                                                          width: .8,
                                                        )
                                                      : null,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                for (final badge
                                    in placedBadges[index] ??
                                        <(ResumeReviewHighlight, Rect)>[])
                                  Positioned(
                                    left: badge.$2.left - 5,
                                    top: badge.$2.top - 5,
                                    child: Semantics(
                                      button: badge.$1.statusLabel == null,
                                      label: badge.$1.statusLabel == null
                                          ? '${badge.$1.commentCount}条评论'
                                          : '改写状态：${badge.$1.statusLabel}',
                                      child: GestureDetector(
                                        key: ValueKey(
                                          badge.$1.statusLabel == null
                                              ? 'comment-badge-${badge.$1.key}'
                                              : 'rewrite-status-${badge.$1.key}',
                                        ),
                                        behavior: HitTestBehavior.opaque,
                                        onTap: badge.$1.statusLabel == null
                                            ? () => widget.onReviewTap?.call([
                                                badge.$1,
                                              ])
                                            : null,
                                        child: Padding(
                                          padding: const EdgeInsets.all(5),
                                          child: Container(
                                            width: badge.$2.width,
                                            height: badge.$2.height,
                                            alignment: Alignment.center,
                                            decoration: BoxDecoration(
                                              color: badge.$1.color.withValues(
                                                alpha: .12,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              badge.$1.statusLabel ??
                                                  (badge.$1.commentCount > 99
                                                      ? '99+'
                                                      : '${badge.$1.commentCount}'),
                                              textScaler: TextScaler.noScaling,
                                              style: TextStyle(
                                                color: badge.$1.color,
                                                fontSize:
                                                    badge.$1.statusLabel == null
                                                    ? 9
                                                    : 8.5,
                                                height: 1,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                if (pages[index].photo case final Rect rect)
                                  Positioned(
                                    left: rect.left * scale,
                                    top: rect.top * scale,
                                    width: rect.width * scale,
                                    height: rect.height * scale,
                                    child: ClipPath(
                                      clipper: ResumePhotoClipper(
                                        displayed.theme,
                                        scale,
                                      ),
                                      child:
                                          resume.source['app_privacy_photo'] ==
                                              true
                                          ? Semantics(
                                              label: '简历头像已隐藏',
                                              child: const Center(
                                                child: Text(resumePrivacyMask),
                                              ),
                                            )
                                          : photoURL.isEmpty
                                          ? TextButton(
                                              onPressed: loadPhoto,
                                              child: const FittedBox(
                                                child: Text(
                                                  '照片加载失败\n点击重试',
                                                  textAlign: TextAlign.center,
                                                ),
                                              ),
                                            )
                                          : Image(
                                              image: ResumePhotoImage(
                                                photoURL,
                                                fileID:
                                                    widget.resume.photoFileID,
                                              ),
                                              fit: BoxFit.cover,
                                              alignment: const Alignment(
                                                0,
                                                -0.35,
                                              ),
                                              semanticLabel: '简历头像',
                                              errorBuilder: (_, _, _) =>
                                                  TextButton(
                                                    onPressed: () {
                                                      ResumePhotoImage(
                                                        photoURL,
                                                        fileID: widget
                                                            .resume
                                                            .photoFileID,
                                                      ).evict();
                                                      loadPhoto();
                                                    },
                                                    child: const FittedBox(
                                                      child: Text(
                                                        '照片加载失败\n点击重试',
                                                        textAlign:
                                                            TextAlign.center,
                                                      ),
                                                    ),
                                                  ),
                                            ),
                                    ),
                                  ),
                                Positioned.fill(
                                  child: IgnorePointer(
                                    child: CustomPaint(
                                      painter: _SheetPainter(
                                        displayed,
                                        index,
                                        paintedRegions[index],
                                        ResumeSheetLayer.ink,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Snapshot already typeset lines, preserving the preview's breaks and baselines.
/// Rasterizes a themed page's artwork for exports; the text stays native.
Future<Uint8List?> resumeExportBackdrop(
  ResumeDocument document,
  int index,
) async {
  if (document.theme.isStandard) return null;
  const scale = 2.0;
  final recorder = ui.PictureRecorder();
  paintResumeBackdrop(Canvas(recorder)..scale(scale), document, index);
  final picture = recorder.endRecording();
  final image = await picture.toImage(
    (resumePaperSize.width * scale).round(),
    (resumePaperSize.height * scale).round(),
  );
  picture.dispose();
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) throw const ApiFailure('页面背景生成失败，请重试');
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  } finally {
    image.dispose();
  }
}

/// Whether [area] lies in a themed page's sidebar, which Word keeps at its
/// page position while the main column flows.
bool resumeWordFixed(ResumeDocument document, Rect area) =>
    switch (document.theme.sidebar) {
      final ResumeThemeSidebar bar => area.right <= bar.width + .5,
      null => false,
    };

Future<Uint8List> _resumeRaster(Size size, void Function(Canvas) paint) async {
  const scale = 3.0;
  final recorder = ui.PictureRecorder();
  paint(Canvas(recorder)..scale(scale));
  final picture = recorder.endRecording();
  final image = await picture.toImage(
    math.max(1, (size.width * scale).ceil()),
    math.max(1, (size.height * scale).ceil()),
  );
  picture.dispose();
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) throw const ApiFailure('页面装饰生成失败，请重试');
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  } finally {
    image.dispose();
  }
}

/// A themed page for flowing Word: the page keeps only its paper and fixed
/// blocks, and each remaining decoration rides on the paragraph it precedes
/// or overlaps, so headings and cards follow the text when Word reflows.
Future<ResumeExportPage> resumeExportWordSheet(
  ResumeDocument document,
  int index, {
  Uint8List? portrait,
}) async {
  final base = resumeExportSheet(document, index, portrait: portrait);
  final paragraphs = <String, Rect>{};
  for (final line in base.lines) {
    final id = line.paragraphId;
    if (id == null || line.fixed) continue;
    final area = Rect.fromLTWH(0, line.top, 1, line.height);
    paragraphs[id] = paragraphs[id]?.expandToInclude(area) ?? area;
  }
  final order = paragraphs.entries.toList()
    ..sort((a, b) => a.value.top.compareTo(b.value.top));
  final fixed = <ResumeDecoration>[];
  final attached = <String, List<ResumeDecoration>>{};
  for (final decoration in document.pages[index].decorations) {
    final area = decoration.bounds;
    final owner = resumeWordFixed(document, area) || order.isEmpty
        ? null
        : order
              .firstWhere(
                (entry) => entry.value.bottom > area.top,
                orElse: () => order.last,
              )
              .key;
    if (owner == null) {
      fixed.add(decoration);
    } else {
      (attached[owner] ??= []).add(decoration);
    }
  }
  final backdrop = await _resumeRaster(resumePaperSize, (canvas) {
    paintResumePaper(canvas, document, index);
    for (final decoration in fixed) {
      decoration.paint(canvas);
    }
  });
  final art = <ResumeExportArt>[];
  for (final MapEntry(key: id, value: decorations) in attached.entries) {
    final area = decorations
        .map((decoration) => decoration.bounds)
        .reduce((a, b) => a.expandToInclude(b))
        .inflate(.5);
    art.add(
      ResumeExportArt(
        id,
        ResumeExportPicture(
          await _resumeRaster(area.size, (canvas) {
            canvas.translate(-area.left, -area.top);
            for (final decoration in decorations) {
              decoration.paint(canvas);
            }
          }),
          area.left,
          area.top,
          area.width,
          area.height,
        ),
      ),
    );
  }
  return ResumeExportPage(
    wordFlow: true,
    lines: base.lines,
    rules: base.rules,
    pictures: base.pictures,
    background: ResumeExportPicture(
      backdrop,
      0,
      0,
      resumePaperSize.width,
      resumePaperSize.height,
    ),
    art: art,
  );
}

ResumeExportPage resumeExportSheet(
  ResumeDocument document,
  int index, {
  Uint8List? portrait,
  Uint8List? backdrop,
}) {
  final sheet = document.pages[index];
  final theme = document.theme;
  final lines = <ResumeExportLine>[];
  for (final ink in sheet.ink) {
    final painter = ink.text;
    final text = painter.text!.toPlainText();
    final ranges = <({int start, int end, TextStyle style})>[];
    var offset = 0;
    void visit(InlineSpan span, TextStyle inherited) {
      if (span is! TextSpan) return;
      final style = inherited.merge(span.style);
      final value = span.text ?? '';
      if (value.isNotEmpty) {
        ranges.add((start: offset, end: offset + value.length, style: style));
      }
      offset += value.length;
      for (final child in span.children ?? <InlineSpan>[]) {
        visit(child, style);
      }
    }

    visit(
      painter.text!,
      const TextStyle(
        fontFamily: resumeDocumentFontFamily,
        fontSize: 10,
        color: resumePaperInk,
      ),
    );
    for (final metric in painter.computeLineMetrics()) {
      if (metric.baseline <= ink.sourceTop ||
          metric.baseline > ink.sourceTop + ink.height + .1) {
        continue;
      }
      final point = painter.getPositionForOffset(
        Offset(metric.left + .001, metric.baseline - metric.ascent / 2),
      );
      final boundary = painter.getLineBoundary(point);
      final spans = <ResumeExportSpan>[];
      for (final range in ranges) {
        final start = math.max(boundary.start, range.start);
        var end = math.min(boundary.end, range.end);
        while (end > start &&
            (text[end - 1] == '\n' || text[end - 1] == '\r')) {
          end--;
        }
        if (end <= start || range.style.color?.a == 0) continue;
        final boxes = painter.getBoxesForSelection(
          TextSelection(baseOffset: start, extentOffset: end),
        );
        if (boxes.isEmpty) continue;
        final left = boxes.map((b) => b.left).reduce(math.min);
        final right = boxes.map((b) => b.right).reduce(math.max);
        final style = range.style;
        spans.add(
          ResumeExportSpan(
            text: text.substring(start, end),
            x: ink.position.dx + left,
            width: right - left,
            size: style.fontSize ?? 10,
            color: (style.color ?? resumePaperInk).toARGB32(),
            weight: (style.fontWeight ?? FontWeight.w400).value.round(),
            bold:
                (style.fontWeight ?? FontWeight.w400).value >=
                FontWeight.w600.value,
            italic: style.fontStyle == FontStyle.italic,
            underline:
                style.decoration?.contains(TextDecoration.underline) ?? false,
            strike:
                style.decoration?.contains(TextDecoration.lineThrough) ?? false,
            letterSpacing: style.letterSpacing ?? 0,
          ),
        );
      }
      if (spans.isNotEmpty) {
        lines.add(
          ResumeExportLine(
            top:
                ink.position.dy +
                metric.baseline -
                metric.ascent -
                ink.sourceTop,
            baseline: ink.position.dy + metric.baseline - ink.sourceTop,
            height: metric.height,
            spans: spans,
            paragraphId:
                'native-${document.painters.indexOf(painter)}-${text.substring(0, boundary.start).split('\n').length}',
            paragraphLeft: ink.wordLeft ?? ink.position.dx,
            paragraphWidth: math.min(
              ink.wordWidth ?? document.paragraphWidths[painter]!,
              resumePaperSize.width -
                  theme.margin.right -
                  (ink.wordLeft ?? ink.position.dx),
            ),
            paragraphAlignRight: ink.wordAlignRight,
            paragraphField: ink.fieldPath,
            fixed: resumeWordFixed(
              document,
              Rect.fromLTWH(
                ink.position.dx,
                ink.position.dy,
                painter.width,
                ink.height,
              ),
            ),
          ),
        );
      }
    }
  }
  final footer = TextPainter(
    text: TextSpan(
      text: '${index + 1}',
      style: TextStyle(
        fontFamily: document.fontFamily,
        fontSize: 9,
        color: Colors.grey,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  final metric = footer.computeLineMetrics().first;
  if (theme.pageNumbers) {
    lines.add(
      ResumeExportLine(
        top: resumePaperSize.height - 34,
        height: metric.height,
        baseline: resumePaperSize.height - 34 + metric.baseline,
        spans: [
          ResumeExportSpan(
            text: '${index + 1}',
            x: (resumePaperSize.width - footer.width) / 2,
            width: footer.width,
            size: 9,
            color: Colors.grey.toARGB32(),
          ),
        ],
      ),
    );
  }
  footer.dispose();
  final rect = sheet.photo;
  final ruleWidth = resumePaperSize.width - theme.margin.horizontal;
  return ResumeExportPage(
    // Theme artwork is fixed to the APP's pagination, so their Word pages keep
    // every paragraph at its typeset position instead of reflowing.
    wordFlow: theme.isStandard,
    lines: lines,
    background: backdrop == null
        ? null
        : ResumeExportPicture(
            backdrop,
            0,
            0,
            resumePaperSize.width,
            resumePaperSize.height,
          ),
    rules: [
      for (final y in sheet.entryDividers)
        ResumeExportRule(
          theme.margin.left,
          y,
          ruleWidth,
          theme.entryDivider?.width ?? .6,
          (theme.entryDivider?.color ?? const Color(0xFFDFE5EE)).toARGB32(),
        ),
      if ((sheet.dividerY, theme.headerRule) case (
        final double y,
        final ResumeThemeRule rule,
      ))
        ResumeExportRule(
          theme.margin.left,
          y,
          ruleWidth,
          rule.width,
          (theme.isStandard ? document.layout.accent : rule.color).toARGB32(),
        ),
    ],
    pictures: [
      if (portrait != null && rect != null)
        ResumeExportPicture(
          portrait,
          rect.left,
          rect.top,
          rect.width,
          rect.height,
        ),
    ],
  );
}

class _SheetPainter extends CustomPainter {
  _SheetPainter(this.document, this.index, this.regions, this.layer);
  final List<ResumeReviewRegion> regions;
  final ResumeDocument document;
  final int index;
  final ResumeSheetLayer layer;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / resumePaperSize.width);
    paintResumeSheet(
      canvas,
      document,
      index,
      reviewRegions: regions,
      layer: layer,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SheetPainter old) =>
      old.document != document ||
      old.index != index ||
      old.regions != regions ||
      old.layer != layer;
}

/// Everything on a page except text: paper, artwork and rules. The standard
/// sheet leaves its white paper to the host so text keeps clean coverage.
/// Page-level artwork: paper, background image, sidebar and ornaments.
void paintResumePaper(Canvas canvas, ResumeDocument document, int index) {
  final theme = document.theme;
  final paper = Offset.zero & resumePaperSize;
  if (!theme.isStandard) {
    canvas.drawRect(paper, Paint()..color = theme.background);
  }
  theme.backgroundImage?.paint(canvas, paper);
  if (theme.sidebar case final ResumeThemeSidebar bar) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, bar.width, resumePaperSize.height),
      Paint()..color = bar.fill,
    );
  }
  final hasPhoto =
      document.pages.isNotEmpty && document.pages.first.photo != null;
  for (final ornament in theme.ornaments) {
    if ((index == 0 || !ornament.firstPage) &&
        (ornament.photo == null || ornament.photo == hasPhoto)) {
      ornament.art.paint(canvas, ornament.rect);
    }
  }
}

void paintResumeBackdrop(Canvas canvas, ResumeDocument document, int index) {
  final theme = document.theme;
  final page = document.pages[index];
  paintResumePaper(canvas, document, index);
  for (final decoration in page.decorations) {
    decoration.paint(canvas);
  }
  final left = theme.margin.left;
  final right = resumePaperSize.width - theme.margin.right;
  for (final y in page.entryDividers) {
    canvas.drawLine(
      Offset(left, y),
      Offset(right, y),
      Paint()
        ..color = theme.entryDivider?.color ?? const Color(0xFFDFE5EE)
        ..strokeWidth = theme.entryDivider?.width ?? .6,
    );
  }
  if ((page.dividerY, theme.headerRule) case (
    final double y,
    final ResumeThemeRule rule,
  )) {
    canvas.drawLine(
      Offset(left, y),
      Offset(right, y),
      Paint()
        ..color = theme.isStandard ? document.layout.accent : rule.color
        ..strokeWidth = rule.width,
    );
  }
}

/// Which part of a sheet to paint, so the photo can sit between the paper
/// and the text a theme may lay over it.
enum ResumeSheetLayer { all, paper, ink }

void paintResumeSheet(
  Canvas canvas,
  ResumeDocument document,
  int index, {
  List<ResumeReviewRegion> reviewRegions = const [],
  ResumeSheetLayer layer = ResumeSheetLayer.all,
}) {
  if (layer != ResumeSheetLayer.ink) {
    paintResumeBackdrop(canvas, document, index);
    for (final region in reviewRegions) {
      paintResumeReviewWash(canvas, region);
    }
    if (layer == ResumeSheetLayer.paper) return;
  }
  final page = document.pages[index];
  for (final run in page.ink) {
    canvas.save();
    canvas.clipRect(
      Rect.fromLTWH(
        run.position.dx,
        run.position.dy,
        run.text.width,
        run.height,
      ),
    );
    final coloredRegions = reviewRegions
        .where(
          (region) =>
              region.highlights.first.colorText &&
              region.highlights.first.fieldPath == run.fieldPath &&
              !run.privacyMasked,
        )
        .toList();
    // Paint the original glyphs outside accepted passages, then tint only
    // those passages. Reuse the laid-out painter to preserve rich-text metrics.
    canvas.save();
    for (final region in coloredRegions) {
      for (final rect in region.waveRects) {
        canvas.clipRect(rect, clipOp: ui.ClipOp.difference, doAntiAlias: false);
      }
    }
    run.text.paint(canvas, run.position - Offset(0, run.sourceTop));
    canvas.restore();
    for (final region in coloredRegions) {
      for (final rect in region.waveRects) {
        canvas.save();
        canvas.clipRect(rect, doAntiAlias: false);
        canvas.saveLayer(
          rect,
          Paint()
            ..colorFilter = ColorFilter.mode(
              region.highlights.first.color,
              BlendMode.srcIn,
            ),
        );
        run.text.paint(canvas, run.position - Offset(0, run.sourceTop));
        canvas.restore();
        canvas.restore();
      }
    }
    canvas.restore();
  }
  for (final region in reviewRegions) {
    paintResumeReviewWave(canvas, region);
  }
  if (!document.theme.pageNumbers) return;
  final footer = TextPainter(
    text: TextSpan(
      text: '${index + 1}',
      style: TextStyle(
        fontFamily: document.fontFamily,
        fontSize: 9,
        color: Colors.grey,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  footer.paint(
    canvas,
    Offset(
      (resumePaperSize.width - footer.width) / 2,
      resumePaperSize.height - 34,
    ),
  );
  footer.dispose();
}

class _AnnotationBubble extends StatelessWidget {
  const _AnnotationBubble({required this.anchor, required this.animation});
  final Rect anchor;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final safe = MediaQuery.paddingOf(context);
      final above = anchor.top - safe.top > 88;
      return CustomSingleChildLayout(
        delegate: _AnnotationBubbleLayout(anchor, safe, above),
        child: ScaleTransition(
          alignment: above ? Alignment.bottomCenter : Alignment.topCenter,
          scale: animation
              .drive(CurveTween(curve: Curves.easeOutCubic))
              .drive(Tween(begin: .92, end: 1.0)),
          child: CustomPaint(
            painter: _GlassBubbleEdge(above: above, shadow: true),
            foregroundPainter: _GlassBubbleEdge(above: above, shadow: false),
            child: ClipPath(
              clipper: _GlassBubbleClip(above),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 28, sigmaY: 28),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: context.isDark
                          ? [
                              context.colors.surface.withValues(alpha: .96),
                              context.colors.inset.withValues(alpha: .93),
                              context.colors.surface.withValues(alpha: .96),
                            ]
                          : const [
                              Color(0xECFFFFFF),
                              Color(0xBDF4F5F8),
                              Color(0xD9EEF0F4),
                            ],
                      stops: [0, .48, 1],
                    ),
                  ),
                  child: Padding(
                    key: const ValueKey('resume-region-actions'),
                    padding: EdgeInsets.only(
                      top: above ? 0 : 7,
                      bottom: above ? 7 : 0,
                    ),
                    child: IntrinsicWidth(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: _BubbleAction(
                              label: '查看评论',
                              onPressed: () {
                                Navigator.pop(context, false);
                              },
                            ),
                          ),
                          SizedBox(
                            height: 19,
                            child: VerticalDivider(
                              width: 1,
                              thickness: .5,
                              color: context.isDark
                                  ? context.colors.border
                                  : const Color(0x303C3C43),
                            ),
                          ),
                          Flexible(
                            child: _BubbleAction(
                              label: '参与改写',
                              onPressed: () {
                                Navigator.pop(context, true);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

Path _glassBubblePath(Size size, bool above) {
  final top = above ? 0.0 : 7.0;
  final bottom = above ? size.height - 7 : size.height;
  final body = Path()
    ..addRRect(
      RRect.fromLTRBR(
        .5,
        top + .5,
        size.width - .5,
        bottom - .5,
        const Radius.circular(13),
      ),
    );
  final x = size.width / 2;
  final tail = Path();
  if (above) {
    tail.moveTo(x - 8, bottom - 1);
    tail.cubicTo(x - 5, bottom, x - 2, bottom + 7, x, bottom + 7);
    tail.cubicTo(x + 2, bottom + 7, x + 5, bottom, x + 8, bottom - 1);
  } else {
    tail.moveTo(x - 8, top + 1);
    tail.cubicTo(x - 5, top, x - 2, top - 7, x, top - 7);
    tail.cubicTo(x + 2, top - 7, x + 5, top, x + 8, top + 1);
  }
  tail.close();
  return Path.combine(PathOperation.union, body, tail);
}

class _GlassBubbleClip extends CustomClipper<Path> {
  const _GlassBubbleClip(this.above);
  final bool above;
  @override
  Path getClip(Size size) => _glassBubblePath(size, above);
  @override
  bool shouldReclip(_GlassBubbleClip old) => above != old.above;
}

class _GlassBubbleEdge extends CustomPainter {
  const _GlassBubbleEdge({required this.above, required this.shadow});
  final bool above, shadow;
  @override
  void paint(Canvas canvas, Size size) {
    final path = _glassBubblePath(size, above);
    if (shadow) {
      canvas.drawShadow(path, const Color(0x330D1628), 8, true);
      canvas.drawShadow(path, const Color(0x240D1628), 1, true);
      return;
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .7
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFFFFF), Color(0x8CFFFFFF), Color(0x40535C6D)],
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(_GlassBubbleEdge old) =>
      above != old.above || shadow != old.shadow;
}

class _BubbleAction extends StatelessWidget {
  const _BubbleAction({required this.label, required this.onPressed});
  final String label;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => CupertinoButton(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
    minimumSize: const Size(0, 44),
    onPressed: onPressed,
    child: Text(
      label,
      style: TextStyle(
        fontFamily: 'AnnotationUI',
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.2,
        color: context.colors.ink,
      ),
    ),
  );
}

class _AnnotationBubbleLayout extends SingleChildLayoutDelegate {
  const _AnnotationBubbleLayout(this.anchor, this.safe, this.above);
  final Rect anchor;
  final EdgeInsets safe;
  final bool above;
  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints(
        maxWidth: math.max(0, constraints.maxWidth - safe.horizontal - 24),
        maxHeight: math.max(0, constraints.maxHeight - safe.vertical - 24),
      );
  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final minX = safe.left + 12;
    final minY = safe.top + 12;
    return Offset(
      (anchor.center.dx - childSize.width / 2).clamp(
        minX,
        math.max(minX, size.width - safe.right - 12 - childSize.width),
      ),
      (above ? anchor.top - childSize.height - 5 : anchor.bottom + 5).clamp(
        minY,
        math.max(minY, size.height - safe.bottom - 12 - childSize.height),
      ),
    );
  }

  @override
  bool shouldRelayout(_AnnotationBubbleLayout old) =>
      anchor != old.anchor || safe != old.safe || above != old.above;
}
