import 'api/bojian_api.dart';
import 'app_store.dart';

const appQRWebsite = 'https://bojian.kelance.cn';
final _qrSecret = RegExp(r'^[A-Za-z0-9_-]{43}$');

class AppQRLoginCode {
  const AppQRLoginCode(this.sessionID, this.scanToken);
  final String sessionID, scanToken;

  factory AppQRLoginCode.parse(String value) {
    final uri = Uri.tryParse(value);
    if (value.length > 512 ||
        uri == null ||
        uri.scheme != 'https' ||
        uri.host != 'bojian.kelance.cn' ||
        uri.port != 443 ||
        uri.userInfo.isNotEmpty ||
        uri.path != '/app-login' ||
        uri.hasQuery ||
        !uri.hasFragment) {
      throw const ApiFailure('请扫描博简官网的 App 登录二维码');
    }
    Map<String, List<String>> fields;
    try {
      // Reject duplicate parameters rather than accepting an ambiguous token.
      fields = Uri(query: uri.fragment).queryParametersAll;
      if (fields.values.any((values) => values.length != 1)) {
        throw const FormatException();
      }
    } on FormatException {
      throw const ApiFailure('登录二维码格式无效，请在官网刷新');
    }
    final id = fields['session']?.single ?? '';
    final token = fields['token']?.single ?? '';
    if (fields.length != 3 ||
        fields['v']?.single != '1' ||
        !_qrSecret.hasMatch(id) ||
        !_qrSecret.hasMatch(token)) {
      throw const ApiFailure('登录二维码格式无效，请在官网刷新');
    }
    return AppQRLoginCode(id, token);
  }
}

enum AppQRLoginStatus { scanned, confirmed, canceled }

class AppQRLoginSession {
  const AppQRLoginSession({
    required this.id,
    required this.status,
    required this.clientName,
    required this.createdAt,
    required this.expiresAt,
  });
  final String id, clientName;
  final AppQRLoginStatus status;
  final DateTime createdAt, expiresAt;

  factory AppQRLoginSession.fromMap(
    Map<String, dynamic> data,
    String expectedID,
  ) {
    final status = switch (data['status']) {
      'SCANNED' => AppQRLoginStatus.scanned,
      'CONFIRMED' => AppQRLoginStatus.confirmed,
      'CANCELED' => AppQRLoginStatus.canceled,
      _ => throw const ApiFailure('登录二维码状态无效，请重新扫码'),
    };
    final created = DateTime.tryParse('${data['created_at'] ?? ''}');
    final expires = DateTime.tryParse('${data['expires_at'] ?? ''}');
    final client = data['client_name'];
    if (data['session_id'] != expectedID ||
        data['website'] != appQRWebsite ||
        client is! String ||
        client.trim().isEmpty ||
        client.length > 80 ||
        created == null ||
        expires == null ||
        !expires.isAfter(created)) {
      throw const ApiFailure('官网登录信息无效，请重新扫码');
    }
    return AppQRLoginSession(
      id: expectedID,
      status: status,
      clientName: client,
      createdAt: created,
      expiresAt: expires,
    );
  }
}

class AppQRLoginService {
  AppQRLoginService(this.store) : epoch = store.epoch;
  final AppStore store;
  final int epoch;
  bool get isCurrent =>
      store.alive && store.isAuthenticated && store.epoch == epoch;

  Future<AppQRLoginSession> action(AppQRLoginCode code, String action) async {
    if (!isCurrent) throw const ApiFailure('登录状态已变化，请重新登录后扫码');
    final result = await store.request(
      switch (action) {
        'scan' => 'PostMeAppQRSessionsSessionScan',
        'confirm' => 'PostMeAppQRSessionsSessionConfirm',
        'cancel' => 'PostMeAppQRSessionsSessionCancel',
        _ => throw ArgumentError.value(action),
      },
      path: {'session': code.sessionID},
      body: {
        'scan_token': code.scanToken,
        if (action == 'confirm') 'confirmed': true,
      },
      expectedEpoch: epoch,
    );
    return AppQRLoginSession.fromMap(result.data, code.sessionID);
  }
}
