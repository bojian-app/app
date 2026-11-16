import 'package:flutter/services.dart';

class DeviceMetadata {
  const DeviceMetadata({
    this.model = '',
    this.osVersion = '',
    this.stableID = '',
  });
  final String model, osVersion;

  /// 重装后不变的设备标识，仅 Android 提供；为空时由应用随机生成设备 ID。
  final String stableID;
  static const channel = MethodChannel('cn.kelance.bojian/settings');

  static Future<DeviceMetadata> read() async {
    try {
      final data = await channel.invokeMapMethod<String, dynamic>('deviceInfo');
      return DeviceMetadata(
        model: '${data?['model'] ?? ''}'.trim(),
        osVersion: '${data?['os_version'] ?? ''}'.trim(),
        stableID: '${data?['stable_id'] ?? ''}'.trim(),
      );
    } on PlatformException {
      return const DeviceMetadata();
    } on MissingPluginException {
      return const DeviceMetadata();
    }
  }

  Map<String, String> get headers => {
    if (model.isNotEmpty) 'x-device-model': Uri.encodeComponent(model),
    if (osVersion.isNotEmpty) 'x-os-version': Uri.encodeComponent(osVersion),
  };
}
