import 'dart:io';
import 'dart:ui' as ui;

import 'package:bojian_mobile/app_store.dart';
import 'package:bojian_mobile/design.dart';
import 'package:bojian_mobile/resume_document.dart';
import 'package:bojian_mobile/resume_guidance_review.dart';
import 'package:bojian_mobile/resume_guidance_view.dart';
import 'package:bojian_mobile/guidance_inline_note.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

const path = 'work_experiences.0.description';
Map<String, dynamic> advice(
  int id,
  int user, {
  String selected = '网站开发',
  String comment = '',
  String replacement = '',
  String status = 'PENDING',
}) => {
  'id': id,
  'reviewer_id': user,
  'reviewer_name': '同名用户',
  'field_path': path,
  'selected_text': selected,
  'suggestion': comment,
  'replacement': replacement,
  'status': status,
  'created_at': '2026-10-10T05:30:00Z',
};
Map<String, dynamic> owner() => {
  'id': 20,
  'is_owner': true,
  'source_resume_id': 42,
  'title': '前端开发简历',
  'snapshot': {},
};
FakeGateway gateway() {
  final api = FakeGateway();
  api.documents['GetResumesId'] = {
    'id': 42,
    'revision': 1,
    'title': '前端开发简历',
    'content': {
      'personal_info': {'full_name': '测试作者', 'phone': '13800000000'},
      'work_experiences': [
        {
          'company': '公司名称',
          'position': '前端工程师',
          'description': '负责网站开发与性能优化，搭建业务组件并改善用户体验。',
        },
      ],
      'projects': [
        {'name': '项目名称', 'description': '负责网站开发与性能优化'},
      ],
    },
  };
  api.documents['GetArticlesIdGuidance'] = owner();
  return api;
}

void main() {
  testWidgets(
    'Closing comments preserves review state and replies update only comment counts',
    (tester) async {
      final api = gateway();
      final comment = advice(7, 2, comment: '补充指标');
      final rewrite = advice(8, 2, selected: '性能优化', replacement: '平台优化');
      api.documents['GetArticlesIdGuidanceAnnotations'] = {
        'items': [comment, rewrite],
      };
      final store = await testStore(authenticated: true, api: api);
      addTearDown(store.dispose);
      final draftKey = '${store.userID}:false:20:user:2';
      store.guidanceReviewDrafts[draftKey] = {8};
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: ResumeGuidanceView(
            store: store,
            id: 20,
            initialData: owner(),
            fromNotification: true,
            reviewerKey: 'user:2',
          ),
        ),
      );
      await tester.pumpAndSettle();
      final state = tester.state<ResumeDocumentViewState>(
        find.byType(ResumeDocumentView),
      );
      final document = state.document;
      final resume = tester
          .widget<ResumeDocumentView>(find.byType(ResumeDocumentView))
          .resume;
      state.changeZoom(1.1);
      state.pageScroll.jumpTo(12);
      await tester.pumpAndSettle();
      final transform = state.transform.value.clone();
      final offset = state.pageScroll.offset;
      Finder badge() => find.byKey(
        ValueKey(
          'comment-badge-${tester.widget<ResumeDocumentView>(find.byType(ResumeDocumentView)).reviewHighlights.singleWhere((mark) => mark.commentCount > 0).key}',
        ),
      );
      await tester.tap(badge());
      await tester.pumpAndSettle();
      final callsBeforeClose = List<String>.from(api.calls);
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(api.calls, callsBeforeClose);
      expect(state.document, same(document));
      expect(state.transform.value, transform);
      expect(state.pageScroll.offset, offset);
      expect(store.guidanceReviewDrafts[draftKey], {8});
      await tester.tap(badge());
      await tester.pumpAndSettle();
      await tester.tap(find.text('回复'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '已补充');
      await tester.pump();
      api.documents['GetArticlesIdGuidanceAnnotations'] = {
        'items': [
          comment,
          rewrite,
          {...advice(9, 1, comment: '已补充'), 'parent_id': 7},
        ],
      };
      final resumeReads = api.calls
          .where((call) => call == 'GetResumesId')
          .length;
      await tester.tap(find.text('发送'));
      await tester.pumpAndSettle();
      expect(find.text('评论（2）'), findsOneWidget);
      final callsAfterReply = List<String>.from(api.calls);
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(api.calls, callsAfterReply);
      expect(
        api.calls.where((call) => call == 'GetResumesId').length,
        resumeReads,
      );
      final view = tester.widget<ResumeDocumentView>(
        find.byType(ResumeDocumentView),
      );
      expect(
        view.reviewHighlights
            .singleWhere((mark) => mark.commentCount > 0)
            .commentCount,
        2,
      );
      expect(view.resume.source, resume.source);
      expect(state.document, same(document));
      expect(state.transform.value, transform);
      expect(state.pageScroll.offset, offset);
      expect(store.guidanceReviewDrafts[draftKey], {8});
    },
  );

  test('Review comparison preserves rich styling, strikes only the original and adds a new line', () {
    const input = TextSpan(
      style: TextStyle(fontSize: 10),
      children: [
        TextSpan(
          text: '负责',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        TextSpan(
          text: '前端开发',
          style: TextStyle(fontStyle: FontStyle.italic),
        ),
        TextSpan(text: '与协作'),
      ],
    );
    final output = resumeReviewComparison(
      input,
      const ResumeReviewChange(
        key: 'one',
        fieldPath: path,
        original: '前端开发',
        replacement: '性能优化',
      ),
    );
    expect(output.toPlainText(), '负责前端开发与协作\n性能优化');
    final styles = <String, TextStyle?>{};
    void walk(InlineSpan value) {
      if (value is TextSpan) {
        if (value.text != null) styles[value.text!] = value.style;
        for (final child in value.children ?? <InlineSpan>[]) {
          walk(child);
        }
      }
    }

    walk(output);
    expect(styles['负责']!.fontWeight, FontWeight.bold);
    expect(styles['前端开发']!.fontStyle, FontStyle.italic);
    expect(
      styles['前端开发']!.decoration!.contains(TextDecoration.lineThrough),
      isTrue,
    );
    expect(styles['与协作']!.decoration, isNull);
    expect(styles['\n性能优化']!.decoration, isNull);
    expect(input.toPlainText(), '负责前端开发与协作');
  });

  test('Draft adoption combines disjoint edits, keeps styles and leaves the original unchanged', () {
    final original = ResumeDraft(
      id: 10,
      title: '原简历',
      source: {
        'work_experiences': [
          {
            'description': '负责开发网站',
            'description_rich': {
              'blocks': [
                {
                  'spans': [
                    {'text': '负责', 'bold': true},
                    {'text': '开发网站', 'italic': true},
                  ],
                },
              ],
            },
          },
        ],
      },
    );
    final changes = [
      advice(1, 2, selected: '负责', replacement: '主导'),
      advice(2, 2, selected: '开发网站', replacement: '前端研发'),
    ];
    final draft = guidanceDraftResume(original, changes);
    final work = (draft.source['work_experiences'] as List).first as Map;
    expect(work['description'], '主导前端研发');
    final spans =
        ((work['description_rich'] as Map)['blocks'] as List).first['spans']
            as List;
    expect(spans.first['bold'], isTrue);
    expect(spans.last['italic'], isTrue);
    expect(
      (original.source['work_experiences'] as List).first['description'],
      '负责开发网站',
    );
    expect(
      () => guidanceDraftResume(original, [
        changes.first,
        advice(3, 2, selected: '负责开发', replacement: '协助'),
      ]),
      throwsStateError,
    );
  });
  testWidgets(
    'Author first sees participants; same-name people remain separate; only selected reviewer marks and details appear',
    (tester) async {
      final api = gateway();
      api.documents['GetArticlesIdGuidanceAnnotations'] = {
        'items': [
          advice(7, 2, comment: '可以补充具体指标'),
          advice(8, 2, selected: '性能优化', replacement: '首屏加载耗时降低 30%'),
          advice(9, 3, selected: '负责', comment: '另一位用户的建议'),
        ],
      };
      final store = await testStore(authenticated: true, api: api);
      addTearDown(store.dispose);
      final boundary = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MaterialApp(
            theme: appTheme,
            home: ResumeGuidanceView(
              store: store,
              id: 20,
              initialData: owner(),
              fromNotification: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('同名用户'), findsNWidgets(2));
      expect(find.byType(ResumeDocumentView), findsNothing);
      expect(api.calls, isNot(contains('GetResumesId')));
      await tester.tap(
        find.byKey(const ValueKey('guidance-participant-user:2')),
      );
      await tester.pumpAndSettle();
      final view = tester.widget<ResumeDocumentView>(
        find.byType(ResumeDocumentView),
      );
      expect(view.resume.phone, '13800000000');
      expect(view.onAnnotate, isNull);
      expect(
        view.reviewHighlights.where((v) => v.commentCount > 0),
        hasLength(2),
      );
      final commentMark = view.reviewHighlights.singleWhere(
        (mark) => mark.text == '网站开发',
      );
      expect(commentMark.isWavy, isTrue);
      final commentRegions = resumeReviewRegions(
        (tester.state(find.byType(ResumeDocumentView)) as dynamic).document
            as ResumeDocument,
        view.reviewHighlights,
      );
      for (var page = 0; page < commentRegions.length; page++) {
        for (var i = 0; i < commentRegions[page].length; i++) {
          if (commentRegions[page][i].highlights.every(
            (mark) => mark.commentCount > 0,
          )) {
            expect(
              find.byKey(ValueKey('resume-review-region-$page-$i')),
              findsNothing,
            );
          }
        }
      }

      expect(commentMark.color, guidanceCommentColor);
      expect(
        view.reviewHighlights
            .singleWhere((mark) => mark.key == 'annotation:8')
            .colorText,
        isTrue,
      );
      expect(view.reviewNotes.any((v) => v.key == 'annotation:7'), isFalse);
      expect(view.reviewChanges, isEmpty);
      expect(
        view.reviewNotes
            .singleWhere((note) => note.key == 'annotation:8')
            .selectedText,
        '性能优化',
      );
      expect(find.text('复位'), findsNothing);
      await tester.runAsync(() async {
        final image =
            await (boundary.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('/tmp/bojian-review-watercolor.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
      expect(find.text('可以补充具体指标'), findsNothing);
      await tester.tap(
        find.byKey(ValueKey('comment-badge-${commentMark.key}')),
      );
      await tester.pumpAndSettle();
      expect(find.text('可以补充具体指标'), findsOneWidget);
      expect(find.text('另一位用户的建议'), findsNothing);
      expect(find.byType(BottomSheet), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(find.text('查看此人的全部记录'), findsNothing);
      final document = tester
          .state<ResumeDocumentViewState>(find.byType(ResumeDocumentView))
          .document!;
      final content = document.pages
          .expand((p) => p.ink)
          .map((v) => v.text.text!.toPlainText())
          .join('\n');
      expect(content, contains('性能优化'));
      expect(document.pages.expand((p) => p.reviewNotes).length, 1);
      expect(find.byType(GuidanceInlineNote), findsOneWidget);

      final replacementNote = find.widgetWithText(
        GuidanceInlineNote,
        '首屏加载耗时降低 30%',
      );
      expect(
        find.descendant(
          of: replacementNote,
          matching: find.byKey(const ValueKey('guidance-rewrite-card')),
        ),
        findsOneWidget,
      );
      expect(
        tester.widget<Text>(find.text('首屏加载耗时降低 30%')).style!.color,
        guidanceReplacementColor,
      );
      expect(
        find.descendant(of: replacementNote, matching: find.text('采纳')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: replacementNote, matching: find.text('不采纳')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Historical field comments underline their original field', (
    tester,
  ) async {
    final api = gateway();
    api.documents['GetArticlesIdGuidanceAnnotations'] = {'items': []};
    final data = owner();
    data['suggestions'] = [
      advice(99, 2, selected: '', comment: '补充项目指标')..remove('selected_text'),
    ];
    final store = await testStore(authenticated: true, api: api);
    addTearDown(store.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: ResumeGuidanceView(
          store: store,
          id: 20,
          initialData: data,
          fromNotification: true,
          reviewerKey: 'user:2',
        ),
      ),
    );
    await tester.pumpAndSettle();
    final view = tester.widget<ResumeDocumentView>(
      find.byType(ResumeDocumentView),
    );
    final doc = tester
        .state<ResumeDocumentViewState>(find.byType(ResumeDocumentView))
        .document!;
    final marks = resumeReviewRegions(
      doc,
      view.reviewHighlights,
    ).expand((page) => page).toList();
    expect(marks, isNotEmpty);
    expect(marks.every((mark) => mark.waveRects.isNotEmpty), isTrue);
    expect(doc.pages.expand((page) => page.reviewNotes), isEmpty);
    expect(find.text('补充项目指标'), findsNothing);
    final comment = view.reviewHighlights.singleWhere(
      (v) => v.commentCount > 0,
    );
    await tester.tap(find.byKey(ValueKey('comment-badge-${comment.key}')));
    await tester.pumpAndSettle();
    expect(find.text('补充项目指标'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Author empty state does not fetch original; failed participant fetch offers retry',
    (tester) async {
      final api = gateway();
      final store = await testStore(authenticated: true, api: api);
      addTearDown(store.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: ResumeGuidanceView(
            store: store,
            id: 20,
            initialData: owner(),
            fromNotification: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('暂时还没有人参与指点'), findsOneWidget);
      expect(find.byType(ResumeDocumentView), findsNothing);
      expect(api.calls, isNot(contains('GetResumesId')));
    },
  );
  test('Watercolor anchors survive page splits, stay in their field, and fall back to that field for changed text', () {
    final draft = ResumeDraft(
      id: 42,
      title: '简历',
      source: {
        'work_experiences': [
          {
            'description': List.generate(
              100,
              (i) => '工作第$i行：开发网站并优化性能。',
            ).join('\n'),
          },
        ],
        'projects': [
          {'name': '项目', 'description': '工作第99行：开发网站并优化性能。'},
        ],
      },
    );
    final document = ResumeDocument(draft);
    addTearDown(document.dispose);
    final marks = resumeReviewRegions(document, [
      const ResumeReviewHighlight(
        key: 'a',
        fieldPath: path,
        text: '工作第99行：开发网站并优化性能。',
        color: guidanceCommentColor,
        label: '评论',
      ),
    ]);
    expect(marks.expand((v) => v), isNotEmpty);
    for (var page = 0; page < marks.length; page++) {
      for (final mark in marks[page]) {
        expect(
          document.pages[page].ink.any(
            (run) =>
                run.fieldPath == path &&
                Rect.fromLTWH(
                  run.position.dx,
                  run.position.dy,
                  run.text.width,
                  run.height,
                ).overlaps(mark.rect),
          ),
          isTrue,
        );
        expect(mark.rect.bottom, lessThan(resumePaperSize.height));
      }
    }
    final fallback = resumeReviewRegions(document, [
      const ResumeReviewHighlight(
        key: 'b',
        fieldPath: path,
        text: '已经被作者删掉的原文',
        color: guidanceReplacementColor,
        label: '修改建议',
      ),
    ]);
    expect(fallback.expand((v) => v), isNotEmpty);
    expect(
      resumeReviewRegions(document, [
        const ResumeReviewHighlight(
          key: 'none',
          fieldPath: 'projects.1.description',
          text: '开发网站',
          color: guidanceCommentColor,
          label: '评论',
        ),
      ]).expand((v) => v),
      isEmpty,
    );
  });
  testWidgets(
    'Saved replacements show final text without a strike or suggestion card',
    (tester) async {
      final api = gateway();
      (api.documents['GetResumesId']!['content'] as Map)['work_experiences'] = [
        {'company': '公司', 'description': '负责前端研发与性能优化'},
      ];
      api.documents['GetArticlesIdGuidanceAnnotations'] = {
        'items': [
          advice(
            7,
            2,
            selected: '网站开发',
            replacement: '前端研发',
            status: 'ACCEPTED',
          ),
        ],
      };
      final store = await testStore(authenticated: true, api: api);
      addTearDown(store.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: ResumeGuidanceView(
            store: store,
            id: 20,
            initialData: owner(),
            fromNotification: true,
            reviewerKey: 'user:2',
          ),
        ),
      );
      await tester.pumpAndSettle();
      final document = tester
          .state<ResumeDocumentViewState>(find.byType(ResumeDocumentView))
          .document!;
      final content = document.pages
          .expand((p) => p.ink)
          .map((v) => v.text.text!.toPlainText())
          .join('\n');
      final workContent = document.pages
          .expand((p) => p.ink)
          .where((v) => v.fieldPath == path)
          .map((v) => v.text.text!.toPlainText())
          .join('\n');
      expect(workContent, isNot(contains('网站开发')));
      expect(content, contains('前端研发'));
      expect(find.byType(GuidanceInlineNote), findsNothing);
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text('采纳'), findsNothing);
      final view = tester.widget<ResumeDocumentView>(
        find.byType(ResumeDocumentView),
      );
      final mark = view.reviewHighlights.singleWhere(
        (v) => v.key.startsWith('accepted:'),
      );
      expect(mark.text, '前端研发');
      expect(mark.isWavy, isFalse);
      expect(mark.colorText, isTrue);
      expect(mark.color, guidanceReplacementColor);
      final regions = resumeReviewRegions(
        document,
        view.reviewHighlights,
      ).expand((v) => v).toList();
      expect(regions, isNotEmpty);
      expect(regions.every((v) => v.waveRects.isNotEmpty), isTrue);
      final target = find.byKey(const ValueKey('resume-review-region-0-0'));
      final state = tester.state<ResumeDocumentViewState>(
        find.byType(ResumeDocumentView),
      );
      String visibleText() => state.displayedDocument!.pages
          .expand((p) => p.ink)
          .where((r) => r.fieldPath == 'work_experiences.0.description')
          .map((r) => r.visibleText)
          .join();
      final press = await tester.startGesture(tester.getCenter(target));
      await tester.pump();
      expect(visibleText(), contains('网站开发'));
      expect(visibleText(), isNot(contains('前端研发')));
      expect(find.byType(BottomSheet), findsNothing);
      expect(
        view.resume.source['work_experiences'][0]['description'],
        contains('前端研发'),
      );
      await press.up();
      await tester.pumpAndSettle();
      expect(visibleText(), contains('前端研发'));
      expect(visibleText(), isNot(contains('网站开发')));
      final cancelled = await tester.startGesture(tester.getCenter(target));
      await tester.pump();
      expect(visibleText(), contains('网站开发'));
      await cancelled.cancel();
      await tester.pump();
      expect(visibleText(), contains('前端研发'));
      final drag = await tester.startGesture(tester.getCenter(target));
      await tester.pump();
      final scrollBefore = state.pageScroll.offset;
      final transformBefore = state.transform.value.clone();
      await drag.moveBy(const Offset(100, -80));
      await tester.pump();
      expect(visibleText(), contains('网站开发'));
      await drag.moveBy(const Offset(-160, 160));
      await tester.pump();
      expect(visibleText(), contains('网站开发'));
      expect(state.pageScroll.offset, scrollBefore);
      expect(state.transform.value, transformBefore);
      await drag.up();
      await tester.pumpAndSettle();
      expect(visibleText(), contains('前端研发'));
      final first = await tester.startGesture(
        tester.getCenter(target),
        pointer: 10,
      );
      await tester.pump();
      expect(visibleText(), contains('网站开发'));
      final second = await tester.startGesture(
        tester.getCenter(target) + const Offset(40, 0),
        pointer: 11,
      );
      await tester.pump();
      expect(visibleText(), contains('网站开发'));
      await second.moveBy(const Offset(60, 30));
      await tester.pump();
      expect(visibleText(), contains('网站开发'));
      await second.up();
      await tester.pump();
      expect(visibleText(), contains('网站开发'));
      await first.up();
      await tester.pumpAndSettle();
      expect(visibleText(), contains('前端研发'));
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text('采纳'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
