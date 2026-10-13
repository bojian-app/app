import 'dart:ui' as ui;

import 'package:bojian_mobile/api/bojian_api.dart';
import 'package:bojian_mobile/guidance_region_comments.dart';
import 'package:bojian_mobile/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

class ReplyGateway extends FakeGateway {
  Map<String, dynamic>? posted;
  final keys = <String>[];
  @override
  Future<ApiDocument> call(
    String method, {
    Map<String, String> path = const {},
    Map<String, String> query = const {},
    Map<String, dynamic>? body,
    Map<String, String> headers = const {},
  }) {
    if (method.startsWith('Post') && method.endsWith('GuidanceAnnotations')) {
      posted = body;
      keys.add(headers['idempotency-key']!);
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

Future<void> expectOpaqueWhiteBottom(WidgetTester tester, GlobalKey key) async {
  final color = await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    final offset = ((image.height - 8) * image.width + image.width ~/ 2) * 4;
    final color = List<int>.generate(
      4,
      (channel) => bytes.getUint8(offset + channel),
    );
    image.dispose();
    return color;
  });
  expect(color, [255, 255, 255, 255]);
}

void main() {
  for (final variant in [
    (extent: .70, navigationBar: 0.0),
    (extent: .82, navigationBar: 0.0),
    (extent: .70, navigationBar: 24.0),
  ]) {
    final restingExtent = variant.extent;
    testWidgets(
      'Keyboard dismissal keeps an opaque bottom and smooth composer at extent $restingExtent / navigation ${variant.navigationBar}',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetViewInsets);
        addTearDown(tester.view.resetPadding);
        addTearDown(tester.view.resetViewPadding);
        tester.view.padding = FakeViewPadding(bottom: variant.navigationBar);
        tester.view.viewPadding = FakeViewPadding(
          bottom: variant.navigationBar,
        );
        final api = ReplyGateway();
        api.documents['GetArticlesIdGuidanceAnnotations'] = {
          'items': <Map<String, dynamic>>[],
        };
        final store = await testStore(authenticated: true, api: api);
        addTearDown(store.dispose);
        final surface = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: surface,
            child: MaterialApp(
              theme: appTheme,
              home: Scaffold(
                backgroundColor: const Color(0xFFFF00FF),
                body: Builder(
                  builder: (context) => TextButton(
                    onPressed: () => showRegionComments(
                      context,
                      store: store,
                      id: 20,
                      notification: false,
                      owner: false,
                      fieldPath: 'summary',
                      selected: '原文',
                      original: '原文',
                    ),
                    child: const Text('打开'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('打开'));
        await tester.pumpAndSettle();
        final draggable = tester.widget<DraggableScrollableSheet>(
          find.byType(DraggableScrollableSheet),
        );
        final controller = draggable.controller!;
        controller.jumpTo(restingExtent);
        await tester.pumpAndSettle();
        final panel = find.byKey(const ValueKey('region-comments-panel'));
        final originalRect = tester.getRect(panel);
        final input = find.byKey(const ValueKey('region-comment-input'));
        await tester.enterText(input, '关闭键盘也保留这条草稿');
        await tester.pumpAndSettle();
        // Focusing alone must not start a second, independent sheet animation.
        expect(tester.getRect(panel), originalRect);
        tester.view.padding = FakeViewPadding.zero;
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        await tester.pumpAndSettle();
        expect(controller.size, closeTo(restingExtent, .0001));
        expect(tester.getRect(panel), originalRect);
        expect(tester.getRect(input).bottom, lessThanOrEqualTo(544));
        // Native IME metrics can arrive every few frames. Retargeting must
        // preserve position and keep moving rather than restart from rest.
        for (final inset in [260.0, 220.0, 180.0, 140.0, 120.0]) {
          final beforeMetric = tester.getRect(input);
          tester.view.viewInsets = FakeViewPadding(bottom: inset);
          await tester.pump();
          expect(tester.getRect(input), beforeMetric);
          await tester.pump(const Duration(milliseconds: 16));
          await tester.pump(const Duration(milliseconds: 16));
          expect(
            tester.getRect(input).bottom,
            greaterThan(beforeMetric.bottom),
          );
        }
        final beforeZero = tester.getRect(panel);
        expect(beforeZero.bottom, closeTo(844, .01));
        expect(tester.getRect(input).bottom, lessThanOrEqualTo(724));
        final inputBeforeZero = tester.getRect(input);
        tester.view.padding = FakeViewPadding(bottom: variant.navigationBar);
        tester.view.viewInsets = FakeViewPadding.zero;
        await tester.pump();
        // The exposed IME area remains painted by the sheet, while only the
        // composer moves. There is no outside padding revealing the page.
        expect(tester.getRect(panel), beforeZero);
        expect(tester.getRect(input), inputBeforeZero);
        await expectOpaqueWhiteBottom(tester, surface);
        var previous = tester.getRect(input);
        for (var frame = 0; frame < 30; frame++) {
          await tester.pump(const Duration(milliseconds: 16));
          final current = tester.getRect(input);
          expect(current.bottom, greaterThanOrEqualTo(previous.bottom - .01));
          expect(tester.getRect(panel), originalRect);
          if (frame == 2 || frame == 8) {
            await expectOpaqueWhiteBottom(tester, surface);
          }
          previous = current;
        }
        expect(controller.size, closeTo(restingExtent, .0001));
        expect(tester.getRect(panel).top, closeTo(originalRect.top, .01));
        expect(tester.getRect(panel).height, closeTo(originalRect.height, .01));
        final settled = tester.getRect(input);
        await tester.pump(const Duration(milliseconds: 220));
        expect(tester.getRect(input), settled);
        expect(tester.widget<TextField>(input).controller!.text, '关闭键盘也保留这条草稿');
        // Closing the route during an IME transition must cancel safely.
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 40));
        await tester.tap(find.byTooltip('关闭评论'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets(
    'Comments group replies, preserve nested reply targets and keep the composer above the keyboard',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      final api = ReplyGateway();
      final store = await testStore(authenticated: true, api: api);
      addTearDown(store.dispose);
      Map<String, dynamic> comment(
        int id,
        String text,
        int user, {
        int? parent,
      }) => {
        'id': id,
        'reviewer_id': user,
        'reviewer_name': user == 2
            ? '小林'
            : user == 3
            ? '小周'
            : '',
        'field_path': 'work_experiences.0.description',
        'selected_text': '网站开发',
        'suggestion': text,
        'created_at': '2026-10-13T02:00:00Z',
        'parent_id': ?parent,
      };
      api.documents['GetArticlesIdGuidanceAnnotations'] = {
        'items': [
          comment(10, '父评论不在当前区域时，这条回复仍然可见', 3, parent: 999),
          comment(9, '第二层回复', store.userID, parent: 8),
          comment(8, '第一层回复', 3, parent: 7),
          comment(7, '主评论：可以补充页面性能指标和实际交付结果。', 2),
        ],
      };
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showRegionComments(
                  context,
                  store: store,
                  id: 20,
                  notification: false,
                  owner: false,
                  fieldPath: 'work_experiences.0.description',
                  selected: '网站开发',
                  original: '负责网站开发',
                ),
                child: const Text('打开'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();
      expect(find.text('评论（4）'), findsOneWidget);
      expect(find.text('第一层回复'), findsNothing);
      expect(find.text('第二层回复'), findsNothing);
      expect(find.text('展开 2 条回复'), findsOneWidget);
      await tester.tap(find.text('展开 2 条回复'));
      await tester.pumpAndSettle();
      expect(find.text('第一层回复'), findsOneWidget);
      expect(find.text('第二层回复'), findsOneWidget);
      final root = find.byKey(const ValueKey('region-comment-comment:7'));
      final child = find.byKey(const ValueKey('region-reply-comment:8'));
      expect(
        tester.getTopLeft(child).dx,
        greaterThan(tester.getTopLeft(root).dx),
      );
      await tester.tap(find.descendant(of: child, matching: find.text('回复')));
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      await tester.pumpAndSettle();
      final input = find.byKey(const ValueKey('region-comment-input'));
      await tester.enterText(input, '这是一条很长的回复。' * 40);
      await tester.pumpAndSettle();
      expect(tester.getRect(input).bottom, lessThanOrEqualTo(360));
      expect(
        tester
            .getRect(find.byKey(const ValueKey('region-comment-send')))
            .bottom,
        lessThanOrEqualTo(360),
      );
      expect(tester.takeException(), isNull);
      tester.view.viewInsets = const FakeViewPadding(bottom: 320);
      await tester.pumpAndSettle();
      expect(tester.getRect(input).bottom, lessThanOrEqualTo(320));
      await tester.tap(find.text('发送'));
      await tester.pumpAndSettle();
      expect(api.posted!['parent_id'], 8);
      expect(api.posted!['selected_text'], '网站开发');
      expect(tester.takeException(), isNull);
    },
  );

  for (final notification in [false, true]) {
    testWidgets(
      'Region replies retain parent, isolate region and retry safely ($notification)',
      (tester) async {
        final api = ReplyGateway();
        final store = await testStore(authenticated: true, api: api);
        addTearDown(store.dispose);
        final resource = notification ? 'Notifications' : 'Articles';
        api.documents['Get${resource}IdGuidanceAnnotations'] = {
          'items': [
            {
              'id': 7,
              'field_path': 'work_experiences.0.description',
              'selected_text': '网站开发',
              'suggestion': '补充指标',
              'reviewer_name': '小李',
            },
            {
              'id': 8,
              'field_path': 'work_experiences.1.description',
              'selected_text': '网站开发',
              'suggestion': '不属于本段',
            },
            {
              'id': 9,
              'field_path': 'work_experiences.0.description',
              'selected_text': '性能优化',
              'suggestion': '属于另一句',
            },
            {
              'id': 10,
              'field_path': 'work_experiences.0.description',
              'selected_text': '网站开发',
              'replacement': '改写不能当评论',
            },
          ],
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
                    owner: true,
                    fieldPath: 'work_experiences.0.description',
                    selected: '网站开发',
                    original: '负责网站开发',
                  ),
                  child: const Text('打开'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('打开'));
        await tester.pumpAndSettle();
        expect(find.text('评论（1）'), findsOneWidget);
        expect(find.text('补充指标'), findsOneWidget);
        expect(find.text('不属于本段'), findsNothing);
        expect(find.text('属于另一句'), findsNothing);
        expect(find.text('改写不能当评论'), findsNothing);
        expect(find.byType(TextField), findsNothing);
        await tester.tap(find.text('回复'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), '谢谢，我补充一下');
        await tester.pump();
        api.failing = 'Post${resource}IdGuidanceAnnotations';
        await tester.tap(find.text('发送'));
        await tester.pumpAndSettle();
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          '谢谢，我补充一下',
        );
        expect(find.text('发送失败，请重试'), findsOneWidget);
        api.failing = null;
        await tester.tap(find.text('发送'));
        await tester.pumpAndSettle();
        expect(api.posted!['parent_id'], 7);
        expect(api.posted!['selected_text'], '网站开发');
        expect(api.posted!['suggestion'], '谢谢，我补充一下');
        expect(api.keys[0], api.keys[1]);
        expect(find.byType(TextField), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
