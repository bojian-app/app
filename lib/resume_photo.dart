import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_selector/file_selector.dart';

import 'api/bojian_api.dart';
import 'app_store.dart';
import 'resume_importer.dart';
import 'photo_format.dart';

const maximumResumePhotoBytes = 5 * 1024 * 1024;
Future<String> validateResumePhoto(XFile file) =>
    validatePickedPhoto(file, maxBytes: maximumResumePhotoBytes);

Future<String> validatePickedPhoto(
  XFile file, {
  required int maxBytes,
  bool allowGif = false,
}) async {
  final size = await file.length();
  if (size <= 0 || size > maxBytes) {
    throw ApiFailure('照片不能为空，且不能超过 ${maxBytes ~/ (1024 * 1024)} MB');
  }
  final bytes = await file.readAsBytes();
  final mime = photoMimeFromBytes(bytes);
  if (mime == null || (mime == 'image/gif' && !allowGif)) {
    throw ApiFailure(
      allowGif ? '请选择 JPG、PNG、WebP 或 GIF 图片' : '请选择 JPG、PNG 或 WebP 照片',
    );
  }
  await checkPhotoDecodes(bytes);
  return mime;
}

Future<void> checkPhotoDecodes(Uint8List bytes) async {
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
    body: {
      'filename': photoUploadName(file.name, mime),
      'content_type': mime,
      'size_bytes': size,
    },
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
