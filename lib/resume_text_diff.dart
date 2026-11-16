import 'dart:typed_data';

enum TextDiffKind { equal, insert, delete }

class TextDiffSegment {
  const TextDiffSegment(this.kind, this.text);
  final TextDiffKind kind;
  final String text;
}

/// A word-aware comparison between two versions of a resume paragraph.
///
/// CJK characters are compared one by one, while Latin words and numbers are
/// kept whole so that "Vue" or "2024" never highlight half a token.
class TextDiff {
  const TextDiff._(this.segments, this.similarity);

  final List<TextDiffSegment> segments;

  /// Share of tokens kept from the original, between 0 and 1.
  final double similarity;

  /// Whether highlighting helps reading; a near-total rewrite reads better as
  /// two plain paragraphs than as a wall of marks.
  bool get readable => similarity >= .3;

  static final _token = RegExp(r'[A-Za-z0-9_.+#%-]+|\s+|.', unicode: true);
  static const _maxCells = 1200000;
  static const _gap = 3;

  static TextDiff? compare(String before, String after) {
    final a = _tokens(before), b = _tokens(after);
    if (a.isEmpty && b.isEmpty) return const TextDiff._([], 1);
    var start = 0;
    while (start < a.length && start < b.length && a[start] == b[start]) {
      start++;
    }
    var endA = a.length, endB = b.length;
    while (endA > start && endB > start && a[endA - 1] == b[endB - 1]) {
      endA--;
      endB--;
    }
    final n = endA - start, m = endB - start;
    if (n * m > _maxCells) return null;
    // Longest common subsequence over the differing middle.
    final width = m + 1;
    final table = Uint32List((n + 1) * width);
    for (var i = n - 1; i >= 0; i--) {
      for (var j = m - 1; j >= 0; j--) {
        table[i * width + j] = a[start + i] == b[start + j]
            ? table[(i + 1) * width + j + 1] + 1
            : _max(table[(i + 1) * width + j], table[i * width + j + 1]);
      }
    }
    final out = <TextDiffSegment>[];
    void add(TextDiffKind kind, String text) {
      if (text.isEmpty) return;
      if (out.isNotEmpty && out.last.kind == kind) {
        out[out.length - 1] = TextDiffSegment(kind, out.last.text + text);
      } else {
        out.add(TextDiffSegment(kind, text));
      }
    }

    add(TextDiffKind.equal, a.sublist(0, start).join());
    var i = 0, j = 0;
    while (i < n && j < m) {
      if (a[start + i] == b[start + j]) {
        add(TextDiffKind.equal, a[start + i]);
        i++;
        j++;
      } else if (table[(i + 1) * width + j] >= table[i * width + j + 1]) {
        add(TextDiffKind.delete, a[start + i]);
        i++;
      } else {
        add(TextDiffKind.insert, b[start + j]);
        j++;
      }
    }
    for (; i < n; i++) {
      add(TextDiffKind.delete, a[start + i]);
    }
    for (; j < m; j++) {
      add(TextDiffKind.insert, b[start + j]);
    }
    add(TextDiffKind.equal, a.sublist(endA).join());
    final kept = start + (a.length - endA) + (n == 0 || m == 0 ? 0 : table[0]);
    final total = a.length > b.length ? a.length : b.length;
    return TextDiff._(_absorbNoise(out), total == 0 ? 1 : kept / total);
  }

  static List<String> _tokens(String value) =>
      _token.allMatches(value).map((m) => m[0]!).toList();

  static int _max(int a, int b) => a > b ? a : b;

  /// A few shared characters between two edits ("负责A的B" vs "主导C的D")
  /// are noise; fold them into the surrounding change so marks read as one
  /// phrase instead of scattered single characters.
  static List<TextDiffSegment> _absorbNoise(List<TextDiffSegment> input) {
    final out = <TextDiffSegment>[];
    for (var k = 0; k < input.length; k++) {
      final s = input[k];
      final changedAround =
          k > 0 &&
          k < input.length - 1 &&
          input[k - 1].kind != TextDiffKind.equal &&
          input[k + 1].kind != TextDiffKind.equal;
      if (s.kind == TextDiffKind.equal &&
          changedAround &&
          !s.text.contains('\n') &&
          s.text.trim().runes.length <= _gap) {
        out
          ..add(TextDiffSegment(TextDiffKind.delete, s.text))
          ..add(TextDiffSegment(TextDiffKind.insert, s.text));
      } else {
        out.add(s);
      }
    }
    // Merge again so deletes and inserts are grouped per edit.
    final merged = <TextDiffSegment>[];
    for (final s in out) {
      if (merged.isNotEmpty && merged.last.kind == s.kind) {
        merged[merged.length - 1] = TextDiffSegment(
          s.kind,
          merged.last.text + s.text,
        );
      } else {
        merged.add(s);
      }
    }
    return merged;
  }

  /// Segments of the revised text only (equal + inserted).
  Iterable<TextDiffSegment> get revised =>
      segments.where((s) => s.kind != TextDiffKind.delete);

  /// Segments of the original text only (equal + deleted).
  Iterable<TextDiffSegment> get original =>
      segments.where((s) => s.kind != TextDiffKind.insert);
}
