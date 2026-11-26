import 'dart:async';

import 'package:bojian_mobile/api/bojian_api.dart';
import 'package:bojian_mobile/design.dart';
import 'package:bojian_mobile/resume_guidance_view.dart';
import 'package:bojian_mobile/user_profile_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

class SlowGuidanceGateway extends FakeGateway {
  final release = Completer<void>();
  bool blocking = false;
  @override
  Future<ApiDocument> call(
    String method, {
    Map<String, String> path = const {},
    Map<String, String> query = const {},
    Map<String, dynamic>? body,
    Map<String, String> headers = const {},
  }) async {
    if (blocking) await release.future;
    return super.call(
      method,
      path: path,
      query: query,
      body: body,
      headers: headers,
    );
  }
}

class SlowProfileGateway extends FakeGateway {
  final profile = Completer<void>();
  @override
  Future<ApiDocument> call(
    String method, {
    Map<String, String> path = const {},
    Map<String, String> query = const {},
    Map<String, dynamic>? body,
    Map<String, String> headers = const {},
  }) async {
    if (method == 'GetUsersFirstSecond') {
      await profile.future;
      return ApiDocument({'id': 2, 'nickname': '小林', 'public_id': '100002'});
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

void main() {
  testWidgets('Loaders fit a small screen and never show a spinner', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    for (final loader in const <Widget>[
      DotMatrixLoader(),
      DotMatrixLoader(compact: true),
      ListSkeleton(count: 5),
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: Scaffold(
            body: loader is ListSkeleton
                ? SingleChildScrollView(child: loader)
                : loader,
          ),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('A loading view stays for at least 0.3 s after it appears', (
    tester,
  ) async {
    final loading = ValueNotifier(true);
    addTearDown(loading.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: ValueListenableBuilder<bool>(
          valueListenable: loading,
          builder: (context, value, _) =>
              LoadingGate(loading: value, builder: (_) => const Text('内容')),
        ),
      ),
    );
    expect(find.byKey(const ValueKey('dot-matrix-loader')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 50));
    loading.value = false; // the data arrived after 50 ms
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('内容'), findsNothing);
    expect(find.byKey(const ValueKey('dot-matrix-loader')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('内容'), findsOneWidget);
    expect(find.byKey(const ValueKey('dot-matrix-loader')), findsNothing);
    // Already loaded content is not delayed.
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: LoadingGate(loading: false, builder: (_) => const Text('立即')),
      ),
    );
    expect(find.text('立即'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Skeleton card rows span the full width', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: const Scaffold(body: ListSkeleton(count: 3)),
      ),
    );
    final list = find.byKey(const ValueKey('list-skeleton'));
    expect(tester.getSize(list).width, 320);
    final cards = find.descendant(of: list, matching: find.byType(Container));
    final widths = [
      for (final card in cards.evaluate())
        tester.getSize(find.byWidget(card.widget)).width,
    ].where((width) => width > 200).toList();
    // Rows keep their 24px gutters instead of shrinking to their content.
    expect(widths, [272.0, 272.0, 272.0]);
    // And they do not touch whatever sits above them.
    final first = cards.evaluate().first;
    expect(
      tester.getTopLeft(find.byWidget(first.widget)).dy -
          tester.getTopLeft(list).dy,
      greaterThanOrEqualTo(16),
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'A profile that is still loading shows the dot loader, not a spinner',
    (tester) async {
      final api = SlowProfileGateway();
      final store = await testStore(authenticated: true, api: api);
      addTearDown(store.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: UserProfilePage(store: store, userID: 2),
        ),
      );
      await tester.pump();
      expect(find.byKey(const ValueKey('dot-matrix-loader')), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      // The dots run behind the app bar, so the whole screen is covered.
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('dot-matrix-loader'))).dy,
        0,
      );
      api.profile.complete();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('dot-matrix-loader')), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('A shared resume that is still loading shows the dot loader', (
    tester,
  ) async {
    final api = SlowGuidanceGateway();
    final store = await testStore(authenticated: true, api: api);
    addTearDown(store.dispose);
    api.blocking = true;
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: ResumeGuidanceView(store: store, id: 77),
      ),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('dot-matrix-loader')), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    api.release.complete();
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
  });
}
