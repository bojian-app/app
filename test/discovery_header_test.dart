import 'package:bojian_mobile/app_store.dart';
import 'package:bojian_mobile/discovery.dart';
import 'package:bojian_mobile/design.dart';
import 'package:bojian_mobile/profile_identity.dart';
import 'package:bojian_mobile/messages_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

void main() {
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
        final create = find.byKey(const ValueKey('discovery-create'));
        final initialRect = tester.getRect(search);
        expect(tester.getSize(create), const Size.square(44));
        expect(
          tester.getRect(create).right,
          lessThanOrEqualTo(tester.getRect(messages).left),
        );
        expect(
          initialRect.right,
          lessThanOrEqualTo(tester.getRect(create).left),
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
    'Search stays in discovery; tabs respond to swipes and taps; header keeps the compact publish shortcut',
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
      expect(find.byKey(const ValueKey('discovery-create')), findsOneWidget);
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
  testWidgets(
    'Compact publish opens one editor and returns with search/category intact',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final api = FakeGateway(seeded: true);
      final store = await testStore(authenticated: true, api: api);
      addTearDown(store.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          builder: (context, child) =>
              TooltipVisibility(visible: false, child: child!),
          home: Scaffold(body: DiscoveryPage(store: store)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('发布动态'), findsOneWidget);
      final search = find.byKey(const ValueKey('discovery-search'));
      await tester.enterText(search, '保留关键词');
      await tester.pumpAndSettle();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.tap(find.text('经验分享'));
      await tester.pumpAndSettle();
      final action = tester
          .widget<IconButton>(find.byKey(const ValueKey('discovery-create')))
          .onPressed!;
      action();
      action();
      await tester.pumpAndSettle();
      expect(find.byType(StoryComposer), findsOneWidget);
      await tester.tap(
        find.byWidgetPredicate(
          (widget) => widget is IconButton && widget.tooltip == '关闭',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(StoryComposer), findsNothing);
      expect(tester.widget<TextField>(search).controller!.text, '保留关键词');
      expect(
        DefaultTabController.of(tester.element(find.byType(TabBar))).index,
        2,
      );
      expect(
        find.byKey(const ValueKey('discovery-create')).hitTestable(),
        findsOneWidget,
      );
      expect(api.calls, isNot(contains('PostArticles')));
      expect(api.calls, isNot(contains('PostArticlesIdPublish')));
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );
}
