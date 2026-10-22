import 'package:bojian_mobile/account_pages.dart';
import 'package:bojian_mobile/app_bottom_navigation.dart';
import 'package:bojian_mobile/app_shell.dart';
import 'package:bojian_mobile/app_store.dart';
import 'package:bojian_mobile/design.dart';
import 'package:bojian_mobile/discovery.dart';
import 'package:bojian_mobile/resume_pages.dart';
import 'package:bojian_mobile/points_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

Future<AppStore> _showShell(
  WidgetTester tester, {
  bool reduceMotion = false,
  ValueNotifier<bool>? motionPreference,
  double textScale = 1,
  bool dark = false,
  Size size = const Size(360, 720),
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
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
      theme: dark ? appDarkTheme : appTheme,
      builder: (context, child) {
        Widget applyPreference(bool reduced) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: reduced,
            textScaler: TextScaler.linear(textScale),
          ),
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
  PointsPage: 2,
  TemplateMarket: 1,
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
    'The market filters and keyboard fit a small dark screen with 2x text',
    (tester) async {
      await _showShell(
        tester,
        size: const Size(320, 640),
        textScale: 2,
        dark: true,
      );
      await tester.tap(find.byKey(const ValueKey('nav-1')));
      await tester.pumpAndSettle();
      final own = find.widgetWithText(ChoiceChip, '我的模板');
      await tester.ensureVisible(own);
      await tester.pumpAndSettle();
      await tester.tap(own);
      await tester.pumpAndSettle();
      expect(find.text('暂无已获取模板'), findsOneWidget);
      addTearDown(tester.view.resetViewInsets);
      tester.view.viewInsets = const FakeViewPadding(bottom: 260);
      await tester.pumpAndSettle();
      expect(find.byType(AppBottomNavigation), findsNothing);
      expect(find.byType(TextField).hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'The second destination opens the existing template market and retains search',
    (tester) async {
      await _showShell(tester);
      await tester.tap(find.byKey(const ValueKey('nav-1')));
      await tester.pumpAndSettle();
      expect(find.byType(TemplateMarket), findsOneWidget);
      expect(find.byType(MessagesPage), findsNothing);
      expect(find.byKey(const ValueKey('nav-unread-badge')), findsNothing);
      final page = tester.element(find.byType(TemplateMarket));
      final field = find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.hintText == '搜索模板或作者',
      );
      await tester.enterText(field, '工程');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('nav-0')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('nav-1')));
      await tester.pumpAndSettle();
      expect(tester.element(find.byType(TemplateMarket)), same(page));
      expect(tester.widget<TextField>(field).controller!.text, '工程');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Top message entries return to discovery and the collapsed profile without changing tabs',
    (tester) async {
      await _showShell(tester);
      final search = find.byKey(const ValueKey('discovery-search'));
      await tester.enterText(search, '保留的搜索');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('discovery-messages')));
      await tester.pumpAndSettle();
      expect(find.byType(MessagesPage), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(search).controller!.text, '保留的搜索');
      expect(
        tester
            .widget<AppBottomNavigation>(find.byType(AppBottomNavigation))
            .selectedIndex,
        0,
      );
      tester.view.physicalSize = const Size(360, 640);
      await tester.tap(find.byKey(const ValueKey('nav-3')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('profile-messages')));
      await tester.pumpAndSettle();
      expect(find.byType(MessagesPage), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      final list = find.byKey(const ValueKey('profile-scroll'));
      final scrolling = tester
          .state<NestedScrollViewState>(list)
          .outerController
          .position;
      final name = find.byKey(const ValueKey('profile-identity-name'));
      final target =
          tester.getTopLeft(name).dy - tester.getTopLeft(list).dy + 1;
      scrolling.jumpTo(target);
      await tester.pumpAndSettle();
      final entry = find.byKey(const ValueKey('profile-messages'));
      expect(entry.hitTestable(), findsOneWidget);
      await tester.tap(entry);
      await tester.pumpAndSettle();
      expect(find.byType(MessagesPage), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(scrolling.pixels, closeTo(target, .001));
      expect(entry.hitTestable(), findsOneWidget);
      expect(
        tester
            .widget<AppBottomNavigation>(find.byType(AppBottomNavigation))
            .selectedIndex,
        3,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Switching fades and gently moves the incoming page while isolating the outgoing page',
    (tester) async {
      await _showShell(tester);
      expect(
        find.byKey(const ValueKey('discovery-messages')).hitTestable(),
        findsOneWidget,
      );
      expect(find.semantics.byLabel(RegExp('推荐')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('nav-2')));
      await tester.pump();

      final startOpacity = _pageFade(tester, PointsPage).opacity.value;
      final startPosition = tester.getTopLeft(find.byType(PointsPage));
      expect(startOpacity, lessThan(1));
      expect(_pageOffset(tester, PointsPage), isNot(Offset.zero));
      expect(find.byType(DiscoveryPage), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 80));
      final middleOpacity = _pageFade(tester, PointsPage).opacity.value;
      expect(middleOpacity, greaterThan(startOpacity));
      expect(middleOpacity, lessThan(1));
      expect(
        find.byKey(const ValueKey('discovery-messages')).hitTestable(),
        findsNothing,
      );
      expect(find.semantics.byLabel(RegExp('推荐')), findsNothing);
      expect(find.text('我的积分').hitTestable(), findsOneWidget);
      expect(find.semantics.byLabel(RegExp('可用积分')), findsOneWidget);
      expect(
        TickerMode.valuesOf(tester.element(find.byType(DiscoveryPage))).enabled,
        isFalse,
      );
      expect(
        TickerMode.valuesOf(tester.element(find.byType(PointsPage))).enabled,
        isTrue,
      );

      await tester.pumpAndSettle();

      expect(_pageFade(tester, PointsPage).opacity.value, 1);
      expect(_pageOffset(tester, PointsPage), Offset.zero);
      final endPosition = tester.getTopLeft(find.byType(PointsPage));
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
      for (final pageType in [DiscoveryPage, PointsPage, TemplateMarket]) {
        expect(find.byType(pageType), findsNothing);
        final retained = find.byType(pageType, skipOffstage: false);
        expect(retained, findsOneWidget);
        expect(TickerMode.valuesOf(tester.element(retained)).enabled, isFalse);
      }
      expect(
        find.text('我的积分', skipOffstage: false).hitTestable(),
        findsNothing,
      );
      expect(find.semantics.byLabel(RegExp('可用积分')), findsNothing);
      expect(find.semantics.byLabel(RegExp('推荐')), findsNothing);
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
      await tester.tap(find.byKey(const ValueKey('nav-2')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      final page = tester.element(find.byType(PointsPage));
      final opacity = _pageFade(tester, PointsPage).opacity.value;
      expect(opacity, allOf(greaterThan(0), lessThan(1)));

      await tester.tap(find.byKey(const ValueKey('nav-2')));
      await tester.pump();
      expect(
        _pageFade(tester, PointsPage).opacity.value,
        greaterThanOrEqualTo(opacity),
      );
      await store.load('profile');
      await tester.pump();
      expect(
        _pageFade(tester, PointsPage).opacity.value,
        greaterThanOrEqualTo(opacity),
      );
      expect(tester.element(find.byType(PointsPage)), same(page));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('nav-2')));
      await tester.pump();
      expect(_pageFade(tester, PointsPage).opacity.value, 1);
      expect(_pageOffset(tester, PointsPage), Offset.zero);
      expect(tester.element(find.byType(PointsPage)), same(page));
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

      await tester.tap(find.byKey(const ValueKey('nav-2')));
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
      expect(controller.text, '发现搜索草稿');
      expect(nested.outerController.position.pixels, closeTo(offset, 0.001));
      nested.outerController.jumpTo(0);
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(search).controller, same(controller));
      expect(controller.text, '发现搜索草稿');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Reduced motion switches immediately without a page transition', (
    tester,
  ) async {
    await _showShell(tester, reduceMotion: true);
    await tester.tap(find.byKey(const ValueKey('nav-2')));
    await tester.pump();

    expect(_pageFade(tester, PointsPage).opacity.value, 1);
    expect(_pageOffset(tester, PointsPage), Offset.zero);
    expect(find.byType(DiscoveryPage), findsNothing);
    expect(find.byType(PointsPage), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 80));
    expect(_pageFade(tester, PointsPage).opacity.value, 1);
    expect(_pageOffset(tester, PointsPage), Offset.zero);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Enabling reduced motion finishes a transition already in progress',
    (tester) async {
      final motionPreference = ValueNotifier(false);
      addTearDown(motionPreference.dispose);
      await _showShell(tester, motionPreference: motionPreference);
      await tester.tap(find.byKey(const ValueKey('nav-2')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      expect(
        _pageFade(tester, PointsPage).opacity.value,
        allOf(greaterThan(0), lessThan(1)),
      );

      motionPreference.value = true;
      await tester.pump();
      expect(_pageFade(tester, PointsPage).opacity.value, 1);
      expect(_pageOffset(tester, PointsPage), Offset.zero);
      expect(find.byType(DiscoveryPage), findsNothing);
      expect(find.byType(PointsPage), findsOneWidget);
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

      await tester.tap(find.byKey(const ValueKey('nav-2')));
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
