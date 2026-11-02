import 'resume_native_market.dart';
import 'resume_preview_color.dart';
import 'template_preview_data.dart';
import 'resume_module_order.dart';

import 'resume_photo_image.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'resume_native_export.dart';

import 'resume_additional_fields.dart';

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import 'api/bojian_api.dart';
import 'app_store.dart';
import 'design.dart';
import 'template_preview_resources.dart';
import 'template_preview_cache.dart';

/// Same marketplace field contract as desktop template filling.
Map<String, dynamic> marketResumeFields(ResumeDraft resume) {
  final source = resume.source;
  final personal = source['personal_info'] as Map? ?? {};
  final job = source['job_expectation'] as Map? ?? {};
  String text(Map row, String key) {
    final rich = plainContent(row['${key}_rich']);
    return rich.isNotEmpty ? rich : row[key]?.toString() ?? '';
  }

  String secondaryText(Map row, String section, String key) => [
    if (section == 'educations') text(row, 'thesis_title'),
    text(row, key),
  ].where((value) => value.trim().isNotEmpty).join('\n');
  Map? secondaryRich(Map row, String section, String key) {
    final rich = row['${key}_rich'];
    final title = section == 'educations' ? text(row, 'thesis_title') : '';
    if (title.trim().isEmpty) return rich is Map ? rich : null;
    return {
      'blocks': [
        {
          'kind': 'paragraph',
          'spans': [
            {'text': title},
          ],
        },
        if (rich is Map && rich['blocks'] is List)
          ...rich['blocks'] as List
        else
          for (final line in text(row, key).split('\n'))
            if (line.isNotEmpty)
              {
                'kind': 'paragraph',
                'spans': [
                  {'text': line},
                ],
              },
      ],
    };
  }

  List<Map<String, dynamic>> entries(
    String key,
    String title,
    String subtitle,
    String auxiliary,
    String detail,
    String secondary,
  ) => (source[key] as List? ?? [])
      .whereType<Map>()
      .map(
        (row) => <String, dynamic>{
          'title': text(row, title),
          'subtitle': text(row, subtitle),
          'auxiliary': text(row, auxiliary),
          'start_date': text(
            row,
            key == 'certifications' ? 'date' : 'start_date',
          ),
          'end_date': row['current'] == true || row['is_current'] == true
              ? '至今'
              : text(row, 'end_date'),
          'detail': text(row, detail),
          'secondary_detail': secondaryText(row, key, secondary),
          if (row['${detail}_rich'] is Map)
            'detail_rich': row['${detail}_rich'],
          if (secondaryRich(row, key, secondary) case final Map rich)
            'secondary_detail_rich': rich,
        },
      )
      .toList();
  return {
    'name': resume.name,
    'phone': resume.phone,
    'email': resume.email,
    'birth_date': resumeBirthLabel(personal),
    'birth_date_label':
        personal['birth_date_display_mode'] == 'age' &&
            resumeAge(personal['birth_date']?.toString() ?? '') != null
        ? '年龄'
        : '出生日期',
    'section_order': resumeModuleOrder(source),
    'gender': resumeGenderLabel(personal['gender']),
    'position': resume.position,
    'city': resume.city,
    'industry': job['industry'] ?? '',
    'salary': job['salary'] ?? '',
    'preference': text(job, 'preference'),
    if (job['preference_rich'] is Map)
      'preference_rich': job['preference_rich'],
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
            if (row['description_rich'] is Map)
              'detail_rich': row['description_rich'],
          },
        )
        .toList(),
  };
}

int marketTemplateProtocol(Map<String, dynamic> dom) {
  final schema = dom['schema'] ?? dom['manifest'];
  if (schema is Map && schema['protocol_version'] is num) {
    return (schema['protocol_version'] as num).toInt();
  }
  if (schema is Map && schema['format'] == 'dom-v2') return 2;
  return (dom['html'] as String? ?? '').contains('data-bj-section') ? 2 : 1;
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
  bool thumbnail = false,
  bool monochrome = false,
  String previewScript = '',
}) {
  final payload = jsonEncode({
    'html': dom['html'],
    'protocol_version': marketTemplateProtocol(dom),
    'fields': fields ?? marketResumeFields(resume),
    'photo': photo,
  }).replaceAll('<', r'\u003c');
  final css = (dom['css'] as String? ?? '').replaceAll(
    RegExp(r'</style', caseSensitive: false),
    '< /style',
  );
  return '''<!doctype html><html><head><meta charset="utf-8">
<meta name="viewport" content="${thumbnail
      ? 'width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no'
      : marketplacePreview
      ? 'width=device-width,initial-scale=1,minimum-scale=1,maximum-scale=4'
      : 'width=826,minimum-scale=0.1,maximum-scale=2.5'}">
<meta http-equiv="Content-Security-Policy" content="default-src 'none'; script-src 'unsafe-inline'; style-src 'unsafe-inline'; img-src data:; font-src file: data:">
<style>$fontStyles</style><style>$css</style><style>
html,body{margin:0!important;padding:0!important;background:#f5f7fa!important;font-family:var(--resume-font,system-ui,-apple-system,sans-serif)!important}
#pages{padding:16px;width:794px;margin:0 auto;filter:${monochrome ? 'grayscale(1)' : 'none'}!important}
.paper{width:794px;height:1123px;position:relative;background:white;overflow:hidden;margin-bottom:16px}
.inner{position:absolute;left:61.5px;top:61.5px;width:671px;height:1000px;overflow:hidden}
#flow,.flow{position:absolute;left:0;top:0;width:671px;height:1000px;column-width:671px;column-gap:32px;column-fill:auto}
#flow{left:-100000px}
#flow *, .flow *{font-family:var(--resume-font,system-ui,-apple-system,sans-serif)!important}
p{white-space:pre-wrap} img{max-width:100%}
${thumbnail ? '''
html,body{overflow:hidden!important;background:white!important}
#pages{padding:0;margin:0;transform-origin:top left}
#pages>.paper{margin:0}
#pages>.paper~.paper{display:none}
''' : ''}
</style></head><body><div id="flow"></div><div id="pages"></div>
${thumbnail ? '''<script>
function fitThumbnail(){document.getElementById('pages').style.transform='scale('+window.innerWidth/794+')';}
fitThumbnail();window.addEventListener('resize',fitThumbnail);
</script>''' : ''}
<script>const payload=$payload;</script><script>$captureScript</script><script>$rendererScript</script>
<script>$previewScript</script>
</body></html>''';
}

class ResumeMarketDocumentView extends StatefulWidget {
  const ResumeMarketDocumentView({
    super.key,
    required this.store,
    required this.resume,
    this.thumbnail = false,
    this.monochrome = false,
  });
  final AppStore store;
  final ResumeDraft resume;
  final bool thumbnail;
  final bool monochrome;
  @override
  State<ResumeMarketDocumentView> createState() =>
      ResumeMarketDocumentViewState();
}

class ResumeMarketDocumentViewState extends State<ResumeMarketDocumentView> {
  WebViewController? controller;
  NativeMarketDocument? nativeDocument;
  bool ready = false;
  String? error;
  int pages = 0, operation = 0, captureToken = 0;
  Completer<Uint8List>? captured;
  Completer<ResumeExportLayout>? nativeLayout;
  Completer<int>? fontReady;
  bool exporting = false;
  File? documentFile;
  Future<void>? exportResourcesReady;
  Timer? loadTimeout;
  Color background = AppColors.light.canvas;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    background = widget.thumbnail ? Colors.white : context.colors.canvas;
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

  Future<void> updatePreviewColor(WebViewController web) async {
    try {
      await web.runJavaScript(
        "document.getElementById('pages')?.style.setProperty('filter', "
        "'${widget.monochrome ? 'grayscale(1)' : 'none'}', 'important');",
      );
    } on PlatformException {
      // Reapply to the replacement DOM when navigation finishes.
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
    if (oldWidget.monochrome != widget.monochrome && controller != null) {
      unawaited(updatePreviewColor(controller!));
    }
    if ((!widget.thumbnail &&
            oldWidget.resume.revision != widget.resume.revision) ||
        oldWidget.thumbnail != widget.thumbnail ||
        oldWidget.resume.marketTemplateID != widget.resume.marketTemplateID) {
      load();
    }
  }

  @override
  void dispose() {
    operation++;
    nativeDocument?.dispose();
    loadTimeout?.cancel();
    if (fontReady != null && !fontReady!.isCompleted) {
      fontReady!.completeError(const ApiFailure('导出已取消'));
    }
    if (captured != null && !captured!.isCompleted) {
      captured!.completeError(const ApiFailure('导出已取消'));
    }
    if (nativeLayout != null && !nativeLayout!.isCompleted) {
      nativeLayout!.completeError(const ApiFailure('导出已取消'));
    }
    final file = documentFile;
    if (file != null) {
      unawaited(file.delete().catchError((_) => file));
    }
    super.dispose();
  }

  Future<String> photoData(String url) async {
    if (Uri.tryParse(url)?.scheme != 'https') {
      throw const ApiFailure('简历照片暂不可用');
    }
    final ready = Completer<ui.Image>();
    final stream = ResumePhotoImage(
      url,
      fileID: widget.resume.photoFileID,
    ).resolve(ImageConfiguration.empty);
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
    final resume = widget.thumbnail
        ? ResumeDraft(
            id: widget.resume.id,
            title: '模板示例',
            marketTemplateID: widget.resume.marketTemplateID,
          )
        : widget.resume.copy();
    loadTimeout?.cancel();
    loadTimeout = Timer(const Duration(seconds: 45), () {
      if (mounted && request == operation && !ready && error == null) {
        setState(() => error = '预览加载超时，请重试');
      }
    });
    setState(() {
      error = null;
      ready = false;
    });
    try {
      final results = await Future.wait<ApiDocument?>([
        widget.thumbnail
            ? Future<ApiDocument?>.value(null)
            : widget.store.request(
                'GetResumesId',
                path: {'id': '${resume.id}'},
              ),
        loadResumeTemplateDOM(widget.store, resume.id, resume.marketTemplateID),
      ]);
      final detail = results[0];
      final dom = results[1]!;
      if (detail != null &&
          integer(detail.data['revision']) != resume.revision) {
        throw const ApiFailure('简历已更新，请返回列表刷新后预览');
      }
      if (integer(dom.data['template_id']) != resume.marketTemplateID) {
        throw const ApiFailure('模板已更新，请刷新预览');
      }
      if ((dom.data['html'] as String? ?? '').trim().isEmpty) {
        throw const ApiFailure('模板版面暂不可用');
      }
      final photo = !widget.thumbnail && resume.photoFileID > 0
          ? await photoData(detail!.data['photo_url'] as String? ?? '')
          : '';
      final schema = dom.data['schema'];
      final nativePayload = schema is Map ? schema['native'] : null;
      if (nativePayload is Map) {
        final nativePhoto = widget.thumbnail
            ? (await rootBundle.load('assets/templates/preview_portrait.png'))
                  .buffer
                  .asUint8List()
            : photo.isEmpty
            ? null
            : base64Decode(photo.split(',').last);
        final value = await NativeMarketDocument.load(
          nativePayload,
          widget.thumbnail ? templatePreviewFields : marketResumeFields(resume),
          nativePhoto,
        );
        if (!mounted || request != operation || epoch != widget.store.epoch) {
          value.dispose();
          return;
        }
        final previous = nativeDocument;
        setState(() {
          nativeDocument = value;
          controller = null;
          ready = true;
          pages = value.document.pages.length;
        });
        loadTimeout?.cancel();
        if (previous != null) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => previous.dispose(),
          );
        }
        return;
      }
      final oldNative = nativeDocument;
      if (oldNative != null) {
        setState(() => nativeDocument = null);
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => oldNative.dispose(),
        );
      }
      final resources = await TemplatePreviewResources.load();
      if (!mounted || request != operation || epoch != widget.store.epoch) {
        return;
      }
      final htmlFile = await resources.createDocument(
        marketDocumentHtml(
          dom: dom.data,
          resume: widget.thumbnail ? ResumeDraft(id: 0, title: '模板示例') : resume,
          fields: widget.thumbnail ? templatePreviewFields : null,
          photo: widget.thumbnail ? resources.portrait : photo,
          captureScript: '',
          rendererScript: resources.renderer,
          fontStyles: resumeDocumentFontStyles,
          thumbnail: widget.thumbnail,
          monochrome: widget.monochrome,
        ),
      );
      if (!mounted || request != operation || epoch != widget.store.epoch) {
        await htmlFile.delete();
        return;
      }
      final previousFile = documentFile;
      documentFile = htmlFile;
      if (previousFile != null) {
        unawaited(previousFile.delete().catchError((_) => previousFile));
      }
      final web = WebViewController();
      if (!widget.thumbnail && web.platform is AndroidWebViewController) {
        // Honor the document viewport and fit its full width on first load.
        // Android otherwise lays out the 826px page at the device width.
        await (web.platform as AndroidWebViewController).setUseWideViewPort(
          true,
        );
      }
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
            if (data['type'] == 'font-ready' &&
                data['token'] == captureToken &&
                fontReady != null &&
                !fontReady!.isCompleted) {
              fontReady!.complete(integer(data['count']));
            }
            if (data['type'] == 'ready') {
              loadTimeout?.cancel();
              setState(() {
                error = null;
                ready = true;
                pages = integer(data['count']);
              });
            }
            if (data['type'] == 'native-layout' &&
                data['token'] == captureToken &&
                nativeLayout != null &&
                !nativeLayout!.isCompleted) {
              nativeLayout!.complete(
                marketExportLayout(
                  data['pages'] as List,
                  wordModel: data['word_model'] as Map?,
                  requiresWordFlow: marketTemplateProtocol(dom.data) >= 2,
                ),
              );
            }
            if (data['type'] == 'error') {
              final failure = ApiFailure(
                data['message'] as String? ?? '模板版面加载失败',
              );
              if (data['token'] == captureToken &&
                  fontReady != null &&
                  !fontReady!.isCompleted) {
                fontReady!.completeError(failure);
              } else if (data['token'] == captureToken &&
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
            if (mounted && controller == web) {
              unawaited(updateBackground(web));
              unawaited(updatePreviewColor(web));
            }
          },
          onNavigationRequest: (request) =>
              request.url == Uri.file(htmlFile.path).toString() ||
                  request.url == 'about:blank' ||
                  request.url.startsWith('data:text/html')
              ? NavigationDecision.navigate
              : NavigationDecision.prevent,
        ),
      );
      if (!mounted || request != operation || epoch != widget.store.epoch) {
        return;
      }
      exportResourcesReady = null;
      setState(() => controller = web);
      await web.loadFile(htmlFile.path);
    } catch (e) {
      if (mounted && request == operation && epoch == widget.store.epoch) {
        loadTimeout?.cancel();
        setState(() => error = e is ApiFailure ? e.message : '模板版面加载失败，请重试');
      }
    }
  }

  Future<void> _prepareExportResources() async {
    final web = controller;
    if (web == null) throw const ApiFailure('请等待预览加载完成');
    final existing = exportResourcesReady;
    if (existing != null) return existing;
    final pending = () async {
      final script = await rootBundle.loadString(
        'assets/templates/html2canvas.min.js',
      );
      if (!mounted || controller != web) throw const ApiFailure('导出已取消');
      await web.runJavaScript(script);
    }();
    exportResourcesReady = pending;
    try {
      await pending;
    } catch (_) {
      if (identical(exportResourcesReady, pending)) exportResourcesReady = null;
      rethrow;
    }
  }

  Future<int> _setExportMode(bool enabled) async {
    // Grayscale is a viewing preference, not a change to exported artwork.
    await controller!.runJavaScript(
      "document.getElementById('pages')?.style.setProperty('filter', "
      "'${!enabled && widget.monochrome ? 'grayscale(1)' : 'none'}', 'important');",
    );
    final waiting = Completer<int>();
    fontReady = waiting;
    captureToken++;
    final result = waiting.future.timeout(const Duration(seconds: 45));
    try {
      final values = await Future.wait<Object?>([
        result,
        controller!.runJavaScript(
          'setResumeExportMode($enabled,$captureToken)',
        ),
      ], eagerError: true);
      return values.first! as int;
    } catch (error, stack) {
      if (!waiting.isCompleted) waiting.completeError(error, stack);
      rethrow;
    } finally {
      fontReady = null;
    }
  }

  Future<void> _restorePreview(int request, int epoch) async {
    if (!mounted || request != operation || epoch != widget.store.epoch) return;
    try {
      final count = await _setExportMode(false);
      if (mounted && request == operation) setState(() => pages = count);
    } catch (_) {
      if (mounted && request == operation) {
        setState(() => error = '预览恢复失败，请重试');
      }
    }
  }

  Future<ResumeExportLayout> captureLayout({
    required bool Function() isCancelled,
    required ValueChanged<String> onProgress,
  }) async {
    final value = nativeDocument;
    if (value != null && ready) {
      final request = operation, epoch = widget.store.epoch;
      return value.export(
        isCancelled: () =>
            !mounted ||
            request != operation ||
            epoch != widget.store.epoch ||
            isCancelled(),
        onProgress: onProgress,
      );
    }
    if (!ready || controller == null) throw const ApiFailure('请等待预览加载完成');
    if (exporting) throw const ApiFailure('正在导出，请稍后再试');
    final request = operation;
    final epoch = widget.store.epoch;
    if (isCancelled()) throw const ApiFailure('导出已取消');
    onProgress('正在准备模板文字和排版…');
    exporting = true;
    try {
      await _prepareExportResources();
      if (!mounted ||
          request != operation ||
          epoch != widget.store.epoch ||
          isCancelled()) {
        throw const ApiFailure('导出已取消');
      }
      await _setExportMode(true);
      if (!mounted ||
          request != operation ||
          epoch != widget.store.epoch ||
          isCancelled()) {
        throw const ApiFailure('导出已取消');
      }
      final waiting = Completer<ResumeExportLayout>();
      nativeLayout = waiting;
      captureToken++;
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
      await _restorePreview(request, epoch);
      exporting = false;
    }
  }

  Future<List<Uint8List>> capturePages({
    required bool Function() isCancelled,
    required ValueChanged<String> onProgress,
  }) async {
    final value = nativeDocument;
    if (value != null && ready && error == null) {
      final request = operation, epoch = widget.store.epoch;
      return value.capture(
        isCancelled: () =>
            !mounted ||
            request != operation ||
            epoch != widget.store.epoch ||
            isCancelled(),
        onProgress: onProgress,
      );
    }
    if (!ready || controller == null || error != null) {
      throw const ApiFailure('请等待模板预览加载完成');
    }
    if (exporting) throw const ApiFailure('正在导出，请稍后再试');
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
    exporting = true;
    try {
      check();
      await _prepareExportResources();
      check();
      final exportPages = await _setExportMode(true);
      for (var index = 0; index < exportPages; index++) {
        check();
        onProgress('正在生成第 ${index + 1}/$exportPages 页…');
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
      await _restorePreview(request, epoch);
      exporting = false;
    }
  }

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      if (nativeDocument != null)
        Positioned.fill(
          child: ResumePreviewColor(
            monochrome: widget.monochrome,
            child: NativeMarketPages(
              value: nativeDocument!,
              thumbnail: widget.thumbnail,
            ),
          ),
        ),
      if (controller != null) WebViewWidget(controller: controller!),
      if (!ready && error == null)
        Positioned.fill(
          child: ColoredBox(
            color: background,
            child: const Center(
              child: SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
        ),
      if (error != null && widget.thumbnail)
        Positioned.fill(
          child: ColoredBox(
            color: Colors.white,
            child: Center(
              child: Text(
                '点按查看',
                style: TextStyle(color: context.colors.muted, fontSize: 10),
              ),
            ),
          ),
        ),
      if (error != null && !widget.thumbnail)
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

ResumeExportLayout marketExportLayout(
  List data, {
  Map? wordModel,
  bool requiresWordFlow = false,
}) {
  if (data.isEmpty || data.length > 30) throw const ApiFailure('模板导出页数无效');
  double n(Map value, String key) => (value[key] as num).toDouble();
  return ResumeExportLayout(
    [
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
                paragraphId: line['paragraph_id'] as String?,
                paragraphLeft: (line['paragraph_left'] as num?)?.toDouble(),
                paragraphWidth: (line['paragraph_width'] as num?)?.toDouble(),
                spans: [
                  for (final span in (line['spans'] as List).cast<Map>())
                    ResumeExportSpan(
                      text: span['text'] as String,
                      wordText: span['word_text'] as String?,
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
    ],
    requiresWordFlow: requiresWordFlow || wordModel != null,
    wordLayout: wordModel == null
        ? null
        : ResumeExportLayout(
            [
              ResumeExportPage(
                wordFlow: true,
                lines: [
                  for (final raw in (wordModel['lines'] as List).cast<Map>())
                    ResumeExportLine(
                      top: n(raw, 'top'),
                      height: n(raw, 'height'),
                      baseline: n(raw, 'baseline'),
                      paragraphId: raw['paragraph_id'] as String?,
                      paragraphField: raw['paragraph_field'] as String?,
                      paragraphLeft: n(raw, 'paragraph_left'),
                      paragraphWidth: n(raw, 'paragraph_width'),
                      paragraphBottom: n(raw, 'paragraph_bottom'),
                      paragraphAlignRight: raw['paragraph_align_right'] == true,
                      spans: [
                        for (final span in (raw['spans'] as List).cast<Map>())
                          ResumeExportSpan(
                            text: span['text'] as String,
                            x: n(span, 'x'),
                            width: n(span, 'width'),
                            size: n(span, 'size'),
                            color: (span['color'] as num).toInt(),
                            weight: (span['weight'] as num).toInt(),
                            italic: span['italic'] == true,
                            underline: span['underline'] == true,
                            strike: span['strike'] == true,
                          ),
                      ],
                    ),
                ],
                rules: [
                  for (final raw in (wordModel['rules'] as List).cast<Map>())
                    ResumeExportRule(
                      n(raw, 'x'),
                      n(raw, 'y'),
                      n(raw, 'width'),
                      n(raw, 'thickness'),
                      (raw['color'] as num).toInt(),
                    ),
                ],
                pictures: [
                  for (final raw in (wordModel['pictures'] as List).cast<Map>())
                    ResumeExportPicture(
                      base64Decode(raw['data'] as String),
                      n(raw, 'x'),
                      n(raw, 'y'),
                      n(raw, 'width'),
                      n(raw, 'height'),
                    ),
                ],
              ),
            ],
            wordMargins: (wordModel['margins'] as Map).map(
              (key, value) =>
                  MapEntry(key as String, (value as num).toDouble()),
            ),
          ),
  );
}
