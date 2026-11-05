import 'package:bojian_mobile/api/bojian_api.dart';
import 'package:bojian_mobile/app_environment.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('test phone and SMS autofill are unavailable in production', () {
    expect(
      AppEnvironment.defaultTestPhone,
      AppEnvironment.isLocal ? '13800138000' : '',
    );
    expect(
      AppEnvironment.smsTestCode('13800138000', '654321'),
      AppEnvironment.isLocal ? '654321' : '',
    );
    expect(AppEnvironment.smsTestCode('13900139000', '654321'), isEmpty);
    expect(AppEnvironment.smsTestCode('13800138000', 'invalid'), isEmpty);
  });

  test('build environment fixes the API destination', () async {
    final api = BojianApi(
      client: MockClient((_) async => http.Response('{}', 200)),
    );
    expect(
      api.baseURL.toString(),
      AppEnvironment.isLocal
          ? 'http://127.0.0.1:8080/api/v1'
          : 'https://bojian.kelance.cn/api/v1',
    );
    await api.close();
  });

  test('local builds reject remote APIs; production rejects cleartext', () {
    final addresses = AppEnvironment.isLocal
        ? ['https://bojian.kelance.cn/api/v1', 'http://192.168.1.2:8080/api/v1']
        : ['http://127.0.0.1:8080/api/v1', 'http://bojian.kelance.cn/api/v1'];
    for (final address in addresses) {
      expect(
        () => BojianApi(baseURL: Uri.parse(address)),
        throwsA(isA<ApiFailure>()),
      );
    }
  });

  test(
    'credentials and drafts remain isolated from production storage',
    () async {
      FlutterSecureStorage.setMockInitialValues({
        'bojian.session': 'production-session',
      });
      final storage = SecureSessionStorage();
      expect(
        await storage.read('bojian.session'),
        AppEnvironment.isLocal ? null : 'production-session',
      );
      await storage.write('bojian.session', 'current-session');
      expect(await storage.read('bojian.session'), 'current-session');
      await storage.write('bojian.session', null);
      expect(await storage.read('bojian.session'), null);
      if (AppEnvironment.isLocal) {
        expect(
          await const FlutterSecureStorage().read(key: 'bojian.session'),
          'production-session',
        );
      }
    },
  );
}
