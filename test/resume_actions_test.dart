import 'package:bojian_mobile/app_store.dart';
import 'package:bojian_mobile/resume_guidance_share.dart';
import 'package:bojian_mobile/resume_pages.dart';
import 'package:bojian_mobile/resume_polish_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

void main() {
  testWidgets(
    'Card groups optimization actions in a dropdown and keeps deletion on the right',
    (tester) async {
      final store = await testStore(authenticated: true);
      addTearDown(store.dispose);
      store.resumes.add(ResumeDraft(id: 42, title: '测试简历'));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ResumeLibrary(store: store)),
        ),
      );
      await tester.pumpAndSettle();
      final menu = find.byKey(const ValueKey('resume-optimize-42'));
      final delete = find.byKey(const ValueKey('resume-delete-42'));
      await tester.ensureVisible(menu);
      expect(tester.getCenter(menu).dy, tester.getCenter(delete).dy);
      expect(
        tester.getCenter(delete).dx,
        greaterThan(tester.getCenter(menu).dx),
      );
      expect(find.text('AI简历优化'), findsNothing);
      await tester.tap(menu);
      await tester.pumpAndSettle();
      expect(find.text('请求优化'), findsOneWidget);
      expect(find.text('AI简历优化'), findsOneWidget);
      expect(find.byType(ResumePreview), findsNothing);
      await tester.tap(find.byKey(const ValueKey('resume-ai-optimize-42')));
      await tester.pumpAndSettle();
      expect(find.byType(ResumePolishPage), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('请求优化'), findsNothing);
      await tester.tap(menu);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('resume-guidance-42')));
      await tester.pumpAndSettle();
      expect(find.byType(ResumeGuidanceShare), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
