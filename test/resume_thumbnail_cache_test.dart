import 'package:bojian_mobile/app_store.dart';
import 'package:bojian_mobile/resume_market_document.dart';
import 'package:bojian_mobile/resume_theme.dart';
import 'package:bojian_mobile/resume_thumbnail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

ResumeDraft resume(String company) => decodeResume({
  'id': 7,
  'content': {
    'personal_info': {'full_name': '缓存测试'},
    'work_experiences': [
      {'company': company, 'description': '中文 English 0123456789'},
    ],
  },
});

Widget host(ResumeDraft draft, {bool shown = true}) => MaterialApp(
  home: Scaffold(
    body: shown
        ? SizedBox(
            width: 100,
            height: 150,
            child: StandardResumeThumbnail(resume: draft),
          )
        : const SizedBox(),
  ),
);

ResumeSheetImage sheetImage(WidgetTester tester) =>
    tester.widget<ResumeSheetImage>(find.byType(ResumeSheetImage));

void main() {
  testWidgets('A rebuilt thumbnail reuses the page already typeset', (
    tester,
  ) async {
    final draft = resume('测试公司');
    await tester.pumpWidget(host(draft));
    final first = sheetImage(tester).document;
    final sheet = sheetImage(tester).sheet;
    expect(sheet, isNotNull);
    // Tabs unmount their pages as the user moves between them.
    await tester.pumpWidget(host(draft, shown: false));
    expect(find.byType(ResumeSheetImage), findsNothing);
    await tester.pumpWidget(host(draft));
    expect(sheetImage(tester).document, same(first));
    expect(sheetImage(tester).sheet, same(sheet));
    // The same content in a new draft object shares it too.
    await tester.pumpWidget(host(resume('测试公司')));
    expect(sheetImage(tester).document, same(first));
    // Changed content is typeset again.
    await tester.pumpWidget(host(resume('另一家公司')));
    expect(sheetImage(tester).document, isNot(same(first)));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Device font changes typeset the covers again', (tester) async {
    final draft = resume('字体公司');
    await tester.pumpWidget(host(draft));
    final first = sheetImage(tester).document;
    await tester.binding.handleSystemMessage({'type': 'fontsChange'});
    await tester.pump();
    await tester.pump();
    expect(sheetImage(tester).document, isNot(same(first)));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('A template resume whose theme is known needs no loading', (
    tester,
  ) async {
    final store = await testStore(authenticated: true);
    addTearDown(store.dispose);
    final draft = decodeResume({
      'id': 9,
      'template_id': 5,
      'content': {
        'personal_info': {'full_name': '主题测试'},
      },
    });
    expect(draft.usesMarketTemplate, isTrue);
    final theme = ResumeTheme.standard;
    MarketThemeCache.put(store, 5, theme);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 100,
            height: 150,
            child: ResumeCardThumbnail(store: store, resume: draft),
          ),
        ),
      ),
    );
    // Typeset like any other cover, with no template to fetch first.
    expect(find.byType(StandardResumeThumbnail), findsOneWidget);
    expect(find.byType(ResumeMarketDocumentView), findsNothing);
    expect(sheetImage(tester).document.theme, same(theme));
    await tester.pumpWidget(const SizedBox());
  });
}
