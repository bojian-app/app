import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:bojian_mobile/api/bojian_api.dart';
import 'package:bojian_mobile/app_store.dart';
import 'package:bojian_mobile/design.dart';
import 'package:bojian_mobile/guidance_inline_note.dart';
import 'package:bojian_mobile/messages_page.dart';
import 'package:bojian_mobile/resume_document.dart';
import 'package:bojian_mobile/resume_native_export.dart';
import 'package:bojian_mobile/resume_guidance_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

const quote = '负责网站开发与性能优化，改善用户体验。';
const targetPath = 'work_experiences.18.description';
const notificationTitle = '小林发来了新的简历反馈';
late ThemeData previewTheme;

class FocusGateway extends FakeGateway {
  final paths = <(String, Map<String, String>)>[];
  Completer<ApiDocument>? delayedAnnotations;
  @override
  Future<ApiDocument> call(
    String method, {
    Map<String, String> path = const {},
    Map<String, String> query = const {},
    Map<String, dynamic>? body,
    Map<String, String> headers = const {},
  }) async {
    paths.add((method, Map.of(path)));
    if (method.endsWith('GuidanceAnnotations') &&
        method.startsWith('Get') &&
        delayedAnnotations != null) {
      return delayedAnnotations!.future;
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

Map<String, dynamic> annotation(
  int id, {
  int reviewer = 2,
  String path = targetPath,
  String comment = '',
  String replacement = '',
  String status = 'PENDING',
  int? parent,
}) => {
  'id': id,
  'reviewer_id': reviewer,
  'reviewer_name': reviewer == 2 ? '小林' : '另一位用户',
  'field_path': path,
  'field_value': quote,
  'selected_text': quote,
  'suggestion': comment,
  'replacement': replacement,
  'status': status,
  'created_at': '2026-10-18T05:00:00Z',
  'parent_id': ?parent,
};

FocusGateway gateway({
  bool private = false,
  bool owner = true,
  int target = 200,
  String feedback = 'REWRITE',
  List<Map<String, dynamic>>? records,
  List<Map<String, dynamic>> legacy = const [],
}) {
  final api = FocusGateway();
  final source = {
    'personal_info': {'full_name': '测试作者'},
    'work_experiences': List.generate(
      24,
      (i) => {'position': '开发工程师 $i', 'description': quote},
    ),
  };
  final data = <String, dynamic>{
    'id': 20,
    'title': '通知定位简历',
    'is_owner': owner,
    'source_resume_id': 42,
    'snapshot': source,
    'suggestions': legacy,
  };
  api.documents['GetResumesId'] = {'id': 42, 'revision': 1, 'content': source};
  api.documents[private
          ? 'GetNotificationsIdGuidance'
          : 'GetArticlesIdGuidance'] =
      data;
  api.documents[private
      ? 'GetNotificationsIdGuidanceAnnotations'
      : 'GetArticlesIdGuidanceAnnotations'] = {
    'items':
        records ??
        [
          annotation(
            100,
            path: 'work_experiences.0.description',
            replacement: '同一人更早的改写',
          ),
          annotation(200, replacement: '这是通知对应的改写'),
          annotation(300, reviewer: 3, replacement: '另一位用户对同样文字的改写'),
        ],
  };
  api.documents['GetNotifications'] = {
    'items': [
      {
        'id': 900,
        'type': 'RESUME_GUIDANCE_FEEDBACK',
        'actor_id': 2,
        'subject_type': private ? 'GUIDANCE_NOTIFICATION' : 'ARTICLE',
        'subject_id': 20,
        'payload': {
          'title': notificationTitle,
          'feedback_type': feedback,
          // Both historical numeric strings and normal JSON numbers are accepted.
          if (target > 0) 'annotation_id': private ? '$target' : target,
        },
        'read_at': '2026-10-18T05:10:00Z',
      },
    ],
  };
  return api;
}

Future<AppStore> mount(
  WidgetTester tester,
  FocusGateway api, {
  bool helpSeen = true,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final store = await testStore(
    authenticated: true,
    api: api,
    guidanceHelpSeen: helpSeen,
  );
  addTearDown(store.dispose);
  await tester.pumpWidget(
    RepaintBoundary(
      key: const ValueKey('notification-focus-preview'),
      child: MaterialApp(
        theme: previewTheme,
        debugShowCheckedModeBanner: false,
        home: Scaffold(body: MessagesPage(store: store)),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return store;
}

List<String> writes(FocusGateway api) => api.calls
    .where(
      (call) =>
          call.startsWith('Post') ||
          call.startsWith('Put') ||
          call.startsWith('Patch') ||
          call.startsWith('Delete'),
    )
    .toList();

Finder note(int id) => find.byWidgetPredicate(
  (widget) =>
      widget is GuidanceInlineNote && integer(widget.record['id']) == id,
);

void expectInside(WidgetTester tester, Finder child, Finder viewport) {
  final area = tester.getRect(viewport);
  final rect = tester.getRect(child);
  expect(rect.top, greaterThanOrEqualTo(area.top - 1));
  expect(rect.bottom, lessThanOrEqualTo(area.bottom + 1));
}

Color? highlightColor(WidgetTester tester, Finder target) =>
    (tester
                .widget<DecoratedBox>(
                  find
                      .descendant(
                        of: target,
                        matching: find.byType(DecoratedBox),
                      )
                      .first,
                )
                .decoration
            as BoxDecoration)
        .color;

Future<void> capture(WidgetTester tester, String name) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('notification-focus-preview')),
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
    for (final font in ['NotificationFocusPreview', 'ResumeDocument']) {
      await (FontLoader(
        font,
      )..addFont(rootBundle.load(resumeFontRegularAsset))).load();
    }
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    previewTheme = appTheme.copyWith(
      textTheme: appTheme.textTheme.apply(
        fontFamily: 'NotificationFocusPreview',
      ),
      appBarTheme: appTheme.appBarTheme.copyWith(
        titleTextStyle: appTheme.appBarTheme.titleTextStyle!.copyWith(
          fontFamily: 'NotificationFocusPreview',
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: appTheme.textButtonTheme.style!.copyWith(
          textStyle: const WidgetStatePropertyAll(
            TextStyle(fontFamily: 'NotificationFocusPreview', fontSize: 13),
          ),
        ),
      ),
    );
  });
  for (final private in [false, true]) {
    testWidgets(
      'Notification opens the exact rewrite on a distant page (private=$private)',
      (tester) async {
        final api = gateway(private: private);
        final store = await mount(tester, api, helpSeen: false);
        expect(store.inbox.single.annotationID, 200);
        final draftKey = '${store.userID}:$private:20:user:2';
        if (!private) store.guidanceReviewDrafts[draftKey] = {100};
        await tester.tap(find.text(notificationTitle));
        await tester.pumpAndSettle();
        expect(note(200), findsOneWidget);
        expect(tester.widget<GuidanceInlineNote>(note(200)).active, isTrue);
        expect(note(300), findsNothing);
        final document = tester.state<ResumeDocumentViewState>(
          find.byType(ResumeDocumentView),
        );
        expect(document.document!.pages.length, greaterThan(2));
        expect(document.pageScroll.offset, greaterThan(400));
        expectInside(
          tester,
          note(200),
          find.byKey(const ValueKey('resume-gesture-viewport')),
        );
        expect(
          api.paths
              .lastWhere(
                (call) =>
                    call.$1 ==
                    (private
                        ? 'GetNotificationsIdGuidance'
                        : 'GetArticlesIdGuidance'),
              )
              .$2,
          {'id': '20'},
        );
        expect(find.byKey(const ValueKey('guidance-coach-card')), findsNothing);
        if (private) await capture(tester, 'notification-focus-rewrite');
        expect(writes(api), isEmpty);
        expect(store.guidanceReviewDrafts[draftKey], private ? isEmpty : {100});
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final saved in [false, true]) {
    testWidgets(
      'Accepted and staged rewrite notifications focus their changed text (saved=$saved)',
      (tester) async {
        final api = gateway(
          records: [
            annotation(
              100,
              path: 'work_experiences.0.description',
              replacement: '其他未处理的建议',
            ),
            annotation(
              200,
              replacement: '已采纳的改写内容',
              status: saved ? 'ACCEPTED' : 'PENDING',
            ),
          ],
        );
        if (saved) {
          final source = api.documents['GetResumesId']!['content'] as Map;
          ((source['work_experiences'] as List)[18] as Map)['description'] =
              '已采纳的改写内容';
        }
        ((api.documents['GetNotifications']!['items'] as List).single
                as Map)['actor_id'] =
            0;
        final store = await mount(tester, api, helpSeen: false);
        final draftKey = '${store.userID}:false:20:user:2';
        if (!saved) store.guidanceReviewDrafts[draftKey] = {200};
        await tester.tap(find.text(notificationTitle));
        await tester.pumpAndSettle();
        final view = tester.widget<ResumeDocumentView>(
          find.byType(ResumeDocumentView),
        );
        final document = tester.state<ResumeDocumentViewState>(
          find.byType(ResumeDocumentView),
        );
        final regions = resumeReviewRegions(
          document.document!,
          view.reviewHighlights,
          fallbackToField: view.reviewNotes.isEmpty,
        );
        final page = regions.indexWhere(
          (list) => list.any(
            (region) => region.highlights.any(
              (mark) => mark.key == 'accepted:annotation:200',
            ),
          ),
        );
        expect(page, greaterThan(0));
        final index = regions[page].indexWhere(
          (region) => region.highlights.any(
            (mark) => mark.key == 'accepted:annotation:200',
          ),
        );
        expectInside(
          tester,
          find.byKey(ValueKey('resume-review-region-$page-$index')),
          find.byKey(const ValueKey('resume-gesture-viewport')),
        );
        expect(document.pageScroll.offset, greaterThan(400));
        expect(note(200), findsNothing);
        expect(
          tester
              .widgetList<GuidanceInlineNote>(find.byType(GuidanceInlineNote))
              .every((note) => !note.active),
          isTrue,
        );
        expect(store.guidanceReviewDrafts[draftKey], saved ? isEmpty : {200});
        expect(find.byKey(const ValueKey('guidance-coach-card')), findsNothing);
        expect(writes(api), isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'A comment notification opens and reveals its exact discussion without reordering or reopening it',
    (tester) async {
      final api = gateway(
        private: true,
        target: 530,
        feedback: 'COMMENT',
        records: List.generate(
          40,
          (i) => annotation(
            539 - i,
            comment: 539 - i == 530
                ? '通知对应的具体评论'
                : '其他评论 ${539 - i}：${List.filled(4, quote).join()}',
          ),
        ),
        legacy: [
          annotation(
            530,
            path: 'work_experiences.0.description',
            comment: '旧建议恰好具有相同编号',
          ),
        ],
      );
      await mount(tester, api, helpSeen: false);
      await tester.tap(find.text(notificationTitle));
      await tester.pumpAndSettle();
      final focused = find.byKey(const ValueKey('notification-comment-530'));
      final list = find.byKey(const ValueKey('region-comments-list'));
      expect(focused, findsOneWidget);
      expectInside(tester, focused, list);
      expect(find.text('通知对应的具体评论'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('region-thread-toggle-legacy:530')),
        findsNothing,
      );
      await capture(tester, 'notification-focus-comment');
      final commentsScroll = tester.state<ScrollableState>(
        find.descendant(of: list, matching: find.byType(Scrollable)),
      );
      expect(commentsScroll.position.pixels, greaterThan(0));
      final targetRect = tester.getRect(focused);
      final targetOffset = commentsScroll.position.pixels;
      final initialColor = highlightColor(tester, focused)!;
      expect(initialColor.a, greaterThan(0));
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(milliseconds: 150));
      expect(highlightColor(tester, focused)!.a, lessThan(initialColor.a));
      expect(highlightColor(tester, focused)!.a, greaterThan(0));
      await tester.pump(const Duration(milliseconds: 200));
      expect(highlightColor(tester, focused)!.a, 0);
      expect(tester.getRect(focused), targetRect);
      expect(commentsScroll.position.pixels, targetOffset);
      expect(find.text('通知对应的具体评论'), findsOneWidget);
      await capture(tester, 'notification-focus-comment-cleared');
      commentsScroll.position.jumpTo(commentsScroll.position.minScrollExtent);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('region-comment-comment:500')),
        findsOneWidget,
      );
      final document = tester.state<ResumeDocumentViewState>(
        find.byType(ResumeDocumentView),
      );
      expect(document.pageScroll.offset, greaterThan(400));
      final offset = document.pageScroll.offset;
      expect(writes(api), isEmpty);
      await tester.tap(find.byTooltip('关闭评论'));
      await tester.pumpAndSettle();
      expect(list, findsNothing);
      expect(document.pageScroll.offset, offset);
      await tester.pump(const Duration(seconds: 1));
      expect(list, findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Reply notifications expand the target thread and reveal a deep reply without selecting a reply or focusing the keyboard',
    (tester) async {
      final records = [
        annotation(600, reviewer: 1, comment: '我的原评论'),
        for (var id = 601; id <= 650; id++)
          annotation(
            id,
            comment: id == 649
                ? '对方最新回复的位置'
                : '历史回复 $id：${List.filled(3, quote).join()}',
            parent: id - 1,
          ),
      ].reversed.toList();
      final api = gateway(
        owner: false,
        target: 649,
        feedback: 'REPLY',
        records: records,
      );
      await mount(tester, api, helpSeen: false);
      tester.view.physicalSize = const Size(320, 640);
      await tester.tap(find.text(notificationTitle));
      await tester.pumpAndSettle();
      final focused = find.byKey(const ValueKey('notification-comment-649'));
      expectInside(
        tester,
        focused,
        find.byKey(const ValueKey('region-comments-list')),
      );
      expect(find.text('对方最新回复的位置'), findsOneWidget);
      await capture(tester, 'notification-focus-reply');
      expect(find.text('收起回复'), findsOneWidget);
      final input = tester.widget<TextField>(
        find.byKey(const ValueKey('region-comment-input')),
      );
      expect(input.controller!.text, isEmpty);
      expect(input.focusNode!.hasFocus, isFalse);
      expect(highlightColor(tester, focused)!.a, greaterThan(0));
      await tester.tap(find.byTooltip('关闭评论'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 3));
      expect(find.byKey(const ValueKey('region-comments-list')), findsNothing);
      expect(api.calls, isNot(contains('GetResumesId')));
      expect(writes(api), isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'A comment taller than the discussion viewport reveals its beginning',
    (tester) async {
      final api = gateway(
        target: 200,
        feedback: 'COMMENT',
        records: [annotation(200, comment: List.filled(60, quote).join('\n'))],
      );
      await mount(tester, api);
      await tester.tap(find.text(notificationTitle));
      await tester.pumpAndSettle();
      final target = tester.getRect(
        find.byKey(const ValueKey('notification-comment-200')),
      );
      final viewport = tester.getRect(
        find.byKey(const ValueKey('region-comments-list')),
      );
      expect(target.height, greaterThan(viewport.height));
      expect(target.top, greaterThanOrEqualTo(viewport.top - 1));
      expect(target.top, lessThan(viewport.top + 40));
      expect(writes(api), isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  for (final target in [0, 999]) {
    testWidgets(
      'Missing or legacy notification targets keep the normal view without activating unrelated suggestions (target=$target)',
      (tester) async {
        final api = gateway(target: target);
        await mount(tester, api);
        await tester.tap(find.text(notificationTitle));
        await tester.pumpAndSettle();
        expect(find.byType(ResumeGuidanceView), findsOneWidget);
        expect(
          find.byKey(const ValueKey('region-comments-list')),
          findsNothing,
        );
        expect(
          tester
              .widgetList<GuidanceInlineNote>(find.byType(GuidanceInlineNote))
              .every((note) => !note.active),
          isTrue,
        );
        expect(
          tester
              .state<ResumeDocumentViewState>(find.byType(ResumeDocumentView))
              .pageScroll
              .offset,
          0,
        );
        expect(writes(api), isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('Loading can retry and still focus the requested annotation', (
    tester,
  ) async {
    final api = gateway()..failing = 'GetArticlesIdGuidanceAnnotations';
    await mount(tester, api);
    await tester.tap(find.text(notificationTitle));
    await tester.pumpAndSettle();
    expect(find.text('重新加载'), findsOneWidget);
    expect(find.byType(ResumeDocumentView), findsNothing);
    api.failing = null;
    await tester.tap(find.text('重新加载'));
    await tester.pumpAndSettle();
    expect(tester.widget<GuidanceInlineNote>(note(200)).active, isTrue);
    expectInside(
      tester,
      note(200),
      find.byKey(const ValueKey('resume-gesture-viewport')),
    );
    expect(writes(api), isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Leaving before a delayed annotation response cannot open a late discussion',
    (tester) async {
      final api = gateway(
        target: 200,
        feedback: 'COMMENT',
        records: [annotation(200, comment: '迟到的评论')],
      );
      final delayed = Completer<ApiDocument>();
      api.delayedAnnotations = delayed;
      await mount(tester, api);
      await tester.tap(find.text(notificationTitle));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(ResumeGuidanceView), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      delayed.complete(
        ApiDocument({
          'items': [annotation(200, comment: '迟到的评论')],
        }),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ResumeGuidanceView), findsNothing);
      expect(find.byKey(const ValueKey('region-comments-list')), findsNothing);
      expect(api.calls, isNot(contains('GetResumesId')));
      expect(writes(api), isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}
