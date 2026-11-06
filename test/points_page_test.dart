import 'package:bojian_mobile/design.dart';
import 'package:bojian_mobile/points_page.dart';
import 'package:bojian_mobile/resume_pages.dart';
import 'package:bojian_mobile/story_composer.dart';
import 'package:bojian_mobile/resume_user_share.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

const _schedule = [50, 75, 100, 125, 150, 200, 300];

/// A newcomer reward on [today] (zero-based) with the given day statuses.
Map<String, dynamic> newcomer(
  List<String> statuses, {
  int today = 3,
  bool claimable = true,
  String status = 'ACTIVE',
}) => {
  'points': _schedule[today],
  'claimable': claimable,
  'status': status,
  'day': today + 1,
  'days': [
    for (var i = 0; i < 7; i++)
      {'day': i + 1, 'points': _schedule[i], 'status': statuses[i]},
  ],
};

const _active = [
  'CLAIMED',
  'MISSED',
  'CLAIMED',
  'AVAILABLE',
  'LOCKED',
  'LOCKED',
  'LOCKED',
];

Widget host(Widget page, {ThemeData? theme}) =>
    MaterialApp(theme: theme ?? appTheme, home: page);

void main() {
  testWidgets('Points loads wallet, retries errors and fits enlarged text', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final api = FakeGateway();
    api.documents['GetWalletDailyReward'] = newcomer(_active);
    final store = await testStore(authenticated: true, api: api);
    addTearDown(store.dispose);
    api.failing = 'GetWallet';
    await tester.pumpWidget(
      MaterialApp(
        theme: appDarkTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
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
    expect(find.bySemanticsLabel('可用积分 123'), findsOneWidget);
    expect(find.text('立即签到 +125'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Newcomer tiles show claimed, missed, today and tomorrow', (
    tester,
  ) async {
    final api = FakeGateway();
    api.documents['GetWalletDailyReward'] = newcomer(_active);
    final store = await testStore(authenticated: true, api: api);
    addTearDown(store.dispose);
    await tester.pumpWidget(host(PointsPage(store: store)));
    await tester.pumpAndSettle();
    expect(find.text('新人 7 天礼'), findsOneWidget);
    expect(find.text('已签 2/7 天'), findsOneWidget);
    expect(find.text('已签'), findsNWidgets(2));
    expect(find.text('漏签'), findsOneWidget);
    expect(find.text('今天'), findsOneWidget);
    expect(find.text('明天'), findsOneWidget);
    expect(find.text('大礼'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Check in confirms once, rolls the balance after the coins land and '
    'opens the real market',
    (tester) async {
      final api = FakeGateway();
      api.documents['GetWalletDailyReward'] = newcomer(_active);
      api.documents['PostWalletDailyRewardClaims'] = {
        'id': 1,
        'points': 125,
        'wallet': {'available_points': 125},
        'reward': newcomer([
          'CLAIMED',
          'MISSED',
          'CLAIMED',
          'CLAIMED',
          'LOCKED',
          'LOCKED',
          'LOCKED',
        ], claimable: false),
      };
      final store = await testStore(authenticated: true, api: api);
      addTearDown(store.dispose);
      await tester.pumpWidget(host(PointsPage(store: store)));
      await tester.pumpAndSettle();
      final button = find.byKey(const ValueKey('profile-claim-reward'));
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      // Coins are still in flight: the balance has not moved yet.
      expect(store.points, 125);
      expect(find.bySemanticsLabel('可用积分 0'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('可用积分 125'), findsOneWidget);
      expect(find.text('今日已签到'), findsOneWidget);
      expect(find.text('已签 3/7 天'), findsOneWidget);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(
        api.calls.where((c) => c == 'PostWalletDailyRewardClaims'),
        hasLength(1),
      );
      final market = find.byKey(const ValueKey('points-market'));
      await tester.ensureVisible(market);
      await tester.tap(market);
      await tester.pumpAndSettle();
      expect(find.byType(TemplateMarket), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Reduced motion credits immediately without flying coins', (
    tester,
  ) async {
    final api = FakeGateway();
    api.documents['GetWalletDailyReward'] = newcomer(_active);
    api.documents['PostWalletDailyRewardClaims'] = {
      'id': 1,
      'points': 125,
      'wallet': {'available_points': 125},
    };
    final store = await testStore(authenticated: true, api: api);
    addTearDown(store.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: PointsPage(store: store),
      ),
    );
    await tester.pumpAndSettle();
    final button = find.byKey(const ValueKey('profile-claim-reward'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();
    await tester.pump();
    expect(find.bySemanticsLabel('可用积分 125'), findsOneWidget);
    expect(find.text('+125 积分已到账'), findsOneWidget);
  });

  testWidgets(
    'Reward tasks open their actions; rewardless and unconfigured tasks are hidden',
    (tester) async {
      final store = await testStore(authenticated: true, seeded: true);
      addTearDown(store.dispose);
      await tester.pumpWidget(host(PointsPage(store: store)));
      await tester.pumpAndSettle();
      for (final label in ['发一篇求职经验', '请大家帮你改简历', '帮别人改简历', '邀请好友']) {
        expect(find.textContaining(label), findsOneWidget);
      }
      for (final label in ['创建一份简历', '看一段视频', '待开放', '赚积分', '兑好礼']) {
        expect(find.textContaining(label), findsNothing);
      }
      final todo = find.widgetWithText(TextButton, '去完成');
      expect(todo, findsNWidgets(3));
      await tester.ensureVisible(todo.at(0));
      await tester.tap(todo.at(0));
      await tester.pumpAndSettle();
      expect(find.byType(StoryComposer), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.ensureVisible(todo.at(1));
      await tester.tap(todo.at(1));
      await tester.pumpAndSettle();
      expect(find.text('选择需要优化的简历'), findsOneWidget);
      await tester.tap(find.text('产品经理 · 社招简历'));
      await tester.pumpAndSettle();
      expect(find.byType(ResumeUserShare), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Ended newcomer reward hides the check-in card', (tester) async {
    final api = FakeGateway();
    api.documents['GetWalletDailyReward'] = newcomer(
      ['CLAIMED', ...List.filled(6, 'MISSED')],
      today: 0,
      claimable: false,
      status: 'EXPIRED',
    );
    final store = await testStore(authenticated: true, api: api);
    addTearDown(store.dispose);
    await tester.pumpWidget(host(PointsPage(store: store)));
    await tester.pumpAndSettle();
    expect(find.text('新人 7 天礼'), findsNothing);
    expect(find.byKey(const ValueKey('profile-claim-reward')), findsNothing);
    expect(find.textContaining('每日任务'), findsOneWidget);
    expect(api.calls, isNot(contains('PostWalletDailyRewardClaims')));
  });

  testWidgets('Completed daily task claims only through the server', (
    tester,
  ) async {
    final api = FakeGateway();
    api.documents['GetWalletTasks'] = {
      'items': [
        {'task': 'PUBLISH_ARTICLE', 'claimable': true, 'claimed': false},
      ],
    };
    api.documents['PostWalletTasksTaskClaims'] = {
      'id': 1,
      'points': 100,
      'deduplicated': false,
    };
    final store = await testStore(authenticated: true, api: api);
    addTearDown(store.dispose);
    await tester.pumpWidget(host(PointsPage(store: store)));
    await tester.pumpAndSettle();
    expect(api.calls, isNot(contains('PostWalletTasksTaskClaims')));
    expect(find.text('已完成 0/3'), findsOneWidget);
    await tester.ensureVisible(find.text('点击领取'));
    api.documents['GetWalletTasks'] = {
      'items': [
        {'task': 'PUBLISH_ARTICLE', 'claimable': false, 'claimed': true},
      ],
    };
    await tester.tap(find.text('点击领取'));
    await tester.pumpAndSettle();
    expect(api.calls.where((v) => v == 'PostWalletTasksTaskClaims').length, 1);
    expect(find.text('已领取'), findsOneWidget);
    expect(find.text('已完成 1/3'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Ledger and rules open as sheets', (tester) async {
    final api = FakeGateway();
    api.documents['GetWalletTransactions'] = {
      'items': [
        {
          'direction': 'IN',
          'amount_points': 125,
          'description': '新人奖励',
          'created_at': '2026-11-06T01:00:00Z',
        },
        {
          'direction': 'OUT',
          'amount_points': 500,
          'description': '兑换模版',
          'created_at': '2026-11-04T01:00:00Z',
        },
      ],
    };
    final store = await testStore(authenticated: true, api: api);
    addTearDown(store.dispose);
    await tester.pumpWidget(host(PointsPage(store: store)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('points-ledger')));
    await tester.pumpAndSettle();
    expect(find.text('积分明细'), findsOneWidget);
    expect(find.text('新人奖励'), findsOneWidget);
    expect(find.text('+125'), findsOneWidget);
    expect(find.text('-500'), findsOneWidget);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    await tester.tap(find.text('规则'));
    await tester.pumpAndSettle();
    expect(find.text('积分规则'), findsOneWidget);
    expect(find.textContaining('积分不能提现或转让'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Guests see login instead of wallet actions', (tester) async {
    final store = await testStore();
    addTearDown(store.dispose);
    await tester.pumpWidget(host(PointsPage(store: store)));
    await tester.pumpAndSettle();
    expect(find.text('登录 / 注册'), findsOneWidget);
    expect(find.byKey(const ValueKey('profile-claim-reward')), findsNothing);
    expect(find.byKey(const ValueKey('points-ledger')), findsNothing);
  });
}
