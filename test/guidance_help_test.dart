import 'package:bojian_mobile/resume_guidance_annotations.dart';
import 'package:bojian_mobile/guidance_region_comments.dart';

import 'resume_guidance_review_test.dart' as review_fixture;

import 'dart:ui' as ui;
import 'dart:io';

import 'package:bojian_mobile/resume_guidance_view.dart';
import 'package:bojian_mobile/resume_guidance_share.dart';
import 'package:bojian_mobile/resume_document.dart';
import 'package:bojian_mobile/app_store.dart';
import 'package:bojian_mobile/design.dart';
import 'package:bojian_mobile/guidance_help.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

const preview = {
  'snapshot': {
    'work_experiences': [
      {'company': '某公司', 'description': '负责网站开发与性能优化，改善用户体验。'},
    ],
  },
};

void main() {
  testWidgets('Author tour preserves pending decisions and points at save', (
    tester,
  ) async {
    final api = review_fixture.gateway();
    api.documents['GetArticlesIdGuidanceAnnotations'] = {
      'items': [
        review_fixture.advice(8, 2, selected: '性能优化', replacement: '平台优化'),
      ],
    };
    final store = await testStore(
      authenticated: true,
      api: api,
      guidanceHelpSeen: false,
    );
    addTearDown(store.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: ResumeGuidanceView(
          store: store,
          id: 20,
          initialData: review_fixture.owner(),
          fromNotification: true,
          reviewerKey: 'user:2',
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (final title in [
      '对照原文审阅',
      '比较这条改写',
      '先采纳，预览效果',
      '不适合可以不采纳',
      '最后一定要保存',
    ]) {
      expect(find.text(title), findsOneWidget);
      await tester.tap(find.text(title == '最后一定要保存' ? '完成，开始操作' : '下一步'));
      await tester.pumpAndSettle();
    }
    expect(
      store.guidanceReviewDrafts.values.every((ids) => ids.isEmpty),
      isTrue,
    );
    expect(api.calls.where((call) => call.contains('Decision')), isEmpty);
    expect(find.text('审阅指点'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Rewrite and comments each guide their actual sheet without sending',
    (tester) async {
      final api = FakeGateway();
      final store = await testStore(
        authenticated: true,
        api: api,
        guidanceHelpSeen: false,
      );
      addTearDown(store.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) => Column(
                children: [
                  TextButton(
                    onPressed: () => composeGuidanceAnnotation(
                      context,
                      store: store,
                      id: 1,
                      notification: false,
                      snapshot: preview['snapshot']!,
                      fieldPath: 'work_experiences.0.description',
                      selectedText: '负责网站开发',
                      replace: true,
                    ),
                    child: const Text('打开改写'),
                  ),
                  TextButton(
                    onPressed: () => showRegionComments(
                      context,
                      store: store,
                      id: 1,
                      notification: false,
                      owner: false,
                      fieldPath: 'work_experiences.0.description',
                      selected: '负责网站开发',
                      original: '负责网站开发与性能优化，改善用户体验。',
                    ),
                    child: const Text('打开评论'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('打开改写'));
      await tester.pumpAndSettle();
      expect(find.text('把原文改成你建议的写法'), findsOneWidget);
      await tester.tap(find.text('下一步'));
      await tester.pumpAndSettle();
      expect(find.text('提交给作者确认'), findsOneWidget);
      await tester.tap(find.text('完成，开始操作'));
      await tester.pumpAndSettle();
      expect(find.text('负责网站开发'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(find.text('打开评论'));
      await tester.pumpAndSettle();
      final spotlight = tester.widget<CustomPaint>(
        find.byWidgetPredicate(
          (widget) =>
              widget is CustomPaint &&
              widget.painter.runtimeType.toString() == '_SpotlightPainter',
        ),
      );
      final Rect highlight = (spotlight.painter as dynamic).rect as Rect;
      final listRect = tester.getRect(
        find.byKey(const ValueKey('region-comments-list'), skipOffstage: false),
      );
      expect(highlight.top, closeTo(listRect.top - 6, 1));
      expect(highlight.bottom, closeTo(listRect.bottom + 6, 1));
      for (final title in ['围绕这段内容讨论', '写评论，也能回复', '关闭后继续指点']) {
        expect(find.text(title), findsOneWidget);
        await tester.tap(find.text(title == '关闭后继续指点' ? '完成，开始操作' : '下一步'));
        await tester.pumpAndSettle();
      }
      expect(
        api.calls.where((call) => call.startsWith('PostArticles')),
        isEmpty,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'First visit spotlights real content, advances and remembers completion',
    (tester) async {
      final store = await testStore(guidanceHelpSeen: false);
      addTearDown(store.dispose);
      Widget app(int visit) => MaterialApp(
        theme: appTheme,
        home: ResumeGuidanceView(
          key: ValueKey(visit),
          store: store,
          id: 1,
          initialData: preview,
        ),
      );
      await tester.pumpWidget(app(1));
      await tester.pumpAndSettle();
      expect(find.text('先看看这份简历'), findsOneWidget);
      expect(
        find.byType(ResumeDocumentView, skipOffstage: false),
        findsOneWidget,
      );
      expect(find.text('操作教程'), findsNothing);
      expect(find.text('指点操作教程'), findsNothing);
      await tester.tap(find.text('下一步'));
      await tester.pumpAndSettle();
      expect(find.text('点这段文字开始指点'), findsOneWidget);
      await tester.tap(find.text('下一步'));
      await tester.pumpAndSettle();
      expect(find.text('评论，说说你的看法'), findsOneWidget);
      await tester.tap(find.text('下一步'));
      await tester.pumpAndSettle();
      expect(find.text('改写，给出具体写法'), findsOneWidget);
      await tester.tap(find.text('完成，开始操作'));
      await tester.pumpAndSettle();
      expect(find.text('简历指点'), findsOneWidget);
      await tester.pumpWidget(app(2));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('guidance-coach-card')), findsNothing);
      expect(
        await store.storage.read(
          guidanceTourStorageKey(store.userID, 'reviewer'),
        ),
        'seen',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Skipping one context does not skip another; back does not mark complete',
    (tester) async {
      final store = await testStore(guidanceHelpSeen: false);
      addTearDown(store.dispose);
      Widget app(String id) => MaterialApp(
        theme: appTheme,
        home: GuidanceWalkthrough(
          key: ValueKey(id),
          store: store,
          id: id,
          steps: const [GuidanceStep('control', '真实按钮', '说明当前操作')],
          child: Scaffold(
            body: Center(
              child: FilledButton(
                key: const ValueKey('control'),
                onPressed: () {},
                child: const Text('操作'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpWidget(app('reviewer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('跳过'));
      await tester.pumpAndSettle();
      expect(
        await store.storage.read(
          guidanceTourStorageKey(store.userID, 'reviewer'),
        ),
        'seen',
      );
      await tester.pumpWidget(app('rewrite'));
      await tester.pumpAndSettle();
      expect(find.text('真实按钮'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(
        await store.storage.read(
          guidanceTourStorageKey(store.userID, 'rewrite'),
        ),
        isNull,
      );
    },
  );

  testWidgets(
    'Share tour scrolls to controls on narrow screens without submitting',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = FakeGateway();
      final store = await testStore(guidanceHelpSeen: false, api: api);
      addTearDown(store.dispose);
      final boundary = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MaterialApp(
            theme: appTheme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(1.5)),
              child: child!,
            ),
            home: ResumeGuidanceShare(
              store: store,
              resume: decodeResume({
                'id': 1,
                'title': '我的简历',
                'content': <String, dynamic>{},
              }),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final title in ['公开向社区请教', '也可以只邀请好友', '告诉大家你想改进什么', '确认分享范围后发送']) {
        expect(find.text(title), findsOneWidget);
        expect(tester.takeException(), isNull);
        if (title == '公开向社区请教') {
          final render =
              boundary.currentContext!.findRenderObject()
                  as RenderRepaintBoundary;
          await tester.runAsync(() async {
            final image = await render.toImage(pixelRatio: 2);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await Directory('build/previews').create(recursive: true);
            await File('build/previews/guidance-tour.png')
                .writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.tap(find.text(title == '确认分享范围后发送' ? '完成，开始操作' : '下一步'));
        await tester.pumpAndSettle();
      }
      expect(find.text('请求指点'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
