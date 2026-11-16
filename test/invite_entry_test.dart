import 'package:bojian_mobile/design.dart';
import 'package:bojian_mobile/discovery.dart';
import 'package:bojian_mobile/invitation_dialog.dart';
import 'package:bojian_mobile/membership_page.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      'Discovery floats the invitation, membership no longer has it, on $platform',
      (tester) async {
        debugDefaultTargetPlatformOverride = platform;
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(800, 2400);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final api = FakeGateway();
        api.documents['GetInvitations'] = {
          'invite_code': 'BJ-6018',
          'download_url': 'https://bojian.kelance.cn',
          'completed_count': 0,
          'pending_count': 0,
        };
        final store = await testStore(authenticated: true, api: api);
        addTearDown(store.dispose);
        await tester.pumpWidget(
          MaterialApp(
            theme: appTheme,
            home: MembershipPage(store: store),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('邀请好友，送 AI 次数'), findsNothing);
        await tester.pumpWidget(
          MaterialApp(
            theme: appTheme,
            home: Scaffold(body: DiscoveryPage(store: store)),
          ),
        );
        await tester.pumpAndSettle();
        final entry = find.byKey(const ValueKey('discovery-invite'));
        expect(entry.hitTestable(), findsOneWidget);
        await tester.tap(entry);
        await tester.pumpAndSettle();
        expect(find.byType(InvitationDialog), findsOneWidget);
        expect(find.text('三天会员体验包'), findsOneWidget);
        expect(api.calls, contains('GetInvitations'));
        expect(tester.takeException(), isNull);
        debugDefaultTargetPlatformOverride = null;
      },
    );
  }
}
