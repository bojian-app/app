import 'dart:async';

import 'package:bojian_mobile/api/bojian_api.dart';
import 'package:bojian_mobile/app_store.dart';
import 'package:bojian_mobile/public_profile_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';
import 'user_profile_page_test.dart' show ProfileGateway;

class HeldPublicProfile extends FakeGateway {
  final result = Completer<ApiDocument>();
  final requested = Completer<void>();
  @override
  Future<ApiDocument> call(
    String method, {
    Map<String, String> path = const {},
    Map<String, String> query = const {},
    Map<String, dynamic>? body,
    Map<String, String> headers = const {},
  }) {
    if (method == 'GetUsersFirstSecond') {
      if (!requested.isCompleted) requested.complete();
      return result.future;
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

void main() {
  for (final invalid in ['author', 'id', 'draft', 'private']) {
    test(
      'A public summary never exposes an invalid detail: $invalid',
      () async {
        final api = ProfileGateway();
        api.documents['GetArticlesId'] = {
          'id': invalid == 'id' ? 99 : 8,
          'author': {'id': invalid == 'author' ? 3 : 2, 'display_name': '作者'},
          'title': '不应展示的内容',
          'status': invalid == 'draft' ? 'DRAFT' : 'PUBLISHED',
          'visibility': invalid == 'private' ? 'PRIVATE' : 'PUBLIC',
          'content': richContent('不应展示的正文'),
        };
        final store = await testStore(authenticated: true, api: api);
        final controller = PublicProfileController(store: store, userID: 2);
        addTearDown(store.dispose);
        addTearDown(controller.dispose);
        await controller.load();
        expect(controller.profile!.userID, 2);
        expect(controller.articles, isEmpty);
        expect(controller.articleError, isNotNull);
        expect(api.calls, isNot(contains('GetMeArticles')));
      },
    );
  }

  for (final dispose in [false, true]) {
    test(
      'A late public profile is ignored after ${dispose ? 'dispose' : 'logout'}',
      () async {
        final api = HeldPublicProfile();
        final store = await testStore(authenticated: true, api: api);
        final controller = PublicProfileController(store: store, userID: 2);
        addTearDown(store.dispose);
        var notifications = 0;
        controller.addListener(() => notifications++);
        final loaded = controller.load();
        await api.requested.future;
        if (dispose) {
          controller.dispose();
        } else {
          await store.endSession(remote: false);
        }
        final before = notifications;
        api.result.complete(ApiDocument({'id': 2, 'nickname': '旧响应'}));
        await loaded;
        expect(controller.profile, isNull);
        expect(controller.articles, isEmpty);
        expect(notifications, before);
        if (!dispose) controller.dispose();
      },
    );
  }
}
