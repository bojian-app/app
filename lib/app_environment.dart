/// Device builds use the local backend unless production is explicitly selected.
abstract final class AppEnvironment {
  static const name = String.fromEnvironment(
    'BOJIAN_ENV',
    defaultValue: 'local',
  );
  static const isLocal = name == 'local';
  static const defaultTestPhone = isLocal ? '13800138000' : '';
  static bool isTestPhone(String phone) => isLocal && phone == defaultTestPhone;

  static String smsTestCode(String phone, Object? value) =>
      isTestPhone(phone) &&
          value is String &&
          RegExp(r'^\d{6}$').hasMatch(value)
      ? value
      : '';
  static const apiBaseURL = String.fromEnvironment(
    'BOJIAN_API_BASE_URL',
    defaultValue: isLocal
        ? 'http://127.0.0.1:8080/api/v1'
        : 'https://bojian.kelance.cn/api/v1',
  );

  static bool accepts(Uri address) {
    if (name != 'local' && name != 'production') return false;
    if (isLocal) {
      return address.scheme == 'http' && address.host == '127.0.0.1';
    }
    return address.scheme == 'https';
  }

  // Keep the installed production session intact when replacing the test APK.
  static String storageKey(String key) =>
      isLocal ? 'local:$apiBaseURL:$key' : key;
}
