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
    'Pulling the feed reveals the refresh animation below the fixed header',
    (tester) async {
      final api = DelayedFeed();
      final store = await testStore(authenticated: true, api: api);
      addTearDown(store.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: Scaffold(body: DiscoveryPage(store: store)),
        ),
      );
      await tester.pumpAndSettle();
      final header = find.byKey(const ValueKey('discovery-search-row'));
      final divider = find.byKey(const ValueKey('discovery-feed-divider'));
      final card = find.byKey(const ValueKey('discovery-story-1'));
      final headerRect = tester.getRect(header);
      final dividerRect = tester.getRect(divider);
      final originalCardTop = tester.getTopLeft(card).dy;
      expect(originalCardTop, closeTo(dividerRect.bottom, .01));

      api.calls.clear();
      api.pending = Completer<void>();
      final pull = await tester.startGesture(tester.getCenter(card));
      for (var i = 0; i < 6; i++) {
        await pull.moveBy(const Offset(0, 60));
        await tester.pump(const Duration(milliseconds: 50));
      }
      await pull.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      final indicator = tester.getRect(find.bySemanticsLabel('正在刷新'));
      expect(tester.getRect(header), headerRect);
      expect(tester.getRect(divider), dividerRect);
      expect(indicator.top, greaterThanOrEqualTo(dividerRect.bottom));
      expect(indicator.bottom, lessThanOrEqualTo(tester.getTopLeft(card).dy));

      api.pending!.complete();
      await tester.pump();
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      expect(api.calls.where((method) => method == 'GetFeed'), hasLength(1));
      expect(tester.getTopLeft(card).dy, closeTo(originalCardTop, .01));
    },
  );

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

  testWidgets(
    'An empty feed loads behind a skeleton, then appears without entering',
    (tester) async {
      final api = DelayedFeed();
      final store = await testStore(authenticated: true, api: api);
      addTearDown(store.dispose);
      store.stories.clear();
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
      await tester.pump();
      expect(find.byKey(const ValueKey('discovery-story-1')), findsNothing);
      api.pending = Completer<void>();
      final loading = store.load('feed');
      await tester.pump();
      expect(
        find.byKey(const ValueKey('discovery-feed-skeleton')),
        findsOneWidget,
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
      api.pending!.complete();
      await tester.runAsync(() => loading);
      await tester.pump();
      final card = find.byKey(const ValueKey('discovery-story-1'));
      expect(card, findsOneWidget);
      final height = tester.getSize(card).height;
      expect(height, greaterThan(0));
      expect(
        find.byKey(const ValueKey('discovery-feed-skeleton')),
        findsNothing,
      );
      await tester.pumpAndSettle();
      expect(tester.getSize(card).height, height);
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
        expect(find.byType(SkeletonPulse), findsNothing);
        expect(tester.element(card), same(element));
        expect(tester.getTopLeft(card), position);
        api.pending!.complete();
        await request;
        await tester.pumpAndSettle();
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.byType(SkeletonPulse), findsNothing);
        expect(tester.element(card), same(element));
        expect(tester.getTopLeft(card), position);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
