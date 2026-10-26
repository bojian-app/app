import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';

import 'app_icons.dart';
import 'api/bojian_api.dart';
import 'app_store.dart';
import 'design.dart';
import 'resume_native_export.dart';

const exportMimeTypes = {
  'PDF': 'application/pdf',
  'DOCX':
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
};

class ExportCancelled implements Exception {}

typedef ExportDownload = Future<XFile> Function(
  Uri uri,
  String name,
  String mime,
  bool Function() cancelled,
);

class ResumeExporter {
  ResumeExporter(
    this.store, {
    this.download,
    Future<void> Function(Duration)? delay,
  }) : delay = delay ?? Future<void>.delayed;
  final AppStore store;
  final ExportDownload? download;
  final Future<void> Function(Duration) delay;

  Future<XFile> export(
    ResumeDraft resume,
    String format, {
    required ValueChanged<String> onProgress,
    required bool Function() isCancelled,
  }) async {
    final mime = exportMimeTypes[format];
    if (mime == null || resume.id <= 0) {
      throw const ApiFailure('请先保存简历，再选择 Word 或 PDF 格式');
    }
    final epoch = store.epoch;
    void check() {
      if (isCancelled()) throw ExportCancelled();
      if (!store.alive || !store.isAuthenticated || epoch != store.epoch) {
        throw const ApiFailure('登录状态已变化，请重新登录');
      }
    }

    check();
    onProgress('正在生成${format == 'PDF' ? ' PDF' : ' Word'}文件…');
    final created = await store.request(
      'PostResumeExports',
      body: {
        'resume_id': resume.id,
        'source_kind': 'WORKING',
        'format': format,
      },
    );
    check();
    final id = integer(created.data['id']);
    if (id <= 0) throw const ApiFailure('未能创建导出任务，请重试');
    for (var attempt = 0; attempt < 120; attempt++) {
      if (attempt > 0) await store.waitForJobUpdate('RESUME_EXPORT', id, delay);
      check();
      final response = await store.request(
        'GetResumeExportsId',
        path: {'id': '$id'},
      );
      check();
      final status = response.data['status'];
      if (status == 'SUCCEEDED') {
        final uri = Uri.tryParse(
          response.data['download_url'] as String? ?? '',
        );
        if (uri == null ||
            uri.scheme != 'https' ||
            uri.host.isEmpty ||
            uri.userInfo.isNotEmpty) {
          throw const ApiFailure('导出文件暂不可下载，请稍后重试');
        }
        var name = resume.title
            .replaceAll(RegExp(r'[\x00-\x1f/\\:*?"<>|]'), '_')
            .trim();
        name = String.fromCharCodes(name.runes.take(80));
        if (name.isEmpty || name == '.' || name == '..') name = '我的简历';
        onProgress('正在下载文件…');
        final file = await (download ?? _download)(
          uri,
          '$name.${format.toLowerCase()}',
          mime,
          () => isCancelled() || epoch != store.epoch || !store.alive,
        );
        try {
          check();
          return file;
        } catch (_) {
          await clearExportFile(file);
          rethrow;
        }
      }
      if (['FAILED', 'CANCELED', 'TIMED_OUT'].contains(status)) {
        throw const ApiFailure('简历导出失败，请稍后重试');
      }
    }
    throw const ApiFailure('简历生成时间较长，请稍后重试');
  }

  Future<XFile> _download(
    Uri uri,
    String name,
    String mime,
    bool Function() cancelled,
  ) async {
    final directory = await Directory.systemTemp.createTemp(
      'bojian-resume-export-',
    );
    final file = File('${directory.path}/$name');
    final shared = store.api is BojianApi
        ? (store.api as BojianApi).client
        : null;
    final client = shared ?? http.Client();
    IOSink? sink;
    try {
      final response = await client
          .send(http.Request('GET', uri)..followRedirects = false)
          .timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) {
        await response.stream.drain<void>();
        throw const ApiFailure('导出文件下载失败，请重试');
      }
      var size = 0;
      final signature = <int>[];
      sink = file.openWrite();
      await for (final chunk in response.stream.timeout(
        const Duration(seconds: 30),
      )) {
        if (cancelled()) throw ExportCancelled();
        size += chunk.length;
        if (size > 30 * 1024 * 1024) throw const ApiFailure('导出文件过大，请使用桌面端导出');
        if (signature.length < 5) {
          signature.addAll(chunk.take(5 - signature.length));
        }
        sink.add(chunk);
      }
      await sink.close();
      sink = null;
      final valid = mime == 'application/pdf'
          ? String.fromCharCodes(signature) == '%PDF-'
          : signature.length >= 4 &&
                signature[0] == 80 &&
                signature[1] == 75 &&
                signature[2] == 3 &&
                signature[3] == 4;
      if (!valid) throw const ApiFailure('服务器返回的导出文件无效，请重试');
      return XFile(file.path, mimeType: mime);
    } catch (error) {
      await sink?.close();
      await directory.delete(recursive: true);
      if (error is ApiFailure || error is ExportCancelled) rethrow;
      throw const ApiFailure('文件下载中断，请检查网络后重试');
    } finally {
      if (shared == null) client.close();
    }
  }
}

Future<void> clearExportFile(XFile? file) async {
  if (file == null) return;
  final directory = File(file.path).parent;
  if (!directory.path
      .split(Platform.pathSeparator)
      .last
      .startsWith('bojian-resume-export-')) {
    return;
  }
  try {
    if (await directory.exists()) await directory.delete(recursive: true);
  } catch (_) {}
}

class ResumeExportSheet extends StatefulWidget {
  const ResumeExportSheet({
    super.key,
    required this.store,
    required this.resume,
    this.captureLayout,
  });
  final AppStore store;
  final ResumeDraft resume;
  final CaptureResumeLayout? captureLayout;
  @override
  State<ResumeExportSheet> createState() => _ResumeExportSheetState();
}

class _ResumeExportSheetState extends State<ResumeExportSheet> {
  bool busy = false;
  String progress = '';
  String? error;
  XFile? file;
  @override
  void dispose() {
    if (!busy) unawaited(clearExportFile(file));
    super.dispose();
  }

  Future<void> generate(String format) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    final epoch = widget.store.epoch;
    bool cancelled() =>
        !mounted || epoch != widget.store.epoch || !widget.store.alive;
    try {
      final result = widget.captureLayout != null
          ? await exportNativeResume(
              capture: widget.captureLayout!,
              title: widget.resume.title,
              format: format,
              isCancelled: cancelled,
              onProgress: (value) {
                if (mounted) setState(() => progress = value);
              },
            )
          : await ResumeExporter(widget.store).export(
              widget.resume,
              format,
              onProgress: (value) {
                if (mounted) setState(() => progress = value);
              },
              isCancelled: cancelled,
            );
      if (cancelled()) {
        await clearExportFile(result);
        return;
      }
      setState(() => file = result);
    } on ExportCancelled {
      /* Closing the sheet stops polling. */
    } catch (e) {
      if (mounted) {
        setState(() => error = e is ApiFailure ? e.message : '导出失败，请重试');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> deliver({required bool save}) async {
    if (file == null || busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (save && Platform.isAndroid) {
        final saved =
            await const MethodChannel('cn.kelance.bojian/resume_files')
                .invokeMethod<bool>('saveExport', {
                  'path': file!.path,
                  'name': file!.name,
                  'mime': file!.mimeType,
                });
        if (mounted && saved == true) toast(context, '文件已保存');
      } else {
        final box = context.findRenderObject() as RenderBox?;
        await SharePlus.instance.share(
          ShareParams(
            files: [file!],
            title: '导出简历',
            sharePositionOrigin: box == null
                ? null
                : box.localToGlobal(Offset.zero) & box.size,
          ),
        );
      }
    } on PlatformException catch (e) {
      if (mounted) {
        setState(
          () => error = switch (e.code) {
            'FILE_INVALID' => '导出文件已失效，请重新导出',
            'SAVE_FAILED' => '无法保存文件，请重试或使用分享文件',
            _ => '无法保存或分享文件，请重试',
          },
        );
      }
    } catch (_) {
      if (mounted) setState(() => error = '无法保存或分享文件，请重试');
    } finally {
      if (mounted) {
        setState(() => busy = false);
      } else {
        await clearExportFile(file);
      }
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '导出简历',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          if (file == null && !busy) ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: AppIcon(AppIcons.pdf, color: context.colors.accent),
              title: const Text('PDF'),
              subtitle: const Text('适合投递、预览和打印'),
              onTap: () => generate('PDF'),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: AppIcon(AppIcons.word, color: context.colors.accent),
              title: const Text('Word'),
              subtitle: const Text('保留文字，可继续编辑'),
              onTap: () => generate('DOCX'),
            ),
          ],
          if (file == null && busy)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Row(
                children: [
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 16),
                  Expanded(child: Text(progress)),
                ],
              ),
            ),
          if (error != null)
            Text(error!, style: const TextStyle(color: Colors.redAccent)),
          if (file != null) ...[
            Text(
              file!.name,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: busy ? null : () => deliver(save: true),
                icon: const AppIcon(AppIcons.download, size: 18),
                label: Text(Platform.isAndroid ? '保存到本机' : '保存到文件'),
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: busy ? null : () => deliver(save: false),
                child: const Text('分享文件'),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}
