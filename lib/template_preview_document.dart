import 'dart:convert';

import 'app_store.dart';
import 'resume_market_document.dart';
import 'resume_native_export.dart';

const templatePreviewFontAssets = resumeDocumentFontAssets;
const traceTemplatePreview = bool.fromEnvironment(
  'BOJIAN_TRACE_TEMPLATE_PREVIEW',
);

/// Fictional content only: browsing a template never reads the user's resumes.
const templatePreviewFields = <String, dynamic>{
  'name': '林晓',
  'position': '高级 HRBP / 人力资源业务伙伴',
  'phone': '138 0000 0000',
  'email': 'lin.xiao@example.com',
  'birth_date': '1996.06',
  'gender': '女',
  'city': '上海 · 可考虑杭州',
  'industry': '企业服务 / B2B SaaS',
  'salary': '25–35K',
  'preference':
      '8年人力资源经验，拥有4年以上B2B SaaS业务支持经验，服务研发、产品及销售等420人团队，带领3人HR团队。'
      '能够将业务目标拆解为组织、编制和人才计划，独立推进关键岗位招聘、绩效校准与人才发展项目。'
      '注重用招聘漏斗、人员流动和人力成本数据验证方案效果，兼顾业务交付与员工体验。',
  'educations': [
    {
      'title': '江南财经大学',
      'subtitle': '人力资源管理 · 本科',
      'auxiliary': '工商管理学院',
      'start_date': '2014.09',
      'end_date': '2018.06',
      'detail': '主修组织行为学、劳动经济学、薪酬管理、统计学与人员测评；专业成绩前15%，获两次校级奖学金。',
      'secondary_detail': '毕业研究以新员工组织融入为主题，完成120份有效问卷的统计分析，并提出入职培训与导师机制改进建议。',
    },
  ],
  'work_experiences': [
    {
      'title': '澄川数字科技有限公司',
      'subtitle': '高级 HRBP · 团队负责人',
      'auxiliary': 'B2B SaaS事业部 · 上海 · 支持420人团队',
      'start_date': '2022.03',
      'end_date': '至今',
      'detail':
          '• 组织与编制：与事业部负责人、财务共同制定年度人员计划，按季度复盘业务产能、岗位缺口及人力成本，明确新增岗位优先级。\n'
          '• 关键人才招聘：统筹研发、产品及销售招聘，2025年完成42个关键岗位交付；通过岗位画像校准、渠道分层与面试时效管理，将平均招聘周期由45天缩短至32天。\n'
          '• 绩效管理：组织季度目标回顾与绩效校准，辅导18位管理者开展反馈面谈，跟进低绩效改进计划及岗位适配方案。',
      'secondary_detail':
          '• 人才发展：建立关键岗位人才盘点和继任清单，为高潜员工制定轮岗、导师辅导及阶段评估计划，推动6名骨干完成内部晋升。\n'
          '• 员工体验：结合离职访谈和入职30/60/90天回访定位适应问题；在2025年入职批次中，将90天留存率由86%提升至94%。',
    },
    {
      'title': '远帆企业服务有限公司',
      'subtitle': '人力资源专员',
      'auxiliary': '人力资源部 · 杭州 · 公司规模180人',
      'start_date': '2018.07',
      'end_date': '2022.02',
      'detail':
          '• 招聘交付：独立负责销售、客户成功及职能岗位招聘，年均完成约30人入职；维护渠道效果台账，定期复盘简历转化、面试通过及录用接受情况。\n'
          '• 人事运营：负责入离转调、劳动合同、考勤及薪酬核算基础数据，建立月度校验清单，配合财务完成异常数据核对与归档。',
      'secondary_detail':
          '• 流程优化：梳理12项高频人事流程，统一申请表单、责任人与办理时限，将常规手续平均办理周期由3个工作日缩短至1个工作日。\n'
          '• 新人培养：组织月度入职培训，建立业务导师与试用期跟进台账，向用人部门反馈培训完成度及岗位适应情况。',
    },
  ],
  'projects': [
    {
      'title': '人力经营分析看板与月度复盘机制',
      'subtitle': '项目负责人 · 数据口径与流程建设',
      'auxiliary': '协同财务、业务负责人及人事运营团队',
      'start_date': '2025.03',
      'end_date': '2025.08',
      'detail':
          '项目背景：编制、招聘及人员流动数据分散在多份表格中，月度汇报依赖人工拼接，部门之间统计口径不一致。\n'
          '实施过程：统一在岗人数、缺编、主动离职率和人力成本口径，使用Power Query整合月度数据，建立明细校验、异常追踪及数据权限规则。',
      'secondary_detail': '项目成果：将月度报表准备时间由2个工作日缩短至半天；形成固定经营复盘材料，支持季度编制调整，并明确每项异常的责任人、改进动作和复盘日期。',
    },
    {
      'title': '关键岗位招聘体系与人才库建设',
      'subtitle': '项目负责人 · 招聘效率提升',
      'auxiliary': '协同研发、产品、销售负责人及面试官',
      'start_date': '2024.04',
      'end_date': '2024.10',
      'detail':
          '项目背景：招聘需求描述不一致、面试评价缺少统一依据，候选人反馈等待时间较长。\n'
          '实施过程：访谈业务负责人，梳理8类关键岗位的能力要求；设计结构化面试题库与评分表，对面试官开展案例校准，并明确48小时反馈时限。',
      'secondary_detail': '项目成果：在试点岗位中，将48小时内反馈率由68%提升至93%；建立包含260名有效候选人的分层人才库，按技能、意向与最近沟通时间维护，实现需求启动后的定向触达。',
    },
  ],
  'skills': [
    {'name': '业务与组织支持', 'detail': '人员规划、岗位分析、组织诊断、关键人才盘点与管理者沟通。'},
    {'name': '招聘与人才发展', 'detail': '岗位画像、结构化面试、招聘漏斗分析、绩效反馈与继任计划。'},
    {
      'name': '数据分析与工具',
      'detail': '熟练使用Excel数据透视表、Power Query及飞书多维表格，能够独立搭建人力分析看板。',
    },
    {
      'name': '沟通与协作',
      'detail': '能够主持跨部门需求澄清与方案评审，输出业务汇报、流程指引及培训材料；可阅读英文岗位说明与行业资料。',
    },
  ],
  'certifications': [
    {
      'title': '企业人力资源管理师（二级）',
      'subtitle': '职业技能等级证书',
      'auxiliary': '人力资源专业能力',
      'start_date': '2024.11',
      'end_date': '2024.11',
      'detail': '系统学习人力资源规划、招聘配置、培训开发、绩效及薪酬管理，并结合业务场景开展实践。',
      'secondary_detail': '',
    },
    {
      'title': '大学英语六级（CET-6）',
      'subtitle': '562分',
      'auxiliary': '英语阅读与书面沟通',
      'start_date': '2017.06',
      'end_date': '2017.06',
      'detail': '能够阅读英文产品资料、岗位说明及人力资源研究报告。',
      'secondary_detail': '',
    },
  ],
};

String templatePreviewDocument({
  required Map<String, dynamic> dom,
  required String rendererScript,
  required String previewScript,
  String photo = '',
  String author = '',
  int initialPage = 0,
  bool showPageActions = true,
}) => marketDocumentHtml(
  dom: dom,
  resume: ResumeDraft(id: 0, title: '模板示例'),
  fields: templatePreviewFields,
  photo: photo,
  captureScript: traceTemplatePreview ? 'window.bojianTrace=true;' : '',
  rendererScript: rendererScript,
  marketplacePreview: true,
  previewScript:
      'window.bojianPreviewOptions=${jsonEncode({'author': author, 'initialPage': initialPage, 'showPageActions': showPageActions}).replaceAll('<', r'\u003c')};\n$previewScript',
  fontStyles: resumeDocumentFontStyles,
);
