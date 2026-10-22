import 'package:bojian_mobile/app_shell.dart';
import 'package:bojian_mobile/auth_page.dart';
import 'package:bojian_mobile/design.dart';
import 'package:bojian_mobile/main.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

Future<void> changeAppearance(
  WidgetTester tester,
  Brightness brightness,
) async {
  tester.platformDispatcher.platformBrightnessTestValue = brightness;
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    TestWidgetsFlutterBinding
            .instance
            .platformDispatcher
            .platformBrightnessTestValue =
        Brightness.light;
  });

  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher
        .clearPlatformBrightnessTestValue();
  });

  testWidgets(
    'System appearance updates the login page without losing consent or starting requests',
    (tester) async {
      final api = FakeGateway();
      final store = await testStore(authenticated: false, api: api);
      await tester.pumpWidget(MyApp(startupAdsEnabled: false, store: store));
      await tester.pumpAndSettle();
      expect(
        Theme.of(tester.element(find.byType(AuthPage))).brightness,
        Brightness.light,
      );
      await tester.tap(find.byKey(const ValueKey('auth-consent')));
      await tester.pumpAndSettle();
      final pageState = tester.state(find.byType(AuthPage));
      final requests = List<String>.of(api.calls);

      for (final brightness in [Brightness.dark, Brightness.light]) {
        await changeAppearance(tester, brightness);
        final context = tester.element(find.byType(AuthPage));
        expect(Theme.of(context).brightness, brightness);
        expect(tester.state(find.byType(AuthPage)), same(pageState));
        expect(
          tester
              .widget<Checkbox>(find.byKey(const ValueKey('auth-consent')))
              .value,
          isTrue,
        );
        expect(api.calls, requests);
        expect(store.isAuthenticated, isFalse);
        expect(find.byKey(const ValueKey('auth-phone-login')), findsNothing);
        expect(
          find.byKey(const ValueKey('auth-wechat')).hitTestable(),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('auth-douyin')).hitTestable(),
          findsOneWidget,
        );
        final overlay = tester
            .widgetList<AnnotatedRegion<SystemUiOverlayStyle>>(
              find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
            )
            .where(
              (widget) =>
                  widget.value.systemNavigationBarColor ==
                  context.colors.canvas,
            );
        expect(overlay, isNotEmpty);
        expect(
          overlay.first.value.systemNavigationBarIconBrightness,
          brightness == Brightness.dark ? Brightness.light : Brightness.dark,
        );
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Open confirmation follows the system and keeps the account and selected tab',
    (tester) async {
      final api = FakeGateway();
      final store = await testStore(
        authenticated: true,
        seeded: true,
        api: api,
      );
      await tester.pumpWidget(MyApp(startupAdsEnabled: false, store: store));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('nav-3')));
      await tester.pumpAndSettle();
      final shell = tester.state<AppShellState>(find.byType(AppShell));
      final signOut = find.byKey(const ValueKey('account-sign-out'));
      await tester.tap(find.byKey(const ValueKey('profile-menu')));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        signOut,
        250,
        scrollable: find.descendant(
          of: find.byKey(const ValueKey('profile-drawer')),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(signOut);
      await tester.pumpAndSettle();
      final requests = List<String>.of(api.calls);
      for (final brightness in [Brightness.dark, Brightness.light]) {
        await changeAppearance(tester, brightness);
        final dialog = tester.element(find.byType(CupertinoAlertDialog));
        expect(CupertinoTheme.brightnessOf(dialog), brightness);
        expect(Theme.of(dialog).brightness, brightness);
        expect(store.isAuthenticated, isTrue);
        expect(shell.selected, 3);
        expect(api.calls, requests);
      }
      await tester.tap(find.text('我再看看'));
      await tester.pumpAndSettle();
      expect(tester.state<AppShellState>(find.byType(AppShell)), same(shell));
      expect(store.isAuthenticated, isTrue);
      expect(api.calls, isNot(contains('PostAuthLogout')));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'A dark system starts directly in the dark theme and colors visited tabs',
    (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      final store = await testStore(authenticated: true, seeded: true);
      await tester.pumpWidget(MyApp(startupAdsEnabled: false, store: store));
      await tester.pumpAndSettle();
      for (var index = 0; index < 4; index++) {
        await tester.tap(find.byKey(ValueKey('nav-$index')));
        await tester.pumpAndSettle();
        final context = tester.element(find.byKey(ValueKey('nav-$index')));
        expect(Theme.of(context).brightness, Brightness.dark);
        final navMaterial = tester.widget<Material>(
          find
              .ancestor(
                of: find.byKey(ValueKey('nav-$index')),
                matching: find.byType(Material),
              )
              .first,
        );
        expect(navMaterial.color, AppColors.dark.surface);
        expect(tester.takeException(), isNull);
      }
    },
  );
}
