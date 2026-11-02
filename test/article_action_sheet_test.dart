import 'package:bojian_mobile/article_owner_actions.dart';
import 'package:bojian_mobile/content_report.dart';
import 'package:bojian_mobile/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

void main() {
  testWidgets('Owner menu cancellation never unpublishes content', (
    tester,
  ) async {
    final api = FakeGateway();
    final store = await testStore(authenticated: true, api: api);
    addTearDown(store.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: Scaffold(
          appBar: AppBar(
            actions: [ArticleOwnerActions(store: store, articleID: 1)],
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('article-owner-actions-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('article-owner-menu-cancel')));
    await tester.pumpAndSettle();
    expect(api.calls, isNot(contains('PostArticlesIdUnpublish')));
    expect(
      find.byKey(const ValueKey('article-action-unpublish')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Report menu opens form only after selection; cancel submits nothing',
    (tester) async {
      final api = FakeGateway();
      final store = await testStore(authenticated: true, api: api);
      addTearDown(store.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: Scaffold(
            appBar: AppBar(
              actions: [ReportArticleButton(store: store, articleID: 1)],
            ),
          ),
        ),
      );
      await tester.tap(find.byTooltip('更多操作'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('article-report-menu-cancel')),
      );
      await tester.pumpAndSettle();
      expect(find.text('举报内容'), findsNothing);
      expect(api.calls, isNot(contains('PostReports')));
      await tester.tap(find.byTooltip('更多操作'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('article-action-report')));
      await tester.pumpAndSettle();
      expect(find.text('举报内容'), findsOneWidget);
      expect(api.calls, isNot(contains('PostReports')));
      expect(tester.takeException(), isNull);
    },
  );
}
