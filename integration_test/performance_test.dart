import 'package:bojian_mobile/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Login input focus and dismissal', (tester) async {
    await tester.pumpWidget(const MyApp(nativeStartup: true));
    await tester.pumpAndSettle();
    // Let the native startup layer finish before measuring interaction.
    await Future<void>.delayed(const Duration(seconds: 3));
    await binding.watchPerformance(() async {
      for (var i = 0; i < 5; i++) {
        final phone = find.byKey(const ValueKey('auth-phone'));
        await tester.tap(phone);
        await tester.pumpAndSettle();
        await tester.tap(find.text('欢迎回到博简'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('auth-code')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('欢迎回到博简'));
        await tester.pumpAndSettle();
      }
    }, reportKey: 'input');
    expect(tester.takeException(), isNull);
  });
}
