import 'package:bojian_mobile/main.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets(
      'Tooltips stay hidden on profile and pushed routes ($brightness)',
      (tester) async {
        tester.view.physicalSize = const Size(390, 780);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        tester.platformDispatcher.platformBrightnessTestValue = brightness;
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
        final store = await testStore(authenticated: true, seeded: true);

        await tester.pumpWidget(MyApp(startupAdsEnabled: false, store: store));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('nav-3')));
        await tester.pumpAndSettle();
        final menu = find.byKey(const ValueKey('profile-menu'));
        expect(menu, findsOneWidget);
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: Offset.zero);
        await mouse.moveTo(tester.getCenter(menu));
        await tester.pump(const Duration(seconds: 2));
        await tester.pumpAndSettle();
        expect(find.text('展开菜单'), findsNothing);
        expect(TooltipVisibility.of(tester.element(menu)), isFalse);
        await mouse.removePointer();
        await tester.tap(menu);
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('profile-drawer')), findsOneWidget);

        var taps = 0;
        final context = tester.element(find.byType(Navigator).first);
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => Scaffold(
              body: Center(
                child: IconButton(
                  key: const ValueKey('route-button'),
                  tooltip: '新页面提示',
                  onPressed: () => taps++,
                  icon: const Icon(Icons.add),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final target = find.byKey(const ValueKey('route-button'));
        final pointer = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
        );
        await pointer.addPointer(location: Offset.zero);
        await pointer.moveTo(tester.getCenter(target));
        await tester.pump(const Duration(seconds: 2));
        await tester.pumpAndSettle();
        expect(find.text('新页面提示'), findsNothing);
        expect(TooltipVisibility.of(tester.element(target)), isFalse);
        await pointer.removePointer();
        await tester.tap(target);
        expect(taps, 1);
      },
    );
  }
}
