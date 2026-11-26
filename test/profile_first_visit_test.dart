import 'package:bojian_mobile/account_pages.dart';
import 'package:bojian_mobile/app_store.dart';
import 'package:bojian_mobile/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

void main() {
  testWidgets(
    'The first visit waits behind the dot matrix until the covers are ready',
    (tester) async {
      tester.view.physicalSize = const Size(390, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final store = await testStore(
        authenticated: true,
        api: FakeGateway(seeded: true),
      );
      addTearDown(store.dispose);
      store.resumes
        ..clear()
        ..addAll([
          for (var id = 1; id <= 3; id++)
            ResumeDraft(
              id: id,
              title: '简历$id',
              name: '姓名$id',
              position: '岗位$id',
            ),
        ]);
      Widget page() => MaterialApp(
        theme: appTheme,
        home: Scaffold(body: ProfilePage(store: store)),
      );
      await tester.pumpWidget(page());
      await tester.pump();
      // The page is built underneath, covered by the loading view.
      expect(find.byKey(const ValueKey('dot-matrix-loader')), findsOneWidget);
      expect(
        tester.getSize(find.byKey(const ValueKey('dot-matrix-loader'))),
        const Size(390, 780),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('dot-matrix-loader')), findsNothing);
      expect(find.byKey(const ValueKey('profile-tab-resumes')), findsOneWidget);
      // Later visits of the same session show the page at once.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(page());
      await tester.pump();
      expect(find.byKey(const ValueKey('dot-matrix-loader')), findsNothing);
      expect(find.byKey(const ValueKey('profile-tab-resumes')), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
