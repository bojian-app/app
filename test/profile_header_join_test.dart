import 'dart:io';
import 'dart:ui' as ui;

import 'package:bojian_mobile/design.dart';
import 'package:bojian_mobile/resume_native_export.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'profile_pull_details_test.dart' as profile;
import 'support/fake_gateway.dart';

void main() {
  setUpAll(() async {
    await (FontLoader(
      'ProfilePullPreview',
    )..addFont(rootBundle.load(resumeFontRegularAsset))).load();
  });

  for (final dark in [false, true]) {
    testWidgets(
      'Profile header and panel stay joined on every pull and return frame ($dark)',
      (tester) async {
        await profile.mount(tester, profile.gateway(), dark: dark);
        final header = find.byKey(const ValueKey('profile-header'));
        final tabs = find.byKey(const ValueKey('profile-tabs'));
        final gaps = <double>[];
        void recordJoin() => gaps.add(
          tester.getTopLeft(tabs).dy - tester.getBottomLeft(header).dy,
        );
        recordJoin();
        final gesture = await tester.startGesture(
          tester.getTopLeft(header) + const Offset(100, 150),
        );
        for (var i = 0; i < 10; i++) {
          await gesture.moveBy(const Offset(0, 7.3));
          await tester.pump(const Duration(milliseconds: 16));
          recordJoin();
        }
        await gesture.up();
        for (var i = 0; i < 18; i++) {
          await tester.pump(const Duration(milliseconds: 16));
          recordJoin();
        }
        await tester.pumpAndSettle();
        recordJoin();
        expect(gaps, everyElement(closeTo(0, .01)));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Rounded profile panel paints no seam at fractional pinned scroll offsets ($dark)',
      (tester) async {
        final api = FakeGateway(seeded: true)
          ..documents['GetMe']!.addAll({
            'nickname': '应用测试员',
            'public_id': '123456',
            'city': '广东省',
            'bio': '记录工作里的发现，也分享每一次认真尝试。喜欢把复杂的事情理清楚。',
          });
        await profile.mount(
          tester,
          api,
          size: const Size(360, 792),
          dark: dark,
        );
        const ratio = 4.0;
        tester.view.devicePixelRatio = ratio;
        tester.view.physicalSize = const Size(1440, 3168);
        tester.view.padding = const FakeViewPadding(top: 160);
        tester.view.viewPadding = const FakeViewPadding(top: 160);
        addTearDown(tester.view.resetViewPadding);
        await tester.pumpAndSettle();
        final nested = tester.state<NestedScrollViewState>(
          find.byKey(const ValueKey('profile-scroll')),
        );
        final tabs = find.byKey(const ValueKey('profile-tabs'));
        final controller = DefaultTabController.of(tester.element(tabs));
        final color = tester.element(tabs).colors.surface.toARGB32();
        final expected = [(color >> 16) & 255, (color >> 8) & 255, color & 255];
        final differences = <Map<String, Object>>[];
        for (var tab = 0; tab < 3; tab++) {
          controller.index = tab;
          await tester.pumpAndSettle();
          for (final visible in [44, 20]) {
            final base =
                (nested.outerController.position.maxScrollExtent - visible)
                    .floorToDouble();
            for (final fraction in [.1, .2, .4, .7, .9]) {
              nested.outerController.jumpTo(base + fraction);
              await tester.pumpAndSettle();
              expect(
                find.byKey(const ValueKey('profile-compact-header')),
                findsOneWidget,
              );
              final join = tester.getTopLeft(tabs).dy;
              final boundary = tester.renderObject<RenderRepaintBoundary>(
                find.byKey(profile.surface),
              );
              await tester.runAsync(() async {
                final image = await boundary.toImage(pixelRatio: ratio);
                final bytes = (await image.toByteData(
                  format: ui.ImageByteFormat.rawRgba,
                ))!.buffer.asUint8List();
                var bad = 0;
                final colors = <int>{};
                for (
                  var y = (join * ratio).floor() - 2;
                  y <= (join * ratio).ceil() + 2;
                  y++
                ) {
                  for (
                    var x = (32 * ratio).round();
                    x < image.width - 32 * ratio;
                    x++
                  ) {
                    final offset = (y * image.width + x) * 4;
                    if (List.generate(
                      3,
                      (channel) =>
                          (bytes[offset + channel] - expected[channel]).abs(),
                    ).any((error) => error > 1)) {
                      bad++;
                      colors.add(
                        (bytes[offset] << 16) |
                            (bytes[offset + 1] << 8) |
                            bytes[offset + 2],
                      );
                    }
                  }
                }
                if (bad > 0) {
                  differences.add({
                    'tab': tab,
                    'visible': visible,
                    'fraction': fraction,
                    'join': join,
                    'bad_pixels': bad,
                    'colors': colors.map((c) => c.toRadixString(16)).toList(),
                  });
                }
                if (visible == 44 && fraction == .1) {
                  final data = await image.toByteData(
                    format: ui.ImageByteFormat.png,
                  );
                  final output = Directory(
                    'artifacts/verification/profile-seam-20261018/previews',
                  );
                  await output.create(recursive: true);
                  await File('${output.path}/panel-$dark-$tab.png')
                      .writeAsBytes(data!.buffer.asUint8List());
                }
                image.dispose();
              });
            }
          }
        }
        expect(differences, isEmpty, reason: '$differences');
        expect(tester.takeException(), isNull);
      },
    );
  }
}
