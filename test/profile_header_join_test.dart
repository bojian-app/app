import 'package:bojian_mobile/resume_native_export.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'profile_pull_details_test.dart' as profile;

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
  }
}
