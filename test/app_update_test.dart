import 'package:bojian_mobile/about_page.dart';
import 'package:bojian_mobile/app_icons.dart';
import 'package:bojian_mobile/app_update.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

void main() {
  final updates = AppUpdates.instance;

  setUp(() {
    final version = updates.installedVersion;
    final build = updates.installedBuild;
    final releases = updates.releases;
    addTearDown(() {
      updates.installedVersion = version;
      updates.installedBuild = build;
      updates.releases = releases;
    });
  });

  void versions(
    String installed,
    int localBuild,
    String published,
    int remoteBuild, {
    String url = 'https://example.com/app.apk',
  }) {
    updates.installedVersion = installed;
    updates.installedBuild = localBuild;
    updates.releases = [
      AppRelease.fromJson({
        'version_name': published,
        'build_number': remoteBuild,
        'download_url': url,
      }),
    ];
  }

  test('higher release wins independently of build number', () {
    versions('1.0.0', 2026111735, '1.1.0', 26111835);
    expect(updates.hasUpdate, isTrue);
    versions('1.1.0', 26111835, '1.0.0', 2026111735);
    expect(updates.hasUpdate, isFalse);
    versions('1.2', 0, '1.10', 0);
    expect(updates.hasUpdate, isTrue);
  });

  test('equivalent releases use real build numbers for hotfixes', () {
    versions('v01.1+local', 20, '1.1.0+999', 19);
    expect(updates.hasUpdate, isFalse);
    versions('1.1.0', 20, 'V1.01+99', 20);
    expect(updates.hasUpdate, isFalse);
    versions('1.1', 20, 'v1.1.0', 21);
    expect(updates.hasUpdate, isTrue);
    versions('1', 0, '1.0', 21);
    expect(updates.hasUpdate, isFalse);
  });

  test('prereleases use identifier order ahead of build numbers', () {
    const ordered = [
      '1.1.0-alpha',
      '1.1-alpha.2',
      '1.1-alpha.10',
      '1.1-alpha.b',
      '1.1-beta',
      '1.1-rc.1',
      '1.1.0',
    ];
    for (var i = 1; i < ordered.length; i++) {
      versions(ordered[i - 1], 300, ordered[i], 100);
      expect(
        updates.hasUpdate,
        isTrue,
        reason: '${ordered[i - 1]} → ${ordered[i]}',
      );
      versions(ordered[i], 100, ordered[i - 1], 300);
      expect(updates.hasUpdate, isFalse);
    }
    versions('1-rc.002', 20, '1.0.0-rc.2+meta', 21);
    expect(updates.hasUpdate, isTrue);
  });

  test(
    'historical labels fall back to build only when both are unparseable',
    () {
      versions('internal', 3, 'public', 4);
      expect(updates.hasUpdate, isTrue);
      versions('internal', 4, 'public', 4);
      expect(updates.hasUpdate, isFalse);
      versions('internal', 1, '1.1.0', 2);
      expect(updates.latestComparison, isNull);
      expect(updates.hasUpdate, isFalse);
      versions('1.1.0', 1, '1.2.0-rc..1', 20);
      expect(updates.latestComparison, isNull);
      expect(updates.hasUpdate, isFalse);
      versions('internal', 0, 'public', 3);
      expect(updates.hasUpdate, isFalse);
    },
  );

  test(
    'a release without a download URL does not trigger a badge or installation',
    () {
      versions('1.0.0', 1, '1.1.0', 2, url: '');
      expect(updates.hasUpdate, isFalse);
      expect(updates.installBlockReason, isNull);
    },
  );

  testWidgets(
    'About reports a published release awaiting download on manual check',
    (tester) async {
      final store = await testStore();
      addTearDown(store.dispose);
      final loaded = updates.loaded;
      addTearDown(() => updates.loaded = loaded);
      updates.loaded = true;
      versions('1.0.0', 2026111735, '1.1.0', 26111835, url: ' ');
      const message = '已发布 v1.1.0，暂未提供下载';
      await tester.pumpWidget(MaterialApp(home: AboutPage(store: store)));
      expect(find.text(message), findsOneWidget);
      expect(find.byType(Badge), findsNothing);
      expect(find.text('立即更新'), findsNothing);
      await tester.tap(find.text('检查更新'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(SnackBar),
          matching: find.text(message),
        ),
        findsOneWidget,
      );
      expect(find.text('已是最新版本'), findsNothing);
    },
  );

  testWidgets('About shows the release notes without being asked', (
    tester,
  ) async {
    final store = await testStore();
    addTearDown(store.dispose);
    updates.releases = [
      AppRelease.fromJson({
        'version_name': '1.2.0',
        'build_number': 2026112795,
        'notes': ['应用名称更新为「Z优简」'],
      }),
    ];
    await tester.pumpWidget(MaterialApp(home: AboutPage(store: store)));
    await tester.pump();
    expect(find.text('更新日志'), findsOneWidget);
    expect(find.text('应用名称更新为「Z优简」'), findsOneWidget);
  });

  for (final (name, scale) in [('1.1.0', 1.0), ('1.1.0-beta.20261128', 2.0)]) {
    testWidgets('A newer version sits with its arrow at the row end ($name)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final store = await testStore();
      addTearDown(store.dispose);
      versions('1.0.0', 1, name, 2);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: AboutPage(store: store),
        ),
      );
      await tester.pump();
      final version = find.text('v$name').first;
      final row = find.ancestor(of: version, matching: find.byType(Row)).first;
      final arrow = tester.getRect(
        find.descendant(of: row, matching: find.byType(AppIcon)),
      );
      expect(arrow.right, tester.getRect(row).right);
      expect(tester.getRect(row).right, 360 - 24);
      expect(tester.getRect(version).right, arrow.left - 8);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'About distinguishes a detected release from an installable package',
    (tester) async {
      final store = await testStore();
      addTearDown(store.dispose);
      versions('1.0.0', 2026111735, 'v1.1.0', 26111835);
      await tester.pumpWidget(MaterialApp(home: AboutPage(store: store)));
      expect(find.text('v1.1.0'), findsOneWidget);
      if (defaultTargetPlatform == TargetPlatform.android) {
        expect(find.text('重新检查更新'), findsOneWidget);
        expect(find.textContaining('无法覆盖安装'), findsOneWidget);
        expect(find.text('立即更新'), findsNothing);
        final installer = AppUpdateInstaller();
        addTearDown(installer.dispose);
        await installer.install(store);
        expect(installer.stage, AppUpdateStage.idle);
        expect(installer.message, isNull);
      } else {
        expect(find.text('立即更新'), findsOneWidget);
        expect(find.textContaining('无法覆盖安装'), findsNothing);
      }
    },
    variant: TargetPlatformVariant.mobile(),
  );
}
