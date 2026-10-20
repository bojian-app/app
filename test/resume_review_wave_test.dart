import 'dart:ui' as ui;

import 'package:bojian_mobile/app_store.dart';
import 'package:bojian_mobile/resume_document.dart';
import 'package:bojian_mobile/resume_native_export.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _field = 'work_experiences.0.description';
const _text = '就读期间曾代表学校参与两次广东省教育厅举办的Web应用技能大赛并获奖。';

ResumeReviewHighlight _mark(String key, String text) => ResumeReviewHighlight(
  key: key,
  fieldPath: _field,
  text: text,
  color: Colors.teal,
  label: '评论',
  isWavy: true,
);

(ResumeDocument, TextPainter) _document({double width = 560}) {
  final painter = TextPainter(
    text: const TextSpan(
      style: TextStyle(fontFamily: resumeDocumentFontFamily, fontSize: 12),
      children: [
        TextSpan(text: '就读期间曾代表学校参与两次广东省教育厅举办的'),
        TextSpan(text: 'Web', style: TextStyle(fontSize: 16)),
        TextSpan(
          text: '应用技能大赛',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        TextSpan(text: '并获奖。'),
      ],
    ),
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: width);
  addTearDown(painter.dispose);
  final document = ResumeDocument(
    decodeResume({'content': <String, dynamic>{}}),
  );
  addTearDown(document.dispose);
  document.pages
    ..clear()
    ..add(
      ResumeSheet()
        ..ink.add(
          ResumeInk(painter, Offset.zero, painter.height, fieldPath: _field),
        ),
    );
  return (document, painter);
}

Future<Uint8List> _render(
  List<ResumeReviewRegion> regions,
  double scale,
) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)..scale(scale);
  for (final region in regions) {
    paintResumeReviewWave(canvas, region);
  }
  final picture = recorder.endRecording();
  final image = await picture.toImage(
    (600 * scale).ceil(),
    (100 * scale).ceil(),
  );
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  image.dispose();
  picture.dispose();
  return data!.buffer.asUint8List();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await (FontLoader(
      resumeDocumentFontFamily,
    )..addFont(rootBundle.load(resumeFontRegularAsset))).load();
  });

  for (final quote in [_text, '']) {
    test(
      'Mixed fonts produce one continuous wave for ${quote.isEmpty ? 'a field' : 'a quote'}',
      () async {
        final (document, painter) = _document();
        final selection = const TextSelection(
          baseOffset: 0,
          extentOffset: _text.length,
        );
        final boxes = painter.getBoxesForSelection(selection);
        // Exercise actual engine fragmentation, including different font metrics.
        expect(boxes.length, greaterThan(1));
        expect(boxes.map((box) => box.bottom).toSet().length, greaterThan(1));
        final line = painter
            .getBoxesForSelection(
              selection,
              boxHeightStyle: ui.BoxHeightStyle.max,
            )
            .map((box) => box.toRect())
            .reduce((a, b) => a.expandToInclude(b));
        final highlight = _mark('mixed', quote);
        final regions = resumeReviewRegions(document, [highlight]).single;
        expect(regions, hasLength(1));
        expect(regions.single.waveRects, [line]);
        final expected = [
          ResumeReviewRegion(line, [highlight], waveRects: [line]),
        ];
        for (final scale in [.56, 1.0, 2.0]) {
          final actualPixels = await _render(regions, scale);
          expect(actualPixels.any((byte) => byte != 0), isTrue);
          expect(actualPixels, orderedEquals(await _render(expected, scale)));
        }
      },
    );
  }

  test(
    'Overlapping comments share a wave and retain both comment identities',
    () {
      final (document, _) = _document();
      final regions = resumeReviewRegions(document, [
        _mark('first', '就读期间曾代表学校参与两次广东省教育厅举办的Web'),
        _mark('second', 'Web应用技能大赛并获奖。'),
      ]).single;
      expect(regions, hasLength(1));
      expect(regions.single.highlights.map((mark) => mark.key), [
        'first',
        'second',
      ]);
      expect(regions.single.waveRects, hasLength(1));
    },
  );

  test('Wrapped mixed fonts keep a separate continuous wave on each line', () {
    final (document, painter) = _document(width: 170);
    final rects =
        resumeReviewRegions(document, [
            _mark('wrapped', _text),
          ]).single.expand((region) => region.waveRects).toList()
          ..sort((a, b) => a.top.compareTo(b.top));
    expect(rects.length, painter.computeLineMetrics().length);
    expect(rects.length, greaterThan(1));
    for (var i = 1; i < rects.length; i++) {
      expect(rects[i].top, greaterThanOrEqualTo(rects[i - 1].bottom - .01));
    }
  });

  test('Separate quoted passages do not underline intervening text', () {
    final (document, _) = _document();
    final rects =
        resumeReviewRegions(document, [
            _mark('first', '就读期间'),
            _mark('last', '并获奖。'),
          ]).single.expand((region) => region.waveRects).toList()
          ..sort((a, b) => a.left.compareTo(b.left));
    expect(rects, hasLength(2));
    expect(rects.first.right, lessThan(rects.last.left));
  });
}
