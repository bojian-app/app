import 'package:flutter/material.dart';

import 'app_icons.dart';
import 'app_store.dart';
import 'design.dart';
import 'profile_avatar.dart';
import 'resume_guidance_view.dart';
import 'resume_updated_label.dart';
import 'story_author_identity.dart';
import 'user_profile_page.dart';

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
    final accent = context.colors.accent;
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
              ? const EdgeInsets.symmetric(horizontal: 16, vertical: 12)
              : const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  InkWell(
                    key: ValueKey('story-author-avatar-${story.id}'),
                    borderRadius: BorderRadius.circular(12),
                    onTap:
                        !authorNavigationEnabled ||
                            story.authorID <= 0 ||
                            story.authorID == store.userID
                        ? null
                        : () => openPage(
                            context,
                            UserProfilePage(
                              store: store,
                              userID: story.authorID,
                            ),
                          ),
                    child: Padding(
                      padding: EdgeInsets.all(flat ? 7 : 4),
                      child: ProfileAvatar(
                        seed: story.authorID > 0
                            ? '${story.authorID}'
                            : story.author,
                        url: authorAvatarURL ?? story.authorAvatarURL,
                        size: flat ? 30 : 26,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: StoryAuthorIdentity(
                      story: story,
                      store: store,
                      name: authorName,
                      flat: flat,
                      fontWeight: FontWeight.w500,
                      metadataTrailing: ListenableBuilder(
                        listenable: store,
                        builder: (context, _) => Text(
                          story.guidanceParticipantCount == null
                              ? '参与人数暂不可用'
                              : '已有${story.guidanceParticipantCount}人参与',
                          key: ValueKey('guidance-participants-${story.id}'),
                        ),
                      ),
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
                    fontWeight: FontWeight.w500,
                    color: context.colors.ink,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Row(
                children: [
                  AppIcon(
                    AppIcons.resume,
                    color: context.colors.muted,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      story.title,
                      key: ValueKey('guidance-resume-title-${story.id}'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: compactTypography ? 11 : 12,
                        height: 1.4,
                        color: context.colors.muted,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: flat ? 8 : 12),
              SizedBox(
                width: double.infinity,
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    if (date != null)
                      Text(
                        resumeUpdatedLabel(date),
                        style: TextStyle(
                          fontSize: 10,
                          color: context.colors.muted,
                        ),
                      ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '查看简历并指点',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: accent,
                          ),
                        ),
                        const SizedBox(width: 6),
                        AppIcon(AppIcons.arrowForward, size: 14, color: accent),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
