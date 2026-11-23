import 'package:bojian_mobile/design.dart';
import 'package:bojian_mobile/membership_page.dart';
import 'package:bojian_mobile/messages_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

void main() {
  final year = membershipPlans.firstWhere((plan) => plan.code == 'YEAR');
  final month = membershipPlans.firstWhere((plan) => plan.code == 'MONTH');
  WalletCoupon coupon(
    int id,
    int cents,
    String? plan, [
    String status = 'AVAILABLE',
  ]) => WalletCoupon.fromJson({
    'id': id,
    'title': '立减券',
    'amount_cents': cents,
    'plan_code': plan,
    'expires_at': '2030-01-01T00:00:00Z',
    'status': status,
  });

  test('checkout picks the largest usable coupon for the plan', () {
    final wallet = MembershipWallet(
      coupons: [
        coupon(1, 500, null),
        coupon(2, 3000, 'YEAR'),
        coupon(3, 9000, 'YEAR', 'USED'),
        coupon(4, 1000, 'MONTH'),
      ],
      cards: const [],
    );
    expect(wallet.bestFor(year)?.id, 2);
    expect(wallet.bestFor(month)?.id, 4);
  });

  test('a coupon never makes the order free', () {
    expect(coupon(1, 9999, null).discountFor(month), month.amountCents - 1);
    expect(coupon(2, 500, null).discountFor(month), 500);
  });

  test('cards map to their plan', () {
    final card = WalletCard.fromJson({
      'id': 1,
      'plan_code': 'YEAR',
      'expires_at': '2030-01-01T00:00:00Z',
      'status': 'AVAILABLE',
    });
    expect(card.plan.orderName, '会员年卡');
    expect(card.membershipEndsAt, isNull);
  });

  testWidgets('卡包可筛选、查看历史并用指定券确认订单', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 780);
    addTearDown(tester.view.reset);
    final api = FakeGateway();
    api.documents['GetMembershipWallet'] = {
      'coupons': [
        {
          'id': 1,
          'title': '月卡小额券',
          'amount_cents': 100,
          'plan_code': 'MONTH',
          'status': 'AVAILABLE',
        },
        {'id': 2, 'title': '通用五元券', 'amount_cents': 500, 'status': 'AVAILABLE'},
        {'id': 3, 'title': '往期券', 'amount_cents': 100, 'status': 'EXPIRED'},
      ],
      'cards': [],
    };
    final store = await testStore(authenticated: true, api: api);
    addTearDown(store.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: MembershipWalletPage(store: store),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('往期券'), findsNothing);
    await tester.tap(find.text('历史记录'));
    await tester.pumpAndSettle();
    expect(find.text('往期券'), findsOneWidget);
    expect(find.text('已过期'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('筛选'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('年卡适用'));
    await tester.pumpAndSettle();
    expect(find.text('月卡小额券'), findsNothing);
    expect(find.text('通用五元券'), findsOneWidget);
    await tester.tap(find.byTooltip('筛选'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('全部'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('去使用').first);
    await tester.pumpAndSettle();
    expect(find.text('确认订单'), findsOneWidget);
    expect(find.textContaining('1.00'), findsWidgets);
    expect(api.calls, isNot(contains('PostMembershipOrders')));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Benefit notification opens the wallet and marks it read', (
    tester,
  ) async {
    final api = FakeGateway();
    api.documents['GetNotifications'] = {
      'unread_count': 1,
      'items': [
        {
          'id': 31,
          'type': 'MEMBERSHIP_BENEFIT',
          'subject_type': 'MEMBERSHIP_WALLET',
          'payload': {'title': '你收到了会员年卡', 'body': '1 张会员年卡已放入卡包'},
        },
      ],
    };
    api.documents['GetMembershipWallet'] = {'coupons': [], 'cards': []};
    final store = await testStore(authenticated: true, api: api);
    addTearDown(store.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: Scaffold(body: MessagesPage(store: store)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('你收到了会员年卡'));
    await tester.pumpAndSettle();
    expect(find.byType(MembershipWalletPage), findsOneWidget);
    expect(store.inbox.single.read, isTrue);
    expect(api.calls, contains('PostNotificationsRead'));
  });
}
