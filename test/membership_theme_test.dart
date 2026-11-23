import 'package:bojian_mobile/design.dart';
import 'package:bojian_mobile/membership_page.dart';
import 'package:bojian_mobile/membership_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

void main() {
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
        final warm = accent == AppAccent.warm;
        expect(
          find.ancestor(of: badge, matching: find.byType(ColorFiltered)),
          warm ? findsOneWidget : findsNothing,
        );
        for (final color in [...face.colors, selectedColor]) {
          expect(
            warm ? color.r > color.b : color.b > color.r,
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
