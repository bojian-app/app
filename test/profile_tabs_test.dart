import 'package:bojian_mobile/account_pages.dart';
import 'package:bojian_mobile/api/bojian_api.dart';
import 'package:bojian_mobile/app_store.dart';
import 'package:bojian_mobile/app_shell.dart';
import 'package:bojian_mobile/design.dart';
import 'package:bojian_mobile/developer_verification_page.dart';
import 'package:bojian_mobile/my_articles_page.dart';
import 'package:bojian_mobile/profile_avatar.dart';
import 'package:bojian_mobile/profile_identity.dart';
import 'package:bojian_mobile/points_page.dart';
import 'package:bojian_mobile/resume_pages.dart';
import 'package:bojian_mobile/saved_articles_page.dart';
import 'package:bojian_mobile/story_composer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

class ProfileContentGateway extends FakeGateway {
  ProfileContentGateway() : super(seeded: true);
  final statuses = <String>[];
  final articleQueries = <Map<String, String>>[];
  bool paginateArticles = false, failArticles = false;
  bool saved = true;

  @override
  Future<ApiDocument> call(
    String method, {
    Map<String, String> path = const {},
    Map<String, String> query = const {},
    Map<String, dynamic>? body,
    Map<String, String> headers = const {},
  }) async {
    if (method == 'GetMeArticles') {
      calls.add(method);
      statuses.add(query['status']!);
      articleQueries.add({...query});
      if (failArticles) throw const ApiFailure('服务器暂不可用');
      return ApiDocument(
        {
          'items': [
            for (
              var i = query.containsKey('cursor') ? 13 : 1;
              i <= (query.containsKey('cursor') ? 24 : 12);
              i++
            )
              {
                'id': i,
                'title': '我的文章 $i',
                'status': query['status'],
                'updated_at': '2026-10-18T08:00:00Z',
                'published_at': '2026-10-18T08:00:00Z',
                'content': richContent('这是我的文章 $i 的正文摘要'),
                'comment_count': 0,
                'is_liked': false,
                'is_favorited': false,
              },
            for (final status in ['SUBMITTED', 'DRAFT', 'REJECTED'])
              {'id': status, 'title': '$status 未发布文章', 'status': status},
          ],
        },
        nextCursor: paginateArticles && !query.containsKey('cursor')
            ? 'page-2'
            : '',
      );
    }
    if (method == 'GetMeFavorites') {
      calls.add(method);
      return ApiDocument({
        'items': [
          if (saved)
            {
              'id': 1,
              'title': '收藏的经验分享',
              'collected_at': '2026-10-18T08:00:00Z',
            },
        ],
      });
    }
    if (method == 'DeleteArticlesIdFavorite') {
      calls.add(method);
      saved = false;
      return ApiDocument({});
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

Future<AppStore> mount(
  WidgetTester tester,
  ProfileContentGateway api, {
  Size size = const Size(390, 780),
  double scale = 1,
  bool dark = false,
  bool shell = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetViewInsets);
  final store = await testStore(authenticated: true, api: api);
  addTearDown(store.dispose);
  await tester.pumpWidget(
    MaterialApp(
      theme: dark ? appDarkTheme : appTheme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: shell
          ? AppShell(store: store)
          : Scaffold(body: ProfilePage(store: store)),
    ),
  );
  await tester.pumpAndSettle();
  if (shell) {
    await tester.tap(find.byKey(const ValueKey('nav-3')));
    await tester.pumpAndSettle();
  }
  return store;
}

NestedScrollViewState nested(WidgetTester tester) => tester
    .state<NestedScrollViewState>(find.byKey(const ValueKey('profile-scroll')));

TabController tabs(WidgetTester tester) => DefaultTabController.of(
  tester.element(find.byKey(const ValueKey('profile-scroll'))),
);

Future<void> select(WidgetTester tester, String tab) async {
  final target = find.byKey(ValueKey('profile-tab-$tab'));
  await Scrollable.of(
    tester.element(target),
    axis: Axis.horizontal,
  ).position.ensureVisible(tester.renderObject(target));
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> pullAt(WidgetTester tester, Offset start) async {
  final gesture = await tester.startGesture(start);
  for (var i = 0; i < 6; i++) {
    await gesture.moveBy(const Offset(0, 55));
    await tester.pump(const Duration(milliseconds: 40));
  }
  await gesture.up();
  await tester.pumpAndSettle();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'Fast profile flings continue into content after collapsing the header',
    (tester) async {
      await mount(tester, ProfileContentGateway());
      await tester.flingFrom(
        const Offset(300, 540),
        const Offset(0, -120),
        1500,
      );
      await tester.pumpAndSettle();
      final outer = nested(tester).outerController;
      expect(outer.offset, closeTo(outer.position.maxScrollExtent, .5));
      final list = find.descendant(
        of: find.byKey(const PageStorageKey('profile-articles')),
        matching: find.byWidgetPredicate(
          (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
        ),
      );
      expect(
        tester.state<ScrollableState>(list).position.pixels,
        greaterThan(0),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Partial profile drags spring to the endpoint in either direction',
    (tester) async {
      await mount(tester, ProfileContentGateway());
      final outer = nested(tester).outerController;
      Future<void> slowDrag(double distance) async {
        final gesture = await tester.startGesture(const Offset(300, 540));
        for (var i = 0; i < 5; i++) {
          await gesture.moveBy(Offset(0, distance / 5));
          await tester.pump(const Duration(milliseconds: 30));
        }
        expect(outer.offset, greaterThan(0));
        expect(outer.offset, lessThan(outer.position.maxScrollExtent));
        await tester.pump(const Duration(milliseconds: 200));
        await gesture.up();
        await tester.pumpAndSettle();
      }

      await slowDrag(-80);
      expect(outer.offset, closeTo(outer.position.maxScrollExtent, .5));
      await slowDrag(80);
      expect(outer.offset, closeTo(0, .5));
      expect(find.byType(ProfileDetailsPage), findsNothing);
      outer.jumpTo(outer.position.maxScrollExtent / 2);
      await tester.pumpAndSettle();
      expect(outer.offset, closeTo(outer.position.maxScrollExtent / 2, .5));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'A profile snap can be interrupted and reversed by another drag',
    (tester) async {
      await mount(tester, ProfileContentGateway());
      final outer = nested(tester).outerController;
      final up = await tester.startGesture(const Offset(300, 540));
      await up.moveBy(const Offset(0, -80));
      await tester.pump(const Duration(milliseconds: 200));
      await up.up();
      await tester.pump(const Duration(milliseconds: 70));
      final down = await tester.startGesture(const Offset(300, 540));
      await down.moveBy(const Offset(0, 60));
      await tester.pump(const Duration(milliseconds: 200));
      await down.up();
      await tester.pumpAndSettle();
      expect(outer.offset, closeTo(0, .5));
      expect(find.byType(ProfileDetailsPage), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Profile actions follow a swipe before it settles', (
    tester,
  ) async {
    await mount(tester, ProfileContentGateway());
    final bar = tester.getRect(find.byKey(const ValueKey('profile-tabs')));
    final start = Offset(320, bar.bottom + 35);
    final publish = find
        .byKey(const ValueKey('profile-publish-article'))
        .hitTestable();
    final add = find.byKey(const ValueKey('profile-add-resume')).hitTestable();
    final controller = DefaultTabController.of(
      tester.element(find.byType(TabBar)),
    );
    var gesture = await tester.startGesture(start);
    await gesture.moveBy(const Offset(-20, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(-230, 0));
    await tester.pump(const Duration(milliseconds: 16));
    expect(controller.index, 0); // The page drag has not settled yet.
    expect(controller.animation!.value, greaterThan(.5));
    expect(publish, findsNothing);
    expect(add, findsNothing);
    await gesture.moveBy(const Offset(250, 0));
    await tester.pump(const Duration(milliseconds: 16));
    expect(publish, findsOneWidget);
    await gesture.up();
    await tester.pumpAndSettle();

    await select(tester, 'saved');
    gesture = await tester.startGesture(start);
    await gesture.moveBy(const Offset(-20, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(-230, 0));
    await tester.pump(const Duration(milliseconds: 16));
    expect(controller.index, 1);
    expect(controller.animation!.value, greaterThan(1.5));
    expect(add, findsOneWidget);
    await gesture.moveBy(const Offset(250, 0));
    await tester.pump(const Duration(milliseconds: 16));
    expect(add, findsNothing);
    await gesture.up();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('profile-tab-resumes')));
    await tester.pump();
    expect(controller.indexIsChanging, isTrue);
    expect(add, findsOneWidget);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('profile-tab-saved')));
    await tester.pump();
    expect(controller.indexIsChanging, isTrue);
    expect(add, findsNothing);
    expect(publish, findsNothing);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Profile tab actions align with tabs and open their matching creation flow',
    (tester) async {
      await mount(tester, ProfileContentGateway());
      final publish = find.byKey(const ValueKey('profile-publish-article'));
      expect(publish, findsOneWidget);
      expect(
        tester.getCenter(publish).dy,
        closeTo(
          tester.getCenter(find.byKey(const ValueKey('profile-tabs'))).dy,
          1,
        ),
      );
      await tester.tap(publish);
      await tester.pumpAndSettle();
      expect(find.byType(StoryComposer), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await select(tester, 'saved');
      expect(find.text('发表动态').hitTestable(), findsNothing);
      expect(find.text('添加简历').hitTestable(), findsNothing);
      await select(tester, 'resumes');
      final add = find.byKey(const ValueKey('profile-add-resume'));
      expect(add, findsOneWidget);
      expect(
        find.descendant(of: find.byType(ResumeLibrary), matching: add),
        findsNothing,
      );
      expect(
        tester.getCenter(add).dy,
        closeTo(
          tester.getCenter(find.byKey(const ValueKey('profile-tabs'))).dy,
          1,
        ),
      );
      await tester.tap(add);
      await tester.pumpAndSettle();
      expect(find.text('手动添加'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Discovery menu opens the shared drawer and preserves search', (
    tester,
  ) async {
    await mount(tester, ProfileContentGateway(), shell: true);
    await tester.tap(find.byKey(const ValueKey('nav-0')));
    await tester.pumpAndSettle();
    final field = find.byKey(const ValueKey('discovery-search'));
    await tester.enterText(field, '简历');
    await tester.pumpAndSettle();
    final menu = find.byKey(const ValueKey('discovery-menu'));
    expect(
      tester.getRect(menu).right,
      lessThanOrEqualTo(tester.getRect(field).left),
    );
    await tester.tap(menu);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('profile-drawer')), findsOneWidget);
    final editor = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const ValueKey('discovery-search'), skipOffstage: false),
        matching: find.byType(EditableText, skipOffstage: false),
      ),
    );
    expect(editor.focusNode.hasFocus, isFalse);
    await tester.tap(find.text('隐私与设置'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsPage), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('profile-drawer')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('profile-menu-close')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('discovery-search')), findsOneWidget);
    expect(tester.widget<TextField>(field).controller!.text, '简历');
    expect(tester.takeException(), isNull);
  });

  for (final dark in [false, true]) {
    testWidgets(
      'Certified profile displays its badge and removes the application, dark=$dark',
      (tester) async {
        final api = ProfileContentGateway()
          ..documents['GetMeIdentityVerification'] = {
            'status': 'VERIFIED',
            'valid_until': '2099-12-31',
          };
        await mount(
          tester,
          api,
          size: const Size(320, 700),
          scale: 2,
          dark: dark,
        );
        expect(
          find.byKey(const ValueKey('profile-developer-badge')),
          findsOneWidget,
        );
        expect(find.text('开发者认证'), findsNothing);
        await tester.tap(find.byKey(const ValueKey('profile-menu')));
        await tester.pumpAndSettle();
        expect(find.text('申请开发者认证'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'The open profile menu updates when the server confirms certification',
    (tester) async {
      final api = ProfileContentGateway();
      final store = await mount(tester, api);
      await tester.tap(find.byKey(const ValueKey('profile-menu')));
      await tester.pumpAndSettle();
      expect(find.text('申请开发者认证'), findsOneWidget);
      api.documents['GetMeIdentityVerification'] = {
        'status': 'VERIFIED',
        'valid_until': '2099-12-31',
      };
      await store.load('identity');
      await tester.pumpAndSettle();
      expect(find.text('申请开发者认证'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('profile-menu-close')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('profile-developer-badge')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final tab in ['articles', 'saved', 'resumes']) {
      testWidgets('Pulling $tab refreshes only the active list ($platform)', (
        tester,
      ) async {
        final api = ProfileContentGateway();
        await mount(tester, api);
        for (final visited in ['saved', 'resumes', 'articles']) {
          await select(tester, visited);
        }
        await select(tester, tab);
        api.calls.clear();
        final bar = tester.getRect(find.byKey(const ValueKey('profile-tabs')));
        await pullAt(tester, Offset(bar.center.dx, bar.bottom + 35));
        expect(find.byType(ProfileDetailsPage), findsNothing);
        expect(api.calls, [
          switch (tab) {
            'articles' => 'GetMeArticles',
            'saved' => 'GetMeFavorites',
            _ => 'GetResumes',
          },
        ]);
        expect(tester.takeException(), isNull);
      }, variant: TargetPlatformVariant({platform}));

      testWidgets(
        'Pulling the header over $tab never refreshes tab content ($platform)',
        (tester) async {
          final api = ProfileContentGateway();
          await mount(tester, api);
          for (final visited in ['saved', 'resumes', 'articles']) {
            await select(tester, visited);
          }
          await select(tester, tab);
          api.calls.clear();
          final header = tester.getRect(
            find.byKey(const ValueKey('profile-header')),
          );
          await pullAt(tester, Offset(header.left + 60, header.top + 120));
          expect(find.byType(ProfileDetailsPage), findsNothing);
          expect(api.calls, isEmpty);
          expect(
            api.calls,
            isNot(
              contains(anyOf('GetMeArticles', 'GetMeFavorites', 'GetResumes')),
            ),
          );
          expect(tester.takeException(), isNull);
        },
        variant: TargetPlatformVariant({platform}),
      );
    }
  }
  testWidgets(
    'A top-origin drag can reverse to refresh without opening details',
    (tester) async {
      final api = ProfileContentGateway();
      await mount(tester, api);
      api.calls.clear();
      final bar = tester.getRect(find.byKey(const ValueKey('profile-tabs')));
      final gesture = await tester.startGesture(
        Offset(bar.center.dx, bar.bottom + 35),
      );
      await gesture.moveBy(const Offset(0, -100));
      await tester.pump(const Duration(milliseconds: 40));
      for (var i = 0; i < 6; i++) {
        await gesture.moveBy(const Offset(0, 70));
        await tester.pump(const Duration(milliseconds: 40));
      }
      await gesture.up();
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(find.byType(ProfileDetailsPage), findsNothing);
      expect(api.calls, ['GetMeArticles']);
      final header = tester.getRect(
        find.byKey(const ValueKey('profile-header')),
      );
      await pullAt(tester, Offset(header.left + 60, header.top + 120));
      expect(find.byType(ProfileDetailsPage), findsNothing);
      expect(api.calls, ['GetMeArticles']);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('A canceled header pull cannot claim the next content gesture', (
    tester,
  ) async {
    final api = ProfileContentGateway();
    await mount(tester, api);
    api.calls.clear();
    final header = tester.getRect(find.byKey(const ValueKey('profile-header')));
    final gesture = await tester.startGesture(
      Offset(header.left + 60, header.top + 120),
    );
    await gesture.moveBy(const Offset(0, 220));
    await tester.pump();
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(api.calls, isEmpty);
    final bar = tester.getRect(find.byKey(const ValueKey('profile-tabs')));
    await pullAt(tester, Offset(bar.center.dx, bar.bottom + 35));
    expect(find.byType(ProfileDetailsPage), findsNothing);
    expect(api.calls, ['GetMeArticles']);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'A drag starting below the list top only returns the scroll position',
    (tester) async {
      final api = ProfileContentGateway();
      await mount(tester, api);
      nested(tester).outerController
          .jumpTo(nested(tester).outerController.position.maxScrollExtent);
      await tester.pumpAndSettle();
      final list = find.descendant(
        of: find.byKey(const PageStorageKey('profile-articles')),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Scrollable &&
              widget.axisDirection == AxisDirection.down,
        ),
      );
      final position = tester.state<ScrollableState>(list).position;
      position.jumpTo(400);
      await tester.pumpAndSettle();
      api.calls.clear();
      final bar = tester.getRect(find.byKey(const ValueKey('profile-tabs')));
      await pullAt(tester, Offset(bar.center.dx, bar.bottom + 35));
      expect(find.byType(ProfileDetailsPage), findsNothing);
      expect(api.calls, isEmpty);
      expect(position.pixels, lessThan(400));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Scrolling back up a list does not expand the header while another tab rests at its top',
    (tester) async {
      final api = ProfileContentGateway();
      await mount(tester, api);
      // Visiting a tab keeps its list alive at offset zero.
      await select(tester, 'saved');
      await select(tester, 'articles');
      final outer = nested(tester).outerController;
      outer.jumpTo(outer.position.maxScrollExtent);
      await tester.pumpAndSettle();
      ScrollPosition articles() => tester
          .state<ScrollableState>(
            find.descendant(
              of: find.byKey(const PageStorageKey('profile-articles')),
              matching: find.byWidgetPredicate(
                (widget) =>
                    widget is Scrollable &&
                    widget.axisDirection == AxisDirection.down,
              ),
            ),
          )
          .position;
      articles().jumpTo(400);
      await tester.pumpAndSettle();
      final bar = tester.getRect(find.byKey(const ValueKey('profile-tabs')));
      await tester.dragFrom(
        Offset(bar.center.dx, bar.bottom + 60),
        const Offset(0, 150),
      );
      await tester.pumpAndSettle();
      expect(outer.offset, closeTo(outer.position.maxScrollExtent, .5));
      expect(articles().pixels, lessThan(400));
      expect(articles().pixels, greaterThan(0));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Profile tabs omit search and keep published content and scroll position',
    (tester) async {
      final api = ProfileContentGateway();
      await mount(tester, api);
      expect(find.byType(MyArticlesPage), findsOneWidget);
      expect(find.text('动态'), findsOneWidget);
      expect(find.text('收藏'), findsOneWidget);
      expect(find.text('简历'), findsOneWidget);
      expect(find.byKey(const ValueKey('my-articles-search')), findsNothing);
      expect(find.byType(TextField), findsNothing);
      expect(find.text('我的积分'), findsNothing);
      expect(find.text('隐私与设置'), findsNothing);
      expect(api.statuses, ['PUBLISHED']);
      for (final status in ['SUBMITTED', 'PUBLISHED', 'DRAFT', 'REJECTED']) {
        expect(find.byKey(ValueKey('articles-$status')), findsNothing);
      }
      expect(find.textContaining('未发布文章'), findsNothing);
      nested(tester).outerController
          .jumpTo(nested(tester).outerController.position.maxScrollExtent);
      await tester.pumpAndSettle();
      final articleState = tester.state(find.byType(MyArticlesPage));
      expect(api.statuses.last, 'PUBLISHED');
      ScrollPosition articlePosition() => tester
          .state<ScrollableState>(
            find.descendant(
              of: find.byKey(const PageStorageKey('profile-articles')),
              matching: find.byWidgetPredicate(
                (widget) =>
                    widget is Scrollable &&
                    widget.axisDirection == AxisDirection.down,
              ),
            ),
          )
          .position;
      articlePosition().jumpTo(120);
      await tester.pumpAndSettle();
      await tester.dragFrom(const Offset(280, 450), const Offset(-300, 0));
      await tester.pumpAndSettle();
      expect(tabs(tester).index, 1);
      expect(find.byType(SavedArticlesPage), findsOneWidget);
      expect(
        find.byKey(const ValueKey('profile-write-article')).hitTestable(),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('saved-search')), findsNothing);
      expect(find.byType(TextField), findsNothing);
      expect(find.text('收藏的经验分享'), findsOneWidget);
      await tester.dragFrom(const Offset(280, 450), const Offset(-300, 0));
      await tester.pumpAndSettle();
      expect(tabs(tester).index, 2);
      expect(find.byType(ResumeLibrary), findsOneWidget);
      expect(find.text('添加简历'), findsOneWidget);
      expect(find.text('创建简历'), findsNothing);
      expect(find.text('导入简历'), findsNothing);
      for (final text in ['找到适合你的模版', '简历库', '最近更新']) {
        expect(find.text(text), findsNothing);
      }
      expect(find.text('产品经理 · 社招简历'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('profile-add-resume')));
      await tester.pumpAndSettle();
      for (final label in ['AI生成简历', '手动添加', '从微信导入', '从手机文件导入']) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.byType(BottomSheet), findsOneWidget);
      await tester.tap(find.text('手动添加'));
      await tester.pumpAndSettle();
      expect(find.byType(ResumeEditor), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('profile-add-resume')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('从微信导入'));
      await tester.pumpAndSettle();
      expect(find.byType(ImportResume), findsOneWidget);
      expect(
        tester.widget<ImportResume>(find.byType(ImportResume)).initialSource,
        ResumeImportSource.wechat,
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await select(tester, 'articles');
      expect(tester.state(find.byType(MyArticlesPage)), same(articleState));
      expect(articlePosition().pixels, closeTo(120, .01));
      articlePosition().jumpTo(0);
      await tester.pumpAndSettle();
      expect(api.statuses, ['PUBLISHED']);
      await select(tester, 'saved');
      await tester.tap(find.byKey(const ValueKey('saved-remove-1')));
      await tester.pumpAndSettle();
      expect(api.saved, isFalse);
      expect(find.text('还没有收藏的文章'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Activity cards use the current profile and update with its identity',
    (tester) async {
      final api = ProfileContentGateway();
      final store = await mount(tester, api);
      nested(tester).outerController
          .jumpTo(nested(tester).outerController.position.maxScrollExtent);
      await tester.pumpAndSettle();
      final author = find.byKey(const ValueKey('profile-story-1'));
      final avatar = find.descendant(
        of: author,
        matching: find.byType(ProfileAvatar),
      );
      expect(find.text('已发布'), findsNothing);
      expect(
        find.descendant(of: author, matching: find.text(store.name)),
        findsOneWidget,
      );
      expect(
        tester.widget<ProfileAvatar>(avatar).seed,
        profileAvatarSeed(store),
      );
      expect(tester.widget<ProfileAvatar>(avatar).url, store.avatarURL);
      expect(
        find.descendant(of: avatar, matching: find.byType(CustomPaint)),
        findsOneWidget,
      );
      store.name = '修改后的用户昵称';
      store.avatarURL = 'https://example.com/current-avatar.png';
      store.changed();
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: author, matching: find.text('修改后的用户昵称')),
        findsOneWidget,
      );
      expect(tester.widget<ProfileAvatar>(avatar).url, store.avatarURL);
      store.name = ' ';
      store.changed();
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: author, matching: find.text('未设置用户昵称')),
        findsOneWidget,
      );
      expect(store.name, ' ');
      await tester.tap(find.text('我的文章 1'));
      await tester.pumpAndSettle();
      expect(api.calls, contains('GetArticlesId'));
      expect(find.byType(MyArticlesPage), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Profile activities have no floating publish action', (
    tester,
  ) async {
    final api = ProfileContentGateway();
    await mount(tester, api, shell: true);
    nested(tester).outerController
        .jumpTo(nested(tester).outerController.position.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('profile-write-article')), findsNothing);
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.byTooltip('发布动态'), findsNothing);
    for (final tab in ['saved', 'resumes', 'articles']) {
      await select(tester, tab);
      expect(find.byType(FloatingActionButton), findsNothing);
    }
    expect(api.calls, isNot(contains('PostArticles')));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Published articles retain their filter for pagination and retry',
    (tester) async {
      final api = ProfileContentGateway()..paginateArticles = true;
      await mount(tester, api);
      nested(tester).outerController
          .jumpTo(nested(tester).outerController.position.maxScrollExtent);
      await tester.pumpAndSettle();
      final list = find.descendant(
        of: find.byKey(const PageStorageKey('profile-articles')),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Scrollable &&
              widget.axisDirection == AxisDirection.down,
        ),
      );
      await tester.scrollUntilVisible(find.text('加载更多'), 400, scrollable: list);
      await tester.pumpAndSettle();
      api.failArticles = true;
      await tester.tap(find.text('加载更多'));
      await tester.pumpAndSettle();
      tester.state<ScrollableState>(list).position.jumpTo(0);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('重新加载'));
      await tester.pumpAndSettle();
      expect(find.text('服务器暂不可用'), findsOneWidget);
      api.failArticles = false;
      await tester.tap(find.text('重新加载'));
      await tester.pumpAndSettle();
      expect(api.articleQueries, [
        {'status': 'PUBLISHED', 'limit': '20'},
        {'status': 'PUBLISHED', 'limit': '20', 'cursor': 'page-2'},
        {'status': 'PUBLISHED', 'limit': '20', 'cursor': 'page-2'},
      ]);
      final position = tester.state<ScrollableState>(list).position;
      position.jumpTo(position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(find.text('我的文章 24').hitTestable(), findsOneWidget);
      expect(find.textContaining('未发布文章'), findsNothing);
      expect(find.text('加载更多'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Embedded resumes keep empty states and can reload and preview drafts',
    (tester) async {
      final api = ProfileContentGateway();
      final store = await mount(tester, api);
      nested(tester).outerController
          .jumpTo(nested(tester).outerController.position.maxScrollExtent);
      await tester.pumpAndSettle();
      await select(tester, 'resumes');
      store.resumes.clear();
      store.changed();
      await tester.pumpAndSettle();
      expect(find.text('这里还没有内容'), findsOneWidget);
      expect(find.text('创建你的第一份简历'), findsNothing);
      store.errors['resumes'] = '服务器暂不可用';
      store.changed();
      await tester.pumpAndSettle();
      expect(find.text('这里还没有内容'), findsNothing);
      await tester.tap(find.text('重新加载'));
      await tester.pumpAndSettle();
      expect(api.calls, contains('GetResumes'));
      expect(find.text('产品经理 · 社招简历'), findsOneWidget);
      expect(find.text('添加简历'), findsOneWidget);
      expect(find.text('创建简历'), findsNothing);
      expect(find.text('导入简历'), findsNothing);
      for (final text in ['找到适合你的模版']) {
        expect(find.text(text), findsNothing);
      }
      await tester.tap(find.byType(LinearProgressIndicator));
      await tester.pumpAndSettle();
      expect(find.byType(ResumePreview), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Menu identity updates live and points keeps the drawer for return',
    (tester) async {
      final api = ProfileContentGateway();
      final store = await mount(tester, api, shell: true);
      store.points = null;
      store.changed();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('profile-menu')));
      await tester.pumpAndSettle();
      final identity = find.byKey(const ValueKey('profile-menu-identity'));
      final avatar = tester.widget<ProfileAvatar>(
        find.descendant(of: identity, matching: find.byType(ProfileAvatar)),
      );
      expect(avatar.seed, '${store.userID}');
      expect(avatar.url, store.avatarURL);
      expect(avatar.size, 44);
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('profile-menu-balance')))
            .data,
        '积分余额：—',
      );
      store.name = '更新后的昵称';
      store.points = 321;
      store.changed();
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('profile-menu-name')))
            .data,
        '更新后的昵称',
      );
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('profile-menu-balance')))
            .data,
        '积分余额：321',
      );
      final close = find.byKey(const ValueKey('profile-menu-close'));
      final scan = find.byKey(const ValueKey('profile-menu-scan'));
      expect(tester.getCenter(close).dx, lessThan(tester.getCenter(scan).dx));
      expect(tester.widget<IconButton>(scan).onPressed, isNotNull);
      final calls = List<String>.of(api.calls);
      expect(find.byKey(const ValueKey('profile-drawer')), findsOneWidget);
      expect(api.calls, calls);
      await tester.tap(find.byKey(const ValueKey('profile-menu-points')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('profile-drawer')), findsNothing);
      expect(
        find.byKey(const ValueKey('profile-drawer'), skipOffstage: false),
        findsOneWidget,
      );
      expect(find.byType(PointsPage), findsOneWidget);
      expect(
        tester
            .state<AppShellState>(find.byType(AppShell, skipOffstage: false))
            .selected,
        3,
      );
      expect(api.calls, isNot(contains('PostWalletDailyRewardClaims')));
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('profile-drawer')), findsOneWidget);
      expect(find.text('积分余额：${store.points}'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('profile-menu-close')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('profile-drawer'), skipOffstage: false),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'The left menu opens a dedicated draft box and preserves profile tabs',
    (tester) async {
      final api = ProfileContentGateway();
      await mount(tester, api);
      expect(find.text('草稿箱'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('profile-menu')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('profile-points-card')), findsNothing);
      expect(find.text('模板市场'), findsNothing);
      expect(find.text('身份认证'), findsNothing);
      expect(find.text('隐私与设置'), findsOneWidget);
      expect(find.byKey(const ValueKey('account-sign-out')), findsOneWidget);
      await tester.ensureVisible(find.text('草稿箱'));
      await tester.tap(find.text('草稿箱'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('profile-drawer')), findsNothing);
      expect(find.text('草稿箱'), findsOneWidget);
      expect(
        tester.widget<MyArticlesPage>(find.byType(MyArticlesPage)).draftsOnly,
        isTrue,
      );
      expect(api.statuses, ['PUBLISHED', 'DRAFT']);
      expect(find.byKey(const ValueKey('articles-SUBMITTED')), findsNothing);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('profile-drawer')), findsOneWidget);
      // A second visit reuses the same retained drawer, without stacking menus.
      await tester.tap(find.text('草稿箱'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('profile-drawer'), skipOffstage: false),
        findsOneWidget,
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('profile-menu-close')));
      await tester.pumpAndSettle();
      expect(tabs(tester).index, 0);
      expect(
        tester
            .widget<MyArticlesPage>(find.byType(MyArticlesPage))
            .publishedOnly,
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'The menu blocks page scrolling and footer taps until dismissed',
    (tester) async {
      await mount(tester, ProfileContentGateway(), shell: true);
      final state = tester.state<AppShellState>(find.byType(AppShell));
      final initialOffset = nested(tester).outerController.offset;
      await tester.tap(find.byKey(const ValueKey('profile-menu')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('nav-1')).hitTestable(), findsNothing);
      await tester.dragFrom(const Offset(370, 400), const Offset(0, -180));
      await tester.pumpAndSettle();
      expect(state.selected, 3);
      expect(nested(tester).outerController.offset, initialOffset);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('profile-drawer')), findsNothing);
      expect(find.byKey(const ValueKey('nav-1')).hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Signing out while the menu is open removes private menu content',
    (tester) async {
      final store = await mount(tester, ProfileContentGateway());
      await tester.tap(find.byKey(const ValueKey('profile-menu')));
      await tester.pumpAndSettle();
      await store.endSession(remote: false);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('profile-drawer')), findsNothing);
      expect(find.byKey(const ValueKey('profile-tabs')), findsNothing);
      expect(find.byType(SettingsPage), findsNothing);
      expect(find.byType(MyArticlesPage), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Signing out beneath an opened destination removes the retained drawer',
    (tester) async {
      final store = await mount(tester, ProfileContentGateway());
      await tester.tap(find.byKey(const ValueKey('profile-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('隐私与设置'));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsPage), findsOneWidget);
      expect(
        find.byKey(const ValueKey('profile-drawer'), skipOffstage: false),
        findsOneWidget,
      );
      await store.endSession(remote: false);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('profile-drawer'), skipOffstage: false),
        findsNothing,
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('profile-menu-identity')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Scrolling article content collapses the header and leaves tabs below it',
    (tester) async {
      await mount(tester, ProfileContentGateway());
      final viewport = tester.getRect(
        find.byKey(const ValueKey('profile-scroll')),
      );
      await tester.dragFrom(
        Offset(viewport.center.dx, viewport.bottom - 70),
        const Offset(0, -500),
      );
      await tester.pumpAndSettle();
      expect(nested(tester).outerController.offset, greaterThan(0));
      nested(tester).outerController
          .jumpTo(nested(tester).outerController.position.maxScrollExtent);
      await tester.pumpAndSettle();
      final compact = tester.getRect(
        find.byKey(const ValueKey('profile-menu')),
      );
      final tabBar = tester.getRect(find.byKey(const ValueKey('profile-tabs')));
      expect(
        compact.top,
        closeTo(
          viewport.top +
              MediaQuery.paddingOf(
                tester.element(find.byKey(const ValueKey('profile-menu'))),
              ).top,
          .01,
        ),
      );
      expect(tabBar.top, greaterThanOrEqualTo(compact.bottom - .01));
      expect(find.byTooltip('发布动态').hitTestable(), findsNothing);
      expect(
        tester
            .getRect(find.byKey(const PageStorageKey('profile-articles')))
            .top,
        greaterThanOrEqualTo(tabBar.bottom - .01),
      );
      expect(
        find.byKey(const ValueKey('profile-menu')).hitTestable(),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('profile-menu')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('profile-drawer')), findsOneWidget);
      expect(find.byKey(const ValueKey('profile-points-card')), findsNothing);
      expect(find.text('模板市场'), findsNothing);
      expect(find.text('身份认证'), findsNothing);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  for (final config in [
    (size: const Size(320, 640), scale: 1.0, dark: false),
    (size: const Size(320, 640), scale: 2.0, dark: true),
    (size: const Size(844, 360), scale: 2.0, dark: false),
  ]) {
    testWidgets('Profile menu and all pages remain usable at $config', (
      tester,
    ) async {
      tester.view.padding = const FakeViewPadding(top: 24, bottom: 20);
      tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 20);
      addTearDown(tester.view.resetPadding);
      addTearDown(tester.view.resetViewPadding);
      final api = ProfileContentGateway();
      final store = await mount(
        tester,
        api,
        size: config.size,
        scale: config.scale,
        dark: config.dark,
      );
      store.name = '一个很长的用户昵称，用来确认动态卡片头像旁边的文字不会溢出';
      store.changed();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('profile-menu')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('profile-drawer')), findsOneWidget);
      expect(find.byKey(const ValueKey('profile-points-card')), findsNothing);
      expect(find.text('模板市场'), findsNothing);
      expect(find.text('身份认证'), findsNothing);
      final drawer = find.byKey(const ValueKey('profile-drawer'));
      final drawerRect = tester.getRect(drawer);
      final signOut = find.byKey(const ValueKey('account-sign-out'));
      final signOutRect = tester.getRect(signOut);
      expect(drawerRect.width, lessThanOrEqualTo(280));
      expect(signOutRect.bottom, closeTo(config.size.height - 20 - 16, .01));
      expect(signOut.hitTestable(), findsOneWidget);
      expect(
        tester.getSize(find.byKey(const ValueKey('profile-menu-close'))),
        const Size(44, 44),
      );
      final draftRow = find.widgetWithText(ListTile, '草稿箱');
      if (config.scale == 1) {
        expect(tester.getSize(draftRow).height, 48);
        expect(signOutRect.height, 44);
      }
      expect(
        find.descendant(of: drawer, matching: find.byType(Divider)),
        findsNothing,
      );
      final menuScroll = find.descendant(
        of: find.byKey(const ValueKey('profile-drawer')),
        matching: find.byType(Scrollable),
      );
      await tester.scrollUntilVisible(
        find.text('申请开发者认证'),
        100,
        scrollable: menuScroll,
      );
      await tester.ensureVisible(find.text('申请开发者认证'));
      await tester.pumpAndSettle();
      final callsBeforeCertification = List<String>.of(api.calls);
      await tester.tap(find.text('申请开发者认证'));
      await tester.pumpAndSettle();
      expect(find.byType(DeveloperVerificationPage), findsOneWidget);
      expect(find.text('本人实名认证'), findsOneWidget);
      final titleRect = tester.getRect(find.text('开发者认证'));
      expect(
        titleRect.left,
        greaterThanOrEqualTo(tester.getRect(find.byType(BackButton)).right),
      );
      expect(titleRect.left, lessThan(config.size.width / 3));
      expect(find.byTooltip('认证帮助'), findsNothing);
      expect(find.text('当前仅本机预览，暂不提交认证资料'), findsNothing);
      expect(find.text('请使用本人有效证件，确保信息真实、照片清晰'), findsNothing);
      expect(api.calls, callsBeforeCertification);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('开发者认证暂未开放'), findsNothing);
      expect(find.byKey(const ValueKey('profile-drawer')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.text('隐私与设置'),
        100,
        scrollable: menuScroll,
      );
      await tester.ensureVisible(find.text('隐私与设置'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('隐私与设置'));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsPage), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('profile-drawer')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('profile-menu-close')));
      await tester.pumpAndSettle();
      expect(tabs(tester).index, 0);
      nested(tester).outerController
          .jumpTo(nested(tester).outerController.position.maxScrollExtent);
      await tester.pumpAndSettle();
      for (final tab in ['saved', 'resumes', 'articles']) {
        await select(tester, tab);
        expect(find.byKey(const ValueKey('my-articles-search')), findsNothing);
        expect(find.byKey(const ValueKey('saved-search')), findsNothing);
        expect(tester.takeException(), isNull);
      }
      expect(find.byKey(const ValueKey('profile-write-article')), findsNothing);
    });
  }
}
