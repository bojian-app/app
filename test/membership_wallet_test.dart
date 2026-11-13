import 'package:bojian_mobile/membership_page.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
