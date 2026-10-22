import 'dart:io';
import 'dart:ui' as ui;

import 'package:bojian_mobile/account_pages.dart';
import 'package:bojian_mobile/design.dart';
import 'package:bojian_mobile/profile_identity.dart';
import 'package:bojian_mobile/resume_native_export.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

void main() {
  setUpAll(() async {
    await (FontLoader(
      'CertificationPreview',
    )..addFont(rootBundle.load(resumeFontRegularAsset))).load();
  });

  test(
    'Crystal silhouette has equal width and height on a transparent canvas',
    () async {
      final data = await rootBundle.load(
        'assets/badges/developer_crystal_v1.png',
      );
      final codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
      addTearDown(codec.dispose);
      final image = (await codec.getNextFrame()).image;
      addTearDown(image.dispose);
      expect(image.width, image.height);
      final pixels = (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;
      var left = image.width, top = image.height, right = -1, bottom = -1;
      for (var y = 0; y < image.height; y++) {
        for (var x = 0; x < image.width; x++) {
          if (pixels.getUint8((y * image.width + x) * 4 + 3) < 128) continue;
          if (x < left) left = x;
          if (x > right) right = x;
          if (y < top) top = y;
          if (y > bottom) bottom = y;
        }
      }
      expect(right, greaterThanOrEqualTo(left));
      expect(left, greaterThan(0));
      expect(top, greaterThan(0));
      expect(right, lessThan(image.width - 1));
      expect(bottom, lessThan(image.height - 1));
      expect((right - left + 1) / (bottom - top + 1), closeTo(1, .02));
    },
  );

  for (final dark in [false, true]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('Certified badge fits the profile, dark=$dark, text=$scale', (
        tester,
      ) async {
        tester.view.physicalSize = Size(scale == 1 ? 390 : 320, 844);
        tester.view.devicePixelRatio = 1;
        tester.view.padding = const FakeViewPadding(top: 24);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPadding);
        final api = FakeGateway()
          ..documents['GetMe']!.addAll({
            'nickname': '认真创造的开发者',
            'public_id': '123456',
            'bio': '把想法变成作品，记录每一次认真创造。',
            'city': '广东省',
          })
          ..documents['GetMeIdentityVerification'] = {
            'status': 'VERIFIED',
            'valid_until': '2099-12-31',
          };
        final store = await testStore(authenticated: true, api: api);
        addTearDown(store.dispose);
        final theme = dark ? appDarkTheme : appTheme;
        const boundary = ValueKey('certification-preview');
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: theme.copyWith(
                textTheme: theme.textTheme.apply(
                  fontFamily: 'CertificationPreview',
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
        final badge = find.byKey(const ValueKey('profile-developer-badge'));
        expect(badge, findsOneWidget);
        await tester.runAsync(
          () => precacheImage(
            const ResizeImage(
              AssetImage('assets/badges/developer_crystal_v1.png'),
              width: 192,
            ),
            tester.element(badge),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<RawImage>(
                find.descendant(of: badge, matching: find.byType(RawImage)),
              )
              .image,
          isNotNull,
        );
        final semantics = tester.ensureSemantics();
        try {
          expect(find.bySemanticsLabel('开发者认证，已通过'), findsOneWidget);
        } finally {
          semantics.dispose();
        }
        final badgeRect = tester.getRect(badge);
        expect(badgeRect.width, closeTo(badgeRect.height, .001));
        expect(badgeRect.left, greaterThanOrEqualTo(16));
        expect(
          badgeRect.right,
          lessThanOrEqualTo(tester.view.physicalSize.width - 16),
        );
        final nameRect = tester.getRect(
          find.byKey(const ValueKey('profile-identity-name')),
        );
        expect(badgeRect.left, greaterThanOrEqualTo(nameRect.right + 4));
        expect(badgeRect.width, closeTo(26 * 2 / 3, .01));
        expect(badgeRect.height, closeTo(26 * 2 / 3, .01));
        expect(find.text('开发者认证'), findsNothing);
        expect(tester.takeException(), isNull);
        if (const bool.fromEnvironment('BADGE_PREVIEW') && scale == 1) {
          final repaint = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(boundary),
          );
          await tester.runAsync(() async {
            final image = await repaint.toImage(pixelRatio: 2);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final dir = Directory(
              'artifacts/verification/developer-certification',
            );
            await dir.create(recursive: true);
            await File('${dir.path}/${dark ? 'dark' : 'light'}.png')
                .writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.tap(find.byKey(const ValueKey('profile-about-summary')));
        await tester.pumpAndSettle();
        expect(find.byType(ProfileDetailsPage), findsOneWidget);
        final detailsBadge = find.bySemanticsLabel('开发者认证，已通过');
        expect(tester.getSize(detailsBadge).width, closeTo(26 * 2 / 3, .01));
        expect(tester.getSize(detailsBadge).height, closeTo(26 * 2 / 3, .01));
        expect(find.text('开发者认证'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.tap(find.byKey(const ValueKey('profile-details-close')));
        await tester.pumpAndSettle();
        final scroll = tester
            .state<NestedScrollViewState>(
              find.byKey(const ValueKey('profile-scroll')),
            )
            .outerController;
        scroll.jumpTo(scroll.position.maxScrollExtent);
        await tester.pumpAndSettle();
        final compact = tester.getRect(
          find.byKey(const ValueKey('profile-developer-badge')),
        );
        expect(compact.width, closeTo(12, .1));
        expect(compact.height, closeTo(12, .1));
        expect(tester.takeException(), isNull);
      });
    }
  }
}
