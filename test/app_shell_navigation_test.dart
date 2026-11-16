import 'package:bojian_mobile/account_pages.dart';
import 'package:bojian_mobile/app_bottom_navigation.dart';
import 'package:bojian_mobile/app_shell.dart';
import 'package:bojian_mobile/app_store.dart';
import 'package:bojian_mobile/design.dart';
import 'package:bojian_mobile/discovery.dart';
import 'package:bojian_mobile/resume_pages.dart';
import 'package:bojian_mobile/membership_page.dart';
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
  MembershipPage: AppShell.membershipTab,
  TemplateMarket: 1,
  ProfilePage: AppShell.profileTab,
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
  testWidgets('Membership is a retained tab with no back button', (
    tester,
  ) async {
    final store = await _showShell(tester);
    await tester.tap(find.byKey(const ValueKey('nav-2')));
    await tester.pumpAndSettle();
    final membership = tester.widget<MembershipPage>(
      find.byType(MembershipPage),
    );
    final state = tester.state(find.byType(MembershipPage));
    expect(membership.embedded, isTrue);
    expect(find.byType(BackButton), findsNothing);
    expect(find.byType(AppBottomNavigation), findsOneWidget);
    expect(
      ModalRoute.of(tester.element(find.byType(MembershipPage)))!.canPop,
      isFalse,
    );

    await tester.tap(find.byKey(const ValueKey('nav-3')));
    await tester.pumpAndSettle();
    expect(find.byType(ProfilePage), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('nav-2')));
    await tester.pumpAndSettle();
    expect(tester.state(find.byType(MembershipPage)), same(state));
    expect(membership.store, same(store));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Membership keeps guest users behind the login entry', (
    tester,
  ) async {
    final api = FakeGateway();
    final store = await testStore(api: api);
    addTearDown(store.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: AppShell(store: store),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('nav-2')));
    await tester.pumpAndSettle();
    expect(find.byType(MembershipPage), findsNothing);
    expect(find.text('登录 / 注册'), findsOneWidget);
    expect(api.calls, isNot(contains('GetMembership')));
    expect(tester.takeException(), isNull);
  });

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
      // Owned templates moved out of the market tabs; use the last filter.
      final paid = find.byKey(const ValueKey('market-tab-paid'));
      await tester.ensureVisible(paid);
      await tester.pumpAndSettle();
      await tester.tap(paid);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
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
            widget is TextField && widget.decoration?.hintText == '搜索模板',
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
    'Top message and settings entries return to their tabs without losing scroll',
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
      await tester.tap(find.byKey(const ValueKey('profile-settings')));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsPage), findsOneWidget);
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
      final entry = find.byKey(const ValueKey('profile-settings'));
      expect(entry.hitTestable(), findsOneWidget);
      await tester.tap(entry);
      await tester.pumpAndSettle();
      expect(find.byType(SettingsPage), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(scrolling.pixels, closeTo(target, .001));
      expect(entry.hitTestable(), findsOneWidget);
      expect(
        tester
            .widget<AppBottomNavigation>(find.byType(AppBottomNavigation))
            .selectedIndex,
        AppShell.profileTab,
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
      expect(find.semantics.byLabel(RegExp(r'^推荐')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('nav-2')));
      await tester.pump();

      final startOpacity = _pageFade(tester, MembershipPage).opacity.value;
      final startPosition = tester.getTopLeft(find.byType(MembershipPage));
      expect(startOpacity, lessThan(1));
      expect(_pageOffset(tester, MembershipPage), isNot(Offset.zero));
      expect(find.byType(DiscoveryPage), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 80));
      final middleOpacity = _pageFade(tester, MembershipPage).opacity.value;
      expect(middleOpacity, greaterThan(startOpacity));
      expect(middleOpacity, lessThan(1));
      expect(
        find.byKey(const ValueKey('discovery-messages')).hitTestable(),
        findsNothing,
      );
      expect(find.semantics.byLabel(RegExp(r'^推荐')), findsNothing);
      expect(
        TickerMode.valuesOf(tester.element(find.byType(DiscoveryPage))).enabled,
        isFalse,
      );
      expect(
        TickerMode.valuesOf(tester.element(find.byType(MembershipPage)))
            .enabled,
        isTrue,
      );

      await tester.pumpAndSettle();

      expect(_pageFade(tester, MembershipPage).opacity.value, 1);
      expect(_pageOffset(tester, MembershipPage), Offset.zero);
      final endPosition = tester.getTopLeft(find.byType(MembershipPage));
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
        AppShell.profileTab,
      );
      expect(find.byType(ProfilePage), findsOneWidget);
      expect(_pageFade(tester, ProfilePage).opacity.value, 1);
      expect(_pageOffset(tester, ProfilePage), Offset.zero);
      for (final pageType in [DiscoveryPage, MembershipPage, TemplateMarket]) {
        expect(find.byType(pageType), findsNothing);
        final retained = find.byType(pageType, skipOffstage: false);
        expect(retained, findsOneWidget);
        expect(TickerMode.valuesOf(tester.element(retained)).enabled, isFalse);
      }
      expect(find.semantics.byLabel(RegExp(r'^推荐')), findsNothing);
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
      final page = tester.element(find.byType(MembershipPage));
      final opacity = _pageFade(tester, MembershipPage).opacity.value;
      expect(opacity, allOf(greaterThan(0), lessThan(1)));

      await tester.tap(find.byKey(const ValueKey('nav-2')));
      await tester.pump();
      expect(
        _pageFade(tester, MembershipPage).opacity.value,
        greaterThanOrEqualTo(opacity),
      );
      await store.load('profile');
      await tester.pump();
      expect(
        _pageFade(tester, MembershipPage).opacity.value,
        greaterThanOrEqualTo(opacity),
      );
      expect(tester.element(find.byType(MembershipPage)), same(page));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('nav-2')));
      await tester.pump();
      expect(_pageFade(tester, MembershipPage).opacity.value, 1);
      expect(_pageOffset(tester, MembershipPage), Offset.zero);
      expect(tester.element(find.byType(MembershipPage)), same(page));
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

    expect(_pageFade(tester, MembershipPage).opacity.value, 1);
    expect(_pageOffset(tester, MembershipPage), Offset.zero);
    expect(find.byType(DiscoveryPage), findsNothing);
    expect(find.byType(MembershipPage), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 80));
    expect(_pageFade(tester, MembershipPage).opacity.value, 1);
    expect(_pageOffset(tester, MembershipPage), Offset.zero);
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
        _pageFade(tester, MembershipPage).opacity.value,
        allOf(greaterThan(0), lessThan(1)),
      );

      motionPreference.value = true;
      await tester.pump();
      expect(_pageFade(tester, MembershipPage).opacity.value, 1);
      expect(_pageOffset(tester, MembershipPage), Offset.zero);
      expect(find.byType(DiscoveryPage), findsNothing);
      expect(find.byType(MembershipPage), findsOneWidget);
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

      for (final index in [0, 1, 2, 3, 4]) {
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
