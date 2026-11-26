import 'package:flutter/material.dart';

import 'design.dart';

class ArticlePrivacy {
  const ArticlePrivacy({
    this.visibility = 'PUBLIC',
    this.followedRepliesOnly = false,
  });

  factory ArticlePrivacy.fromDraft(Map? draft) {
    final content = draft?['content'];
    final visibility = draft?['visibility'];
    return ArticlePrivacy(
      visibility: visibility == 'PRIVATE' || visibility == 'FRIENDS'
          ? visibility as String
          : 'PUBLIC',
      followedRepliesOnly:
          draft?['followed_replies_only'] == true ||
          content is Map && content['followed_replies_only'] == true,
    );
  }

  final String visibility;
  final bool followedRepliesOnly;

  @override
  bool operator ==(Object other) =>
      other is ArticlePrivacy &&
      visibility == other.visibility &&
      followedRepliesOnly == other.followedRepliesOnly;

  @override
  int get hashCode => Object.hash(visibility, followedRepliesOnly);
}

Future<ArticlePrivacy?> editArticlePrivacy(
  BuildContext context,
  ArticlePrivacy initial,
) {
  var visibility = initial.visibility;
  var followed = initial.followedRepliesOnly;
  return showModalBottomSheet<ArticlePrivacy>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: context.colors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
    ),
    clipBehavior: Clip.antiAlias,
    builder: (context) => StatefulBuilder(
      builder: (context, update) => SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              for (final option in [
                ('PUBLIC', '公开'),
                if (initial.visibility == 'FRIENDS') ('FRIENDS', '好友可见'),
                ('PRIVATE', '私密'),
              ])
                Semantics(
                  selected: visibility == option.$1,
                  inMutuallyExclusiveGroup: true,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 32),
                    minLeadingWidth: 20,
                    leading: Icon(
                      visibility == option.$1
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      size: 20,
                      color: visibility == option.$1
                          ? context.colors.accent
                          : context.colors.muted,
                    ),
                    title: Text(option.$2),
                    onTap: () => update(() => visibility = option.$1),
                  ),
                ),
              const Divider(indent: 32, endIndent: 32, height: 1),
              SwitchListTile.adaptive(
                contentPadding: const EdgeInsets.symmetric(horizontal: 32),
                title: const Text('仅我关注的可回复'),
                value: followed,
                onChanged: (value) => update(() => followed = value),
              ),
              const SizedBox(height: 22),
              const Divider(height: 1),
              TextButton(
                style: TextButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                  foregroundColor: context.colors.ink,
                ),
                onPressed: () => Navigator.of(context).pop(
                  ArticlePrivacy(
                    visibility: visibility,
                    followedRepliesOnly: followed,
                  ),
                ),
                child: const Text('确定'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
