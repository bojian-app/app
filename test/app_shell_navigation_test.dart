import 'package:bojian_mobile/account_pages.dart';
import 'package:bojian_mobile/app_bottom_navigation.dart';
import 'package:bojian_mobile/app_shell.dart';
import 'package:bojian_mobile/app_store.dart';
import 'package:bojian_mobile/design.dart';
import 'package:bojian_mobile/discovery.dart';
import 'package:bojian_mobile/resume_pages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

Future<AppStore> _showShell(
  WidgetTester tester, {
  bool reduceMotion = false,
  ValueNotifier<bool>? motionPreference,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(360, 720);
  tester.view.padding = const FakeViewPadding(bottom: 24);
  tester.view.viewPadding = const FakeViewPadding(bottom: 24);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetPadding);
  addTearDown(tester.view.resetViewPadding);
  final store = await testStore(authenticated: true, seeded: true);
  addTearDown(store.dispose);
  await tester.pumpWidget(
    MaterialApp(
      theme: appTheme,
      builder: (context, child) {
        Widget applyPreference(bool reduced) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
          child: child!,
        );
        return motionPreference == null
            ? applyPreference(reduceMotion)
            : ValueListenableBuilder<bool>(
                valueListenable: motionPreference,
                builder: (_, reduced, _) => applyPreference(reduced),
              );
      },
      home: AppShell(store: store),
    ),
  );
  await tester.pumpAndSettle();
  return store;
}

int _pageIndex(Type pageType) => {
  DiscoveryPage: 0,
  ResumeLibrary: 1,
  MessagesPage: 2,
  ProfilePage: 3,
}[pageType]!;

FadeTransition _pageFade(WidgetTester tester, Type pageType) =>
    tester.widget<FadeTransition>(
      find.byKey(ValueKey('tab-fade-${_pageIndex(pageType)}')),
    );

Offset _pageOffset(WidgetTester tester, Type pageType) {
  final transform = tester
      .widget<Transform>(
        find.byKey(ValueKey('tab-offset-${_pageIndex(pageType)}')),
      )
      .transform;
  return Offset(transform.storage[12], transform.storage[13]);
}

void main() {
  testWidgets(
    'Switching fades and gently moves the incoming page while isolating the outgoing page',
    (tester) async {
      await _showShell(tester);
      expect(
        find.byKey(const ValueKey('discovery-company-benefits')).hitTestable(),
        findsOneWidget,
      );
      expect(find.semantics.byLabel(RegExp('企业福利')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('nav-1')));
      await tester.pump();

      final startOpacity = _pageFade(tester, ResumeLibrary).opacity.value;
      final startPosition = tester.getTopLeft(find.byType(ResumeLibrary));
      expect(startOpacity, lessThan(1));
      expect(_pageOffset(tester, ResumeLibrary), isNot(Offset.zero));
      expect(find.byType(DiscoveryPage), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 80));
      final middleOpacity = _pageFade(tester, ResumeLibrary).opacity.value;
      expect(middleOpacity, greaterThan(startOpacity));
      expect(middleOpacity, lessThan(1));
      expect(
        find.byKey(const ValueKey('discovery-company-benefits')).hitTestable(),
        findsNothing,
      );
      expect(find.semantics.byLabel(RegExp('企业福利')), findsNothing);
      expect(find.text('创建简历').hitTestable(), findsOneWidget);
      expect(find.semantics.byLabel('创建简历'), findsOneWidget);
      expect(
        TickerMode.valuesOf(tester.element(find.byType(DiscoveryPage))).enabled,
        isFalse,
      );
      expect(
        TickerMode.valuesOf(tester.element(find.byType(ResumeLibrary))).enabled,
        isTrue,
      );

      await tester.pumpAndSettle();

      expect(_pageFade(tester, ResumeLibrary).opacity.value, 1);
      expect(_pageOffset(tester, ResumeLibrary), Offset.zero);
      final endPosition = tester.getTopLeft(find.byType(ResumeLibrary));
      expect((startPosition - endPosition).distance, greaterThan(0));
      expect((startPosition - endPosition).distance, lessThanOrEqualTo(8));
      expect(find.byType(DiscoveryPage), findsNothing);
      expect(find.byType(DiscoveryPage, skipOffstage: false), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Rapid switches settle on the last page with one interactive tab',
    (tester) async {
      await _showShell(tester);
      for (final index in [1, 2, 0, 3]) {
        await tester.tap(find.byKey(ValueKey('nav-$index')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 30));
      }
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<AppBottomNavigation>(find.byType(AppBottomNavigation))
            .selectedIndex,
        3,
      );
      expect(find.byType(ProfilePage), findsOneWidget);
      expect(_pageFade(tester, ProfilePage).opacity.value, 1);
      expect(_pageOffset(tester, ProfilePage), Offset.zero);
      for (final pageType in [DiscoveryPage, ResumeLibrary, MessagesPage]) {
        expect(find.byType(pageType), findsNothing);
        final retained = find.byType(pageType, skipOffstage: false);
        expect(retained, findsOneWidget);
        expect(TickerMode.valuesOf(tester.element(retained)).enabled, isFalse);
      }
      expect(
        find.text('创建简历', skipOffstage: false).hitTestable(),
        findsNothing,
      );
      expect(find.semantics.byLabel('创建简历'), findsNothing);
      expect(find.semantics.byLabel(RegExp('企业福利')), findsNothing);
      expect(
        TickerMode.valuesOf(tester.element(find.byType(ProfilePage))).enabled,
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Repeated selection and store updates do not restart a transition',
    (tester) async {
      final store = await _showShell(tester);
      await tester.tap(find.byKey(const ValueKey('nav-1')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      final page = tester.element(find.byType(ResumeLibrary));
      final opacity = _pageFade(tester, ResumeLibrary).opacity.value;
      expect(opacity, allOf(greaterThan(0), lessThan(1)));

      await tester.tap(find.byKey(const ValueKey('nav-1')));
      await tester.pump();
      expect(
        _pageFade(tester, ResumeLibrary).opacity.value,
        greaterThanOrEqualTo(opacity),
      );
      await store.load('profile');
      await tester.pump();
      expect(
        _pageFade(tester, ResumeLibrary).opacity.value,
        greaterThanOrEqualTo(opacity),
      );
      expect(tester.element(find.byType(ResumeLibrary)), same(page));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('nav-1')));
      await tester.pump();
      expect(_pageFade(tester, ResumeLibrary).opacity.value, 1);
      expect(_pageOffset(tester, ResumeLibrary), Offset.zero);
      expect(tester.element(find.byType(ResumeLibrary)), same(page));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Returning to an existing tab preserves its state, draft and scroll',
    (tester) async {
      final store = await _showShell(tester);
      final page = tester.state(find.byType(DiscoveryPage));
      final nested = tester.state<NestedScrollViewState>(
        find.byType(NestedScrollView),
      );
      final search = find.byKey(const ValueKey('discovery-search'));
      final controller = tester.widget<TextField>(search).controller!;
      await tester.enterText(search, '发现搜索草稿');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      expect(nested.outerController.position.maxScrollExtent, greaterThan(60));
      nested.outerController.jumpTo(60);
      await tester.pumpAndSettle();
      final offset = nested.outerController.position.pixels;

      await tester.tap(find.byKey(const ValueKey('nav-1')));
      await tester.pumpAndSettle();
      await store.load('profile');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('nav-0')));
      await tester.pumpAndSettle();

      expect(tester.state(find.byType(DiscoveryPage)), same(page));
      expect(
        tester.state<NestedScrollViewState>(find.byType(NestedScrollView)),
        same(nested),
      );
      expect(tester.widget<TextField>(search).controller, same(controller));
      expect(controller.text, '发现搜索草稿');
      expect(nested.outerController.position.pixels, closeTo(offset, 0.001));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Reduced motion switches immediately without a page transition', (
    tester,
  ) async {
    await _showShell(tester, reduceMotion: true);
    await tester.tap(find.byKey(const ValueKey('nav-1')));
    await tester.pump();

    expect(_pageFade(tester, ResumeLibrary).opacity.value, 1);
    expect(_pageOffset(tester, ResumeLibrary), Offset.zero);
    expect(find.byType(DiscoveryPage), findsNothing);
    expect(find.byType(ResumeLibrary), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 80));
    expect(_pageFade(tester, ResumeLibrary).opacity.value, 1);
    expect(_pageOffset(tester, ResumeLibrary), Offset.zero);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Enabling reduced motion finishes a transition already in progress',
    (tester) async {
      final motionPreference = ValueNotifier(false);
      addTearDown(motionPreference.dispose);
      await _showShell(tester, motionPreference: motionPreference);
      await tester.tap(find.byKey(const ValueKey('nav-1')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      expect(
        _pageFade(tester, ResumeLibrary).opacity.value,
        allOf(greaterThan(0), lessThan(1)),
      );

      motionPreference.value = true;
      await tester.pump();
      expect(_pageFade(tester, ResumeLibrary).opacity.value, 1);
      expect(_pageOffset(tester, ResumeLibrary), Offset.zero);
      expect(find.byType(DiscoveryPage), findsNothing);
      expect(find.byType(ResumeLibrary), findsOneWidget);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Keyboard hides the navigation and restores the selected page and its draft',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 720);
      tester.view.padding = const FakeViewPadding(bottom: 24);
      tester.view.viewPadding = const FakeViewPadding(bottom: 24);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetPadding);
      addTearDown(tester.view.resetViewPadding);
      addTearDown(tester.view.resetViewInsets);
      final store = await testStore(authenticated: true);
      addTearDown(store.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: AppShell(store: store),
        ),
      );
      await tester.pumpAndSettle();
      final pageState = tester.state(find.byType(DiscoveryPage));
      final search = find.byKey(const ValueKey('discovery-search'));
      final controller = tester.widget<TextField>(search).controller!;
      final bar = tester.getRect(find.byType(AppBottomNavigation));
      await tester.enterText(search, '发现搜索草稿');
      tester.view.viewInsets = const FakeViewPadding(bottom: 244);
      await tester.pumpAndSettle();

      for (final index in [0, 1, 2, 3]) {
        expect(find.byKey(ValueKey('nav-$index')).hitTestable(), findsNothing);
      }
      expect(find.byType(AppBottomNavigation), findsNothing);
      expect(tester.state(find.byType(DiscoveryPage)), same(pageState));
      expect(tester.widget<TextField>(search).controller, same(controller));
      expect(controller.text, '发现搜索草稿');
      expect(tester.takeException(), isNull);

      FocusManager.instance.primaryFocus?.unfocus();
      tester.view.viewInsets = FakeViewPadding.zero;
      await tester.pumpAndSettle();

      final navigation = tester.widget<AppBottomNavigation>(
        find.byType(AppBottomNavigation),
      );
      expect(navigation.selectedIndex, 0);
      expect(tester.getRect(find.byType(AppBottomNavigation)), bar);
      expect(tester.state(find.byType(DiscoveryPage)), same(pageState));
      expect(tester.widget<TextField>(search).controller, same(controller));
      expect(controller.text, '发现搜索草稿');

      await tester.tap(find.byKey(const ValueKey('nav-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('nav-0')));
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(DiscoveryPage)), same(pageState));
      expect(tester.widget<TextField>(search).controller, same(controller));
      expect(controller.text, '发现搜索草稿');
      expect(tester.takeException(), isNull);
    },
  );
}
