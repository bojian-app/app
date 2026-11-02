import 'package:bojian_mobile/route_transition_snapshot.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'snapshots stop at transition end and expose live updates after return',
    (tester) async {
      final name = ValueNotifier('原内容');
      addTearDown(name.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: RouteTransitionSnapshot(
            child: Scaffold(
              body: Builder(
                builder: (context) => Column(
                  children: [
                    ValueListenableBuilder(
                      valueListenable: name,
                      builder: (_, value, _) => Text(value),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).push(
                        CupertinoPageRoute<void>(
                          builder: (_) => const RouteTransitionSnapshot(
                            child: Scaffold(body: Text('详情')),
                          ),
                        ),
                      ),
                      child: const Text('打开'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('打开'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      final moving = tester.widgetList<SnapshotWidget>(
        find.byType(SnapshotWidget, skipOffstage: false),
      );
      expect(moving, hasLength(2));
      expect(moving.every((w) => w.controller.allowSnapshotting), isTrue);
      await tester.pumpAndSettle();
      expect(
        tester
            .widgetList<SnapshotWidget>(
              find.byType(SnapshotWidget, skipOffstage: false),
            )
            .every((w) => !w.controller.allowSnapshotting),
        isTrue,
      );
      name.value = '新内容';
      Navigator.of(tester.element(find.text('详情'))).pop();
      await tester.pumpAndSettle();
      expect(find.text('新内容'), findsOneWidget);
      expect(
        tester
            .widget<SnapshotWidget>(find.byType(SnapshotWidget))
            .controller
            .allowSnapshotting,
        isFalse,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
