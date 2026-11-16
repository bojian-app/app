import 'package:bojian_mobile/design.dart';
import 'package:bojian_mobile/membership_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

void main() {
  const alipay = MethodChannel('cn.kelance.bojian/alipay');
  final month = membershipPlans.firstWhere((plan) => plan.code == 'MONTH');

  Future<FakeGateway> pay(
    WidgetTester tester, {
    required String alipayStatus,
    required Map<String, dynamic> settled,
  }) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      alipay,
      (_) async => {'resultStatus': alipayStatus},
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        alipay,
        null,
      ),
    );
    final api = FakeGateway();
    api.documents['GetMembershipPlans'] = {
      'channels': ['ALIPAY'],
    };
    api.documents['GetMembershipWallet'] = {'coupons': [], 'cards': []};
    api.documents['PostMembershipOrders'] = {
      'id': 42,
      'plan_code': 'MONTH',
      'amount_cents': 2500,
      'discount_cents': 0,
      'channel': 'ALIPAY',
      'status': 'PENDING',
      'alipay_order_string': 'signed',
    };
    api.documents['GetMembershipOrdersId'] = settled;
    final store = await testStore(authenticated: true, api: api);
    addTearDown(store.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => openPage<void>(
              context,
              MembershipCheckoutPage(store: store, plan: month),
            ),
            child: const Text('会员页'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('会员页'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('立即支付'));
    // Checkout polls the order for up to 12 seconds; the result page may
    // show a spinner, so step the clock instead of settling.
    for (var i = 0; i < 16; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    return api;
  }

  testWidgets('a paid order replaces checkout with the result page', (
    tester,
  ) async {
    await pay(
      tester,
      alipayStatus: '9000',
      settled: {
        'id': 42,
        'plan_code': 'MONTH',
        'amount_cents': 2000,
        'discount_cents': 500,
        'channel': 'ALIPAY',
        'status': 'PAID',
        'paid_at': '2026-11-14T02:30:00Z',
        'membership_ends_at': '2026-12-14T02:30:00Z',
      },
    );
    expect(find.text('支付成功'), findsOneWidget);
    expect(find.text('¥20.00'), findsOneWidget);
    expect(find.text('-¥5.00'), findsOneWidget);
    expect(find.text('会员有效期至'), findsOneWidget);
    expect(find.text('确认订单'), findsNothing);

    // Done returns to where checkout was opened, not to checkout.
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();
    expect(find.text('会员页'), findsOneWidget);
    expect(find.text('确认订单'), findsNothing);
  });

  testWidgets('a payment awaiting confirmation keeps checking on the result '
      'page', (tester) async {
    final api = await pay(
      tester,
      alipayStatus: '8000',
      settled: {
        'id': 42,
        'plan_code': 'MONTH',
        'amount_cents': 2500,
        'channel': 'ALIPAY',
        'status': 'PENDING',
      },
    );
    expect(find.text('支付结果确认中'), findsOneWidget);

    api.documents['GetMembershipOrdersId'] = {
      ...api.documents['GetMembershipOrdersId']!,
      'status': 'PAID',
      'membership_ends_at': '2026-12-14T02:30:00Z',
    };
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('支付成功'), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('a cancelled payment stays on checkout', (tester) async {
    await pay(
      tester,
      alipayStatus: '6001',
      settled: {'id': 42, 'status': 'PENDING'},
    );
    expect(find.text('确认订单'), findsOneWidget);
    expect(find.text('支付成功'), findsNothing);
    await tester.pump(const Duration(seconds: 3));
  });
}
