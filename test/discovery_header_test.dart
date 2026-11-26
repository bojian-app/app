import 'package:bojian_mobile/app_store.dart';
import 'package:bojian_mobile/app_update.dart';
import 'package:bojian_mobile/discovery.dart';
import 'package:bojian_mobile/design.dart';
import 'package:bojian_mobile/messages_page.dart';
import 'package:bojian_mobile/profile_avatar.dart';
import 'package:bojian_mobile/story_composer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';
import 'support/profile_navigation_helpers.dart';

Future<AppStore> storeWithScrollableFeed() {
  final api = FakeGateway(seeded: true);
  final example =
      (api.documents['GetFeed']!['items'] as List).first
          as Map<String, dynamic>;
  api.documents['GetFeed'] = {
    'items': [
      for (var id = 1; id <= 12; id++)
        {...example, 'id': id, 'title': '文章 $id'},
    ],
  };
  return testStore(authenticated: true, api: api);
}

void main() {
  testWidgets(
    'Avatar menu keeps all four shortcuts usable at large text sizes',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 720);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final store = await storeWithScrollableFeed();
      addTearDown(store.dispose);
      final opened = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: DiscoveryPage(
              store: store,
              onOpenProfile: () => opened.add('我的'),
              onOpenMembership: () => opened.add('会员中心'),
              onOpenService: () => opened.add('在线客服'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final profile = find.byKey(const ValueKey('discovery-profile'));
      final service = find.byKey(const ValueKey('discovery-service'));
      final myPage = find.byKey(const ValueKey('discovery-my-page'));
      final membership = find.byKey(const ValueKey('discovery-membership'));
      final scan = find.byKey(const ValueKey('discovery-scan'));
      final menuItems = [myPage, membership, service, scan];
      final profileRect = tester.getRect(profile);
      expect(find.text('发现'), findsNothing);
      expect(find.text('在线客服'), findsNothing);
      for (final item in menuItems) {
        expect(item, findsNothing);
      }

      final scroll = discoveryFeedPosition(tester);
      expect(scroll.maxScrollExtent, greaterThan(0));
      scroll.jumpTo(scroll.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(profile.hitTestable(), findsOneWidget);
      expect(tester.getRect(profile), profileRect);
      await tester.tap(profile);
      await tester.pumpAndSettle();
      expect(opened, isEmpty);
      var previousBottom = profileRect.bottom;
      for (final item in menuItems) {
        expect(item.hitTestable(), findsOneWidget);
        final rect = tester.getRect(item);
        expect(rect.top, greaterThanOrEqualTo(previousBottom));
        expect(rect.height, greaterThanOrEqualTo(44));
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(320));
        previousBottom = rect.bottom;
      }
      await tester.tapAt(const Offset(310, 680));
      await tester.pumpAndSettle();
      expect(scan.hitTestable(), findsNothing);
      expect(opened, isEmpty);

      await tapDiscoveryMenuItem(tester, 'discovery-service');
      await tester.pumpAndSettle();
      expect(opened, ['在线客服']);
      expect(service, findsNothing);

      await tester.tap(profile);
      await tester.pumpAndSettle();
      tester.semantics.tap(find.semantics.byLabel('成为会员'));
      await tester.pumpAndSettle();
      expect(opened, ['在线客服', '会员中心']);
      expect(membership.hitTestable(), findsNothing);
      await tester.tap(profile);
      await tester.pumpAndSettle();
      await tester.tap(myPage);
      await tester.pumpAndSettle();
      expect(opened, ['在线客服', '会员中心', '我的']);
      expect(scan.hitTestable(), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Publishing lives in the avatar menu at the far right', (
    tester,
  ) async {
    final store = await testStore(authenticated: true, seeded: true);
    addTearDown(store.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: Scaffold(
          body: DiscoveryPage(
            store: store,
            onOpenProfile: () {},
            onOpenMembership: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('discovery-create')), findsNothing);
    final profile = find.byKey(const ValueKey('discovery-profile'));
    final messages = find.byKey(const ValueKey('discovery-messages'));
    expect(
      tester.getRect(profile).left,
      greaterThanOrEqualTo(tester.getRect(messages).right),
    );
    await tester.tap(profile);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('discovery-add-resume')).hitTestable(),
      findsOneWidget,
    );
    // The entries to the profile and membership read as actions.
    expect(find.text('个人资料'), findsOneWidget);
    expect(find.text('成为会员'), findsOneWidget);
    expect(find.text('会员中心'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('discovery-create-story')));
    await tester.pumpAndSettle();
    expect(find.byType(StoryComposer), findsOneWidget);
  });

  testWidgets('The profile shortcut shows an available app update', (
    tester,
  ) async {
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
    final store = await testStore(authenticated: true, seeded: true);
    addTearDown(store.dispose);
    Widget home() => MaterialApp(
      theme: appTheme,
      home: Scaffold(
        body: DiscoveryPage(store: store, onOpenProfile: () {}),
      ),
    );
    await tester.pumpWidget(home());
    await tester.pumpAndSettle();
    final badge = find.descendant(
      of: find.byKey(const ValueKey('discovery-profile')),
      matching: find.byType(Badge),
    );
    expect(tester.widget<Badge>(badge).isLabelVisible, isTrue);
    updates.installedBuild = 2;
    await tester.pumpWidget(home());
    await tester.pumpAndSettle();
    expect(tester.widget<Badge>(badge).isLabelVisible, isFalse);
  });

  for (final width in [320.0, 390.0]) {
    testWidgets('Scrolled discovery keeps all header actions usable ($width)', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = await storeWithScrollableFeed();
      addTearDown(store.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: Scaffold(
            body: DiscoveryPage(store: store, onOpenService: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final messages = find.byKey(const ValueKey('discovery-messages'));
      final messagesState = tester.state(messages);
      final scroll = discoveryFeedPosition(tester);
      expect(scroll.maxScrollExtent, greaterThan(0));
      scroll.jumpTo(scroll.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(messages.hitTestable(), findsOneWidget);
      final profile = find.byKey(const ValueKey('discovery-profile'));
      expect(profile.hitTestable(), findsOneWidget);
      expect(find.byKey(const ValueKey('discovery-create')), findsNothing);
      expect(
        tester.getRect(profile).left,
        greaterThanOrEqualTo(tester.getRect(messages).right),
      );
      expect(tester.getRect(messages).top, greaterThanOrEqualTo(0));
      expect(tester.getRect(messages).right, lessThanOrEqualTo(width));
      expect(tester.state(messages), same(messagesState));
      final search = find.byKey(const ValueKey('discovery-search'));
      expect(search.hitTestable(), findsOneWidget);
      expect(
        tester.getRect(search).right,
        lessThanOrEqualTo(tester.getRect(messages).left),
      );
      await tester.tap(messages);
      await tester.pumpAndSettle();
      expect(find.byType(MessagesPage), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      final restored = discoveryFeedPosition(tester);
      expect(restored.pixels, greaterThan(0));
      restored.jumpTo(0);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('discovery-search')).hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  for (final config in [
    (size: const Size(320, 720), scale: 1.0, dark: false),
    (size: const Size(390, 720), scale: 1.3, dark: true),
    (size: const Size(320, 720), scale: 2.0, dark: false),
    (size: const Size(844, 360), scale: 2.0, dark: true),
  ]) {
    testWidgets('Avatar, search, messages and publish share one row: $config', (
      tester,
    ) async {
      tester.view.physicalSize = config.size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = await testStore(authenticated: true, seeded: true);
      await tester.pumpWidget(
        MaterialApp(
          theme: config.dark ? appDarkTheme : appTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(config.scale)),
            child: child!,
          ),
          home: Scaffold(
            body: DiscoveryPage(store: store, onOpenProfile: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final search = find.byKey(const ValueKey('discovery-search'));
      final messages = find.byKey(const ValueKey('discovery-messages'));
      final initialRect = tester.getRect(search);
      final gap = find.byKey(const ValueKey('discovery-feed-divider'));
      final gapRect = tester.getRect(gap);
      final firstRow = find.byType(FeedRow).first;
      expect(gapRect.size, Size(config.size.width, 6));
      expect(gapRect.left, 0);
      expect(gapRect.top, greaterThanOrEqualTo(initialRect.bottom));
      expect(gapRect.bottom, closeTo(tester.getRect(firstRow).top, 0.01));
      expect(
        tester.widget<Divider>(gap).color,
        tester.widget<FeedRow>(firstRow).gapColor,
      );
      final profile = find.byKey(const ValueKey('discovery-profile'));
      final avatar = find.descendant(
        of: profile,
        matching: find.byType(ProfileAvatar),
      );
      final pageInset =
          (config.size.width - 600).clamp(0.0, double.infinity) / 2;
      void expectAligned() {
        final searchRect = tester.getRect(search);
        final messagesRect = tester.getRect(messages);
        final profileRect = tester.getRect(profile);
        final avatarRect = tester.getRect(avatar);
        expect(profileRect.center.dy, closeTo(searchRect.center.dy, 0.01));
        expect(searchRect.right, lessThanOrEqualTo(messagesRect.left));
        expect(messagesRect.right, lessThanOrEqualTo(profileRect.left));
        expect(profileRect.size, const Size.square(48));
        expect(avatarRect.size, const Size.square(24));
        expect(avatarRect.center, profileRect.center);
        expect(tester.widget<ProfileAvatar>(avatar).borderRadius, 12);
        expect(messagesRect.width, greaterThanOrEqualTo(44));
        expect(messagesRect.height, greaterThanOrEqualTo(44));
        expect(searchRect.center.dy, closeTo(messagesRect.center.dy, 0.01));
        expect(searchRect.height, closeTo(initialRect.height, 0.01));
        expect(searchRect.left, pageInset + 24);
        expect(avatarRect.right, config.size.width - pageInset - 24);
        expect(profileRect.right, config.size.width - pageInset - 12);
        final editable = tester.getRect(
          find.descendant(of: search, matching: find.byType(EditableText)),
        );
        expect(editable.top, greaterThanOrEqualTo(searchRect.top));
        expect(editable.bottom, lessThanOrEqualTo(searchRect.bottom));
        expect(tester.takeException(), isNull);
      }

      expect(find.byType(TabBar), findsNothing);
      expect(find.byType(TabBarView), findsNothing);
      expectAligned();
      await tester.enterText(search, '很长的搜索关键词，用于检查输入和清空时保持对齐');
      await tester.pumpAndSettle();
      expectAligned();
      await tester.tap(find.byTooltip('清空搜索'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(search).controller!.text, isEmpty);
      expect(tester.widget<TextField>(search).focusNode!.hasFocus, isTrue);
      expectAligned();
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    });
  }

  testWidgets('Discovery searches all story categories in a single feed', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = await testStore(authenticated: true, seeded: true);
    store.stories.add(
      Story(
        id: 2,
        title: '简历讨论',
        author: '阿明',
        role: '',
        category: '简历分享',
        excerpt: '经历怎么写',
        paragraphs: [],
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: Scaffold(body: DiscoveryPage(store: store)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(TabBar), findsNothing);
    expect(find.byType(TabBarView), findsNothing);
    final original = store.stories.first;
    expect(find.text(original.title), findsOneWidget);
    expect(find.text('简历讨论'), findsOneWidget);
    expect(find.text('开始创作'), findsNothing);
    expect(find.byKey(const ValueKey('discovery-create')), findsNothing);
    expect(find.text('发布新动态'), findsNothing);
    final search = find.byKey(const ValueKey('discovery-search'));
    await tester.tap(search);
    await tester.enterText(search, '不存在的关键词');
    await tester.pumpAndSettle();
    expect(find.byType(StorySearch), findsNothing);
    expect(find.byType(DiscoveryPage), findsOneWidget);
    expect(find.text('没有找到相关内容'), findsOneWidget);
    await tester.tap(find.byTooltip('清空搜索'));
    await tester.pumpAndSettle();
    final editable = tester.widget<EditableText>(
      find.descendant(of: search, matching: find.byType(EditableText)),
    );
    expect(editable.focusNode.hasFocus, true);
    editable.focusNode.unfocus();
    await tester.pumpAndSettle();
    await tester.enterText(search, '阿明');
    await tester.pumpAndSettle();
    expect(find.text('简历讨论'), findsOneWidget);
    expect(find.text(original.title), findsNothing);
    await tester.tap(find.byTooltip('清空搜索'));
    await tester.pumpAndSettle();
    expect(find.text(original.title), findsOneWidget);
    expect(find.text('简历讨论'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    store.dispose();
  });
}
