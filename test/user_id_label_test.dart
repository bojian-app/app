import 'dart:async';

import 'package:bojian_mobile/design.dart';
import 'package:bojian_mobile/user_id_label.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> showID(
  WidgetTester tester,
  String value, {
  bool dark = false,
  double scale = 1,
}) => tester.pumpWidget(
  MaterialApp(
    theme: dark ? appDarkTheme : appTheme,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: UserIDLabel(value: value),
      ),
    ),
  ),
);

void main() {
  final writes = <String>[];
  final calls = <String>[];
  var fail = false;
  Completer<void>? pending;
  setUp(() {
    writes.clear();
    calls.clear();
    fail = false;
    pending = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (!call.method.startsWith('Clipboard.')) return null;
          calls.add(call.method);
          if (pending != null) await pending!.future;
          if (fail) throw PlatformException(code: 'clipboard-unavailable');
          if (call.method == 'Clipboard.setData') {
            writes.add((call.arguments as Map)['text'] as String);
          }
          return null;
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null),
  );

  testWidgets('Only an explicit tap copies the complete ID without its label', (
    tester,
  ) async {
    const id = 'BJSMYMHGDPKOMN';
    await showID(tester, id);
    await tester.pumpAndSettle();
    expect(calls, isEmpty);
    await tester.tap(find.byTooltip('复制用户 ID'));
    await tester.pumpAndSettle();
    expect(calls, ['Clipboard.setData']);
    expect(writes, [id]);
    expect(find.text('用户 ID 已复制'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('A clipboard failure can be retried without a false success', (
    tester,
  ) async {
    await showID(tester, 'BJ-TEST');
    fail = true;
    await tester.tap(find.byTooltip('复制用户 ID'));
    await tester.pumpAndSettle();
    expect(writes, isEmpty);
    expect(find.text('用户 ID 已复制'), findsNothing);
    expect(find.text('复制失败，请重试'), findsOneWidget);
    fail = false;
    await tester.tap(find.byTooltip('复制用户 ID'));
    await tester.pumpAndSettle();
    expect(writes, ['BJ-TEST']);
    expect(find.text('用户 ID 已复制'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Completing a copy after leaving the page does not use its context',
    (tester) async {
      await showID(tester, 'BJ-TEST');
      pending = Completer<void>();
      await tester.tap(find.byTooltip('复制用户 ID'));
      await tester.pumpWidget(const SizedBox());
      pending!.complete();
      await tester.pumpAndSettle();
      expect(writes, ['BJ-TEST']);
      expect(tester.takeException(), isNull);
    },
  );

  for (final dark in [false, true]) {
    testWidgets(
      'A long ID keeps copy visible at 320px with 2x text (dark=$dark)',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final id = List.filled(12, 'LONG-ID-').join();
        await showID(tester, id, dark: dark, scale: 2);
        await tester.pumpAndSettle();
        final button = find.byTooltip('复制用户 ID');
        final text = find.text('用户 ID：$id');
        expect(button.hitTestable(), findsOneWidget);
        expect(
          tester.getTopLeft(button).dx,
          greaterThanOrEqualTo(tester.getTopRight(text).dx),
        );
        expect(tester.getBottomRight(button).dx, lessThanOrEqualTo(300));
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(writes, [id]);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
