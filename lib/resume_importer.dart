import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import 'api/bojian_api.dart';
import 'app_store.dart';

const maximumResumeFileBytes = 20 * 1024 * 1024;

enum ResumeImportPhase { reading, uploading, parsing, ready }

const resumeMimeTypes = {
  'pdf': 'application/pdf',
  'doc': 'application/msword',
  'docx':
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
};

typedef ResumeUpload = Future<void> Function(
  Map<String, dynamic> authorization,
  XFile file,
  String mimeType,
);

class ImportCancelled implements Exception {
  const ImportCancelled();
}

Future<void> uploadResumeDocument(
  Map<String, dynamic> authorization,
  XFile file,
  String mimeType, {
  http.Client? client,
}) async {
  final uri = Uri.tryParse(authorization['upload_url'] as String? ?? '');
  final fields = authorization['fields'];
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      authorization['method'] != 'POST' ||
      fields is! Map ||
      fields['token'] is! String ||
      fields['key'] is! String ||
      (fields['token'] as String).isEmpty ||
      (fields['key'] as String).isEmpty) {
    throw const ApiFailure('文件上传地址无效，请稍后重试');
  }
  final transport = client ?? http.Client();
  try {
    final request = http.MultipartRequest('POST', uri)..followRedirects = false;
    for (final entry in fields.entries) {
      if (entry.key is! String || entry.value is! String) {
        throw const ApiFailure('文件上传参数无效');
      }
      request.fields[entry.key as String] = entry.value as String;
    }
    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        file.path,
        filename: file.name,
        contentType: MediaType.parse(mimeType),
      ),
    );
    final response = await transport
        .send(request)
        .timeout(const Duration(seconds: 90));
    await response.stream.drain<void>().timeout(const Duration(seconds: 20));
    if (response.statusCode == 419 &&
        (uri.host == 'qiniup.com' || uri.host.endsWith('.qiniup.com'))) {
      throw const ApiFailure('文件存储服务暂不可用，请联系管理员恢复服务（419）');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiFailure('文件上传失败（HTTP ${response.statusCode}），请重试');
    }
  } on TimeoutException {
    throw const ApiFailure('文件上传超时，请检查网络后重试');
  } on http.ClientException {
    throw const ApiFailure('文件上传连接失败，请检查网络后重试');
  } finally {
    if (client == null) transport.close();
  }
}

class ResumeImporter {
  ResumeImporter({
    required this.store,
    ResumeUpload? upload,
    Future<void> Function(Duration)? delay,
  }) : upload = upload ?? uploadResumeDocument,
       delay = delay ?? Future<void>.delayed;
  final AppStore store;
  final ResumeUpload upload;
  final Future<void> Function(Duration) delay;

  Future<ResumeDraft> importFile(
    XFile file, {
    required void Function(String) onProgress,
    required bool Function() isCancelled,
    void Function(ResumeImportPhase)? onPhase,
  }) async {
    final epoch = store.epoch;
    var taskID = 0;
    void check() {
      if (isCancelled()) throw const ImportCancelled();
      if (!store.alive || store.epoch != epoch || !store.isAuthenticated) {
        throw const ApiFailure('登录状态已变化，请重新选择文件');
      }
    }

    try {
      check();
      onPhase?.call(ResumeImportPhase.reading);
      final dot = file.name.lastIndexOf('.');
      final extension = dot > 0
          ? file.name.substring(dot + 1).toLowerCase()
          : '';
      final mime = resumeMimeTypes[extension];
      if (mime == null) throw const ApiFailure('请选择 PDF、DOC 或 DOCX 简历文件');
      final size = await file.length();
      check();
      if (size <= 0) throw const ApiFailure('文件为空，请重新选择');
      if (size > maximumResumeFileBytes) throw const ApiFailure('文件不能超过 20 MB');
      final name = String.fromCharCodes(
        file.name.substring(0, dot).runes.take(160),
      );
      onProgress('正在准备上传…');
      onPhase?.call(ResumeImportPhase.uploading);
      final auth = await store.request(
        'PostFilesUploads',
        body: {
          'purpose': 'RESUME_IMPORT',
          'filename': file.name,
          'content_type': mime,
          'size_bytes': size,
        },
      );
      check();
      final fileID = integer(auth.data['id']);
      if (fileID <= 0) throw const ApiFailure('未能创建文件上传，请重试');
      onProgress('正在上传文件…');
      await upload(auth.data, file, mime);
      check();
      await store.request(
        'PostFilesUploadsIdComplete',
        path: {'id': '$fileID'},
        body: {},
      );
      check();
      onPhase?.call(ResumeImportPhase.parsing);
      onProgress('正在提交 AI 解析…');
      final task = await store.request(
        'PostResumeImports',
        body: {'file_id': fileID, 'name': name.isEmpty ? '导入的简历' : name},
      );
      taskID = integer(task.data['id']);
      check();
      if (taskID <= 0) throw const ApiFailure('未能创建简历解析任务，请重试');
      onProgress('正在解析简历，请稍候…');
      for (var i = 0; i < 200; i++) {
        if (i > 0) await store.waitForJobUpdate('RESUME_IMPORT', taskID, delay);
        check();
        final task = await store.request(
          'GetResumeImportsId',
          path: {'id': '$taskID'},
        );
        check();
        final data = task.data;
        final status = data['status'];
        if (status == 'SUCCEEDED' && integer(data['resume_id']) > 0) {
          final saved = await store.request(
            'GetResumesId',
            path: {'id': '${data['resume_id']}'},
          );
          check();
          onPhase?.call(ResumeImportPhase.ready);
          return decodeResume(saved.data);
        }
        if (status == 'WAITING_CONFIRMATION') {
          final parsed = data['parsed_content'];
          final content = parsed is Map
              ? Map<String, dynamic>.from(parsed)
              : <String, dynamic>{};
          final raw =
              content['raw_text'] as String? ??
              data['unresolved_source_text'] as String? ??
              '';
          if (decodeResume({'content': content}).progress == 0 &&
              raw.trim().isNotEmpty) {
            content['job_expectation'] = {'preference': raw};
          }
          final draft = decodeResume({'title': name, 'content': content});
          onPhase?.call(ResumeImportPhase.ready);
          return ResumeDraft(
            id: 0,
            importID: taskID,
            photoFileID: integer(data['photo_file_id']),
            photoURL: data['photo_url'] as String? ?? '',
            title: draft.title,
            name: draft.name,
            position: draft.position,
            city: draft.city,
            phone: draft.phone,
            email: draft.email,
            summary: draft.summary,
            experience: draft.experience,
            education: draft.education,
            skills: draft.skills,
            source: draft.source,
            progress: draft.progress,
          );
        }
        if (['FAILED', 'CANCELED', 'TIMED_OUT'].contains(status)) {
          final message = switch (data['error_code']) {
            'OBJECT_STORAGE_READ_FAILED' ||
            'FILE_READ_FAILED' => '服务器暂时无法读取已上传的文件，请稍后重试',
            'IMPORT_AI_DOCUMENT_PARSE_FAILED' => '未能识别简历内容，请检查文件或稍后重试',
            'IMPORT_AI_PARSE_FAILED' => '简历内容整理失败，请稍后重试',
            _ =>
              status == 'CANCELED'
                  ? '简历导入已取消'
                  : status == 'TIMED_OUT'
                  ? '简历解析超时，请稍后重试'
                  : '简历解析失败，请稍后重试',
          };
          throw ApiFailure(message);
        }
      }
      throw const ApiFailure('简历解析时间较长，请稍后重试');
    } on ImportCancelled {
      if (taskID > 0 && store.epoch == epoch && store.isAuthenticated) {
        unawaited(
          store
              .request(
                'PostResumeImportsIdCancel',
                path: {'id': '$taskID'},
                body: {},
              )
              .then<void>((_) {}, onError: (Object _) {}),
        );
      }
      rethrow;
    }
  }
}
