import 'package:bojian_mobile/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('WeChat login consent dialog interaction', (tester) async {
    await tester.pumpWidget(const MyApp(nativeStartup: true));
    await tester.pumpAndSettle();
    // Let the native startup layer finish before measuring interaction.
    await Future<void>.delayed(const Duration(seconds: 3));
    await binding.watchPerformance(() async {
      for (var i = 0; i < 5; i++) {
        await tester.tap(find.byKey(const ValueKey('auth-wechat')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('暂不同意'));
        await tester.pumpAndSettle();
      }
    }, reportKey: 'wechat-consent');
    expect(tester.takeException(), isNull);
  });
}
