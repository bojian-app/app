import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'api/bojian_api.dart';
import 'app_store.dart';
import 'design.dart';
import 'resume_additional_fields.dart';
import 'resume_document.dart';
import 'resume_module_order.dart';
import 'resume_native_export.dart';
import 'resume_preview_color.dart';
import 'resume_theme.dart';
import 'resume_thumbnail.dart';
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
