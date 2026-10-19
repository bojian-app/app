import 'package:bojian_mobile/confirmation_dialog.dart';
import 'package:bojian_mobile/design.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _launch(
  WidgetTester tester, {
  required ValueChanged<bool?> onResult,
  bool enabled = true,
  bool barrierDismissible = true,
  String? cancelLabel = '取消',
  String message = '这项操作需要你的确认。',
  double textScale = 1,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: appTheme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              onResult(
                await showAppConfirmation(
                  context,
                  title: '确认操作？',
                  content: Text(message),
                  confirmLabel: '确认操作',
                  cancelLabel: cancelLabel,
                  destructive: true,
                  confirmEnabled: enabled,
                  barrierDismissible: barrierDismissible,
                ),
              );
            },
            child: const Text('打开'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('打开'));
  await tester.pumpAndSettle();
}

void main() {
  for (final action in ['confirm', 'cancel', 'back', 'outside']) {
    testWidgets('Confirmation returns the explicit $action decision', (
      tester,
    ) async {
      final results = <bool?>[];
      await _launch(tester, onResult: results.add);
      expect(results, isEmpty);
      expect(find.byType(CupertinoAlertDialog), findsOneWidget);
      final confirm = find.widgetWithText(CupertinoDialogAction, '确认操作');
      expect(
        tester.widget<CupertinoDialogAction>(confirm).isDestructiveAction,
        isTrue,
      );
      switch (action) {
        case 'confirm':
          await tester.tap(confirm);
        case 'cancel':
          await tester.tap(find.text('取消'));
        case 'back':
          await tester.binding.handlePopRoute();
        case 'outside':
          await tester.tapAt(const Offset(5, 5));
      }
      await tester.pumpAndSettle();
      expect(results, [
        action == 'confirm'
            ? true
            : action == 'cancel'
            ? false
            : null,
      ]);
      expect(find.byType(AppConfirmationDialog), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Disabled confirmation and protected barrier cannot approve', (
    tester,
  ) async {
    final results = <bool?>[];
    await _launch(
      tester,
      onResult: results.add,
      enabled: false,
      barrierDismissible: false,
    );
    await tester.tap(find.text('确认操作'));
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(results, isEmpty);
    expect(find.byType(AppConfirmationDialog), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(results, [false]);
  });

  testWidgets('Single action notice closes after acknowledgement', (
    tester,
  ) async {
    final results = <bool?>[];
    await _launch(tester, onResult: results.add, cancelLabel: null);
    expect(find.byType(CupertinoDialogAction), findsOneWidget);
    await tester.tap(find.text('确认操作'));
    await tester.pumpAndSettle();
    expect(results, [true]);
  });

  for (final size in [const Size(320, 400), const Size(700, 320)]) {
    testWidgets('Long confirmation stays usable at 2x text on $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final results = <bool?>[];
      await _launch(
        tester,
        onResult: results.add,
        textScale: 2,
        message: '请检查本次操作的内容，确认后才会提交。' * 30,
      );
      final confirm = find.widgetWithText(CupertinoDialogAction, '确认操作');
      await tester.ensureVisible(confirm);
      await tester.pumpAndSettle();
      final rect = tester.getRect(confirm);
      expect(rect.top, greaterThanOrEqualTo(0));
      expect(rect.bottom, lessThanOrEqualTo(size.height));
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(size.width));
      expect(tester.takeException(), isNull);
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(results, [true]);
    });
  }
}
