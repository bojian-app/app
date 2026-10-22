import 'dart:io';
import 'dart:ui' as ui;

import 'package:bojian_mobile/account_pages.dart';
import 'package:bojian_mobile/app_store.dart';
import 'package:bojian_mobile/app_icons.dart';
import 'package:bojian_mobile/design.dart';
import 'package:bojian_mobile/main.dart';
import 'package:bojian_mobile/profile_identity.dart';
import 'package:bojian_mobile/resume_native_export.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

const bio = '个人介绍内容。个人介绍内容。个人介绍内容。';
const surface = ValueKey('profile-pull-preview');

Future<AppStore> mount(
  WidgetTester tester,
  FakeGateway api, {
  Size size = const Size(390, 844),
  double textScale = 1,
  bool dark = false,
  bool reduced = false,
  bool realApp = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(top: 24);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPadding);
  final store = await testStore(authenticated: true, api: api);
  if (!realApp) addTearDown(store.dispose);
  await tester.pumpWidget(
    RepaintBoundary(
      key: surface,
      child: realApp
          ? MyApp(startupAdsEnabled: false, store: store)
          : MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: (dark ? appDarkTheme : appTheme).copyWith(
                textTheme: (dark ? appDarkTheme : appTheme).textTheme.apply(
                  fontFamily: 'ProfilePullPreview',
                ),
                textButtonTheme: TextButtonThemeData(
                  style: (dark ? appDarkTheme : appTheme).textButtonTheme.style!
                      .copyWith(
                        textStyle: const WidgetStatePropertyAll(
                          TextStyle(
                            fontFamily: 'ProfilePullPreview',
                            fontSize: 13,
                          ),
                        ),
                      ),
                ),
              ),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(textScale),
                  disableAnimations: reduced,
                ),
                child: child!,
              ),
              home: Scaffold(body: ProfilePage(store: store)),
            ),
    ),
  );
  await tester.pumpAndSettle();
  if (realApp) {
    await tester.tap(find.byKey(const ValueKey('nav-3')));
    await tester.pumpAndSettle();
  }
  api.calls.clear();
  return store;
}

FakeGateway gateway({String description = bio}) =>
    FakeGateway()
      ..documents['GetMe']!.addAll({'bio': description, 'city': '广东省'});

Future<TestGesture> beginPull(WidgetTester tester, double amount) async {
  final list = find.byKey(const ValueKey('profile-scroll'));
  final gesture = await tester.startGesture(
    tester.getTopLeft(list) + const Offset(100, 150),
  );
  for (var i = 0; i < 4; i++) {
    await gesture.moveBy(Offset(0, amount / 4));
    await tester.pump(const Duration(milliseconds: 40));
  }
  return gesture;
}

Future<void> pull(WidgetTester tester, double amount) async {
  final gesture = await beginPull(tester, amount);
  await gesture.up();
  await tester.pumpAndSettle();
  // The list refresh can finish its minimum launch duration behind the details route.
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
}

ScrollPosition position(WidgetTester tester) => tester
    .state<NestedScrollViewState>(find.byKey(const ValueKey('profile-scroll')))
    .outerController
    .position;

Future<ui.Image> render(WidgetTester tester) => tester
    .runAsync(
      () => tester
          .renderObject<RenderRepaintBoundary>(find.byKey(surface))
          .toImage(pixelRatio: 2),
    )
    .then((image) => image!);

Future<void> capture(WidgetTester tester, String name) async {
  final image = await render(tester);
  await tester.runAsync(() async {
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory('build/previews').create(recursive: true);
    await File('build/previews/$name.png')
        .writeAsBytes(bytes!.buffer.asUint8List());
  });
  image.dispose();
}

void main() {
  setUpAll(() async {
    await (FontLoader(
      'ProfilePullPreview',
    )..addFont(rootBundle.load(resumeFontRegularAsset))).load();
  });

  testWidgets('Only expanded details retain the public ID copy action', (
    tester,
  ) async {
    const id = 'BJSMYMHGDPKOMN';
    final api = gateway()..documents['GetMe']!['public_id'] = id;
    final copied = <String>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied.add((call.arguments as Map)['text'] as String);
      }
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    await mount(tester, api);
    expect(copied, isEmpty);
    expect(find.byTooltip('复制用户 ID'), findsNothing);
    await pull(tester, 220);
    expect(find.byType(ProfileDetailsPage), findsOneWidget);
    expect(copied, isEmpty);
    await tester.tap(find.byTooltip('复制用户 ID'));
    await tester.pumpAndSettle();
    expect(copied, [id]);
    expect(
      api.calls.where(
        (call) => call.startsWith('Post') || call.startsWith('Patch'),
      ),
      isEmpty,
    );
    expect(tester.takeException(), isNull);
  });

  for (final config in [
    (
      name: 'light',
      size: const Size(390, 640),
      scale: 1.0,
      dark: false,
      app: false,
    ),
    (
      name: 'dark',
      size: const Size(390, 640),
      scale: 1.0,
      dark: true,
      app: false,
    ),
    (
      name: 'large',
      size: const Size(320, 600),
      scale: 2.0,
      dark: true,
      app: false,
    ),
    (
      name: 'landscape',
      size: const Size(844, 360),
      scale: 2.0,
      dark: false,
      app: false,
    ),
    (
      name: 'safe-area',
      size: const Size(390, 640),
      scale: 1.0,
      dark: false,
      app: true,
    ),
  ]) {
    testWidgets(
      'Profile identity morphs continuously while scrolling (${config.name})',
      (tester) async {
        final api = gateway();
        final store = await mount(
          tester,
          api,
          size: config.size,
          textScale: config.scale,
          dark: config.dark,
          realApp: config.app,
        );
        final list = find.byKey(const ValueKey('profile-scroll'));
        final name = find.byKey(const ValueKey('profile-identity-name'));
        final compact = find.byKey(const ValueKey('profile-compact-header'));
        final start =
            tester.getTopLeft(name).dy -
            tester.getTopLeft(list).dy -
            MediaQuery.paddingOf(tester.element(list)).top;
        final scrolling = position(tester);
        expect(scrolling.maxScrollExtent, greaterThan(start + 1));
        expect(compact, findsNothing);
        final avatar = find.byKey(const ValueKey('profile-identity-avatar'));
        final menu = find.byKey(const ValueKey('profile-menu'));
        final shared = [
          avatar,
          name,
          menu,
          find.byKey(const ValueKey('profile-edit')),
          find.byKey(const ValueKey('profile-messages')),
        ];
        final elements = shared.map(tester.element).toList();
        final menuRect = tester.getRect(menu);
        var previousAvatar = tester.getRect(avatar);
        for (final fraction in [.25, .5, .75, 1.0]) {
          scrolling.jumpTo(start * fraction);
          await tester.pumpAndSettle();
          expect(compact, findsOneWidget);
          for (var i = 0; i < shared.length; i++) {
            expect(tester.element(shared[i]), same(elements[i]));
          }
          final actual = tester.getRect(avatar);
          expect(actual.width, lessThanOrEqualTo(previousAvatar.width));
          expect(actual.center.dx, lessThanOrEqualTo(previousAvatar.center.dx));
          expect(actual.center.dy, lessThanOrEqualTo(previousAvatar.center.dy));
          expect(tester.getRect(menu), menuRect);
          expect(
            tester.getSize(
              find.descendant(of: menu, matching: find.byType(AppIcon)),
            ),
            const Size.square(20),
          );
          previousAvatar = actual;
          if (config.name == 'light') {
            await capture(tester, 'profile-scroll-${(fraction * 100).round()}');
          }
        }
        expect(previousAvatar.width, closeTo(44, .01));
        expect(previousAvatar.center.dx, closeTo(74, .01));
        if (config.name == 'light') {
          store.loading.add('profile');
          store.changed();
          await tester.pump();
          expect(find.byType(CircularProgressIndicator), findsNothing);
          store.loading.remove('profile');
          store.changed();
          await tester.pump();
        }
        scrolling.jumpTo(start + 1);
        await tester.pumpAndSettle();
        store.name = '一个非常长的个人昵称用于验证顶部栏不会挤出屏幕';
        store.changed();
        await tester.pumpAndSettle();
        final label = tester.widget<Text>(
          find.byKey(const ValueKey('profile-identity-name')),
        );
        expect(label.data, store.name);
        expect(label.maxLines, 1);
        expect(label.overflow, TextOverflow.ellipsis);
        expect(scrolling.pixels, closeTo(start + 1, .001));
        if (!config.app) {
          await capture(tester, 'profile-compact-${config.name}');
        }
        if (config.name == 'light') {
          tester.view.physicalSize = const Size(320, 600);
          await tester.pumpAndSettle();
          expect(compact, findsOneWidget);
          expect(scrolling.pixels, closeTo(start + 1, .001));
        }
        await tester.tap(find.byKey(const ValueKey('profile-edit')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('profile-edit-actions')),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const ValueKey('profile-edit-cancel')));
        await tester.pumpAndSettle();
        expect(scrolling.pixels, closeTo(start + 1, .001));
        scrolling.jumpTo(0);
        await tester.pumpAndSettle();
        expect(compact, findsNothing);
        await pull(tester, 220);
        expect(find.byType(ProfileDetailsPage), findsOneWidget);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(compact, findsNothing);
        expect(
          api.calls.where(
            (call) => call.startsWith('Patch') || call.startsWith('Post'),
          ),
          isEmpty,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'Details grow continuously from the pulled header and shrink back',
    (tester) async {
      await mount(tester, gateway());
      final handle = find.byKey(const ValueKey('profile-drag-handle'));
      final edge = find.byKey(const ValueKey('profile-curved-edge'));
      expect(handle, findsOneWidget);
      expect(tester.getSize(handle), const Size(44, 4));
      expect(tester.getCenter(handle).dx, tester.getCenter(edge).dx);
      final gesture = await beginPull(tester, 220);
      final start = tester.getRect(
        find.byKey(const ValueKey('profile-header')),
      );
      final startAvatar = tester.getRect(
        find.byKey(const ValueKey('profile-identity-avatar')),
      );
      await gesture.up();
      await tester.pump();
      await tester.pump();
      final region = find.byKey(const ValueKey('profile-expansion-region'));
      for (var i = 0; i < 20 && region.evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(tester.getRect(region).height, closeTo(start.height, 3));
      await tester.pump(const Duration(milliseconds: 140));
      final middle = tester.getRect(region);
      expect(middle.height, greaterThan(start.height));
      expect(middle.height, lessThan(844));
      final flyingAvatar = tester.getRect(
        find.byKey(const ValueKey('profile-avatar-flight')),
      );
      expect(flyingAvatar.center.dx, greaterThan(startAvatar.center.dx));
      expect(flyingAvatar.width, lessThan(startAvatar.width));
      expect(find.byKey(const ValueKey('profile-details-name')), findsNothing);
      await capture(tester, 'profile-expansion-middle');
      await tester.pumpAndSettle();
      final finalAvatar = tester.getRect(
        find.byKey(const ValueKey('profile-details-avatar')),
      );
      expect(finalAvatar.center.dx, greaterThan(flyingAvatar.center.dx));
      expect(finalAvatar.width, lessThan(flyingAvatar.width));
      expect(find.text('IP属地：广东省'), findsOneWidget);
      expect(tester.getRect(region).height, 844);
      await tester.tap(find.byKey(const ValueKey('profile-details-close')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 140));
      expect(tester.getRect(region).height, lessThan(844));
      expect(tester.getRect(region).height, greaterThan(start.height));
      final returningAvatar = tester.getRect(
        find.byKey(const ValueKey('profile-avatar-flight')),
      );
      expect(returningAvatar.width, greaterThan(finalAvatar.width));
      expect(returningAvatar.width, lessThan(startAvatar.width));
      await tester.pumpAndSettle();
      expect(find.byType(ProfileDetailsPage), findsNothing);
      expect(handle, findsOneWidget);
      expect(position(tester).pixels, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Pulled details return to the actual resting header without a jump',
    (tester) async {
      await mount(tester, gateway(), realApp: true);
      final source = find.descendant(
        of: find.byType(ProfilePage, skipOffstage: false),
        matching: find.byKey(
          const ValueKey('profile-header'),
          skipOffstage: false,
        ),
      );
      final resting = tester.getRect(source);
      final gesture = await beginPull(tester, 220);
      expect(tester.getRect(source).height, greaterThan(resting.height + 30));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.text('IP属地：广东省'), findsOneWidget);
      expect(tester.getRect(source).height, closeTo(resting.height, .1));
      await tester.tap(find.byKey(const ValueKey('profile-details-close')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 316));
      final returning = tester.getRect(
        find.byKey(const ValueKey('profile-expansion-region')),
      );
      expect(returning.bottom, closeTo(tester.getRect(source).bottom, 2));
      await tester.pumpAndSettle();
      expect(tester.getRect(source).height, closeTo(resting.height, .1));
      expect(tester.takeException(), isNull);
    },
  );

  for (final scenario in ['resting', 'scrolled', 'pulled', 'app']) {
    testWidgets(
      'Photo crop and brightness stay continuous through $scenario details',
      (tester) async {
        await mount(tester, gateway(), realApp: scenario == 'app');
        if (scenario == 'scrolled') {
          position(tester).jumpTo(60);
          await tester.pumpAndSettle();
        }
        final gesture = scenario == 'pulled'
            ? await beginPull(tester, 220)
            : null;
        final header = tester.getRect(
          find.byKey(const ValueKey('profile-header')),
        );
        // Sample the exposed margin, away from text, controls and Hero flights.
        Future<List<int>> stripe(double top) async {
          final image = await render(tester);
          final bytes = await tester.runAsync(
            () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
          );
          final values = <int>[];
          for (var y = 100; y <= header.height - 40 && y <= 260; y += 20) {
            for (final x in [2, 5, 8]) {
              final pixel = (((top + y) * 2).round() * image.width + x * 2) * 4;
              values.addAll(
                List.generate(3, (c) => bytes!.getUint8(pixel + c)),
              );
            }
          }
          image.dispose();
          return values;
        }

        final before = await stripe(header.top);
        final backdrop = tester.renderObject<RenderRepaintBoundary>(
          find
              .descendant(
                of: find.byType(ProfileBackdrop).first,
                matching: find.byType(RepaintBoundary),
              )
              .first,
        );
        final photo = (await tester.runAsync(
          () => backdrop.toImage(pixelRatio: 2),
        ))!;
        final photoBytes = (await tester.runAsync(
          () => photo.toByteData(format: ui.ImageByteFormat.rawRgba),
        ))!;
        final untinted = <int>[];
        for (var y = 100; y <= header.height - 40 && y <= 260; y += 20) {
          for (final x in [2, 5, 8]) {
            final pixel = (y * 2 * photo.width + x * 2) * 4;
            untinted.addAll(
              List.generate(3, (c) => photoBytes.getUint8(pixel + c)),
            );
          }
        }
        photo.dispose();
        if (gesture != null) {
          await gesture.up();
        } else {
          await tester.tap(find.byKey(const ValueKey('profile-about-summary')));
        }
        await tester.pump();
        final region = find.byKey(const ValueKey('profile-expansion-region'));
        for (var i = 0; i < 20 && region.evaluate().isEmpty; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        Future<void> expectSameBackdrop(String phase) async {
          final actual = await stripe(tester.getRect(region).top);
          final page = tester.widget<ProfileDetailsPage>(
            find.byType(ProfileDetailsPage),
          );
          final progress = Curves.easeInOutCubic.transform(
            page.expansion.value,
          );
          for (var i = 0; i < before.length; i++) {
            final expected = before[i] + (untinted[i] - before[i]) * progress;
            expect(
              (actual[i] - expected.round()).abs(),
              lessThanOrEqualTo(2),
              reason: '$scenario $phase: photo crop/gradient changed at $i',
            );
          }
        }

        await expectSameBackdrop('first frame');
        await tester.pump(const Duration(milliseconds: 150));
        await expectSameBackdrop('expanding');
        await tester.pumpAndSettle();
        expect(find.text('IP属地：广东省'), findsOneWidget);
        await expectSameBackdrop('expanded');
        await tester.tap(find.byKey(const ValueKey('profile-details-close')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 150));
        await expectSameBackdrop('collapsing');
        await tester.pumpAndSettle();
        final after = await stripe(
          tester.getRect(find.byKey(const ValueKey('profile-header'))).top,
        );
        for (var i = 0; i < before.length; i++) {
          expect((after[i] - before[i]).abs(), lessThanOrEqualTo(2));
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'A deep pull reveals real details once; close and back preserve the profile',
    (tester) async {
      final api = gateway();
      final store = await mount(tester, api);
      final original = tester.getRect(
        find.byKey(const ValueKey('profile-curved-edge')),
      );
      final gesture = await beginPull(tester, 220);
      expect(find.byType(ProfileDetailsPage), findsNothing);
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('profile-curved-edge'))).dy,
        greaterThan(original.top),
      );
      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.byType(ProfileDetailsPage), findsOneWidget);
      expect(find.text(store.name), findsOneWidget);
      expect(find.text('用户 ID：${store.publicID}'), findsOneWidget);
      expect(find.text(bio), findsOneWidget);
      expect(api.calls.where((call) => call == 'GetMe'), hasLength(1));
      expect(
        api.calls.where(
          (call) => call.startsWith('Post') || call.startsWith('Patch'),
        ),
        isEmpty,
      );
      await capture(tester, 'profile-pull-details');
      await tester.tap(find.byKey(const ValueKey('profile-details-close')));
      await tester.pumpAndSettle();
      expect(find.byType(ProfileDetailsPage), findsNothing);
      expect(position(tester).pixels, 0);
      expect(
        tester.getRect(find.byKey(const ValueKey('profile-curved-edge'))),
        original,
      );
      await pull(tester, 220);
      expect(find.byType(ProfileDetailsPage), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(ProfileDetailsPage), findsNothing);
      expect(position(tester).pixels, 0);
      expect(tester.takeException(), isNull);
    },
  );

  for (final scenario in ['tiny', 'refresh', 'reverse', 'cancel', 'scrolled']) {
    testWidgets('Pull boundaries keep normal behavior ($scenario)', (
      tester,
    ) async {
      final api = gateway();
      await mount(tester, api);
      if (scenario == 'scrolled') {
        position(tester).jumpTo(140);
        await tester.pumpAndSettle();
      }
      final gesture = await beginPull(tester, switch (scenario) {
        'tiny' => 35,
        'refresh' => 90,
        _ => 220,
      });
      if (scenario == 'reverse') {
        await gesture.moveBy(const Offset(0, -210));
        await tester.pump();
      }
      if (scenario == 'cancel') {
        await gesture.cancel();
      } else {
        await gesture.up();
      }
      await tester.pumpAndSettle();
      expect(find.byType(ProfileDetailsPage), findsNothing);
      expect(
        api.calls.where((call) => call == 'GetMe'),
        hasLength(scenario == 'refresh' ? 1 : 0),
      );
      expect(tester.takeException(), isNull);
    });
  }

  for (final dark in [false, true]) {
    testWidgets(
      'Rounded corners reveal one continuous photo background (dark=$dark)',
      (tester) async {
        await mount(tester, gateway(), dark: dark);
        final edge = tester.getRect(
          find.byKey(const ValueKey('profile-curved-edge')),
        );
        final image = await render(tester);
        final bytes = await tester.runAsync(
          () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
        );
        int channel(int x, int y, int c) =>
            bytes!.getUint8((y * image.width + x) * 4 + c);
        final top = (edge.top * 2).round();
        for (final x in [1, image.width - 2]) {
          for (var c = 0; c < 3; c++) {
            expect(
              (channel(x, top - 2, c) - channel(x, top + 2, c)).abs(),
              lessThan(12),
            );
          }
        }
        image.dispose();
        await capture(tester, 'profile-corners-${dark ? 'dark' : 'light'}');
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'A failed short refresh can retry without losing the stored profile',
    (tester) async {
      final api = gateway();
      final store = await mount(tester, api);
      api.failing = 'GetMe';
      await pull(tester, 90);
      expect(store.errors['profile'], isNotNull);
      expect(find.text(store.name), findsOneWidget);
      expect(find.byType(ProfileDetailsPage), findsNothing);
      api.failing = null;
      await pull(tester, 220);
      expect(store.errors['profile'], isNull);
      expect(find.byType(ProfileDetailsPage), findsOneWidget);
      expect(api.calls.where((call) => call == 'GetMe'), hasLength(2));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Disposing during a deep pull cannot refresh or open a late route',
    (tester) async {
      final api = gateway();
      await mount(tester, api);
      final gesture = await beginPull(tester, 220);
      await tester.pumpWidget(const SizedBox());
      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.byType(ProfileDetailsPage), findsNothing);
      expect(api.calls, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  for (final size in [const Size(320, 640), const Size(844, 360)]) {
    testWidgets(
      'Expanded details scroll with 2x text and reduced motion at $size',
      (tester) async {
        final api = gateway(description: List.filled(12, bio).join('\n'));
        await mount(
          tester,
          api,
          size: size,
          textScale: 2,
          dark: true,
          reduced: true,
        );
        await pull(tester, 220);
        expect(find.byType(ProfileDetailsPage), findsOneWidget);
        final route = ModalRoute.of(
          tester.element(find.byType(ProfileDetailsPage)),
        )!;
        expect(route.transitionDuration, Duration.zero);
        expect(
          find.text(api.documents['GetMe']!['bio'] as String),
          findsOneWidget,
        );
        await tester.drag(
          find.byType(SingleChildScrollView),
          const Offset(0, -300),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('profile-details-close')).hitTestable(),
          findsOneWidget,
        );
        await capture(
          tester,
          'profile-details-${size.width == 320 ? 'small' : 'landscape'}',
        );
        await tester.tap(find.byKey(const ValueKey('profile-details-close')));
        await tester.pumpAndSettle();
        expect(find.byType(ProfileDetailsPage), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'Editing from expanded details updates both views and keeps the return path',
    (tester) async {
      final api = gateway();
      final store = await mount(tester, api);
      await pull(tester, 220);
      await tester.tap(find.byKey(const ValueKey('profile-details-edit')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('profile-edit-settings')));
      await tester.pumpAndSettle();
      expect(find.byType(ProfileEditor), findsOneWidget);
      await tester.ensureVisible(find.byKey(const ValueKey('profile-name')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('profile-name')),
        '更新后的昵称',
      );
      await tester.ensureVisible(find.byKey(const ValueKey('profile-save')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('profile-save')));
      await tester.pumpAndSettle();
      expect(find.byType(ProfileDetailsPage), findsOneWidget);
      expect(find.text('更新后的昵称'), findsOneWidget);
      expect(store.name, '更新后的昵称');
      expect(api.calls.where((call) => call == 'PatchMe'), hasLength(1));
      await tester.tap(find.byKey(const ValueKey('profile-details-close')));
      await tester.pumpAndSettle();
      expect(find.text('更新后的昵称'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Signing out closes expanded details without retaining private content',
    (tester) async {
      final api = gateway();
      final store = await mount(tester, api, realApp: true);
      await pull(tester, 220);
      expect(find.byType(ProfileDetailsPage), findsOneWidget);
      await store.endSession(remote: false);
      await tester.pumpAndSettle();
      expect(find.byType(ProfileDetailsPage), findsNothing);
      expect(find.text(bio), findsNothing);
      expect(find.byKey(const ValueKey('auth-wechat')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
