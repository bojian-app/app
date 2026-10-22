import 'dart:async';
import 'dart:convert';

import 'package:bojian_mobile/app_shell.dart';
import 'package:bojian_mobile/app_store.dart';
import 'package:bojian_mobile/auth_page.dart';
import 'package:bojian_mobile/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

class DelayedSessionStorage extends MemoryStorage {
  final sessionRead = Completer<String?>();

  @override
  Future<String?> read(String key) =>
      key == 'bojian.session' ? sessionRead.future : super.read(key);
}

void main() {
  testWidgets('Restored cold start never mounts the login page', (
    tester,
  ) async {
    final storage = DelayedSessionStorage();
    final store = AppStore(api: FakeGateway(), storage: storage);
    await tester.pumpWidget(MyApp(store: store, startupAdsEnabled: false));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const ValueKey('startup-session-gate')), findsOneWidget);
    expect(find.byType(AuthPage, skipOffstage: false), findsNothing);
    expect(find.byType(AppShell), findsNothing);

    storage.sessionRead.complete(
      jsonEncode({
        'access_token': 'restored-access',
        'refresh_token': 'restored-refresh',
        'user_id': 1,
      }),
    );
    // Inspect intermediate frames too: a final-home assertion misses the flash.
    for (var frame = 0; frame < 30; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.byType(AuthPage, skipOffstage: false), findsNothing);
    }
    await tester.pumpAndSettle();
    expect(find.byType(AppShell), findsOneWidget);
    expect(find.byKey(const ValueKey('startup-session-gate')), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final saved in <String?>[null, '{invalid']) {
    testWidgets(
      'Missing or invalid session shows login only after restore ($saved)',
      (tester) async {
        final storage = DelayedSessionStorage();
        final store = AppStore(api: FakeGateway(), storage: storage);
        await tester.pumpWidget(MyApp(store: store, startupAdsEnabled: false));
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.byType(AuthPage, skipOffstage: false), findsNothing);
        storage.sessionRead.complete(saved);
        await tester.pumpAndSettle();
        expect(find.byType(AuthPage), findsOneWidget);
        expect(find.byType(AppShell), findsNothing);
        expect(
          find.byKey(const ValueKey('startup-session-gate')),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
