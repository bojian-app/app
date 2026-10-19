import 'dart:io';
import 'dart:ui' as ui;

import 'package:bojian_mobile/account_pages.dart';
import 'package:bojian_mobile/app_icons.dart';
import 'package:bojian_mobile/app_store.dart';
import 'package:bojian_mobile/design.dart';
import 'package:bojian_mobile/profile_identity.dart';
import 'package:bojian_mobile/resume_native_export.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

const description = '记录工作里的发现，也分享每一次认真尝试。喜欢把复杂的事情理清楚，让每一份经历都能被更好地看见。';
const boundary = ValueKey('profile-about-reference-preview');

Future<AppStore> mount(
  WidgetTester tester,
  FakeGateway api, {
  Size size = const Size(390, 844),
  bool dark = false,
  double scale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(top: 24);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPadding);
  final store = await testStore(authenticated: true, api: api);
  addTearDown(store.dispose);
  await tester.pumpWidget(
    RepaintBoundary(
      key: boundary,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: (dark ? appDarkTheme : appTheme).copyWith(
          textTheme: (dark ? appDarkTheme : appTheme).textTheme.apply(
            fontFamily: 'ProfileAboutPreview',
          ),
          textButtonTheme: TextButtonThemeData(
            style: (dark ? appDarkTheme : appTheme).textButtonTheme.style
                ?.copyWith(
                  textStyle: const WidgetStatePropertyAll(
                    TextStyle(fontFamily: 'ProfileAboutPreview', fontSize: 13),
                  ),
                ),
          ),
        ),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Scaffold(body: ProfilePage(store: store)),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return store;
}

FakeGateway gateway({String bio = description}) =>
    FakeGateway()
      ..documents['GetMe']!.addAll({
        'nickname': '认真生活的开发者',
        'public_id': '123456',
        'bio': bio,
        'created_at': '2026-10-15T12:34:56Z',
        // city is derived from the network IP by the authenticated API.
        'city': '浙江省',
      });

Future<void> capture(WidgetTester tester, String name) async {
  final repaint = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(boundary),
  );
  await tester.runAsync(() async {
    final image = await repaint.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final output = Directory(
      'artifacts/verification/account-polish-20261018/previews',
    );
    await output.create(recursive: true);
    await File('${output.path}/$name.png')
        .writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUpAll(() async {
    await (FontLoader(
      'ProfileAboutPreview',
    )..addFont(rootBundle.load(resumeFontRegularAsset))).load();
  });

  test('Registration time comes from GetMe and is cleared when absent or signed out', () async {
    final api = gateway();
    final store = await testStore(authenticated: true, api: api);
    addTearDown(store.dispose);
    expect(store.registeredAt, DateTime.utc(2026, 10, 15, 12, 34, 56));
    api.documents['GetMe']!['created_at'] = 'invalid';
    await store.load('profile');
    expect(store.registeredAt, isNull);
    api.documents['GetMe']!['created_at'] = '2026-10-15T12:34:56Z';
    await store.load('profile');
    expect(store.registeredAt, isNotNull);
    await store.endSession(remote: false);
    expect(store.registeredAt, isNull);
  });

  for (final config in [
    (name: 'light', size: const Size(390, 844), dark: false, scale: 1.0),
    (name: 'dark-large', size: const Size(320, 640), dark: true, scale: 2.0),
    (name: 'landscape', size: const Size(844, 360), dark: false, scale: 2.0),
  ]) {
    testWidgets(
      'Profile summary and expanded details follow the reference (${config.name})',
      (tester) async {
        final api = gateway();
        final store = await mount(
          tester,
          api,
          size: config.size,
          dark: config.dark,
          scale: config.scale,
        );
        final header = find.byKey(const ValueKey('profile-header'));
        final name = find.byKey(const ValueKey('profile-identity-name'));
        final id = find.byKey(const ValueKey('profile-account-summary'));
        final about = find.byKey(const ValueKey('profile-about-summary'));
        expect(tester.getTopLeft(name).dx, 16);
        expect(tester.getTopLeft(id).dx, 16);
        expect(tester.getTopLeft(about).dx, 16);
        expect(
          tester
              .getCenter(find.byKey(const ValueKey('profile-identity-avatar')))
              .dx,
          tester.getCenter(header).dx,
        );
        final summary = tester.widget<Text>(
          find.byKey(const ValueKey('profile-about-text')),
        );
        expect(summary.semanticsLabel, contains('关于我'));
        expect(summary.maxLines, 3);
        final actionLabel = find.descendant(
          of: about,
          matching: find.text('关于我'),
        );
        final actionIcon = find.descendant(
          of: about,
          matching: find.byType(AppIcon),
        );
        expect(tester.takeException(), isNull);
        if (config.name == 'light') {
          await capture(tester, 'profile-header-light');
        }
        await Scrollable.ensureVisible(tester.element(about), alignment: .5);
        await tester.pumpAndSettle();
        expect(
          tester.getCenter(actionIcon).dy,
          closeTo(tester.getCenter(actionLabel).dy, 1),
        );
        if (config.name != 'light') {
          await capture(tester, 'profile-header-${config.name}');
        }
        api.calls.clear();
        await tester.tap(about);
        await tester.pumpAndSettle();
        expect(find.byType(ProfileDetailsPage), findsOneWidget);
        expect(api.calls, isNot(contains('GetMe')));
        expect(find.text('注册时间：2026年10月15日'), findsOneWidget);
        expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('profile-details-bio')))
              .data,
          store.bio,
        );
        expect(find.text('IP属地：浙江省'), findsOneWidget);
        final fullName = find.byKey(const ValueKey('profile-details-name'));
        final avatar = find.byKey(const ValueKey('profile-details-avatar'));
        expect(
          tester.getTopRight(fullName).dx,
          lessThan(tester.getTopLeft(avatar).dx),
        );
        expect(tester.getTopLeft(avatar).dy, tester.getTopLeft(fullName).dy);
        expect(tester.takeException(), isNull);
        await capture(tester, 'profile-details-${config.name}');
        if (config.name != 'light') {
          final fullBio = find.byKey(const ValueKey('profile-details-bio'));
          await Scrollable.ensureVisible(
            tester.element(fullBio),
            alignment: .5,
          );
          await tester.pumpAndSettle();
          expect(fullBio.hitTestable(), findsOneWidget);
          expect(tester.takeException(), isNull);
          await capture(tester, 'profile-details-${config.name}-scrolled');
        }
        await tester.tap(find.byKey(const ValueKey('profile-details-close')));
        await tester.pumpAndSettle();
        expect(find.byType(ProfileDetailsPage), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'A very long biography leaves its inline About me action visible and opens the full text',
    (tester) async {
      final longBio = List.filled(10, '专注做好手头的事情，认真记录生活与工作。🌿').join();
      await mount(tester, gateway(bio: longBio));
      final about = find.byKey(const ValueKey('profile-about-summary'));
      final summary = tester.widget<Text>(
        find.byKey(const ValueKey('profile-about-text')),
      );
      expect(summary.textSpan!.toPlainText(), contains('...  '));
      final icon = find.descendant(of: about, matching: find.byType(AppIcon));
      final summaryRect = tester.getRect(about);
      expect(
        tester.getTopRight(icon).dx,
        lessThanOrEqualTo(summaryRect.left + summaryRect.width * .8 + 1),
      );
      expect(tester.getCenter(icon).dy, greaterThan(summaryRect.top + 39));
      expect(
        tester.getBottomRight(icon).dy,
        lessThanOrEqualTo(tester.getBottomRight(about).dy + 1),
      );
      await tester.tap(icon);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('profile-details-bio')))
            .data,
        longBio,
      );
      await tester.drag(
        find.byType(SingleChildScrollView).last,
        const Offset(0, -500),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Empty biographies and missing registration dates do not create fictitious content',
    (tester) async {
      final api = gateway(bio: '')
        ..documents['GetMe']!.remove('created_at')
        ..documents['GetMe']!.remove('city');
      await mount(tester, api);
      await tester.tap(find.byKey(const ValueKey('profile-about-summary')));
      await tester.pumpAndSettle();
      expect(find.byType(ProfileDetailsPage), findsOneWidget);
      expect(
        find.byKey(const ValueKey('profile-registration-date')),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('profile-details-bio')), findsNothing);
      expect(find.textContaining('IP'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
