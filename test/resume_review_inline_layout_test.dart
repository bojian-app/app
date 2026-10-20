import 'dart:ui' as ui;

import 'package:bojian_mobile/app_store.dart';
import 'package:bojian_mobile/resume_document.dart';
import 'package:bojian_mobile/resume_guidance_review.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _field = 'work_experiences.0.description';

ResumeDraft _resume(String description, {String project = ''}) => decodeResume({
  'title': '行内评论验证',
  'content': {
    'personal_info': {'full_name': '测试作者'},
    'work_experiences': [
      {'company': '测试公司', 'description': description},
    ],
    if (project.isNotEmpty)
      'projects': [
        {'name': '另一段经历', 'description': project},
      ],
  },
});

ResumeReviewNote _note(String key, String quote, {double height = 28}) =>
    ResumeReviewNote(
      key: key,
      fieldPath: _field,
      selectedText: quote,
      height: height,
    );

ResumeReviewHighlight _highlight(String key, String quote) =>
    ResumeReviewHighlight(
      key: key,
      fieldPath: _field,
      text: quote,
      color: guidanceCommentColor,
      label: '评论',
      isWavy: true,
    );

// Selection geometry follows the public painter's clips, including page splits.
List<(int, Rect)> _quoteBoxes(ResumeDocument document, String quote) {
  final result = <(int, Rect)>[];
  for (var page = 0; page < document.pages.length; page++) {
    for (final run in document.pages[page].ink) {
      if (run.fieldPath != _field) continue;
      final value = run.text.text!.toPlainText();
      final start = value.indexOf(quote);
      if (start < 0) continue;
      final clip = Rect.fromLTWH(
        run.position.dx,
        run.position.dy,
        run.text.width,
        run.height,
      );
      for (final box in run.text.getBoxesForSelection(
        TextSelection(baseOffset: start, extentOffset: start + quote.length),
      )) {
        final rect = box.toRect().shift(
          run.position - Offset(0, run.sourceTop),
        );
        if (rect.overlaps(clip)) result.add((page, rect.intersect(clip)));
      }
    }
  }
  return result;
}

(int, ResumeReviewPlacement) _placement(ResumeDocument document, String key) {
  final matches = [
    for (var page = 0; page < document.pages.length; page++)
      for (final note in document.pages[page].reviewNotes)
        if (note.note.key == key) (page, note),
  ];
  expect(matches, hasLength(1));
  return matches.single;
}

void _expectInsidePages(ResumeDocument document) {
  for (final page in document.pages) {
    for (final note in page.reviewNotes) {
      expect(note.rect.top, greaterThanOrEqualTo(resumePaperMargin));
      expect(note.rect.bottom, lessThanOrEqualTo(resumePaperSize.height - 50));
    }
    for (final run in page.ink) {
      expect(run.position.dy, greaterThanOrEqualTo(resumePaperMargin));
      expect(
        run.position.dy + run.height,
        lessThanOrEqualTo(resumePaperSize.height - 50 + .01),
      );
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Compact comment badges avoid text and one another at phone scale', () {
    final doc = ResumeDocument(
      _resume('First comment followed by more content'),
    );
    addTearDown(doc.dispose);
    final scale = 336 / resumePaperSize.width;
    final anchor = _quoteBoxes(doc, 'comment').single.$2;
    final first = resumeCommentBadgeRect(
      page: doc.pages[0],
      anchor: anchor,
      scale: scale,
      width: 336,
      count: 1,
    );
    final second = resumeCommentBadgeRect(
      page: doc.pages[0],
      anchor: anchor,
      scale: scale,
      width: 336,
      count: 123,
      occupied: [first],
    );
    expect(first.size, const Size(14, 14));
    expect(second.size, const Size(24, 14));
    expect(first.overlaps(second), isFalse);
    for (final badge in [first, second]) {
      expect(badge.left, greaterThanOrEqualTo(0));
      expect(badge.right, lessThanOrEqualTo(336));
      for (final run in doc.pages[0].ink) {
        for (final box in run.text.getBoxesForSelection(
          TextSelection(
            baseOffset: 0,
            extentOffset: run.text.text!.toPlainText().length,
          ),
        )) {
          final rect = box.toRect().shift(
            run.position - Offset(0, run.sourceTop),
          );
          final ink = Rect.fromLTRB(
            rect.left * scale,
            rect.top * scale,
            rect.right * scale,
            rect.bottom * scale,
          );
          expect(badge.overlaps(ink), isFalse);
        }
      }
    }
  });

  testWidgets(
    'Holding one adjacent edit preserves other text, colors, waves and badges',
    (tester) async {
      final resume = _resume('FirstSecond comment');
      const marks = [
        ResumeReviewHighlight(
          key: 'first',
          fieldPath: _field,
          text: 'First',
          color: guidanceReplacementColor,
          label: '原文',
          colorText: true,
          originalText: 'The original first passage',
        ),
        ResumeReviewHighlight(
          key: 'second',
          fieldPath: _field,
          text: 'Second',
          color: guidanceReplacementColor,
          label: '原文',
          colorText: true,
          originalText: 'The original second passage',
        ),
        ResumeReviewHighlight(
          key: 'comment',
          fieldPath: _field,
          text: 'comment',
          color: guidanceCommentColor,
          label: '评论',
          isWavy: true,
          commentCount: 2,
        ),
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ResumeDocumentView(
              resume: resume,
              reviewHighlights: marks,
              onReviewTap: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final state = tester.state<ResumeDocumentViewState>(
        find.byType(ResumeDocumentView),
      );
      final regions = resumeReviewRegions(state.document!, marks)[0];
      expect(
        regions.where(
          (region) => region.highlights.any((mark) => mark.colorText),
        ),
        hasLength(2),
      );
      final firstIndex = regions.indexWhere(
        (region) => region.highlights.any((mark) => mark.key == 'first'),
      );
      final press = await tester.startGesture(
        tester.getCenter(
          find.byKey(ValueKey('resume-review-region-0-$firstIndex')),
        ),
      );
      await tester.pump();
      String text() => state.displayedDocument!.pages
          .expand((page) => page.ink)
          .map((run) => run.visibleText)
          .join();
      expect(text(), contains('The original first passageSecond comment'));
      expect(text(), isNot(contains('The original second passage')));
      expect(
        find.byKey(const ValueKey('comment-badge-comment')),
        findsOneWidget,
      );
      final painter =
          tester
                  .widgetList<CustomPaint>(find.byType(CustomPaint))
                  .map((widget) => widget.painter)
                  .firstWhere(
                    (painter) =>
                        painter.runtimeType.toString() == '_SheetPainter',
                  )
              as dynamic;
      final painted = (painter.regions as List<ResumeReviewRegion>)
          .expand((region) => region.highlights)
          .toList();
      expect(
        painted.singleWhere((mark) => mark.key == 'first').text,
        'The original first passage',
      );
      expect(
        painted.singleWhere((mark) => mark.key == 'first').color,
        resumePaperInk,
      );
      expect(
        painted.singleWhere((mark) => mark.key == 'second'),
        same(marks[1]),
      );
      expect(
        painted.singleWhere((mark) => mark.key == 'comment'),
        same(marks[2]),
      );
      expect(
        state.document!.pages
            .expand((page) => page.ink)
            .map((run) => run.visibleText)
            .join(),
        contains('FirstSecond comment'),
      );
      await press.moveBy(const Offset(60, 70));
      await tester.pump();
      expect(text(), contains('The original first passageSecond comment'));
      expect(
        find.byKey(const ValueKey('comment-badge-comment')),
        findsOneWidget,
      );
      await press.up();
      await tester.pumpAndSettle();
      expect(text(), contains('FirstSecond comment'));
      expect(find.byType(BottomSheet), findsNothing);
    },
  );

  test(
    'Accepted passages tint only their glyphs without an underline',
    () async {
      final doc = ResumeDocument(_resume('Original accepted unchanged'));
      addTearDown(doc.dispose);
      final regions = resumeReviewRegions(doc, [
        const ResumeReviewHighlight(
          key: 'accepted',
          fieldPath: _field,
          text: 'accepted',
          color: guidanceReplacementColor,
          label: '原文',
          colorText: true,
        ),
      ])[0];
      expect(regions, isNotEmpty);
      Future<List<int>> render(List<ResumeReviewRegion> marks) async {
        final recorder = ui.PictureRecorder();
        paintResumeSheet(Canvas(recorder), doc, 0, reviewRegions: marks);
        final picture = recorder.endRecording();
        final image = await picture.toImage(596, 842);
        final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        final bytes = data!.buffer.asUint8List().toList();
        image.dispose();
        picture.dispose();
        return bytes;
      }

      final before = await render([]);
      final after = await render(regions);
      var changed = 0;
      final bounds = regions.expand((r) => r.waveRects).toList();
      for (var i = 0; i < before.length; i += 4) {
        if (before[i] == after[i] &&
            before[i + 1] == after[i + 1] &&
            before[i + 2] == after[i + 2] &&
            before[i + 3] == after[i + 3]) {
          continue;
        }
        changed++;
        final point = Offset(
          (i ~/ 4 % 596).toDouble() + .5,
          (i ~/ 4 ~/ 596).toDouble() + .5,
        );
        expect(bounds.any((rect) => rect.inflate(1).contains(point)), isTrue);
        expect(after[i + 3], before[i + 3]);
        if (after[i + 3] == 255) {
          expect(after[i], (guidanceReplacementColor.r * 255).round());
          expect(after[i + 1], (guidanceReplacementColor.g * 255).round());
          expect(after[i + 2], (guidanceReplacementColor.b * 255).round());
        }
      }
      expect(changed, greaterThan(0));
    },
  );

  test('Field comments underline every page of their field without marking unrelated content', () {
    final description = List.generate(
      100,
      (i) => '第$i句：负责开发并优化业务体验。',
    ).join('\n');
    final doc = ResumeDocument(
      _resume(description, project: '另一个字段'),
      reviewNotes: [_note('field', '')],
    );
    addTearDown(doc.dispose);
    final marks = resumeReviewRegions(doc, [_highlight('field', '')]);
    final markedPages = <int>{};
    for (var p = 0; p < doc.pages.length; p++) {
      final fieldRuns = doc.pages[p].ink
          .where((run) => run.fieldPath == _field)
          .toList();
      if (fieldRuns.isEmpty) {
        expect(marks[p], isEmpty);
        continue;
      }
      markedPages.add(p);
      expect(marks[p], isNotEmpty);
      for (final mark in marks[p]) {
        expect(mark.waveRects, isNotEmpty);
        for (final rect in mark.waveRects) {
          expect(
            fieldRuns.any(
              (run) => Rect.fromLTWH(
                run.position.dx,
                run.position.dy,
                run.text.width,
                run.height,
              ).overlaps(rect),
            ),
            isTrue,
          );
        }
      }
    }
    expect(markedPages.length, greaterThan(1));
    _expectInsidePages(doc);
  });

  test(
    'Comment follows an early quoted sentence before later field content',
    () {
      const quote = '首句负责网站研发。';
      const later = '第二句保留后面的成果与指标。';
      final document = ResumeDocument(
        _resume('$quote\n$later', project: quote),
        reviewNotes: [_note('early', quote)],
      );
      addTearDown(document.dispose);

      final (page, note) = _placement(document, 'early');
      final quoteBox = _quoteBoxes(document, quote).last;
      final laterBox = _quoteBoxes(document, later).first;
      expect(page, quoteBox.$1);
      expect(note.rect.top, greaterThanOrEqualTo(quoteBox.$2.bottom - .01));
      expect(note.rect.top - quoteBox.$2.bottom, lessThan(16));
      expect(laterBox.$1, page);
      expect(laterBox.$2.top, greaterThanOrEqualTo(note.rect.bottom));
      expect(document.pages.expand((p) => p.reviewNotes), hasLength(1));
      _expectInsidePages(document);
    },
  );

  test(
    'Wrapped quote is underlined on every line and comment follows its end',
    () {
      final quote = List.generate(8, (i) => '贡献$i：通过业务组件与交互优化提升产品体验。').join();
      const later = '下一句仍应在评论之后完整保留。';
      final document = ResumeDocument(
        _resume('$quote\n$later'),
        reviewNotes: [_note('wrapped', quote)],
      );
      addTearDown(document.dispose);
      final boxes = _quoteBoxes(document, quote);
      expect(boxes.length, greaterThan(1));
      final (page, note) = _placement(document, 'wrapped');
      expect(page, boxes.last.$1);
      expect(note.rect.top, greaterThanOrEqualTo(boxes.last.$2.bottom - .01));
      expect(
        _quoteBoxes(document, later).first.$2.top,
        greaterThanOrEqualTo(note.rect.bottom),
      );

      final regions = resumeReviewRegions(document, [
        _highlight('wrapped', quote),
      ], fallbackToField: false);
      final waves = regions
          .expand((p) => p)
          .expand((r) => r.waveRects)
          .toList();
      expect(waves.length, boxes.length);
      for (var i = 0; i < waves.length; i++) {
        expect(waves[i].left, closeTo(boxes[i].$2.left, .01));
        expect(waves[i].right, closeTo(boxes[i].$2.right, .01));
        // The wave follows the whole line's metrics, including font fallback.
        expect(waves[i].top, lessThanOrEqualTo(boxes[i].$2.top));
        expect(waves[i].bottom, greaterThanOrEqualTo(boxes[i].$2.bottom));
      }
      _expectInsidePages(document);
    },
  );

  test(
    'Several comments on one sentence stay together before the next sentence',
    () {
      const first = '第一句负责业务组件。';
      const second = '第二句负责性能优化。';
      const finalSentence = '最后一句包含交付结果。';
      final document = ResumeDocument(
        _resume('$first\n$second\n$finalSentence'),
        reviewNotes: [
          _note('a', first),
          _note('b', first, height: 42),
          _note('c', second),
        ],
      );
      addTearDown(document.dispose);
      final (pageA, a) = _placement(document, 'a');
      final (pageB, b) = _placement(document, 'b');
      final (pageC, c) = _placement(document, 'c');
      expect(pageB, pageA);
      expect(pageC, pageA);
      expect(b.rect.top, greaterThanOrEqualTo(a.rect.bottom));
      final secondBox = _quoteBoxes(document, second).single.$2;
      expect(secondBox.top, greaterThanOrEqualTo(b.rect.bottom));
      expect(c.rect.top, greaterThanOrEqualTo(secondBox.bottom));
      expect(
        _quoteBoxes(document, finalSentence).single.$2.top,
        greaterThanOrEqualTo(c.rect.bottom),
      );
      _expectInsidePages(document);
    },
  );

  test('Page split keeps the quoted final line with its comment and retains all text', () {
    final lines = List.generate(100, (i) => '工作第$i行：开发网站并优化性能。');
    final plain = ResumeDocument(_resume(lines.join('\n')));
    final quote = lines.lastWhere(
      (line) => _quoteBoxes(plain, line).single.$1 == 0,
    );
    final document = ResumeDocument(
      _resume(lines.join('\n')),
      reviewNotes: [_note('page-edge', quote, height: 160)],
    );
    addTearDown(plain.dispose);
    addTearDown(document.dispose);
    final (page, note) = _placement(document, 'page-edge');
    final quoteBox = _quoteBoxes(document, quote).single;
    expect(page, greaterThan(_quoteBoxes(plain, quote).single.$1));
    expect(page, quoteBox.$1);
    expect(note.rect.top, greaterThanOrEqualTo(quoteBox.$2.bottom));
    final before = plain.pages
        .expand((p) => p.ink)
        .where((r) => r.fieldPath == _field)
        .fold<double>(0, (sum, run) => sum + run.height);
    final after = document.pages
        .expand((p) => p.ink)
        .where((r) => r.fieldPath == _field)
        .fold<double>(0, (sum, run) => sum + run.height);
    expect(after, closeTo(before, .05));
    for (final line in [lines.first, quote, lines.last]) {
      expect(_quoteBoxes(document, line), isNotEmpty);
    }
    _expectInsidePages(document);
  });

  test('A quote spanning pages places its single comment after the final selected line', () {
    final lines = List.generate(100, (i) => '第$i项交付内容：保留完整的简历正文与标点。');
    final quote = lines.sublist(30, 65).join('\n');
    final document = ResumeDocument(
      _resume(lines.join('\n')),
      reviewNotes: [_note('long-quote', quote)],
    );
    addTearDown(document.dispose);
    final boxes = _quoteBoxes(document, quote);
    expect(boxes.map((box) => box.$1).toSet().length, greaterThan(1));
    final (page, note) = _placement(document, 'long-quote');
    expect(page, boxes.last.$1);
    expect(note.rect.top, greaterThanOrEqualTo(boxes.last.$2.bottom));
    final next = _quoteBoxes(document, lines[65]).single;
    expect(next.$1, page);
    expect(next.$2.top, greaterThanOrEqualTo(note.rect.bottom));
    final regions = resumeReviewRegions(document, [
      _highlight('long-quote', quote),
    ], fallbackToField: false);
    expect([
      for (var i = 0; i < regions.length; i++)
        if (regions[i].isNotEmpty) i,
    ], boxes.map((box) => box.$1).toSet().toList());
    _expectInsidePages(document);
  });

  test(
    'Unknown and ambiguous quotes keep notes without marking unrelated text',
    () {
      const repeated = '共同措辞';
      const last = '字段末尾仍然需要保留。';
      final document = ResumeDocument(
        _resume(
          '第一句包含$repeated。\n第二句再次包含$repeated。\n$last',
          project: '已经删去的历史原文',
        ),
        reviewNotes: [
          _note('ambiguous', repeated),
          _note('missing', '已经删去的历史原文'),
        ],
      );
      addTearDown(document.dispose);
      final (page, ambiguous) = _placement(document, 'ambiguous');
      final (_, missing) = _placement(document, 'missing');
      final lastBox = _quoteBoxes(document, last).single;
      expect(page, lastBox.$1);
      expect(ambiguous.rect.top, greaterThanOrEqualTo(lastBox.$2.bottom));
      expect(missing.rect.top, greaterThanOrEqualTo(ambiguous.rect.bottom));
      final regions = resumeReviewRegions(document, [
        _highlight('ambiguous', repeated),
        _highlight('missing', '已经删去的历史原文'),
      ], fallbackToField: false);
      expect(regions.expand((p) => p), isEmpty);
      _expectInsidePages(document);
    },
  );

  test(
    'A repeated quote across rich paragraphs falls back after the entire field',
    () {
      const repeated = '负责共同模块';
      const last = '最后一个富文本段落。';
      final resume = decodeResume({
        'content': {
          'work_experiences': [
            {
              'company': '公司',
              'description_rich': {
                'blocks': [
                  {
                    'spans': [
                      {'text': '$repeated并维护服务。', 'bold': true},
                    ],
                  },
                  {
                    'spans': [
                      {'text': '随后$repeated并完成测试。', 'italic': true},
                    ],
                  },
                  {
                    'spans': [
                      {'text': last},
                    ],
                  },
                ],
              },
            },
          ],
        },
      });
      final document = ResumeDocument(
        resume,
        reviewNotes: [_note('rich', repeated)],
      );
      addTearDown(document.dispose);
      final (page, note) = _placement(document, 'rich');
      final finalLine = _quoteBoxes(document, last).single;
      expect(page, finalLine.$1);
      expect(note.rect.top, greaterThanOrEqualTo(finalLine.$2.bottom));
      expect(
        resumeReviewRegions(document, [
          _highlight('rich', repeated),
        ], fallbackToField: false).expand((p) => p),
        isEmpty,
      );
    },
  );

  test(
    'Historical comments survive empty fields and deleted resume entries',
    () {
      final resumes = [
        _resume(''),
        decodeResume({
          'content': {
            'personal_info': {'full_name': '测试作者'},
            'projects': [
              {'name': '保留项目', 'description': '当前仍然存在的经历。'},
            ],
          },
        }),
      ];
      for (final resume in resumes) {
        final document = ResumeDocument(
          resume,
          reviewNotes: [_note('historical', '已经删去的工作描述。')],
        );
        addTearDown(document.dispose);
        _placement(document, 'historical');
        expect(
          resumeReviewRegions(document, [
            _highlight('historical', '已经删去的工作描述。'),
          ], fallbackToField: false).expand((p) => p),
          isEmpty,
        );
        _expectInsidePages(document);
      }
    },
  );

  testWidgets('Changing only the quoted text repositions an existing comment', (
    tester,
  ) async {
    const first = '第一句的引用。';
    const second = '第二句的引用。';
    final resume = _resume('$first\n$second');
    final key = GlobalKey<ResumeDocumentViewState>();
    Future<void> show(String selectedText) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ResumeDocumentView(
              key: key,
              resume: resume,
              reviewNotes: [_note('same-comment', selectedText)],
            ),
          ),
        ),
      );
    }

    await show(first);
    final originalTop = _placement(
      key.currentState!.document!,
      'same-comment',
    ).$2.rect.top;
    await show(second);
    final document = key.currentState!.document!;
    final (_, note) = _placement(document, 'same-comment');
    expect(note.rect.top, greaterThan(originalTop));
    expect(
      note.rect.top,
      greaterThanOrEqualTo(_quoteBoxes(document, second).single.$2.bottom),
    );
    expect(tester.takeException(), isNull);
  });
}
