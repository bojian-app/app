import 'dart:io';
import 'dart:ui' as ui;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import 'api/bojian_api.dart';
import 'app_store.dart';
import 'resume_importer.dart';
import 'resume_photo.dart';

const systemAvatarNames = ['小熊', '小猫', '兔子', '狐狸', '熊猫', '考拉', '企鹅', '小狗'];
String profileAvatarSeed(AppStore store) =>
    store.userID > 0 ? '${store.userID}' : store.publicID;
int? storedSystemAvatar(String url) {
  final match = RegExp(r'system-avatar-([0-7])\.png')
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

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.seed,
    this.url = '',
    this.variant,
    this.file,
    this.size = 36,
  });
  final String seed, url;
  final int? variant;
  final XFile? file;
  final double size;
  @override
  Widget build(BuildContext context) {
    final fallback = CustomPaint(
      painter: SystemAvatarPainter(variant ?? assignedAvatar(seed)),
      size: Size.square(size),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * .34),
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
            : Image.network(
                url,
                fit: BoxFit.cover,
                cacheWidth: (size * MediaQuery.devicePixelRatioOf(context))
                    .ceil(),
                errorBuilder: (_, _, _) => fallback,
              ),
      ),
    );
  }
}

class SystemAvatarPainter extends CustomPainter {
  const SystemAvatarPainter(this.variant);
  final int variant;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);
    final i = variant % 8;
    final backgrounds = [
      0xFFF3E7D5,
      0xFFE1EDFF,
      0xFFFFE7EC,
      0xFFFFE9D8,
      0xFFE6F0E6,
      0xFFE8E5FA,
      0xFFDFF1F4,
      0xFFF4EBCF,
    ];
    final coats = [
      0xFFC4966C,
      0xFF8AABDA,
      0xFFFFFAF4,
      0xFFE99C62,
      0xFFFFFCF7,
      0xFFA9A5C7,
      0xFF465E73,
      0xFFD5B077,
    ];
    final coat = Color(coats[i]);
    final dark = const Color(0xFF344052);
    void oval(Rect rect, Color color) =>
        canvas.drawOval(rect, Paint()..color = color);
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 100, 100),
      Paint()..color = Color(backgrounds[i]),
    );
    oval(const Rect.fromLTWH(16, 73, 68, 52), coat);
    if (i == 2) {
      oval(const Rect.fromLTWH(28, 8, 16, 44), coat);
      oval(const Rect.fromLTWH(56, 8, 16, 44), coat);
      oval(const Rect.fromLTWH(32, 14, 8, 28), const Color(0xFFF1B8CA));
      oval(const Rect.fromLTWH(60, 14, 8, 28), const Color(0xFFF1B8CA));
    } else if (i == 1 || i == 3) {
      for (final x in [22.0, 61.0]) {
        canvas.drawPath(
          Path()
            ..moveTo(x, 47)
            ..lineTo(x + 1, 18)
            ..lineTo(x + 23, 38)
            ..close(),
          Paint()..color = coat,
        );
        canvas.drawPath(
          Path()
            ..moveTo(x + 6, 39)
            ..lineTo(x + 6, 26)
            ..lineTo(x + 16, 36)
            ..close(),
          Paint()..color = const Color(0xFFECC3BE),
        );
      }
    } else if (i != 6) {
      for (final x in [19.0, 65.0]) {
        final earColor = i == 4 ? dark : coat;
        oval(
          Rect.fromLTWH(
            x,
            i == 7 ? 33 : 23,
            i == 7 ? 17 : 22,
            i == 7 ? 42 : 24,
          ),
          earColor,
        );
        if (i != 4 && i != 7) {
          oval(Rect.fromLTWH(x + 5, 29, 12, 13), coat.withValues(alpha: .5));
        }
      }
    }
    oval(const Rect.fromLTWH(22, 30, 56, 55), coat);
    if (i == 4) {
      oval(const Rect.fromLTWH(30, 46, 17, 21), dark);
      oval(const Rect.fromLTWH(53, 46, 17, 21), dark);
    }
    if (i == 6) {
      oval(const Rect.fromLTWH(29, 40, 42, 42), const Color(0xFFFFFAF0));
    }
    if (i == 3 || i == 7) {
      oval(const Rect.fromLTWH(31, 59, 38, 23), const Color(0xFFFFF3DD));
    }
    for (final x in [39.0, 61.0]) {
      canvas.drawCircle(
        Offset(x, 55),
        3.2,
        Paint()..color = i == 4 ? Colors.white : dark,
      );
    }
    if (i == 5) {
      oval(const Rect.fromLTWH(44, 56, 12, 16), dark);
    } else if (i == 6) {
      canvas.drawPath(
        Path()
          ..moveTo(44, 65)
          ..lineTo(56, 65)
          ..lineTo(50, 73)
          ..close(),
        Paint()..color = const Color(0xFFE8B45D),
      );
    } else {
      oval(const Rect.fromLTWH(46, 63, 8, 6), dark);
    }
    if (i != 6) {
      canvas.drawArc(
        const Rect.fromLTWH(44, 67, 12, 9),
        .1,
        2.94,
        false,
        Paint()
          ..color = dark
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..strokeCap = StrokeCap.round,
      );
    }
    if (i != 4) {
      oval(
        const Rect.fromLTWH(28, 62, 9, 5),
        const Color(0xFFE8A9A1).withValues(alpha: .65),
      );
      oval(
        const Rect.fromLTWH(63, 62, 9, 5),
        const Color(0xFFE8A9A1).withValues(alpha: .65),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(SystemAvatarPainter oldDelegate) =>
      oldDelegate.variant != variant;
}

Future<XFile> createSystemAvatarFile(int variant) async {
  final recorder = ui.PictureRecorder();
  SystemAvatarPainter(variant).paint(Canvas(recorder), const Size.square(512));
  final picture = recorder.endRecording();
  ui.Image? image;
  try {
    image = await picture.toImage(512, 512);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) throw const ApiFailure('头像生成失败，请重试');
    final directory = await Directory.systemTemp.createTemp(
      'bojian-system-avatar-',
    );
    final file = File('${directory.path}/system-avatar-$variant.png');
    try {
      await file.writeAsBytes(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      );
    } catch (_) {
      await directory.delete(recursive: true);
      rethrow;
    }
    return XFile(file.path);
  } finally {
    image?.dispose();
    picture.dispose();
  }
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
      'filename': file.name,
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
