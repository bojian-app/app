import 'package:flutter/material.dart';

import 'app_store.dart';
import 'design.dart';
import 'profile_avatar.dart';
import 'user_profile_page.dart';

/// The public location comes from the author's authenticated IP lookup.
class StoryAuthorIdentity extends StatelessWidget {
  const StoryAuthorIdentity({
    super.key,
    required this.story,
    required this.store,
    this.name,
    this.flat = false,
    this.fontWeight = FontWeight.w600,
    this.metadataTrailing,
  });

  final Story story;
  final AppStore store;
  final String? name;
  final bool flat;
  final FontWeight fontWeight;
  final Widget? metadataTrailing;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) {
      final location =
          (store.isAuthenticated && story.authorID == store.userID
                  ? store.ipLocation
                  : story.role)
              .trim()
              .replaceFirst(RegExp(r'省$'), '');
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name ?? story.author,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: flat ? 13 : 11, fontWeight: fontWeight),
          ),
          if (location.isNotEmpty || metadataTrailing != null) ...[
            const SizedBox(height: 3),
            DefaultTextStyle.merge(
              style: TextStyle(
                fontSize: flat ? 10 : 9.5,
                color: context.colors.muted,
                height: 1.25,
              ),
              child: Wrap(
                spacing: 8,
                runSpacing: 3,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (location.isNotEmpty)
                    Text(
                      'IP属地：$location',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: flat ? 10 : 9.5,
                        color: context.colors.muted,
                        height: 1.25,
                      ),
                    ),
                  ?metadataTrailing,
                ],
              ),
            ),
          ],
        ],
      );
    },
  );
}

/// Author avatar on feed cards; opens the author's profile when allowed.
class StoryAuthorAvatar extends StatelessWidget {
  const StoryAuthorAvatar({
    super.key,
    required this.story,
    required this.store,
    required this.size,
    this.flat = false,
    this.name,
    this.avatarURL,
    this.navigationEnabled = true,
  });

  final Story story;
  final AppStore store;
  final double size;
  final bool flat;
  final String? name, avatarURL;
  final bool navigationEnabled;

  @override
  Widget build(BuildContext context) {
    final canOpen =
        navigationEnabled &&
        story.authorID > 0 &&
        story.authorID != store.userID;
    return Semantics(
      button: canOpen,
      label: '${name ?? story.author}的头像',
      child: InkWell(
        key: ValueKey('story-author-avatar-${story.id}'),
        borderRadius: BorderRadius.circular(13),
        onTap: canOpen
            ? () => openPage(
                context,
                UserProfilePage(store: store, userID: story.authorID),
              )
            : null,
        child: Padding(
          // Flat cards start the avatar on the text edge.
          padding: flat
              ? const EdgeInsets.fromLTRB(0, 7, 7, 7)
              : const EdgeInsets.all(4),
          child: ProfileAvatar(
            seed: story.authorID > 0 ? '${story.authorID}' : story.author,
            url: avatarURL ?? story.authorAvatarURL,
            size: size,
          ),
        ),
      ),
    );
  }
}
