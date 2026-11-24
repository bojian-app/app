import 'dart:io';
import 'dart:ui' as ui;

import 'package:bojian_mobile/design.dart';
import 'package:bojian_mobile/invitation_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

void main() {
  _friendCodeTests();
  setUpAll(() async {
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    await (FontLoader(
      'ResumeDocument',
    )..addFont(rootBundle.load('assets/fonts/resume-sans-bold.ttf'))).load();
  });
  for (final size in [
    const Size(390, 844),
    const Size(320, 640),
    const Size(844, 390),
  ]) {
    testWidgets('Invitation popup fits $size, shows real code and dismisses', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final clipboardWrites = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboardWrites.add((call.arguments as Map)['text'] as String);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final shares = <MethodCall>[];
      const channel = MethodChannel('dev.fluttercommunity.plus/share');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        shares.add(call);
        return 'test-target';
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      final api = FakeGateway();
      api.documents['GetInvitations'] = {
        'invite_code': 'BJ-6018',
        'download_url': 'https://bojian.kelance.cn',
        'completed_count': 2,
        'pending_count': 1,
      };
      final store = await testStore(authenticated: true, api: api);
      addTearDown(store.dispose);
      await tester.pumpWidget(
        RepaintBoundary(
          key: const ValueKey('preview'),
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: appTheme,
            home: Scaffold(
              backgroundColor: const Color(0xFF44475A),
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showInvitationDialog(context, store),
                  child: const Text('邀请'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('邀请'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('invitation-poster-ready')),
        findsOneWidget,
      );
      expect(find.byType(InvitationDialog), findsOneWidget);
      expect(find.text('我的二维码'), findsOneWidget);
      expect(find.text('BJ-6018'), findsOneWidget);
      expect(find.bySemanticsLabel('拾页邀请下载二维码'), findsOneWidget);
      expect(tester.takeException(), isNull);
      if (size.width == 390) {
        await tester.runAsync(() async {
          await precacheImage(
            const AssetImage('assets/invitation/reward-envelope-blank.png'),
            tester.element(find.byType(InvitationDialog)),
          );
        });
        await tester.pumpAndSettle();
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('preview')),
        );
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          await File('/tmp/bojian-invitation-preview.png')
              .writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.ensureVisible(
        find.byKey(const ValueKey('invitation-copy-code')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('invitation-copy-code')));
      await tester.pumpAndSettle();
      expect(clipboardWrites, contains('BJ-6018'));
      expect(find.text('邀请码已复制'), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(const ValueKey('invitation-copy-link')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('invitation-copy-link')));
      await tester.pumpAndSettle();
      expect(
        clipboardWrites.last,
        'https://bojian.kelance.cn?invite_code=BJ-6018',
      );
      expect(find.text('邀请链接已复制'), findsOneWidget);
      expect(shares, isEmpty);
      await tester.ensureVisible(
        find.byKey(const ValueKey('invitation-close')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('invitation-close')));
      await tester.pumpAndSettle();
      expect(find.byType(InvitationDialog), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('Invitation request failure can retry without fabricated code', (
    tester,
  ) async {
    final api = FakeGateway()..failing = 'GetInvitations';
    final store = await testStore(authenticated: true, api: api);
    addTearDown(store.dispose);
    await tester.pumpWidget(MaterialApp(home: InvitationDialog(store: store)));
    await tester.pumpAndSettle();
    expect(find.text('邀请信息加载失败，点击重试'), findsOneWidget);
    expect(find.text('——'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('invitation-copy-code')));
    await tester.pumpAndSettle();
    expect(find.text('邀请码已复制'), findsNothing);
    api.failing = null;
    api.documents['GetInvitations'] = {
      'invite_code': 'BJ-42',
      'download_url': 'https://bojian.kelance.cn',
    };
    await tester.ensureVisible(find.byKey(const ValueKey('invitation-retry')));
    await tester.tap(find.byKey(const ValueKey('invitation-retry')));
    await tester.pumpAndSettle();
    expect(find.text('三天会员体验包'), findsOneWidget);
    expect(find.text('BJ-42'), findsOneWidget);
    expect(find.text('邀请信息加载失败，点击重试'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

void _friendCodeTests() {
  testWidgets('New accounts enter a friend code once in the invitation popup', (
    tester,
  ) async {
    final api = FakeGateway();
    api.documents['GetInvitations'] = {
      'invite_code': 'BJ-42',
      'download_url': 'https://bojian.kelance.cn',
      'bound_invite_code': null,
      'can_bind_invite_code': true,
    };
    api.documents['PostInvitationsBind'] = {
      'invite_code': 'BJ-42',
      'download_url': 'https://bojian.kelance.cn',
      'bound_invite_code': 'K7Q2M9XD',
      'can_bind_invite_code': false,
    };
    final store = await testStore(authenticated: true, api: api);
    addTearDown(store.dispose);
    await tester.pumpWidget(MaterialApp(home: InvitationDialog(store: store)));
    await tester.pumpAndSettle();
    final entry = find.byKey(const ValueKey('invitation-friend-code'));
    await tester.ensureVisible(entry);
    await tester.tap(entry);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('friend-invite-code')),
      'k7q2m9xd',
    );
    await tester.tap(find.byKey(const ValueKey('friend-invite-submit')));
    await tester.pumpAndSettle();
    expect(api.calls, contains('PostInvitationsBind'));
    expect(find.byKey(const ValueKey('invitation-friend-code')), findsNothing);
    expect(find.byKey(const ValueKey('friend-invite-code')), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Older accounts see no friend code entry', (tester) async {
    final api = FakeGateway();
    api.documents['GetInvitations'] = {
      'invite_code': 'BJ-42',
      'download_url': 'https://bojian.kelance.cn',
      'can_bind_invite_code': false,
    };
    final store = await testStore(authenticated: true, api: api);
    addTearDown(store.dispose);
    await tester.pumpWidget(MaterialApp(home: InvitationDialog(store: store)));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('invitation-friend-code')), findsNothing);
  });
}
