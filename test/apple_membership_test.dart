import 'package:bojian_mobile/apple_membership_products.dart';
import 'package:bojian_mobile/apple_membership_purchases.dart';
import 'package:bojian_mobile/design.dart';
import 'package:bojian_mobile/membership_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

const _products = {
  'products': [
    {'id': 'cn.kelance.bojian.membership.month', 'displayPrice': r'$3.99'},
    {'id': 'cn.kelance.bojian.membership.year', 'displayPrice': r'$19.99'},
    {'id': 'cn.kelance.bojian.membership.month.auto', 'displayPrice': r'$2.99'},
    {'id': 'cn.kelance.bojian.membership.year.auto', 'displayPrice': r'$18.99'},
  ],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AppleMembershipProducts.channel, null);
  });

  Future<FakeGateway> openMembership(
    WidgetTester tester, {
    required Future<Object?> Function(MethodCall) products,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AppleMembershipProducts.channel, (
          call,
        ) async {
          if (call.method == 'products') return products(call);
          if (call.method == 'unfinished' || call.method == 'restore') {
            return {'transactions': []};
          }
          if (call.method == 'purchase') return {'status': 'cancelled'};
          return null;
        });
    final api = FakeGateway();
    api.documents['GetMembership'] = {'active': false};
    api.documents['GetMembershipApple'] = {
      'available': true,
      'app_account_token': 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee',
      'product_ids': AppleMembershipProducts.productIDs,
      'sandbox_allowed': true,
    };
    api.documents['GetTemplates'] = {'items': []};
    api.documents['GetMembershipPlans'] = {
      'channels': ['ALIPAY', 'WECHAT'],
    };
    api.documents['GetMembershipWallet'] = {'coupons': [], 'cards': []};
    final store = await testStore(authenticated: true, api: api);
    addTearDown(() {
      if (usesAppleMembership) {
        AppleMembershipPurchases.forStore(store).dispose();
      }
      store.dispose();
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: MembershipPage(store: store),
      ),
    );
    await tester.pumpAndSettle();
    return api;
  }

  testWidgets(
    'iOS uses storefront prices and cannot route to external payment',
    (tester) async {
      final productCalls = <MethodCall>[];
      final api = await openMembership(
        tester,
        products: (call) async {
          productCalls.add(call);
          return _products;
        },
      );
      expect(membershipPageAvailable, isTrue);
      expect(productCalls.single.method, 'products');
      expect(
        (productCalls.single.arguments as Map)['productIDs'],
        containsAll(AppleMembershipProducts.productIDs.values),
      );
      expect(find.text(r'$3.99'), findsWidgets);
      expect(find.text(r'$19.99'), findsOneWidget);
      expect(find.textContaining('¥'), findsNothing);
      expect(find.text('自动续费'), findsNothing);
      expect(find.text('卡包'), findsNothing);

      await tester.tap(find.text('查看购买详情'));
      await tester.pumpAndSettle();
      expect(find.text('会员月卡'), findsOneWidget);
      expect(find.text('App Store 内购'), findsOneWidget);
      expect(find.text(r'$3.99'), findsNWidgets(2));
      expect(find.text('支付宝'), findsNothing);
      expect(find.text('微信支付'), findsNothing);
      expect(find.textContaining('优惠券'), findsNothing);
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, '确认购买'),
      );
      expect(button.onPressed, isNotNull);
      expect(api.calls, isNot(contains('PostMembershipOrders')));
      expect(find.text('到期不自动续费'), findsOneWidget);
      final toggle = tester.widget<Checkbox>(find.byType(Checkbox));
      expect(toggle.value, isFalse);
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      expect(find.text(r'$2.99'), findsNWidgets(2));
      expect(find.text('每月自动续费'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, '确认开通'), findsOneWidget);
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();

      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('年卡'));
      await tester.tap(find.text('年卡'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('查看购买详情'));
      await tester.pumpAndSettle();
      expect(find.text('会员年卡'), findsOneWidget);
      expect(find.text(r'$19.99'), findsNWidgets(2));
      expect(find.text(r'$3.99'), findsNothing);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant({TargetPlatform.iOS}),
  );

  for (final failure in ['missing', 'network']) {
    testWidgets('iOS $failure products stay unavailable and refresh recovers', (
      tester,
    ) async {
      var attempts = 0;
      final api = await openMembership(
        tester,
        products: (_) async {
          attempts++;
          if (attempts > 1) return _products;
          if (failure == 'network') {
            throw PlatformException(code: 'UNAVAILABLE');
          }
          return {'products': []};
        },
      );
      expect(find.text('暂不可用'), findsWidgets);
      expect(find.textContaining('¥'), findsNothing);
      await tester.tap(find.text('查看购买详情'));
      await tester.pumpAndSettle();
      expect(find.text('暂不可用'), findsNWidgets(2));
      await tester.tap(find.text('刷新'));
      await tester.pumpAndSettle();
      expect(attempts, 2);
      expect(find.text(r'$3.99'), findsNWidgets(2));
      expect(find.text('暂不可用'), findsNothing);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, '确认购买'))
            .onPressed,
        isNotNull,
      );
      expect(api.calls, isNot(contains('PostMembershipOrders')));
      expect(tester.takeException(), isNull);
    }, variant: TargetPlatformVariant({TargetPlatform.iOS}));
  }

  testWidgets('Android keeps its membership checkout without querying Apple', (
    tester,
  ) async {
    var appleCalls = 0;
    await openMembership(
      tester,
      products: (_) async {
        appleCalls++;
        return _products;
      },
    );
    expect(find.text('卡包'), findsOneWidget);
    expect(find.text('立即开通'), findsOneWidget);
    await tester.tap(find.text('立即开通'));
    await tester.pumpAndSettle();
    expect(find.byType(MembershipCheckoutPage), findsOneWidget);
    expect(find.text('支付宝'), findsOneWidget);
    expect(find.text('微信支付'), findsOneWidget);
    expect(find.text('App Store 内购'), findsNothing);
    expect(appleCalls, 0);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant({TargetPlatform.android}));
}
