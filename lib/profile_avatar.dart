import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'api/bojian_api.dart';
import 'app_store.dart';
import 'network_image_cache.dart';
import 'resume_importer.dart';
import 'resume_photo.dart';
import 'photo_format.dart';

const systemAvatarNames = [
  '听歌',
  '冰淇淋',
  '元气',
  '摄影',
  '篮球',
  '墨镜',
  '比耶',
  '阅读',
  '咖啡',
  '灵感',
];
String systemAvatarAsset(int variant) =>
    'assets/avatars/avatar_${variant + 1}.webp';
String profileAvatarSeed(AppStore store) =>
    store.userID > 0 ? '${store.userID}' : store.publicID;
// Uploads named system-avatar-N.png or system-avatar-v2-N.webp hold retired
// sets. They keep showing their stored image and must not mark a current choice
// as selected.
int? storedSystemAvatar(String url) {
  final match = RegExp(r'system-avatar-v3-([0-9])\.webp')
      .firstMatch(Uri.tryParse(url)?.path ?? '');
  return match == null ? null : int.parse(match.group(1)!);
}

int assignedAvatar(String accountID) {
  var hash = 0;
  for (final value in accountID.runes) {
    hash = (hash * 31 + value) & 0x7fffffff;
  }
  return hash % systemAvatarNames.length;
}

// One decode size for every avatar placement, so all pages share one entry.
ImageProvider profileAvatarImage(String url) =>
    ResizeImage(CachedNetworkImage(url), width: 256, height: 256);

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.seed,
    this.url = '',
    this.variant,
    this.file,
    this.size = 36,
    this.borderRadius,
    this.onTap,
    this.semanticsLabel = '查看用户主页',
  });
  final String seed, url;
  final int? variant;
  final XFile? file;
  final double size;

  /// Avatars are fully round unless a caller asks for another radius (the
  /// full-screen avatar editor previews the whole square photo with 0).
  final double? borderRadius;
  final VoidCallback? onTap;
  final String semanticsLabel;
  @override
  Widget build(BuildContext context) {
    final fallback = Image.asset(
      systemAvatarAsset(variant ?? assignedAvatar(seed)),
      fit: BoxFit.cover,
      gaplessPlayback: true,
    );
    final avatar = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius ?? size / 2),
      child: SizedBox.square(
        dimension: size,
        child: file != null
            ? Image.file(
                File(file!.path),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => fallback,
              )
            : variant != null || url.isEmpty
            ? fallback
            : Image(
                image: profileAvatarImage(url),
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (_, _, _) => fallback,
              ),
      ),
    );
    if (onTap == null) return avatar;
    return Semantics(
      button: true,
      label: semanticsLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: avatar,
      ),
    );
  }
}

Future<XFile> createSystemAvatarFile(int variant) async {
  final bytes = await rootBundle.load(systemAvatarAsset(variant));
  final directory = await Directory.systemTemp.createTemp(
    'bojian-system-avatar-',
  );
  final file = File('${directory.path}/system-avatar-v3-$variant.webp');
  try {
    await file.writeAsBytes(
      bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
    );
  } catch (_) {
    await directory.delete(recursive: true);
    rethrow;
  }
  return XFile(file.path);
}

Future<void> discardSystemAvatarFile(XFile file) async {
  final directory = File(file.path).parent;
  if (!directory.path
      .split(Platform.pathSeparator)
      .last
      .startsWith('bojian-system-avatar-')) {
    return;
  }
  if (await directory.exists()) await directory.delete(recursive: true);
}

Future<void> uploadProfileAvatar(
  AppStore store,
  XFile file, {
  ResumeUpload? upload,
}) async {
  final epoch = store.epoch;
  void check() {
    if (!store.alive || epoch != store.epoch || !store.isAuthenticated) {
      throw const ApiFailure('登录状态已变化，请重新登录');
    }
  }

  check();
  final mime = await validateResumePhoto(file);
  check();
  final response = await store.request(
    'PostMeAvatarUploads',
    body: {
      'filename': photoUploadName(file.name, mime),
      'content_type': mime,
      'size_bytes': await file.length(),
    },
  );
  check();
  final id = integer(response.data['id']);
  if (id <= 0) throw const ApiFailure('无法创建头像上传，请重试');
  await (upload ?? uploadResumeDocument)(response.data, file, mime);
  check();
  await store.request(
    'PostFilesUploadsIdComplete',
    path: {'id': '$id'},
    body: {},
  );
  check();
  final saved = await store.request(
    'PostMeAvatarCommit',
    body: {'file_id': id, 'crop': <String, dynamic>{}},
  );
  check();
  final url = saved.data['avatar_url']?.toString() ?? '';
  final uri = Uri.tryParse(url);
  if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
    throw const ApiFailure('头像保存结果无效，请刷新个人资料');
  }
  store.avatarURL = url;
  store.changed();
}
