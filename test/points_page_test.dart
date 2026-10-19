import 'package:bojian_mobile/design.dart';
import 'package:bojian_mobile/points_page.dart';
import 'package:bojian_mobile/resume_pages.dart';
import 'package:bojian_mobile/story_composer.dart';
import 'package:bojian_mobile/resume_guidance_share.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

void main() {
  testWidgets('Points loads wallet, retries errors and fits enlarged text', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final api = FakeGateway();
    final store = await testStore(authenticated: true, api: api);
    addTearDown(store.dispose);
    api.failing = 'GetWallet';
    await tester.pumpWidget(
      MaterialApp(
        theme: appDarkTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: PointsPage(store: store),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('服务器暂不可用'), findsOneWidget);
    api.failing = null;
    api.documents['GetWallet'] = {'available_points': 123};
    await tester.ensureVisible(find.text('重新加载'));
    await tester.tap(find.text('重新加载'));
    await tester.pumpAndSettle();
    expect(find.text('服务器暂不可用'), findsNothing);
    expect(store.points, 123);
    expect(find.text('每日奖励 +10 积分'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Check in confirms once and redemption opens the real market', (
    tester,
  ) async {
    final api = FakeGateway();
    api.documents['PostWalletDailyRewardClaims'] = {
      'id': 1,
      'points': 37,
      'wallet': {'available_points': 37},
    };
    final store = await testStore(authenticated: true, api: api);
    addTearDown(store.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: PointsPage(store: store),
      ),
    );
    await tester.pumpAndSettle();
    final button = find.byKey(const ValueKey('profile-claim-reward'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(store.points, 37);
    expect(store.rewardPoints, 37);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('check-in-received-amount')),
        matching: find.text('+37'),
      ),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.text('今天已签到'), findsOneWidget);
    await tester.tap(button);
    expect(
      api.calls.where((c) => c == 'PostWalletDailyRewardClaims'),
      hasLength(1),
    );
    await tester.ensureVisible(find.byKey(const ValueKey('points-tab-1')));
    await tester.tap(find.byKey(const ValueKey('points-tab-1')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('逛逛模版市场'));
    await tester.tap(find.text('逛逛模版市场'));
    await tester.pumpAndSettle();
    expect(find.byType(TemplateMarket), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Task groups expose the three one-time actions and two daily tasks',
    (tester) async {
      final store = await testStore(authenticated: true, seeded: true);
      addTearDown(store.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: PointsPage(store: store),
        ),
      );
      await tester.pumpAndSettle();
      for (final label in ['邀请新人', '创建一份简历', '发布一篇文章', '请求别人优化简历', '观看广告']) {
        expect(find.text(label), findsOneWidget);
      }
      for (final label in ['打卡', '长期任务', '仅限一次', '每项任务仅可完成一次']) {
        expect(find.text(label), findsNothing);
      }
      expect(find.text('每日任务'), findsNothing);
      expect(find.text('每天都可以参与'), findsNothing);
      expect(find.text('打卡瓜分积分'), findsNothing);
      expect(find.text('发现心仪模版'), findsNothing);
      final pendingTasks = find.widgetWithText(TextButton, '待开放');
      expect(pendingTasks, findsNWidgets(2));
      for (final button in tester.widgetList<TextButton>(pendingTasks)) {
        expect(button.onPressed, isNull);
      }
      await tester.ensureVisible(find.text('去创建'));
      await tester.tap(find.text('去创建'));
      await tester.pumpAndSettle();
      expect(find.byType(ResumeEditor), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('去发布'));
      await tester.tap(find.text('去发布'));
      await tester.pumpAndSettle();
      expect(find.byType(StoryComposer), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('去请求'));
      await tester.tap(find.text('去请求'));
      await tester.pumpAndSettle();
      expect(find.text('选择需要优化的简历'), findsOneWidget);
      await tester.tap(find.text('产品经理 · 社招简历'));
      await tester.pumpAndSettle();
      expect(find.byType(ResumeGuidanceShare), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Guests see login instead of wallet actions', (tester) async {
    final store = await testStore();
    addTearDown(store.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: PointsPage(store: store),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('登录 / 注册'), findsOneWidget);
    expect(find.byKey(const ValueKey('profile-claim-reward')), findsNothing);
  });
}
