import 'package:bojian_mobile/app_store.dart';
import 'package:bojian_mobile/discovery.dart';
import 'package:bojian_mobile/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

void main() {
  testWidgets(
    'Search stays in discovery; tabs respond to swipes and taps; creation is an icon',
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
      await tester.tap(find.byKey(const ValueKey('discovery-create')));
      await tester.pumpAndSettle();
      expect(find.byType(StoryComposer), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    },
  );
}
