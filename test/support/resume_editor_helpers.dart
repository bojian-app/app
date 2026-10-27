import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> openResumeSection(WidgetTester tester, int section) async {
  final card = find.byKey(ValueKey('resume-overview-section-$section'));
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
