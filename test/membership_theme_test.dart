import 'package:bojian_mobile/design.dart';
import 'package:bojian_mobile/membership_page.dart';
import 'package:bojian_mobile/membership_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

void main() {
  testWidgets('大字体下会员权益按列对齐，常见问题滚入后可展开', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    addTearDown(tester.view.reset);
    final api = FakeGateway();
    api.documents['GetMembership'] = {'active': false, 'ai_packs': []};
    final store = await testStore(authenticated: true, api: api);
    addTearDown(store.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.65)),
          child: child!,
        ),
        home: MembershipPage(store: store),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ExpansionTile), findsNothing);
    final free = find.text('不提供');
    final member = find.text('月卡 3 次\n年卡 36 次');
    expect(tester.getTopLeft(free.first).dx, tester.getTopLeft(free.last).dx);
    expect(
      tester.getTopLeft(member.first).dx,
      tester.getTopLeft(member.last).dx,
    );
    expect(
      tester.getTopLeft(member.first).dx,
      greaterThan(tester.getTopLeft(free.first).dx),
    );
    final (question, answer) = membershipFaqs.last;
    await tester.scrollUntilVisible(find.text(question).hitTestable(), 230);
    await tester.pumpAndSettle();
    await tester.tap(find.text(question));
    await tester.pumpAndSettle();
    expect(find.text(answer), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('会员卡和套餐选中态在切换外观时立即换色', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 1000);
    addTearDown(tester.view.reset);
    final api = FakeGateway();
    api.documents['GetMembership'] = {
      'active': true,
      'ends_at': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
      'plan_code': 'YEAR',
    };
    final store = await testStore(authenticated: true, api: api);
    addTearDown(store.dispose);
    final page = MembershipPage(store: store);
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      for (final accent in AppAccent.values) {
        await tester.pumpWidget(
          MaterialApp(
            theme: accent.lightTheme,
            darkTheme: accent.darkTheme,
            themeMode: mode,
            home: page,
          ),
        );
        await tester.pumpAndSettle();
        final face = tester
            .widgetList<DecoratedBox>(find.byType(DecoratedBox))
            .map((box) => box.decoration)
            .whereType<BoxDecoration>()
            .map((box) => box.gradient)
            .whereType<LinearGradient>()
            .singleWhere((gradient) => gradient.stops?.length == 4);
        final check = tester.widget<AnimatedContainer>(
          find
              .ancestor(
                of: find.byIcon(Icons.check_rounded),
                matching: find.byType(AnimatedContainer),
              )
              .first,
        );
        final selectedColor = (check.decoration! as BoxDecoration).color!;
        final badge = find.byWidgetPredicate(
          (w) =>
              w is Image &&
              w.semanticLabel != null &&
              w.semanticLabel!.contains('会员'),
        );
        expect(badge, findsOneWidget);
        expect(
          find.ancestor(of: badge, matching: find.byType(ColorFiltered)),
          accent == AppAccent.blue ? findsNothing : findsOneWidget,
        );
        for (final color in [...face.colors, selectedColor]) {
          expect(
            switch (accent) {
              AppAccent.warm => color.r > color.b,
              AppAccent.green => color.g > color.r && color.g > color.b,
              AppAccent.blue => color.b > color.r,
            },
            isTrue,
            reason: '$accent / $mode / $color',
          );
        }
      }
    }
    await tester.pumpWidget(const SizedBox());
    MembershipStatus.instance.reset();
  });
}
