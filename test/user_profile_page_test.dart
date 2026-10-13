import 'package:bojian_mobile/api/bojian_api.dart';
import 'package:bojian_mobile/app_store.dart';
import 'package:bojian_mobile/design.dart';
import 'package:bojian_mobile/discovery.dart';
import 'package:bojian_mobile/user_profile_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

class ProfileGateway extends FakeGateway {
  String? failure;
  final paths = <Map<String, String>>[];
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
    if (method != 'GetUsersFirstSecond') return response;
    paths.add(Map.of(path));
    if (path['second'] == failure) {
      throw const ApiFailure('暂时不可见', code: 'USER_NOT_FOUND');
    }
    return ApiDocument(
      path['second'] == 'profile'
          ? {
              'id': 2,
              'nickname': '小林',
              'public_id': 'BJ-LIN',
              'bio': '记录工作中的收获，也分享面试中的思考。',
              'city': '上海市',
            }
          : {
              'items': [
                {
                  'id': 8,
                  'title': '我的面试复盘',
                  'published_at': '2026-10-09T07:00:00Z',
                },
              ],
            },
    );
  }
}

Story article(int author) => Story(
  id: 8,
  title: '我的面试复盘',
  author: '小林',
  authorID: author,
  role: '上海市',
  category: '经验分享',
  excerpt: '复盘',
  paragraphs: ['文章正文'],
);

Future<void> launchProfile(WidgetTester tester, AppStore store) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: appTheme,
      home: UserProfilePage(store: store, userID: 2),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'Another author avatar opens profile using the public user endpoints',
    (tester) async {
      final api = ProfileGateway();
      final store = await testStore(authenticated: true, api: api);
      addTearDown(store.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: Scaffold(
            body: StoryCard(story: article(2), store: store),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('story-author-avatar-8')));
      await tester.pumpAndSettle();
      expect(find.byType(UserProfilePage), findsOneWidget);
      expect(api.paths, [
        {'first': '2', 'second': 'profile'},
        {'first': '2', 'second': 'articles'},
      ]);
      expect(find.text('小林'), findsOneWidget);
      expect(find.text('用户 ID：BJ-LIN'), findsOneWidget);
      expect(find.text('记录工作中的收获，也分享面试中的思考。'), findsOneWidget);
      expect(find.text('上海市'), findsOneWidget);
      expect(find.text('公开文章'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Own avatar and missing author identity do not navigate or request a profile',
    (tester) async {
      final api = ProfileGateway();
      final store = await testStore(authenticated: true, api: api);
      addTearDown(store.dispose);
      for (final id in [store.userID, 0]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: appTheme,
            home: Scaffold(
              body: StoryCard(story: article(id), store: store),
            ),
          ),
        );
        await tester.tap(find.byKey(const ValueKey('story-author-avatar-8')));
        await tester.pumpAndSettle();
        expect(find.byType(UserProfilePage), findsNothing);
        expect(api.paths, isEmpty);
      }
    },
  );

  testWidgets('Public article opens complete detail and no draft is exposed', (
    tester,
  ) async {
    final api = ProfileGateway();
    api.documents['GetArticlesId'] = {
      'id': 8,
      'title': '我的面试复盘',
      'content': richContent('完整公开正文'),
      'author': {'id': 2, 'display_name': '小林'},
    };
    final store = await testStore(authenticated: true, api: api);
    addTearDown(store.dispose);
    await launchProfile(tester, store);
    await tester.ensureVisible(find.byKey(const ValueKey('public-article-8')));
    await tester.tap(find.byKey(const ValueKey('public-article-8')));
    await tester.pumpAndSettle();
    expect(find.byType(StoryDetail), findsOneWidget);
    expect(find.text('完整公开正文'), findsOneWidget);
    expect(api.calls, contains('GetArticlesId'));
    expect(api.calls, isNot(contains('GetMeArticles')));
  });

  testWidgets(
    'Unavailable profile hides identity and skips article requests, retry can recover',
    (tester) async {
      final api = ProfileGateway()..failure = 'profile';
      final store = await testStore(authenticated: true, api: api);
      addTearDown(store.dispose);
      await launchProfile(tester, store);
      expect(find.text('该用户主页暂不可见'), findsOneWidget);
      expect(find.byKey(const ValueKey('public-user-identity')), findsNothing);
      expect(api.paths.where((p) => p['second'] == 'articles'), isEmpty);
      api.failure = null;
      await tester.tap(find.text('重新加载'));
      await tester.pumpAndSettle();
      expect(find.text('小林'), findsOneWidget);
      expect(find.text('我的面试复盘'), findsOneWidget);
      api.failure = 'profile';
      await tester.drag(find.byType(ListView), const Offset(0, 400));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('public-user-identity')), findsNothing);
      expect(find.text('我的面试复盘'), findsNothing);
    },
  );

  testWidgets(
    'Article failure retains profile and displays retry instead of an empty state',
    (tester) async {
      final api = ProfileGateway()..failure = 'articles';
      final store = await testStore(authenticated: true, api: api);
      addTearDown(store.dispose);
      await launchProfile(tester, store);
      expect(find.text('小林'), findsOneWidget);
      expect(find.text('文章加载失败，请稍后重试'), findsOneWidget);
      expect(find.text('暂时没有公开文章'), findsNothing);
      api.failure = null;
      await tester.ensureVisible(find.text('重新加载'));
      await tester.tap(find.text('重新加载'));
      await tester.pumpAndSettle();
      expect(find.text('我的面试复盘'), findsOneWidget);
    },
  );

  testWidgets(
    'Landscape and enlarged default font keep all profile content scrollable',
    (tester) async {
      tester.view.physicalSize = const Size(844, 360);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = ProfileGateway();
      final store = await testStore(authenticated: true, api: api);
      addTearDown(store.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.6)),
            child: child!,
          ),
          home: UserProfilePage(store: store, userID: 2),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('我的面试复盘'), 180);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
