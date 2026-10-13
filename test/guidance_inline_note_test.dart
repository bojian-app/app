import 'package:bojian_mobile/design.dart';
import 'package:bojian_mobile/guidance_inline_note.dart';
import 'package:bojian_mobile/resume_guidance_review.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _record({
  String replacement = '主导前端研发，完成组件体系建设。',
  String reason = '',
  String status = 'PENDING',
}) => {
  'id': 8,
  'replacement': replacement,
  'suggestion': reason,
  'status': status,
};

void main() {
  final layouts = [
    (width: 310.0, paperScale: .6, textScale: 1.0, long: false),
    (width: 250.0, paperScale: .5, textScale: 1.0, long: true),
    (width: 310.0, paperScale: .6, textScale: 1.5, long: true),
    (width: 250.0, paperScale: .5, textScale: 1.5, long: false),
    (width: 95.0, paperScale: .5, textScale: 1.5, long: false),
  ];
  for (final layout in layouts) {
    testWidgets(
      'Reserved note height matches wrapped content at ${layout.width} wide '
      'and ${layout.textScale} text scale (${layout.long ? 'long' : 'short'})',
      (tester) async {
        final record = _record(
          replacement: layout.long
              ? List.filled(7, '主导企业管理平台的前端研发，完善组件体系并提升交付效率。').join()
              : '主导企业管理平台的前端研发，完善组件体系。',
          reason: layout.long
              ? List.filled(4, '突出个人职责，并用可核实的数据说明成果。').join()
              : '',
        );
        var reservedHeight = 0.0;
        await tester.pumpWidget(
          MaterialApp(
            theme: appTheme,
            home: MediaQuery(
              data: MediaQueryData(
                size: const Size(400, 800),
                textScaler: TextScaler.linear(layout.textScale),
              ),
              child: Scaffold(
                body: Align(
                  alignment: Alignment.topCenter,
                  child: Builder(
                    builder: (context) {
                      reservedHeight = guidanceNoteHeight(
                        context,
                        record,
                        layout.width,
                        paperScale: layout.paperScale,
                      );
                      return SizedBox(
                        width: layout.width,
                        child: GuidanceInlineNote(
                          record: record,
                          paperScale: layout.paperScale,
                          onDecide: (_) {},
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        final naturalHeight = tester
            .getSize(find.byType(GuidanceInlineNote))
            .height;
        expect(reservedHeight, closeTo(naturalHeight, .5));
        expect(find.text(record['replacement'] as String), findsOneWidget);
        if (layout.long) {
          final replacementHeight = tester
              .getSize(find.text(record['replacement'] as String))
              .height;
          expect(replacementHeight, greaterThan(30));
          expect(find.text(record['suggestion'] as String), findsOneWidget);
        }
        if (layout.width == 95) {
          expect(
            tester.getTopLeft(find.text('采纳')).dy,
            greaterThan(tester.getTopLeft(find.text('不采纳')).dy),
          );
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'Pending rewrite keeps compact typography and visible decisions',
    (tester) async {
      final record = _record(
        replacement: '就读期间代表学校参加了两次Web应用技术大赛省赛，并取得最高一等奖的荣誉。',
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: Scaffold(
            body: Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: 310,
                child: GuidanceInlineNote(
                  record: record,
                  paperScale: .6,
                  onDecide: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      final replacement = tester.widget<Text>(
        find.text(record['replacement'] as String),
      );
      // A4 body text is 10.5 points at this same document scale.
      expect(replacement.style!.fontSize, inInclusiveRange(10.5 * .6, 8));
      expect(replacement.style!.color, guidanceReplacementColor);
      expect(
        tester.getSize(find.byType(GuidanceInlineNote)).height,
        lessThan(65),
      );
      expect(find.text('采纳'), findsOneWidget);
      expect(find.text('不采纳'), findsOneWidget);
      final card = find.byKey(const ValueKey('guidance-rewrite-card'));
      expect(card, findsOneWidget);
      final decoration =
          tester.widget<DecoratedBox>(card).decoration as BoxDecoration;
      expect(decoration.color, const Color(0xFFF8F6FC));
      expect(
        decoration.border,
        Border.all(
          color: guidanceReplacementColor.withValues(alpha: .12),
          width: .5,
        ),
      );
      expect(decoration.borderRadius, BorderRadius.circular(7));
      expect(decoration.boxShadow, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Plain comments retain text without a rewrite card', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: Scaffold(
          body: SizedBox(
            width: 310,
            child: GuidanceInlineNote(
              record: _record(replacement: '', reason: '可以补充具体项目成果。'),
              paperScale: .6,
              onDecide: (_) => fail('A comment has no rewrite decisions'),
            ),
          ),
        ),
      ),
    );
    expect(find.text('可以补充具体项目成果。'), findsOneWidget);
    expect(find.byKey(const ValueKey('guidance-rewrite-card')), findsNothing);
    expect(find.byType(TextButton), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Decision controls dispatch once and stop while disabled or busy',
    (tester) async {
      final decisions = <bool>[];
      Future<void> show({bool disabled = false, bool busy = false}) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: appTheme,
            home: Scaffold(
              body: Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: 310,
                  child: GuidanceInlineNote(
                    record: _record(),
                    paperScale: .6,
                    disabled: disabled,
                    busy: busy,
                    onDecide: decisions.add,
                  ),
                ),
              ),
            ),
          ),
        );
      }

      await show();
      await tester.tap(find.text('不采纳'));
      await tester.tap(find.text('采纳'));
      expect(decisions, [false, true]);
      await show(disabled: true);
      for (final button in tester.widgetList<TextButton>(
        find.byType(TextButton),
      )) {
        expect(button.onPressed, isNull);
      }
      await tester.tap(find.text('不采纳'));
      await tester.tap(find.text('采纳'));
      expect(decisions, [false, true]);
      await show(busy: true);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      for (final button in tester.widgetList<TextButton>(
        find.byType(TextButton),
      )) {
        expect(button.onPressed, isNull);
      }
      await tester.tap(find.text('不采纳'));
      expect(decisions, [false, true]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Read-only and resolved rewrites keep status without decisions', (
    tester,
  ) async {
    for (final (status, canDecide, label) in [
      ('PENDING', false, '等待作者确认'),
      ('ACCEPTED', true, '已采纳'),
      ('REJECTED', true, '未采纳'),
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: Scaffold(
            body: GuidanceInlineNote(
              record: _record(status: status),
              paperScale: .6,
              canDecide: canDecide,
              onDecide: (_) => fail('Read-only rewrites must not be decided'),
            ),
          ),
        ),
      );
      expect(find.text(label), findsOneWidget);
      expect(find.byType(TextButton), findsNothing);
      expect(tester.takeException(), isNull);
    }
  });
}
