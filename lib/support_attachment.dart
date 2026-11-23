import 'package:file_selector/file_selector.dart' show XFile;

import 'api/bojian_api.dart';
import 'app_store.dart';
import 'resume_importer.dart' show ResumeUpload, uploadResumeDocument;

/// 客服工单和反馈表单共用的私有附件引用。
String supportContentWithPhotos(String content, Iterable<String> ids) =>
    ids.isEmpty ? content : '$content\n反馈附图：${ids.join(",")}';

Future<int> uploadSupportPhoto(
  AppStore store,
  XFile photo,
  String mime, {
  required int epoch,
  required void Function() checkSession,
  ResumeUpload transfer = uploadResumeDocument,
}) async {
  final size = await photo.length();
  checkSession();
  final response = await store.request(
    'PostFilesUploads',
    expectedEpoch: epoch,
    body: {
      'purpose': 'CHAT_ATTACHMENT',
      'filename': 'feedback-image.${mime.split('/').last}',
      'content_type': mime,
      'size_bytes': size,
    },
  );
  final id = integer(response.data['id']);
  if (id <= 0) throw const ApiFailure('无法上传反馈图片，请重试');
  checkSession();
  await transfer(response.data, photo, mime);
  checkSession();
  await store.request(
    'PostFilesUploadsIdComplete',
    expectedEpoch: epoch,
    path: {'id': '$id'},
    body: {},
  );
  return id;
}
