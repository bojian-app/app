import 'package:flutter/services.dart';

class DeviceMetadata {
  const DeviceMetadata({this.model = '', this.osVersion = ''});
  final String model, osVersion;
  static const channel = MethodChannel('cn.kelance.bojian/settings');

  static Future<DeviceMetadata> read() async {
    try {
      final data = await channel.invokeMapMethod<String, dynamic>('deviceInfo');
      return DeviceMetadata(
        model: '${data?['model'] ?? ''}'.trim(),
        osVersion: '${data?['os_version'] ?? ''}'.trim(),
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
