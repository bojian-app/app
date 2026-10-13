import 'package:bojian_mobile/design.dart';
import 'package:bojian_mobile/resume_document.dart';
import 'package:bojian_mobile/resume_guidance_annotations.dart';
import 'package:bojian_mobile/resume_guidance_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

Map<String, dynamic> shared({bool owner = false}) => {
  'id': 20,
  'is_owner': owner,
  'source_resume_id': owner ? 42 : null,
  'snapshot': {
    'work_experiences': [
      {'company': '公司', 'description': '负责网站开发与性能优化'},
    ],
  },
};
void main() {
  for (final notification in [false, true]) {
    testWidgets(
      'Own guidance records use a full page and filter other reviewers ($notification)',
      (tester) async {
        final api = FakeGateway();
        final store = await testStore(authenticated: true, api: api);
        addTearDown(store.dispose);
        final prefix = notification ? 'Notifications' : 'Articles';
        final mine = store.userID;
        expect(mine, greaterThan(0));
        api.documents['Get${prefix}IdGuidance'] = {
          ...shared(),
          'suggestions': [
            {'id': 4, 'reviewer_id': mine, 'suggestion': '我的早期建议'},
          ],
        };
        api.documents['Get${prefix}IdGuidanceAnnotations'] = {
          'items': [
            {
              'id': 1,
              'reviewer_id': mine,
              'selected_text': '原句',
              'replacement': '我的改写',
              'status': 'PENDING',
            },
            {'id': 2, 'reviewer_id': mine, 'suggestion': '我的评论'},
            {'id': 3, 'reviewer_id': mine + 1, 'suggestion': '别人的评论'},
          ],
        };
        await tester.pumpWidget(
          MaterialApp(
            theme: appTheme,
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => openPage(
                    context,
                    GuidanceAnnotations(
                      store: store,
                      id: 20,
                      notification: notification,
                      owner: false,
                      mineOnly: true,
                      currentSnapshot: shared()['snapshot'] as Map?,
                      onChanged: () {},
                    ),
                  ),
                  child: const Text('打开记录'),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('打开记录'));
        await tester.pumpAndSettle();
        expect(find.text('我的优化建议'), findsOneWidget);
        expect(find.byType(BottomSheet), findsNothing);
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.text('我的改写'), findsOneWidget);
        expect(find.text('等待作者确认'), findsOneWidget);
        expect(find.text('别人的评论'), findsNothing);
        expect(find.text('采纳'), findsNothing);
        final records = find.byType(ListView);
        await tester.scrollUntilVisible(
          find.text('我的早期建议'),
          250,
          scrollable: find.descendant(
            of: records,
            matching: find.byType(Scrollable),
          ),
        );
        expect(find.text('我的早期建议'), findsOneWidget);
        await tester.pageBack();
        await tester.pumpAndSettle();
        api.failing = 'Get${prefix}IdGuidanceAnnotations';
        await tester.tap(find.text('打开记录'));
        await tester.pumpAndSettle();
        expect(find.text('重新加载'), findsOneWidget);
        api.failing = null;
        api.documents['Get${prefix}IdGuidanceAnnotations'] = {
          'items': [
            {
              'id': 1,
              'reviewer_id': mine,
              'replacement': '我的改写',
              'status': 'ACCEPTED',
            },
          ],
        };
        await tester.tap(find.text('重新加载'));
        await tester.pumpAndSettle();
        expect(find.text('作者已采纳'), findsOneWidget);
      },
    );
  }
  for (final replace in [true, false]) {
    testWidgets(
      '${replace ? "Rewrite" : "Comment"} input and submit stay above keyboard with a long quote',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetViewInsets);
        final api = FakeGateway();
        final store = await testStore(authenticated: true, api: api);
        addTearDown(store.dispose);
        final original = List.generate(
          40,
          (i) => '第$i项：负责业务开发与性能优化。',
        ).join('\n');
        await tester.pumpWidget(
          MaterialApp(
            theme: appTheme,
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => composeGuidanceAnnotation(
                    context,
                    store: store,
                    id: 20,
                    notification: false,
                    snapshot: {
                      'work_experiences': [
                        {'description': original},
                      ],
                    },
                    fieldPath: 'work_experiences.0.description',
                    selectedText: original,
                    replace: replace,
                  ),
                  child: const Text('打开'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('打开'));
        await tester.pumpAndSettle();
        expect(
          find.byWidgetPredicate(
            (widget) => widget is Text && widget.data == original,
          ),
          replace ? findsNothing : findsOneWidget,
        );
        if (replace) {
          expect(
            tester.widget<TextField>(find.byType(TextField)).controller!.text,
            original,
          );
        }
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        await tester.pumpAndSettle();
        final field = find.byType(TextField);
        final submit = find.byKey(const ValueKey('annotation-submit'));
        void expectVisible(double keyboardTop) {
          final inputRect = tester.getRect(field);
          final buttonRect = tester.getRect(submit);
          expect(inputRect.top, greaterThanOrEqualTo(0));
          expect(inputRect.bottom, lessThanOrEqualTo(buttonRect.top));
          expect(buttonRect.bottom, lessThanOrEqualTo(keyboardTop));
          expect(submit.hitTestable(), findsOneWidget);
          expect(tester.takeException(), isNull);
        }

        expectVisible(340);
        await tester.enterText(field, '这是修改后的内容');
        tester.view.viewInsets = FakeViewPadding.zero;
        await tester.pumpAndSettle();
        tester.view.viewInsets = const FakeViewPadding(bottom: 340);
        await tester.pumpAndSettle();
        expectVisible(300);
        expect(tester.widget<TextField>(field).controller!.text, '这是修改后的内容');
        await tester.tap(submit);
        await tester.pumpAndSettle();
        expect(
          api.lastBody![replace ? 'replacement' : 'suggestion'],
          '这是修改后的内容',
        );
        expect(api.lastBody!['selected_text'], original);
      },
    );
  }

  testWidgets(
    'Tapping a text region offers comment and replacement for the complete region',
    (tester) async {
      final api = FakeGateway();
      final store = await testStore(authenticated: true, api: api);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: ResumeGuidanceView(
            store: store,
            id: 20,
            initialData: {
              ...shared(),
              'suggestions': [
                {'suggestion': '历史建议'},
              ],
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(SelectableText), findsNothing);
      expect(find.text('评论与修改建议'), findsNothing);
      expect(find.text('查看建议'), findsNothing);
      await tester.tap(find.bySemanticsLabel('选中区域：负责网站开发与性能优化'));
      await tester.pumpAndSettle();
      expect(find.text('查看评论'), findsOneWidget);
      expect(find.text('参与改写'), findsOneWidget);
      final actions = tester.getRect(
        find.byKey(const ValueKey('resume-region-actions')),
      );
      expect(actions.height, lessThanOrEqualTo(60));
      expect(
        tester.getCenter(find.text('查看评论')).dy,
        tester.getCenter(find.text('参与改写')).dy,
      );
      expect(find.byType(PopupMenuItem<bool>), findsNothing);
      expect(find.text('简历指点'), findsOneWidget);
      expect(
        actions.top,
        greaterThan(tester.getRect(find.byType(AppBar)).bottom),
      );
      final selected = tester
          .state<ResumeDocumentViewState>(find.byType(ResumeDocumentView))
          .selectedRegion;
      expect(selected!.text.text!.toPlainText(), '负责网站开发与性能优化');
      await tester.tap(find.text('参与改写'));
      await tester.pumpAndSettle();
      expect(find.text('改写内容仅你和作者可见。'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '负责网站开发与性能优化',
      );
      await tester.enterText(find.byType(TextField), '前端研发');
      await tester.tap(find.text('提交替换建议'));
      await tester.pumpAndSettle();
      expect(api.calls, contains('PostArticlesIdGuidanceAnnotations'));
      expect(api.lastMutationBody, {
        'field_path': 'work_experiences.0.description',
        'field_value': '负责网站开发与性能优化',
        'selected_text': '负责网站开发与性能优化',
        'suggestion': '',
        'replacement': '前端研发',
      });
      final document = tester.state<ResumeDocumentViewState>(
        find.byType(ResumeDocumentView),
      );
      expect(
        document.document!.pages
            .expand((v) => v.ink)
            .map((v) => v.text.text!.toPlainText()),
        contains('负责网站开发与性能优化'),
      );
      expect(tester.takeException(), isNull);
      store.dispose();
    },
  );
  testWidgets(
    'Tapping a region submits a whole-region comment and cancelling clears selection',
    (tester) async {
      final api = FakeGateway();
      final store = await testStore(authenticated: true, api: api);
      addTearDown(store.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: ResumeGuidanceView(store: store, id: 20, initialData: shared()),
        ),
      );
      await tester.pumpAndSettle();
      final region = find.bySemanticsLabel('选中区域：负责网站开发与性能优化');
      await tester.tap(region);
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(5, 100));
      await tester.pumpAndSettle();
      expect(
        tester
            .state<ResumeDocumentViewState>(find.byType(ResumeDocumentView))
            .selectedRegion,
        isNull,
      );
      expect(api.calls, isNot(contains('PostArticlesIdGuidanceAnnotations')));
      await tester.tap(region);
      await tester.pumpAndSettle();
      await tester.tap(find.text('查看评论'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '建议补充成果');
      await tester.pump();
      await tester.tap(find.text('发送'));
      await tester.pumpAndSettle();
      expect(api.calls, contains('PostArticlesIdGuidanceAnnotations'));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Region toolbar fits a narrow screen with enlarged text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = await testStore(authenticated: true, api: FakeGateway());
    addTearDown(store.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(2)),
          child: child!,
        ),
        home: ResumeGuidanceView(store: store, id: 20, initialData: shared()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('选中区域：负责网站开发与性能优化'));
    await tester.pumpAndSettle();
    final rect = tester.getRect(
      find.byKey(const ValueKey('resume-region-actions')),
    );
    expect(rect.left, greaterThanOrEqualTo(0));
    expect(rect.right, lessThanOrEqualTo(308));
    expect(rect.top, greaterThanOrEqualTo(0));
    expect(rect.bottom, lessThanOrEqualTo(688));
    expect(find.byType(Dialog), findsNothing);
    expect(find.text('查看评论'), findsOneWidget);
    expect(find.text('参与改写'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Author sees unmasked resume without selection and can accept or reject pending replacement',
    (tester) async {
      final api = FakeGateway();
      api.documents['GetResumesId'] = {
        'id': 42,
        'revision': 1,
        'content': {
          'personal_info': {'full_name': '作者'},
          'work_experiences': [
            {'company': '公司', 'description': '负责网站开发与性能优化'},
          ],
        },
      };
      api.documents['GetArticlesIdGuidanceAnnotations'] = {
        'items': [
          {
            'id': 7,
            'selected_text': '网站开发',
            'replacement': '前端研发',
            'status': 'PENDING',
            'reviewer_name': '小明',
            'reviewer_id': 2,
            'field_path': 'work_experiences.0.description',
          },
        ],
      };
      api.documents['GetArticlesIdGuidance'] = shared(owner: true);
      final store = await testStore(authenticated: true, api: api);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: ResumeGuidanceView(
            store: store,
            id: 20,
            initialData: shared(owner: true),
            fromNotification: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(SelectableText), findsNothing);
      expect(find.byType(ResumeDocumentView), findsNothing);
      await tester.tap(
        find.byKey(const ValueKey('guidance-participant-user:2')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('resume-review-region-0-0')));
      await tester.pumpAndSettle();
      expect(find.text('采纳'), findsOneWidget);
      expect(find.text('不采纳'), findsOneWidget);
      await tester.tap(find.text('采纳'));
      await tester.pumpAndSettle();
      expect(
        api.calls,
        isNot(
          contains('PostArticlesIdGuidanceAnnotationsAnnotationIdDecision'),
        ),
      );
      expect(find.text('采纳'), findsNothing);
      final edited = tester.widget<ResumeDocumentView>(
        find.byType(ResumeDocumentView),
      );
      expect(
        (edited.resume.source['work_experiences'] as List).first['description'],
        '负责前端研发与性能优化',
      );
      expect(edited.reviewChanges, isEmpty);
      expect(edited.reviewNotes, isEmpty);
      final accepted = edited.reviewHighlights.singleWhere(
        (v) => v.key.startsWith('accepted:'),
      );
      expect(accepted.text, '前端研发');
      expect(accepted.isWavy, isFalse);
      expect(accepted.colorText, isTrue);
      final press = await tester.startGesture(
        tester.getCenter(
          find.byKey(const ValueKey('resume-review-region-0-0')),
        ),
      );
      await tester.pump();
      final state = tester.state<ResumeDocumentViewState>(
        find.byType(ResumeDocumentView),
      );
      String visibleText() => state.displayedDocument!.pages
          .expand((p) => p.ink)
          .where((r) => r.fieldPath == 'work_experiences.0.description')
          .map((r) => r.visibleText)
          .join();
      expect(visibleText(), contains('网站开发'));
      expect(visibleText(), isNot(contains('前端研发')));
      expect(find.byType(BottomSheet), findsNothing);
      await press.up();
      await tester.pump();
      expect(visibleText(), contains('前端研发'));
      expect(visibleText(), isNot(contains('网站开发')));
      api.failing = 'PostArticlesIdGuidanceAnnotationsAnnotationIdDecision';
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(
        (tester
                    .widget<ResumeDocumentView>(find.byType(ResumeDocumentView))
                    .resume
                    .source['work_experiences']
                as List)
            .first['description'],
        '负责前端研发与性能优化',
      );
      expect(find.text('采纳'), findsNothing);
      expect(api.lastMutationBody, {
        'status': 'ACCEPTED',
        'annotation_ids': [7],
      });
      api.failing = null;
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(
        api.calls,
        contains('PostArticlesIdGuidanceAnnotationsAnnotationIdDecision'),
      );

      // Loading after a decision does not erase the full original resume.
      expect(
        tester
            .widget<ResumeDocumentView>(find.byType(ResumeDocumentView))
            .resume
            .name,
        '作者',
      );
      expect(tester.takeException(), isNull);
      store.dispose();
    },
  );
}
