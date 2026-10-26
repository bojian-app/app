import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'resume_native_export.dart';

import 'resume_additional_fields.dart';

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'api/bojian_api.dart';
import 'app_store.dart';
import 'design.dart';

/// Same marketplace field contract as desktop template filling.
Map<String, dynamic> marketResumeFields(ResumeDraft resume) {
  final source = resume.source;
  final personal = source['personal_info'] as Map? ?? {};
  final job = source['job_expectation'] as Map? ?? {};
  String text(Map row, String key) {
    final rich = plainContent(row['${key}_rich']);
    return rich.isNotEmpty ? rich : row[key]?.toString() ?? '';
  }

  List<Map<String, String>> entries(
    String key,
    String title,
    String subtitle,
    String auxiliary,
    String detail,
    String secondary,
  ) => (source[key] as List? ?? [])
      .whereType<Map>()
      .map(
        (row) => <String, String>{
          'title': text(row, title),
          'subtitle': text(row, subtitle),
          'auxiliary': text(row, auxiliary),
          'start_date': text(row, 'start_date'),
          'end_date': row['is_current'] == true ? '至今' : text(row, 'end_date'),
          'detail': text(row, detail),
          'secondary_detail': text(row, secondary),
        },
      )
      .toList();
  return {
    'name': resume.name,
    'phone': resume.phone,
    'email': resume.email,
    'birth_date': resumeBirthLabel(personal),
    'gender': resumeGenderLabel(personal['gender']),
    'position': resume.position,
    'city': resume.city,
    'industry': job['industry'] ?? '',
    'salary': job['salary'] ?? '',
    'preference': text(job, 'preference'),
    'educations': entries(
      'educations',
      'institution',
      'degree',
      'field_of_study',
      'campus_experience',
      'thesis_description',
    ),
    'work_experiences': entries(
      'work_experiences',
      'company',
      'position',
      'industry',
      'description',
      '',
    ),
    'projects': entries(
      'projects',
      'name',
      'role',
      'url',
      'description',
      'achievements',
    ),
    'certifications': entries('certifications', 'name', 'issuer', '', '', ''),
    'skills': (source['skills'] as List? ?? [])
        .whereType<Map>()
        .map(
          (row) => {
            'name': text(row, 'name'),
            'detail': text(row, 'description'),
          },
        )
        .toList(),
  };
}

String marketDocumentHtml({
  required Map<String, dynamic> dom,
  required ResumeDraft resume,
  required String captureScript,
  required String rendererScript,
  String photo = '',
  String fontStyles = '',
  Map<String, dynamic>? fields,
  bool marketplacePreview = false,
  String previewScript = '',
}) {
  final payload = jsonEncode({
    'html': dom['html'],
    'fields': fields ?? marketResumeFields(resume),
    'photo': photo,
  }).replaceAll('<', r'\u003c');
  final css = (dom['css'] as String? ?? '').replaceAll(
    RegExp(r'</style', caseSensitive: false),
    '< /style',
  );
  return '''<!doctype html><html><head><meta charset="utf-8">
<meta name="viewport" content="${marketplacePreview ? 'width=device-width,initial-scale=1,minimum-scale=1,maximum-scale=4' : 'width=826,initial-scale=0.43,minimum-scale=0.3,maximum-scale=2.5'}">
<meta http-equiv="Content-Security-Policy" content="default-src 'none'; script-src 'unsafe-inline'; style-src 'unsafe-inline'; img-src data:; font-src file: data:">
<style>$fontStyles</style><style>$css</style><style>
html,body{margin:0!important;padding:0!important;background:#f5f7fa!important;font-family:'ResumeDocument',sans-serif!important}
#pages{padding:16px;width:794px;margin:0 auto}
.paper{width:794px;height:1123px;position:relative;background:white;overflow:hidden;margin-bottom:16px}
.inner{position:absolute;left:61.5px;top:61.5px;width:671px;height:1000px;overflow:hidden}
#flow,.flow{position:absolute;left:0;top:0;width:671px;height:1000px;column-width:671px;column-gap:32px;column-fill:auto}
#flow{left:-100000px}
#flow *, .flow *{font-family:'ResumeDocument',sans-serif!important}
p{white-space:pre-wrap} img{max-width:100%}
</style></head><body><div id="flow"></div><div id="pages"></div>
<script>const payload=$payload;</script><script>$captureScript</script><script>$rendererScript</script>
<script>$previewScript</script>
</body></html>''';
}

class ResumeMarketDocumentView extends StatefulWidget {
  const ResumeMarketDocumentView({
    super.key,
    required this.store,
    required this.resume,
  });
  final AppStore store;
  final ResumeDraft resume;
  @override
  State<ResumeMarketDocumentView> createState() =>
      ResumeMarketDocumentViewState();
}

class ResumeMarketDocumentViewState extends State<ResumeMarketDocumentView> {
  WebViewController? controller;
  bool ready = false;
  String? error;
  int pages = 0, operation = 0, captureToken = 0;
  Completer<Uint8List>? captured;
  Completer<ResumeExportLayout>? nativeLayout;
  Directory? documentDirectory;
  Color background = AppColors.light.canvas;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    background = context.colors.canvas;
    final web = controller;
    if (web != null) unawaited(updateBackground(web));
  }

  // Change only the page surround; template paper and exported pixels keep
  // their authored colors and the current document/scroll position stays put.
  Future<void> updateBackground(WebViewController web) async {
    final color = background;
    try {
      await web.setBackgroundColor(color);
      if (!mounted || background != color) return;
      final hex = color.toARGB32().toRadixString(16).substring(2);
      await web.runJavaScript('''
        for (const node of [document.documentElement, document.body]) {
          node?.style.setProperty('background-color', '#$hex', 'important');
        }
      ''');
    } on PlatformException {
      // Navigation can replace the DOM mid-update; apply again when it finishes.
    }
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void didUpdateWidget(ResumeMarketDocumentView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.resume.revision != widget.resume.revision ||
        oldWidget.resume.marketTemplateID != widget.resume.marketTemplateID) {
      load();
    }
  }

  @override
  void dispose() {
    operation++;
    if (captured != null && !captured!.isCompleted) {
      captured!.completeError(const ApiFailure('导出已取消'));
    }
    if (nativeLayout != null && !nativeLayout!.isCompleted) {
      nativeLayout!.completeError(const ApiFailure('导出已取消'));
    }
    final directory = documentDirectory;
    if (directory != null) {
      unawaited(directory.delete(recursive: true).catchError((_) => directory));
    }
    super.dispose();
  }

  Future<String> photoData(String url) async {
    if (Uri.tryParse(url)?.scheme != 'https') {
      throw const ApiFailure('简历照片暂不可用');
    }
    final ready = Completer<ui.Image>();
    final stream = NetworkImage(url).resolve(ImageConfiguration.empty);
    late ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) {
        if (!ready.isCompleted) ready.complete(info.image.clone());
      },
      onError: (Object e, StackTrace? s) {
        if (!ready.isCompleted) {
          ready.completeError(const ApiFailure('简历照片加载失败'));
        }
      },
    );
    stream.addListener(listener);
    ui.Image? image;
    try {
      image = await ready.future.timeout(const Duration(seconds: 30));
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) throw const ApiFailure('简历照片暂不可用');
      return 'data:image/png;base64,${base64Encode(bytes.buffer.asUint8List())}';
    } finally {
      stream.removeListener(listener);
      image?.dispose();
    }
  }

  Future<void> load() async {
    final request = ++operation, epoch = widget.store.epoch;
    setState(() {
      error = null;
      ready = false;
    });
    try {
      final detail = await widget.store.request(
        'GetResumesId',
        path: {'id': '${widget.resume.id}'},
      );
      if (integer(detail.data['revision']) != widget.resume.revision) {
        throw const ApiFailure('简历已更新，请返回列表刷新后预览');
      }
      final dom = await widget.store.request(
        'GetResumesIdDomPreview',
        path: {'id': '${widget.resume.id}'},
      );
      if (integer(dom.data['template_id']) != widget.resume.marketTemplateID) {
        throw const ApiFailure('模板已更新，请刷新预览');
      }
      final photo = widget.resume.photoFileID > 0
          ? await photoData(detail.data['photo_url'] as String? ?? '')
          : '';
      final captureScript = await rootBundle.loadString(
        'assets/templates/html2canvas.min.js',
      );
      final rendererScript = await rootBundle.loadString(
        'assets/templates/market_renderer.js',
      );
      if (!mounted || request != operation || epoch != widget.store.epoch) {
        return;
      }
      final directory = await Directory.systemTemp.createTemp(
        'bojian-market-document-',
      );
      for (final entry in resumeDocumentFontAssets.entries) {
        final data = await rootBundle.load(entry.value);
        await File('${directory.path}/${entry.key}').writeAsBytes(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        );
      }
      if (!mounted || request != operation || epoch != widget.store.epoch) {
        await directory.delete(recursive: true);
        return;
      }
      final previousDirectory = documentDirectory;
      documentDirectory = directory;
      final htmlFile = File('${directory.path}/document.html');
      final web = WebViewController();
      await web.setJavaScriptMode(JavaScriptMode.unrestricted);
      await web.setBackgroundColor(background);
      await web.addJavaScriptChannel(
        'BojianPages',
        onMessageReceived: (message) {
          if (!mounted || request != operation || epoch != widget.store.epoch) {
            return;
          }
          try {
            final data = jsonDecode(message.message) as Map;
            if (data['type'] == 'ready') {
              setState(() {
                ready = true;
                pages = integer(data['count']);
              });
            }
            if (data['type'] == 'native-layout' &&
                data['token'] == captureToken &&
                nativeLayout != null &&
                !nativeLayout!.isCompleted) {
              nativeLayout!.complete(marketExportLayout(data['pages'] as List));
            }
            if (data['type'] == 'error') {
              final failure = ApiFailure(
                data['message'] as String? ?? '模板版面加载失败',
              );
              if (data['token'] == captureToken &&
                  nativeLayout != null &&
                  !nativeLayout!.isCompleted) {
                nativeLayout!.completeError(failure);
              } else if (data['token'] == captureToken &&
                  captured != null &&
                  !captured!.isCompleted) {
                captured!.completeError(failure);
              } else {
                setState(() => error = failure.message);
              }
            }
            if (data['type'] == 'page' &&
                data['token'] == captureToken &&
                captured != null &&
                !captured!.isCompleted) {
              captured!.complete(base64Decode(data['data'] as String));
            }
          } catch (_) {
            if (nativeLayout != null && !nativeLayout!.isCompleted) {
              nativeLayout!.completeError(const ApiFailure('模板版面数据无效'));
            }
            if (mounted) setState(() => error = '模板版面数据无效');
          }
        },
      );
      await web.setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted && controller == web) unawaited(updateBackground(web));
          },
          onNavigationRequest: (request) =>
              request.url == Uri.file(htmlFile.path).toString() ||
                  request.url == 'about:blank' ||
                  request.url.startsWith('data:text/html')
              ? NavigationDecision.navigate
              : NavigationDecision.prevent,
        ),
      );
      if (!mounted || request != operation) return;
      setState(() => controller = web);
      await htmlFile.writeAsString(
        marketDocumentHtml(
          dom: dom.data,
          resume: widget.resume,
          photo: photo,
          captureScript: captureScript,
          rendererScript: rendererScript,
          fontStyles: resumeDocumentFontStyles,
        ),
      );
      await web.loadFile(htmlFile.path);
      if (previousDirectory != null) {
        unawaited(
          previousDirectory
              .delete(recursive: true)
              .catchError((_) => previousDirectory),
        );
      }
    } catch (e) {
      if (mounted && request == operation) {
        setState(() => error = e is ApiFailure ? e.message : '模板版面加载失败，请重试');
      }
    }
  }

  Future<ResumeExportLayout> captureLayout({
    required bool Function() isCancelled,
    required ValueChanged<String> onProgress,
  }) async {
    if (!ready || controller == null) throw const ApiFailure('请等待预览加载完成');
    final request = operation;
    final epoch = widget.store.epoch;
    if (isCancelled()) throw const ApiFailure('导出已取消');
    onProgress('正在准备模板文字和排版…');
    final waiting = Completer<ResumeExportLayout>();
    nativeLayout = waiting;
    captureToken++;
    try {
      await controller!.runJavaScript('exportNativeLayout($captureToken)');
      final result = await waiting.future.timeout(const Duration(seconds: 90));
      if (!mounted ||
          request != operation ||
          epoch != widget.store.epoch ||
          isCancelled()) {
        throw const ApiFailure('导出已取消');
      }
      return result;
    } finally {
      nativeLayout = null;
    }
  }

  Future<List<Uint8List>> capturePages({
    required bool Function() isCancelled,
    required ValueChanged<String> onProgress,
  }) async {
    if (!ready || controller == null || error != null) {
      throw const ApiFailure('请等待模板预览加载完成');
    }
    if (captured != null) throw const ApiFailure('正在导出，请稍后再试');
    final epoch = widget.store.epoch, request = operation;
    void check() {
      if (!mounted ||
          isCancelled() ||
          epoch != widget.store.epoch ||
          request != operation) {
        throw const ApiFailure('导出已取消');
      }
    }

    final result = <Uint8List>[];
    try {
      for (var index = 0; index < pages; index++) {
        check();
        onProgress('正在生成第 ${index + 1}/$pages 页…');
        captured = Completer<Uint8List>();
        final waiting = captured!.future.timeout(const Duration(seconds: 60));
        captureToken++;
        await controller!.runJavaScript('capturePage($index,$captureToken)');
        result.add(await waiting);
        check();
        captured = null;
      }
      return result;
    } finally {
      captured = null;
    }
  }

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      if (controller != null) WebViewWidget(controller: controller!),
      if (!ready && error == null)
        const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      if (error != null)
        ColoredBox(
          color: context.colors.canvas,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: context.colors.muted),
                  ),
                  TextButton(onPressed: load, child: const Text('重新加载')),
                ],
              ),
            ),
          ),
        ),
    ],
  );
}

ResumeExportLayout marketExportLayout(List data) {
  if (data.isEmpty || data.length > 30) throw const ApiFailure('模板导出页数无效');
  double n(Map value, String key) => (value[key] as num).toDouble();
  return ResumeExportLayout([
    for (final page in data.cast<Map>())
      ResumeExportPage(
        background: page['background'] is String
            ? ResumeExportPicture(
                base64Decode(page['background'] as String),
                0,
                0,
                595.28,
                841.89,
              )
            : null,
        lines: [
          for (final line in (page['lines'] as List).cast<Map>())
            ResumeExportLine(
              top: n(line, 'top'),
              height: n(line, 'height'),
              baseline: n(line, 'baseline'),
              spans: [
                for (final span in (line['spans'] as List).cast<Map>())
                  ResumeExportSpan(
                    text: span['text'] as String,
                    x: n(span, 'x'),
                    width: n(span, 'width'),
                    size: n(span, 'size'),
                    color: (span['color'] as num).toInt(),
                    bold: span['bold'] == true,
                    weight: (span['weight'] as num?)?.toInt(),
                    italic: span['italic'] == true,
                    underline: span['underline'] == true,
                    strike: span['strike'] == true,
                  ),
              ],
            ),
        ],
        rules: [
          for (final rule in (page['rules'] as List).cast<Map>())
            ResumeExportRule(
              n(rule, 'x'),
              n(rule, 'y'),
              n(rule, 'width'),
              n(rule, 'thickness'),
              (rule['color'] as num).toInt(),
              height: n(rule, 'height'),
            ),
        ],
        pictures: [
          for (final image in (page['pictures'] as List).cast<Map>())
            ResumeExportPicture(
              base64Decode(image['data'] as String),
              n(image, 'x'),
              n(image, 'y'),
              n(image, 'width'),
              n(image, 'height'),
            ),
        ],
      ),
  ]);
}
