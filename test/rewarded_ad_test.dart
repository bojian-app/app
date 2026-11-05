import 'package:bojian_mobile/rewarded_ad.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final eligible in [false, true]) {
    test('Ad claims require native eligibility: $eligible', () async {
      final api = FakeGateway();
      api.documents['PostWalletAdSessions'] = {
        'id': 'session',
        'app_id': 'app',
        'slot_id': 'slot',
        'user_id': '1',
        'extra': 'session',
      };
      api.documents['PostWalletAdSessionsIdClaims'] = {'id': 1, 'points': 20};
      final store = await testStore(authenticated: true, api: api);
      addTearDown(store.dispose);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            RewardedAd.channel,
            (MethodCall call) async => {'eligible': eligible},
          );
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(RewardedAd.channel, null),
      );
      expect(await RewardedAd.watch(store), eligible ? 20 : 0);
      expect(api.calls.contains('PostWalletAdSessionsIdClaims'), eligible);
    });
  }
}
