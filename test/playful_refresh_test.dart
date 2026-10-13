import 'dart:async';

import 'package:bojian_mobile/playful_refresh.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pull(WidgetTester tester, {bool reverse = false}) async {
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(ListView)),
    );
    for (var i = 0; i < 6; i++) {
      await gesture.moveBy(Offset(0, reverse ? -60 : 60));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
  }

  Future<void> mount(
    WidgetTester tester,
    Future<void> Function() refresh, {
    bool reverse = false,
    bool reduced = false,
    bool Function()? hasError,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduced),
          child: Scaffold(
            body: PlayfulRefresh(
              onRefresh: refresh,
              hasError: hasError,
              child: ListView(
                reverse: reverse,
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [SizedBox(height: 40, child: Text('内容'))],
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('short lists refresh once and finish with confirmation', (
    tester,
  ) async {
    final pending = Completer<void>();
    var calls = 0;
    await mount(tester, () {
      calls++;
      return pending.future;
    });
    final contentPosition = tester.getTopLeft(find.text('内容'));
    await pull(tester);
    await tester.pump(const Duration(milliseconds: 200));
    expect(
      tester.getTopLeft(find.text('内容')).dy,
      greaterThan(contentPosition.dy),
    );
    expect(calls, 1);
    expect(find.bySemanticsLabel('正在刷新'), findsOneWidget);
    expect(find.byType(RefreshProgressIndicator), findsNothing);
    pending.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.bySemanticsLabel('已更新'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 320));
    var previousY = tester.getTopLeft(find.text('内容')).dy;
    final deltas = <double>[];
    for (var frame = 0; frame < 25; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      final y = tester.getTopLeft(find.text('内容')).dy;
      expect(y, lessThanOrEqualTo(previousY + .01));
      final delta = previousY - y;
      if (delta > .01) deltas.add(delta);
      previousY = y;
    }
    expect(deltas, isNotEmpty);
    final maximum = deltas.reduce((a, b) => a > b ? a : b);
    expect(deltas.last, lessThan(maximum / 2));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(find.bySemanticsLabel('已更新'), findsNothing);
    expect(find.text('内容'), findsOneWidget);
    expect(tester.getTopLeft(find.text('内容')), contentPosition);
  });

  testWidgets(
    'stored request errors are not reported as success and can retry',
    (tester) async {
      var failed = true;
      await mount(tester, () async {}, hasError: () => failed);
      await pull(tester);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.bySemanticsLabel('刷新失败'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      failed = false;
      await pull(tester);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.bySemanticsLabel('已更新'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
    },
  );

  testWidgets('small pull cancels without making a request', (tester) async {
    var calls = 0;
    await mount(tester, () async {
      calls++;
    });
    await tester.drag(find.byType(ListView), const Offset(0, 35));
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(find.bySemanticsLabel('下拉刷新'), findsNothing);
  });

  testWidgets('reverse chat and reduced motion preserve refresh behavior', (
    tester,
  ) async {
    var calls = 0;
    await mount(
      tester,
      () async {
        calls++;
      },
      reverse: true,
      reduced: true,
    );
    await pull(tester);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(calls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed refresh remains usable; disposal cancels timers', (
    tester,
  ) async {
    await mount(tester, () async {
      throw StateError('offline');
    });
    await pull(tester);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    expect(find.bySemanticsLabel('刷新失败'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
  });
}
