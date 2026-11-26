import 'package:bojian_mobile/account_pages.dart';
import 'package:bojian_mobile/app_shell.dart';
import 'package:bojian_mobile/app_store.dart';
import 'package:bojian_mobile/design.dart';
import 'package:bojian_mobile/discovery.dart';
import 'package:bojian_mobile/membership_page.dart';
import 'package:bojian_mobile/customer_service_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';
import 'support/profile_navigation_helpers.dart';

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

double _pageLeft(WidgetTester tester, Type pageType) =>
    tester.getTopLeft(find.byType(pageType)).dx;

void main() {
  testWidgets(
    'Membership opens from discovery and retains state when revisited',
    (tester) async {
      final store = await _showShell(tester);
      await tapDiscoveryMenuItem(tester, 'discovery-membership');
      await tester.pumpAndSettle();
      final membership = tester.widget<MembershipPage>(
        find.byType(MembershipPage),
      );
      final state = tester.state(find.byType(MembershipPage));
      expect(membership.embedded, isTrue);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(DiscoveryPage), findsOneWidget);
      await tapDiscoveryMenuItem(tester, 'discovery-membership');
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(MembershipPage)), same(state));
      expect(membership.store, same(store));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Service and profile return to discovery without a bottom bar', (
    tester,
  ) async {
    await _showShell(tester);
    final home = tester.state(find.byType(DiscoveryPage));
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold).first).bottomNavigationBar,
      isNull,
    );
    await tapDiscoveryMenuItem(tester, 'discovery-service');
    await tester.pumpAndSettle();
    expect(find.byType(CustomerServicePage), findsOneWidget);
    tester
        .state<AppShellState>(find.byType(AppShell))
        .select(AppShell.profileTab);
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(CustomerServicePage), findsOneWidget);
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    expect(tester.state(find.byType(DiscoveryPage)), same(home));
    await tapDiscoveryMenuItem(tester, 'discovery-my-page');
    await tester.pumpAndSettle();
    expect(find.byType(ProfilePage), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(tester.state(find.byType(DiscoveryPage)), same(home));
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
    await tapDiscoveryMenuItem(tester, 'discovery-membership');
    await tester.pumpAndSettle();
    expect(find.byType(MembershipPage), findsNothing);
    expect(find.text('登录 / 注册'), findsOneWidget);
    expect(api.calls, isNot(contains('GetMembership')));
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(DiscoveryPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

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
      expect(find.byType(DiscoveryPage), findsOneWidget);
      tester.view.physicalSize = const Size(360, 640);
      await tapDiscoveryMenuItem(tester, 'discovery-my-page');
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
        tester.state<AppShellState>(find.byType(AppShell)).selected,
        AppShell.profileTab,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Opening slides the new page in from the right and back restores the previous page from the left',
    (tester) async {
      await _showShell(tester);
      expect(
        find.byKey(const ValueKey('discovery-messages')).hitTestable(),
        findsOneWidget,
      );
      expect(find.byTooltip('我的').hitTestable(), findsOneWidget);
      await tapDiscoveryMenuItem(tester, 'discovery-membership');
      await tester.pump();

      final width = tester.getSize(find.byType(DiscoveryPage)).width;
      expect(_pageLeft(tester, MembershipPage), width);
      expect(_pageLeft(tester, DiscoveryPage), 0);
      await tester.pump(const Duration(milliseconds: 80));
      final entering = _pageLeft(tester, MembershipPage);
      final leaving = _pageLeft(tester, DiscoveryPage);
      expect(entering, allOf(greaterThan(0), lessThan(width)));
      expect(leaving, lessThan(0));
      expect(entering - leaving, closeTo(width, 0.001));
      expect(
        find.byKey(const ValueKey('discovery-messages')).hitTestable(),
        findsNothing,
      );
      expect(find.byTooltip('我的').hitTestable(), findsNothing);
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

      expect(_pageLeft(tester, MembershipPage), 0);
      expect(find.byType(DiscoveryPage), findsNothing);
      expect(find.byType(DiscoveryPage, skipOffstage: false), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(_pageLeft(tester, DiscoveryPage), -width);
      await tester.pump(const Duration(milliseconds: 80));
      final returning = _pageLeft(tester, DiscoveryPage);
      final exiting = _pageLeft(tester, MembershipPage);
      expect(returning, allOf(greaterThan(-width), lessThan(0)));
      expect(exiting, greaterThan(0));
      expect(exiting - returning, closeTo(width, 0.001));
      await tester.pumpAndSettle();
      expect(_pageLeft(tester, DiscoveryPage), 0);
      expect(find.byType(MembershipPage), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Queued back follows history when tab numbers run in reverse', (
    tester,
  ) async {
    await _showShell(tester);
    final shell = tester.state<AppShellState>(find.byType(AppShell));
    shell.select(AppShell.profileTab);
    await tester.pumpAndSettle();
    final width = tester.getSize(find.byType(ProfilePage)).width;

    shell.select(AppShell.serviceTab);
    await tester.pump();
    expect(_pageLeft(tester, CustomerServicePage), width);
    await tester.pump(const Duration(milliseconds: 80));
    final beforeBack = _pageLeft(tester, CustomerServicePage);
    shell.goBack();
    await tester.pump();
    expect(_pageLeft(tester, CustomerServicePage), beforeBack);
    await tester.pump(appPageTransitionDuration);
    await tester.pump(const Duration(milliseconds: 80));
    final returning = _pageLeft(tester, ProfilePage);
    final exiting = _pageLeft(tester, CustomerServicePage);
    expect(returning, allOf(greaterThan(-width), lessThan(0)));
    expect(exiting - returning, closeTo(width, 0.001));
    await tester.pumpAndSettle();
    expect(_pageLeft(tester, ProfilePage), 0);
  });

  testWidgets(
    'Rapid switches settle on the last page with one interactive tab',
    (tester) async {
      await _showShell(tester);
      final shell = tester.state<AppShellState>(find.byType(AppShell));
      shell.select(AppShell.membershipTab);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));
      final beforeNextSelection = _pageLeft(tester, MembershipPage);
      shell.select(AppShell.serviceTab);
      await tester.pump();
      expect(_pageLeft(tester, MembershipPage), beforeNextSelection);
      for (final index in [0, AppShell.profileTab]) {
        shell.select(index);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 30));
      }
      await tester.pumpAndSettle();

      expect(
        tester.state<AppShellState>(find.byType(AppShell)).selected,
        AppShell.profileTab,
      );
      expect(find.byType(ProfilePage), findsOneWidget);
      expect(_pageLeft(tester, ProfilePage), 0);
      for (final pageType in [
        DiscoveryPage,
        MembershipPage,
        CustomerServicePage,
      ]) {
        expect(find.byType(pageType), findsNothing);
        final retained = find.byType(pageType, skipOffstage: false);
        expect(retained, findsOneWidget);
        expect(TickerMode.valuesOf(tester.element(retained)).enabled, isFalse);
      }
      expect(find.byTooltip('我的').hitTestable(), findsNothing);
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
      await tapDiscoveryMenuItem(tester, 'discovery-membership');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      final page = tester.element(find.byType(MembershipPage));
      final left = _pageLeft(tester, MembershipPage);
      final width = tester.getSize(find.byType(MembershipPage)).width;
      expect(left, allOf(greaterThan(0), lessThan(width)));

      tester
          .state<AppShellState>(find.byType(AppShell))
          .select(AppShell.membershipTab);
      await tester.pump();
      expect(_pageLeft(tester, MembershipPage), lessThanOrEqualTo(left));
      await store.load('profile');
      await tester.pump();
      expect(_pageLeft(tester, MembershipPage), lessThanOrEqualTo(left));
      expect(tester.element(find.byType(MembershipPage)), same(page));
      await tester.pumpAndSettle();
      tester
          .state<AppShellState>(find.byType(AppShell))
          .select(AppShell.membershipTab);
      await tester.pump();
      expect(_pageLeft(tester, MembershipPage), 0);
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
      tester.view.physicalSize = const Size(360, 220);
      await tester.pumpAndSettle();
      final search = find.byKey(const ValueKey('discovery-search'));
      final controller = tester.widget<TextField>(search).controller!;
      final scroll = discoveryFeedPosition(tester);
      await tester.enterText(search, '一页简历');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      expect(scroll.maxScrollExtent, greaterThan(60));
      scroll.jumpTo(60);
      await tester.pumpAndSettle();
      final offset = scroll.pixels;

      tester
          .state<AppShellState>(find.byType(AppShell))
          .select(AppShell.membershipTab);
      await tester.pumpAndSettle();
      await store.load('profile');
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(tester.state(find.byType(DiscoveryPage)), same(page));
      expect(discoveryFeedPosition(tester), same(scroll));
      expect(controller.text, '一页简历');
      expect(scroll.pixels, closeTo(offset, 0.001));
      scroll.jumpTo(0);
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(search).controller, same(controller));
      expect(controller.text, '一页简历');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Reduced motion switches immediately without a page transition', (
    tester,
  ) async {
    await _showShell(tester, reduceMotion: true);
    await tapDiscoveryMenuItem(tester, 'discovery-membership');
    await tester.pump();

    expect(_pageLeft(tester, MembershipPage), 0);
    expect(find.byType(DiscoveryPage), findsNothing);
    expect(find.byType(MembershipPage), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 80));
    expect(_pageLeft(tester, MembershipPage), 0);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Enabling reduced motion finishes a transition already in progress',
    (tester) async {
      final motionPreference = ValueNotifier(false);
      addTearDown(motionPreference.dispose);
      await _showShell(tester, motionPreference: motionPreference);
      await tapDiscoveryMenuItem(tester, 'discovery-membership');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      expect(
        _pageLeft(tester, MembershipPage),
        allOf(
          greaterThan(0),
          lessThan(tester.getSize(find.byType(MembershipPage)).width),
        ),
      );

      motionPreference.value = true;
      await tester.pump();
      expect(_pageLeft(tester, MembershipPage), 0);
      expect(find.byType(DiscoveryPage), findsNothing);
      expect(find.byType(MembershipPage), findsOneWidget);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Opening and closing the keyboard preserves the discovery search draft',
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
      expect(
        tester
            .widget<Scaffold>(find.byType(Scaffold).first)
            .bottomNavigationBar,
        isNull,
      );
      await tester.enterText(search, '发现搜索草稿');
      tester.view.viewInsets = const FakeViewPadding(bottom: 244);
      await tester.pumpAndSettle();

      expect(tester.state(find.byType(DiscoveryPage)), same(pageState));
      expect(tester.widget<TextField>(search).controller, same(controller));
      expect(controller.text, '发现搜索草稿');
      expect(tester.takeException(), isNull);

      FocusManager.instance.primaryFocus?.unfocus();
      tester.view.viewInsets = FakeViewPadding.zero;
      await tester.pumpAndSettle();

      expect(tester.state(find.byType(DiscoveryPage)), same(pageState));
      expect(tester.widget<TextField>(search).controller, same(controller));
      expect(controller.text, '发现搜索草稿');

      await tapDiscoveryMenuItem(tester, 'discovery-membership');
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(DiscoveryPage)), same(pageState));
      expect(tester.widget<TextField>(search).controller, same(controller));
      expect(controller.text, '发现搜索草稿');
      expect(tester.takeException(), isNull);
    },
  );
}
