import 'dart:ui' as ui;

import 'package:file_selector/file_selector.dart';

import 'api/bojian_api.dart';
import 'app_store.dart';
import 'resume_importer.dart';

const maximumResumePhotoBytes = 5 * 1024 * 1024;
Future<String> validateResumePhoto(XFile file) async {
  final extension = file.name.split('.').last.toLowerCase();
  final mime = switch (extension) {
    'jpg' || 'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    'webp' => 'image/webp',
    _ => throw const ApiFailure('请选择 JPG、PNG 或 WebP 照片'),
  };
  final size = await file.length();
  if (size <= 0 || size > maximumResumePhotoBytes) {
    throw const ApiFailure('照片不能为空，且不能超过 5 MB');
  }
  final bytes = await file.readAsBytes();
  final valid = switch (mime) {
    'image/jpeg' =>
      bytes.length >= 3 &&
          bytes[0] == 255 &&
          bytes[1] == 216 &&
          bytes[2] == 255,
    'image/png' =>
      bytes.length >= 8 &&
          bytes.take(8).join(',') == '137,80,78,71,13,10,26,10',
    _ =>
      bytes.length >= 12 &&
          String.fromCharCodes(bytes.take(4)) == 'RIFF' &&
          String.fromCharCodes(bytes.skip(8).take(4)) == 'WEBP',
  };
  if (!valid) throw const ApiFailure('照片格式与文件扩展名不一致，请重新选择');
  try {
    final codec = await ui.instantiateImageCodec(bytes, targetWidth: 200);
    try {
      final frame = await codec.getNextFrame();
      frame.image.dispose();
    } finally {
      codec.dispose();
    }
  } catch (_) {
    throw const ApiFailure('无法读取这张照片，请重新选择');
  }
  return mime;
}

Future<ResumeDraft> uploadResumePhoto(
  AppStore store,
  ResumeDraft resume,
  XFile file, {
  ResumeUpload? upload,
}) async {
  if (resume.id <= 0) throw const ApiFailure('请先保存简历');
  final epoch = store.epoch;
  void check() {
    if (!store.alive || store.epoch != epoch || !store.isAuthenticated) {
      throw const ApiFailure('登录状态已变化，请重新登录');
    }
  }

  check();
  final mime = await validateResumePhoto(file);
  final size = await file.length();
  check();
  final path = {'id': '${resume.id}'};
  final auth = await store.request(
    'PostResumesIdPhotoUploads',
    path: path,
    body: {'filename': file.name, 'content_type': mime, 'size_bytes': size},
  );
  check();
  final fileID = integer(auth.data['id']);
  if (fileID <= 0) throw const ApiFailure('未能创建照片上传，请重试');
  await (upload ?? uploadResumeDocument)(auth.data, file, mime);
  check();
  await store.request(
    'PostFilesUploadsIdComplete',
    path: {'id': '$fileID'},
    body: {},
  );
  check();
  final response = await store.request(
    'PostResumesIdPhotoCommit',
    path: path,
    body: {'file_id': fileID, 'crop': <String, dynamic>{}},
  );
  check();
  final saved = decodeResume(response.data);
  if (saved.id != resume.id ||
      saved.photoFileID != fileID ||
      saved.revision <= 0) {
    throw const ApiFailure('照片保存结果无效，请刷新简历后重试');
  }
  await store.load('resumes');
  return saved;
}
