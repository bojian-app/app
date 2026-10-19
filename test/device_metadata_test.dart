import 'package:bojian_mobile/device_metadata.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Device bridge reports hardware and encodes request headers', () async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(DeviceMetadata.channel, (call) async {
      expect(call.method, 'deviceInfo');
      return {'model': 'OPPO PJD110', 'os_version': '15'};
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(DeviceMetadata.channel, null),
    );
    final device = await DeviceMetadata.read();
    expect(device.model, 'OPPO PJD110');
    expect(device.headers, {
      'x-device-model': 'OPPO%20PJD110',
      'x-os-version': '15',
    });
  });
  test('Unsupported device host does not block login', () async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      DeviceMetadata.channel,
      (_) async => throw PlatformException(code: 'UNSUPPORTED'),
    );
    addTearDown(
      () => messenger.setMockMethodCallHandler(DeviceMetadata.channel, null),
    );
    expect((await DeviceMetadata.read()).headers, isEmpty);
  });
  test(
    'Retail device name is preserved and safely encoded in headers',
    () async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        DeviceMetadata.channel,
        (_) async => {'model': '一加 12', 'os_version': '16'},
      );
      addTearDown(
        () => messenger.setMockMethodCallHandler(DeviceMetadata.channel, null),
      );
      final device = await DeviceMetadata.read();
      expect(device.model, '一加 12');
      expect(device.headers['x-device-model'], '%E4%B8%80%E5%8A%A0%2012');
      expect(device.headers['x-os-version'], '16');
    },
  );
}
