import 'package:bojian_mobile/design.dart';
import 'package:bojian_mobile/membership_page.dart';
import 'package:bojian_mobile/membership_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

Future<void> _pumpMembership(
  WidgetTester tester,
  Map<String, dynamic> membership,
) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(800, 2400);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final api = FakeGateway();
  api.documents['GetMembership'] = membership;
  final store = await testStore(authenticated: true, api: api);
  addTearDown(store.dispose);
  await tester.pumpWidget(
    MaterialApp(
      theme: appTheme,
      home: MembershipPage(store: store),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('member sees remaining quotas summed across packs', (
    tester,
  ) async {
    final soon = DateTime(2030, 1, 5, 9, 30);
    final later = DateTime(2030, 12, 20, 9, 30);
    await _pumpMembership(tester, {
      'active': true,
      'ends_at': later.toUtc().toIso8601String(),
      'plan_code': 'YEAR',
      'ai_create_remaining': 186,
      'ai_polish_remaining': 185,
      'ai_text_remaining': 1287,
      'ai_packs': [
        {
          'source': 'MEMBERSHIP',
          'ends_at': soon.toUtc().toIso8601String(),
          'ai_create_remaining': 6,
          'ai_polish_remaining': 5,
          'ai_text_remaining': 87,
        },
        {
          'source': 'MEMBERSHIP',
          'ends_at': later.toUtc().toIso8601String(),
          'ai_create_remaining': 180,
          'ai_polish_remaining': 180,
          'ai_text_remaining': 1200,
        },
      ],
    });
    expect(find.bySemanticsLabel('简历生成剩余 186 次'), findsOneWidget);
    expect(find.bySemanticsLabel('简历优化剩余 185 次'), findsOneWidget);
    expect(find.bySemanticsLabel('单段生成剩余 1287 次'), findsOneWidget);
    expect(find.textContaining('最早一份 01-05 09:30 到期清零'), findsNothing);
    expect(find.textContaining('AI 简历生成 180 次'), findsNothing);
    expect(tester.takeException(), isNull);
    // Disposing the page and the shared status cancels both expiry timers.
    await tester.pumpWidget(const SizedBox());
    MembershipStatus.instance.reset();
  });

  testWidgets('referral trial is a membership with its own uses', (
    tester,
  ) async {
    final ends = DateTime(2030, 3, 2, 18, 5);
    await _pumpMembership(tester, {
      'active': true,
      'ends_at': ends.toUtc().toIso8601String(),
      'ai_packs': [
        {
          'source': 'REFERRAL',
          'ends_at': ends.toUtc().toIso8601String(),
          'ai_create_remaining': 1,
          'ai_polish_remaining': 1,
          'ai_text_remaining': 10,
        },
      ],
    });
    expect(find.bySemanticsLabel('简历生成剩余 1 次'), findsOneWidget);
    expect(find.bySemanticsLabel('简历优化剩余 1 次'), findsOneWidget);
    expect(find.bySemanticsLabel('单段生成剩余 10 次'), findsOneWidget);
    expect(find.textContaining('邀请奖励 03-02 18:05 到期清零'), findsNothing);
    expect(find.textContaining('会员体验中'), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    MembershipStatus.instance.reset();
  });

  testWidgets('members buy extra uses by the use', (tester) async {
    final ends = DateTime(2030, 12, 20, 9, 30);
    await _pumpWithPlans(tester, {
      'active': true,
      'ends_at': ends.toUtc().toIso8601String(),
      'plan_code': 'MONTH',
      'ai_packs': [
        {
          'source': 'MEMBERSHIP',
          'ends_at': ends.toUtc().toIso8601String(),
          'ai_create_remaining': 15,
          'ai_polish_remaining': 15,
          'ai_text_remaining': 100,
        },
      ],
      'ai_addon': {
        'ai_create_remaining': 3,
        'ai_polish_remaining': 0,
        'ai_text_remaining': 25,
      },
    });
    expect(find.bySemanticsLabel('简历生成剩余 18 次'), findsOneWidget);
    expect(find.bySemanticsLabel('简历优化剩余 15 次'), findsOneWidget);
    expect(find.bySemanticsLabel('单段生成剩余 125 次'), findsOneWidget);
    expect(find.text('加购 AI 次数'), findsNothing);
    expect(find.text('购买次数'), findsNothing);
    expect(find.text('AI 次数加购'), findsNothing);
    expect(find.text('加购次数'), findsOneWidget);
    expect(find.text('18'), findsOneWidget);
    expect(find.text('125'), findsOneWidget);
    await tester.tap(find.text('加购次数'));
    await tester.pumpAndSettle();
    expect(find.text('选择加购类型'), findsOneWidget);
    expect(find.text('AI 简历生成'), findsWidgets);
    expect(find.text('AI 简历优化'), findsWidgets);
    expect(find.text('AI 单段生成'), findsWidgets);
    await tester.tap(find.widgetWithText(ListTile, 'AI 简历生成'));
    await tester.pumpAndSettle();
    expect(find.text('¥4.95'), findsWidgets);
    await tester.tap(find.bySemanticsLabel('增加'));
    await tester.pump();
    expect(find.text('¥5.94'), findsWidgets);
    await tester.tap(find.text('20 次'));
    await tester.pump();
    expect(find.text('¥19.80'), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    MembershipStatus.instance.reset();
  });

  testWidgets('lapsed members see their bought uses frozen', (tester) async {
    await _pumpWithPlans(tester, {
      'active': false,
      'ai_addon': {
        'ai_create_remaining': 2,
        'ai_polish_remaining': 1,
        'ai_text_remaining': 0,
      },
    });
    expect(find.text('已冻结'), findsOneWidget);
    expect(find.bySemanticsLabel('简历生成剩余 2 次'), findsOneWidget);
    expect(find.bySemanticsLabel('简历优化剩余 1 次'), findsOneWidget);
    expect(find.bySemanticsLabel('单段生成剩余 0 次'), findsOneWidget);
    expect(find.text('加购 AI 次数'), findsNothing);
    expect(find.text('加购次数'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('without packs no remaining uses are shown', (tester) async {
    await _pumpMembership(tester, {'active': false});
    expect(find.textContaining('剩余'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

const _addonPlans = {
  'items': [],
  'channels': ['ALIPAY'],
  'ai_addons': [
    {
      'kind': 'CREATE',
      'name': 'AI 简历生成',
      'unit_price_cents': 99,
      'max_quantity': 200,
    },
    {
      'kind': 'POLISH',
      'name': 'AI 简历优化',
      'unit_price_cents': 99,
      'max_quantity': 200,
    },
    {
      'kind': 'TEXT',
      'name': 'AI 单段生成',
      'unit_price_cents': 10,
      'max_quantity': 1000,
    },
  ],
};

Future<void> _pumpWithPlans(
  WidgetTester tester,
  Map<String, dynamic> membership,
) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 1200);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final api = FakeGateway();
  api.documents['GetMembership'] = membership;
  api.documents['GetMembershipPlans'] = _addonPlans;
  final store = await testStore(authenticated: true, api: api);
  addTearDown(store.dispose);
  await tester.pumpWidget(
    MaterialApp(
      theme: appTheme,
      home: MembershipPage(store: store),
    ),
  );
  await tester.pumpAndSettle();
}
