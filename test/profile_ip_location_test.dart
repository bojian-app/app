import 'dart:async';

import 'package:bojian_mobile/api/bojian_api.dart';
import 'package:bojian_mobile/app_store.dart';
import 'package:bojian_mobile/profile_identity.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'profile_about_reference_test.dart' as profile;
import 'support/fake_gateway.dart';

class LoginLocationGateway extends FakeGateway {
  final requested = Completer<Map<String, String>>();
  final profileResult = Completer<ApiDocument>();
  int profileRequests = 0;

  @override
  Future<ApiDocument> call(
    String method, {
    Map<String, String> path = const {},
    Map<String, String> query = const {},
    Map<String, dynamic>? body,
    Map<String, String> headers = const {},
  }) async {
    if (method == 'GetMe') {
      profileRequests++;
      if (!requested.isCompleted) requested.complete({...headers});
      return profileResult.future;
    }
    return super.call(
      method,
      path: path,
      query: query,
      body: body,
      headers: headers,
    );
  }
}

Future<AppStore> loginStore(LoginLocationGateway api) => testStore(
  api: api,
  weChatAuthorizer: FakeWeChatAuthorizer(),
  douyinAuthorizer: FakeDouyinAuthorizer(),
);

void main() {
  for (final provider in ['wechat', 'douyin']) {
    test(
      'Successful $provider login automatically fetches its authenticated IP location',
      () async {
        final api = LoginLocationGateway();
        final store = await loginStore(api);
        addTearDown(store.dispose);
        store.ipLocation = '上个账号的属地';
        final success = provider == 'wechat'
            ? await store.signInWithWeChat()
            : await store.signInWithDouyin();
        expect(success, isTrue);
        final headers = await api.requested.future;
        expect(headers['authorization'], 'Bearer test-access');
        expect(store.ipLocation, isEmpty);
        final loaded = store.sectionRequests['profile']!;
        api.profileResult.complete(
          ApiDocument({...api.documents['GetMe']!, 'city': ' 杭州市 '}),
        );
        await loaded;
        expect(api.profileRequests, 1);
        expect(store.ipLocation, '杭州市');
        expect(store.isAuthenticated, isTrue);
        await store.endSession(remote: false);
        expect(store.ipLocation, isEmpty);
      },
    );
  }

  test(
    'An unavailable IP lookup does not turn successful login into failure',
    () async {
      final api = LoginLocationGateway();
      final store = await loginStore(api);
      addTearDown(store.dispose);
      expect(await store.signInWithWeChat(), isTrue);
      await api.requested.future;
      final loaded = store.sectionRequests['profile']!;
      api.profileResult.completeError(const ApiFailure('资料暂时无法读取'));
      await loaded;
      expect(store.isAuthenticated, isTrue);
      expect(store.ipLocation, isEmpty);
    },
  );

  test('A late location response cannot restore data after logout', () async {
    final api = LoginLocationGateway();
    final store = await loginStore(api);
    addTearDown(store.dispose);
    await store.signInWithDouyin();
    await api.requested.future;
    final loaded = store.sectionRequests['profile']!;
    await store.endSession(remote: false);
    api.profileResult.complete(
      ApiDocument({...api.documents['GetMe']!, 'city': '旧响应城市'}),
    );
    await loaded;
    expect(store.ipLocation, isEmpty);
    expect(store.isAuthenticated, isFalse);
  });

  test(
    'Profile refresh updates the IP location and clears a missing value',
    () async {
      final api = FakeGateway();
      api.documents['GetMe']!['city'] = '杭州市';
      final store = await testStore(authenticated: true, api: api);
      addTearDown(store.dispose);
      expect(store.ipLocation, '杭州市');
      api.documents['GetMe']!['city'] = '深圳市';
      await store.load('profile');
      expect(store.ipLocation, '深圳市');
      api.documents['GetMe']!.remove('city');
      await store.load('profile');
      expect(store.ipLocation, isEmpty);
    },
  );

  test('Canceled authorizations never request a location', () async {
    final api = LoginLocationGateway();
    final store = await testStore(
      api: api,
      weChatAuthorizer: FakeWeChatAuthorizer(code: null),
      douyinAuthorizer: FakeDouyinAuthorizer(code: null),
    );
    addTearDown(store.dispose);
    expect(await store.signInWithWeChat(), isFalse);
    expect(await store.signInWithDouyin(), isFalse);
    expect(api.profileRequests, 0);
    expect(store.ipLocation, isEmpty);
  });

  testWidgets(
    'Nickname and ID stay close while the actual location and ID copy remain usable',
    (tester) async {
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
      final store = await profile.mount(tester, profile.gateway());
      final name = find.byKey(const ValueKey('profile-identity-name'));
      final id = find.byKey(const ValueKey('profile-account-summary'));
      expect(
        tester.getTopLeft(id).dy - tester.getBottomRight(name).dy,
        inInclusiveRange(0, 8),
      );
      expect(find.text('ID：${store.publicID} / IP：浙江'), findsOneWidget);
      expect(find.byTooltip('复制用户 ID'), findsNothing);
      expect(store.ipLocation, '浙江省');
      expect(copied, isEmpty);
      await tester.tap(find.byKey(const ValueKey('profile-about-summary')));
      await tester.pumpAndSettle();
      expect(find.byType(ProfileDetailsPage), findsOneWidget);
      expect(find.text('IP属地：浙江省'), findsOneWidget);
      final fullName = find.byKey(const ValueKey('profile-details-name'));
      expect(
        tester.getTopLeft(find.text('用户 ID：${store.publicID}')).dy -
            tester.getBottomRight(fullName).dy,
        inInclusiveRange(0, 8),
      );
      await tester.tap(find.byTooltip('复制用户 ID'));
      await tester.pumpAndSettle();
      expect(copied, [store.publicID]);
      expect(tester.takeException(), isNull);
    },
  );
}
