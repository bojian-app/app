/// Locally bundled documents. Opening these documents does not send a request,
/// grant consent, or leave the app.
enum LegalDocumentKind { userAgreement, privacyPolicy }

const _privacyVersion = '3.3';
const legalAgreementVersions = {'terms': '2.1', 'privacy': _privacyVersion};

sealed class LegalBlock {
  const LegalBlock();

  String get plainText;
}

class LegalParagraph extends LegalBlock {
  const LegalParagraph(this.text, {this.emphasized = false});

  final String text;
  final bool emphasized;

  @override
  String get plainText => text;
}

class LegalSubheading extends LegalBlock {
  const LegalSubheading(this.text);

  final String text;

  @override
  String get plainText => text;
}

class LegalTable extends LegalBlock {
  const LegalTable({required this.headers, required this.rows});

  final List<String> headers;
  final List<List<String>> rows;

  @override
  String get plainText =>
      [headers, ...rows].map((row) => row.join('　')).join('\n');
}

class LegalSection {
  const LegalSection({
    required this.id,
    required this.title,
    required this.blocks,
  });

  final String id;
  final String title;
  final List<LegalBlock> blocks;

  String get plainText =>
      [title, ...blocks.map((block) => block.plainText)].join('\n\n');
}

class LegalDocument {
  const LegalDocument({
    required this.kind,
    required this.title,
    required this.metadata,
    required this.introduction,
    required this.sections,
  });

  final LegalDocumentKind kind;
  final String title;
  final List<String> metadata;
  final List<LegalParagraph> introduction;
  final List<LegalSection> sections;

  String get plainText => [
    title,
    metadata.join('　'),
    ...introduction.map((paragraph) => paragraph.text),
    ...sections.map((section) => section.plainText),
  ].join('\n\n');
}

LegalDocument legalDocumentFor(LegalDocumentKind kind) => switch (kind) {
  LegalDocumentKind.userAgreement => userAgreementDocument,
  LegalDocumentKind.privacyPolicy => privacyPolicyDocument,
};

/// 运营主体信息。未确认的内容保留【待填写】标记，确认后在此统一替换。
const _operator = '珠海科岚盛网络科技有限公司';
const _contactEmail = 'notifier@kelantech.cn';
const _icpRecord = '粤ICP备2026155383号';
const _creditCode = '91440403MAD4CAX58L';
const _address = '珠海市斗门区湖心路口翠湖路308号1栋社区用房';
const _updatedDate = '2026年11月24日';
const _effectiveDate = '2026年11月24日';

const userAgreementDocument = LegalDocument(
  kind: LegalDocumentKind.userAgreement,
  title: '拾页用户协议',
  metadata: ['版本：V2.1', '更新日期：$_updatedDate', '生效日期：$_effectiveDate'],
  introduction: [
    LegalParagraph(
      '欢迎使用拾页！本协议是您与$_operator（以下简称“我们”）之间就使用拾页App及相关服务所订立的协议。请您在注册、登录或使用前仔细阅读并充分理解本协议全部内容，特别是以粗体标识的免除或限制责任、会员与付费、自动续费、争议解决等条款。未成年人应在监护人陪同下阅读。您点击“同意”、勾选同意后登录，或以其他方式实际使用本服务的，即表示您已阅读并同意本协议及《隐私政策》；如不同意，请不要注册或使用本服务。',
      emphasized: true,
    ),
  ],
  sections: [
    LegalSection(
      id: 'definitions',
      title: '第一条 定义与适用范围',
      blocks: [
        LegalParagraph(
          '1.1 拾页／本服务：指由我们运营的“拾页”移动应用（含Android和iOS版本）、官方网站 bojian.kelance.cn 及相关服务。',
        ),
        LegalParagraph('1.2 用户／您：指注册、登录或使用本服务的自然人。'),
        LegalParagraph(
          '1.3 用户内容：指您在本服务中填写、上传、发布或发送的文字、图片、文件等信息，包括头像、个人资料、简历、文章动态、评论、修改意见、聊天消息、举报与反馈内容等。',
        ),
        LegalParagraph(
          '1.4 AI 功能：指基于第三方大模型服务提供的AI简历生成、AI简历优化（诊断润色）、单段内容生成及简历文件导入解析等功能。',
        ),
        LegalParagraph(
          '1.5 会员：指您付费购买或通过邀请活动获得的、在有效期内享有会员权益的服务资格；会员权益及规则以本协议第六条和购买页面展示为准。',
        ),
        LegalParagraph(
          '1.6 《隐私政策》、会员购买页面说明及我们在本服务中发布的各类规则，是本协议不可分割的组成部分，与本协议具有同等效力。',
        ),
      ],
    ),
    LegalSection(
      id: 'consent',
      title: '第二条 协议的订立与变更',
      blocks: [
        LegalParagraph(
          '2.1 首次使用时，我们会通过弹窗、登录页勾选等方式请您阅读并同意本协议和《隐私政策》。您可随时在登录页及“设置”页面查阅本协议和《隐私政策》。',
        ),
        LegalParagraph('2.2 在您同意前，我们不会发起微信或抖音授权、短信验证码请求，也不会初始化广告等第三方SDK。'),
        LegalParagraph(
          '2.3 我们可能根据法律法规变化或业务调整修订本协议。修订后的协议将在本服务中公布；涉及您重大权益的变更，我们会通过弹窗、站内通知等显著方式提前告知并在必要时重新征得您的同意。您不同意修订内容的，可以停止使用并注销账号；您继续使用的，视为接受修订后的协议。',
          emphasized: true,
        ),
      ],
    ),
    LegalSection(
      id: 'account',
      title: '第三条 账号注册、登录与安全',
      blocks: [
        LegalParagraph(
          '3.1 您可以使用中国大陆手机号加短信验证码登录，也可以通过微信或抖音授权登录。使用微信或抖音登录时，还需验证本人手机号；该手机号已注册拾页账号的，第三方账号将关联至该账号。首次登录时，我们会在您确认注册后创建账号。',
        ),
        LegalParagraph(
          '3.2 账号仅限您本人使用，不得出借、出租、转让、售卖或与他人共用。您应妥善保管手机号、第三方账号及登录设备；因您保管不善导致的损失由您自行承担，但因我们的过错造成的除外。',
        ),
        LegalParagraph(
          '3.3 您可以在“设置—账号安全”中查看已登录的设备，并退出任一设备。发现账号被盗用或存在安全风险的，请及时联系我们。',
        ),
        LegalParagraph(
          '3.4 如您申请成为认证用户（实名认证），需按页面提示提供身份证照片并完成人脸核验，具体处理规则见《隐私政策》。',
        ),
        LegalParagraph(
          '3.5 为保障账号与平台安全，我们在发现账号异常、涉嫌违法违规或被他人举报并经核实的情况下，可以采取限制登录、限制功能等措施，并通过站内通知告知您处理结果与申诉方式。',
        ),
      ],
    ),
    LegalSection(
      id: 'services',
      title: '第四条 服务内容',
      blocks: [
        LegalParagraph(
          '4.1 本服务目前包括：个人资料与头像管理；简历创建、编辑、保存、模板套用、预览与导出（PDF／DOCX）；简历文件导入解析；AI简历生成、AI简历优化与单段生成；文章动态发布、评论、点赞、收藏；简历求指点与修改意见；好友搜索、好友聊天与站内通知；邀请好友；认证用户实名认证；会员服务；意见反馈、举报与账号申诉。具体以App实际提供的功能为准。',
        ),
        LegalParagraph(
          '4.2 拾页是简历制作与职业交流工具，不提供招聘职位投递、面试安排或录用服务，我们不对您获得面试、录用或任何求职结果作出承诺或保证。',
          emphasized: true,
        ),
        LegalParagraph(
          '4.3 免费用户在发现页可能看到第三方广告（目前为横幅广告），广告内容由广告主负责；您点击广告后与广告主之间的交易由您与广告主自行处理。有效会员不展示广告。',
        ),
        LegalParagraph('4.4 我们可能根据业务需要调整、升级或下线部分功能。涉及已付费权益的，我们将提前公告并妥善处理您的权益。'),
      ],
    ),
    LegalSection(
      id: 'ai',
      title: '第五条 AI 功能特别约定',
      blocks: [
        LegalParagraph(
          '5.1 使用AI功能时，我们会将完成该功能所必需的内容（如您填写的生成要求、简历经历文本、待生成的段落、导入的简历文件内容）发送给第三方大模型服务提供方处理，详见《隐私政策》。请不要在这些内容中填写与求职无关的个人信息，或他人未授权提供的个人信息。',
          emphasized: true,
        ),
        LegalParagraph(
          '5.2 AI生成的内容由算法自动生成，可能存在不准确、不完整或与事实不符的情况，仅供参考。生成结果不会自动覆盖您的简历，只有在您确认后才会保存。您应自行核对并对最终使用的简历内容的真实性负责，不得利用AI功能编造学历、工作经历等虚假信息。',
          emphasized: true,
        ),
        LegalParagraph(
          '5.3 您不得利用AI功能生成违反法律法规、侵犯他人权益或违背公序良俗的内容。我们会依法对输入和输出内容进行必要的安全管理，并对违规使用采取限制措施。',
        ),
        LegalParagraph(
          '5.4 AI功能的使用次数受会员权益限制，具体见第六条。因第三方模型服务故障、网络等原因导致生成失败的，我们会尽力返还或不扣减对应次数，具体以系统记录为准。',
        ),
      ],
    ),
    LegalSection(
      id: 'membership',
      title: '第六条 会员服务与付费条款',
      blocks: [
        LegalParagraph('6.1 会员套餐与价格'),
        LegalTable(
          headers: ['套餐', '价格', '有效期', '包含的AI次数'],
          rows: [
            ['月卡', '9元', '自购买时起1个月', 'AI简历生成3次、AI简历优化3次、单段生成10次'],
            ['年卡', '99元', '自购买时起12个月', 'AI简历生成36次、AI简历优化36次、单段生成120次'],
          ],
        ),
        LegalParagraph(
          '会员期内还可享受：不展示广告、付费模板直接使用等权益，以会员页面展示为准。实际价格以购买页面展示为准；如有优惠券或促销活动，以活动规则为准。',
        ),
        LegalParagraph(
          '6.2 每次购买独立计算：每次购买都是独立的一份会员，从购买成功时起算，不在已有会员到期后顺延。同时持有多份时，会员到期日以最晚到期的一份为准；AI次数优先扣减最早到期的一份。',
          emphasized: true,
        ),
        LegalParagraph(
          '6.3 次数一次性发放、到期清零：每份会员包含的AI次数在购买时一次性发放，只能在该份会员有效期内使用。到期后该份剩余的次数自动清零，不累计、不顺延、不折现。',
          emphasized: true,
        ),
        LegalParagraph(
          '6.4 按次加购：有效会员可以额外加购AI次数。Android 端价格为：AI简历生成、AI简历优化每次0.99元，单段生成每次0.1元；iOS 端以 App Store 展示的固定次数档位及价格为准。加购的次数没有到期日，但只能在会员有效期内使用；会员到期后加购次数冻结，再次开通会员后恢复可用。',
          emphasized: true,
        ),
        LegalParagraph(
          '6.5 支付方式：Android 端支持支付宝、微信支付（以页面实际展示的渠道为准）；iOS 端通过 Apple App Store 应用内购买支付，费用由 Apple 向您的 Apple 账户收取。会员是否开通以我们服务端确认的支付结果为准。',
        ),
        LegalParagraph(
          '6.6 自动续费（仅 iOS）：Android 端不提供自动续费，到期后不会自动扣费。iOS 端默认是一次性购买；只有您在下单时主动选择“自动续费”套餐，才会在当前订阅期结束时由 App Store 按相同周期和当时价格自动续订并扣款。Apple 会在当前订阅期结束前24小时内从您的 Apple 账户扣费。您可以随时在 iPhone“设置—Apple 账户—订阅”或App内“管理自动续费”入口取消，取消需在当前订阅期结束至少24小时前完成，取消后当前已付费周期内的权益不受影响。',
          emphasized: true,
        ),
        LegalParagraph(
          '6.7 邀请奖励：好友使用您的邀请码注册并绑定手机号后，您将获得一份三天会员体验包：到账起3天内享受会员权益，另含AI简历生成1次、AI简历优化1次、单段生成10次，到期清零。邀请奖励不可转让、不可折现；以作弊、批量注册等不正当方式获取奖励的，我们有权取消奖励并追回已发放权益。',
        ),
        LegalParagraph('6.8 积分：积分不出售，也不能用于兑换现金。积分功能已下线，改版前用积分兑换的模板在原有效期内继续可用。'),
        LegalParagraph(
          '6.9 虚拟服务与退款：会员及AI次数属于数字化虚拟服务，购买成功并发放后，除法律法规另有规定或因我们的原因导致您无法使用外，不支持退款、转让或折现。通过 App Store 购买的，退款由 Apple 依其规则处理；Apple 退款后，我们将相应收回该笔交易对应的会员时长和次数。如遇重复扣款、付款后权益未到账等问题，请通过App内“恢复购买”或联系我们处理。',
          emphasized: true,
        ),
        LegalParagraph(
          '6.10 价格与权益调整：我们可能调整会员价格或权益，调整前已购买的会员在其有效期内不受影响。iOS 自动续费价格上调的，Apple 会依其规则通知您并在需要时征得您的同意。',
        ),
        LegalParagraph(
          '6.11 会员权益仅限本账号使用，可在登录同一账号的设备上使用，不得出借、转让或出售。注销账号将导致未使用的会员时长和次数作废，且不予退还。',
          emphasized: true,
        ),
      ],
    ),
    LegalSection(
      id: 'user-content',
      title: '第七条 用户内容与知识产权',
      blocks: [
        LegalParagraph(
          '7.1 您对自己的用户内容享有相应的权利并承担责任，应保证内容真实、合法，不侵犯他人的著作权、肖像权、隐私权、个人信息等合法权益；内容涉及他人个人信息的，应事先取得其同意。',
        ),
        LegalParagraph(
          '7.2 对于您主动公开发布的内容（如文章动态、评论、社区求指点），您授予我们在本服务范围内为展示、传播之目的，免费、非独占地使用该内容的权利。该授权在您删除内容或注销账号后终止，但已被他人转发、保存的除外。您的私人简历、聊天消息不在此授权范围内，我们不会公开或用于其他目的。',
          emphasized: true,
        ),
        LegalParagraph(
          '7.3 本服务的软件、界面设计、商标、模板及我们自有内容的知识产权归我们或相应权利人所有。您通过会员或其他方式取得模板使用权的，仅可用于制作您个人的简历，不得转售、再分发模板或用于其他商业用途。未经许可，不得对本服务进行反向工程、反编译或以爬虫等方式批量获取数据。',
        ),
        LegalParagraph(
          '7.4 您可以随时删除简历、删除或撤回文章、删除评论、取消点赞和收藏。删除前已被他人查看、接收或保存的内容，可能无法从对方处删除。',
        ),
      ],
    ),
    LegalSection(
      id: 'conduct',
      title: '第八条 用户行为规范与内容审核',
      blocks: [
        LegalParagraph('8.1 您不得利用本服务制作、上传、发布或传播含有下列内容的信息：'),
        LegalParagraph(
          '（一）反对宪法基本原则，危害国家安全、荣誉和利益，煽动民族仇恨、破坏民族团结，宣扬邪教、迷信、恐怖主义、极端主义的；',
        ),
        LegalParagraph('（二）散布谣言，扰乱社会秩序，宣扬淫秽、色情、赌博、暴力、凶杀或教唆犯罪的；'),
        LegalParagraph('（三）侮辱、诽谤他人，侵害他人名誉、隐私、个人信息、知识产权等合法权益的；'),
        LegalParagraph('（四）虚假招聘、诈骗、传销、违规收费、恶意营销或垃圾广告的；'),
        LegalParagraph('（五）其他违反法律法规、社会公德或公序良俗的。'),
        LegalParagraph(
          '8.2 您不得冒用他人身份或伪造资质；不得使用外挂、自动化脚本、批量注册等方式干扰服务正常运行，或恶意刷取邀请奖励、会员权益。',
        ),
        LegalParagraph(
          '8.3 为履行平台信息安全管理义务，您发布的文章动态、评论、社区求指点投稿及修改意见等公开或互动内容，在发布前会经过自动审核（详见《隐私政策》），必要时由人工复审。未通过审核的内容将不会发布或被退回。',
        ),
        LegalParagraph(
          '8.4 对违反本协议的行为，我们可以视情节采取删除内容、限制功能、暂停或终止账号等措施，依法保存有关记录并向主管部门报告。您对处理结果有异议的，可以通过App内“账号申诉”提出申诉。',
        ),
        LegalParagraph('8.5 您发现违法违规内容的，可以通过内容页面的“举报”功能或第十四条联系方式向我们举报，我们会及时处理。'),
      ],
    ),
    LegalSection(
      id: 'guidance',
      title: '第九条 简历求指点特别约定',
      blocks: [
        LegalParagraph('9.1 您可以将简历公开投稿到社区求指点，也可以定向邀请1至20位好友指点。'),
        LegalParagraph(
          '9.2 系统会在求指点快照中自动隐藏个人信息区、照片、项目链接、学校名称、公司名称、项目名称和证书颁发机构。但简历标题、您的提问以及职位、经历描述、技能、求职意向等其他内容仍会被他人看到，可能包含能识别您身份的线索。自动隐藏不等于匿名化，请您在提交前自行检查。',
          emphasized: true,
        ),
        LegalParagraph('9.3 其他用户提出的修改意见由提出者负责，您可以自主决定采纳或拒绝；采纳的内容在您保存后合并到原简历。'),
      ],
    ),
    LegalSection(
      id: 'deletion',
      title: '第十条 账号注销',
      blocks: [
        LegalParagraph(
          '10.1 您可以在App“设置—账号安全—账号注销”中申请注销账号。提交申请后，您账号在所有设备上的登录将立即失效，注销将在30天冷静期届满后执行。',
        ),
        LegalParagraph(
          '10.2 冷静期内撤回注销申请的方式：您重新登录该账号，并在弹出的提示中确认继续使用该账号，注销申请即被撤回。',
        ),
        LegalParagraph(
          '10.3 注销完成后，您将无法再登录或找回该账号，账号下的个人资料、简历、文章、评论、聊天记录、会员权益、AI次数及加购次数等将被删除或匿名化处理且无法恢复，法律法规另有规定的除外。请在申请前自行导出需要保留的简历。',
          emphasized: true,
        ),
        LegalParagraph(
          '10.4 通过 iOS 自动续费订阅的，注销账号不会自动取消 App Store 订阅，请您先在 Apple 订阅管理中取消，以免继续扣费。',
        ),
      ],
    ),
    LegalSection(
      id: 'minors',
      title: '第十一条 未成年人使用',
      blocks: [
        LegalParagraph(
          '本服务主要面向求职者及职场人士。未满18周岁的未成年人应在监护人同意和指导下使用本服务，并在监护人同意后进行任何付费。不满14周岁的儿童请勿注册使用本服务。监护人发现未成年人未经同意使用或付费的，可以通过第十四条联系方式与我们联系。',
        ),
      ],
    ),
    LegalSection(
      id: 'liability',
      title: '第十二条 免责与责任限制',
      blocks: [
        LegalParagraph(
          '12.1 我们会尽力保障服务稳定运行，但因系统维护升级、网络故障、第三方服务（如支付、短信、AI模型、云存储）故障、不可抗力等原因导致服务中断或受影响的，我们将尽快修复，并在法律允许的范围内免除责任。',
          emphasized: true,
        ),
        LegalParagraph(
          '12.2 社区内容、指点意见和AI生成内容仅供参考，不构成任何职业或法律建议；您基于这些内容作出的决定由您自行判断和承担。',
          emphasized: true,
        ),
        LegalParagraph(
          '12.3 在法律允许的范围内，我们对您承担的赔偿责任总额以您就相关付费服务实际支付的金额为限。法律规定不得免除或限制的责任除外。',
          emphasized: true,
        ),
      ],
    ),
    LegalSection(
      id: 'disputes',
      title: '第十三条 法律适用与争议解决',
      blocks: [
        LegalParagraph(
          '本协议的订立、履行和解释适用中华人民共和国大陆地区法律。因本协议产生的争议，双方应友好协商；协商不成的，任何一方可向$_operator住所地珠海市斗门区有管辖权的人民法院提起诉讼。',
          emphasized: true,
        ),
      ],
    ),
    LegalSection(
      id: 'contact',
      title: '第十四条 通知与联系方式',
      blocks: [
        LegalParagraph('14.1 我们可以通过App弹窗、站内通知、短信等方式向您发送通知。'),
        LegalParagraph(
          '14.2 运营主体：$_operator；统一社会信用代码：$_creditCode；注册地址：$_address；联系邮箱：$_contactEmail；ICP备案号：$_icpRecord。我们将在收到您的问题后15个工作日内答复。',
        ),
        LegalParagraph('14.3 本协议部分条款被认定无效的，不影响其他条款的效力。'),
      ],
    ),
  ],
);

const privacyPolicyDocument = LegalDocument(
  kind: LegalDocumentKind.privacyPolicy,
  title: '拾页隐私政策',
  metadata: ['版本：V$_privacyVersion', '更新日期：2026年11月24日', '生效日期：2026年11月24日'],
  introduction: [
    LegalParagraph(
      '$_operator（以下简称“我们”）是拾页App的个人信息处理者。我们依据《中华人民共和国个人信息保护法》等法律法规制定本政策，说明我们如何收集、使用、存储、共享和保护您的个人信息，以及您如何行使权利。请您仔细阅读，特别是加粗内容。在您同意本政策前，我们不会发起微信或抖音授权、短信验证码请求，也不会初始化广告等第三方SDK。如有疑问，请通过本政策第十条的方式联系我们。',
      emphasized: true,
    ),
  ],
  sections: [
    LegalSection(
      id: 'collection',
      title: '一、我们如何收集和使用您的个人信息',
      blocks: [
        LegalParagraph(
          '我们遵循合法、正当、必要和诚信原则，只收集实现功能所必需的信息。基本功能（登录、简历编辑与保存）所需的信息为必要信息；其他功能所需的信息仅在您使用该功能时收集，您拒绝提供只会导致该功能无法使用，不影响其他功能。',
        ),
        LegalSubheading('1. 注册与登录'),
        LegalParagraph(
          '手机号登录：我们收集您的手机号和短信验证码，用于验证身份、创建或登录账号。为防止恶意发送短信，获取验证码前需完成图形滑块验证。',
        ),
        LegalParagraph(
          '微信登录：在您主动选择微信登录并在微信中确认授权后，我们通过微信开放平台获取您的微信账号标识（OpenID、UnionID），首次注册时还会获取您授权的微信昵称和头像作为初始资料。',
        ),
        LegalParagraph(
          '抖音登录：在您主动选择抖音登录后，我们才初始化抖音开放平台SDK并发起授权，获取您的抖音账号标识（OpenID），首次注册时还会获取您授权的抖音昵称和头像。',
        ),
        LegalParagraph('使用微信或抖音登录时，还需验证您的手机号，以便识别账号、保障账号安全。'),
        LegalSubheading('2. 设备信息与登录安全'),
        LegalParagraph(
          '为识别登录设备、管理登录会话和保障账号安全，我们会收集：设备型号、操作系统及版本、应用版本、设备标识。Android 设备上，设备标识由系统的 Android ID 加入应用信息后经不可逆哈希处理生成，我们不会获取原始 Android ID；iOS 设备上为应用随机生成的标识。我们不收集IMEI、IMSI、MAC地址、OAID、IDFA及已安装应用列表。您可在“设置—账号安全”查看和退出登录设备。',
          emphasized: true,
        ),
        LegalParagraph(
          '我们还会记录登录时间、会话令牌（服务端仅保存摘要）、IP地址、请求日志和安全事件，用于保持登录、网络通信、故障排查和防范攻击。',
        ),
        LegalSubheading('3. IP 属地'),
        LegalParagraph(
          '根据法律法规要求，我们会根据您访问时的IP地址，通过服务端本地IP地址库推算您所在的省份或城市，并在您的个人主页和发布的内容中展示IP属地。我们不使用GPS等精确定位，也不会向在线定位服务查询。',
          emphasized: true,
        ),
        LegalSubheading('4. 个人资料'),
        LegalParagraph(
          '您可以填写或修改昵称、头像、个人简介和在职状态。头像可从相册选择或拍照上传。账号ID、注册时间、公开状态由系统生成。',
        ),
        LegalSubheading('5. 简历信息'),
        LegalParagraph(
          '您在简历中主动填写的信息会保存到我们的服务器，以便您在多台设备上编辑和导出，包括：姓名、性别、手机号、邮箱、出生日期、照片；工作经历、教育经历、项目经历、技能证书；求职意向（目标城市、职位、行业、期望薪资）等。简历可能包含较多个人信息，请仅填写求职所需的内容；身份证号、健康状况、宗教信仰等属于敏感个人信息，与求职无关的请不要填写。简历导出文件在您的设备本地生成。',
          emphasized: true,
        ),
        LegalSubheading('6. AI 简历生成、优化与单段生成'),
        LegalParagraph(
          '当您主动使用以下AI功能时，我们会将相应内容提供给 DeepSeek 开放平台处理，并向您展示结果：AI简历生成——您填写的生成要求和描述，以及您此前AI生成结果中的项目名称和描述（用于避免生成重复内容）；AI简历优化——简历中的工作、项目、教育、技能和证书等经历文本以及求职岗位（不包含单独填写的姓名、联系方式、出生日期和照片）；单段生成——生成工作描述时为公司名称、职位、行业和起止时间，生成项目描述时为项目名称和担任角色，生成项目成就时另含项目描述。生成结果需经您确认后才会保存。首次使用AI功能前，我们会弹窗单独征求您的同意，见第三部分。',
          emphasized: true,
        ),
        LegalSubheading('7. 简历文件导入'),
        LegalParagraph(
          '当您主动选择PDF、DOC、DOCX文件导入简历时，文件会上传至我们的云存储，服务端优先在本地提取文字；扫描件等无法直接提取文字的，我们会将需要识别的页面图像发送给 DeepSeek 开放平台。提取的文字也会发送给该平台，用于整理简历字段。导入结果经您检查确认后才会创建简历。导入文件中可能包含您的姓名、联系方式、照片等个人信息，请勿在文件中包含身份证号等无关的敏感信息。该功能同样需要您事先单独同意。',
          emphasized: true,
        ),
        LegalSubheading('8. 社区互动与内容审核'),
        LegalParagraph(
          '您发布文章动态、评论、点赞、收藏时，我们会处理相应内容及互动记录，并在社区中展示您的昵称、头像、IP属地等公开资料。您可以在设置中关闭公开个人主页。为履行信息安全管理义务，您发布的文章、评论、社区求指点投稿和修改意见的文字内容会发送给腾讯云内容审核服务（见第三部分第（4）项）进行自动审核，必要时由人工复审。',
        ),
        LegalSubheading('9. 简历求指点'),
        LegalParagraph(
          '您发起求指点时，我们会将简历标题、您的提问和隐藏了个人信息区、照片、学校、公司、项目名称、项目链接和证书颁发机构后的简历快照，展示给社区用户或您选择的好友。其他内容（如职位、经历描述、技能、求职意向）仍会展示，可能包含身份线索，请您提交前检查。',
          emphasized: true,
        ),
        LegalSubheading('10. 好友、聊天与通知'),
        LegalParagraph(
          '使用好友搜索、聊天功能时，我们处理好友关系、聊天消息内容、发送时间和已读状态。聊天消息在服务端加密存储（该方式不属于端到端加密）。站内通知会处理互动类型和已读记录。',
        ),
        LegalSubheading('11. 邀请好友'),
        LegalParagraph(
          '您使用邀请功能时，我们会生成您的邀请码和邀请二维码，并记录邀请关系，用于发放邀请奖励。您扫描邀请二维码时，二维码在设备本地识别。',
        ),
        LegalSubheading('12. 实名认证（可选）'),
        LegalParagraph(
          '仅在您主动申请成为认证用户时：我们会将您拍摄或选择的身份证正反面照片发送给百度智能云进行识别，获得姓名、身份证号、证件有效期；在您单独同意后，调用百度人脸采集SDK采集现场人脸进行活体检测和身份比对。身份证号和人脸信息属于敏感个人信息，我们仅用于核验身份，加密保存核验结果（姓名、身份证号、证件有效期和核验状态），不保存身份证照片和人脸图像。您可以不进行实名认证，不影响其他功能。',
          emphasized: true,
        ),
        LegalSubheading('13. 会员购买与支付'),
        LegalParagraph(
          '您购买会员或AI次数时，我们会记录订单信息（订单号、商品、金额、支付渠道、支付状态、支付时间）和会员权益记录。Android 端支付由支付宝或微信支付完成，我们会将订单号、金额等交易信息提供给支付机构，支付密码、银行卡号等支付信息由支付机构直接收集，我们不会获取；iOS 端由 Apple 应用内购买完成，我们会接收 Apple 返回的交易标识和交易状态用于核验和发放权益，不会获取您的 Apple 账户和支付卡信息。',
        ),
        LegalSubheading('14. 广告'),
        LegalParagraph(
          '免费用户登录后，发现页会展示穿山甲（GroMore）横幅广告，有效会员不展示。我们已关闭广告SDK获取位置、电话状态、Wi-Fi信息、Android ID、OAID、IDFA、录音和应用列表的能力，并关闭个性化广告推荐。广告SDK收集的信息见第三部分的第三方SDK清单。',
          emphasized: true,
        ),
        LegalSubheading('15. 反馈、举报与申诉'),
        LegalParagraph('您提交意见反馈、举报或账号申诉时，我们会处理您填写的内容和自主提供的联系方式，用于处理您的问题。'),
        LegalSubheading('16. 无需征得同意的情形'),
        LegalParagraph(
          '根据法律规定，为订立或履行您作为一方当事人的合同所必需、为履行法定职责或义务所必需、为应对突发公共卫生事件或紧急情况下保护自然人生命健康和财产安全所必需等情形，我们处理个人信息无需取得您的同意。',
        ),
      ],
    ),
    LegalSection(
      id: 'permissions',
      title: '二、设备权限调用说明',
      blocks: [
        LegalParagraph('我们只在您使用对应功能时才申请权限，您可以随时在系统设置中关闭。关闭后对应功能无法使用，不影响其他功能。'),
        LegalTable(
          headers: ['权限', '使用场景', '拒绝后的影响'],
          rows: [
            [
              '相机',
              '拍摄头像、简历照片、身份证照片；扫描邀请二维码和官网登录二维码；实名认证时的人脸核验',
              '无法拍照和扫码，仍可从相册选择图片或手动输入邀请码',
            ],
            ['相册（照片）', '选择头像、简历照片、身份证照片或二维码图片；仅访问您选中的照片', '无法从相册选择图片'],
            ['网络', '与服务器通信、上传文件、加载图片和广告', '无法使用联网功能'],
            ['安装未知应用（仅Android）', '下载新版本安装包后调起系统安装', '无法通过App内更新安装新版本'],
          ],
        ),
        LegalParagraph(
          '此外：选择导入文件和保存导出文件使用系统文件选择器，不申请存储权限；仅在您点击“复制”时写入剪贴板，不读取剪贴板；在 Android 上仅查询微信、抖音（含抖音极速版）、支付宝是否安装，以调起登录、分享或支付，不获取完整应用列表。',
        ),
      ],
    ),
    LegalSection(
      id: 'sharing',
      title: '三、第三方SDK与对外提供',
      blocks: [
        LegalParagraph(
          '为实现相关功能，我们的App接入了以下第三方SDK，并委托以下服务商处理数据。我们会与其约定数据保护义务，要求其按本政策和法律法规处理个人信息。以下SDK均在您同意本政策后、使用对应功能时才初始化。',
        ),
        LegalTable(
          headers: ['名称及提供方', '使用目的与场景', '收集或处理的个人信息', '隐私政策'],
          rows: [
            [
              '穿山甲 GroMore 广告SDK（北京巨量引擎网络技术有限公司）',
              '免费用户登录后在发现页展示横幅广告、广告统计与反作弊（Android、iOS）',
              '设备型号、系统版本、应用信息、网络类型、IP地址、屏幕参数、广告展示与点击数据；已关闭位置、电话状态、Wi-Fi、Android ID、OAID、IDFA、应用列表和个性化推荐',
              'https://www.csjplatform.com/terms/gromoresdk-privacy',
            ],
            [
              '微信 OpenSDK（深圳市腾讯计算机系统有限公司）',
              '微信授权登录、将简历分享到微信（Android、iOS）',
              '微信授权码、OpenID/UnionID；授权后获取昵称和头像',
              'https://support.weixin.qq.com/cgi-bin/mmsupportacctnodeweb-bin/pages/RYiYJkLOrQwu0nb8',
            ],
            [
              '抖音开放平台SDK（北京抖音科技有限公司及其关联方）',
              '抖音授权登录（Android、iOS）',
              '抖音授权码、OpenID、授权状态，以及SDK运行所需的设备型号、系统版本、网络状态',
              'https://developer.open-douyin.com/docs/resource/zh-CN/dop/operation-standard/service-protocol/douyin-sdk-privacy-policy',
            ],
            [
              'App 支付宝客户端SDK（支付宝支付科技有限公司）',
              'Android 端支付宝支付会员和AI次数',
              '可变更设备唯一标识、基本设备信息、网络信息，用于支付安全风控和履行反洗钱等法定义务；订单信息',
              'https://opendocs.alipay.com/open/54/01g6qm',
            ],
            [
              '百度人脸采集SDK（北京百度网讯科技有限公司）',
              '实名认证时的活体检测与身份核验（仅在您单独同意后调用）',
              '现场人脸图像、姓名、身份证号，以及设备型号、系统版本、网络信息（用于安全风控）',
              'https://ai.baidu.com/ai-doc/REFERENCE/Ul028s5hk',
            ],
            [
              'Google ML Kit 条码识别（Google LLC，mobile_scanner 插件内置）',
              'Android 端扫描二维码，在设备本地识别画面',
              '相机画面仅在本地处理不上传；SDK可能向Google发送设备型号、系统版本、应用包名、SDK版本等运行指标',
              'https://developers.google.com/ml-kit/terms',
            ],
          ],
        ),
        LegalParagraph('我们还委托以下服务商在服务端处理数据（不在您的设备上运行）：'),
        LegalParagraph('（1）七牛云（上海七牛信息技术有限公司）：存储您上传的头像、简历照片、导入文件和导出文件。'),
        LegalParagraph('（2）火山引擎短信服务（北京火山引擎科技有限公司）：向您的手机号发送登录及绑定验证码，处理手机号和验证码。'),
        LegalParagraph('（3）百度智能云（北京百度网讯科技有限公司）：实名认证时识别身份证照片，处理身份证照片、姓名、身份证号。'),
        LegalParagraph(
          '（4）腾讯云文本内容安全（腾讯云计算（北京）有限责任公司）：对您公开发布的文章标题和正文、评论与回复、修改意见，以及社区求指点投稿的标题、提问和已隐藏个人信息区的简历快照的文字内容进行自动内容审核，不包含您的手机号和账号ID。',
        ),
        LegalParagraph('（5）支付宝、微信支付（财付通支付科技有限公司）、Apple：处理会员和AI次数的支付及交易核验。'),
        LegalSubheading('向 DeepSeek 提供个人信息'),
        LegalParagraph(
          '在您单独同意后，我们会向杭州深度求索人工智能基础技术研究有限公司（DeepSeek 开放平台，联系方式：api-service@deepseek.com）提供第一部分第6、7项所述内容，用于简历生成、诊断优化、单段生成和文件导入；提供方式为通过加密接口传输，由其大模型处理后返回结果。根据该平台的隐私政策，DeepSeek 可能在加密和去标识化后使用输入与输出进行模型训练、评估和改进，因此该提供属于向其他个人信息处理者提供，而非单纯的委托处理。首次使用上述功能前，我们会弹窗告知并征求您的单独同意；您不同意的，只是无法使用AI功能，不影响其他功能。您可以随时在“设置—AI 功能授权”中撤回同意，撤回不影响撤回前已进行的处理。我们会记录您同意和撤回的时间及对应的说明版本，作为依法取得同意的凭证，注销账号时一并删除。详见《DeepSeek开放平台隐私政策》https://cdn.deepseek.com/policies/zh-CN/deepseek-open-platform-privacy-policy.html',
          emphasized: true,
        ),
        LegalParagraph(
          '除上述情形及法律法规规定的情形外，我们不会向第三方共享、转让您的个人信息，也不会公开披露。如发生合并、分立、解散、被宣告破产等情形需要转移个人信息的，我们会告知接收方的名称和联系方式，并要求其继续履行本政策义务。您主动将简历导出、分享给他人的，接收方由您选择。',
          emphasized: true,
        ),
      ],
    ),
    LegalSection(
      id: 'storage-and-security',
      title: '四、个人信息的存储与保护',
      blocks: [
        LegalParagraph(
          '4.1 存储地点：我们在中华人民共和国境内收集和产生的个人信息存储在境内。Android 端扫码使用的 Google ML Kit 可能向 Google 发送设备型号、系统版本、应用包名、SDK版本等运行指标（见第三部分），不包含相机画面和您的账号信息；除此之外，我们不会向境外提供您的个人信息。如未来需要，我们会依法履行法定程序并另行取得您的单独同意。',
          emphasized: true,
        ),
        LegalParagraph(
          '4.2 存储期限：我们只在实现目的所必需的最短期限内保存您的个人信息。账号信息和简历在您使用期间保存，您删除或注销后按本政策删除或匿名化；网络日志依法保存不少于六个月；交易记录依法保存不少于三年；系统备份数据保存30日，超过30日后清除。超出上述期限后，我们会删除或匿名化处理。',
        ),
        LegalParagraph(
          '4.3 安全措施：我们采用HTTPS加密传输；登录凭证保存在设备系统安全存储中；服务端仅保存令牌摘要；聊天消息和实名信息加密存储；私密图片采用短期签名访问；对员工访问权限进行控制。',
        ),
        LegalParagraph(
          '4.4 如发生个人信息泄露等安全事件，我们会立即启动应急预案，采取补救措施，并按法律要求通过站内通知、短信等方式告知您事件情况和应对建议，同时向主管部门报告。',
        ),
      ],
    ),
    LegalSection(
      id: 'rights',
      title: '五、您的权利',
      blocks: [
        LegalParagraph('您可以通过以下方式管理您的个人信息：'),
        LegalParagraph(
          '（1）查阅和更正：在“我的”页面及资料编辑页查阅、修改昵称、头像、简介；在简历编辑页查阅、修改简历；在“设置—账号安全”查看手机号和登录设备。',
        ),
        LegalParagraph('（2）删除：删除简历、文章、评论，取消点赞和收藏；您也可以联系我们删除其他个人信息。'),
        LegalParagraph('（3）复制与转移：您可以导出简历为PDF或DOCX文件；需要获取其他个人信息副本的，可以联系我们。'),
        LegalParagraph('（4）控制公开范围：在设置中关闭公开个人主页。'),
        LegalParagraph(
          '（5）撤回同意：您可以在“设置—AI 功能授权”中撤回向 DeepSeek 提供信息的同意；可以在系统设置中关闭相机、相册等权限，或停止使用对应功能来撤回授权；撤回不影响此前基于您同意已进行的处理。您也可以在“设置”中查看本政策，并通过注销账号撤回全部同意。',
        ),
        LegalParagraph('（6）注销账号：见本政策第六部分。'),
        LegalParagraph(
          '（7）其他：您可以通过第十部分的联系方式提出请求、投诉或举报，我们会在验证身份后15个工作日内答复。对我们的答复不满意的，您可以向网信、工信、市场监管等主管部门投诉。',
        ),
      ],
    ),
    LegalSection(
      id: 'deletion',
      title: '六、注销账号',
      blocks: [
        LegalParagraph(
          '您可以在App“设置—账号安全—账号注销”中申请注销，按提示输入确认语句后提交。提交后您的账号会在所有设备上退出登录，注销将在30天冷静期后执行；冷静期内您重新登录该账号并在提示中确认继续使用，即可撤回申请。',
        ),
        LegalParagraph(
          '注销完成后，我们将删除您的个人信息或进行匿名化处理，包括账号资料、简历、文章、评论、聊天记录、会员及次数记录等，法律法规要求保留的（如交易记录、网络日志）除外，保留期满后删除。备份数据保存30日，超过30日后清除，因此注销完成后至多再经30日，您的数据会从备份中全部清除。',
          emphasized: true,
        ),
      ],
    ),
    LegalSection(
      id: 'minors',
      title: '七、未成年人个人信息保护',
      blocks: [
        LegalParagraph(
          '本服务主要面向成年求职者和职场人士。未满18周岁的未成年人使用本服务前，应取得监护人同意。我们不会主动收集不满14周岁儿童的个人信息；如发现在未取得监护人同意的情况下收集了儿童个人信息，我们会尽快删除。监护人对未成年人个人信息有疑问的，可以通过第十部分的方式联系我们。',
        ),
      ],
    ),
    LegalSection(
      id: 'cookies',
      title: '八、本地存储',
      blocks: [
        LegalParagraph(
          '为保持登录状态和提升体验，App会在您的设备上保存登录凭证、设备标识、图片缓存和临时文件。您可以在“设置”中清理缓存；清理本地缓存不会删除服务器上的数据。',
        ),
      ],
    ),
    LegalSection(
      id: 'updates',
      title: '九、本政策的更新',
      blocks: [
        LegalParagraph(
          '我们可能适时更新本政策。更新后会在App内公布，并在页面顶部标注更新日期。对于重大变更（如处理目的、个人信息种类、第三方共享对象发生变化），我们会通过弹窗等显著方式通知您，并在需要时重新征得您的同意。',
        ),
      ],
    ),
    LegalSection(
      id: 'contact',
      title: '十、联系我们',
      blocks: [
        LegalParagraph(
          '个人信息处理者：$_operator；统一社会信用代码：$_creditCode；注册地址：$_address；个人信息保护负责人邮箱：$_contactEmail；ICP备案号：$_icpRecord。我们会在收到您的请求后15个工作日内答复。',
        ),
      ],
    ),
  ],
);
