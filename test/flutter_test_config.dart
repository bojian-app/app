import 'dart:async';

import 'package:bojian_mobile/device_metadata.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Native device information has no engine-side implementation in widget tests.
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(DeviceMetadata.channel, (_) async => <String, dynamic>{});
  await testMain();
}
