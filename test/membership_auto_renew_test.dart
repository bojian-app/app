import 'package:bojian_mobile/design.dart';
import 'package:bojian_mobile/membership_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

void main() {
  Future<FakeGateway> openMembership(
    WidgetTester tester, {
    List<String> autoRenewChannels = const ['ALIPAY', 'WECHAT'],
    Map<String, dynamic>? running,
  }) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final api = FakeGateway();
    api.documents['GetMembership'] = {'active': false, 'auto_renew': running};
    api.documents['GetTemplates'] = {'items': []};
    api.documents['GetMembershipPlans'] = {
      'channels': ['ALIPAY', 'WECHAT'],
      'auto_renew': [
        {
          'plan_code': 'MONTH',
          'amount_cents': 1800,
          'channels': autoRenewChannels,
        },
        {
          'plan_code': 'YEAR',
          'amount_cents': 12800,
          'channels': autoRenewChannels,
        },
      ],
    };
    api.documents['GetMembershipWallet'] = {'coupons': [], 'cards': []};
    final store = await testStore(authenticated: true, api: api);
    addTearDown(store.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: MembershipPage(store: store),
      ),
    );
    await tester.pumpAndSettle();
    return api;
  }

  testWidgets('checkout offers an unticked auto-renew checkbox', (
    tester,
  ) async {
    final api = await openMembership(tester, autoRenewChannels: ['ALIPAY']);
    // No separate auto-renew plan card.
    expect(find.text('连续包月'), findsNothing);
    expect(find.text('默认一次性购买；下单时可勾选自动续费'), findsOneWidget);

    await tester.tap(find.text('月卡').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('立即开通'));
    await tester.pumpAndSettle();
    expect(find.text('自动续费 ¥18/月'), findsOneWidget);
    expect(find.text('不勾选为一次性购买，到期不自动扣费。'), findsOneWidget);
    expect(find.text('¥25'), findsOneWidget);
    expect(find.text('微信支付'), findsOneWidget);

    await tester.tap(find.text('自动续费 ¥18/月'));
    await tester.pumpAndSettle();
    expect(find.textContaining('每月自动扣费 ¥18，在会员到期前扣款'), findsOneWidget);
    expect(find.text('¥18'), findsOneWidget);
    expect(find.text('支付并开通'), findsOneWidget);
    // Only channels with approved deduction are offered.
    expect(find.text('微信支付'), findsNothing);

    api.documents['PostMembershipSubscriptions'] = {
      'subscription': {'status': 'ACTIVE'},
    };
    await tester.tap(find.text('支付并开通'));
    await tester.pumpAndSettle();
    expect(api.calls, contains('PostMembershipSubscriptions'));
    expect(api.lastMutationBody, {'plan_code': 'MONTH', 'channel': 'ALIPAY'});
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('year card can also renew automatically', (tester) async {
    await openMembership(tester, autoRenewChannels: ['ALIPAY']);
    await tester.tap(find.text('立即开通'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('自动续费 ¥128/年'));
    await tester.pumpAndSettle();
    expect(find.textContaining('每年自动扣费 ¥128'), findsOneWidget);
  });

  testWidgets('no checkbox until a channel is approved', (tester) async {
    await openMembership(tester, autoRenewChannels: []);
    expect(find.text('一次性购买，到期不自动扣费'), findsOneWidget);
    await tester.tap(find.text('立即开通'));
    await tester.pumpAndSettle();
    expect(find.textContaining('自动续费 ¥'), findsNothing);
  });

  testWidgets('a running auto-renewal can be cancelled', (tester) async {
    final api = await openMembership(
      tester,
      running: {
        'id': 7,
        'channel': 'WECHAT',
        'plan_code': 'MONTH',
        'status': 'ACTIVE',
        'amount_cents': 1800,
        'next_charge_on': '2026-12-14',
      },
    );
    expect(find.text('月卡自动续费生效中'), findsOneWidget);
    expect(find.text('下次扣款 2026-12-14 · ¥18 · 微信支付'), findsOneWidget);

    api.documents['GetMembership'] = {'active': true, 'auto_renew': null};
    await tester.ensureVisible(find.text('取消自动续费'));
    await tester.drag(find.byType(ListView), const Offset(0, -200));
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消自动续费'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消续费'));
    await tester.pumpAndSettle();
    expect(api.calls, contains('PostMembershipSubscriptionCancel'));
    expect(find.text('月卡自动续费生效中'), findsNothing);
    await tester.pump(const Duration(seconds: 3));
  });
}
