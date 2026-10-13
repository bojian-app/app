import 'dart:async';

import 'package:bojian_mobile/api/bojian_api.dart';
import 'package:bojian_mobile/app_store.dart';
import 'package:bojian_mobile/api/generated/auth.pb.dart' as auth;
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

class ExpiringGateway extends FakeGateway {
  int refreshCount = 0;
  @override
  Future<ApiDocument> call(
    String method, {
    Map<String, String> path = const {},
    Map<String, String> query = const {},
    Map<String, dynamic>? body,
    Map<String, String> headers = const {},
  }) async {
    if (method == 'GetFeed' &&
        headers['authorization'] != 'Bearer refreshed-test') {
      throw const ApiFailure('登录失效', unauthenticated: true);
    }
    return super.call(
      method,
      path: path,
      query: query,
      body: body,
      headers: headers,
    );
  }

  @override
  Future<auth.TokenResponse> refresh(
    String token,
    Map<String, String> headers,
  ) async {
    refreshCount++;
    await Future<void>.delayed(const Duration(milliseconds: 10));
    return super.refresh(token, headers);
  }
}

class DelayedGateway extends FakeGateway {
  final response = Completer<ApiDocument>();
  @override
  Future<ApiDocument> call(
    String method, {
    Map<String, String> path = const {},
    Map<String, String> query = const {},
    Map<String, dynamic>? body,
    Map<String, String> headers = const {},
  }) => method == 'GetFeed'
      ? response.future
      : super.call(
          method,
          path: path,
          query: query,
          body: body,
          headers: headers,
        );
}

void main() {
  test(
    'Fresh production store contains no samples or invented balance',
    () async {
      final store = await testStore();
      addTearDown(store.dispose);
      expect(store.stories, isEmpty);
      expect(store.resumes, isEmpty);
      expect(store.inbox, isEmpty);
      expect(store.friends, isEmpty);
      expect(store.templates, isEmpty);
      expect(store.points, isNull);
      expect(store.name, isEmpty);
      expect(store.isAuthenticated, isFalse);
    },
  );
  test(
    'Failed mutation leaves state unchanged and clears pending flag',
    () async {
      final api = FakeGateway(seeded: true);
      final store = await testStore(authenticated: true, api: api);
      addTearDown(store.dispose);
      final story = store.stories.first;
      api.failing = 'PutArticlesIdLike';
      await expectLater(store.like(story), throwsA(isA<ApiFailure>()));
      expect(story.liked, isFalse);
      expect(story.likes, 0);
      expect(store.pending, isEmpty);
    },
  );
  test('Resume writes preserve unknown fields and enforce revision', () async {
    final api = FakeGateway();
    final store = await testStore(authenticated: true, api: api);
    addTearDown(store.dispose);
    final draft = decodeResume({
      'id': 4,
      'revision': 7,
      'title': '我的简历',
      'content': {
        'personal_info': {'full_name': '姓名', 'birth_date': '2000-01-01'},
        'job_expectation': {'position': '工程师'},
        'projects': [
          {
            'name': '保留项目',
            'description_rich': {'blocks': []},
          },
        ],
        'certifications': [
          {'name': '保留证书'},
        ],
      },
    });
    draft.name = '新姓名';
    await store.updateResume(draft);
    final row = api.documents['GetResumes']!['items'][0] as Map;
    expect(row['content']['projects'][0]['name'], '保留项目');
    expect(row['content']['certifications'][0]['name'], '保留证书');
    expect(row['content']['personal_info']['birth_date'], '2000-01-01');
    expect(api.calls, contains('PatchResumesId'));
  });
  test(
    'Expired access token refreshes once across concurrent requests',
    () async {
      final api = ExpiringGateway();
      final store = await testStore(api: api);
      addTearDown(store.dispose);
      store.session = {
        'access_token': 'old',
        'refresh_token': 'refresh',
        'user_id': 1,
      };
      await Future.wait([store.request('GetFeed'), store.request('GetFeed')]);
      expect(api.refreshCount, 1);
      expect(store.session!['access_token'], 'refreshed-test');
    },
  );
  test('Late response after logout cannot restore private data', () async {
    final api = DelayedGateway();
    final store = await testStore(api: api);
    addTearDown(store.dispose);
    store.session = {
      'access_token': 'old',
      'refresh_token': 'refresh',
      'user_id': 1,
    };
    final loading = store.load('feed');
    await Future<void>.delayed(Duration.zero);
    await store.endSession(remote: false);
    api.response.complete(
      ApiDocument({
        'items': [
          {'id': 4, 'title': '旧账号文章', 'author': {}, 'content': {}},
        ],
      }),
    );
    await loading;
    expect(store.stories, isEmpty);
    expect(store.isAuthenticated, isFalse);
    expect(store.errors, isEmpty);
  });
  test('Concurrent loads wait for the same server response', () async {
    final api = DelayedGateway();
    final store = await testStore(api: api);
    addTearDown(store.dispose);
    store.session = {
      'access_token': 'access',
      'refresh_token': 'refresh',
      'user_id': 1,
    };
    var secondFinished = false;
    final first = store.load('feed');
    final second = store.load('feed').then((_) => secondFinished = true);
    await Future<void>.delayed(Duration.zero);
    expect(secondFinished, isFalse);
    api.response.complete(ApiDocument({'items': []}));
    await Future.wait([first, second]);
    expect(secondFinished, isTrue);
    expect(store.loading, isEmpty);
  });
}
