import 'package:bojian_mobile/main.dart';
import 'package:bojian_mobile/app_store.dart';
import 'package:bojian_mobile/account_pages.dart';
import 'package:bojian_mobile/resume_pages.dart';
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
  testWidgets('Profile exposes sign out directly and clears the session', (
    tester,
  ) async {
    final api = FakeGateway();
    final store = await testStore(authenticated: true, api: api);
    await launch(tester, width: 360, store: store);
    await tester.tap(find.byKey(const ValueKey('nav-3')));
    await tester.pumpAndSettle();
    expect(find.text('每一点积累，都算数'), findsNothing);
    expect(find.text('我的文章'), findsOneWidget);
    expect(find.text('我的收藏'), findsOneWidget);
    expect(find.text('隐私与设置'), findsOneWidget);
    final signOut = find.byKey(const ValueKey('account-sign-out'));
    await tester.ensureVisible(signOut);
    await tester.tap(signOut);
    await tester.pumpAndSettle();
    expect(store.isAuthenticated, isTrue);
    expect(api.calls, isNot(contains('PostAuthLogout')));
    expect(find.text('确定要退出登录么？'), findsOneWidget);
    expect(find.text('狠心离开'), findsOneWidget);
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
    expect(tester.getCenter(find.byType(Dialog)).dy, closeTo(422, 1));
    final confirmButton = tester.widget<FilledButton>(
      find.byKey(const ValueKey('confirm-sign-out')),
    );
    final sheetContext = tester.element(
      find.byKey(const ValueKey('confirm-sign-out')),
    );
    expect(confirmButton.style?.backgroundColor, isNull);
    expect(
      Theme.of(sheetContext).filledButtonTheme.style!.backgroundColor!
          .resolve({}),
      const Color(0xFF2867EE),
    );
    await tester.tap(find.text('我再看看'));
    await tester.pumpAndSettle();
    await tester.tap(signOut);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-sign-out')));
    await tester.pumpAndSettle();
    expect(store.isAuthenticated, isFalse);
    expect(api.calls, contains('PostAuthLogout'));
    expect(find.byKey(const ValueKey('auth-phone')), findsOneWidget);
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
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('account-sign-out')),
      150,
      scrollable: find.descendant(
        of: find.byType(ProfilePage),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Discovery creates a resume directly without creating it early', (
    tester,
  ) async {
    final api = FakeGateway();
    final store = await testStore(authenticated: true, api: api);
    await launch(tester, store: store);
    expect(find.text('创建我的简历'), findsOneWidget);
    await tester.tap(find.text('创建简历'));
    await tester.pumpAndSettle();
    expect(tester.widget<ResumeEditor>(find.byType(ResumeEditor)).draft.id, 0);
    expect(find.text('简历库'), findsNothing);
    expect(api.calls, isNot(contains('PostResumes')));
    expect(store.resumes, isEmpty);
  });

  testWidgets(
    'Discovery opens the most complete draft and hides completed cards',
    (tester) async {
      final store = await testStore(authenticated: true);
      store.resumes.addAll([
        ResumeDraft(id: 1, title: '较早草稿', progress: .25),
        ResumeDraft(id: 2, title: '正在填写', progress: .75),
      ]);
      await launch(tester, store: store);
      expect(find.text('待完善简历'), findsOneWidget);
      expect(find.text('完善度 75%'), findsOneWidget);
      await tester.tap(find.text('继续完善'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<ResumeEditor>(find.byType(ResumeEditor)).draft.id,
        2,
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      store.resumes.last.progress = 1;
      store.changed();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('discovery-resume-card')), findsNothing);
    },
  );

  testWidgets(
    'Unknown or failed resume loading does not show a creation card',
    (tester) async {
      final store = await testStore(authenticated: true);
      store.resumesLoaded = false;
      await launch(tester, store: store);
      expect(find.byKey(const ValueKey('discovery-resume-card')), findsNothing);
      store.resumesLoaded = true;
      store.errors['resumes'] = '服务器暂不可用';
      store.changed();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('discovery-resume-card')), findsNothing);
      store.errors.remove('resumes');
      store.changed();
      await tester.pumpAndSettle();
      expect(find.text('创建我的简历'), findsOneWidget);
    },
  );

  testWidgets('Empty account shows real empty states and no sample people', (
    tester,
  ) async {
    await launch(tester);
    expect(find.text('还没有发布的内容'), findsOneWidget);
    expect(find.textContaining('陈一然'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('nav-1')));
    await tester.pumpAndSettle();
    expect(find.text('创建你的第一份简历'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('nav-2')));
    await tester.pumpAndSettle();
    expect(find.text('暂无系统通知'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('nav-3')));
    await tester.pumpAndSettle();
    expect(find.text('测试账号'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
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
    await tester.tap(find.byKey(const ValueKey('nav-1')));
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
    await tester.ensureVisible(find.byKey(const ValueKey('account-sign-out')));
    await tester.tap(find.byKey(const ValueKey('account-sign-out')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-sign-out')));
    await tester.pumpAndSettle();
    expect(store.resumes, isEmpty);
    expect(store.stories, isEmpty);
    expect(find.text('欢迎回到博简'), findsOneWidget);
    expect(find.byType(SettingsPage), findsNothing);
  });
}
