import 'package:bojian_mobile/api/bojian_api.dart';
import 'package:bojian_mobile/app_store.dart';
import 'package:bojian_mobile/design.dart';
import 'package:bojian_mobile/discovery.dart';
import 'package:bojian_mobile/user_profile_page.dart';
import 'package:bojian_mobile/profile_identity.dart';
import 'package:bojian_mobile/profile_avatar.dart';
import 'package:bojian_mobile/guidance_feed_card.dart';
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
    if (method == 'GetArticlesId' && !documents.containsKey(method)) {
      return ApiDocument({
        'id': int.parse(path['id']!),
        'title': '我的面试复盘',
        'author': {'id': 2, 'display_name': '小林'},
        'content': richContent('完整公开正文'),
        'status': 'PUBLISHED',
        'visibility': 'PUBLIC',
      });
    }
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
              'public_id': '100002',
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
      expect(find.text('小林'), findsNWidgets(2));
      expect(find.text('ID：100002 / IP：上海市'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('profile-about-summary')),
        findsOneWidget,
      );
      expect(find.byType(ProfileHeader), findsOneWidget);
      expect(find.byType(ProfileContentTabs), findsOneWidget);
      expect(find.text('动态'), findsOneWidget);
      expect(find.text('公开文章'), findsNothing);
      expect(find.byKey(const ValueKey('profile-edit')), findsNothing);
      expect(find.byKey(const ValueKey('profile-avatar-camera')), findsNothing);
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
      'status': 'PUBLISHED',
      'visibility': 'PUBLIC',
    };
    final store = await testStore(authenticated: true, api: api);
    addTearDown(store.dispose);
    await launchProfile(tester, store);
    await tester.ensureVisible(find.byKey(const ValueKey('public-article-8')));
    await tester.tap(find.text('我的面试复盘'));
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
      expect(find.byType(ProfileHeader), findsNothing);
      expect(api.paths.where((p) => p['second'] == 'articles'), isEmpty);
      api.failure = null;
      await tester.tap(find.text('重新加载'));
      await tester.pumpAndSettle();
      expect(find.text('小林'), findsNWidgets(2));
      expect(find.text('我的面试复盘'), findsOneWidget);
      api.failure = 'profile';
      await tester.drag(
        find.byKey(const ValueKey('public-profile-scroll')),
        const Offset(0, 400),
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(find.byType(ProfileHeader), findsNothing);
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
      expect(find.text('暂时没有公开动态'), findsNothing);
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
      await tester.scrollUntilVisible(
        find.text('我的面试复盘'),
        180,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('public-profile-scroll')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Shared header morphs continuously and public details are read only',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = ProfileGateway();
      final store = await testStore(authenticated: true, api: api);
      store.name = '当前登录用户';
      store.ipLocation = '广东省';
      addTearDown(store.dispose);
      await launchProfile(tester, store);
      final header = tester.widget<ProfileHeader>(find.byType(ProfileHeader));
      expect(header.identity!.userID, 2);
      expect(header.identity!.name, '小林');
      expect(find.textContaining('广东'), findsNothing);
      expect(find.textContaining('当前登录用户'), findsNothing);
      final avatar = find.byKey(const ValueKey('profile-identity-avatar'));
      final element = tester.element(avatar);
      final scroller = tester
          .widget<CustomScrollView>(
            find.byKey(const ValueKey('public-profile-scroll')),
          )
          .controller!;
      final extent = scroller.position.maxScrollExtent;
      scroller.jumpTo(extent);
      await tester.pumpAndSettle();
      expect(tester.element(avatar), same(element));
      expect(tester.getSize(avatar), const Size.square(44));
      expect(tester.getSize(find.byType(ProfileContentTabs)).height, 38);
      scroller.jumpTo(0);
      await tester.pumpAndSettle();
      final height = tester.getSize(find.byType(ProfileHeader)).height;
      await tester.tap(find.byKey(const ValueKey('profile-about-summary')));
      await tester.pumpAndSettle();
      expect(find.byType(ProfileDetailsPage), findsOneWidget);
      expect(find.text('IP属地：上海市'), findsOneWidget);
      expect(find.byKey(const ValueKey('profile-details-edit')), findsNothing);
      expect(find.byKey(const ValueKey('profile-avatar-camera')), findsNothing);
      final detailAvatars = tester.widgetList<ProfileAvatar>(
        find.descendant(
          of: find.byType(ProfileDetailsPage),
          matching: find.byType(ProfileAvatar),
        ),
      );
      expect(detailAvatars.every((avatar) => avatar.seed == '2'), isTrue);
      await tester.tap(find.byKey(const ValueKey('profile-details-close')));
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(ProfileHeader)).height, height);
      expect(store.name, '当前登录用户');
      expect(store.ipLocation, '广东省');
      // Pulling the real shared header opens the same details and returns to rest.
      await tester.dragFrom(
        tester.getCenter(find.byKey(const ValueKey('profile-identity-name'))),
        const Offset(0, 180),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ProfileDetailsPage), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('profile-details-close')));
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(ProfileHeader)).height, height);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Resume guidance uses the same discovery entry and compact activity card',
    (tester) async {
      final api = ProfileGateway();
      api.documents['GetArticlesId'] = {
        'id': 8,
        'title': '公开简历指点',
        'author': {'id': 2, 'display_name': '小林'},
        'content': {'kind': 'RESUME_GUIDANCE', 'question': '想请大家帮我看看这份简历'},
        'status': 'PUBLISHED',
        'visibility': 'PUBLIC',
      };
      final store = await testStore(authenticated: true, api: api);
      addTearDown(store.dispose);
      final story = decodeStory(api.documents['GetArticlesId']!);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: Scaffold(
            body: StoryCard(story: story, store: store),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('story-author-avatar-8')));
      await tester.pumpAndSettle();
      expect(find.byType(UserProfilePage), findsOneWidget);
      final card = find.descendant(
        of: find.byType(UserProfilePage),
        matching: find.byType(GuidanceFeedCard),
      );
      expect(card, findsOneWidget);
      expect(tester.widget<GuidanceFeedCard>(card).compactTypography, isTrue);
      expect(
        tester.widget<GuidanceFeedCard>(card).authorNavigationEnabled,
        isFalse,
      );
      expect(find.byKey(const ValueKey('profile-edit')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final dark in [false, true]) {
    testWidgets('Public profile remains compact on narrow large text ($dark)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = ProfileGateway();
      final store = await testStore(authenticated: true, api: api);
      addTearDown(store.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: dark ? appDarkTheme : appTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: UserProfilePage(store: store, userID: 2),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(ProfileContentTabs)).height, 38);
      await tester.tap(find.byKey(const ValueKey('profile-about-summary')));
      await tester.pumpAndSettle();
      expect(find.byType(ProfileDetailsPage), findsOneWidget);
      expect(find.text('IP属地：上海市'), findsOneWidget);
      expect(find.byKey(const ValueKey('profile-details-edit')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('profile-details-close')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
