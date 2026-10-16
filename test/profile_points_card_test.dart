import 'dart:async';

import 'package:bojian_mobile/api/bojian_api.dart';
import 'package:bojian_mobile/account_pages.dart';
import 'package:bojian_mobile/design.dart';
import 'package:bojian_mobile/profile_points_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

class RewardGateway extends FakeGateway {
  final response = Completer<ApiDocument>();
  Completer<ApiDocument>? profileResponse;
  bool fail = false;
  @override
  Future<ApiDocument> call(
    String method, {
    Map<String, String> path = const {},
    Map<String, String> query = const {},
    Map<String, dynamic>? body,
    Map<String, String> headers = const {},
  }) async {
    if (method == 'GetMe' && profileResponse != null) {
      calls.add(method);
      return profileResponse!.future;
    }
    if (method == 'PostWalletDailyRewardClaims') {
      calls.add(method);
      if (fail) throw const ApiFailure('领取失败');
      final result = await response.future;
      documents['GetWallet'] = {'available_points': 137};
      documents['GetWalletDailyReward'] = {'points': 37, 'claimable': false};
      return result;
    }
    return super.call(
      method,
      path: path,
      query: query,
      body: body,
      headers: headers,
    );
  }
}

void main() {
  testWidgets(
    'Reward animates only after confirmation and prevents repeated claims',
    (tester) async {
      final api = RewardGateway();
      final store = await testStore(authenticated: true, api: api);
      addTearDown(store.dispose);
      store.points = 100;
      store.rewardPoints = 37;
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: Scaffold(body: ProfilePointsCard(store: store)),
        ),
      );
      expect(find.text('每日奖励 +37 积分'), findsOneWidget);
      final button = find.byKey(const ValueKey('profile-claim-reward'));
      await tester.tap(button);
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('领取中…'), findsOneWidget);
      expect(find.text('+37 积分已到账'), findsNothing);
      await tester.tap(button);
      expect(
        api.calls.where((v) => v == 'PostWalletDailyRewardClaims'),
        hasLength(1),
      );
      api.response.complete(
        ApiDocument({
          'id': 12,
          'points': 37,
          'wallet': {'available_points': 137},
        }),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('+37 积分已到账'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text('137'), findsOneWidget);
      expect(find.text('今日已领取'), findsOneWidget);
      expect(store.rewardClaimed, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Failure leaves balance unchanged and allows retry', (
    tester,
  ) async {
    final api = RewardGateway()..fail = true;
    final store = await testStore(authenticated: true, api: api);
    addTearDown(store.dispose);
    store.points = 100;
    store.rewardPoints = 37;
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: Scaffold(body: ProfilePointsCard(store: store)),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('profile-claim-reward')));
    await tester.pumpAndSettle();
    expect(find.text('领取失败'), findsOneWidget);
    expect(find.text('100'), findsOneWidget);
    expect(store.rewardClaimed, isFalse);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('profile-claim-reward')),
          )
          .onPressed,
      isNotNull,
    );
    expect(find.text('+37 积分已到账'), findsNothing);
    api.fail = false;
    api.response.complete(
      ApiDocument({
        'id': 12,
        'points': 37,
        'wallet': {'available_points': 137},
      }),
    );
    await tester.tap(find.byKey(const ValueKey('profile-claim-reward')));
    await tester.pumpAndSettle();
    expect(store.rewardClaimed, isTrue);
    expect(find.text('137'), findsOneWidget);
    expect(
      api.calls.where((method) => method == 'PostWalletDailyRewardClaims'),
      hasLength(2),
    );
  });

  for (final textScale in [1.0, 1.5]) {
    testWidgets(
      'Claim and profile refresh keep the page still at text scale $textScale',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(360, 540);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        final api = RewardGateway();
        final store = await testStore(authenticated: true, api: api);
        addTearDown(store.dispose);
        store.points = 100;
        store.rewardPoints = 37;
        await tester.pumpWidget(
          MaterialApp(
            theme: appTheme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!,
            ),
            home: Scaffold(body: ProfilePage(store: store)),
          ),
        );
        await tester.drag(find.byType(ListView), const Offset(0, -40));
        await tester.pumpAndSettle();
        final scroll = tester.state<ScrollableState>(find.byType(Scrollable));
        final scrollOffset = scroll.position.pixels;
        expect(scrollOffset, greaterThan(0));
        final card = find.byKey(const ValueKey('profile-points-card'));
        final button = find.byKey(const ValueKey('profile-claim-reward'));
        final status = find.byKey(const ValueKey('profile-reward-status'));
        final signOut = find.byKey(const ValueKey('account-sign-out'));
        final cardRect = tester.getRect(card);
        final buttonRect = tester.getRect(button);
        final statusTop = tester.getTopLeft(status).dy;

        void expectStableLayout() {
          expect(tester.getRect(card), cardRect);
          expect(tester.getRect(button), buttonRect);
          expect(tester.getTopLeft(status).dy, statusTop);
          expect(scroll.position.pixels, scrollOffset);
          expect(tester.takeException(), isNull);
        }

        await tester.tap(button);
        for (final elapsed in [120, 300, 650]) {
          await tester.pump(Duration(milliseconds: elapsed));
          expect(find.text('领取中…'), findsOneWidget);
          expect(find.text('100'), findsOneWidget);
          expectStableLayout();
        }
        api.response.complete(
          ApiDocument({
            'id': 12,
            'points': 37,
            'wallet': {'available_points': 137},
          }),
        );
        await tester.pump();
        for (final elapsed in [120, 300, 650]) {
          await tester.pump(Duration(milliseconds: elapsed));
          expect(find.text('今日已领取'), findsOneWidget);
          expectStableLayout();
        }
        await tester.pumpAndSettle();
        expect(find.text('137'), findsOneWidget);
        expectStableLayout();

        // Wallet events can refresh the profile independently of claiming.
        // Refresh stays silent without moving the sign-out button or changing
        // this scrolled page's extent.
        await tester.scrollUntilVisible(signOut, 80);
        await tester.pumpAndSettle();
        final signOutRect = tester.getRect(signOut);
        final bottomOffset = scroll.position.pixels;
        api.profileResponse = Completer<ApiDocument>();
        final refreshing = store.load('profile');
        await tester.pump();
        expect(find.byType(LinearProgressIndicator), findsNothing);
        expect(tester.getRect(signOut), signOutRect);
        expect(scroll.position.pixels, bottomOffset);
        api.profileResponse!.complete(ApiDocument(api.documents['GetMe']!));
        await refreshing;
        await tester.pumpAndSettle();
        expect(find.byType(LinearProgressIndicator), findsNothing);
        expect(tester.getRect(signOut), signOutRect);
        expect(scroll.position.pixels, bottomOffset);
        expect(tester.takeException(), isNull);
      },
    );
  }

  test('Deduplicated reward reports no newly earned points', () async {
    final api = RewardGateway();
    final store = await testStore(authenticated: true, api: api);
    addTearDown(store.dispose);
    api.response.complete(
      ApiDocument({'id': 12, 'points': 37, 'deduplicated': true}),
    );
    expect(await store.claimReward(), 0);
    expect(store.rewardClaimed, isTrue);
  });

  test(
    'Claim uses its confirmed wallet without reloading the profile',
    () async {
      final api = RewardGateway();
      final store = await testStore(authenticated: true, api: api);
      addTearDown(store.dispose);
      api.calls.clear();
      api.response.complete(
        ApiDocument({
          'id': 12,
          'points': 37,
          'wallet': {'available_points': 137},
        }),
      );
      expect(await store.claimReward(), 37);
      expect(store.rewardClaimed, isTrue);
      expect(store.points, 137);
      expect(api.calls, ['PostWalletDailyRewardClaims']);
      expect(store.loading, isNot(contains('profile')));
    },
  );

  test('Missing claim wallet refreshes the real balance', () async {
    final api = RewardGateway();
    final store = await testStore(authenticated: true, api: api);
    addTearDown(store.dispose);
    store.points = 100;
    api.calls.clear();
    api.response.complete(ApiDocument({'id': 12, 'points': 37}));
    expect(await store.claimReward(), 37);
    expect(store.points, 137);
    expect(store.rewardClaimed, isTrue);
    expect(api.calls, ['PostWalletDailyRewardClaims', 'GetWallet']);
  });

  test(
    'Wallet refresh failure retains the confirmed claim and known balance',
    () async {
      final api = RewardGateway();
      final store = await testStore(authenticated: true, api: api);
      addTearDown(store.dispose);
      store.points = 100;
      api.failing = 'GetWallet';
      api.response.complete(ApiDocument({'id': 12, 'points': 37}));
      expect(await store.claimReward(), 37);
      expect(store.rewardClaimed, isTrue);
      expect(store.points, 100);
    },
  );
}
