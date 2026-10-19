import 'dart:io';
import 'dart:ui' as ui;

import 'package:bojian_mobile/api/bojian_api.dart';
import 'package:bojian_mobile/app_store.dart';
import 'package:bojian_mobile/design.dart';
import 'package:bojian_mobile/guidance_coach.dart';
import 'package:bojian_mobile/guidance_help.dart';
import 'package:bojian_mobile/guidance_region_comments.dart';
import 'package:bojian_mobile/resume_document.dart';
import 'package:bojian_mobile/resume_native_export.dart';
import 'package:bojian_mobile/resume_guidance_annotations.dart';
import 'package:bojian_mobile/resume_guidance_share.dart';
import 'package:bojian_mobile/resume_guidance_view.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'resume_guidance_review_test.dart' as fixtures;
import 'support/fake_gateway.dart';

const original = '负责网站开发与性能优化，改善用户体验。';
const fieldPath = 'work_experiences.0.description';
const preview = {
  'snapshot': {
    'work_experiences': [
      {'description': original},
    ],
  },
};

class SceneGateway extends FakeGateway {
  @override
  Future<ApiDocument> call(
    String method, {
    Map<String, String> path = const {},
    Map<String, String> query = const {},
    Map<String, dynamic>? body,
    Map<String, String> headers = const {},
  }) async {
    final result = await super.call(
      method,
      path: path,
      query: query,
      body: body,
      headers: headers,
    );
    if (method == 'PostArticlesIdGuidanceAnnotations') {
      final rows =
          documents['GetArticlesIdGuidanceAnnotations']?['items'] as List? ??
          [];
      documents['GetArticlesIdGuidanceAnnotations'] = {
        'items': [
          ...rows,
          {
            ...body!,
            'id': rows.length + 100,
            'reviewer_id': 1,
            'reviewer_name': '我',
            'status': 'PENDING',
          },
        ],
      };
    }
    if (method.endsWith('GuidanceAnnotationsAnnotationIdDecision')) {
      final ids =
          body!['annotation_ids'] as List? ??
          [int.parse(path['annotation_id']!)];
      final rows =
          documents['GetArticlesIdGuidanceAnnotations']?['items'] as List? ??
          [];
      documents['GetArticlesIdGuidanceAnnotations'] = {
        'items': [
          for (final row in rows)
            {
              ...row as Map,
              if (ids.contains(row['id'])) 'status': body['status'],
            },
        ],
      };
    }
    return result;
  }
}

class NavigationLog extends NavigatorObserver {
  final pushes = <Route<dynamic>>[];
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      pushes.add(route);
}

Finder get card => find.byKey(const ValueKey('guidance-coach-card'));
Finder region() => find
    .byWidgetPredicate(
      (widget) =>
          widget.key is ValueKey<String> &&
          (widget.key as ValueKey<String>).value.startsWith(
            'resume-annotation-region-',
          ),
    )
    .first;
Finder compareRegion() => find
    .byWidgetPredicate(
      (widget) =>
          widget.key is ValueKey<String> &&
          (widget.key as ValueKey<String>).value.startsWith(
            'guidance-compare-region-',
          ),
    )
    .first;

List<String> writes(FakeGateway api) => api.calls
    .where(
      (call) =>
          call.startsWith('Post') ||
          call.startsWith('Put') ||
          call.startsWith('Patch') ||
          call.startsWith('Delete'),
    )
    .toList();

Future<void> tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder, warnIfMissed: true);
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

Future<void> capture(
  WidgetTester tester,
  GlobalKey boundary,
  String name,
) async {
  final render =
      boundary.currentContext!.findRenderObject() as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final picture = await render.toImage(pixelRatio: 2);
    final bytes = await picture.toByteData(format: ui.ImageByteFormat.png);
    await Directory('build/previews').create(recursive: true);
    await File('build/previews/$name.png')
        .writeAsBytes(bytes!.buffer.asUint8List());
    picture.dispose();
  });
}

void noManualTeaching() {
  for (final label in ['使用教学', '学习目录', '练习模式', '看一遍动作示范', '跟着做，学会用']) {
    expect(find.textContaining(label), findsNothing);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ThemeData previewTheme, previewDarkTheme;
  setUpAll(() async {
    await (FontLoader(
      'GuidancePreview',
    )..addFont(rootBundle.load(resumeFontRegularAsset))).load();
    await (FontLoader(
      'ResumeDocument',
    )..addFont(rootBundle.load(resumeFontRegularAsset))).load();
    await (FontLoader(
      'AnnotationUI',
    )..addFont(rootBundle.load('assets/fonts/annotation-ui.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    ThemeData withPreviewFont(ThemeData base) => base.copyWith(
      textTheme: base.textTheme.apply(fontFamily: 'GuidancePreview'),
      appBarTheme: base.appBarTheme.copyWith(
        titleTextStyle: base.appBarTheme.titleTextStyle!.copyWith(
          fontFamily: 'GuidancePreview',
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: base.filledButtonTheme.style!.copyWith(
          textStyle: const WidgetStatePropertyAll(
            TextStyle(fontFamily: 'GuidancePreview', fontSize: 14),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: base.textButtonTheme.style!.copyWith(
          textStyle: const WidgetStatePropertyAll(
            TextStyle(fontFamily: 'GuidancePreview', fontSize: 13),
          ),
        ),
      ),
    );
    previewTheme = withPreviewFont(appTheme);
    previewDarkTheme = withPreviewFont(appDarkTheme);
  });

  testWidgets(
    'Only hidden text selection and hold-to-compare receive guidance in real scenes',
    (tester) async {
      final api = SceneGateway();
      final store = await testStore(
        authenticated: true,
        guidanceHelpSeen: false,
        api: api,
      );
      addTearDown(store.dispose);
      final nav = NavigationLog();
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          navigatorObservers: [nav],
          home: ResumeGuidanceView(store: store, id: 20, initialData: preview),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('点这段文字开始指点'), findsOneWidget);
      expect(nav.pushes, hasLength(1));
      expect(card, findsOneWidget);
      noManualTeaching();
      expect(writes(api), isEmpty);

      await tap(tester, region());
      expect(find.text('选好这段，再选择操作'), findsNothing);
      expect(find.text('查看评论'), findsOneWidget);
      expect(nav.pushes, hasLength(2)); // the actual selection menu
      await tap(tester, find.text('查看评论'));
      expect(find.text('围绕这段内容说说看法'), findsNothing);
      expect(card, findsNothing);
      expect(
        find.byKey(const ValueKey('region-comment-input')),
        findsOneWidget,
      );
      expect(writes(api), isEmpty);
      await tester.enterText(
        find.byKey(const ValueKey('region-comment-input')),
        '建议补充实际成果。',
      );
      await tester.pumpAndSettle();
      expect(find.text('确认内容，再发送'), findsNothing);
      expect(writes(api), isEmpty);
      await tap(tester, find.byKey(const ValueKey('region-comment-send')));
      expect(find.text('建议补充实际成果。'), findsOneWidget);
      expect(find.text('已发送，回到刚才的简历位置'), findsNothing);
      expect(writes(api), ['PostArticlesIdGuidanceAnnotations']);
      await tap(tester, find.byKey(const ValueKey('tour-comment-close')));
      expect(find.byType(ResumeDocumentView), findsOneWidget);

      await tap(tester, region());
      expect(find.text('选好这段，再选择操作'), findsNothing);
      await tap(tester, find.text('参与改写'));
      expect(find.text('把原文改成你建议的写法'), findsNothing);
      expect(find.byType(TextField), findsOneWidget);
      expect(writes(api), hasLength(1));
      await tester.enterText(find.byType(TextField), '优化加载流程，改善页面使用体验。');
      await tester.pumpAndSettle();
      expect(find.text('提交给作者确认'), findsNothing);
      await tap(tester, find.byKey(const ValueKey('annotation-submit')));
      expect(find.text('按住改写，就能查看原文'), findsOneWidget);
      expect(writes(api), hasLength(2));
      await tester.ensureVisible(compareRegion());
      final press = await tester.startGesture(
        tester.getCenter(compareRegion()),
      );
      await tester.pumpAndSettle();
      final document = tester.state<ResumeDocumentViewState>(
        find.byType(ResumeDocumentView),
      );
      expect(document.originalMark, isNotNull);
      await press.up();
      await tester.pumpAndSettle();
      expect(document.originalMark, isNull);
      expect(card, findsNothing);
      expect(
        await store.storage.read(
          guidanceTourStorageKey(store.userID, 'rewrite-preview'),
        ),
        'seen',
      );
      noManualTeaching();
    },
  );

  testWidgets(
    'Sharing, friend selection, question entry and sending no longer show guidance',
    (tester) async {
      final api = SceneGateway();
      api.documents['GetFriends'] = {
        'items': [
          {'id': 2, 'display_name': '小林', 'public_id': '10086'},
        ],
      };
      api.documents['PostResumesIdGuidance'] = {'id': 99};
      final store = await testStore(
        authenticated: true,
        guidanceHelpSeen: false,
        api: api,
      );
      addTearDown(store.dispose);
      final nav = NavigationLog();
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          navigatorObservers: [nav],
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ResumeGuidanceShare(
                      store: store,
                      resume: decodeResume({
                        'id': 42,
                        'title': '我的简历',
                        'content': <String, dynamic>{},
                      }),
                    ),
                  ),
                ),
                child: const Text('打开分享'),
              ),
            ),
          ),
        ),
      );
      await tap(tester, find.text('打开分享'));
      expect(find.text('先决定向谁请教'), findsNothing);
      expect(nav.pushes, hasLength(2));
      await tap(tester, find.text('指定用户'));
      expect(find.text('搜索后勾选想请教的好友'), findsNothing);
      expect(card, findsNothing);
      await tap(tester, find.text('小林'));
      expect(find.text('告诉大家你想改进什么'), findsNothing);
      await tester.enterText(
        find.byKey(const ValueKey('guidance-question')),
        '怎样写清工作成果？',
      );
      await tester.pumpAndSettle();
      expect(find.text('确认分享范围后发送'), findsNothing);
      expect(writes(api), isEmpty);
      await tap(tester, find.byKey(const ValueKey('guidance-submit')));
      expect(writes(api), ['PostResumesIdGuidance']);
      expect(find.text('打开分享'), findsOneWidget);
      expect(card, findsNothing);
      expect(
        await store.storage.read(guidanceTourStorageKey(store.userID, 'share')),
        isNull,
      );
      noManualTeaching();
    },
  );

  testWidgets(
    'Author only receives the hidden comparison tip with save semantics',
    (tester) async {
      final api = SceneGateway();
      api.documents.addAll(fixtures.gateway().documents);
      api.documents['GetArticlesIdGuidanceAnnotations'] = {
        'items': [fixtures.advice(8, 2, selected: '性能优化', replacement: '平台优化')],
      };
      final store = await testStore(
        authenticated: true,
        guidanceHelpSeen: false,
        api: api,
      );
      addTearDown(store.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: ResumeGuidanceView(
            store: store,
            id: 20,
            initialData: fixtures.owner(),
            fromNotification: true,
            reviewerKey: 'user:2',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('对照原文，决定是否采纳'), findsNothing);
      expect(
        store.guidanceReviewDrafts.values.every((ids) => ids.isEmpty),
        isTrue,
      );
      expect(writes(api), isEmpty);
      await tap(tester, find.byKey(const ValueKey('tour-accept')));
      expect(find.text('按住改写，就能查看原文'), findsOneWidget);
      expect(find.textContaining('原简历会保留'), findsOneWidget);
      expect(store.guidanceReviewDrafts.values.single, {8});
      expect(writes(api), isEmpty);
      await tester.ensureVisible(compareRegion());
      final press = await tester.startGesture(
        tester.getCenter(compareRegion()),
      );
      await tester.pump(const Duration(milliseconds: 400));
      await press.up();
      await tester.pumpAndSettle();
      expect(find.text('采纳后，记得保存'), findsNothing);
      expect(writes(api), isEmpty);
      await tap(tester, find.byKey(const ValueKey('tour-save')));
      expect(
        writes(api).single,
        endsWith('GuidanceAnnotationsAnnotationIdDecision'),
      );
      expect(store.guidanceReviewDrafts.values.single, isEmpty);
      expect(
        await store.storage.read(
          guidanceTourStorageKey(store.userID, 'review-save'),
        ),
        'seen',
      );
      expect(card, findsNothing);
    },
  );

  testWidgets(
    'Participant selection and ordinary review actions no longer show guidance',
    (tester) async {
      final api = SceneGateway();
      api.documents.addAll(fixtures.gateway().documents);
      api.documents['GetArticlesIdGuidanceAnnotations'] = {
        'items': [fixtures.advice(8, 2, selected: '性能优化', replacement: '平台优化')],
      };
      final store = await testStore(
        authenticated: true,
        guidanceHelpSeen: false,
        api: api,
      );
      addTearDown(store.dispose);
      final nav = NavigationLog();
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          navigatorObservers: [nav],
          home: ResumeGuidanceView(
            store: store,
            id: 20,
            initialData: fixtures.owner(),
            fromNotification: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('选择一位指点者'), findsNothing);
      await tap(
        tester,
        find.byKey(const ValueKey('guidance-participant-user:2')),
      );
      expect(find.text('对照原文，决定是否采纳'), findsNothing);
      expect(card, findsNothing);
      expect(nav.pushes, hasLength(2));
      expect(writes(api), isEmpty);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(card, findsNothing);
    },
  );

  testWidgets(
    'Replies send to the selected comment without input, send or close tutorials',
    (tester) async {
      final api = SceneGateway();
      api.documents['GetArticlesIdGuidanceAnnotations'] = {
        'items': [fixtures.advice(7, 2, selected: original, comment: '请补充成果')],
      };
      final store = await testStore(
        authenticated: true,
        guidanceHelpSeen: false,
        api: api,
      );
      addTearDown(store.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showRegionComments(
                  context,
                  store: store,
                  id: 20,
                  notification: false,
                  owner: true,
                  fieldPath: fieldPath,
                  selected: original,
                  original: original,
                ),
                child: const Text('打开评论'),
              ),
            ),
          ),
        ),
      );
      await tap(tester, find.text('打开评论'));
      expect(find.text('点评论，继续与对方交流'), findsNothing);
      await tap(tester, find.text('回复'));
      expect(find.text('回复对象已经选好了'), findsNothing);
      await tester.enterText(
        find.byKey(const ValueKey('region-comment-input')),
        '谢谢，我会补充。',
      );
      await tester.pumpAndSettle();
      expect(find.text('发送这条回复'), findsNothing);
      expect(writes(api), isEmpty);
      await tap(tester, find.byKey(const ValueKey('region-comment-send')));
      expect(api.lastMutationBody!['parent_id'], 7);
      expect(find.text('已发送，回到刚才的简历位置'), findsNothing);
      await tap(tester, find.byKey(const ValueKey('tour-comment-close')));
      expect(card, findsNothing);
      expect(
        await store.storage.read(
          guidanceTourStorageKey(store.userID, 'reply-comments'),
        ),
        isNull,
      );
    },
  );

  testWidgets(
    'Completion and skip are isolated by scene and account with no manual entry',
    (tester) async {
      final store = await testStore(guidanceHelpSeen: false);
      final flow = GuidanceFlowController();
      addTearDown(store.dispose);
      addTearDown(flow.dispose);
      Widget app(String id, int visit) => MaterialApp(
        theme: appTheme,
        home: GuidanceWalkthrough(
          key: ValueKey(visit),
          store: store,
          id: id,
          controller: flow,
          steps: const [
            GuidanceStep(
              'actual',
              '当前场景的操作',
              '点击实际按钮继续。',
              event: 'actual.done',
            ),
          ],
          child: Scaffold(
            body: Center(
              child: FilledButton(
                key: const ValueKey('actual'),
                onPressed: () => flow.complete('actual.done'),
                child: const Text('实际操作'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpWidget(app('reviewer', 1));
      await tester.pumpAndSettle();
      expect(card, findsOneWidget);
      await tap(tester, find.text('暂不提示'));
      expect(
        await store.storage.read(guidanceTourStorageKey(0, 'reviewer')),
        'skipped',
      );
      await tester.pumpWidget(app('reviewer', 2));
      await tester.pumpAndSettle();
      expect(card, findsNothing);
      await tester.pumpWidget(app('rewrite', 3));
      await tester.pumpAndSettle();
      expect(card, findsOneWidget);
      store.userID = 77;
      await tester.pumpWidget(app('reviewer', 4));
      await tester.pumpAndSettle();
      expect(card, findsOneWidget);
      await tap(tester, find.byKey(const ValueKey('actual')));
      expect(card, findsNothing);
      expect(
        await store.storage.read(guidanceTourStorageKey(77, 'reviewer')),
        'seen',
      );
      store.userID = 88;
      await tester.pumpWidget(app('reviewer', 4));
      await tester.pumpAndSettle();
      expect(card, findsOneWidget);
      expect(
        await store.storage.read(guidanceTourStorageKey(88, 'reviewer')),
        isNull,
      );
      await tap(tester, find.byKey(const ValueKey('actual')));
      expect(card, findsNothing);
      expect(
        await store.storage.read(guidanceTourStorageKey(88, 'reviewer')),
        'seen',
      );
      noManualTeaching();
    },
  );

  testWidgets(
    'Guidance blocks background drags and wheel scrolling and resumes across routes',
    (tester) async {
      final store = await testStore(guidanceHelpSeen: false);
      final flow = GuidanceFlowController();
      final childFlow = GuidanceFlowController();
      final navigation = NavigationLog();
      addTearDown(store.dispose);
      addTearDown(flow.dispose);
      addTearDown(childFlow.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          navigatorObservers: [navigation],
          home: Builder(
            builder: (context) => GuidanceWalkthrough(
              store: store,
              id: 'reviewer',
              controller: flow,
              steps: const [
                GuidanceStep(
                  'real-target',
                  '当前页面的提示',
                  '操作当前按钮后继续。',
                  event: 'actual.done',
                ),
              ],
              child: Scaffold(
                appBar: AppBar(
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => GuidanceWalkthrough(
                            store: store,
                            id: 'feedback',
                            controller: childFlow,
                            steps: const [
                              GuidanceStep(
                                'child-target',
                                '新场景的提示',
                                '操作当前按钮后继续。',
                                event: 'child.done',
                              ),
                            ],
                            child: Scaffold(
                              appBar: AppBar(),
                              body: Center(
                                child: FilledButton(
                                  key: const ValueKey('child-target'),
                                  onPressed: () =>
                                      childFlow.complete('child.done'),
                                  child: const Text('场景内操作'),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      child: const Text('打开另一场景'),
                    ),
                  ],
                ),
                body: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 600),
                      FilledButton(
                        key: const ValueKey('real-target'),
                        onPressed: () => flow.complete('actual.done'),
                        child: const Text('实际操作'),
                      ),
                      const SizedBox(height: 700),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('当前页面的提示'), findsOneWidget);
      final target = find.byKey(const ValueKey('real-target'));
      final initialPosition = tester.getCenter(target);
      await tester.dragFrom(const Offset(40, 565), const Offset(0, -100));
      await tester.pumpAndSettle();
      expect(tester.getCenter(target), initialPosition);
      await tester.drag(target, const Offset(0, -120));
      await tester.pumpAndSettle();
      expect(tester.getCenter(target), initialPosition);
      await tester.sendEventToBinding(
        const PointerScrollEvent(
          position: Offset(40, 565),
          scrollDelta: Offset(0, 160),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.getCenter(target), initialPosition);
      final paint = tester.widget<CustomPaint>(
        find.byWidgetPredicate(
          (widget) =>
              widget is CustomPaint &&
              widget.painter is GuidanceSpotlightPainter,
        ),
      );
      expect(
        (paint.painter as GuidanceSpotlightPainter).rect.center.dy,
        closeTo(tester.getCenter(target).dy, 1),
      );
      await tap(tester, find.text('打开另一场景'));
      expect(card, findsOneWidget);
      expect(find.text('新场景的提示'), findsOneWidget);
      expect(find.text('当前页面的提示'), findsNothing);
      expect(navigation.pushes, hasLength(2));
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(card, findsOneWidget);
      expect(find.text('当前页面的提示'), findsOneWidget);
      expect(
        await store.storage.read(guidanceTourStorageKey(0, 'reviewer')),
        isNull,
      );
      expect(
        await store.storage.read(guidanceTourStorageKey(0, 'feedback')),
        isNull,
      );
      await tap(tester, target);
      expect(card, findsNothing);
      await tester.dragFrom(const Offset(40, 565), const Offset(0, -100));
      await tester.pumpAndSettle();
      expect(tester.getCenter(target).dy, lessThan(initialPosition.dy - 50));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Skipping a tip unlocks vertical and nested horizontal lists with explicit physics',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = await testStore(guidanceHelpSeen: false);
      final vertical = ScrollController();
      final horizontal = ScrollController();
      addTearDown(store.dispose);
      addTearDown(vertical.dispose);
      addTearDown(horizontal.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: GuidanceWalkthrough(
            store: store,
            id: 'reviewer',
            steps: const [GuidanceStep('target', '隐藏操作', '了解这处操作。')],
            child: Scaffold(
              body: SafeArea(
                child: Column(
                  children: [
                    FilledButton(
                      key: const ValueKey('target'),
                      onPressed: () {},
                      child: const Text('实际操作'),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        controller: vertical,
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          children: [
                            const SizedBox(height: 340),
                            SizedBox(
                              key: const ValueKey('horizontal-list'),
                              height: 100,
                              child: ListView(
                                controller: horizontal,
                                physics: const ClampingScrollPhysics(),
                                scrollDirection: Axis.horizontal,
                                children: List.generate(
                                  20,
                                  (i) => SizedBox(
                                    width: 100,
                                    child: Text('项目 $i'),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 1400),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(card, findsOneWidget);
      final row = find.byKey(const ValueKey('horizontal-list'));
      await tester.drag(row, const Offset(-180, 0));
      await tester.dragFrom(const Offset(40, 760), const Offset(0, -160));
      await tester.sendEventToBinding(
        const PointerScrollEvent(
          position: Offset(40, 760),
          scrollDelta: Offset(0, 160),
        ),
      );
      await tester.pumpAndSettle();
      expect(vertical.offset, 0);
      expect(horizontal.offset, 0);
      await tap(tester, find.text('暂不提示'));
      expect(card, findsNothing);
      await tester.drag(row, const Offset(-180, 0));
      await tester.pumpAndSettle();
      expect(horizontal.offset, greaterThan(100));
      await tester.dragFrom(const Offset(40, 760), const Offset(0, -160));
      await tester.pumpAndSettle();
      expect(vertical.offset, greaterThan(100));
    },
  );

  testWidgets(
    'Opening guidance stops a running fling and releases its lock when hidden or disposed',
    (tester) async {
      final store = await testStore(guidanceHelpSeen: false);
      final ready = ValueNotifier(false);
      final scroll = ScrollController();
      final nextScroll = ScrollController();
      addTearDown(store.dispose);
      addTearDown(ready.dispose);
      addTearDown(scroll.dispose);
      addTearDown(nextScroll.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: ValueListenableBuilder<bool>(
            valueListenable: ready,
            builder: (context, value, _) => GuidanceWalkthrough(
              store: store,
              id: 'reviewer',
              ready: value,
              steps: const [GuidanceStep('target', '隐藏操作', '了解这处操作。')],
              child: Scaffold(
                body: Column(
                  children: [
                    const SizedBox(
                      key: ValueKey('target'),
                      height: 48,
                      child: Text('实际操作'),
                    ),
                    Expanded(
                      child: ListView.builder(
                        controller: scroll,
                        itemExtent: 60,
                        itemCount: 100,
                        itemBuilder: (_, i) => Text('内容 $i'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.flingFrom(
        const Offset(40, 550),
        const Offset(0, -100),
        1200,
      );
      await tester.pump(const Duration(milliseconds: 30));
      expect(scroll.position.isScrollingNotifier.value, isTrue);
      ready.value = true;
      await tester.pumpAndSettle();
      expect(card, findsOneWidget);
      final stoppedAt = scroll.offset;
      expect(stoppedAt, greaterThan(0));
      await tester.pump(const Duration(seconds: 2));
      expect(scroll.offset, stoppedAt);
      expect(scroll.position.isScrollingNotifier.value, isFalse);
      ready.value = false;
      await tester.pumpAndSettle();
      expect(card, findsNothing);
      await tester.dragFrom(const Offset(40, 550), const Offset(0, -100));
      await tester.pumpAndSettle();
      expect(scroll.offset, greaterThan(stoppedAt + 50));
      ready.value = true;
      await tester.pumpAndSettle();
      expect(card, findsOneWidget);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              controller: nextScroll,
              children: const [SizedBox(height: 2000)],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(card, findsNothing);
      await tester.dragFrom(const Offset(40, 550), const Offset(0, -100));
      await tester.pumpAndSettle();
      expect(nextScroll.offset, greaterThan(50));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Document guidance freezes page scrolling and custom pinch and pan gestures until skipped',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = SceneGateway();
      final store = await testStore(guidanceHelpSeen: false, api: api);
      addTearDown(store.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: ResumeGuidanceView(
            store: store,
            id: 20,
            initialData: {
              'snapshot': {
                'work_experiences': List.generate(
                  20,
                  (i) => {'position': '前端工程师 $i', 'description': original},
                ),
              },
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(card, findsOneWidget);
      final document = tester.state<ResumeDocumentViewState>(
        find.byType(ResumeDocumentView),
      );
      expect(document.document!.pages.length, greaterThan(1));
      final offset = document.pageScroll.offset;
      Future<void> pinch() async {
        final first = await tester.startGesture(
          const Offset(140, 710),
          pointer: 1,
        );
        final second = await tester.startGesture(
          const Offset(250, 710),
          pointer: 2,
        );
        await first.moveBy(const Offset(-60, -30));
        await second.moveBy(const Offset(60, 30));
        await tester.pump();
        await first.up();
        await second.up();
        await tester.pumpAndSettle();
      }

      await tester.dragFrom(const Offset(40, 760), const Offset(0, -180));
      await pinch();
      expect(document.pageScroll.offset, offset);
      expect(document.transform.value, Matrix4.identity());
      // The zoomed document also implements panning outside Scrollable.
      document.changeZoom(2);
      await tester.pumpAndSettle();
      final zoomed = document.transform.value.clone();
      await tester.dragFrom(const Offset(40, 760), const Offset(-30, -80));
      await tester.pumpAndSettle();
      expect(document.transform.value, zoomed);
      expect(document.pageScroll.offset, offset);
      await tap(tester, find.text('暂不提示'));
      expect(card, findsNothing);
      document.resetZoom();
      await tester.pumpAndSettle();
      await tester.dragFrom(const Offset(40, 760), const Offset(0, -180));
      await tester.pumpAndSettle();
      expect(document.pageScroll.offset, greaterThan(offset + 100));
      await pinch();
      expect(document.transform.value.getMaxScaleOnAxis(), greaterThan(1));
      expect(writes(api), isEmpty);
    },
  );

  testWidgets(
    'Removing all steps releases the old overlay and scroll lock without marking the scene seen',
    (tester) async {
      final store = await testStore(guidanceHelpSeen: false);
      final tipsAvailable = ValueNotifier(true);
      final scroll = ScrollController();
      addTearDown(store.dispose);
      addTearDown(tipsAvailable.dispose);
      addTearDown(scroll.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: ValueListenableBuilder<bool>(
            valueListenable: tipsAvailable,
            builder: (_, available, _) => GuidanceWalkthrough(
              store: store,
              id: 'review-save',
              steps: available
                  ? const [GuidanceStep('target', '隐藏操作', '了解这处操作。')]
                  : const [],
              child: Scaffold(
                body: Column(
                  children: [
                    const SizedBox(
                      key: ValueKey('target'),
                      height: 48,
                      child: Text('实际操作'),
                    ),
                    Expanded(
                      child: ListView(
                        controller: scroll,
                        children: const [SizedBox(height: 2000)],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(card, findsOneWidget);
      tipsAvailable.value = false;
      await tester.pumpAndSettle();
      expect(card, findsNothing);
      await tester.dragFrom(const Offset(40, 550), const Offset(0, -100));
      await tester.pumpAndSettle();
      expect(scroll.offset, greaterThan(50));
      expect(
        await store.storage.read(guidanceTourStorageKey(0, 'review-save')),
        isNull,
      );
      tipsAvailable.value = true;
      await tester.pumpAndSettle();
      expect(card, findsOneWidget);
    },
  );

  for (final dark in [false, true]) {
    testWidgets(
      'Retained tip fits a small screen with large text and reduced motion (dark=$dark)',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final store = await testStore(guidanceHelpSeen: false);
        addTearDown(store.dispose);
        final boundary = GlobalKey();
        final theme = dark ? previewDarkTheme : previewTheme;
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: MaterialApp(
              theme: theme,
              debugShowCheckedModeBanner: false,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(1.5),
                  disableAnimations: true,
                ),
                child: child!,
              ),
              home: ResumeGuidanceView(
                store: store,
                id: 20,
                initialData: preview,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(card, findsOneWidget);
        final bounds = tester.getRect(card);
        expect(bounds.top, greaterThanOrEqualTo(0));
        expect(bounds.bottom, lessThanOrEqualTo(640));
        expect(bounds.overlaps(tester.getRect(region())), isFalse);
        await capture(
          tester,
          boundary,
          'guidance-pruned-small-${dark ? 'dark' : 'light'}',
        );
        final document = tester.state<ResumeDocumentViewState>(
          find.byType(ResumeDocumentView),
        );
        final offset = document.pageScroll.offset;
        await tester.dragFrom(const Offset(10, 600), const Offset(0, -100));
        await tester.pumpAndSettle();
        expect(document.pageScroll.offset, offset);
        await tap(tester, find.text('暂不提示'));
        expect(card, findsNothing);
      },
    );
  }

  testWidgets(
    'Small-screen rewrite form has no tutorial and preserves the draft on failure',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      final api = SceneGateway()..failing = 'PostArticlesIdGuidanceAnnotations';
      final store = await testStore(
        authenticated: true,
        guidanceHelpSeen: false,
        api: api,
      );
      addTearDown(store.dispose);
      final boundary = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MaterialApp(
            theme: previewTheme,
            debugShowCheckedModeBanner: false,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(1.5),
                disableAnimations: true,
              ),
              child: child!,
            ),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => composeGuidanceAnnotation(
                    context,
                    store: store,
                    id: 20,
                    notification: false,
                    snapshot: preview['snapshot']!,
                    fieldPath: fieldPath,
                    selectedText: original,
                    replace: true,
                  ),
                  child: const Text('打开改写'),
                ),
              ),
            ),
          ),
        ),
      );
      await tap(tester, find.text('打开改写'));
      expect(find.text('把原文改成你建议的写法'), findsNothing);
      final field = find.byType(TextField);
      expect(card, findsNothing);
      await tap(tester, field);
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      await tester.enterText(field, '我的未提交改写草稿');
      await tester.pumpAndSettle();
      expect(find.text('提交给作者确认'), findsNothing);
      final submit = find.byKey(const ValueKey('annotation-submit'));
      expect(card, findsNothing);
      expect(card, findsNothing);
      await capture(tester, boundary, 'guidance-scene-keyboard');
      await tap(tester, submit);
      expect(find.text('我的未提交改写草稿'), findsOneWidget);
      expect(find.text('提交给作者确认'), findsNothing);
      expect(
        await store.storage.read(
          guidanceTourStorageKey(store.userID, 'rewrite'),
        ),
        isNull,
      );
      expect(writes(api), hasLength(1));
      tester.view.viewInsets = FakeViewPadding.zero;
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(card, findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Selection menu is usable without a tutorial and cancel does not write data',
    (tester) async {
      final api = SceneGateway();
      final store = await testStore(guidanceHelpSeen: false, api: api);
      addTearDown(store.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: ResumeGuidanceView(store: store, id: 20, initialData: preview),
        ),
      );
      await tester.pumpAndSettle();
      await tap(tester, region());
      expect(find.text('选好这段，再选择操作'), findsNothing);
      await tester.tapAt(const Offset(4, 590));
      await tester.pumpAndSettle();
      expect(find.text('查看评论'), findsNothing);
      expect(
        await store.storage.read(
          guidanceTourStorageKey(store.userID, 'selection-menu'),
        ),
        isNull,
      );
      await tap(tester, region());
      expect(find.text('选好这段，再选择操作'), findsNothing);
      expect(writes(api), isEmpty);
    },
  );

  testWidgets(
    'Only the hidden gesture shows a spotlight in the actual scene preview',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = await testStore(guidanceHelpSeen: false);
      addTearDown(store.dispose);
      final boundary = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MaterialApp(
            theme: previewTheme,
            debugShowCheckedModeBanner: false,
            home: ResumeGuidanceView(
              store: store,
              id: 20,
              initialData: preview,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(card, findsOneWidget);
      await capture(tester, boundary, 'guidance-scene-automatic');
      final paint = tester.widget<CustomPaint>(
        find.byWidgetPredicate(
          (widget) =>
              widget is CustomPaint &&
              widget.painter is GuidanceSpotlightPainter,
        ),
      );
      expect(
        (paint.painter as GuidanceSpotlightPainter).rect.center.dx,
        closeTo(tester.getRect(region()).center.dx, 1),
      );
      await tap(tester, region());
      expect(card, findsNothing);
      await capture(tester, boundary, 'guidance-scene-selection');
      await tap(tester, find.text('参与改写'));
      expect(find.text('把原文改成你建议的写法'), findsNothing);
      await capture(tester, boundary, 'guidance-scene-rewrite');
      noManualTeaching();
    },
  );
}
