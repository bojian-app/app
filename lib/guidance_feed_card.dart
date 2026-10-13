import 'package:flutter/material.dart';

import 'app_icons.dart';
import 'app_store.dart';
import 'design.dart';
import 'profile_avatar.dart';
import 'resume_guidance_view.dart';
import 'resume_updated_label.dart';
import 'user_profile_page.dart';

class GuidanceFeedCard extends StatelessWidget {
  const GuidanceFeedCard({super.key, required this.story, required this.store});
  final Story story;
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF428E7B);
    final date = DateTime.tryParse(story.publishedAt);
    final question =
        (story.content['question']?.toString() ??
                story.excerpt.split('\n').first)
            .trim();
    return Material(
      key: ValueKey('guidance-card-${story.id}'),
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFE1EEE8)),
      ),
      child: InkWell(
        onTap: () =>
            openPage(context, ResumeGuidanceView(store: store, id: story.id)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  InkWell(
                    key: ValueKey('story-author-avatar-${story.id}'),
                    borderRadius: BorderRadius.circular(12),
                    onTap: story.authorID <= 0 || story.authorID == store.userID
                        ? null
                        : () => openPage(
                            context,
                            UserProfilePage(
                              store: store,
                              userID: story.authorID,
                            ),
                          ),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: ProfileAvatar(
                        seed: story.authorID > 0
                            ? '${story.authorID}'
                            : story.author,
                        url: story.authorAvatarURL,
                        size: 26,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      story.author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    '简历求指点',
                    style: TextStyle(
                      fontSize: 10,
                      color: accent,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: AppIcon(AppIcons.resume, color: accent, size: 22),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      story.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              if (question.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F8F6),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    question,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.6,
                      color: Color(0xFF667F75),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      date == null ? '' : resumeUpdatedLabel(date),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 10, color: muted),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    '查看简历并指点',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: accent,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const AppIcon(AppIcons.arrowForward, size: 14, color: accent),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
