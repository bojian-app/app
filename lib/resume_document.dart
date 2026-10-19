import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_theme.dart';

import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/physics.dart';

import 'app_store.dart';
import 'guidance_help.dart';
import 'resume_templates.dart';
import 'resume_native_export.dart';
import 'resume_additional_fields.dart';
import 'api/bojian_api.dart';
import 'resume_guidance_privacy.dart';

// Point dimensions and typography mirror the macOS standard PDF template.
const resumePaperSize = Size(595.28, 841.89);
const resumePaperMargin = 46.0;
const resumePaperInk = Color(0xFF26292E);

InlineSpan _transparentPrivacySpans(InlineSpan span) {
  if (!span.toPlainText().contains(resumePrivacyMask)) return span;
  if (span is! TextSpan) return span;
  final text = span.text ?? '';
  final children = <InlineSpan>[];
  var cursor = 0;
  for (final match in RegExp('▒+').allMatches(text)) {
    if (match.start > cursor) {
      children.add(TextSpan(text: text.substring(cursor, match.start)));
    }
    children.add(
      TextSpan(
        text: match.group(0),
        style: const TextStyle(color: Colors.transparent),
      ),
    );
    cursor = match.end;
  }
  if (cursor < text.length) {
    children.add(TextSpan(text: text.substring(cursor)));
  }
  children.addAll((span.children ?? []).map(_transparentPrivacySpans));
  return TextSpan(style: span.style, children: children);
}

/// Soft translucent condensation over anonymous, defocused glyph shapes.
/// No identifying source text is ever painted beneath the frosted area.
void paintPrivacyFog(Canvas canvas, Rect bounds) {
  final rect = bounds.deflate(bounds.height * .1);
  final height = rect.height;
  final pane = rect.inflate(3);
  final paint = Paint()
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
  canvas.drawRRect(
    RRect.fromRectAndRadius(pane, const Radius.circular(6)),
    paint
      ..shader = ui.Gradient.linear(
        pane.topLeft,
        pane.bottomRight,
        [
          const Color(0xDDF5F8FA),
          const Color(0x88E6EDF1),
          const Color(0xAAF9FBFC),
        ],
        const [0.0, .5, 1.0],
      ),
  );
  paint.shader = null;
  paint.color = const Color(0x44647585);
  paint.maskFilter = MaskFilter.blur(
    BlurStyle.normal,
    math.max(2.5, height * .19),
  );
  final step = math.max(6.0, height * .5);
  var index = 0;
  for (var x = rect.left + 2; x < rect.right - 3; x += step) {
    final h = height * ([.4, .64, .5, .72][index++ % 4]);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(x + step * .25, rect.center.dy),
          width: step * .55,
          height: h,
        ),
        const Radius.circular(2),
      ),
      paint,
    );
  }
  canvas.drawRRect(
    RRect.fromRectAndRadius(pane, const Radius.circular(6)),
    Paint()
      ..color = const Color(0x77FFFFFF)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
  );
  // Faint highlights suggest water vapour without drawing a hard border.
  for (var i = 0; i < 3; i++) {
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(
          rect.left + rect.width * (.2 + i * .29),
          rect.top + height * (.32 + (i % 2) * .24),
        ),
        width: 1.6,
        height: 2.1,
      ),
      Paint()
        ..color = const Color(0x99FFFFFF)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, .7),
    );
  }
}

class ResumeInk {
  ResumeInk(
    this.text,
    this.position,
    this.height, {
    this.sourceTop = 0,
    this.fieldPath,
  });
  final String? fieldPath;
  final TextPainter text;
  final Offset position;
  final double height;
  final double sourceTop;
  bool get privacyMasked =>
      text.text!.toPlainText().contains(resumePrivacyMask);
  String get visibleText {
    final value = text.text!.toPlainText();
    final start = text.getPositionForOffset(Offset(0, sourceTop)).offset;
    final end = text
        .getPositionForOffset(Offset(text.width, sourceTop + height - .001))
        .offset;
    return value.substring(start, end).replaceAll(RegExp('▒+'), '隐私信息已隐藏');
  }
}

class ResumeSheet {
  final ink = <ResumeInk>[];
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
    String? fontFamily,
    String photoURL = '',
    List<ResumeReviewChange> reviewChanges = const [],
    List<ResumeReviewNote> reviewNotes = const [],
  }) : layout = ResumeLayout.resolve(
         resume.source['app_layout'] ?? resume.template,
       ) {
    final builder = _ResumeTypesetter(
      this,
      fontFamily ?? resumeDocumentFontFamily,
      reviewChanges,
      reviewNotes,
    );
    builder.compose(
      resume,
      photoURL.isNotEmpty ||
          resume.photoFileID > 0 ||
          resume.source['app_privacy_photo'] == true,
    );
  }
  final ResumeLayout layout;
  final pages = <ResumeSheet>[];
  final painters = <TextPainter>[];
  final sectionTitles = <String>[];
  void dispose() {
    for (final painter in painters) {
      painter.dispose();
    }
  }
}

class _ResumeTypesetter {
  _ResumeTypesetter(
    this.document,
    this.fontFamily,
    this.reviewChanges,
    this.reviewNotes,
  ) {
    page = ResumeSheet();
    document.pages.add(page);
  }
  final ResumeDocument document;
  final String? fontFamily;
  final List<ResumeReviewChange> reviewChanges;
  final appliedChanges = <String>{};
  final List<ResumeReviewNote> reviewNotes;
  final placedNotes = <String>{};
  final anchorOccurrences = <String, Map<String, int>>{};
  late ResumeSheet page;
  double y = resumePaperMargin;
  static const width = 595.28 - 92;
  static const bottom = 841.89 - 50;

  TextStyle style(double size, {bool bold = false, Color? color}) {
    return TextStyle(
      fontFamily: fontFamily,
      fontSize: size,
      height: (size + 4) / size,
      fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
      color: color ?? resumePaperInk,
    );
  }

  TextPainter measure(InlineSpan text, [double available = width]) {
    final painter = TextPainter(
      text: _transparentPrivacySpans(text),
      textDirection: TextDirection.ltr,
      textScaler: TextScaler.noScaling,
    )..layout(maxWidth: available);
    document.painters.add(painter);
    return painter;
  }

  void nextPage() {
    page = ResumeSheet();
    document.pages.add(page);
    y = resumePaperMargin;
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
      ResumeReviewPlacement(
        note,
        Rect.fromLTWH(resumePaperMargin, y, width, note.height),
      ),
    );
    placedNotes.add(note.key);
    y += note.height + after;
  }

  void paragraph(
    InlineSpan text, {
    double before = 0,
    double after = 7,
    String? fieldPath,
    bool changesApplied = false,
  }) {
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
          lines[stop - 1].height + noteReserve <= bottom - resumePaperMargin;
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
          Offset(resumePaperMargin, y),
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
    double size = 10.5,
    bool bold = false,
    Color? color,
    double before = 0,
    double after = 7,
    String? fieldPath,
  }) {
    if (value.trim().isEmpty) {
      placeReviewNotes(fieldPath);
      return;
    }
    paragraph(
      TextSpan(
        text: value,
        style: style(size, bold: bold, color: color),
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
          style: style(10.5, bold: span['bold'] == true).copyWith(
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
      text(value(entry, key), fieldPath: fieldPath);
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
            style: style(10.5),
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
        leftWidth + rightWidth + 24 <= width) {
      final height = math.max(left.height, right.height);
      ensure(height);
      page.ink.add(ResumeInk(left, Offset(resumePaperMargin, y), height));
      page.ink.add(
        ResumeInk(
          right,
          Offset(resumePaperMargin + width - rightWidth, y),
          height,
        ),
      );
      y += height + 8;
    } else {
      text(label, size: 9.5, color: const Color(0xFF555555));
      text(dates, size: 9.5, color: const Color(0xFF555555));
    }
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
    section(title);
    var renderedEntries = 0;
    for (var index = 0; index < values.length; index++) {
      final entry = values[index];
      if (!meaningful(entry)) continue;
      if (distinguishEntries && renderedEntries > 0) {
        final previousPage = page;
        ensure(80);
        // A page boundary already separates entries; keep rules off page tops.
        if (identical(page, previousPage)) {
          y += 5;
          page.entryDividers.add(y);
          y += 13;
        }
      }
      ensure(48);
      text(
        value(entry, heading),
        size: distinguishEntries ? 13 : 11,
        bold: true,
        after: distinguishEntries ? 5 : 7,
        fieldPath: '$key.$index.$heading',
      );
      final dates = [
        value(entry, key == 'certifications' ? 'date' : 'start_date'),
        entry['current'] == true ? '至今' : value(entry, 'end_date'),
      ].where((s) => s.isNotEmpty).join(' - ');
      metadata(
        supporting
            .map((key) => value(entry, key))
            .where((s) => s.isNotEmpty)
            .join(' · '),
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
    final contacts = [
      resume.phone,
      resume.email,
      resumeBirthLabel(personal),
      gender,
    ].where((s) => s.isNotEmpty).join('   ·   ');
    final header = [
      measure(
        TextSpan(
          text: resume.name.isEmpty ? resume.title : resume.name,
          style: style(25, bold: true, color: document.layout.accent),
        ),
        hasPhoto ? width - 100 : width,
      ),
      if (resume.position.isNotEmpty)
        measure(
          TextSpan(text: resume.position, style: style(11)),
          hasPhoto ? width - 100 : width,
        ),
      if (contacts.isNotEmpty)
        measure(
          TextSpan(text: contacts, style: style(9.5)),
          hasPhoto ? width - 100 : width,
        ),
    ];
    final height = math.max(
      hasPhoto ? 97.0 : 65.0,
      header.fold<double>(0, (h, p) => h + p.height + 7),
    );
    if (height <= 180) {
      for (final painter in header) {
        page.ink.add(
          ResumeInk(painter, Offset(resumePaperMargin, y), painter.height),
        );
        y += painter.height + 7;
      }
      if (hasPhoto) page.photo = const Rect.fromLTWH(474.28, 46, 75, 90);
      y = resumePaperMargin + height + 10;
      page.dividerY = y;
      y += 8;
    } else {
      text(
        resume.name.isEmpty ? resume.title : resume.name,
        size: 25,
        bold: true,
      );
      text(resume.position, size: 11);
      text(contacts, size: 9.5);
    }
    final expectations = [
      if (resume.position.isNotEmpty) '期望职位: ${resume.position}',
      if (resume.city.isNotEmpty) '期望城市: ${resume.city}',
      if (value(job, 'industry').isNotEmpty) '期望行业: ${value(job, 'industry')}',
      if (value(job, 'salary').isNotEmpty) '期望薪资: ${value(job, 'salary')}',
    ].join('   ·   ');
    if (expectations.isNotEmpty ||
        resume.summary.isNotEmpty ||
        job['preference_rich'] is Map) {
      section('求职期望');
      text(expectations);
      detail(
        {...job, 'preference': resume.summary},
        'preference',
        fieldPath: 'job_expectation.preference',
      );
    }
    entrySection(
      source,
      'educations',
      '教育经历',
      'institution',
      ['degree', 'field_of_study'],
      ['campus_experience', 'thesis_title', 'thesis_description'],
      fallback: resume.education,
    );
    entrySection(
      source,
      'work_experiences',
      '工作经历',
      'company',
      ['position', 'industry'],
      ['description'],
      fallback: resume.experience,
    );
    entrySection(
      source,
      'projects',
      '项目经历',
      'name',
      ['role', 'url'],
      ['description', 'achievements'],
    );
    final skills = entries(source['skills']);
    if (skills.any(meaningful)) {
      section('技能');
      for (var index = 0; index < skills.length; index++) {
        final skill = skills[index];
        if (!meaningful(skill)) continue;
        text(value(skill, 'name'), bold: true, fieldPath: 'skills.$index.name');
        detail(skill, 'description', fieldPath: 'skills.$index.description');
      }
    } else if (resume.skills.isNotEmpty) {
      section('技能');
      text(resume.skills);
    }
    entrySection(source, 'certifications', '证书', 'name', ['issuer'], []);
    // Historical comments still belong to this review even if their entire
    // source entry has since been removed from the resume.
    for (final note in reviewNotes) {
      if (!placedNotes.contains(note.key)) placeReviewNote(note);
    }
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
          final area = Rect.fromLTWH(
            run.position.dx,
            run.position.dy,
            run.text.width,
            run.height,
          );
          for (final box in run.text.getBoxesForSelection(
            TextSelection(baseOffset: 0, extentOffset: length),
          )) {
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
      );
      for (final (index, run) in matches) {
        if (!identical(run.text, matchedPainter)) continue;
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
  });
  final void Function(String fieldPath, String selectedText, bool replace)?
  onAnnotate;
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
        fontFamily: resumeDocumentFontFamily,
        photoURL: photoURL,
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
        math.min(680.0, viewportSize.width - 24) / resumePaperSize.width;
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
    inertia.dispose();
    scrollHold?.cancel();
    pageScroll.dispose();
    document?.dispose();
    originalPreview?.dispose();
    transform.dispose();
    super.dispose();
  }

  Future<ResumeExportLayout> captureLayout({
    required bool Function() isCancelled,
    required ValueChanged<String> onProgress,
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
        final stream = NetworkImage(url).resolve(ImageConfiguration.empty);
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
      exportDocument = ResumeDocument(resume, fontFamily: font, photoURL: url);
      final pages = <ResumeExportPage>[];
      for (var index = 0; index < exportDocument.pages.length; index++) {
        check();
        onProgress('正在准备第 ${index + 1}/${exportDocument.pages.length} 页文字…');
        Uint8List? portrait;
        final rect = exportDocument.pages[index].photo;
        if (photo != null && rect != null) {
          final recorder = ui.PictureRecorder();
          final canvas = Canvas(recorder)..scale(3);
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
        pages.add(resumeExportSheet(exportDocument, index, portrait: portrait));
        await Future<void>.delayed(Duration.zero);
      }
      check();
      return ResumeExportLayout(pages);
    } finally {
      photo?.dispose();
      exportDocument?.dispose();
    }
  }

  Future<List<Uint8List>> capturePages({
    required bool Function() isCancelled,
    required ValueChanged<String> onProgress,
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
        final stream = NetworkImage(url).resolve(ImageConfiguration.empty);
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
      exportDocument = ResumeDocument(resume, fontFamily: font, photoURL: url);
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
        paintResumeSheet(canvas, exportDocument, index);
        final rect = exportDocument.pages[index].photo;
        if (photo != null && rect != null) {
          paintImage(
            canvas: canvas,
            rect: rect,
            image: photo,
            fit: BoxFit.cover,
            alignment: const Alignment(0, -.35),
          );
        }
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
    } finally {
      exportDocument?.dispose();
      photo?.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final resume = widget.resume;
    const font = resumeDocumentFontFamily;
    final key = jsonEncode([
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
      font,
      photoURL,
      resume.photoFileID,
      widget.reviewNotes
          .map((v) => [v.key, v.fieldPath, v.height, v.selectedText])
          .toList(),
      widget.reviewChanges
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
    if (key != cacheKey) {
      selectedRegion = null;
      document?.dispose();
      document = ResumeDocument(
        resume,
        fontFamily: font,
        photoURL: photoURL,
        reviewChanges: widget.reviewChanges,
        reviewNotes: widget.reviewNotes,
      );
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
      ...displayedHighlights.where((mark) => mark.commentCount > 0),
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
      color: context.isDark ? context.colors.canvas : const Color(0xFFE8EBEF),
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
                  final width = math.min(680.0, constraints.maxWidth - 24);
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
                                    child:
                                        resume.source['app_privacy_photo'] ==
                                            true
                                        ? Semantics(
                                            label: '简历头像已隐藏',
                                            child: DecoratedBox(
                                              decoration: const BoxDecoration(
                                                color: Color(0xFFE6E9ED),
                                                borderRadius: BorderRadius.all(
                                                  Radius.circular(4),
                                                ),
                                              ),
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
                                        : Image.network(
                                            photoURL,
                                            fit: BoxFit.cover,
                                            alignment: const Alignment(
                                              0,
                                              -0.35,
                                            ),
                                            semanticLabel: '简历头像',
                                            errorBuilder: (_, _, _) =>
                                                TextButton(
                                                  onPressed: () {
                                                    NetworkImage(photoURL)
                                                        .evict();
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
ResumeExportPage resumeExportSheet(
  ResumeDocument document,
  int index, {
  Uint8List? portrait,
}) {
  final sheet = document.pages[index];
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
            bold:
                (style.fontWeight ?? FontWeight.w400).value >=
                FontWeight.w600.value,
            italic: style.fontStyle == FontStyle.italic,
            underline:
                style.decoration?.contains(TextDecoration.underline) ?? false,
            strike:
                style.decoration?.contains(TextDecoration.lineThrough) ?? false,
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
          ),
        );
      }
    }
  }
  final footer = TextPainter(
    text: TextSpan(
      text: '${index + 1}',
      style: const TextStyle(
        fontFamily: resumeDocumentFontFamily,
        fontSize: 9,
        color: Colors.grey,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  final metric = footer.computeLineMetrics().first;
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
  footer.dispose();
  final rect = sheet.photo;
  return ResumeExportPage(
    lines: lines,
    rules: [
      for (final y in sheet.entryDividers)
        ResumeExportRule(
          resumePaperMargin,
          y,
          resumePaperSize.width - 2 * resumePaperMargin,
          .6,
          0xFFDFE5EE,
        ),
      if (sheet.dividerY case final double y)
        ResumeExportRule(
          resumePaperMargin,
          y,
          resumePaperSize.width - 2 * resumePaperMargin,
          1.5,
          document.layout.accent.toARGB32(),
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
  _SheetPainter(this.document, this.index, this.regions);
  final List<ResumeReviewRegion> regions;
  final ResumeDocument document;
  final int index;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / resumePaperSize.width);
    paintResumeSheet(canvas, document, index, reviewRegions: regions);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SheetPainter old) =>
      old.document != document || old.index != index || old.regions != regions;
}

void paintResumeSheet(
  Canvas canvas,
  ResumeDocument document,
  int index, {
  List<ResumeReviewRegion> reviewRegions = const [],
}) {
  for (final region in reviewRegions) {
    paintResumeReviewWash(canvas, region);
  }
  final page = document.pages[index];
  for (final y in page.entryDividers) {
    canvas.drawLine(
      Offset(resumePaperMargin, y),
      Offset(resumePaperSize.width - resumePaperMargin, y),
      Paint()
        ..color = const Color(0xFFDFE5EE)
        ..strokeWidth = .6,
    );
  }
  for (final run in page.ink) {
    canvas.save();
    canvas.clipRect(
      Rect.fromLTWH(
        run.position.dx,
        run.position.dy,
        run.text.width,
        run.height,
      ).inflate(run.privacyMasked ? 5 : 0),
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
    if (run.privacyMasked) {
      for (final match in RegExp(
        '▒+',
      ).allMatches(run.text.text!.toPlainText())) {
        for (final box in run.text.getBoxesForSelection(
          TextSelection(baseOffset: match.start, extentOffset: match.end),
        )) {
          paintPrivacyFog(
            canvas,
            box.toRect().shift(run.position - Offset(0, run.sourceTop)),
          );
        }
      }
    }
    canvas.restore();
  }
  for (final region in reviewRegions) {
    paintResumeReviewWave(canvas, region);
  }
  if (page.dividerY case final double y) {
    canvas.drawLine(
      Offset(46, y),
      Offset(549.28, y),
      Paint()
        ..color = document.layout.accent
        ..strokeWidth = 1.5,
    );
  }
  final footer = TextPainter(
    text: TextSpan(
      text: '${index + 1}',
      style: const TextStyle(
        fontFamily: resumeDocumentFontFamily,
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
