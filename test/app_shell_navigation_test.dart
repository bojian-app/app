import 'package:bojian_mobile/account_pages.dart';
import 'package:bojian_mobile/app_shell.dart';
import 'package:bojian_mobile/app_store.dart';
import 'package:bojian_mobile/app_tab_bar.dart';
import 'package:bojian_mobile/app_update.dart';
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
      await tapAppTab(tester, 'membership');
      await tester.pumpAndSettle();
      final membership = tester.widget<MembershipPage>(
        find.byType(MembershipPage),
      );
      final state = tester.state(find.byType(MembershipPage));
      expect(membership.embedded, isTrue);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(DiscoveryPage), findsOneWidget);
      await tapAppTab(tester, 'membership');
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(MembershipPage)), same(state));
      expect(membership.store, same(store));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('The tab bar opens every destination', (tester) async {
    await _showShell(tester);
    final shell = tester.state<AppShellState>(find.byType(AppShell));
    for (final (name, tab, page) in [
      ('membership', AppShell.membershipTab, MembershipPage),
      ('messages', AppShell.messagesTab, MessagesPage),
      ('profile', AppShell.profileTab, ProfilePage),
      ('home', 0, DiscoveryPage),
    ]) {
      await tester.tap(find.byKey(ValueKey('app-tab-$name')));
      await tester.pumpAndSettle();
      expect(shell.selected, tab);
      expect(find.byType(page), findsOneWidget);
      expect(find.byTooltip('返回'), findsNothing);
    }
    await tester.tap(find.byKey(const ValueKey('app-tab-publish')));
    await tester.pumpAndSettle();
    expect(find.byType(StoryComposer), findsOneWidget);
    expect(find.byType(AppTabBar), findsNothing);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(shell.selected, 0);
    expect(find.byType(AppTabBar), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('The tab bar clears the system inset and the end of a page', (
    tester,
  ) async {
    await _showShell(tester);
    final bar = tester.getRect(find.byKey(const ValueKey('app-tab-bar')));
    // 24pt of gesture area plus the 4pt gap.
    expect(bar.bottom, 720 - 28);
    expect(bar.height, AppTabBar.height);
    // The publish button stands out above the capsule, and pages end above it.
    final publish = tester.getRect(
      find.byKey(const ValueKey('app-tab-publish')),
    );
    expect(publish.top, bar.top - AppTabBar.rise);
    expect(publish.center.dx, bar.center.dx);
    expect(find.text('发布新动态'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('app-tab-membership')));
    await tester.pumpAndSettle();
    final list = tester.widget<ListView>(
      find.descendant(
        of: find.byType(MembershipPage),
        matching: find.byType(ListView),
      ),
    );
    expect(
      (list.padding! as EdgeInsets).bottom,
      greaterThanOrEqualTo(720 - publish.top),
    );
    await tester.tap(find.byKey(const ValueKey('app-tab-home')));
    await tester.pumpAndSettle();
    await tester.tapAt(publish.topCenter + const Offset(0, 4));
    await tester.pumpAndSettle();
    expect(find.byType(StoryComposer), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    // Lets the shell's idle warm-up timer fire before the test ends.
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'The messages tab counts unread notifications and reads them only when open',
    (tester) async {
      final store = await _showShell(tester);
      final api = store.api as FakeGateway;
      api.documents['GetNotifications'] = {
        'unread_count': 1,
        'items': [
          {
            'id': 5,
            'type': 'SYSTEM',
            'payload': {'title': '导出已完成', 'body': '你的文件已准备好'},
            'created_at': '2026-10-08T05:50:00Z',
            'read_at': null,
          },
        ],
      };
      final entry = find.byKey(const ValueKey('app-tab-messages'));
      final badge = find.descendant(
        of: entry,
        matching: find.byKey(const ValueKey('messages-unread-badge')),
      );
      await tester.tap(entry);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('app-tab-home')));
      await tester.pumpAndSettle();

      // A notification arriving while the tab is hidden stays unread.
      api.calls.clear();
      api.documents['GetNotifications'] = {
        'unread_count': 1,
        'items': [
          {
            'id': 6,
            'type': 'SYSTEM',
            'payload': {'title': '新通知', 'body': '新内容'},
            'created_at': '2026-10-09T05:50:00Z',
            'read_at': null,
          },
        ],
      };
      await store.load('messages');
      await tester.pumpAndSettle();
      expect(api.calls, isNot(contains('PostNotificationsRead')));
      expect(
        find.descendant(of: badge, matching: find.text('1')),
        findsOneWidget,
      );

      // Coming back refreshes the list, which then counts as read.
      api.calls.clear();
      await tester.tap(entry);
      await tester.pumpAndSettle();
      expect(api.calls, contains('GetNotifications'));
      expect(api.calls, contains('PostNotificationsRead'));
      expect(find.text('新通知'), findsOneWidget);
      expect(badge, findsNothing);
      final list = tester.widget<ListView>(
        find.descendant(
          of: find.byType(MessagesPage),
          matching: find.byType(ListView),
        ),
      );
      expect(
        (list.padding! as EdgeInsets).bottom,
        greaterThanOrEqualTo(AppTabBar.height),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('The profile tab flags an available app update', (tester) async {
    final updates = AppUpdates.instance;
    final installed = updates.installedBuild;
    final releases = updates.releases;
    addTearDown(() {
      updates.installedBuild = installed;
      updates.releases = releases;
    });
    updates.installedBuild = 1;
    updates.releases = [
      AppRelease.fromJson({
        'build_number': 2,
        'download_url': 'https://example.com/app.apk',
      }),
    ];
    final store = await _showShell(tester);
    final badge = find.descendant(
      of: find.byKey(const ValueKey('app-tab-profile')),
      matching: find.byType(Badge),
    );
    expect(tester.widget<Badge>(badge).isLabelVisible, isTrue);
    // No other tab carries it.
    expect(
      find.descendant(of: find.byType(AppTabBar), matching: find.byType(Badge)),
      findsOneWidget,
    );
    updates.installedBuild = 2;
    store.changed();
    await tester.pumpAndSettle();
    expect(tester.widget<Badge>(badge).isLabelVisible, isFalse);
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Messages and profile return to discovery through back', (
    tester,
  ) async {
    await _showShell(tester);
    final home = tester.state(find.byType(DiscoveryPage));
    await tapAppTab(tester, 'messages');
    await tester.pumpAndSettle();
    expect(find.byType(MessagesPage), findsOneWidget);
    tester
        .state<AppShellState>(find.byType(AppShell))
        .select(AppShell.profileTab);
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(MessagesPage), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(tester.state(find.byType(DiscoveryPage)), same(home));
    await tapAppTab(tester, 'profile');
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
    await tapAppTab(tester, 'membership');
    await tester.pumpAndSettle();
    expect(find.byType(MembershipPage), findsNothing);
    expect(find.text('登录 / 注册'), findsOneWidget);
    expect(api.calls, isNot(contains('GetMembership')));
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(DiscoveryPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Message tab and settings entries return without losing scroll', (
    tester,
  ) async {
    await _showShell(tester);
    final search = find.byKey(const ValueKey('discovery-search'));
    await tester.enterText(search, '保留的搜索');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    await tapAppTab(tester, 'messages');
    await tester.pumpAndSettle();
    expect(find.byType(MessagesPage), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(search).controller!.text, '保留的搜索');
    expect(find.byType(DiscoveryPage), findsOneWidget);
    tester.view.physicalSize = const Size(360, 640);
    await tapAppTab(tester, 'profile');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('profile-settings')));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsPage), findsOneWidget);
    final service = find.byKey(const ValueKey('settings-customer-service'));
    await tester.scrollUntilVisible(
      service,
      120,
      scrollable: find
          .descendant(
            of: find.byType(SettingsPage),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.ensureVisible(service);
    await tester.pumpAndSettle();
    await tester.tap(service);
    await tester.pumpAndSettle();
    expect(find.byType(CustomerServicePage), findsOneWidget);
    await tester.tap(find.text('发起新服务'));
    await tester.pumpAndSettle();
    expect(find.text('客服小简'), findsWidgets);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('发起新服务'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(CustomerServicePage), findsNothing);
    expect(find.byType(SettingsPage), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    final list = find.byKey(const ValueKey('profile-scroll'));
    final scrolling = tester
        .state<NestedScrollViewState>(list)
        .outerController
        .position;
    final name = find.byKey(const ValueKey('profile-identity-name'));
    final target = tester.getTopLeft(name).dy - tester.getTopLeft(list).dy + 1;
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
  });

  testWidgets(
    'Opening slides the new page in from the right and back restores the previous page from the left',
    (tester) async {
      await _showShell(tester);
      expect(
        find.byKey(const ValueKey('discovery-search')).hitTestable(),
        findsOneWidget,
      );
      expect(find.byTooltip('扫一扫').hitTestable(), findsOneWidget);
      await tapAppTab(tester, 'membership');
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
        find.byKey(const ValueKey('discovery-search')).hitTestable(),
        findsNothing,
      );
      expect(find.byTooltip('扫一扫').hitTestable(), findsNothing);
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

  testWidgets('Queued back follows history and slides by tab position', (
    tester,
  ) async {
    await _showShell(tester);
    final shell = tester.state<AppShellState>(find.byType(AppShell));
    shell.select(AppShell.profileTab);
    await tester.pumpAndSettle();
    final width = tester.getSize(find.byType(ProfilePage)).width;

    // Messages sits left of profile in the bar, so it arrives from the left.
    shell.select(AppShell.messagesTab);
    await tester.pump();
    expect(_pageLeft(tester, MessagesPage), -width);
    await tester.pump(const Duration(milliseconds: 80));
    final beforeBack = _pageLeft(tester, MessagesPage);
    shell.goBack();
    await tester.pump();
    expect(_pageLeft(tester, MessagesPage), beforeBack);
    await tester.pump(appPageTransitionDuration);
    await tester.pump(const Duration(milliseconds: 80));
    final returning = _pageLeft(tester, ProfilePage);
    final exiting = _pageLeft(tester, MessagesPage);
    expect(returning, allOf(greaterThan(0), lessThan(width)));
    expect(returning - exiting, closeTo(width, 0.001));
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
      shell.select(AppShell.messagesTab);
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
      for (final pageType in [DiscoveryPage, MembershipPage, MessagesPage]) {
        expect(find.byType(pageType), findsNothing);
        final retained = find.byType(pageType, skipOffstage: false);
        expect(retained, findsOneWidget);
        expect(TickerMode.valuesOf(tester.element(retained)).enabled, isFalse);
      }
      expect(find.byTooltip('扫一扫').hitTestable(), findsNothing);
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
      await tapAppTab(tester, 'membership');
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
      await tester.enterText(search, '一页简历');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      final scroll = discoverySearchPosition(tester, '一页简历');
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
      expect(discoverySearchPosition(tester, '一页简历'), same(scroll));
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
    await tapAppTab(tester, 'membership');
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
      await tapAppTab(tester, 'membership');
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

      await tapAppTab(tester, 'membership');
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
