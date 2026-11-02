import 'resume_photo_image.dart';
import 'template_preview_data.dart';

import 'package:flutter/material.dart';

import 'app_icons.dart';
import 'app_store.dart';
import 'design.dart';
import 'resume_document.dart';
import 'resume_market_document.dart';

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
        : Image.network(
            url,
            cacheWidth: 720,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => placeholder,
          );
  }
}

class StandardResumeThumbnail extends StatefulWidget {
  const StandardResumeThumbnail({super.key, required this.resume, this.photo});
  final ResumeDraft resume;
  final ImageProvider? photo;
  @override
  State<StandardResumeThumbnail> createState() =>
      _StandardResumeThumbnailState();
}

class _StandardResumeThumbnailState extends State<StandardResumeThumbnail> {
  late var document = ResumeDocument(
    widget.resume,
    fontFamily: null,
    photoURL: widget.resume.photoURL,
  );
  @override
  void didUpdateWidget(covariant StandardResumeThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    document.dispose();
    document = ResumeDocument(
      widget.resume,
      fontFamily: null,
      photoURL: widget.resume.photoURL,
    );
  }

  @override
  void dispose() {
    document.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final rect = document.pages.first.photo;
      final scale = constraints.maxWidth / resumePaperSize.width;
      return Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _ThumbnailPainter(document)),
          ),
          if (rect != null && widget.resume.photoURL.isNotEmpty)
            Positioned(
              left: rect.left * scale,
              top: rect.top * scale,
              width: rect.width * scale,
              height: rect.height * scale,
              child: Image(
                image:
                    widget.photo ??
                    ResizeImage(
                      ResumePhotoImage(
                        widget.resume.photoURL,
                        fileID: widget.resume.photoFileID,
                      ),
                      width: 240,
                    ),
                fit: BoxFit.cover,
                alignment: const Alignment(0, -.35),
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
        ],
      );
    },
  );
}

class _ThumbnailPainter extends CustomPainter {
  const _ThumbnailPainter(this.document);
  final ResumeDocument document;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / resumePaperSize.width);
    paintResumeSheet(canvas, document, 0);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ThumbnailPainter oldDelegate) =>
      oldDelegate.document != document;
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
                    resume: _defaultThumbnailResume,
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
final _defaultThumbnailResume = decodeResume({
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
