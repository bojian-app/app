/// Six equally weighted groups; each group is either complete or incomplete.
/// Empty entry placeholders and explicitly excluded fields never earn points.
class ResumeEditorProgress {
  const ResumeEditorProgress(this.filled, this.total);
  final int filled, total;
  double get fraction => filled / total;
  int get percent => (fraction * 100).round();
}

ResumeEditorProgress resumeEditorProgress({
  required Map<String, String> fields,
  required Iterable<Map<String, dynamic>> work,
  required Iterable<Map<String, dynamic>> projects,
  required Iterable<Map<String, dynamic>> education,
  required Iterable<Map<String, dynamic>> skills,
}) {
  bool present(Object? value) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty) return false;
    return !const {
      '姓名',
      '学校名称',
      '学校',
      '学历',
      '专业',
      '公司名称',
      '项目名称',
      '待填写',
      '待补充',
      '待完善',
      '请输入',
      '请填写',
    }.contains(text);
  }

  bool hasEntry(
    Iterable<Map<String, dynamic>> entries,
    List<String> keys, {
    bool allowCurrent = false,
  }) => entries.any(
    (entry) => keys.every(
      (key) =>
          key == 'end_date' && allowCurrent && entry['current'] == true ||
          present(entry[key]),
    ),
  );
  final checks = [
    present(fields['name']) &&
        (present(fields['phone']) || present(fields['email'])),
    present(fields['position']) && present(fields['city']),
    hasEntry(work, [
      'company',
      'position',
      'start_date',
      'end_date',
      'description',
    ], allowCurrent: true),
    hasEntry(projects, [
      'name',
      'role',
      'start_date',
      'end_date',
      'description',
      'achievements',
    ]),
    hasEntry(education, [
      'institution',
      'field_of_study',
      'start_date',
      'end_date',
      'campus_experience',
    ]),
    hasEntry(skills, ['name', 'description']),
  ];
  return ResumeEditorProgress(
    checks.where((filled) => filled).length,
    checks.length,
  );
}
