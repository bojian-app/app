/// Counts the editor's seven core groups. Optional certificates, portraits,
/// gender and birth dates do not prevent an otherwise complete resume.
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

  bool has(Map<String, dynamic> entry, List<String> keys) =>
      keys.every((key) => present(entry[key]));
  final phone = fields['phone']?.replaceAll(RegExp(r'\D'), '') ?? '';
  final email = fields['email']?.trim() ?? '';
  final checks = [
    present(fields['name']),
    present(fields['position']),
    phone.length >= 7 || RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email),
    present(fields['summary']),
    work.any((entry) => has(entry, ['company', 'position', 'description'])) ||
        projects.any((entry) => has(entry, ['name', 'description'])),
    education.any((entry) => has(entry, ['institution', 'field_of_study'])),
    skills.any(
      (entry) => present(entry['name']) || present(entry['description']),
    ),
  ];
  return ResumeEditorProgress(
    checks.where((filled) => filled).length,
    checks.length,
  );
}
