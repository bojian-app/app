import 'package:bojian_mobile/app_icons.dart';
import 'package:bojian_mobile/app_store.dart';
import 'package:bojian_mobile/discovery.dart';
import 'package:bojian_mobile/discovery_banner.dart';
import 'package:bojian_mobile/feed_search.dart';
import 'package:bojian_mobile/design.dart';
import 'package:bojian_mobile/messages_button.dart';
import 'package:bojian_mobile/profile_avatar.dart';
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
  testWidgets('Scanning replaces the avatar menu at the far right', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 720);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final store = await storeWithScrollableFeed();
    addTearDown(store.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(body: DiscoveryPage(store: store)),
      ),
    );
    await tester.pumpAndSettle();
    final header = find.byKey(const ValueKey('discovery-search-row'));
    // The page is named at the left of the search, on the same line.
    final title = tester.getRect(find.text('首页'));
    final field = tester.getRect(
      find.byKey(const ValueKey('discovery-search')),
    );
    expect(title.left, 24);
    expect(field.left, title.right + 12);
    expect(title.center.dy, closeTo(field.center.dy, 1));
    expect(
      find.descendant(of: header, matching: find.byType(ProfileAvatar)),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('discovery-profile')), findsNothing);
    expect(find.byType(PopupMenuButton<VoidCallback>), findsNothing);
    final scan = find.byKey(const ValueKey('discovery-scan'));
    // Messages moved to the tab bar; scanning is the only header button.
    expect(find.byType(MessagesButton), findsNothing);
    expect(
      find.descendant(of: header, matching: find.byType(IconButton)),
      findsOneWidget,
    );
    expect(find.byTooltip('扫一扫'), findsOneWidget);
    final scanRect = tester.getRect(scan);
    final search = find.byKey(const ValueKey('discovery-search'));
    expect(scanRect.left, greaterThanOrEqualTo(tester.getRect(search).right));
    final scroll = discoveryFeedPosition(tester);
    expect(scroll.maxScrollExtent, greaterThan(0));
    scroll.jumpTo(scroll.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(scan.hitTestable(), findsOneWidget);
    expect(tester.getRect(scan), scanRect);
    expect(tester.takeException(), isNull);
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
          home: Scaffold(body: DiscoveryPage(store: store)),
        ),
      );
      await tester.pumpAndSettle();
      final scroll = discoveryFeedPosition(tester);
      expect(scroll.maxScrollExtent, greaterThan(0));
      scroll.jumpTo(scroll.maxScrollExtent);
      await tester.pumpAndSettle();
      final scan = find.byKey(const ValueKey('discovery-scan'));
      expect(scan.hitTestable(), findsOneWidget);
      expect(find.byKey(const ValueKey('discovery-create')), findsNothing);
      expect(tester.getRect(scan).top, greaterThanOrEqualTo(0));
      expect(tester.getRect(scan).right, lessThanOrEqualTo(width));
      final search = find.byKey(const ValueKey('discovery-search'));
      expect(search.hitTestable(), findsOneWidget);
      expect(
        tester.getRect(search).right,
        lessThanOrEqualTo(tester.getRect(scan).left),
      );
      scroll.jumpTo(0);
      await tester.pumpAndSettle();
      expect(search.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final config in [
    (size: const Size(320, 720), scale: 1.0, dark: false),
    (size: const Size(390, 720), scale: 1.3, dark: true),
    (size: const Size(320, 720), scale: 2.0, dark: false),
    (size: const Size(844, 360), scale: 2.0, dark: true),
  ]) {
    testWidgets('Search and scan share one row: $config', (tester) async {
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
          home: Scaffold(body: DiscoveryPage(store: store)),
        ),
      );
      await tester.pumpAndSettle();
      final search = find.byKey(const ValueKey('discovery-search'));
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
      final scan = find.byKey(const ValueKey('discovery-scan'));
      final icon = find.descendant(of: scan, matching: find.byType(AppIcon));
      final pageInset =
          (config.size.width - 600).clamp(0.0, double.infinity) / 2;
      void expectAligned() {
        final searchRect = tester.getRect(search);
        final scanRect = tester.getRect(scan);
        final iconRect = tester.getRect(icon);
        expect(scanRect.center.dy, closeTo(searchRect.center.dy, 0.01));
        expect(searchRect.right, lessThanOrEqualTo(scanRect.left));
        expect(scanRect.size, const Size.square(44));
        expect(iconRect.size, const Size.square(20));
        expect(iconRect.center, scanRect.center);
        expect(searchRect.height, closeTo(initialRect.height, 0.01));
        final titleRect = tester.getRect(find.text('首页'));
        expect(titleRect.left, pageInset + 24);
        expect(searchRect.left, closeTo(titleRect.right + 12, 0.01));
        expect(titleRect.center.dy, closeTo(searchRect.center.dy, 1));
        expect(iconRect.right, config.size.width - pageInset - 24);
        expect(scanRect.right, config.size.width - pageInset - 12);
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
    final api = FakeGateway(seeded: true);
    (api.documents['GetFeed']!['items'] as List).add({
      'id': 2,
      'title': '简历讨论',
      'author': {'id': 3, 'display_name': '阿明'},
      'content': richContent('经历怎么写'),
    });
    final store = await testStore(authenticated: true, api: api);
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
    await tester.pump(FeedSearch.pause);
    await tester.pumpAndSettle();
    expect(find.byType(StorySearch), findsNothing);
    expect(find.byType(DiscoveryPage), findsOneWidget);
    expect(find.text('没有找到相关内容'), findsOneWidget);
    // The banner steps aside, and the result stays put when the keyboard
    // rises, with both of its lines above it.
    expect(find.byType(DiscoveryBanner, skipOffstage: false), findsNothing);
    final resting = tester.getRect(find.byType(EmptyState));
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byType(EmptyState)), resting);
    expect(
      tester.getBottomLeft(find.text('试试其他关键词。')).dy,
      lessThanOrEqualTo(720 - 300),
    );
    tester.view.resetViewInsets();
    await tester.tap(find.byTooltip('清空搜索'));
    await tester.pumpAndSettle();
    expect(find.byType(DiscoveryBanner, skipOffstage: false), findsOneWidget);
    final editable = tester.widget<EditableText>(
      find.descendant(of: search, matching: find.byType(EditableText)),
    );
    expect(editable.focusNode.hasFocus, true);
    editable.focusNode.unfocus();
    await tester.pumpAndSettle();
    await tester.enterText(search, '阿明');
    await tester.pump(FeedSearch.pause);
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
