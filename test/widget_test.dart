import 'package:bojian_mobile/main.dart';
import 'package:bojian_mobile/app_store.dart';
import 'package:bojian_mobile/account_pages.dart';
import 'package:bojian_mobile/resume_pages.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

Future<void> launch(
  WidgetTester tester, {
  double width = 390,
  AppStore? store,
}) async {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MyApp(
      nativeStartup: true,
      store: store ?? await testStore(authenticated: true),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Profile menu exposes sign out and clears the session', (
    tester,
  ) async {
    final api = FakeGateway();
    final store = await testStore(authenticated: true, api: api);
    await launch(tester, width: 360, store: store);
    await tester.tap(find.byKey(const ValueKey('nav-3')));
    await tester.pumpAndSettle();
    expect(find.text('每一点积累，都算数'), findsNothing);
    expect(find.text('动态'), findsOneWidget);
    expect(find.text('收藏'), findsOneWidget);
    expect(find.text('隐私与设置'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('profile-menu')));
    await tester.pumpAndSettle();
    expect(find.text('隐私与设置'), findsOneWidget);
    final signOut = find.byKey(const ValueKey('account-sign-out'));
    await tester.ensureVisible(signOut);
    await tester.pumpAndSettle();
    await tester.tap(signOut);
    await tester.pumpAndSettle();
    expect(store.isAuthenticated, isTrue);
    expect(api.calls, isNot(contains('PostAuthLogout')));
    expect(find.text('确定要退出登录么？'), findsOneWidget);
    expect(find.text('狠心离开'), findsOneWidget);
    expect(find.byType(CupertinoAlertDialog), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
    expect(
      tester.getCenter(find.byType(CupertinoAlertDialog)).dy,
      closeTo(422, 1),
    );
    final confirmButton = tester.widget<CupertinoDialogAction>(
      find.byKey(const ValueKey('confirm-sign-out')),
    );
    expect(confirmButton.isDestructiveAction, isTrue);
    await tester.tap(find.text('我再看看'));
    await tester.pumpAndSettle();
    await tester.tap(signOut);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-sign-out')));
    await tester.pumpAndSettle();
    expect(store.isAuthenticated, isFalse);
    expect(api.calls, contains('PostAuthLogout'));
    expect(find.byKey(const ValueKey('auth-wechat')), findsOneWidget);
    expect(find.byKey(const ValueKey('auth-phone')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Profile remains scrollable with long content in landscape', (
    tester,
  ) async {
    final store = await testStore(authenticated: true);
    store.name = '一个比较长的个人昵称用于检查排版';
    store.bio = '个人介绍内容。' * 15;
    await launch(tester, width: 844, store: store);
    await tester.tap(find.byKey(const ValueKey('nav-3')));
    await tester.pumpAndSettle();
    tester.view.physicalSize = const Size(844, 360);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('profile-menu')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('account-sign-out')),
      150,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('profile-drawer')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Discovery removes the resume card and the resume tab still creates drafts',
    (tester) async {
      final api = FakeGateway();
      final store = await testStore(authenticated: true, api: api);
      await launch(tester, store: store);
      expect(find.byKey(const ValueKey('discovery-resume-card')), findsNothing);
      expect(find.text('创建我的简历'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('nav-3')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('profile-tab-resumes')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('添加简历'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('手动添加'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<ResumeEditor>(find.byType(ResumeEditor)).draft.id,
        0,
      );
      expect(api.calls, isNot(contains('PostResumes')));
      expect(store.resumes, isEmpty);
    },
  );

  testWidgets('Discovery has no resume card across loading and draft states', (
    tester,
  ) async {
    final store = await testStore(authenticated: true);
    await launch(tester, store: store);
    for (final state in ['unknown', 'failed', 'empty', 'draft', 'complete']) {
      store.resumes.clear();
      store.resumesLoaded = state != 'unknown';
      store.errors.remove('resumes');
      if (state == 'failed') store.errors['resumes'] = '服务器暂不可用';
      if (state == 'draft' || state == 'complete') {
        store.resumes.add(
          ResumeDraft(
            id: 1,
            title: '我的简历',
            progress: state == 'draft' ? .75 : 1,
          ),
        );
      }
      store.changed();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('discovery-resume-card')), findsNothing);
      expect(find.text('创建我的简历'), findsNothing);
      expect(find.text('待完善简历'), findsNothing);
      expect(find.text('企业福利'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('Empty account shows real empty states and no sample people', (
    tester,
  ) async {
    await launch(tester);
    expect(find.text('还没有发布的内容'), findsOneWidget);
    expect(find.textContaining('陈一然'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('nav-3')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('profile-tab-resumes')));
    await tester.pumpAndSettle();
    expect(find.text('这里还没有内容'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('nav-1')));
    await tester.pumpAndSettle();
    expect(find.byType(TemplateMarket), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('nav-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('discovery-messages')));
    await tester.pumpAndSettle();
    expect(find.text('暂无系统通知'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('nav-3')));
    await tester.pumpAndSettle();
    expect(find.text('测试账号'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('profile-menu')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('profile-points-card')), findsNothing);
    expect(find.text('草稿箱'), findsOneWidget);
    expect(find.text('隐私与设置'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Failed server requests show retry rather than sample content', (
    tester,
  ) async {
    final api = FakeGateway()..failing = 'GetFeed';
    await launch(tester, store: await testStore(authenticated: true, api: api));
    expect(find.text('服务器暂不可用'), findsOneWidget);
    api.failing = null;
    await tester.tap(find.text('重新加载'));
    await tester.pumpAndSettle();
    expect(find.text('还没有发布的内容'), findsOneWidget);
  });
  testWidgets('Saving a resume uses server response before showing it', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await launch(
      tester,
      store: await testStore(authenticated: true, seeded: true),
    );
    await tester.tap(find.byKey(const ValueKey('nav-3')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('profile-tab-resumes')));
    await tester.pumpAndSettle();
    final card = find
        .ancestor(of: find.text('产品经理 · 社招简历'), matching: find.byType(InkWell))
        .last;
    await tester.tapAt(tester.getTopLeft(card) + const Offset(8, 30));
    await tester.pumpAndSettle();
    await tester.tap(find.text('编辑'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('resume-name')), '李明');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(
      find.bySemanticsLabel(RegExp('简历第.*李明', dotAll: true)),
      findsOneWidget,
    );
    semantics.dispose();
  });
  testWidgets('Narrow phone layouts fit all destinations', (tester) async {
    await launch(tester, width: 320);
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.byKey(ValueKey('nav-$i')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });
  testWidgets('Logout clears private account content and navigation stack', (
    tester,
  ) async {
    final store = await testStore(authenticated: true, seeded: true);
    await launch(tester, store: store);
    await tester.tap(find.byKey(const ValueKey('nav-3')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('profile-menu')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('account-sign-out')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('account-sign-out')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-sign-out')));
    await tester.pumpAndSettle();
    expect(store.resumes, isEmpty);
    expect(store.stories, isEmpty);
    expect(find.byKey(const ValueKey('auth-wechat')), findsOneWidget);
    expect(find.byType(SettingsPage), findsNothing);
  });
}
