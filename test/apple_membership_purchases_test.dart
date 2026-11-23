import 'dart:async';

import 'package:bojian_mobile/api/bojian_api.dart';
import 'package:bojian_mobile/app_store.dart';
import 'package:bojian_mobile/apple_membership_products.dart';
import 'package:bojian_mobile/apple_membership_purchases.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:bojian_mobile/template_market_store.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

const _token = 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee';
const _transaction = {
  'transactionID': '2000000123456789',
  'environment': 'Sandbox',
  'productID': 'cn.kelance.bojian.membership.month',
  'appAccountToken': _token,
};
const _delivered = {
  'transaction_id': '2000000123456789',
  'status': 'DELIVERED',
  'membership': {'active': true, 'ends_at': '2026-12-13T00:00:00Z'},
};

class _Gateway extends FakeGateway {
  Completer<ApiDocument>? confirmation;
  final confirming = Completer<void>();
  bool grantTemplate = false;

  @override
  Future<ApiDocument> call(
    String method, {
    Map<String, String> path = const {},
    Map<String, String> query = const {},
    Map<String, dynamic>? body,
    Map<String, String> headers = const {},
  }) async {
    final response = await super.call(
      method,
      path: path,
      query: query,
      body: body,
      headers: headers,
    );
    if (method == 'PostMembershipAppleTransactions') {
      if (!confirming.isCompleted) confirming.complete();
      if (confirmation != null) return confirmation!.future;
      if (grantTemplate) {
        documents['GetMeTemplates'] = {
          'items': [
            {
              'id': 9,
              'source': 'ACQUIRED',
              'pricing_type': 'PAID',
              'expires_at': null,
            },
          ],
        };
      }
    }
    return response;
  }
}

class _Harness {
  final api = _Gateway();
  late final AppStore store;
  late final AppleMembershipPurchases purchases;
  final nativeCalls = <MethodCall>[];
  Map<String, dynamic> purchaseResult = {
    'status': 'verified',
    'transaction': _transaction,
  };
  List<Map<String, dynamic>> unfinished = [];
  List<Map<String, dynamic>> history = [];
  bool unverified = false;

  Future<void> start() async {
    api.documents['GetMembershipApple'] = {
      'available': true,
      'app_account_token': _token,
      'product_ids': AppleMembershipProducts.productIDs,
      'sandbox_allowed': true,
      'template_products': [
        for (final p in AppleMembershipProducts.templateProductIDs.entries)
          {'template_id': p.key, 'product_id': p.value},
      ],
    };
    api.documents['PostMembershipAppleTransactions'] = _delivered;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AppleMembershipProducts.channel, (
          call,
        ) async {
          nativeCalls.add(call);
          return switch (call.method) {
            'unfinished' => {
              'transactions': unfinished,
              'unverified': unverified,
            },
            'restore' => {'transactions': history, 'unverified': unverified},
            'purchase' => purchaseResult,
            'products' => {
              'products': [
                {
                  'id': 'cn.kelance.bojian.template.9',
                  'displayPrice': r'A$1.49',
                },
              ],
            },
            _ => null,
          };
        });
    store = await testStore(authenticated: true, api: api);
    purchases = AppleMembershipPurchases(store)..start();
    await purchases.syncUnfinished();
  }

  int nativeCount(String method) =>
      nativeCalls.where((call) => call.method == method).length;
  int get submissions => api.calls
      .where((method) => method == 'PostMembershipAppleTransactions')
      .length;

  Future<void> event(Map<String, dynamic> transaction) async {
    final completer = Completer<void>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          AppleMembershipProducts.channel.name,
          const StandardMethodCodec().encodeMethodCall(
            MethodCall('transaction', transaction),
          ),
          (_) => completer.complete(),
        );
    await completer.future;
  }

  void dispose() {
    purchases.dispose();
    store.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AppleMembershipProducts.channel, null);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Harness h;
  setUp(() async {
    h = _Harness();
    await h.start();
  });
  tearDown(() => h.dispose());

  test(
    'configuration is refreshed and unavailable products never charge',
    () async {
      h.api.documents['GetMembershipApple']!['available'] = false;
      await h.purchases.purchase('MONTH');
      expect(h.nativeCount('purchase'), 0);
      expect(h.submissions, 0);
      expect(h.purchases.state, ApplePurchaseState.error);
      h.api.documents['GetMembershipApple']!['available'] = true;
      h.api.documents['GetMembershipApple']!['product_ids'] = {
        'MONTH': 'wrong',
      };
      await h.purchases.purchase('MONTH');
      expect(h.nativeCount('purchase'), 0);
    },
  );

  test('auto-renew choice buys the auto-renewable product', () async {
    await h.purchases.purchase('YEAR', autoRenew: true);
    final arguments =
        h.nativeCalls.firstWhere((c) => c.method == 'purchase').arguments
            as Map;
    expect(arguments['productID'], 'cn.kelance.bojian.membership.year.auto');
  });

  test('verified purchase finishes only after server delivery', () async {
    h.api.confirmation = Completer<ApiDocument>();
    final purchase = h.purchases.purchase('MONTH');
    await h.api.confirming.future;
    expect(h.nativeCount('finish'), 0);
    expect(h.purchases.state, ApplePurchaseState.confirming);
    expect(h.api.lastBody, {
      'transaction_id': _transaction['transactionID'],
      'environment': 'Sandbox',
    });
    final arguments =
        h.nativeCalls.firstWhere((c) => c.method == 'purchase').arguments
            as Map;
    expect(arguments['appAccountToken'], _token);
    h.api.confirmation!.complete(ApiDocument(_delivered));
    await purchase;
    expect(h.nativeCount('finish'), 1);
    expect(h.purchases.state, ApplePurchaseState.delivered);
    expect(h.purchases.needsRetry, isFalse);
    expect(h.purchases.needsRestore, isFalse);
  });

  test('delivery failure retains transaction and retry never charges again', () async {
    h.api.failing = 'PostMembershipAppleTransactions';
    await h.purchases.purchase('MONTH');
    expect(h.nativeCount('finish'), 0);
    expect(h.purchases.state, ApplePurchaseState.error);
    expect(h.purchases.needsRetry, isTrue);
    h.api.failing = null;
    // Even a second purchase call must retry the old order, not open Apple pay.
    await h.purchases.purchase('MONTH');
    expect(h.nativeCount('purchase'), 1);
    expect(h.nativeCount('finish'), 1);
    expect(h.purchases.state, ApplePurchaseState.delivered);
  });

  for (final status in ['cancelled', 'pending', 'unverified']) {
    test('$status does not grant, submit or finish a transaction', () async {
      h.purchaseResult = {'status': status};
      await h.purchases.purchase('MONTH');
      expect(h.submissions, 0);
      expect(h.nativeCount('finish'), 0);
      expect(h.purchases.state, isNot(ApplePurchaseState.delivered));
      if (status != 'cancelled') {
        await h.purchases.purchase('MONTH');
        expect(h.nativeCount('purchase'), 1);
      }
    });
  }

  test(
    'purchase result and simultaneous transaction update are deduplicated',
    () async {
      h.api.confirmation = Completer<ApiDocument>();
      final purchase = h.purchases.purchase('MONTH');
      await h.api.confirming.future;
      final event = h.event(_transaction);
      await Future<void>.delayed(Duration.zero);
      expect(h.submissions, 1);
      h.api.confirmation!.complete(ApiDocument(_delivered));
      await Future.wait([purchase, event]);
      expect(h.nativeCount('finish'), 1);
    },
  );

  test(
    'account change during server confirmation never finishes old order',
    () async {
      h.api.confirmation = Completer<ApiDocument>();
      final purchase = h.purchases.purchase('MONTH');
      await h.api.confirming.future;
      await h.store.endSession(remote: false);
      await h.store.signIn('13812345678', '654321');
      h.api.confirmation!.complete(ApiDocument(_delivered));
      await purchase;
      expect(h.nativeCount('finish'), 0);
      expect(h.purchases.state, isNot(ApplePurchaseState.delivered));
      expect(h.purchases.membershipRevision, 0);
    },
  );

  test(
    'foreground retries unfinished without requesting AppStore sync',
    () async {
      h.unfinished = [_transaction];
      await h.purchases.syncUnfinished();
      expect(h.submissions, 1);
      expect(h.nativeCount('finish'), 1);
      expect(h.nativeCount('restore'), 0);
      expect(h.nativeCount('purchase'), 0);
    },
  );

  test(
    'explicit restore verifies full history and skips another account',
    () async {
      h.history = [
        _transaction,
        {
          ..._transaction,
          'transactionID': '2000000123456790',
          'appAccountToken': 'ffffffff-bbbb-4ccc-8ddd-eeeeeeeeeeee',
        },
      ];
      await h.purchases.restore();
      expect(h.nativeCount('restore'), 1);
      expect(h.submissions, 1);
      expect(h.nativeCount('purchase'), 0);
      expect(h.nativeCount('finish'), 1);
    },
  );

  for (final status in ['EXPIRED', 'REVOKED']) {
    test(
      '$status finishes queue without displaying a new membership grant',
      () async {
        h.unfinished = [_transaction];
        h.api.documents['PostMembershipAppleTransactions'] = {
          ..._delivered,
          'status': status,
        };
        await h.purchases.syncUnfinished();
        expect(h.nativeCount('finish'), 1);
        expect(h.purchases.state, isNot(ApplePurchaseState.delivered));
        expect(h.purchases.membershipRevision, 1);
      },
    );
  }

  test('unverified history is never reported as restored', () async {
    h.unverified = true;
    await h.purchases.restore();
    expect(h.submissions, 0);
    expect(h.nativeCount('finish'), 0);
    expect(h.purchases.state, ApplePurchaseState.error);
  });

  test(
    'merged account restores its older token and finishes with that token',
    () async {
      const oldToken = 'ffffffff-bbbb-4ccc-8ddd-eeeeeeeeeeee';
      h.api.documents['GetMembershipApple']!['app_account_tokens'] = [
        _token,
        oldToken,
      ];
      h.history = [
        {..._transaction, 'appAccountToken': oldToken},
      ];
      await h.purchases.restore();
      expect(h.submissions, 1);
      expect(h.nativeCount('finish'), 1);
      final finish = h.nativeCalls.singleWhere(
        (call) => call.method == 'finish',
      );
      expect((finish.arguments as Map)['appAccountToken'], oldToken);
    },
  );

  test('a mismatched server acknowledgement cannot finish an order', () async {
    h.api.documents['PostMembershipAppleTransactions'] = {
      ..._delivered,
      'transaction_id': '9999999',
    };
    await h.purchases.purchase('MONTH');
    expect(h.nativeCount('finish'), 0);
    expect(h.purchases.needsRetry, isTrue);
    expect(h.purchases.state, ApplePurchaseState.error);
  });

  group('Apple templates', () {
    final transaction = {
      ..._transaction,
      'productID': 'cn.kelance.bojian.template.9',
    };
    final delivered = {
      ..._delivered,
      'product_id': 'cn.kelance.bojian.template.9',
      'template_id': 9,
      'membership': {'active': false},
    };
    setUp(() {
      h.purchaseResult = {'status': 'verified', 'transaction': transaction};
      h.api.documents['PostMembershipAppleTransactions'] = delivered;
      h.api.documents['GetMeTemplates'] = {'items': []};
    });

    test(
      'simultaneous callbacks deliver one template without changing membership',
      () async {
        h.api.confirmation = Completer<ApiDocument>();
        final purchase = h.purchases.purchaseTemplate(9);
        await h.api.confirming.future;
        final event = h.event(transaction);
        await Future<void>.delayed(Duration.zero);
        expect(h.submissions, 1);
        expect(h.nativeCount('finish'), 0);
        h.api.confirmation!.complete(ApiDocument(delivered));
        await Future.wait([purchase, event]);
        expect(h.nativeCount('finish'), 1);
        expect(h.purchases.templateRevision, 1);
        expect(h.purchases.membershipRevision, 0);
      },
    );

    test(
      'failed template acknowledgement retries without another purchase',
      () async {
        h.api.failing = 'PostMembershipAppleTransactions';
        await h.purchases.purchaseTemplate(9);
        expect(h.nativeCount('finish'), 0);
        expect(h.purchases.templateRevision, 0);
        h.api.failing = null;
        await h.purchases.purchaseTemplate(9);
        expect(h.nativeCount('purchase'), 1);
        expect(h.nativeCount('finish'), 1);
        expect(h.purchases.templateRevision, 1);
      },
    );

    test('mismatched template acknowledgement remains unfinished', () async {
      h.api.documents['PostMembershipAppleTransactions'] = {
        ...delivered,
        'template_id': 10,
      };
      await h.purchases.purchaseTemplate(9);
      expect(h.nativeCount('finish'), 0);
      expect(h.purchases.templateRevision, 0);
      expect(h.purchases.needsRetry, isTrue);
    });

    test(
      'unlisted templates and wrong native products never deliver',
      () async {
        await h.purchases.purchaseTemplate(99);
        expect(h.nativeCount('purchase'), 0);
        h.purchaseResult = {
          'status': 'verified',
          'transaction': {
            ...transaction,
            'productID': 'cn.kelance.bojian.template.10',
          },
        };
        await h.purchases.purchaseTemplate(9);
        expect(h.submissions, 0);
        expect(h.nativeCount('finish'), 0);
        expect(h.purchases.needsRestore, isTrue);
      },
    );

    test(
      'restoring refunded template refreshes access without purchasing',
      () async {
        h.history = [transaction];
        h.api.documents['PostMembershipAppleTransactions'] = {
          ...delivered,
          'status': 'REVOKED',
        };
        await h.purchases.restore();
        expect(h.nativeCount('purchase'), 0);
        expect(h.nativeCount('finish'), 1);
        expect(h.purchases.templateRevision, 1);
        expect(h.purchases.lastDeliveredProductID, isNull);
      },
    );

    test('market uses localized price and server ownership, then prevents repurchase', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final market = TemplateMarketStore(h.store);
      try {
        await market.applePurchases!.syncUnfinished();
        await market.appleProducts!.load();
        expect(market.priceLabel(9, 0), r'A$1.49');
        expect(market.canPurchase(10), isFalse);
        h.api.grantTemplate = true;
        expect(await market.purchase(id: 9), isTrue);
        expect(market.ownedIDs, contains(9));
        expect(await market.purchase(id: 9), isTrue);
        expect(h.nativeCount('purchase'), 1);
        expect(h.api.calls, isNot(contains('PostTemplateOrders')));
      } finally {
        market.dispose();
        market.applePurchases!.dispose();
        debugDefaultTargetPlatformOverride = null;
      }
    });

    test(
      'market does not grant ownership from StoreKit success alone',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        final market = TemplateMarketStore(h.store);
        try {
          await market.applePurchases!.syncUnfinished();
          await market.appleProducts!.load();
          h.api.failing = 'PostMembershipAppleTransactions';
          await expectLater(market.purchase(id: 9), throwsA(isA<ApiFailure>()));
          expect(market.ownedIDs, isEmpty);
          expect(h.nativeCount('finish'), 0);
          h.api.failing = null;
          h.api.grantTemplate = true;
          expect(await market.purchase(id: 9), isTrue);
          expect(h.nativeCount('purchase'), 1);
        } finally {
          market.dispose();
          market.applePurchases!.dispose();
          debugDefaultTargetPlatformOverride = null;
        }
      },
    );
  });
}
