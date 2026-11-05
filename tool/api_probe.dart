import 'dart:convert';
import 'dart:io';

import 'package:bojian_mobile/app_environment.dart';

Future<void> main() async {
  final base = Uri.parse(AppEnvironment.apiBaseURL);
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 12);
  try {
    for (final route in ['/health', '/auth/captchas']) {
      final uri = base.replace(
        path: '${base.path.replaceFirst(RegExp(r'/$'), '')}$route',
        query: route == '/auth/captchas' ? 'type=SLIDE' : null,
      );
      final request = await client.openUrl(
        route == '/health' ? 'GET' : 'POST',
        uri,
      );
      request.followRedirects = false;
      request.headers.set('x-platform', 'ANDROID');
      request.headers.set('x-device-id', 'mobile-connectivity-probe');
      request.headers.set('x-app-version', '1.0.0');
      if (route != '/health') {
        request.headers.contentType = ContentType.json;
        request.write('{}');
      }
      final response = await request.close().timeout(
        const Duration(seconds: 12),
      );
      final body = jsonDecode(await utf8.decoder.bind(response).join()) as Map;
      stdout.writeln(
        '$route: status=${response.statusCode}, hasData=${body.containsKey('data')}, errorCode=${body['error']?['code'] ?? 'none'}',
      );
    }
  } finally {
    client.close(force: true);
  }
}
