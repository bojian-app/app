import 'package:bojian_mobile/design.dart';
import 'package:bojian_mobile/messages_page.dart';
import 'package:bojian_mobile/resume_document.dart';
import 'package:bojian_mobile/resume_guidance_review.dart';
import 'package:bojian_mobile/resume_guidance_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

const field = 'work_experiences.0.description';
Map<String, dynamic> record(
  int id,
  int user, {
  String comment = '',
  String replacement = '',
  String status = 'PENDING',
}) => {
  'id': id,
  'reviewer_id': user,
  'reviewer_name': '用户$user',
  'field_path': field,
  'selected_text': '网站开发',
  'suggestion': comment,
  'replacement': replacement,
  'status': status,
};
Map<String, dynamic> shared(bool owner) => {
  'is_owner': owner,
  'source_resume_id': owner ? 42 : null,
  'snapshot': {
    'work_experiences': [
      {'company': '公司', 'description': '负责网站开发与性能优化'},
    ],
  },
};
FakeGateway gateway() => FakeGateway()
  ..documents['GetResumesId'] = {
    'id': 42,
    'revision': 1,
    'title': '原简历',
    'content': {
      'personal_info': {'full_name': '作者', 'phone': '13800000000'},
      'work_experiences': [
        {'company': '公司', 'description': '负责网站开发与性能优化'},
      ],
    },
  };

void main() {
  testWidgets(
    'Author opens own share as plain resume detail, even with a reviewer key',
    (tester) async {
      final api = gateway();
      final store = await testStore(authenticated: true, api: api);
      addTearDown(store.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: ResumeGuidanceView(
            store: store,
            id: 20,
            initialData: shared(true),
            reviewerKey: 'user:2',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('简历详情'), findsOneWidget);
      expect(find.byType(GuidanceParticipantList), findsNothing);
      expect(api.calls, isNot(contains('GetArticlesIdGuidanceAnnotations')));
      final view = tester.widget<ResumeDocumentView>(
        find.byType(ResumeDocumentView),
      );
      expect(view.resume.phone, '13800000000');
      expect(view.reviewHighlights, isEmpty);
      expect(view.reviewNotes, isEmpty);
      expect(view.onAnnotate, isNull);
    },
  );

  for (final notification in [false, true]) {
    testWidgets(
      'Other viewer sees all comments and only own rewrites ($notification)',
      (tester) async {
        final api = gateway();
        final store = await testStore(authenticated: true, api: api);
        addTearDown(store.dispose);
        final resource = notification ? 'Notifications' : 'Articles';
        api.documents['Get${resource}IdGuidanceAnnotations'] = {
          'items': [
            record(1, store.userID, comment: '我的评论'),
            record(2, 2, comment: '他人的评论'),
            record(3, store.userID, replacement: '我的改写'),
            record(4, 2, replacement: '他人的改写'),
            record(5, 3, replacement: '他人已采纳改写', status: 'ACCEPTED'),
          ],
        };
        await tester.pumpWidget(
          MaterialApp(
            theme: appTheme,
            home: ResumeGuidanceView(
              store: store,
              id: 20,
              initialData: shared(false),
              notification: notification,
            ),
          ),
        );
        await tester.pumpAndSettle();
        final view = tester.widget<ResumeDocumentView>(
          find.byType(ResumeDocumentView),
        );
        expect(view.onAnnotate, isNotNull);
        expect(find.text('我的优化建议'), findsNothing);
        expect(
          view.reviewHighlights
              .singleWhere((mark) => mark.commentCount > 0)
              .commentCount,
          2,
        );
        final rewrite = view.reviewHighlights.singleWhere(
          (mark) => mark.key == 'annotation:3',
        );
        expect(rewrite.colorText, isTrue);
        expect(rewrite.color, guidanceReplacementColor);
        expect(
          view.reviewHighlights.any(
            (mark) =>
                mark.key.contains('annotation:4') ||
                mark.key.contains('annotation:5'),
          ),
          isFalse,
        );
        expect(view.reviewNotes, isEmpty);
        expect(
          view.resume.source['work_experiences'][0]['description'],
          '负责我的改写与性能优化',
        );
        expect(rewrite.text, '我的改写');
        expect(find.text('待采纳'), findsOneWidget);
        expect(find.text('他人的改写'), findsNothing);
        expect(find.text('他人已采纳改写'), findsNothing);
        expect(find.text('采纳'), findsNothing);
        expect(find.text('不采纳'), findsNothing);
        final mark = view.reviewHighlights.singleWhere(
          (mark) => mark.commentCount > 0,
        );
        await tester.tap(find.byKey(ValueKey('comment-badge-${mark.key}')));
        await tester.pumpAndSettle();
        expect(find.text('我的评论'), findsOneWidget);
        expect(find.text('他人的评论'), findsOneWidget);
        await tester.tap(find.byIcon(Icons.close));
        await tester.pumpAndSettle();
        await tester.tap(find.bySemanticsLabel('选中区域：负责我的改写与性能优化'));
        await tester.pumpAndSettle();
        expect(find.text('查看评论'), findsOneWidget);
        expect(find.text('参与改写'), findsOneWidget);
      },
    );
  }

  testWidgets(
    'Own rewrites replace text with status tags while comments and submissions keep canonical quotes',
    (tester) async {
      final api = gateway();
      final store = await testStore(authenticated: true, api: api);
      addTearDown(store.dispose);
      final snapshot = {
        'work_experiences': [
          {'company': '公司', 'description': '负责网站开发'},
          {'company': '公司', 'description': '负责数据建模'},
          {'company': '公司', 'description': '负责系统部署'},
        ],
      };
      api.documents['GetArticlesIdGuidanceAnnotations'] = {
        'items': [
          record(1, store.userID, replacement: '前端研发'),
          {
            ...record(2, store.userID, replacement: '数据建模', status: 'ACCEPTED'),
            'field_path': 'work_experiences.1.description',
            'selected_text': '数据分析',
          },
          {
            ...record(
              3,
              store.userID,
              replacement: '自动化发布',
              status: 'REJECTED',
            ),
            'field_path': 'work_experiences.2.description',
            'selected_text': '系统部署',
          },
          record(0, store.userID, replacement: '旧改写'),
          record(5, 2, replacement: '他人改写不可见'),
          record(8, 2, comment: '这段评论仍可见'),
        ],
      };
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: ResumeGuidanceView(
            store: store,
            id: 20,
            initialData: {'is_owner': false, 'snapshot': snapshot},
          ),
        ),
      );
      await tester.pumpAndSettle();
      final view = tester.widget<ResumeDocumentView>(
        find.byType(ResumeDocumentView),
      );
      final state = tester.state<ResumeDocumentViewState>(
        find.byType(ResumeDocumentView),
      );
      String visible() => state.displayedDocument!.pages
          .expand((page) => page.ink)
          .map((run) => run.visibleText)
          .join();
      expect(visible(), contains('负责前端研发'));
      expect(visible(), contains('负责数据建模'));
      expect(visible(), contains('负责自动化发布'));
      expect(visible(), isNot(contains('旧改写')));
      expect(visible(), isNot(contains('他人改写不可见')));
      expect(view.reviewNotes, isEmpty);
      expect(view.reviewNoteBuilder, isNull);
      expect(find.text('待采纳'), findsOneWidget);
      expect(find.text('已采纳'), findsOneWidget);
      expect(find.text('未采纳'), findsOneWidget);
      expect(find.text('前端研发'), findsNothing);
      expect(find.text('采纳'), findsNothing);
      expect(snapshot['work_experiences']![0]['description'], '负责网站开发');
      final comment = view.reviewHighlights.singleWhere(
        (mark) => mark.commentCount > 0,
      );
      expect(comment.text, '前端研发');
      expect(comment.sourceText, '网站开发');
      final regions = resumeReviewRegions(
        state.document!,
        view.reviewHighlights,
      );
      expect(
        regions
            .expand((page) => page)
            .any(
              (region) =>
                  region.highlights.contains(comment) &&
                  region.waveRects.isNotEmpty,
            ),
        isTrue,
      );
      final rewriteRegion = regions[0].firstWhere(
        (region) => region.highlights.any((mark) => mark.key == 'annotation:1'),
      );
      final sheet = find.byKey(const ValueKey('resume-sheet-0'));
      final scale = tester.getSize(sheet).width / resumePaperSize.width;
      final gesture = await tester.startGesture(
        tester.getTopLeft(sheet) + rewriteRegion.rect.center * scale,
      );
      await tester.pump();
      expect(visible(), contains('负责网站开发'));
      expect(visible(), contains('负责自动化发布'));
      expect(
        find.byKey(ValueKey('comment-badge-${comment.key}')),
        findsOneWidget,
      );
      expect(find.text('待采纳'), findsOneWidget);
      await gesture.moveBy(const Offset(70, 30));
      await tester.pump();
      expect(visible(), contains('负责网站开发'));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(visible(), contains('负责前端研发'));
      await tester.tap(find.byKey(ValueKey('comment-badge-${comment.key}')));
      await tester.pumpAndSettle();
      expect(find.text('这段评论仍可见'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('选中区域：负责前端研发'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('参与改写'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '负责网站开发',
      );
      await tester.enterText(find.byType(TextField), '再次改写');
      await tester.tap(find.text('提交替换建议'));
      await tester.pumpAndSettle();
      expect(api.lastMutationBody!['field_value'], '负责网站开发');
      expect(api.lastMutationBody!['selected_text'], '负责网站开发');
      expect(api.lastMutationBody!['replacement'], '再次改写');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Feedback notification selects its actor and shows all comments but only that actor’s rewrites',
    (tester) async {
      final api = gateway();
      api.documents['GetNotifications'] = {
        'items': [
          {
            'id': 100,
            'type': 'RESUME_GUIDANCE_FEEDBACK',
            'actor_id': 2,
            'subject_type': 'ARTICLE',
            'subject_id': 20,
            'payload': {'title': '收到简历指点'},
          },
        ],
      };
      api.documents['GetArticlesIdGuidance'] = shared(true);
      api.documents['GetArticlesIdGuidanceAnnotations'] = {
        'items': [
          record(1, 2, comment: '对应用户评论'),
          record(2, 3, comment: '其他用户评论'),
          record(3, 2, replacement: '对应用户改写'),
          record(4, 3, replacement: '其他用户改写'),
          record(5, 3, replacement: '他人已采纳内容', status: 'ACCEPTED'),
        ],
      };
      final store = await testStore(authenticated: true, api: api);
      addTearDown(store.dispose);
      expect(store.inbox.single.actorID, 2);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: Scaffold(body: MessagesPage(store: store)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('收到简历指点'));
      await tester.pumpAndSettle();
      final route = tester.widget<ResumeGuidanceView>(
        find.byType(ResumeGuidanceView),
      );
      expect(route.fromNotification, isTrue);
      expect(route.reviewerKey, 'user:2');
      expect(find.byType(GuidanceParticipantList), findsNothing);
      final view = tester.widget<ResumeDocumentView>(
        find.byType(ResumeDocumentView),
      );
      expect(
        view.reviewHighlights
            .where((mark) => mark.commentCount > 0)
            .single
            .commentCount,
        2,
      );
      expect(
        view.reviewHighlights
            .where((mark) => mark.commentCount == 0)
            .single
            .key,
        'annotation:3',
      );
      expect(find.text('对应用户改写'), findsOneWidget);
      expect(find.text('其他用户改写'), findsNothing);
      expect(find.text('他人已采纳内容'), findsNothing);
      expect(find.text('采纳'), findsOneWidget);
      expect(view.onAnnotate, isNull);
    },
  );
}
