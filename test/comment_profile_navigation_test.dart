import 'package:bojian_mobile/api/bojian_api.dart';
import 'package:bojian_mobile/app_store.dart';
import 'package:bojian_mobile/design.dart';
import 'package:bojian_mobile/discovery.dart';
import 'package:bojian_mobile/guidance_region_comments.dart';
import 'package:bojian_mobile/messages_page.dart';
import 'package:bojian_mobile/resume_guidance_annotations.dart';
import 'package:bojian_mobile/resume_guidance_review.dart';
import 'package:bojian_mobile/resume_guidance_view.dart';
import 'package:bojian_mobile/user_profile_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

class _ProfileGateway extends FakeGateway {
  final profileUsers = <int>[];
  bool unavailable = false;
  Map<String, dynamic>? annotationPost;

  @override
  Future<ApiDocument> call(
    String method, {
    Map<String, String> path = const {},
    Map<String, String> query = const {},
    Map<String, dynamic>? body,
    Map<String, String> headers = const {},
  }) async {
    if (method.startsWith('Post') && method.endsWith('GuidanceAnnotations')) {
      annotationPost = Map.of(body!);
    }
    final response = await super.call(
      method,
      path: path,
      query: query,
      body: body,
      headers: headers,
    );
    if (method != 'GetUsersFirstSecond') return response;
    final user = int.parse(path['first']!);
    if (path['second'] == 'articles') return ApiDocument({'items': []});
    profileUsers.add(user);
    if (unavailable) {
      throw const ApiFailure('不可见', code: 'USER_NOT_FOUND');
    }
    return ApiDocument({
      'id': user,
      'nickname': '主页用户$user',
      'public_id': 'user$user',
    });
  }
}

const _field = 'work_experiences.0.description';
Map<String, dynamic> _comment(int id, int user, {int? parent}) => {
  'id': id,
  'reviewer_id': user,
  'reviewer_name': '同名用户',
  'field_path': _field,
  'selected_text': '网站开发',
  'suggestion': '评论$id',
  'parent_id': ?parent,
};

Future<void> _visitAndReturn(
  WidgetTester tester,
  _ProfileGateway api,
  String avatarKey,
  int user,
) async {
  final avatar = find.byKey(ValueKey(avatarKey));
  await tester.ensureVisible(avatar);
  await tester.pumpAndSettle();
  await tester.tap(avatar);
  await tester.pumpAndSettle();
  expect(
    tester.widget<UserProfilePage>(find.byType(UserProfilePage)).userID,
    user,
  );
  expect(api.profileUsers.last, user);
  await tester.tap(find.byTooltip('返回'));
  await tester.pumpAndSettle();
  expect(find.byType(UserProfilePage), findsNothing);
  expect(tester.takeException(), isNull);
}

void main() {
  testWidgets(
    'Article root and reply avatars open exact users including self and preserve the draft',
    (tester) async {
      final api = _ProfileGateway();
      final store = await testStore(authenticated: true, api: api);
      addTearDown(store.dispose);
      api.documents['GetArticlesIdComments'] = {
        'items': [
          for (final item in [(10, 2), (20, 3), (30, store.userID)])
            {
              'id': item.$1,
              'author': {'id': item.$2, 'display_name': '同名用户'},
              'content': '主评论${item.$1}',
              'reply_count': item.$1 == 10 ? 1 : 0,
            },
        ],
      };
      api.documents['GetArticlesIdCommentsCommentIDReplies'] = {
        'items': [
          {
            'id': 11,
            'parent_id': 10,
            'author': {'id': 4, 'display_name': '回复用户'},
            'content': '楼中楼回复',
          },
        ],
      };
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: StoryDetail(
            store: store,
            story: decodeStory({'id': 1, 'title': '测试文章'}),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('展开 1 条回复'));
      await tester.tap(find.text('展开 1 条回复'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('楼中楼回复'));
      await tester.enterText(
        find.byKey(const ValueKey('article-comment-input')),
        '未发送的回复草稿',
      );
      for (final item in [(10, 2), (20, 3), (30, store.userID), (11, 4)]) {
        await _visitAndReturn(
          tester,
          api,
          'comment-avatar-${item.$1}',
          item.$2,
        );
        expect(find.text('回复 回复用户'), findsOneWidget);
        expect(find.text('未发送的回复草稿'), findsOneWidget);
        expect(find.text('楼中楼回复'), findsOneWidget);
      }
      expect(api.profileUsers, [2, 3, store.userID, 4]);
      expect(api.calls, isNot(contains('PostArticlesIdComments')));
      expect(api.calls, isNot(contains('PutArticlesIdCommentsCommentIDLike')));
    },
  );

  testWidgets('Deleted and missing article identities never open a profile', (
    tester,
  ) async {
    final api = _ProfileGateway();
    final store = await testStore(authenticated: true, api: api);
    addTearDown(store.dispose);
    api.documents['GetArticlesIdComments'] = {
      'items': [
        {
          'id': 10,
          'author': {'id': 0},
          'content': '无身份评论',
        },
        {
          'id': 20,
          'author': {'id': 2},
          'is_deleted': true,
        },
      ],
    };
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: StoryDetail(
          store: store,
          story: decodeStory({'id': 1, 'title': '测试文章'}),
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (final id in [10, 20]) {
      final avatar = find.byKey(ValueKey('comment-avatar-$id'));
      await tester.ensureVisible(avatar);
      await tester.tap(avatar);
      await tester.pumpAndSettle();
    }
    expect(api.profileUsers, isEmpty);
    expect(find.byType(UserProfilePage), findsNothing);
  });

  for (final notification in [false, true]) {
    testWidgets(
      'Region comments and replies keep sheet, reply target and draft after profiles ($notification)',
      (tester) async {
        final api = _ProfileGateway();
        final store = await testStore(authenticated: true, api: api);
        addTearDown(store.dispose);
        final prefix = notification ? 'Notifications' : 'Articles';
        api.documents['Get${prefix}IdGuidanceAnnotations'] = {
          'items': [_comment(7, 2), _comment(8, store.userID, parent: 7)],
        };
        await tester.pumpWidget(
          MaterialApp(
            theme: appTheme,
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showRegionComments(
                    context,
                    store: store,
                    id: 20,
                    notification: notification,
                    owner: false,
                    fieldPath: _field,
                    selected: '网站开发',
                    original: '负责网站开发',
                    legacyItems: [
                      {..._comment(9, 3), 'legacy': true},
                      {..._comment(10, 0), 'legacy': true},
                    ],
                  ),
                  child: const Text('打开评论'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('打开评论'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('展开 1 条回复'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('评论8'));
        await tester.enterText(
          find.byKey(const ValueKey('region-comment-input')),
          '区域回复草稿',
        );
        for (final item in [
          ('comment:7', 2),
          ('comment:8', store.userID),
          ('legacy:9', 3),
        ]) {
          await _visitAndReturn(
            tester,
            api,
            'region-avatar-${item.$1}',
            item.$2,
          );
          expect(
            find.byKey(const ValueKey('region-comments-panel')),
            findsOneWidget,
          );
          expect(find.text('区域回复草稿'), findsOneWidget);
          expect(find.text('评论8'), findsOneWidget);
          expect(find.text('取消回复'), findsOneWidget);
        }
        final invalid = find.byKey(const ValueKey('region-avatar-legacy:10'));
        await tester.scrollUntilVisible(
          invalid,
          -200,
          scrollable: find.descendant(
            of: find.byKey(const ValueKey('region-comments-list')),
            matching: find.byType(Scrollable),
          ),
        );
        await tester.ensureVisible(invalid);
        await tester.pumpAndSettle();
        await tester.tap(invalid);
        await tester.pumpAndSettle();
        expect(api.profileUsers, [2, store.userID, 3]);
        expect(
          api.calls,
          isNot(contains('Post${prefix}IdGuidanceAnnotations')),
        );
        api.failing = 'Post${prefix}IdGuidanceAnnotations';
        await tester.tap(find.byKey(const ValueKey('region-comment-send')));
        await tester.pumpAndSettle();
        expect(api.annotationPost?['parent_id'], 8);
        expect(api.annotationPost?['suggestion'], '区域回复草稿');
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets(
    'Guidance record avatars preserve identity and unavailable profiles use existing status',
    (tester) async {
      final api = _ProfileGateway();
      final store = await testStore(authenticated: true, api: api);
      addTearDown(store.dispose);
      api.documents['GetArticlesIdGuidanceAnnotations'] = {
        'items': [_comment(7, 2), _comment(8, 0)],
      };
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: GuidanceAnnotations(
            store: store,
            id: 20,
            notification: false,
            owner: false,
            onChanged: () {},
            legacyItems: [
              {..._comment(9, 3), 'legacy': true},
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _visitAndReturn(
        tester,
        api,
        'guidance-record-avatar-annotation:7',
        2,
      );
      await _visitAndReturn(tester, api, 'guidance-record-avatar-legacy:9', 3);
      final invalid = find.byKey(
        const ValueKey('guidance-record-avatar-annotation:8'),
      );
      await tester.ensureVisible(invalid);
      await tester.tap(invalid);
      await tester.pumpAndSettle();
      expect(api.profileUsers, [2, 3]);
      api.unavailable = true;
      final avatar = find.byKey(
        const ValueKey('guidance-record-avatar-annotation:7'),
      );
      await tester.ensureVisible(avatar);
      await tester.pumpAndSettle();
      await tester.tap(avatar);
      await tester.pumpAndSettle();
      expect(find.text('该用户主页暂不可见'), findsOneWidget);
      expect(find.text('主页用户2'), findsNothing);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('评论7'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Participant avatars open profiles without selecting reviews; review heading also navigates',
    (tester) async {
      final api = _ProfileGateway();
      final store = await testStore(authenticated: true, api: api);
      addTearDown(store.dispose);
      final guidance = {
        'id': 20,
        'is_owner': true,
        'source_resume_id': 42,
        'title': '简历',
        'snapshot': <String, dynamic>{},
      };
      api.documents['GetArticlesIdGuidance'] = guidance;
      api.documents['GetArticlesIdGuidanceAnnotations'] = {
        'items': [_comment(7, 2)],
      };
      api.documents['GetResumesId'] = {
        'id': 42,
        'revision': 1,
        'content': {
          'personal_info': {'full_name': '作者'},
          'work_experiences': [
            {'company': '公司', 'description': '负责网站开发'},
          ],
        },
      };
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: ResumeGuidanceView(
            store: store,
            id: 20,
            initialData: guidance,
            fromNotification: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _visitAndReturn(
        tester,
        api,
        'guidance-participant-avatar-user:2',
        2,
      );
      expect(find.byType(GuidanceParticipantList), findsOneWidget);
      expect(find.byType(GuidanceReviewHeading), findsNothing);
      await tester.tap(
        find.byKey(const ValueKey('guidance-participant-user:2')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(GuidanceReviewHeading), findsOneWidget);
      await _visitAndReturn(tester, api, 'guidance-review-avatar', 2);
      expect(find.byType(GuidanceReviewHeading), findsOneWidget);
    },
  );

  testWidgets(
    'Comment notification avatars open the actor without reading or opening the discussion',
    (tester) async {
      final api = _ProfileGateway();
      api.documents['GetNotifications'] = {
        'unread_count': 1,
        'items': [
          {
            'id': 100,
            'type': 'RESUME_GUIDANCE_FEEDBACK',
            'actor_id': 2,
            'actor': {'display_name': '评论用户'},
            'subject_type': 'ARTICLE',
            'subject_id': 20,
            'payload': {'feedback_type': 'REPLY'},
          },
        ],
      };
      final store = await testStore(authenticated: true, api: api);
      addTearDown(store.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: Scaffold(body: MessagesPage(store: store)),
        ),
      );
      await tester.pumpAndSettle();
      await _visitAndReturn(tester, api, 'notification-actor-avatar-100', 2);
      expect(store.inbox.single.read, isFalse);
      expect(store.notificationUnreadCount, 1);
      expect(api.calls, isNot(contains('PostNotificationsRead')));
      expect(api.calls, isNot(contains('GetArticlesIdGuidance')));
      expect(find.byType(MessagesPage), findsOneWidget);
    },
  );
}
