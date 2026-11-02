import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> openResumeSection(WidgetTester tester, int section) async {
  final card = find.byKey(ValueKey('resume-overview-section-$section'));
  if (card.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      card,
      250,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('resume-modules')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
  }
  await tester.ensureVisible(card);
  await tester.pumpAndSettle();
  await tester.tapAt(tester.getTopLeft(card) + const Offset(32, 32));
  await tester.pumpAndSettle();
}

Future<void> saveResumeSection(WidgetTester tester) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('resume-section-save')));
  await tester.pumpAndSettle();
}

Future<void> workMenuAction(WidgetTester tester, String action) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('resume-more')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ValueKey('work-action-$action')));
  await tester.pumpAndSettle();
}

Future<void> enterJobTitleChoice(WidgetTester tester, String value) =>
    enterResumeOptionChoice(tester, value, keyPrefix: 'job-title');

Future<void> enterResumeOptionChoice(
  WidgetTester tester,
  String value, {
  required String keyPrefix,
}) async {
  await tester.enterText(find.byKey(ValueKey('$keyPrefix-search')), value);
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pumpAndSettle();
  final custom = find.byKey(ValueKey('$keyPrefix-custom'));
  final choice = custom.evaluate().isNotEmpty ? custom : find.text(value).last;
  await tester.ensureVisible(choice);
  await tester.tap(choice);
  await tester.pumpAndSettle();
}
