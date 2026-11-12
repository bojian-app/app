import 'network_image_cache.dart';
import 'resume_photo_image.dart';
import 'template_preview_data.dart';

import 'package:flutter/material.dart';

import 'app_icons.dart';
import 'app_store.dart';
import 'design.dart';
import 'resume_document.dart';
import 'resume_market_document.dart';
import 'resume_native_market.dart';
import 'resume_theme.dart';

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
  late var document = ResumeDocument(
    widget.resume,
    fontFamily: null,
    photoURL: widget.resume.photoURL,
    theme: widget.theme,
  );
  @override
  void didUpdateWidget(covariant StandardResumeThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    document.dispose();
    document = ResumeDocument(
      widget.resume,
      fontFamily: null,
      photoURL: widget.resume.photoURL,
      theme: widget.theme,
    );
  }

  @override
  void dispose() {
    document.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ResumeSheetImage(
    resume: widget.resume,
    document: document,
    index: 0,
    photo: widget.photo,
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
  });
  final ResumeDraft resume;
  final ResumeDocument document;
  final int index;
  final ImageProvider? photo;

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
              painter: _ThumbnailPainter(document, index, ResumeSheetLayer.ink),
            ),
          ),
        ],
      );
    },
  );
}

class _ThumbnailPainter extends CustomPainter {
  const _ThumbnailPainter(this.document, this.index, this.layer);
  final ResumeDocument document;
  final int index;
  final ResumeSheetLayer layer;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / resumePaperSize.width);
    paintResumeSheet(canvas, document, index, layer: layer);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ThumbnailPainter oldDelegate) =>
      oldDelegate.document != document ||
      oldDelegate.index != index ||
      oldDelegate.layer != layer;
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
    label: '${resume.templateTitle}预览',
    image: true,
    child: ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: ColoredBox(
          color: Colors.white,
          child: AspectRatio(
            aspectRatio: resumePaperSize.aspectRatio,
            child: resume.usesMarketTemplate
                ? IgnorePointer(
                    child: ResumeMarketDocumentView(
                      key: ValueKey(
                        '${store.epoch}:${resume.id}:${resume.marketTemplateID}',
                      ),
                      store: store,
                      resume: resume,
                      thumbnail: true,
                    ),
                  )
                : StandardResumeThumbnail(
                    resume: templateThumbnailResume,
                    photo: const AssetImage(
                      'assets/templates/preview_portrait.png',
                    ),
                  ),
          ),
        ),
      ),
    ),
  );
}

// The card's title and progress are real; its paper is always a template example.
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
  late var document = ResumeDocument(
    templateThumbnailResume,
    fontFamily: null,
    photoURL: templateThumbnailResume.photoURL,
    theme: widget.theme,
  );

  @override
  void didUpdateWidget(covariant ResumeThemeSamplePages oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.theme == widget.theme) return;
    document.dispose();
    document = ResumeDocument(
      templateThumbnailResume,
      fontFamily: null,
      photoURL: templateThumbnailResume.photoURL,
      theme: widget.theme,
    );
  }

  @override
  void dispose() {
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
