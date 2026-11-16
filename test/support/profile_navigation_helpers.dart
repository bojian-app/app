import 'dart:async';

import 'package:bojian_mobile/account_pages.dart';
import 'package:flutter_test/flutter_test.dart';

/// Opens the shared account menu directly for its route and lifecycle tests.
/// This helper does not depend on a navigation button in the app UI.
Future<void> openSharedAccountMenu(WidgetTester tester) async {
  final profile = find.byType(ProfilePage);
  final store = tester.widget<ProfilePage>(profile).store;
  unawaited(showAccountMenu(tester.element(profile), store));
  await tester.pumpAndSettle();
}
