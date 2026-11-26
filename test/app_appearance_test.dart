import 'dart:async';

import 'package:bojian_mobile/app_appearance.dart';
import 'package:bojian_mobile/app_theme.dart';
import 'package:bojian_mobile/customer_service_page.dart';
import 'package:bojian_mobile/main.dart';
import 'package:bojian_mobile/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';
import 'support/profile_navigation_helpers.dart';

class _DelayedStorage extends MemoryStorage {
  final started = Completer<void>();
  final finish = Completer<void>();

  @override
  Future<void> write(String key, String? value) async {
    started.complete();
    await finish.future;
    await super.write(key, value);
  }
}

void main() {
  test('切色立即可见，保存失败时恢复上次成功保存的外观', () async {
    final storage = _DelayedStorage();
    final appearance = AppAppearance(storage);
    addTearDown(appearance.dispose);
    final pending = appearance.update(accent: AppAccent.warm);
    final failed = expectLater(pending, throwsStateError);
    await storage.started.future;
    expect(appearance.value.accent, AppAccent.warm);
    storage.finish.completeError(StateError('保存失败'));
    await failed;
    expect(appearance.value.accent, AppAccent.blue);
  });

  test('Concurrent changes persist both choices and unknown values fall back independently', () async {
    final storage = MemoryStorage();
    await storage.write(
      'bojian.appearance',
      '{"accent":"warm","mode":"obsolete"}',
    );
    final preferences = AppAppearance(storage);
    addTearDown(preferences.dispose);
    await preferences.restore();
    expect(preferences.value, (accent: AppAccent.warm, mode: ThemeMode.system));
    await Future.wait([
      preferences.update(mode: ThemeMode.dark),
      preferences.update(accent: AppAccent.blue),
    ]);
    final restored = AppAppearance(storage);
    addTearDown(restored.dispose);
    await restored.restore();
    expect(restored.value, (accent: AppAccent.blue, mode: ThemeMode.dark));
  });

  testWidgets(
    'App startup restores the saved warm palette and manual dark mode',
    (tester) async {
      final store = await testStore();
      await store.storage.write(
        'bojian.appearance',
        '{"accent":"warm","mode":"dark"}',
      );
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await tester.pumpWidget(
        MyApp(
          store: store,
          startupAnimationEnabled: false,
          bannerAdsEnabled: false,
        ),
      );
      await tester.pumpAndSettle();
      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.themeMode, ThemeMode.dark);
      expect(app.darkTheme!.extension<AppColors>()!.palette, AppAccent.warm);
      expect(
        Theme.of(tester.element(find.byType(Navigator))).brightness,
        Brightness.dark,
      );
    },
  );

  testWidgets(
    'Settings apply immediately, persist and follow the device when requested',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final platform = tester.platformDispatcher;
      platform.platformBrightnessTestValue = Brightness.light;
      addTearDown(platform.clearPlatformBrightnessTestValue);
      final store = await testStore(authenticated: true);
      await tester.pumpWidget(
        MyApp(
          store: store,
          startupAnimationEnabled: false,
          bannerAdsEnabled: false,
        ),
      );
      await tester.pumpAndSettle();
      await openMyPage(tester);
      await tester.tap(find.byKey(const ValueKey('profile-settings')));
      await tester.pumpAndSettle();

      BuildContext settings() => tester.element(find.byType(SettingsPage));
      Future<void> choose(String entry, String option) async {
        final row = find.text(entry);
        await tester.ensureVisible(row);
        await tester.tap(row);
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(ListTile, option));
        await tester.pumpAndSettle();
      }

      expect(find.text('跟随系统'), findsOneWidget);
      expect(settings().colors.palette, AppAccent.blue);
      await choose('主题色', '珊瑚暖色');
      expect(settings().colors.palette, AppAccent.warm);
      await choose('主题色', '青竹绿');
      expect(settings().colors.palette, AppAccent.green);
      expect(settings().colors.accent, AppAccent.green.seed);
      await choose('主题色', '珊瑚暖色');
      expect(settings().colors.palette, AppAccent.warm);
      await choose('外观模式', '深色');
      expect(settings().isDark, isTrue);
      await choose('外观模式', '浅色');
      platform.platformBrightnessTestValue = Brightness.dark;
      await tester.pumpAndSettle();
      expect(settings().isDark, isFalse);
      await choose('外观模式', '跟随系统');
      expect(settings().isDark, isTrue);
      platform.platformBrightnessTestValue = Brightness.light;
      await tester.pumpAndSettle();
      expect(settings().isDark, isFalse);
      final restored = AppAppearance(store.storage);
      addTearDown(restored.dispose);
      await restored.restore();
      expect(restored.value, (accent: AppAccent.warm, mode: ThemeMode.system));

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tapDiscoveryMenuItem(tester, 'discovery-service');
      await tester.pumpAndSettle();
      expect(
        tester.element(find.byType(CustomerServicePage)).colors.palette,
        AppAccent.warm,
      );
      final backgrounds = tester
          .widgetList<DecoratedBox>(
            find.ancestor(
              of: find.text('发起新服务'),
              matching: find.byType(DecoratedBox),
            ),
          )
          .map((w) => w.decoration)
          .whereType<BoxDecoration>();
      expect(
        backgrounds.any(
          (d) =>
              d.gradient is LinearGradient &&
              d.gradient!.colors.every((c) => c.r > c.b),
        ),
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
