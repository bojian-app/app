/// Shared by the editor and the default document. Personal information is a
/// fixed page header; these are the movable content modules below it.
const resumeModuleOrderKey = 'app_section_order';
const resumeModules = <(String, String)>[
  ('job_expectation', '求职意向'),
  ('self_evaluation', '自我评价'),
  ('work_experiences', '工作经历'),
  ('projects', '项目经历'),
  ('educations', '教育经历'),
  ('skills', '专业技能'),
  ('certifications', '证书'),
];

List<String> resumeModuleOrder(Map source) {
  final defaults = resumeModules.map((entry) => entry.$1).toList();
  final stored = source[resumeModuleOrderKey];
  return {
    if (stored is List)
      for (final key in stored)
        if (key is String && defaults.contains(key)) key,
    ...defaults,
  }.toList();
}
