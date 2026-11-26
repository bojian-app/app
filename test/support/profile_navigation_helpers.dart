import 'dart:async';

import 'package:bojian_mobile/account_pages.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Opens the shared account menu directly for its route and lifecycle tests.
/// This helper does not depend on a navigation button in the app UI.
Future<void> openSharedAccountMenu(WidgetTester tester) async {
  final profile = find.byType(ProfilePage);
  final store = tester.widget<ProfilePage>(profile).store;
  unawaited(showAccountMenu(tester.element(profile), store));
  await tester.pumpAndSettle();
}

ScrollPosition discoveryFeedPosition(WidgetTester tester) {
  final scrollable = find.descendant(
    of: find.byKey(const PageStorageKey('discovery-feed-推荐')),
    matching: find.byType(Scrollable),
  ).first;
  return tester.state<ScrollableState>(scrollable).position;
}

Future<void> tapDiscoveryMenuItem(WidgetTester tester, String itemKey) async {
  await tester.tap(find.byKey(const ValueKey('discovery-profile')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ValueKey(itemKey)));
}

Future<void> openMyPage(WidgetTester tester) async {
  await tapDiscoveryMenuItem(tester, 'discovery-my-page');
  await tester.pumpAndSettle();
}
