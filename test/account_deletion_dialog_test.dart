import 'package:bojian_mobile/account_deletion_dialog.dart';
import 'package:bojian_mobile/design.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'Deletion dialog scrolls with keyboard in landscape and requires exact confirmation',
    (tester) async {
      tester.view.physicalSize = const Size(850, 420);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      bool? result;
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  result = await showAccountDeletionDialog(context);
                },
                child: const Text('打开'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoAlertDialog), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);
      await tester.ensureVisible(find.byType(CupertinoTextField));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(CupertinoTextField), '注销');
      tester.view.viewInsets = const FakeViewPadding(bottom: 180);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<CupertinoDialogAction>(
              find.widgetWithText(CupertinoDialogAction, '申请注销'),
            )
            .onPressed,
        isNull,
      );
      await tester.enterText(find.byType(CupertinoTextField), '我已确认并主动注销此账号');
      await tester.pumpAndSettle();
      final confirm = find.widgetWithText(CupertinoDialogAction, '申请注销');
      await tester.ensureVisible(confirm);
      await tester.pumpAndSettle();
      expect(tester.getRect(confirm).bottom, lessThanOrEqualTo(240));
      expect(
        tester.widget<CupertinoDialogAction>(confirm).isDestructiveAction,
        isTrue,
      );
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(result, true);
      expect(tester.takeException(), isNull);
    },
  );
}
