import 'package:flutter/material.dart';

import 'design.dart';

/// One line of a [showContentsSheet]; [indent] sets a lower heading in.
typedef ContentsEntry<T> = ({Key key, T value, String title, double indent});

/// The table of contents sheet the legal documents and posts share. Completes
/// with the picked entry's value, or null when dismissed.
Future<T?> showContentsSheet<T>(
  BuildContext context, {
  required String title,
  required List<ContentsEntry<T>> entries,
  Key? listKey,
}) => showModalBottomSheet<T>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: context.colors.surface,
  showDragHandle: true,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
  ),
  builder: (context) => SafeArea(
    top: false,
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * .62,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              appPageHorizontalPadding,
              0,
              appPageHorizontalPadding,
              12,
            ),
            child: Text(
              title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            child: ListView.separated(
              key: listKey,
              padding: const EdgeInsets.fromLTRB(
                appPageHorizontalPadding,
                0,
                appPageHorizontalPadding,
                16,
              ),
              itemCount: entries.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final entry = entries[index];
                return TextButton(
                  key: entry.key,
                  onPressed: () => Navigator.of(context).pop(entry.value),
                  style: TextButton.styleFrom(
                    foregroundColor: context.colors.ink,
                    alignment: Alignment.centerLeft,
                    minimumSize: const Size.fromHeight(52),
                    padding: EdgeInsets.fromLTRB(entry.indent, 14, 0, 14),
                    overlayColor: Colors.transparent,
                  ).withoutHover(),
                  child: Text(
                    entry.title,
                    style: const TextStyle(fontSize: 14, height: 1.5),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ),
  ),
);
