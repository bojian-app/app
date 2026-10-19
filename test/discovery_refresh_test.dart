import 'dart:async';

import 'package:bojian_mobile/api/bojian_api.dart';
import 'package:bojian_mobile/discovery.dart';
import 'package:bojian_mobile/design.dart';
import 'package:bojian_mobile/playful_refresh.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

class DelayedFeed extends FakeGateway {
  DelayedFeed() : super(seeded: true);
  Completer<void>? pending;

  @override
  Future<ApiDocument> call(
    String method, {
    Map<String, String> path = const {},
    Map<String, String> query = const {},
    Map<String, dynamic>? body,
    Map<String, String> headers = const {},
  }) async {
    if (method == 'GetFeed' && pending != null) await pending!.future;
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
  testWidgets(
    'Discovery refresh no longer depends on resume loading or its errors',
    (tester) async {
      final api = DelayedFeed();
      final store = await testStore(authenticated: true, api: api);
      addTearDown(store.dispose);
      store.errors['resumes'] = '服务器暂不可用';
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: Scaffold(body: DiscoveryPage(store: store)),
        ),
      );
      await tester.pumpAndSettle();
      final refresh = tester.widget<PlayfulRefresh>(
        find.byType(PlayfulRefresh).first,
      );
      expect(refresh.hasError!(), isFalse);
      api.calls.clear();
      await refresh.onRefresh();
      await tester.pumpAndSettle();
      expect(api.calls, contains('GetFeed'));
      expect(api.calls, isNot(contains('GetResumes')));
      expect(refresh.hasError!(), isFalse);
      api.failing = 'GetFeed';
      await refresh.onRefresh();
      await tester.pumpAndSettle();
      expect(refresh.hasError!(), isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Only new records enter; existing cards keep their elements and move gradually',
    (tester) async {
      final api = DelayedFeed();
      final store = await testStore(authenticated: true, api: api);
      addTearDown(store.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: Scaffold(
            body: AnimatedBuilder(
              animation: store,
              builder: (_, _) => DiscoveryPage(store: store),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final oldCard = find.byKey(
        const ValueKey('discovery-story-1'),
        skipOffstage: false,
      );
      final element = tester.element(oldCard);
      final originalY = tester.getTopLeft(oldCard).dy;
      final rows = api.documents['GetFeed']!['items'] as List;
      api.documents['GetFeed'] = {
        'items': [
          {...rows.first as Map<String, dynamic>, 'id': 2, 'title': '新增文章'},
          ...rows,
        ],
      };
      await store.load('feed');
      expect(store.stories.map((s) => s.id), contains(2));
      await tester.pump();
      final newCard = find.byKey(
        const ValueKey('discovery-story-2'),
        skipOffstage: false,
      );
      expect(tester.getSize(newCard).height, 0);
      expect(tester.element(oldCard), same(element));
      await tester.pump(const Duration(milliseconds: 100));
      final middleHeight = tester.getSize(newCard).height;
      final middleY = tester.getTopLeft(oldCard).dy;
      expect(middleHeight, greaterThan(0));
      expect(middleY, greaterThan(originalY));
      await tester.pumpAndSettle();
      expect(tester.getSize(newCard).height, greaterThan(middleHeight));
      expect(tester.getTopLeft(oldCard).dy, greaterThan(middleY));
      expect(tester.element(oldCard), same(element));
      expect(find.byType(CircularProgressIndicator), findsNothing);
    },
  );

  for (final fails in [false, true]) {
    testWidgets(
      'Cached feed stays visible and stable during ${fails ? 'failed' : 'successful'} refresh',
      (tester) async {
        final api = DelayedFeed();
        final store = await testStore(authenticated: true, api: api);
        addTearDown(store.dispose);
        await tester.pumpWidget(
          MaterialApp(
            theme: appTheme,
            home: Scaffold(
              body: AnimatedBuilder(
                animation: store,
                builder: (_, _) => DiscoveryPage(store: store),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final card = find.byKey(const ValueKey('discovery-story-1'));
        final element = tester.element(card);
        final position = tester.getTopLeft(card);
        api.pending = Completer<void>();
        if (fails) api.failing = 'GetFeed';
        final request = store.load('feed');
        await tester.pump();
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(tester.element(card), same(element));
        expect(tester.getTopLeft(card), position);
        api.pending!.complete();
        await request;
        await tester.pumpAndSettle();
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(tester.element(card), same(element));
        expect(tester.getTopLeft(card), position);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
