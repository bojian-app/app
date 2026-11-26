import 'network_image_cache.dart';
import 'resume_photo_image.dart';
import 'template_preview_data.dart';

import 'dart:collection';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'app_icons.dart';
import 'app_store.dart';
import 'design.dart';
import 'resume_document.dart';
import 'resume_market_document.dart';
import 'resume_theme.dart';
import 'resume_system_fonts.dart';

// Template covers use fictional sample data rather than the saved resume content.
class MarketResumeThumbnail extends StatelessWidget {
  const MarketResumeThumbnail({super.key, required this.url});
  final String url;
  @override
  Widget build(BuildContext context) {
    final placeholder = Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(AppIcons.templates, size: 28, color: context.colors.muted),
          const SizedBox(height: 8),
          Text(
            '预览暂不可用',
            style: TextStyle(color: context.colors.muted, fontSize: 10),
          ),
        ],
      ),
    );
    return url.isEmpty
        ? placeholder
        : Image(
            image: ResizeImage(CachedNetworkImage(url), width: 720),
            gaplessPlayback: true,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => placeholder,
          );
  }
}

/// A laid-out cover page and its recorded drawing. Tabs and lists tear their
/// thumbnails down and rebuild them as the user moves around, and typesetting a
/// page costs tens of milliseconds, so thumbnails of the same content share one.
class ThumbnailSheet {
  ThumbnailSheet(this.document);
  final ResumeDocument document;
  ui.Picture? _paper, _ink;
  int _users = 0;

  ui.Picture picture(ResumeSheetLayer layer) => switch (layer) {
    ResumeSheetLayer.ink => _ink ??= _record(layer),
    _ => _paper ??= _record(ResumeSheetLayer.paper),
  };

  ui.Picture _record(ResumeSheetLayer layer) {
    final recorder = ui.PictureRecorder();
    paintResumeSheet(Canvas(recorder), document, 0, layer: layer);
    return recorder.endRecording();
  }

  /// Small covers are drawn from a snapshot rather than by replaying every
  /// glyph, which moves the first-draw cost of a page of text off the frame
  /// that first shows it.
  static const snapshotWidth = 400;
  ui.Image? _paperImage, _inkImage;

  ui.Image? snapshot(ResumeSheetLayer layer) =>
      layer == ResumeSheetLayer.ink ? _inkImage : _paperImage;

  void rasterize() {
    _paperImage ??= _snapshot(picture(ResumeSheetLayer.paper));
    _inkImage ??= _snapshot(picture(ResumeSheetLayer.ink));
  }

  ui.Image _snapshot(ui.Picture source) {
    const scale = snapshotWidth / 595.28;
    final recorder = ui.PictureRecorder();
    Canvas(recorder)
      ..scale(scale)
      ..drawPicture(source);
    final wrapper = recorder.endRecording();
    try {
      return wrapper.toImageSync(
        snapshotWidth,
        (resumePaperSize.height * scale).ceil(),
      );
    } finally {
      wrapper.dispose();
    }
  }

  void _dispose() {
    _paper?.dispose();
    _ink?.dispose();
    _paperImage?.dispose();
    _inkImage?.dispose();
    document.dispose();
  }
}

class ThumbnailSheetCache {
  static const _idleLimit = 12;
  static final _entries = LinkedHashMap<String, ThumbnailSheet>();

  /// Bumped when device fonts change, so every cover is typeset again.
  static int epoch = 0;

  static String keyFor(ResumeDraft resume, ResumeTheme? theme) =>
      '$epoch|${ResumeDocument.layoutKey(resume, photoURL: resume.photoURL, theme: theme)}';

  static ResumeDocument typeset(ResumeDraft resume, ResumeTheme? theme) =>
      ResumeDocument(
        resume,
        photoURL: resume.photoURL,
        theme: theme,
        standardCoverOnly: true,
      );

  /// Typesets and records the covers of [resumes] ahead of time, one per turn
  /// of the event loop so a loading view keeps animating meanwhile.
  static Future<void> warm(
    Iterable<ResumeDraft> resumes, {
    bool Function()? valid,
    ResumeTheme? Function(ResumeDraft resume)? themeOf,
  }) async {
    for (final resume in resumes) {
      final theme = resume.usesMarketTemplate ? themeOf?.call(resume) : null;
      if (resume.usesMarketTemplate && theme == null) continue;
      if (valid != null && !valid()) return;
      final key = keyFor(resume, theme);
      final sheet = acquire(key, () => typeset(resume, theme));
      await Future<void>.delayed(Duration.zero);
      sheet.picture(ResumeSheetLayer.paper);
      await Future<void>.delayed(Duration.zero);
      sheet.picture(ResumeSheetLayer.ink);
      await Future<void>.delayed(Duration.zero);
      sheet.rasterize();
      release(key);
      await Future<void>.delayed(Duration.zero);
    }
  }

  static ThumbnailSheet acquire(String key, ResumeDocument Function() create) {
    final sheet = _entries.remove(key) ?? ThumbnailSheet(create());
    _entries[key] = sheet; // most recently used last
    sheet._users++;
    return sheet;
  }

  static void release(String key) {
    final sheet = _entries[key];
    if (sheet == null) return;
    sheet._users--;
    final idle = [
      for (final entry in _entries.entries)
        if (entry.value._users <= 0) entry.key,
    ];
    if (idle.length <= _idleLimit) return;
    for (final old in idle.take(idle.length - _idleLimit)) {
      _entries.remove(old)!._dispose();
    }
  }

  static void invalidate() {
    epoch++;
    final idle = [
      for (final entry in _entries.entries)
        if (entry.value._users <= 0) entry.key,
    ];
    for (final key in idle) {
      _entries.remove(key)!._dispose();
    }
  }
}

class StandardResumeThumbnail extends StatefulWidget {
  const StandardResumeThumbnail({
    super.key,
    required this.resume,
    this.photo,
    this.theme,
  });
  final ResumeDraft resume;
  final ImageProvider? photo;
  final ResumeTheme? theme;
  @override
  State<StandardResumeThumbnail> createState() =>
      _StandardResumeThumbnailState();
}

class _StandardResumeThumbnailState extends State<StandardResumeThumbnail> {
  late final ResumeSystemFontObserver systemFonts;
  late String layoutKey, sheetKey;
  late int sheetEpoch;
  late ThumbnailSheet sheet;

  String get currentLayoutKey => ResumeDocument.layoutKey(
    widget.resume,
    photoURL: widget.resume.photoURL,
    theme: widget.theme,
  );

  ResumeDocument createDocument() =>
      ThumbnailSheetCache.typeset(widget.resume, widget.theme);

  void acquire() {
    layoutKey = currentLayoutKey;
    sheetEpoch = ThumbnailSheetCache.epoch;
    sheetKey = ThumbnailSheetCache.keyFor(widget.resume, widget.theme);
    sheet = ThumbnailSheetCache.acquire(sheetKey, createDocument);
  }

  @override
  void initState() {
    super.initState();
    acquire();
    systemFonts = ResumeSystemFontObserver(fontsChanged);
  }

  void fontsChanged() {
    // The first thumbnail to notice retires the shared covers for all.
    if (sheetEpoch == ThumbnailSheetCache.epoch)
      ThumbnailSheetCache.invalidate();
    setState(rebuildDocument);
  }

  @override
  void didUpdateWidget(covariant StandardResumeThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (currentLayoutKey == layoutKey) return;
    rebuildDocument();
  }

  void rebuildDocument() {
    ThumbnailSheetCache.release(sheetKey);
    acquire();
  }

  @override
  void dispose() {
    systemFonts.dispose();
    ThumbnailSheetCache.release(sheetKey);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ResumeSheetImage(
    resume: widget.resume,
    document: sheet.document,
    index: 0,
    photo: widget.photo,
    sheet: sheet,
  );
}

/// One laid-out page with its photo, for read-only previews.
class ResumeSheetImage extends StatelessWidget {
  const ResumeSheetImage({
    super.key,
    required this.resume,
    required this.document,
    required this.index,
    this.photo,
    this.sheet,
  });
  final ResumeDraft resume;
  final ResumeDocument document;
  final int index;
  final ImageProvider? photo;

  /// Replays a recorded drawing of the page instead of painting it each time.
  final ThumbnailSheet? sheet;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final rect = document.pages[index].photo;
      final scale = constraints.maxWidth / resumePaperSize.width;
      return Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _ThumbnailPainter(
                document,
                index,
                ResumeSheetLayer.paper,
                sheet,
              ),
            ),
          ),
          if (rect != null && resume.photoURL.isNotEmpty)
            Positioned(
              left: rect.left * scale,
              top: rect.top * scale,
              width: rect.width * scale,
              height: rect.height * scale,
              child: ClipPath(
                clipper: ResumePhotoClipper(document.theme, scale),
                child: Image(
                  image:
                      photo ??
                      ResizeImage(
                        ResumePhotoImage(
                          resume.photoURL,
                          fileID: resume.photoFileID,
                        ),
                        width: 240,
                      ),
                  fit: BoxFit.cover,
                  alignment: const Alignment(0, -.35),
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ),
          Positioned.fill(
            child: CustomPaint(
              painter: _ThumbnailPainter(
                document,
                index,
                ResumeSheetLayer.ink,
                sheet,
              ),
            ),
          ),
        ],
      );
    },
  );
}

class _ThumbnailPainter extends CustomPainter {
  const _ThumbnailPainter(this.document, this.index, this.layer, this.sheet);
  final ResumeDocument document;
  final int index;
  final ResumeSheetLayer layer;
  final ThumbnailSheet? sheet;
  @override
  void paint(Canvas canvas, Size size) {
    final recorded = sheet;
    final snapshot = index == 0 && size.width <= 160
        ? recorded?.snapshot(layer)
        : null;
    if (snapshot != null) {
      canvas.drawImageRect(
        snapshot,
        Rect.fromLTWH(
          0,
          0,
          snapshot.width.toDouble(),
          snapshot.height.toDouble(),
        ),
        Offset.zero & size,
        Paint()..filterQuality = FilterQuality.medium,
      );
      return;
    }
    canvas.save();
    canvas.scale(size.width / resumePaperSize.width);
    if (recorded != null && index == 0) {
      canvas.drawPicture(recorded.picture(layer));
    } else {
      paintResumeSheet(canvas, document, index, layer: layer);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ThumbnailPainter oldDelegate) =>
      oldDelegate.document != document ||
      oldDelegate.index != index ||
      oldDelegate.layer != layer ||
      oldDelegate.sheet != sheet;
}

class ResumeCardThumbnail extends StatelessWidget {
  const ResumeCardThumbnail({
    super.key,
    required this.store,
    required this.resume,
  });
  final AppStore store;
  final ResumeDraft resume;
  @override
  Widget build(BuildContext context) => Semantics(
    label: '${resume.title}预览',
    image: true,
    child: ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: ColoredBox(
          color: Colors.white,
          child: AspectRatio(
            aspectRatio: resumePaperSize.aspectRatio,
            child: resume.usesMarketTemplate
                ? switch (MarketThemeCache.get(
                    store,
                    resume.marketTemplateID,
                  )) {
                    // A theme package is typeset like every other cover, so a
                    // known one needs no loading at all.
                    final ResumeTheme theme => StandardResumeThumbnail(
                      resume: resume,
                      theme: theme,
                    ),
                    _ => IgnorePointer(
                      child: ResumeMarketDocumentView(
                        key: ValueKey(
                          '${store.epoch}:${resume.id}:${resume.marketTemplateID}',
                        ),
                        store: store,
                        resume: resume,
                        thumbnail: true,
                      ),
                    ),
                  }
                : StandardResumeThumbnail(resume: resume),
          ),
        ),
      ),
    ),
  );
}

// Sample content for previews in the template catalogue.
final templateThumbnailResume = decodeResume({
  'id': 0,
  'title': '模板示例',
  'photo_url': 'asset:preview_portrait',
  'content': {
    'personal_info': {
      'full_name': templatePreviewFields['name'],
      'phone': templatePreviewFields['phone'],
      'email': templatePreviewFields['email'],
    },
    'job_expectation': {
      for (final key in [
        'position',
        'city',
        'industry',
        'salary',
        'preference',
      ])
        key: templatePreviewFields[key],
    },
    'educations': _sampleEntries('educations', {
      'institution': 'title',
      'degree': 'subtitle',
      'field_of_study': 'auxiliary',
      'campus_experience': 'detail',
      'thesis_description': 'secondary_detail',
    }),
    'work_experiences': _sampleEntries('work_experiences', {
      'company': 'title',
      'position': 'subtitle',
      'industry': 'auxiliary',
      'description': 'detail',
    }),
    'projects': _sampleEntries('projects', {
      'name': 'title',
      'role': 'subtitle',
      'description': 'detail',
      'achievements': 'secondary_detail',
    }),
    'skills': [
      for (final row in templatePreviewFields['skills'] as List)
        {'name': row['name'], 'description': row['detail']},
    ],
    'certifications': [
      for (final row in templatePreviewFields['certifications'] as List)
        {
          'name': row['title'],
          'issuer': row['subtitle'],
          'date': row['start_date'],
        },
    ],
  },
});

List<Map<String, dynamic>> _sampleEntries(
  String key,
  Map<String, String> fields,
) => [
  for (final row in templatePreviewFields[key] as List)
    {
      for (final entry in fields.entries) entry.key: row[entry.value],
      'start_date': row['start_date'],
      'end_date': row['end_date'],
    },
];

/// Market preview of a theme package, typeset with the template sample.
class ResumeThemeSamplePages extends StatefulWidget {
  const ResumeThemeSamplePages({
    super.key,
    required this.theme,
    this.watermark,
    this.header,
  });
  final ResumeTheme theme;
  final String? watermark;
  final Widget? header;
  @override
  State<ResumeThemeSamplePages> createState() => _ResumeThemeSamplePagesState();
}

class _ResumeThemeSamplePagesState extends State<ResumeThemeSamplePages> {
  late final ResumeSystemFontObserver systemFonts;
  late var document = ResumeDocument(
    templateThumbnailResume,
    photoURL: templateThumbnailResume.photoURL,
    theme: widget.theme,
  );

  @override
  void initState() {
    super.initState();
    systemFonts = ResumeSystemFontObserver(() => setState(rebuildDocument));
  }

  @override
  void didUpdateWidget(covariant ResumeThemeSamplePages oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.theme == widget.theme) return;
    rebuildDocument();
  }

  void rebuildDocument() {
    document.dispose();
    document = ResumeDocument(
      templateThumbnailResume,
      photoURL: templateThumbnailResume.photoURL,
      theme: widget.theme,
    );
  }

  @override
  void dispose() {
    systemFonts.dispose();
    document.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListView(
    key: ObjectKey(document),
    padding: const EdgeInsets.only(bottom: 16),
    children: [
      ?widget.header,
      for (var index = 0; index < document.pages.length; index++)
        Padding(
          padding: EdgeInsets.only(top: index == 0 ? 0 : 12),
          child: DecoratedBox(
            // Paper on a white page needs an edge to read as paper.
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1C2A44).withValues(alpha: .08),
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: AspectRatio(
              aspectRatio: resumePaperSize.aspectRatio,
              child: CustomPaint(
                foregroundPainter: switch (widget.watermark) {
                  final String text => _WatermarkPainter(text),
                  null => null,
                },
                child: ResumeSheetImage(
                  resume: templateThumbnailResume,
                  document: document,
                  index: index,
                  photo: const AssetImage(
                    'assets/templates/preview_portrait.png',
                  ),
                ),
              ),
            ),
          ),
        ),
    ],
  );
}

/// Tiles [text] diagonally across a page of [page] points.
void paintPreviewWatermark(Canvas canvas, Size page, String text) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w500,
        color: Color(0x24334155),
      ),
    ),
    textDirection: TextDirection.ltr,
    maxLines: 1,
    ellipsis: '…',
  )..layout(maxWidth: 230);
  for (double y = 90; y < page.height + 180; y += 180) {
    for (double x = 130; x < page.width + 260; x += 260) {
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(-0.4487989505);
      painter.paint(canvas, Offset(-painter.width / 2, -painter.height / 2));
      canvas.restore();
    }
  }
  painter.dispose();
}

class _WatermarkPainter extends CustomPainter {
  _WatermarkPainter(this.text);
  final String text;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.scale(size.width / resumePaperSize.width);
    paintPreviewWatermark(canvas, resumePaperSize, text);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_WatermarkPainter old) => old.text != text;
}
