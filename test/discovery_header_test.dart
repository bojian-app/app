import 'package:bojian_mobile/app_store.dart';
import 'package:bojian_mobile/discovery.dart';
import 'package:bojian_mobile/design.dart';
import 'package:bojian_mobile/profile_identity.dart';
import 'package:bojian_mobile/messages_button.dart';
import 'package:bojian_mobile/messages_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

void main() {
  for (final width in [320.0, 390.0]) {
    testWidgets('Collapsed discovery keeps menu and messages usable ($width)', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = await testStore(authenticated: true, seeded: true);
      addTearDown(store.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: Scaffold(body: DiscoveryPage(store: store)),
        ),
      );
      await tester.pumpAndSettle();
      final menu = find.byKey(const ValueKey('discovery-menu'));
      final messages = find.byKey(const ValueKey('discovery-messages'));
      final messagesState = tester.state(messages);
      final scroll = tester
          .state<NestedScrollViewState>(find.byType(NestedScrollView))
          .outerController;
      scroll.jumpTo(scroll.position.maxScrollExtent);
      await tester.pumpAndSettle();
      for (final button in [menu, messages]) {
        expect(button.hitTestable(), findsOneWidget);
        expect(tester.getRect(button).top, greaterThanOrEqualTo(0));
        expect(tester.getRect(button).right, lessThanOrEqualTo(width));
      }
      expect(tester.state(messages), same(messagesState));
      final tabs = tester.getRect(find.byKey(const ValueKey('discovery-tabs')));
      expect(tabs.left, greaterThanOrEqualTo(tester.getRect(menu).right));
      expect(tabs.right, lessThanOrEqualTo(tester.getRect(messages).left));
      expect(
        find.byKey(const ValueKey('discovery-search')).hitTestable(),
        findsNothing,
      );
      await tester.tap(menu);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('profile-drawer')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('profile-menu-close')));
      await tester.pumpAndSettle();
      await tester.tap(messages);
      await tester.pumpAndSettle();
      expect(find.byType(MessagesPage), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      final experience = find.text('经验分享');
      await tester.ensureVisible(experience);
      await tester.pumpAndSettle();
      await tester.tap(experience);
      await tester.pumpAndSettle();
      expect(
        DefaultTabController.of(tester.element(find.byType(TabBar))).index,
        2,
      );
      scroll.jumpTo(0);
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
    testWidgets(
      'Discovery search and messages stay compact and aligned: $config',
      (tester) async {
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
        final messages = find.byKey(const ValueKey('discovery-messages'));
        final initialRect = tester.getRect(search);
        expect(
          initialRect.right,
          lessThanOrEqualTo(tester.getRect(messages).left),
        );
        void expectAligned() {
          final searchRect = tester.getRect(search);
          final messagesRect = tester.getRect(messages);
          expect(messagesRect.size, const Size.square(44));
          expect(searchRect.center.dy, closeTo(messagesRect.center.dy, 0.01));
          expect(searchRect.height, closeTo(initialRect.height, 0.01));
          expect(searchRect.left, greaterThanOrEqualTo(0));
          expect(messagesRect.right, lessThanOrEqualTo(config.size.width));
          final editable = tester.getRect(
            find.descendant(of: search, matching: find.byType(EditableText)),
          );
          expect(editable.top, greaterThanOrEqualTo(searchRect.top));
          expect(editable.bottom, lessThanOrEqualTo(searchRect.bottom));
          expect(tester.takeException(), isNull);
        }

        if (config.scale == 1) {
          expect(initialRect.height, 32);
          expect(
            tester
                .getSize(find.byKey(const ValueKey('discovery-search-row')))
                .height,
            44,
          );
        }
        final tabs = find.byType(ProfileContentTabs);
        expect(tester.getSize(tabs).height, 38);
        expect(tester.widget<TextField>(search).style!.fontSize, 13);
        expect(tester.widget<MessagesButton>(messages).iconSize, 20);
        expect(
          tester.widget<TabBar>(find.byType(TabBar)).labelStyle!.fontSize,
          13,
        );
        expect(tester.widget<TabBar>(find.byType(TabBar)).indicatorWeight, 2);
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
      },
    );
  }

  testWidgets(
    'Search stays in discovery; tabs respond to swipes and taps; header omits the publish shortcut',
    (tester) async {
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
          category: '简历求指点',
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
      expect(find.text('发现'), findsNothing);
      expect(find.text('开始创作'), findsNothing);
      expect(find.byKey(const ValueKey('discovery-create')), findsNothing);
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
      TabController controller() =>
          DefaultTabController.of(tester.element(find.byType(TabBar)));
      await tester.drag(find.byType(TabBarView), const Offset(-280, 0));
      await tester.pumpAndSettle();
      expect(controller().index, 1);
      expect(find.text('简历讨论'), findsOneWidget);
      await tester.drag(find.byType(TabBarView), const Offset(-280, 0));
      await tester.pumpAndSettle();
      expect(controller().index, 2);
      await tester.drag(find.byType(TabBarView), const Offset(280, 0));
      await tester.pumpAndSettle();
      expect(controller().index, 1);
      await tester.tap(find.text('推荐'));
      await tester.pumpAndSettle();
      expect(controller().index, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    },
  );
}
