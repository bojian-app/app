import 'package:flutter/material.dart';

import 'app_store.dart';
import 'design.dart';

/// The public location comes from the author's authenticated IP lookup.
class StoryAuthorIdentity extends StatelessWidget {
  const StoryAuthorIdentity({
    super.key,
    required this.story,
    required this.store,
    this.name,
    this.flat = false,
    this.fontWeight = FontWeight.w600,
  });

  final Story story;
  final AppStore store;
  final String? name;
  final bool flat;
  final FontWeight fontWeight;

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
          if (location.isNotEmpty) ...[
            const SizedBox(height: 3),
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
          ],
        ],
      );
    },
  );
}
