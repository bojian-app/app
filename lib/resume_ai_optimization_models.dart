import 'resume_text_diff.dart';

/// One rewrite the AI proposes for a single resume field.
class PolishChange {
  PolishChange({
    required this.path,
    required this.before,
    required this.after,
    required this.reason,
  });
  factory PolishChange.from(Map value) => PolishChange(
    path: '${value['path'] ?? ''}',
    before: '${value['before'] ?? ''}',
    after: '${value['after'] ?? ''}',
    reason: '${value['reason'] ?? ''}'.trim(),
  );
  final String path, before, after, reason;
  late final TextDiff? diff = TextDiff.compare(before, after);

  /// Facts the AI left for the user, as "【待补充：hint】"; the server only
  /// accepts this change with every one of them replaced.
  static final _placeholder = RegExp(r'【待补充[：:]([^【】\n]{1,40})】');
  late final List<String> placeholders = [
    for (final m in _placeholder.allMatches(after)) m.group(1)!.trim(),
  ];

  /// [after] with each placeholder replaced by the matching entry of [values].
  String fill(List<String> values) {
    var i = 0;
    return after.replaceAllMapped(_placeholder, (_) => values[i++].trim());
  }

  /// The same suggestion showing the user's filled text, for display.
  PolishChange filled(String text) =>
      PolishChange(path: path, before: before, after: text, reason: reason);

  /// "原 420 字 → 180 字" when the rewrite clearly changes the length, so a
  /// trim reads as a trim even though deleted text is hidden by default.
  String? get lengthNote {
    final a = _count(before), b = _count(after);
    if (a == 0 || (a - b).abs() < a * .15) return null;
    return '原 $a 字 → $b 字';
  }

  static int _count(String text) =>
      text.replaceAll(RegExp(r'[\s•·]'), '').runes.length;
}

/// A gap the AI could not fix without more facts from the user.
class PolishIssue {
  const PolishIssue({
    required this.path,
    required this.type,
    required this.message,
    required this.question,
  });
  factory PolishIssue.from(Map value) => PolishIssue(
    path: '${value['path'] ?? ''}',
    type: '${value['type'] ?? ''}',
    message: '${value['message'] ?? ''}'.trim(),
    question: '${value['question'] ?? ''}'.trim(),
  );
  final String path, type, message, question;
  String get typeLabel => switch (type) {
    'consistency' => '需核对',
    'structure' => '结构问题',
    _ => '待补充',
  };
}

enum PolishLevel { good, fair, weak }

class PolishDimension {
  const PolishDimension(this.key, this.level, this.comment);
  final String key;
  final PolishLevel level;
  final String comment;
  static const titles = {
    'relevance': '岗位匹配度',
    'specificity': '内容具体度',
    'ownership': '职责清晰度',
    'evidence': '成果与依据',
  };
  String get title => titles[key] ?? key;
  String get levelLabel => switch (level) {
    PolishLevel.good => '良好',
    PolishLevel.fair => '一般',
    PolishLevel.weak => '待加强',
  };
}

class PolishDiagnosis {
  const PolishDiagnosis(
    this.overall,
    this.dimensions, {
    this.priorities = const [],
    this.score,
    this.highlights = const [],
    this.risks = const [],
  });
  final String overall;
  final List<PolishDimension> dimensions;

  /// The few whole-resume actions worth doing first.
  final List<String> priorities;

  /// Overall competitiveness for the target role, 1 to 10.
  final int? score;

  /// What already works and should be kept.
  final List<String> highlights;

  /// Points an interviewer is likely to probe, such as employment gaps.
  final List<String> risks;

  static List<String> _list(Object? value) => [
    for (final item in value is List ? value : const [])
      if ('$item'.trim().isNotEmpty) '$item'.trim(),
  ].take(3).toList();

  static PolishDiagnosis? from(Object? value) {
    if (value is! Map) return null;
    final rows = <PolishDimension>[];
    final raw = value['dimensions'];
    if (raw is List) {
      for (final key in PolishDimension.titles.keys) {
        final row = raw.whereType<Map>().where((r) => r['key'] == key);
        if (row.isEmpty) continue;
        final level = PolishLevel.values
            .where((l) => l.name == row.first['level'])
            .firstOrNull;
        final comment = '${row.first['comment'] ?? ''}'.trim();
        if (level != null && comment.isNotEmpty) {
          rows.add(PolishDimension(key, level, comment));
        }
      }
    }
    final overall = '${value['overall'] ?? ''}'.trim();
    final priorities = _list(value['priorities']);
    final highlights = _list(value['highlights']);
    final risks = _list(value['risks']);
    final rawScore = value['score'];
    final score = rawScore is num && rawScore >= 1 && rawScore <= 10
        ? rawScore.round()
        : null;
    if (overall.isEmpty &&
        rows.isEmpty &&
        priorities.isEmpty &&
        highlights.isEmpty &&
        risks.isEmpty &&
        score == null) {
      return null;
    }
    return PolishDiagnosis(
      overall,
      rows,
      priorities: priorities,
      score: score,
      highlights: highlights,
      risks: risks,
    );
  }
}

/// Where a suggestion lives in the resume, in the words the editor uses.
class PolishLocation {
  const PolishLocation(this.section, this.order, this.item, this.field);
  final String section;
  final int order;
  final String item, field;
  String get title {
    final parts = [item, field].where((v) => v.isNotEmpty);
    return parts.isEmpty ? section : parts.join(' · ');
  }

  static const _sections = {
    'work_experiences': ('工作经历', 0),
    'projects': ('项目经历', 1),
    'educations': ('教育经历', 2),
    'skills': ('专业技能', 3),
    'certifications': ('证书', 4),
  };
  static const _fields = {
    'description': '描述',
    'achievements': '项目成果',
    'campus_experience': '在校经历',
    'thesis_title': '论文题目',
    'thesis_description': '论文内容',
    'name': '名称',
    'role': '担任角色',
    'company': '公司名称',
    'position': '职位',
    'industry': '行业',
    'start_date': '开始时间',
    'end_date': '结束时间',
    'current': '在职状态',
    'institution': '学校',
    'degree': '学历',
    'field_of_study': '专业',
    'issuer': '颁发机构',
    'date': '时间',
  };
  static const _sectionFields = {
    'work_experiences.description': '工作内容',
    'projects.description': '项目介绍',
    'projects.name': '项目名称',
    'skills.description': '技能说明',
    'skills.name': '技能名称',
    'certifications.name': '证书名称',
  };

  static PolishLocation resolve(String path, Map<String, dynamic> source) {
    final parts = path.split('.');
    final group = parts.first;
    if (group == 'job_expectation') {
      final field = parts.length > 1 ? parts[1] : '';
      return switch (field) {
        'preference' => const PolishLocation('自我评价', 5, '', ''),
        'position' => const PolishLocation('求职意向', 5, '', '期望职位'),
        'industry' => const PolishLocation('求职意向', 5, '', '期望行业'),
        _ => const PolishLocation('求职意向', 5, '', ''),
      };
    }
    final (section, order) = _sections[group] ?? ('简历', 9);
    final index = parts.length > 1 ? int.tryParse(parts[1]) : null;
    var item = '';
    if (index != null) {
      final rows = source[group];
      final row = rows is List && index >= 0 && index < rows.length
          ? rows[index]
          : null;
      if (row is Map) {
        final names = switch (group) {
          'work_experiences' => [row['company'], row['position']],
          'educations' => [row['institution'], row['field_of_study']],
          _ => [row['name']],
        };
        item = names
            .whereType<String>()
            .map((v) => v.trim())
            .where((v) => v.isNotEmpty)
            .join(' · ');
      }
      if (item.isEmpty) item = '第 ${index + 1} 段';
    }
    final key = parts.length > 2 ? parts.last : '';
    final field = key.isEmpty
        ? ''
        : _sectionFields['$group.$key'] ?? _fields[key] ?? '';
    return PolishLocation(section, order, item, field);
  }
}
