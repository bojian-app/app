import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'api/bojian_api.dart';
import 'app_store.dart';
import 'design.dart';
import 'template_preview_document.dart';

class TemplateLivePreview extends StatefulWidget {
  const TemplateLivePreview({
    super.key,
    required this.store,
    required this.templateID,
    required this.version,
    required this.author,
    this.initialPage = 0,
    this.fullscreen = false,
    this.onOpenPage,
  });
  final AppStore store;
  final int templateID, version;
  final String author;
  final int initialPage;
  final bool fullscreen;
  final ValueChanged<int>? onOpenPage;

  @override
  State<TemplateLivePreview> createState() => _TemplateLivePreviewState();
}

class _TemplateLivePreviewState extends State<TemplateLivePreview> {
  WebViewController? controller;
  Directory? directory;
  Timer? timeout;
  int operation = 0, pages = 0;
  late final int epoch = widget.store.epoch;
  String? error;
  bool ready = false;
  final pageActions =
      ValueNotifier<List<({int index, double top, double bottom})>>([]);
  Color background = AppColors.light.canvas;

  bool current(int request) =>
      mounted && request == operation && widget.store.epoch == epoch;

  @override
  void initState() {
    super.initState();
    widget.store.addListener(accountChanged);
    load();
  }

  void accountChanged() {
    if (widget.store.epoch == epoch) return;
    operation++;
    timeout?.cancel();
    setState(() {
      controller = null;
      ready = false;
      error = '登录状态已变化，请返回后重试';
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    background = context.colors.surface;
    updateBackground();
  }

  @override
  void didUpdateWidget(covariant TemplateLivePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.author != oldWidget.author) unawaited(updateAuthor());
    if (widget.fullscreen != oldWidget.fullscreen ||
        widget.initialPage != oldWidget.initialPage) {
      unawaited(updatePreviewMode());
    }
  }

  Future<void> updatePreviewMode() async {
    if (widget.store.epoch != epoch) return;
    try {
      await controller?.runJavaScript(
        'window.setPreviewMode?.(${widget.fullscreen}, ${widget.initialPage});',
      );
    } on PlatformException {
      // Apply again when the document has finished loading.
    }
  }

  Future<void> updateAuthor() async {
    try {
      await controller?.runJavaScript(
        'window.updatePreviewAuthor?.(${jsonEncode(widget.author)});',
      );
    } on PlatformException {
      // The next page-finished callback applies the latest author.
    }
  }

  Future<void> openPage(int index) async {
    if (!ready ||
        widget.fullscreen ||
        error != null ||
        widget.store.epoch != epoch) {
      return;
    }
    try {
      // Save the browser's scroll position before the fullscreen transition.
      await controller?.runJavaScript('window.openPreviewPage?.($index);');
    } on PlatformException {
      if (mounted) setState(() => error = '模板预览暂不可用，请重新加载');
    }
  }

  void updatePageActions(dynamic items) {
    if (items is! List) return;
    final positions = <({int index, double top, double bottom})>[];
    for (final item in items.take(30)) {
      if (item is! Map) continue;
      final index = item['index'], top = item['top'], bottom = item['bottom'];
      if (index is! int ||
          index < 0 ||
          index >= 30 ||
          top is! num ||
          !top.isFinite ||
          top < 0 ||
          top >= 1 ||
          bottom is! num ||
          !bottom.isFinite ||
          bottom <= top ||
          bottom > 1 ||
          positions.any((position) => position.index == index)) {
        continue;
      }
      positions.add((
        index: index,
        top: top.toDouble(),
        bottom: bottom.toDouble(),
      ));
    }
    pageActions.value = positions;
  }

  Future<void> updateBackground() async {
    final web = controller;
    if (web == null) return;
    try {
      await web.setBackgroundColor(background);
      final hex = background.toARGB32().toRadixString(16).substring(2);
      await web.runJavaScript(
        "for(const n of [document.documentElement,document.body]) n.style.setProperty('background-color','#$hex','important')",
      );
    } on PlatformException {
      /* The document may be navigating. */
    }
  }

  @override
  void dispose() {
    widget.store.removeListener(accountChanged);
    operation++;
    timeout?.cancel();
    pageActions.dispose();
    removeDirectory(directory);
    super.dispose();
  }

  void removeDirectory(Directory? value) {
    if (value != null) {
      unawaited(value.delete(recursive: true).catchError((_) => value));
    }
  }

  Future<void> load() async {
    if (widget.store.epoch != epoch) return;
    final request = ++operation;
    timeout?.cancel();
    pageActions.value = [];
    final previous = directory;
    directory = null;
    setState(() {
      ready = false;
      error = null;
      controller = null;
    });
    removeDirectory(previous);
    Directory? pending;
    try {
      final result = await widget.store.request(
        'GetTemplatesIdDom',
        path: {'id': '${widget.templateID}'},
      );
      if (!current(request)) return;
      if ((result.data['html'] as String? ?? '').trim().isEmpty) {
        throw const ApiFailure('模板预览正在准备，请稍后重试');
      }
      if (integer(result.data['template_id']) != widget.templateID ||
          (widget.version > 0 &&
              integer(result.data['version']) != widget.version)) {
        throw const ApiFailure('模板已更新，请刷新详情');
      }
      final renderer = await rootBundle.loadString(
        'assets/templates/market_renderer.js',
      );
      final preview = await rootBundle.loadString(
        'assets/templates/market_preview.js',
      );
      final fontData = await Future.wait(
        templatePreviewFontAssets.values.map(rootBundle.load),
      );
      final portrait = await rootBundle.load(
        'assets/templates/preview_portrait.png',
      );
      if (!current(request)) return;
      pending = await Directory.systemTemp.createTemp(
        'bojian-template-preview-',
      );
      for (var index = 0; index < fontData.length; index++) {
        final font = fontData[index];
        final name = templatePreviewFontAssets.keys.elementAt(index);
        await File('${pending.path}/$name').writeAsBytes(
          font.buffer.asUint8List(font.offsetInBytes, font.lengthInBytes),
        );
      }
      final file = File('${pending.path}/preview.html');
      await file.writeAsString(
        templatePreviewDocument(
          dom: result.data,
          rendererScript: renderer,
          previewScript: preview,
          author: widget.author,
          initialPage: widget.initialPage,
          showPageActions: widget.onOpenPage != null,
          photo:
              'data:image/png;base64,${base64Encode(portrait.buffer.asUint8List(portrait.offsetInBytes, portrait.lengthInBytes))}',
        ),
      );
      if (!current(request)) return;
      final web = WebViewController();
      await web.setJavaScriptMode(JavaScriptMode.unrestricted);
      await web.setBackgroundColor(background);
      await web.addJavaScriptChannel(
        'BojianPages',
        onMessageReceived: (message) {
          if (!current(request)) return;
          try {
            final data = jsonDecode(message.message) as Map;
            if (data['type'] == 'ready') {
              timeout?.cancel();
              setState(() {
                pages = integer(data['count']);
                ready = true;
              });
            } else if (data['type'] == 'page-actions') {
              updatePageActions(data['items']);
            } else if (data['type'] == 'open-page' && ready && error == null) {
              final index = data['index'];
              if (index is int && index >= 0 && index < pages) {
                widget.onOpenPage?.call(index);
              }
            } else if (data['type'] == 'error') {
              timeout?.cancel();
              setState(() => error = '模板预览暂不可用，请重试');
            }
          } catch (_) {
            setState(() => error = '模板预览数据无效，请重试');
          }
        },
      );
      await web.setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (current(request)) {
              unawaited(updateBackground());
              unawaited(updateAuthor());
              unawaited(updatePreviewMode());
            }
          },
          onNavigationRequest: (navigation) =>
              navigation.url == Uri.file(file.path).toString() ||
                  navigation.url == 'about:blank'
              ? NavigationDecision.navigate
              : NavigationDecision.prevent,
          onWebResourceError: (failure) {
            if (current(request) && failure.isForMainFrame == true) {
              timeout?.cancel();
              setState(() => error = '模板预览加载失败，请重试');
            }
          },
        ),
      );
      if (!current(request)) return;
      directory = pending;
      pending = null;
      setState(() => controller = web);
      timeout = Timer(const Duration(seconds: 30), () {
        if (current(request) && !ready) setState(() => error = '模板预览加载超时，请重试');
      });
      await web.loadFile(file.path);
    } catch (e) {
      if (current(request)) {
        timeout?.cancel();
        setState(() => error = e is ApiFailure ? e.message : '模板预览加载失败，请重试');
      }
    } finally {
      removeDirectory(pending);
    }
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      if (controller != null && error == null)
        Semantics(
          label: ready ? '$pages 页简历预览，作者水印：${widget.author}' : '简历预览',
          child: WebViewWidget(
            controller: controller!,
            gestureRecognizers: {
              Factory<OneSequenceGestureRecognizer>(
                () => EagerGestureRecognizer(),
              ),
            },
          ),
        ),
      if (ready &&
          error == null &&
          !widget.fullscreen &&
          widget.onOpenPage != null)
        LayoutBuilder(
          builder: (context, constraints) => ValueListenableBuilder(
            valueListenable: pageActions,
            builder: (context, positions, _) => Stack(
              children: [
                for (final position in positions)
                  if (position.index < pages &&
                      (position.bottom - position.top) *
                              constraints.maxHeight >=
                          50)
                    Positioned(
                      top: position.top * constraints.maxHeight + 6,
                      right: 6,
                      child: Tooltip(
                        message: '全屏查看第 ${position.index + 1} 页',
                        child: TextButton.icon(
                          key: ValueKey(
                            'preview-page-action-${position.index}',
                          ),
                          onPressed: () => openPage(position.index),
                          style: TextButton.styleFrom(
                            foregroundColor: context.colors.accent,
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.94,
                            ),
                            minimumSize: const Size(0, 44),
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            textStyle: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon: const Icon(Icons.fullscreen, size: 18),
                          label: const Text('全屏查看'),
                        ),
                      ),
                    ),
              ],
            ),
          ),
        ),
      if (!ready && error == null)
        ColoredBox(
          color: context.colors.surface,
          child: const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(strokeWidth: 2),
                SizedBox(height: 16),
                Text('正在展开模板…', style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ),
      if (error != null)
        ColoredBox(
          color: context.colors.surface,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: context.colors.muted, height: 1.6),
                  ),
                  if (widget.store.epoch == epoch)
                    TextButton(onPressed: load, child: const Text('重新加载预览')),
                ],
              ),
            ),
          ),
        ),
    ],
  );
}
