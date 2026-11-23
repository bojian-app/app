import 'package:flutter/material.dart';

import 'app_store.dart';
import 'design.dart';
import 'resume_guidance_view.dart';
import 'resume_updated_label.dart';
import 'story_author_identity.dart';

class GuidanceFeedCard extends StatelessWidget {
  const GuidanceFeedCard({
    super.key,
    required this.story,
    required this.store,
    this.flat = false,
    this.compactTypography = false,
    this.authorName,
    this.authorAvatarURL,
    this.authorNavigationEnabled = true,
  });
  final Story story;
  final AppStore store;
  final bool flat;
  final bool compactTypography;
  final String? authorName, authorAvatarURL;
  final bool authorNavigationEnabled;

  @override
  Widget build(BuildContext context) {
    final date = DateTime.tryParse(story.publishedAt);
    final question =
        (story.content['question']?.toString() ??
                story.excerpt.split('\n').first)
            .trim();
    return Material(
      key: ValueKey('guidance-card-${story.id}'),
      color: context.colors.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(flat ? 0 : 20),
        side: flat ? BorderSide.none : BorderSide(color: context.colors.border),
      ),
      child: InkWell(
        onTap: () async {
          final epoch = store.epoch;
          await openPage(
            context,
            ResumeGuidanceView(store: store, id: story.id),
          );
          if (context.mounted && store.epoch == epoch) {
            await store.refreshGuidanceParticipants(story);
          }
        },
        child: Padding(
          padding: flat
              ? const EdgeInsets.symmetric(
                  horizontal: feedContentPadding,
                  vertical: 12,
                )
              : const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  StoryAuthorAvatar(
                    story: story,
                    store: store,
                    size: flat ? 30 : 26,
                    flat: flat,
                    name: authorName,
                    avatarURL: authorAvatarURL,
                    navigationEnabled: authorNavigationEnabled,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: StoryAuthorIdentity(
                      story: story,
                      store: store,
                      name: authorName,
                      flat: flat,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              SizedBox(height: flat ? 8 : 14),
              if (question.isNotEmpty) ...[
                Text(
                  question,
                  key: ValueKey('guidance-question-${story.id}'),
                  maxLines: flat ? 2 : 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: compactTypography ? 14 : (flat ? 16 : 15),
                    height: 1.45,
                    fontWeight: feedTitleWeight,
                    color: context.colors.ink,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              _SharedResumeAttachment(
                story: story,
                store: store,
                compact: compactTypography,
              ),
              if (date != null) ...[
                const SizedBox(height: 8),
                Text(
                  resumeUpdatedLabel(date),
                  style: TextStyle(fontSize: 10, color: context.colors.muted),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SharedResumeAttachment extends StatelessWidget {
  const _SharedResumeAttachment({
    required this.story,
    required this.store,
    required this.compact,
  });

  final Story story;
  final AppStore store;
  final bool compact;

  @override
  Widget build(BuildContext context) => Container(
    width: 264,
    padding: const EdgeInsets.fromLTRB(12, 12, 12, 9),
    decoration: BoxDecoration(
      color: context.colors.inset,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    story.title.trim().isEmpty ? '分享的简历' : story.title,
                    key: ValueKey('guidance-resume-title-${story.id}'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: compact ? 13 : 14,
                      fontWeight: FontWeight.w600,
                      color: context.colors.ink,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ListenableBuilder(
                    listenable: store,
                    builder: (context, _) => Text(
                      story.guidanceParticipantCount == null
                          ? '参与人数暂不可用'
                          : '已有${story.guidanceParticipantCount}人参与',
                      key: ValueKey('guidance-participants-${story.id}'),
                      style: TextStyle(
                        fontSize: 11,
                        color: context.colors.muted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            const ExcludeSemantics(
              child: CustomPaint(
                painter: _ResumeFilePainter(),
                child: SizedBox(
                  width: 32,
                  height: 40,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(3, 12, 3, 2),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '简历',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Image.asset(
              'assets/branding/app_icon.png',
              width: 13,
              height: 13,
              cacheWidth: 52,
              excludeFromSemantics: true,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                '博简',
                style: TextStyle(fontSize: 10, color: context.colors.muted),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _ResumeFilePainter extends CustomPainter {
  const _ResumeFilePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final page = Path()
      ..moveTo(3, 0)
      ..lineTo(w - 10, 0)
      ..lineTo(w, 10)
      ..lineTo(w, h - 3)
      ..quadraticBezierTo(w, h, w - 3, h)
      ..lineTo(3, h)
      ..quadraticBezierTo(0, h, 0, h - 3)
      ..lineTo(0, 3)
      ..quadraticBezierTo(0, 0, 3, 0)
      ..close();
    canvas.drawPath(page, Paint()..color = const Color(0xFFDC4A4A));
    final fold = Path()
      ..moveTo(w - 10, 0)
      ..lineTo(w, 10)
      ..lineTo(w - 8, 10)
      ..quadraticBezierTo(w - 10, 10, w - 10, 8)
      ..close();
    canvas.drawPath(fold, Paint()..color = const Color(0xFFAC3338));
  }

  @override
  bool shouldRepaint(_ResumeFilePainter oldDelegate) => false;
}
