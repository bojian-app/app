import 'package:bojian_mobile/api/bojian_api.dart';
import 'package:bojian_mobile/design.dart';
import 'package:bojian_mobile/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

class SettingsGateway extends FakeGateway {
  @override
  Future<ApiDocument> call(
    String method, {
    Map<String, String> path = const {},
    Map<String, String> query = const {},
    Map<String, dynamic>? body,
    Map<String, String> headers = const {},
  }) async {
    final response = await super.call(
      method,
      path: path,
      query: query,
      body: body,
      headers: headers,
    );
    return method == 'PatchMe' ? ApiDocument(documents['GetMe']!) : response;
  }
}

Future<void> tapText(WidgetTester tester, String label) async {
  final target = find.text(label);
  if (target.evaluate().isEmpty) {
    await tester.scrollUntilVisible(target, 160);
  }
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Remote logout preserves current login and failed rows', (
    tester,
  ) async {
    final api = SettingsGateway()..failing = 'DeleteMeSessionsId';
    api.documents['GetMeSessions'] = {
      'items': [
        {'id': 1, 'platform': 'ANDROID', 'is_current': true},
        {'id': 2, 'platform': 'MACOS', 'is_current': false},
      ],
    };
    final store = await testStore(authenticated: true, api: api);
    addTearDown(store.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: SettingsPage(store: store),
      ),
    );
    await tapText(tester, '账号安全');
    Future<void> logout() async {
      await tester.tap(find.widgetWithText(TextButton, '退出登录').last);
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(TextButton, '退出登录'),
        ),
      );
      await tester.pumpAndSettle();
    }

    await logout();
    expect(find.text('macOS 设备'), findsOneWidget);
    expect(store.isAuthenticated, true);
    api.failing = null;
    await logout();
    expect(find.text('macOS 设备'), findsNothing);
    expect(find.text('Android 设备'), findsOneWidget);
    expect(store.isAuthenticated, true);
  });

  testWidgets('Security lists hardware model and full OS version per device', (
    tester,
  ) async {
    final api = SettingsGateway();
    api.documents['GetMeSessions'] = {
      'items': [
        {
          'id': 1,
          'platform': 'ANDROID',
          'device_model': 'OPPO PJD110',
          'os_version': '15',
          'is_current': true,
        },
        {
          'id': 2,
          'platform': 'IOS',
          'device_model': 'Apple iPhone (iPhone17,1)',
          'os_version': '18.2',
          'is_current': false,
        },
      ],
    };
    final store = await testStore(authenticated: true, api: api);
    addTearDown(store.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: SettingsPage(store: store),
      ),
    );
    await tapText(tester, '账号安全');
    expect(find.text('OPPO PJD110'), findsOneWidget);
    expect(find.text('系统：Android 15'), findsOneWidget);
    expect(find.text('Apple iPhone (iPhone17,1)'), findsOneWidget);
    expect(find.text('系统：iOS 18.2'), findsOneWidget);
  });

  testWidgets('Account appeal uses own account and preserves failed content', (
    tester,
  ) async {
    final api = SettingsGateway()..failing = 'PostAppeals';
    final store = await testStore(authenticated: true, api: api);
    addTearDown(store.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: SettingsPage(store: store),
      ),
    );
    await tapText(tester, '账号安全');
    await tapText(tester, '账号申诉');
    await tester.enterText(find.byType(TextField), '账号使用出现异常');
    await tapText(tester, '提交申诉');
    expect(api.lastBody, {
      'subject_type': 'USER',
      'subject_id': store.userID,
      'reason': '账号使用出现异常',
    });
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '账号使用出现异常',
    );
    api.failing = null;
    await tapText(tester, '提交申诉');
    expect(find.text('账号管理'), findsOneWidget);
  });
  testWidgets('Privacy changes persist only after successful response', (
    tester,
  ) async {
    final api = SettingsGateway();
    final store = await testStore(authenticated: true, api: api);
    addTearDown(store.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: SettingsPage(store: store),
      ),
    );
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(store.publicProfile, false);
    expect(api.lastBody, {'profile_visibility': 'PRIVATE'});
    api.failing = 'PatchMe';
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(store.publicProfile, false);
    expect(tester.widget<Switch>(find.byType(Switch)).value, false);
  });

  testWidgets(
    'Feedback preserves input on failure and submits correct category',
    (tester) async {
      final api = SettingsGateway()..failing = 'PostFeedback';
      final store = await testStore(authenticated: true, api: api);
      addTearDown(store.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: SettingsPage(store: store),
        ),
      );
      await tapText(tester, '意见反馈');
      await tapText(tester, '功能建议');
      await tester.enterText(find.byType(TextField), ' 希望增加更多模板 ');
      await tapText(tester, '提交反馈');
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        ' 希望增加更多模板 ',
      );
      expect(api.lastBody, {
        'category': 'SUGGESTION',
        'content': '希望增加更多模板',
        'diagnostic_consent': false,
      });
      api.failing = null;
      await tapText(tester, '提交反馈');
      expect(find.byType(TextField), findsNothing);
      expect(find.text('隐私与设置'), findsOneWidget);
    },
  );

  testWidgets(
    'Security displays server data and cancelling deletion makes no request',
    (tester) async {
      final api = SettingsGateway();
      api.documents['GetMeSessions'] = {
        'items': [
          {
            'id': 1,
            'platform': 'ANDROID',
            'logged_in_at': '2026-10-09T02:00:00Z',
            'is_current': true,
          },
          {
            'id': 2,
            'platform': 'MACOS',
            'logged_in_at': '2026-10-08T02:00:00Z',
            'is_current': false,
          },
        ],
      };
      final store = await testStore(authenticated: true, api: api);
      addTearDown(store.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: SettingsPage(store: store),
        ),
      );
      await tapText(tester, '账号安全');
      expect(find.text('Android 设备'), findsOneWidget);
      expect(find.text('macOS 设备'), findsOneWidget);
      expect(find.text('当前设备'), findsOneWidget);
      expect(find.text('最近安全记录'), findsNothing);
      await tapText(tester, '账号注销');
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, '申请注销'))
            .onPressed,
        isNull,
      );
      await tester.enterText(find.byType(TextField), '我已确认并主动注销此账号');
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, '申请注销'))
            .onPressed,
        isNotNull,
      );
      await tapText(tester, '暂不注销');
      expect(api.calls, isNot(contains('DeleteMeAccount')));
      expect(store.isAuthenticated, true);
    },
  );

  testWidgets(
    'Landscape settings remain scrollable and clearing cache keeps session',
    (tester) async {
      tester.view.physicalSize = const Size(900, 420);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = await testStore(authenticated: true);
      addTearDown(store.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: SettingsPage(store: store),
        ),
      );
      await tapText(tester, '图片缓存');
      await tapText(tester, '清理');
      expect(store.isAuthenticated, true);
      await tapText(tester, '关于博简');
      expect(find.text('博简'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
