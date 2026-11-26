import 'package:flutter/material.dart';

import 'dart:async';
import 'dart:typed_data';

import 'api/bojian_api.dart';
import 'app_store.dart';
import 'design.dart';
import 'resume_document.dart';
import 'resume_native_export.dart';
import 'resume_preview_color.dart';
import 'resume_theme.dart';
import 'resume_thumbnail.dart';
import 'template_preview_cache.dart';

/// Themes already decoded for a template, so covers of resumes that use one
/// can be set at once instead of loading the template again.
class MarketThemeCache {
  static final _themes = <String, ResumeTheme>{};
  static String _key(AppStore store, int templateID) =>
      '${store.epoch}:$templateID';
  static ResumeTheme? get(AppStore store, int templateID) =>
      _themes[_key(store, templateID)];
  static void put(AppStore store, int templateID, ResumeTheme theme) =>
      _themes[_key(store, templateID)] = theme;

  static final _loading = <String, Future<ResumeTheme?>>{};

  /// Loads the theme package of a template resume ahead of its thumbnail, so
  /// the cover can be typeset before the page that shows it. Null on failure.
  static Future<ResumeTheme?> fetch(AppStore store, ResumeDraft resume) {
    final id = resume.marketTemplateID, key = _key(store, id);
    final epoch = store.epoch;
    final known = _themes[key];
    if (known != null) return Future.value(known);
    return _loading[key] ??= () async {
      try {
        final dom = await loadResumeTemplateDOM(store, resume.id, id);
        final schema = dom.data['schema'];
        if (integer(dom.data['template_id']) != id ||
            !isResumeThemeSchema(schema)) {
          return null;
        }
        final theme = await resumeThemeOf(id, schema as Map);
        if (store.epoch == epoch) put(store, id, theme);
        return theme;
      } catch (_) {
        return null;
      } finally {
        unawaited(_loading.remove(key));
      }
    }();
  }
}

/// How many template-resume thumbnails are still loading, so a page can wait
/// for them before it is shown.
class MarketThumbnailLoads {
  static int pending = 0;
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

/// Template resumes are theme packages (`bojian-theme-v1`) typeset by the
/// built-in [ResumeDocumentView]; there is no web/HTML rendering path.
class ResumeMarketDocumentViewState extends State<ResumeMarketDocumentView> {
  ResumeTheme? theme;
  final themeDocumentKey = GlobalKey<ResumeDocumentViewState>();
  bool ready = false;
  String? error;
  int operation = 0;
  Timer? loadTimeout;
  Color background = AppColors.light.canvas;
  bool counted = false;

  void trackLoading(bool loading) {
    if (!widget.thumbnail || loading == counted) return;
    counted = loading;
    MarketThumbnailLoads.pending += loading ? 1 : -1;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    background = widget.thumbnail ? Colors.white : context.colors.canvas;
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void didUpdateWidget(ResumeMarketDocumentView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.resume.id != widget.resume.id ||
        oldWidget.resume.revision != widget.resume.revision ||
        oldWidget.thumbnail != widget.thumbnail ||
        oldWidget.resume.marketTemplateID != widget.resume.marketTemplateID) {
      load();
    }
  }

  @override
  void dispose() {
    trackLoading(false);
    operation++;
    loadTimeout?.cancel();
    super.dispose();
  }

  Future<void> load() async {
    final request = ++operation, epoch = widget.store.epoch;
    final resume = widget.resume.copy();
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
      final schema = dom.data['schema'];
      if (!isResumeThemeSchema(schema)) {
        throw const ApiFailure('模板版面暂不可用');
      }
      final value = await resumeThemeOf(resume.marketTemplateID, schema as Map);
      if (!mounted || request != operation || epoch != widget.store.epoch) {
        return;
      }
      MarketThemeCache.put(widget.store, resume.marketTemplateID, value);
      setState(() {
        theme = value;
        ready = true;
      });
      loadTimeout?.cancel();
    } catch (e) {
      if (mounted && request == operation && epoch == widget.store.epoch) {
        loadTimeout?.cancel();
        setState(() => error = e is ApiFailure ? e.message : '模板版面加载失败，请重试');
      }
    }
  }

  Future<ResumeExportLayout> captureLayout({
    required bool Function() isCancelled,
    required ValueChanged<String> onProgress,
  }) async {
    final view = themeDocumentKey.currentState;
    if (theme == null || !ready || view == null) {
      throw const ApiFailure('请等待预览加载完成');
    }
    return view.captureLayout(isCancelled: isCancelled, onProgress: onProgress);
  }

  Future<List<Uint8List>> capturePages({
    required bool Function() isCancelled,
    required ValueChanged<String> onProgress,
  }) async {
    final view = themeDocumentKey.currentState;
    if (theme == null || !ready || error != null || view == null) {
      throw const ApiFailure('请等待模板预览加载完成');
    }
    return view.capturePages(isCancelled: isCancelled, onProgress: onProgress);
  }

  @override
  Widget build(BuildContext context) {
    trackLoading(!ready && error == null);
    return _buildStack(context);
  }

  Widget _buildStack(BuildContext context) => Stack(
    children: [
      if (theme case final ResumeTheme theme when error == null)
        Positioned.fill(
          child: widget.thumbnail
              ? StandardResumeThumbnail(resume: widget.resume, theme: theme)
              : ResumePreviewColor(
                  monochrome: widget.monochrome,
                  child: ResumeDocumentView(
                    key: themeDocumentKey,
                    resume: widget.resume,
                    store: widget.store,
                    theme: theme,
                  ),
                ),
        ),
      Positioned.fill(
        child: LoadingGate(
          loading: !ready && error == null,
          loader: ColoredBox(
            color: background,
            child: widget.thumbnail ? null : const DotMatrixLoader(),
          ),
          builder: (_) => const SizedBox.shrink(),
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
