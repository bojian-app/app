import 'dart:io';
import 'dart:ui' as ui;

import 'package:bojian_mobile/account_pages.dart';
import 'package:bojian_mobile/app_shell.dart';
import 'package:bojian_mobile/design.dart';
import 'package:bojian_mobile/discovery.dart';
import 'package:bojian_mobile/my_articles_page.dart';
import 'package:bojian_mobile/profile_edit_actions.dart';
import 'package:bojian_mobile/resume_native_export.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

ThemeData previewTheme(ThemeData theme) => theme.copyWith(
  textTheme: theme.textTheme.apply(fontFamily: 'ReferenceLayoutPreview'),
  textButtonTheme: TextButtonThemeData(
    style: theme.textButtonTheme.style?.copyWith(
      textStyle: WidgetStatePropertyAll(
        theme.textTheme.labelLarge?.copyWith(
          fontFamily: 'ReferenceLayoutPreview',
          fontSize: 13,
        ),
      ),
    ),
  ),
);

Future<void> capture(WidgetTester tester, String name) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('reference-layout-preview')),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory('build/previews').create(recursive: true);
    await File('build/previews/$name.png')
        .writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUpAll(() async {
    await (FontLoader(
      'ReferenceLayoutPreview',
    )..addFont(rootBundle.load(resumeFontRegularAsset))).load();
  });

  for (final config in [
    (name: 'light', size: const Size(390, 844), scale: 1.0, dark: false),
    (name: 'dark', size: const Size(390, 844), scale: 1.0, dark: true),
    (name: 'small', size: const Size(320, 640), scale: 1.5, dark: true),
    (name: 'landscape', size: const Size(844, 360), scale: 1.3, dark: false),
  ]) {
    testWidgets(
      'Reference layouts preserve real content and routes (${config.name})',
      (tester) async {
        tester.view.physicalSize = config.size;
        tester.view.devicePixelRatio = 1;
        tester.view.padding = const FakeViewPadding(top: 24);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPadding);
        final api = FakeGateway(seeded: true);
        api.documents['GetMeArticles'] = {
          'items': [
            {
              'id': 1,
              'title':
                  (api.documents['GetFeed']!['items'] as List).first['title'],
              'status': 'PUBLISHED',
              'published_at': '2026-10-07T00:00:00Z',
              'content':
                  (api.documents['GetFeed']!['items'] as List).first['content'],
              'comment_count': 0,
              'is_liked': false,
              'is_favorited': false,
            },
          ],
        };
        final store = await testStore(authenticated: true, api: api);
        addTearDown(store.dispose);
        store.name = config.scale > 1 ? '一个较长的个人昵称用于验证排版' : store.name;
        store.bio = config.scale > 1 ? '个人介绍内容。' * 15 : '';
        await tester.pumpWidget(
          RepaintBoundary(
            key: const ValueKey('reference-layout-preview'),
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: previewTheme(config.dark ? appDarkTheme : appTheme),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(config.scale)),
                child: child!,
              ),
              home: AppShell(store: store),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final story = store.stories.single;
        expect(find.text('企业福利'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('discovery-resume-card')),
          findsNothing,
        );
        expect(
          tester.getTopLeft(find.byType(TabBar)).dy,
          lessThan(tester.getTopLeft(find.text('企业福利')).dy),
        );
        if (config.size.height < 500) {
          await tester.drag(
            find.byType(NestedScrollView),
            const Offset(0, -200),
          );
          await tester.pumpAndSettle();
        }
        expect(find.text(story.title), findsOneWidget);
        expect(tester.widget<StoryCard>(find.byType(StoryCard)).flat, isTrue);
        expect(tester.takeException(), isNull);
        await capture(tester, 'discovery-reference-${config.name}');

        if (config.scale == 1) {
          await tester.tap(find.text('简历求指点'));
          await tester.pumpAndSettle();
          expect(find.text('还没有发布的内容'), findsOneWidget);
          expect(find.text(story.title), findsNothing);
          await capture(tester, 'discovery-reference-empty-${config.name}');
        }
        await tester.tap(find.byKey(const ValueKey('nav-3')));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('profile-identity-name')))
              .data,
          store.name,
        );
        expect(find.text('ID：${store.publicID}'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await capture(tester, 'profile-reference-${config.name}');

        expect(find.text('隐私与设置'), findsNothing);
        await tester.tap(find.byKey(const ValueKey('profile-menu')));
        await tester.pumpAndSettle();
        final menuScroll = find.descendant(
          of: find.byKey(const ValueKey('profile-drawer')),
          matching: find.byType(Scrollable),
        );
        await capture(tester, 'profile-menu-${config.name}');
        final signOut = find.byKey(const ValueKey('account-sign-out'));
        await tester.scrollUntilVisible(signOut, 180, scrollable: menuScroll);
        await tester.pumpAndSettle();
        await tester.tap(signOut);
        await tester.pumpAndSettle();
        expect(find.text('确定要退出登录么？'), findsOneWidget);
        await tester.tap(find.text('我再看看'));
        await tester.pumpAndSettle();
        expect(store.isAuthenticated, isTrue);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        final nested = tester.state<NestedScrollViewState>(
          find.byKey(const ValueKey('profile-scroll')),
        );
        nested.outerController.jumpTo(
          nested.outerController.position.maxScrollExtent,
        );
        await tester.pumpAndSettle();
        final profileTabs = find.byKey(const ValueKey('profile-tabs'));
        for (final label in ['动态', '收藏', '简历']) {
          expect(
            find.descendant(of: profileTabs, matching: find.text(label)),
            findsOneWidget,
          );
        }
        expect(find.byKey(const ValueKey('my-articles-search')), findsNothing);
        expect(find.byType(MyArticlesPage), findsOneWidget);
        final author = find.byKey(const ValueKey('profile-story-1'));
        expect(
          find.descendant(of: author, matching: find.text(store.name)),
          findsOneWidget,
        );
        expect(find.text('已发布'), findsNothing);
        await capture(tester, 'profile-tabs-${config.name}');
        final controller = DefaultTabController.of(
          tester.element(find.byKey(const ValueKey('profile-scroll'))),
        );
        controller.animateTo(1);
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('saved-search')), findsNothing);
        expect(tester.takeException(), isNull);
        await capture(tester, 'profile-saved-${config.name}');
        controller.animateTo(2);
        await tester.pumpAndSettle();
        expect(find.text('创建简历'), findsNothing);
        expect(find.text('导入简历'), findsNothing);
        expect(find.text('找到适合你的模版'), findsNothing);
        expect(tester.takeException(), isNull);
        await capture(tester, 'profile-resumes-${config.name}');
        nested.outerController.jumpTo(0);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('profile-identity-avatar')));
        await tester.pumpAndSettle();
        expect(find.byType(ProfileEditor), findsOneWidget);
        expect(
          tester.widget<ProfileEditor>(find.byType(ProfileEditor)).action,
          ProfileEditAction.avatar,
        );
        expect(
          find.byKey(const ValueKey('profile-edit-actions')),
          findsNothing,
        );
        expect(
          api.calls.where(
            (call) => call.startsWith('Post') || call.startsWith('Patch'),
          ),
          isEmpty,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
