import 'package:bojian_mobile/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _home = Scaffold(key: ValueKey('home'));
const _detail = Scaffold(key: ValueKey('detail'));

void _expectHomeLeftOfDetail(WidgetTester tester) {
  final home = tester.getRect(find.byKey(_home.key!, skipOffstage: false));
  final detail = tester.getRect(find.byKey(_detail.key!, skipOffstage: false));
  expect(home.left, inExclusiveRange(-home.width, 0));
  expect(detail.left, inExclusiveRange(0, detail.width));
  expect(home.right, closeTo(detail.left, 1));
  expect(home.top, 0);
  expect(detail.top, 0);
}

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('Push slides left and pop slides right on $platform', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme.copyWith(platform: platform),
          home: _home,
        ),
      );
      final home = tester.element(find.byKey(_home.key!));
      final result = openPage<String>(home, _detail);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      _expectHomeLeftOfDetail(tester);
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.byKey(_detail.key!)), Offset.zero);

      Navigator.of(tester.element(find.byKey(_detail.key!))).pop('已返回');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      _expectHomeLeftOfDetail(tester);
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.byKey(_home.key!)), Offset.zero);
      expect(await result, '已返回');
    });
  }

  testWidgets('Replacing a page slides the replaced page away', (tester) async {
    await tester.pumpWidget(MaterialApp(theme: appTheme, home: _home));
    final home = tester.element(find.byKey(_home.key!));
    Navigator.of(
      home,
    ).pushReplacement<void, void>(AppPageRoute<void>(builder: (_) => _detail));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    _expectHomeLeftOfDetail(tester);
    await tester.pumpAndSettle();
    expect(find.byKey(_home.key!, skipOffstage: false), findsNothing);
    expect(tester.getTopLeft(find.byKey(_detail.key!)), Offset.zero);
  });

  testWidgets('An interrupted push retraces without a position jump', (
    tester,
  ) async {
    await tester.pumpWidget(MaterialApp(theme: appTheme, home: _home));
    final home = tester.element(find.byKey(_home.key!));
    final navigator = Navigator.of(home);
    openPage<void>(home, _detail);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    final detail = find.byKey(_detail.key!);
    final before = tester.getTopLeft(detail);
    navigator.pop();
    await tester.pump();
    expect(tester.getTopLeft(detail), before);
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.byKey(_home.key!)), Offset.zero);
  });

  testWidgets('An iOS edge gesture can cancel or complete a return', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme.copyWith(platform: TargetPlatform.iOS),
        home: _home,
      ),
    );
    openPage<void>(tester.element(find.byKey(_home.key!)), _detail);
    await tester.pumpAndSettle();
    final detail = find.byKey(_detail.key!);
    final width = tester.getSize(detail).width;

    for (final distance in [width * .2, width * .7]) {
      final gesture = await tester.startGesture(const Offset(1, 200));
      await gesture.moveBy(const Offset(24, 0));
      await tester.pump();
      await gesture.moveBy(Offset(distance, 0));
      await tester.pump();
      _expectHomeLeftOfDetail(tester);
      await tester.pump(const Duration(milliseconds: 250));
      await gesture.up();
      await tester.pumpAndSettle();
      if (distance < width / 2) {
        expect(tester.getTopLeft(detail), Offset.zero);
      }
    }
    expect(detail, findsNothing);
    expect(tester.getTopLeft(find.byKey(_home.key!)), Offset.zero);
  });

  testWidgets('Reduced motion displays the destination immediately', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(MaterialApp(theme: appTheme, home: _home));
    openPage<void>(tester.element(find.byKey(_home.key!)), _detail);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    expect(tester.getTopLeft(find.byKey(_detail.key!)), Offset.zero);
    expect(find.byKey(_detail.key!).hitTestable(), findsOneWidget);
    await tester.pumpAndSettle();

    Navigator.of(tester.element(find.byKey(_detail.key!))).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    expect(tester.getTopLeft(find.byKey(_home.key!)), Offset.zero);
    expect(find.byKey(_home.key!).hitTestable(), findsOneWidget);
    await tester.pumpAndSettle();
  });
}
