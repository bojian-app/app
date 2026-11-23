import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_store.dart';

const _channel = MethodChannel('cn.kelance.bojian/settings');

// 和发布接口使用同一套顺序。旧标签只在双方都无法解析时按构建号比较。
final _releaseVersionPattern = RegExp(
  r'^[vV]?(\d+)(?:\.(\d+))?(?:\.(\d+))?'
  r'(?:-([0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?'
  r'(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?$',
);
final _numericIdentifier = RegExp(r'^\d+$');

int _compareReleaseVersions(RegExpMatch left, RegExpMatch right) {
  for (var i = 1; i <= 3; i++) {
    final result = BigInt.parse(left[i] ?? '0')
        .compareTo(BigInt.parse(right[i] ?? '0'));
    if (result != 0) return result;
  }
  final leftPre = left[4]?.split('.');
  final rightPre = right[4]?.split('.');
  if (leftPre == null) return rightPre == null ? 0 : 1;
  if (rightPre == null) return -1;
  for (var i = 0; i < leftPre.length && i < rightPre.length; i++) {
    final a = leftPre[i];
    final b = rightPre[i];
    final aNumeric = _numericIdentifier.hasMatch(a);
    final bNumeric = _numericIdentifier.hasMatch(b);
    if (aNumeric != bNumeric) return aNumeric ? -1 : 1;
    final result = aNumeric
        ? BigInt.parse(a).compareTo(BigInt.parse(b))
        : a.compareTo(b);
    if (result != 0) return result;
  }
  return leftPre.length.compareTo(rightPre.length);
}

/// 服务端发布的一个 App 版本。
class AppRelease {
  const AppRelease({
    required this.versionName,
    required this.buildNumber,
    required this.notes,
    required this.downloadURL,
    required this.sizeBytes,
    required this.sha256,
    required this.releasedAt,
  });

  factory AppRelease.fromJson(Map<String, dynamic> json) => AppRelease(
    versionName: '${json['version_name'] ?? ''}',
    buildNumber: integer(json['build_number']),
    notes: [
      for (final note in json['notes'] is List ? json['notes'] as List : [])
        if ('$note'.trim().isNotEmpty) '$note'.trim(),
    ],
    downloadURL: '${json['download_url'] ?? ''}'.trim(),
    sizeBytes: integer(json['size_bytes']),
    sha256: '${json['sha256'] ?? ''}',
    releasedAt: DateTime.tryParse('${json['released_at'] ?? ''}')?.toLocal(),
  );

  final String versionName, downloadURL, sha256;
  final int buildNumber, sizeBytes;
  final List<String> notes;
  final DateTime? releasedAt;
}

/// 已安装版本、服务端版本记录以及是否需要更新。全应用共用一份，
/// 菜单红点和关于页读取的是同一个结果。
class AppUpdates extends ChangeNotifier {
  AppUpdates._();
  static final instance = AppUpdates._();

  static const _staleAfter = Duration(minutes: 10);

  String installedVersion = '';
  int installedBuild = 0;
  List<AppRelease> releases = const [];
  bool loading = false, loaded = false, failed = false;
  DateTime? _checkedAt;

  AppRelease? get latest => releases.isEmpty ? null : releases.first;

  /// 正数表示远端更新，null 表示版本信息不足以比较。
  int? get latestComparison {
    final release = latest;
    if (release == null) return null;
    final remote = _releaseVersionPattern.firstMatch(
      release.versionName.trim(),
    );
    final local = _releaseVersionPattern.firstMatch(installedVersion.trim());
    if (remote != null && local != null) {
      final result = _compareReleaseVersions(remote, local);
      if (result != 0) return result;
    } else if (remote != null || local != null) {
      return null;
    }
    if (release.buildNumber <= 0 || installedBuild <= 0) return null;
    return release.buildNumber.compareTo(installedBuild);
  }

  /// 红点和安装入口只针对已提供下载的新版。
  bool get hasUpdate =>
      latest?.downloadURL.isNotEmpty == true && (latestComparison ?? 0) > 0;

  String? get installBlockReason {
    final release = latest;
    if (defaultTargetPlatform == TargetPlatform.android &&
        release != null &&
        release.buildNumber > 0 &&
        release.buildNumber < installedBuild &&
        hasUpdate) {
      return '已发现新版本，但发布记录中的 Android 版本码低于本机，暂时无法覆盖安装。请等待新的安装包。';
    }
    return null;
  }

  static String get _platform => Platform.isIOS ? 'IOS' : 'ANDROID';

  Future<void> _readInstalled() async {
    if (installedBuild > 0) return;
    try {
      final info = await _channel.invokeMapMethod<String, dynamic>('appInfo');
      installedVersion = '${info?['version'] ?? ''}';
      installedBuild = integer(info?['build']);
    } on PlatformException {
      /* 读取不到时不判断更新。 */
    } on MissingPluginException {
      /* 非移动端宿主。 */
    }
  }

  /// [force] 为真时忽略缓存，用于用户主动点“检查更新”。
  Future<void> refresh(AppStore store, {bool force = false}) async {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    if (loading) return;
    final checked = _checkedAt;
    if (!force &&
        checked != null &&
        DateTime.now().difference(checked) < _staleAfter) {
      return;
    }
    loading = true;
    notifyListeners();
    try {
      await _readInstalled();
      final result = await store.request(
        'GetAppReleases',
        query: {'platform': _platform},
        authenticated: false,
      );
      final items = result.data['items'];
      releases = [
        if (items is List)
          for (final item in items.whereType<Map>())
            AppRelease.fromJson(Map<String, dynamic>.from(item)),
      ];
      failed = false;
      loaded = true;
      _checkedAt = DateTime.now();
    } catch (_) {
      // 刷新失败保留上次结果，不把网络错误当作“已是最新”。
      failed = true;
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}

enum AppUpdateStage { idle, downloading, installing, failed, needsPermission }

/// 下载并安装新版本。Android 下载到应用缓存后交给系统安装器；
/// 其他平台直接打开下载地址。
class AppUpdateInstaller extends ChangeNotifier {
  AppUpdateStage stage = AppUpdateStage.idle;
  double progress = 0;
  String? message;

  bool get busy => stage == AppUpdateStage.downloading;

  /// 已跳转到“安装未知应用”授权页，等用户回来后继续，不必再点一次。
  bool get waitingForPermission => stage == AppUpdateStage.needsPermission;

  void _set(AppUpdateStage next, {String? text, double? value}) {
    stage = next;
    message = text;
    if (value != null) progress = value;
    notifyListeners();
  }

  /// 下载地址是短时效签名，页面停留较久后会过期，所以每次安装前重新取一次。
  Future<void> install(AppStore store) async {
    if (busy) return;
    final updates = AppUpdates.instance;
    if (updates.installBlockReason != null) return;
    // 先确认安装权限，再下载，避免授权回来后白白重新下载。
    if (Platform.isAndroid) {
      try {
        final granted =
            await _channel.invokeMethod<bool>('installPermission', {
              'request': true,
            }) ??
            false;
        if (!granted) {
          _set(
            AppUpdateStage.needsPermission,
            text: '请在设置中允许博简安装应用，返回后会自动开始更新',
          );
          return;
        }
      } on PlatformException {
        _set(AppUpdateStage.failed, text: '无法打开系统设置，请稍后重试');
        return;
      }
    }
    _set(AppUpdateStage.downloading, value: 0);
    await updates.refresh(store, force: true);
    final release = updates.latest;
    if (!updates.hasUpdate || release == null) {
      _set(AppUpdateStage.failed, text: '暂时无法获取更新包，请稍后重试');
      return;
    }
    if (updates.installBlockReason != null) {
      _set(AppUpdateStage.idle);
      return;
    }
    await _download(release);
  }

  Future<void> _download(AppRelease release) async {
    final uri = Uri.tryParse(release.downloadURL);
    if (uri == null || uri.scheme != 'https') {
      _set(AppUpdateStage.failed, text: '更新地址无效，请稍后重试');
      return;
    }
    if (!Platform.isAndroid) {
      _set(AppUpdateStage.idle);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        _set(AppUpdateStage.failed, text: '无法打开更新地址');
      }
      return;
    }
    final client = http.Client();
    try {
      final directory = Directory(
        '${(await getTemporaryDirectory()).path}/update',
      );
      directory.createSync(recursive: true);
      final file = File('${directory.path}/bojian-${release.buildNumber}.apk');
      // 清理旧版本的安装包，保留本版本已下载完整的包，重试时直接安装。
      for (final entry in directory.listSync()) {
        if (entry.path != file.path) entry.deleteSync(recursive: true);
      }
      if (release.sizeBytes > 0 &&
          file.existsSync() &&
          file.lengthSync() == release.sizeBytes) {
        await _handOver(file, release);
        return;
      }
      final response = await client.send(http.Request('GET', uri));
      if (response.statusCode != 200) {
        throw HttpException('HTTP ${response.statusCode}');
      }
      final total = response.contentLength ?? release.sizeBytes;
      var received = 0;
      final sink = file.openWrite();
      try {
        await for (final chunk in response.stream) {
          sink.add(chunk);
          received += chunk.length;
          if (total > 0) {
            final next = (received / total).clamp(0.0, 1.0);
            if (next - progress >= .01) _set(stage, value: next);
          }
        }
      } finally {
        await sink.close();
      }
      if (release.sizeBytes > 0 && received != release.sizeBytes) {
        file.deleteSync();
        throw const HttpException('安装包不完整');
      }
      await _handOver(file, release);
    } on PlatformException {
      _set(AppUpdateStage.failed, text: '无法调起系统安装器，请稍后重试');
    } catch (_) {
      _set(AppUpdateStage.failed, text: '下载失败，请检查网络后重试');
    } finally {
      client.close();
    }
  }

  Future<void> _handOver(File file, AppRelease release) async {
    _set(AppUpdateStage.installing, value: 1);
    final outcome = await _channel.invokeMethod<String>('installApk', {
      'path': file.path,
      'sha256': release.sha256,
    });
    switch (outcome) {
      case 'permission':
        _set(AppUpdateStage.needsPermission, text: '请在设置中允许博简安装应用，返回后会自动开始更新');
      case 'checksum':
        _set(AppUpdateStage.failed, text: '安装包校验未通过，请重试');
      default:
        _set(AppUpdateStage.idle);
    }
  }
}
