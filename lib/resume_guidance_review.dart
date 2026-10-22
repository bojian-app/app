import 'user_display_name.dart';

import 'package:flutter/material.dart';

import 'app_store.dart';
import 'app_icons.dart';
import 'design.dart';
import 'profile_avatar.dart';
import 'resume_updated_label.dart';
import 'playful_refresh.dart';

const guidanceCommentColor = Color(0xFF408C77);
const guidanceReplacementColor = Color(0xFF7964A4);
String guidanceRecordKey(Map record) =>
    '${record['legacy'] == true ? 'legacy' : 'annotation'}:${record['id']}';
String guidanceReviewerKey(Map record) {
  final id = integer(record['reviewer_id']);
  // Missing historical identity is kept separate rather than merged by nickname.
  return id > 0 ? 'user:$id' : 'unknown:${guidanceRecordKey(record)}';
}

List<Map<String, dynamic>> guidanceRecords(
  List<dynamic> annotations,
  List<dynamic> legacy,
) => [
  for (final item in annotations.whereType<Map>())
    Map<String, dynamic>.from(item),
  for (final item in legacy.whereType<Map>())
    {...Map<String, dynamic>.from(item), 'legacy': true},
];

class GuidanceParticipant {
  GuidanceParticipant(this.key, this.records);
  final String key;
  final List<Map<String, dynamic>> records;
  int get userID => integer(records.first['reviewer_id']);
  String get name {
    final value = '${records.first['reviewer_name'] ?? ''}'.trim();
    return userDisplayName(value);
  }

  String get seed => integer(records.first['reviewer_id']) > 0
      ? '${records.first['reviewer_id']}'
      : key;
  String get avatar => '${records.first['reviewer_avatar_url'] ?? ''}';
  int get comments =>
      records.where((v) => '${v['replacement'] ?? ''}'.isEmpty).length;
  int get replacements => records.length - comments;
  int get pending => records
      .where(
        (v) =>
            v['legacy'] != true &&
            '${v['replacement'] ?? ''}'.isNotEmpty &&
            (v['status'] ?? 'PENDING') == 'PENDING',
      )
      .length;
  DateTime? get updated => records
      .map(
        (v) => DateTime.tryParse('${v['created_at'] ?? v['updated_at'] ?? ''}'),
      )
      .whereType<DateTime>()
      .fold<DateTime?>(null, (a, b) => a == null || b.isAfter(a) ? b : a);
}

List<GuidanceParticipant> guidanceParticipants(
  List<Map<String, dynamic>> records,
) {
  final groups = <String, List<Map<String, dynamic>>>{};
  for (final record in records) {
    (groups[guidanceReviewerKey(record)] ??= []).add(record);
  }
  final result = groups.entries
      .map((e) => GuidanceParticipant(e.key, e.value))
      .toList();
  result.sort(
    (a, b) =>
        (b.updated ?? DateTime(1970)).compareTo(a.updated ?? DateTime(1970)),
  );
  return result;
}

class GuidanceParticipantList extends StatelessWidget {
  const GuidanceParticipantList({
    super.key,
    required this.title,
    required this.records,
    required this.onReview,
    required this.onRefresh,
    this.onOpenProfile,
  });
  final String title;
  final List<Map<String, dynamic>> records;
  final ValueChanged<GuidanceParticipant> onReview;
  final Future<void> Function() onRefresh;
  final ValueChanged<GuidanceParticipant>? onOpenProfile;
  @override
  Widget build(BuildContext context) {
    final people = guidanceParticipants(records);
    return PlayfulRefresh(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontSize: 13, color: context.colors.muted),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const Text(
                        '参与指点',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${people.length} 位',
                        style: TextStyle(
                          fontSize: 13,
                          color: context.colors.muted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (people.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 48,
                      ),
                      decoration: BoxDecoration(
                        color: context.colors.surface,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        children: [
                          AppIcon(
                            AppIcons.feedback,
                            size: 30,
                            color: context.colors.muted,
                          ),
                          SizedBox(height: 16),
                          Text(
                            '暂时还没有人参与指点',
                            style: TextStyle(
                              fontSize: 14,
                              color: context.colors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  for (final person in people)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Material(
                        color: context.colors.surface,
                        borderRadius: BorderRadius.circular(20),
                        child: InkWell(
                          key: ValueKey('guidance-participant-${person.key}'),
                          borderRadius: BorderRadius.circular(20),
                          onTap: () => onReview(person),
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    ProfileAvatar(
                                      key: ValueKey(
                                        'guidance-participant-avatar-${person.key}',
                                      ),
                                      seed: person.seed,
                                      url: person.avatar,
                                      size: 42,
                                      onTap:
                                          person.userID > 0 &&
                                              onOpenProfile != null
                                          ? () => onOpenProfile!(person)
                                          : null,
                                      semanticsLabel: '查看${person.name}的主页',
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            person.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            [
                                              if (person.comments > 0)
                                                '${person.comments} 条评论',
                                              if (person.replacements > 0)
                                                '${person.replacements} 条修改建议',
                                            ].join(' · '),
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: context.colors.muted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    AppIcon(
                                      AppIcons.forward,
                                      size: 19,
                                      color: context.colors.muted,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        person.updated == null
                                            ? '查看提交记录'
                                            : '最近提交：${resumeUpdatedLabel(person.updated!)}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: context.colors.muted,
                                        ),
                                      ),
                                    ),
                                    if (person.pending > 0)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 9,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: blue.withValues(alpha: .07),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Text(
                                          '${person.pending} 条待处理',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: context.colors.accent,
                                          ),
                                        ),
                                      )
                                    else
                                      Text(
                                        '审阅记录',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: context.colors.accent,
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class GuidanceReviewHeading extends StatelessWidget {
  const GuidanceReviewHeading({
    super.key,
    required this.participant,
    this.onOpenProfile,
  });
  final GuidanceParticipant participant;
  final VoidCallback? onOpenProfile;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
    child: Row(
      children: [
        ProfileAvatar(
          key: const ValueKey('guidance-review-avatar'),
          seed: participant.seed,
          url: participant.avatar,
          size: 28,
          onTap: participant.userID > 0 ? onOpenProfile : null,
          semanticsLabel: '查看${participant.name}的主页',
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            participant.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(width: 12),
        const _ReviewLegend(color: guidanceCommentColor, label: '评论'),
        const SizedBox(width: 12),
        const _ReviewLegend(color: guidanceReplacementColor, label: '修改建议'),
      ],
    ),
  );
}

class _ReviewLegend extends StatelessWidget {
  const _ReviewLegend({required this.color, required this.label});
  final Color color;
  final String label;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
      const SizedBox(width: 5),
      Text(label, style: TextStyle(fontSize: 10, color: context.colors.muted)),
    ],
  );
}

ResumeDraft guidanceDraftResume(
  ResumeDraft original,
  List<Map<String, dynamic>> changes,
) {
  final result = original.copy();
  final edits = <(Map, String, String, String, int)>[];
  for (final change in changes) {
    final parts = '${change['field_path']}'.split('.');
    dynamic entry = result.source;
    for (final part in parts.take(parts.length - 1)) {
      entry = entry is Map
          ? entry[part]
          : entry is List &&
                int.tryParse(part) != null &&
                int.parse(part) < entry.length
          ? entry[int.parse(part)]
          : null;
    }
    final key = parts.last;
    final old = entry is Map ? entry[key] : null;
    final selected = '${change['selected_text'] ?? ''}';
    final replacement = '${change['replacement'] ?? ''}';
    if (entry is! Map ||
        old is! String ||
        selected.isEmpty ||
        replacement.isEmpty ||
        selected.allMatches(old).length != 1) {
      throw StateError('这段内容已变化，请重新核对建议');
    }
    edits.add((entry, key, selected, replacement, old.indexOf(selected)));
  }
  for (var i = 0; i < edits.length; i++) {
    for (var j = i + 1; j < edits.length; j++) {
      final a = edits[i], b = edits[j];
      if (identical(a.$1, b.$1) &&
          a.$2 == b.$2 &&
          a.$5 < b.$5 + b.$3.length &&
          b.$5 < a.$5 + a.$3.length) {
        throw StateError('同一处有重叠建议，请选择一种修改');
      }
    }
  }
  edits.sort((a, b) => b.$5.compareTo(a.$5));
  for (final (entry, key, selected, replacement, _) in edits) {
    entry[key] = (entry[key] as String).replaceFirst(selected, replacement);
    final rich = entry['${key}_rich'];
    var applied = false;
    if (rich is Map && rich['blocks'] is List) {
      for (final block in rich['blocks'] as List) {
        final spans = block is Map ? block['spans'] : null;
        if (spans is! List) continue;
        final plain = spans
            .whereType<Map>()
            .map((s) => '${s['text'] ?? ''}')
            .join();
        final start = plain.indexOf(selected);
        if (start < 0) continue;
        final end = start + selected.length;
        var offset = 0, inserted = false;
        for (final span in spans.whereType<Map>()) {
          final text = '${span['text'] ?? ''}';
          final right = offset + text.length;
          if (right > start && offset < end) {
            final left = (start - offset).clamp(0, text.length);
            final tail = (end - offset).clamp(0, text.length);
            span['text'] =
                text.substring(0, left) +
                (inserted ? '' : replacement) +
                text.substring(tail);
            inserted = true;
          }
          offset = right;
        }
        applied = true;
        break;
      }
    }
    if (!applied) entry.remove('${key}_rich');
  }
  return result;
}
