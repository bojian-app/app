/// The seven answers are sent as a readable brief through the existing API.
/// Selections guide the writing. Missing experience becomes an identified role
/// example; supplied personal facts take priority over example material.
class ResumeCreationAnswers {
  String identity = '';
  String years = '';
  String position = '';
  String major = '';
  final skills = <String>{};
  final certificates = <String>{};
  final projectTypes = <String>{};
  final activities = <String>{};
  final traits = <String>{};

  String describe(String additional) => [
    '创建方式：问答创建',
    '身份：$identity',
    if (years.isNotEmpty) '工作年限：$years',
    '意向岗位：$position',
    if (major.isNotEmpty) '所学专业：$major',
    if (skills.isNotEmpty) '软技能：${skills.join('、')}',
    if (traits.isNotEmpty) '性格特征：${traits.join('、')}',
    if (projectTypes.isNotEmpty)
      '参与项目类别：${projectTypes.join('、')}。这是选中的项目主题，请结合目标岗位生成完整项目经历。',
    if (activities.isNotEmpty)
      '校园活动标签：${activities.join('、')}。这是选中的校园活动主题，请结合专业和目标岗位生成完整在校经历。',
    if (certificates.isNotEmpty) '资格证书：${certificates.join('、')}',
    if (additional.trim().isNotEmpty) '本人补充的经历：\n${additional.trim()}',
    '请优先融入本人补充或参考文件中的经历，完整生成公司、职位、起止时间和工作内容；项目名称、角色、起止时间、描述及成果；学校、专业、入学与毕业时间及在校经历；技能名称与说明。资料不足时结合目标岗位、身份、年限和专业撰写可编辑的完整草稿，不留空、不输出填空提示。缺少姓名时默认使用“好名字”，缺少邮箱时默认使用“example@bojian.com”，已有信息优先保留。意向职位和城市必须有值，城市只输出名称。所有字段只输出正文，不加入“岗位示例”“非实际履历”“学习示例”“建议”等附加说明。',
  ].join('\n');
}

const resumeCreationMajors = [
  '工商管理',
  '护理学',
  '学前教育',
  '电子商务',
  '会计学',
  '市场营销',
  '计算机科学与技术',
  '软件工程',
  '汉语言文学',
  '新闻传播学',
  '人力资源管理',
  '金融学',
  '机械设计制造及其自动化',
  '土木工程',
  '艺术设计',
  '英语',
];

const resumeCreationSoftSkills = [
  '团队协作',
  '行业洞察',
  '创新思维',
  '决策分析',
  '项目管理',
  '变革管理',
  '批判思维',
  '战略思维',
];

const resumeCreationCertificates = [
  '大学英语四级',
  '大学英语六级',
  '教师资格证',
  '普通话水平测试',
  '计算机二级',
  '初级会计证',
  '医师资格证',
];

const resumeGraduateProjects = [
  '大型活动策划',
  '财务报表分析',
  '产品推广方案',
  '行业竞品分析',
  '网站APP开发',
  '课程设计',
  '临床试验管理',
];
const resumeCampusActivities = [
  '学生会',
  '创新创业大赛',
  '学生社团',
  '青年志愿者协会',
  '校园公众号',
  '文艺汇演策划',
  '辩论队',
];
const resumeGraduateSkills = [
  '沟通协作',
  '创新思维',
  '学习能力',
  '批判思维',
  '执行能力',
  '适应应变',
  '自我驱动',
  '时间管理',
];
const resumeStudentTraits = [
  '责任感强',
  '积极主动',
  '善于沟通',
  '勤奋好学',
  '成熟稳重',
  '创意丰富',
  '高效协作',
  '耐心细心',
];

List<String> resumeProjectPrompts(String position) {
  if (RegExp('开发|软件|测试|程序|工程师').hasMatch(position)) {
    return [
      '说说你负责的系统或功能、采用的技术方案，以及解决的具体问题。',
      '补充一次性能优化、故障排查或上线交付：你做了什么，有哪些实际结果？',
      '项目服务谁、你负责哪些模块、如何协作？已有性能或质量数据可以一起写。',
    ];
  }
  if (RegExp('产品|项目经理').hasMatch(position)) {
    return [
      '选一个主导项目，说明业务目标、你的职责、推进过程和最终交付。',
      '补充需求分析、方案取舍和跨团队协作中的关键行动，以及已有业务结果。',
      '项目遇到什么难点？你如何调整计划、推动落地并验证效果？',
    ];
  }
  if (RegExp('运营|营销|销售|客户').hasMatch(position)) {
    return [
      '聚焦近期核心项目，说明目标用户、渠道策略、你的工作和已有成果。',
      '补充一次内容、活动或客户转化项目：如何执行，结果有哪些可核实的数据？',
      '说说你怎样发现问题、调整方案并复盘，保留实际的增长或转化结果。',
    ];
  }
  if (RegExp('教师|教育|护士|医师').hasMatch(position)) {
    return [
      '结合一次教学、服务或改进项目，说明对象、目标、个人行动和实际反馈。',
      '描述你解决过的具体问题，以及采用的方法、协作过程和可核实的结果。',
      '补充课程、活动或流程改进中的具体职责，用实际案例体现专业能力。',
    ];
  }
  return [
    '聚焦近期主导的核心项目，写清背景、个人职责、具体行动和已有成果。',
    '选择一个最能体现岗位能力的案例，说明你解决了什么问题、怎样推进。',
    '可以补充工作、实习、课程或校园项目；有真实数据或反馈时一起写。',
  ];
}

/// Keeps the imported facts readable and editable before they are submitted.
String resumeReferenceText(Map<String, dynamic> content) {
  final raw = content['raw_text'];
  if (raw is String && raw.trim().isNotEmpty) return raw.trim();
  const labels = {
    'personal_info': '基本信息',
    'full_name': '姓名',
    'gender': '性别',
    'phone': '电话',
    'birth_date': '出生日期',
    'email': '邮箱',
    'summary': '自我评价',
    'work_experiences': '工作经历',
    'company': '公司',
    'industry': '行业',
    'start_date': '开始时间',
    'end_date': '结束时间',
    'current': '目前仍在职',
    'position': '岗位',
    'description': '具体内容',
    'projects': '项目经历',
    'name': '名称',
    'role': '角色',
    'achievements': '成果',
    'url': '链接',
    'educations': '教育经历',
    'degree': '学历',
    'institution': '学校',
    'field_of_study': '专业',
    'campus_experience': '在校经历',
    'thesis_title': '论文题目',
    'thesis_description': '论文内容',
    'certifications': '资格证书',
    'issuer': '颁发机构',
    'date': '日期',
    'skills': '技能',
    'job_expectation': '求职意向',
    'city': '城市',
    'preference': '补充说明',
    'salary': '薪资',
    'unresolved_source_text': '其他原文',
  };
  String render(dynamic value) {
    if (value is Map) {
      return value.entries
          .where((entry) => labels.containsKey(entry.key))
          .map((entry) {
            final text = render(entry.value);
            return text.isEmpty ? '' : '${labels[entry.key]}：$text';
          })
          .where((line) => line.isNotEmpty)
          .join('\n');
    }
    if (value is List) {
      return value.map(render).where((v) => v.isNotEmpty).join('\n\n');
    }
    if (value is bool) return value ? '是' : '否';
    if (value is String && !{'undisclosed', 'age', 'date'}.contains(value)) {
      return value.trim();
    }
    return '';
  }

  return render(content);
}
