import 'dart:ui' as ui;

import 'package:bojian_mobile/account_pages.dart';
import 'package:bojian_mobile/design.dart';
import 'package:bojian_mobile/discovery.dart';
import 'package:bojian_mobile/main.dart';
import 'package:bojian_mobile/profile_identity.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

// Sample the painted status-bar position, as the platform does, so a style
// below a SafeArea cannot make this test pass.
SystemUiOverlayStyle statusStyle(WidgetTester tester) =>
    tester.binding.renderViews.single.debugLayer!.find<SystemUiOverlayStyle>(
      Offset(tester.view.physicalSize.width / 2, tester.view.padding.top / 2),
    )!;

Future<void> expectDiscoveryStatusBackground(WidgetTester tester) async {
  final page = find.byType(DiscoveryPage);
  final surface = tester.element(page).colors.surface;
  final boundaryFinder = find
      .ancestor(of: page, matching: find.byType(RepaintBoundary))
      .first;
  expect(tester.getTopLeft(boundaryFinder).dy, 0);
  final boundary = tester.renderObject<RenderRepaintBoundary>(boundaryFinder);
  await tester.runAsync(() async {
    final image = await boundary.toImage();
    try {
      final bytes = (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;
      // Both the actual status-bar area and page edge must paint the surface.
      for (final y in [2, tester.view.padding.top.toInt() + 2]) {
        final offset = (y * image.width + 2) * 4;
        final rgba = bytes.getUint32(offset);
        expect(((rgba & 0xff) << 24) | (rgba >> 8), surface.toARGB32());
      }
    } finally {
      image.dispose();
    }
  });
}

void main() {
  for (final inset in [24.0, 44.0]) {
    testWidgets(
      'Profile background and system icons follow scroll and theme ($inset)',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        tester.view.padding = FakeViewPadding(top: inset);
        tester.view.viewPadding = FakeViewPadding(top: inset);
        tester.platformDispatcher.platformBrightnessTestValue =
            Brightness.light;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPadding);
        addTearDown(tester.view.resetViewPadding);
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
        final store = await testStore(authenticated: true);
        await tester.pumpWidget(MyApp(startupAdsEnabled: false, store: store));
        await tester.pumpAndSettle();
        expect(tester.getTopLeft(find.byType(DiscoveryPage)).dy, inset);
        expect(statusStyle(tester).statusBarIconBrightness, Brightness.dark);
        await expectDiscoveryStatusBackground(tester);
        await tester.tap(find.byKey(const ValueKey('nav-3')));
        await tester.pumpAndSettle();
        final list = find.byKey(const ValueKey('profile-scroll'));
        final profileState = tester.state(find.byType(ProfilePage));
        final scroll = tester
            .state<NestedScrollViewState>(list)
            .outerController;
        final header = find.byKey(const ValueKey('profile-header'));
        final backdrop = find.descendant(
          of: header,
          matching: find.byType(ProfileBackdrop),
        );
        expect(tester.getTopLeft(backdrop).dy, 0);
        expect(
          tester.getTopLeft(find.byKey(const ValueKey('profile-menu'))).dy,
          greaterThanOrEqualTo(inset),
        );
        final center = tester.getCenter(header).dx;
        expect(
          tester
              .getCenter(find.byKey(const ValueKey('profile-identity-avatar')))
              .dx,
          closeTo(center, .01),
        );
        for (final item in [
          find.byKey(const ValueKey('profile-identity-name')),
          find.byKey(const ValueKey('profile-account-summary')),
        ]) {
          expect(tester.getTopLeft(item).dx, closeTo(16, .01));
        }
        expect(statusStyle(tester).statusBarIconBrightness, Brightness.light);
        expect(statusStyle(tester).statusBarColor, Colors.transparent);
        await tester.tap(find.byKey(const ValueKey('profile-menu')));
        await tester.pumpAndSettle();
        expect(statusStyle(tester).statusBarIconBrightness, Brightness.dark);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(statusStyle(tester).statusBarIconBrightness, Brightness.light);
        tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
        await tester.pumpAndSettle();
        expect(statusStyle(tester).statusBarIconBrightness, Brightness.light);
        await tester.tap(find.byKey(const ValueKey('nav-0')));
        await tester.pumpAndSettle();
        await expectDiscoveryStatusBackground(tester);
        expect(statusStyle(tester).statusBarIconBrightness, Brightness.light);
        await tester.tap(find.byKey(const ValueKey('nav-3')));
        await tester.pumpAndSettle();
        scroll.jumpTo(scroll.position.maxScrollExtent);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('profile-compact-header')),
          findsOneWidget,
        );
        expect(
          tester.getTopLeft(find.byKey(const ValueKey('profile-menu'))).dy,
          greaterThanOrEqualTo(inset),
        );
        expect(statusStyle(tester).statusBarIconBrightness, Brightness.light);
        tester.platformDispatcher.platformBrightnessTestValue =
            Brightness.light;
        await tester.pumpAndSettle();
        expect(statusStyle(tester).statusBarIconBrightness, Brightness.dark);
        final offset = scroll.offset;
        await tester.tap(find.byKey(const ValueKey('nav-0')));
        await tester.pumpAndSettle();
        expect(tester.getTopLeft(find.byType(DiscoveryPage)).dy, inset);
        expect(statusStyle(tester).statusBarIconBrightness, Brightness.dark);
        await expectDiscoveryStatusBackground(tester);
        await tester.tap(find.byKey(const ValueKey('nav-3')));
        await tester.pumpAndSettle();
        expect(tester.state(find.byType(ProfilePage)), same(profileState));
        expect(scroll.offset, closeTo(offset, .01));
        expect(statusStyle(tester).statusBarIconBrightness, Brightness.dark);
        await tester.tap(find.byKey(const ValueKey('profile-messages')));
        await tester.pumpAndSettle();
        expect(find.byType(MessagesPage), findsOneWidget);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(statusStyle(tester).statusBarIconBrightness, Brightness.dark);
        scroll.jumpTo(0);
        await tester.pumpAndSettle();
        expect(statusStyle(tester).statusBarIconBrightness, Brightness.light);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
