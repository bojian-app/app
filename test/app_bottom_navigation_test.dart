import 'package:bojian_mobile/app_bottom_navigation.dart';
import 'package:bojian_mobile/navigation_icon.dart';
import 'package:bojian_mobile/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _destinations = [
  (index: 0, label: '发现'),
  (index: 1, label: '模版市场'),
  (index: 2, label: '积分'),
  (index: 3, label: '我的'),
];

void _phoneView(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(320, 720);
  tester.view.padding = const FakeViewPadding(bottom: 24);
  tester.view.viewPadding = const FakeViewPadding(bottom: 24);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetPadding);
  addTearDown(tester.view.resetViewPadding);
}

Future<void> _showNavigation(
  WidgetTester tester, {
  int selected = 0,
  double textScale = 1,
  bool reduceMotion = false,
  ValueChanged<int>? onSelected,
}) => tester.pumpWidget(
  MaterialApp(
    theme: appTheme,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(textScale),
        disableAnimations: reduceMotion,
      ),
      child: child!,
    ),
    home: Scaffold(
      body: const SizedBox.expand(),
      bottomNavigationBar: AppBottomNavigation(
        selectedIndex: selected,
        onSelected: onSelected ?? (_) {},
      ),
    ),
  ),
);

List<Rect> _destinationRects(WidgetTester tester) => [
  for (final destination in _destinations)
    tester.getRect(find.byKey(ValueKey('nav-${destination.index}'))),
];

void main() {
  for (final textScale in [1.5, 2.0]) {
    testWidgets(
      'Four destinations fit one row at 320px and text scale $textScale',
      (tester) async {
        _phoneView(tester);
        await _showNavigation(tester, textScale: textScale);
        await tester.pumpAndSettle();

        final destinations = _destinationRects(tester);
        for (var index = 0; index < destinations.length; index++) {
          final rect = destinations[index];
          expect(rect.width, greaterThanOrEqualTo(48));
          expect(rect.height, greaterThanOrEqualTo(48));
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(320));
          expect(rect.bottom, lessThanOrEqualTo(696));
          final label = tester.getRect(find.text(_destinations[index].label));
          expect(label.left, greaterThanOrEqualTo(rect.left));
          expect(label.right, lessThanOrEqualTo(rect.right));
          expect(label.top, greaterThanOrEqualTo(rect.top));
          expect(label.bottom, lessThanOrEqualTo(rect.bottom));
          for (var other = 0; other < index; other++) {
            expect(rect.overlaps(destinations[other]), isFalse);
          }
        }
        final first = destinations.first;
        final firstLabel = tester.getRect(find.text(_destinations.first.label));
        for (var index = 0; index < destinations.length; index++) {
          final rect = destinations[index];
          expect(rect.top, closeTo(first.top, 0.001));
          expect(rect.bottom, closeTo(first.bottom, 0.001));
          expect(rect.width, closeTo(first.width, 0.001));
          expect(
            tester.getRect(find.text(_destinations[index].label)).top,
            closeTo(firstLabel.top, 0.001),
          );
          if (index > 0) {
            expect(
              rect.left,
              greaterThanOrEqualTo(destinations[index - 1].right),
            );
          }
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'Destinations expose selection and respond to touch and semantics',
    (tester) async {
      _phoneView(tester);
      final selected = <int>[];
      await _showNavigation(tester, selected: 2, onSelected: selected.add);
      await tester.pumpAndSettle();

      for (final destination in _destinations) {
        final node = find.semantics
            .byLabel(destination.label)
            .evaluate()
            .single;
        expect(
          node,
          isSemantics(
            label: destination.label,
            isButton: true,
            hasSelectedState: true,
            isSelected: destination.index == 2,
            hasTapAction: true,
          ),
        );
        await tester.tap(find.byKey(ValueKey('nav-${destination.index}')));
        await tester.pumpAndSettle();
      }
      tester.semantics.tap(find.semantics.byLabel('模版市场'));
      await tester.pump();
      expect(selected, [0, 1, 2, 3, 1]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Selection changes leave every destination in place', (
    tester,
  ) async {
    _phoneView(tester);
    await _showNavigation(tester, textScale: 2);
    await tester.pumpAndSettle();
    final baseline = _destinationRects(tester);
    final bar = tester.getRect(find.byType(AppBottomNavigation));

    for (final state in [(2, 1), (3, 99), (1, 12457), (0, 0)]) {
      await _showNavigation(tester, selected: state.$1, textScale: 2);
      expect(_destinationRects(tester), baseline);
      expect(tester.getRect(find.byType(AppBottomNavigation)), bar);
      await tester.pump(const Duration(milliseconds: 80));
      expect(_destinationRects(tester), baseline);
      expect(tester.getRect(find.byType(AppBottomNavigation)), bar);
      await tester.pumpAndSettle();
      expect(_destinationRects(tester), baseline);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
    'Rapid selection changes keep icon surfaces fixed and finish on the latest tab',
    (tester) async {
      _phoneView(tester);
      await _showNavigation(tester, textScale: 2);
      await tester.pumpAndSettle();
      final destinationRects = _destinationRects(tester);
      final surfaceRects = <Rect>[];
      final iconRects = <Rect>[];
      for (final destination in _destinations) {
        final surface = find.byKey(
          ValueKey('nav-icon-surface-${destination.index}'),
        );
        surfaceRects.add(tester.getRect(surface));
        iconRects.add(
          tester.getRect(
            find.descendant(of: surface, matching: find.byType(NavigationIcon)),
          ),
        );
      }

      for (final selected in [2, 1, 3, 0, 2]) {
        await _showNavigation(tester, selected: selected, textScale: 2);
        await tester.pump(const Duration(milliseconds: 40));
        expect(_destinationRects(tester), destinationRects);
        for (final destination in _destinations) {
          final surface = find.byKey(
            ValueKey('nav-icon-surface-${destination.index}'),
          );
          expect(tester.getRect(surface), surfaceRects[destination.index]);
          expect(
            tester.getRect(
              find.descendant(
                of: surface,
                matching: find.byType(NavigationIcon),
              ),
            ),
            iconRects[destination.index],
          );
          expect(
            find.descendant(of: surface, matching: find.byType(DecoratedBox)),
            findsNothing,
          );
        }
        expect(tester.takeException(), isNull);
      }
      await tester.pumpAndSettle();
      for (final destination in _destinations) {
        final surface = find.byKey(
          ValueKey('nav-icon-surface-${destination.index}'),
        );
        final icon = tester.widget<NavigationIcon>(
          find.descendant(of: surface, matching: find.byType(NavigationIcon)),
        );
        expect(icon.progress, destination.index == 2 ? 1 : 0);
        expect(tester.getRect(surface), surfaceRects[destination.index]);
      }
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  for (final reduced in [false, true]) {
    testWidgets(
      'Selection respects reduced motion without changing layout (reduced=$reduced)',
      (tester) async {
        _phoneView(tester);
        await _showNavigation(tester, reduceMotion: reduced);
        await tester.pumpAndSettle();
        final baseline = _destinationRects(tester);

        await _showNavigation(tester, selected: 3, reduceMotion: reduced);
        await tester.pump(const Duration(milliseconds: 1));
        expect(tester.binding.hasScheduledFrame, !reduced);
        expect(_destinationRects(tester), baseline);
        await tester.pumpAndSettle();
        expect(tester.binding.hasScheduledFrame, isFalse);
        expect(_destinationRects(tester), baseline);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
