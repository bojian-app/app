/// A post's tags are not part of its writing. The shared document carries them
/// as topic spans, which the app takes out of the text and shows on their own.
library;

bool _isTag(Object? span) =>
    span is Map &&
    span['topic'] is String &&
    (span['topic'] as String).trim().isNotEmpty;

bool _isBlank(Object? span) =>
    span is Map &&
    span['topic'] == null &&
    '${span['text'] ?? ''}'.trim().isEmpty;

/// [content] with the tags taken out of its writing, and those tags in the
/// order they appear. Tags standing at the start or the end of a text block are
/// taken out; one inside a sentence is a word of it and stays there.
({Map<String, dynamic> body, List<String> tags}) splitArticleTags(Map content) {
  final body = Map<String, dynamic>.from(content);
  final blocks = content['blocks'];
  if (blocks is! List) return (body: body, tags: const []);
  final tags = <String>{};
  final kept = [];
  for (final block in blocks) {
    final spans = block is Map ? block['spans'] : null;
    if (block is! Map || spans is! List || !spans.any(_isTag)) {
      kept.add(block);
      continue;
    }
    var start = 0, end = spans.length;
    while (start < end && (_isTag(spans[start]) || _isBlank(spans[start]))) {
      start++;
    }
    while (end > start &&
        (_isTag(spans[end - 1]) || _isBlank(spans[end - 1]))) {
      end--;
    }
    final leading = spans.take(start).where(_isTag).toList();
    final trailing = spans.skip(end).where(_isTag).toList();
    if (leading.isEmpty && trailing.isEmpty) {
      kept.add(block);
      continue;
    }
    for (final span in [...leading, ...trailing]) {
      tags.add((span as Map)['topic'] as String);
    }
    if (start == end) continue;
    final rest = [...spans.sublist(start, end)];
    // The space that set a tag apart goes with it.
    void trim(int index, String Function(String) cut) {
      final span = rest[index];
      if (span is Map && span['topic'] == null) {
        rest[index] = {...span, 'text': cut('${span['text'] ?? ''}')};
      }
    }

    if (leading.isNotEmpty) trim(0, (text) => text.trimLeft());
    if (trailing.isNotEmpty) {
      trim(rest.length - 1, (text) => text.trimRight());
    }
    kept.add({...block, 'spans': rest});
  }
  body['blocks'] = kept;
  return (body: body, tags: tags.toList());
}

/// The block a post carries [tags] in, after its writing.
Map<String, dynamic> articleTagBlock(List<String> tags) => {
  'kind': 'paragraph',
  'spans': [
    for (var i = 0; i < tags.length; i++) ...[
      if (i > 0) {'text': ' '},
      {'text': '#${tags[i]}#', 'topic': tags[i]},
    ],
  ],
};
