/// Locally bundled documents. Opening these documents does not send a request,
/// grant consent, or leave the app.
enum LegalDocumentKind { userAgreement, privacyPolicy }

const legalAgreementVersions = {'terms': '1.0', 'privacy': '1.0'};

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

const userAgreementDocument = LegalDocument(
  kind: LegalDocumentKind.userAgreement,
  title: '用户协议',
  metadata: ['更新日期：2026年10月【　】日', '生效日期：2026年10月【　】日'],
  introduction: [
    LegalParagraph(
      '重要提示：在您注册、登录或使用博简App服务前，请务必审慎阅读并充分理解本协议全部条款，特别是以粗体标识的免除或减轻责任、争议解决、虚拟权益及授权条款。如对条款有疑问，请通过【客服邮箱/电话】咨询。如您是未成年人，请在监护人指导下阅读本协议，并在取得监护人同意后使用本服务。 您勾选“同意”完成登录，或以其他方式实际使用本服务的，即视为您已接受本协议全部内容；不同意任何条款的，请停止注册或使用。',
      emphasized: true,
    ),
  ],
  sections: [
    LegalSection(
      id: 'definitions',
      title: '第一条 定义',
      blocks: [
        LegalParagraph(
          '1.1 博简／本服务：指由【运营主体全称】（以下简称“我们”）运营的移动应用程序“博简”（含Android及iOS客户端，当前源码版本1.0.0+1）及相关服务，业务接口为 bojian.kelance.cn。',
        ),
        LegalParagraph(
          '1.2 用户／您：指通过微信或抖音授权登录并使用本服务的自然人。尚未注册的用户，仅在明确确认注册后创建账号。',
        ),
        LegalParagraph(
          '1.3 用户内容：指您在本服务中填写、上传、发布、发送的文字、图片、文件及其他信息，包括简历内容、文章、评论、修改意见、企业福利投稿、举报说明及聊天消息等。',
        ),
      ],
    ),
    LegalSection(
      id: 'services',
      title: '第二条 服务内容与功能边界',
      blocks: [
        LegalParagraph(
          '2.1 本服务当前提供：个人资料编辑、简历创建编辑与保存、简历照片裁剪上传、简历预览与导出（PDF／DOCX）、文件导入与AI解析、免费模板领取与积分模板购买、文章发布、评论与互动、简历求指点与修改意见、好友搜索与聊天、站内通知、企业公开福利信息浏览与提交、意见反馈、账号申诉、登录设备管理及账号注销申请。',
        ),
        LegalParagraph('2.2 您理解并确认本服务的以下边界：'),
        LegalParagraph(
          '（1）博简是信息整理与表达辅助工具，不提供招聘职位投递、雇主接收简历、面试安排或录用承诺等交易服务，我们不对您获得面试、录用或任何职业结果作出任何明示或默示的保证；',
          emphasized: true,
        ),
        LegalParagraph('（2）应用内“AI简历优化”功能目前处于预告状态、尚未开放；文件导入中的AI解析功能已实际接入；'),
        LegalParagraph('（3）当前不提供充值、提现、银行账户管理、现金支付、实名认证、创作者认证及模板创作发布功能；'),
        LegalParagraph(
          '（4）企业福利模块仅收录企业依法公开的信息；不同岗位、时期、地区的待遇可能不同，相应内容仅供参考，以企业最新公开信息为准；点击来源链接将在外部浏览器打开，相关页面内容由对应企业或网站负责。',
          emphasized: true,
        ),
        LegalParagraph(
          '2.3 简历导出文件在您的手机本地生成；DOCX格式导出文件的正文为页面图像，文字无法直接编辑。您通过系统保存或分享面板将导出文件交付其他应用的，后续使用由您自行控制，我们无法亦不会追踪。',
        ),
      ],
    ),
    LegalSection(
      id: 'consent',
      title: '第三条 协议的订立与同意机制',
      blocks: [
        LegalParagraph('3.1 本协议以数据电文形式订立。您可通过登录页及“隐私与设置”页随时查阅本协议及《隐私政策》。'),
        LegalParagraph(
          '3.2 在您同意本协议及《隐私政策》之前，我们不会发起微信或抖音授权、图形验证或短信验证码请求。图形验证与短信请求仅在您主动选择绑定手机号时发起；选择“暂不同意”将中止相应流程，不影响您此后重新作出同意的选择。',
        ),
        LegalParagraph(
          '3.3 我们可能适时修订本协议。涉及您重大权益变更的，我们将通过弹窗、站内通知等显著方式告知；如您不同意修订内容，应停止使用本服务，继续使用视为接受修订后的协议。',
          emphasized: true,
        ),
      ],
    ),
    LegalSection(
      id: 'account',
      title: '第四条 账号、登录与会话管理',
      blocks: [
        LegalParagraph(
          '4.1 您可使用本人控制的微信或抖音账号授权登录，并自愿绑定本人控制的中国大陆手机号；暂时跳过绑定不影响使用其他功能。不同平台账号分别识别，不会根据昵称或手机号自动合并。账号仅限您本人使用，不得出借、转让或与他人共用。',
        ),
        LegalParagraph('4.2 登录成功后，系统向您下发访问令牌与刷新令牌，登录凭证保存于设备系统安全存储中。'),
        LegalParagraph(
          '4.3 “隐私与设置—账号安全”展示您账号下的有效登录会话（含设备型号、操作系统及登录时间）。您可主动退出任一登录设备；退出当前设备即结束本次登录。您仅能管理本人账号下的会话。',
        ),
        LegalParagraph(
          '4.4 普通退出登录将清理本机凭证与业务状态、撤销当前服务端会话，但不会删除您的服务端账号及简历数据，也不会清除本机保留的随机设备标识。',
        ),
        LegalParagraph(
          '4.5 账号注销：您需在“账号安全—账号注销”中输入确认语句“我已确认并主动注销此账号”提交申请。提交后立即撤销您账号的全部登录会话，注销将于30日后执行。 30日冷静期内的撤回方式为【待补充：撤回渠道】。注销完成后，您账号下的数据将按《隐私政策》处理，您的积分余额及已获取模板的使用权益将一并终止，请在此前自行安排处置【待与业务确认余额处理规则】。',
          emphasized: true,
        ),
      ],
    ),
    LegalSection(
      id: 'user-content',
      title: '第五条 用户内容',
      blocks: [
        LegalParagraph(
          '5.1 您应对自己填写、上传、发布或发送的用户内容的合法性负责，并保证不侵犯任何第三方权利；内容涉及第三方个人信息的，您应确保已获得该等第三方的同意。',
        ),
        LegalParagraph(
          '5.2 除法律禁止的情形外，您在发布用户内容时即授予我们在本服务内为展示、传播及推广之目的，免费、非独占、不可撤销地使用该内容的权利；该许可不改变内容的权属。',
          emphasized: true,
        ),
        LegalParagraph(
          '5.3 您可删除简历、撤回文章、删除评论、取消点赞或收藏。删除或撤回操作不影响撤回前已被其他用户查看、接收或另行保存的内容。',
        ),
      ],
    ),
    LegalSection(
      id: 'conduct',
      title: '第六条 用户行为规范',
      blocks: [
        LegalParagraph('6.1 您承诺不利用本服务从事下列行为：'),
        LegalParagraph(
          '（一）发布、传播危害国家安全、谣言、淫秽色情、侮辱诽谤、欺诈、恶意营销、侵犯他人隐私或合法权益及其他违法内容；',
        ),
        LegalParagraph('（二）冒用他人或企业身份，伪造资质或信息；'),
        LegalParagraph('（三）实施干扰服务正常运行的行为，包括外挂、自动化攻击、恶意刷取积分或绕过交易流程等；'),
        LegalParagraph(
          '（四）在企业福利模块提交劳动合同、工资明细、未公开制度、内网内容、员工群聊记录、匿名泄漏材料等非公开信息，或任何涉密、侵犯商业秘密的内容；',
        ),
        LegalParagraph('（五）在举报或权利异议说明中复制商业秘密原文、身份证件号码、工资明细或他人个人信息；'),
        LegalParagraph('（六）其他违反法律法规或公序良俗的行为。'),
        LegalParagraph(
          '6.2 违反前述约定的，我们有权视情节采取内容退回、下架、限制功能、封禁账号等措施，保存相关记录并依法向主管部门报告；构成犯罪的，依法移交司法机关。 您可通过账号申诉渠道对处理结果提出申诉。',
        ),
      ],
    ),
    LegalSection(
      id: 'guidance',
      title: '第七条 简历求指点与修改意见的特别约定',
      blocks: [
        LegalParagraph('7.1 您可将在社区公开投稿求指点，或定向邀请1至20位好友。'),
        LegalParagraph(
          '7.2 系统对求指点快照执行固定字段过滤：隐藏您的个人信息区、照片、项目链接、学校名称、公司名称、项目名称及证书颁发机构，并在展示端另行遮挡。但简历标题、您填写的提问及未列入隐藏范围的职位、经历描述、技能、求职意向等仍将向接收方展示，且可能包含可识别您身份的线索。字段过滤不等于匿名化处理，请您在提交前自行审慎审查快照内容。',
          emphasized: true,
        ),
        LegalParagraph(
          '7.3 其他用户可对可见简历区域提出评论、文字替换或增删等修改意见；您可采纳或拒绝，采纳内容将在保存时合并至原简历并形成修订版本记录。修改意见的内容与责任由提出者承担；您对是否采纳享有完全控制权。',
        ),
      ],
    ),
    LegalSection(
      id: 'points-and-templates',
      title: '第八条 积分与模板服务',
      blocks: [
        LegalParagraph(
          '8.1 积分是本服务内向您提供的虚拟权益，不代表任何现金价值，不可兑换法定货币、不可转让、不可提现。 您可于每个自然日（北京时间）领取一次每日积分（当前为100积分），积分可用于购买积分模板。购买时后端将在同一事务中完成订单、购买记录、积分扣减及账目登记；网络重试通过同一请求标识防止重复扣减。',
          emphasized: true,
        ),
        LegalParagraph(
          '8.2 您通过免费获取或积分购买取得模板的，仅取得为制作您个人简历之目的在本服务内使用该模板的许可，不取得模板及其元素的著作权或其他知识产权；未经权利人书面许可，不得转售、再分发模板源文件或用于其他商业用途。 购买确认页面展示的模板、积分价格、模板版本及购买协议版本标识（当前为 template-purchase-v1）构成订单组成部分。',
          emphasized: true,
        ),
        LegalParagraph(
          '8.3 当前版本未提供退款或模板转让功能。积分有效期、退款规则、异常扣减处理、模板下架后已购模板的使用及账号注销时的积分处理规则：【待补充】。',
          emphasized: true,
        ),
      ],
    ),
    LegalSection(
      id: 'intellectual-property',
      title: '第九条 知识产权',
      blocks: [
        LegalParagraph(
          '本服务软件系统、界面、商标标识、模板及我们自有内容的知识产权归我们或相应权利人所有。未经书面许可，不得对本服务进行反向工程、反向编译或商用。',
        ),
      ],
    ),
    LegalSection(
      id: 'liability',
      title: '第十条 免责声明与责任限制',
      blocks: [
        LegalParagraph(
          '10.1 本服务按“现状”提供，我们不保证服务不中断、无错误。因系统维护等原因中断服务的，我们将尽合理努力提前或及时告知。',
          emphasized: true,
        ),
        LegalParagraph(
          '10.2 在适用法律允许的最大范围内，我们对任何间接损失、利润损失、数据丢失不承担责任；我们对您承担的赔偿责任总额，以您就相关服务实际支付的积分对应对价（如无，则以零元为限）为上限。',
          emphasized: true,
        ),
        LegalParagraph(
          '10.3 您通过本服务获取的企业福利信息、社区内容、求指点意见均为用户生成或来源于公开渠道的参考性信息，不构成任何形式的承诺、建议或保证；您据此作出的任何决定及后果由您自行承担。',
          emphasized: true,
        ),
      ],
    ),
    LegalSection(
      id: 'notices',
      title: '第十一条 通知与送达',
      blocks: [LegalParagraph('本协议项下通知通过App弹窗、站内通知或您申诉/反馈中主动提供的联系方式作出。')],
    ),
    LegalSection(
      id: 'disputes',
      title: '第十二条 法律适用与争议解决',
      blocks: [
        LegalParagraph(
          '本协议适用中华人民共和国法律。因本协议产生的争议协商不成的，任何一方均可向【运营主体住所地】有管辖权的人民法院提起诉讼。',
          emphasized: true,
        ),
      ],
    ),
    LegalSection(
      id: 'additional-terms',
      title: '第十三条 附则',
      blocks: [
        LegalParagraph('13.1 本协议部分条款无效不影响其他条款的效力。'),
        LegalParagraph(
          '13.2 运营主体信息（待补充）：主体全称、统一社会信用代码、住所地、客服邮箱、客服电话、ICP备案号【待补充】。',
        ),
      ],
    ),
  ],
);

const privacyPolicyDocument = LegalDocument(
  kind: LegalDocumentKind.privacyPolicy,
  title: '隐私政策',
  metadata: [
    '更新日期：2026年10月【　】日',
    '生效日期：2026年10月【　】日',
    '版本：V2.0（替代2026年9月3日版本）',
  ],
  introduction: [
    LegalParagraph(
      '重要提示：珠海科岚盛网络科技有限公司（以下简称“我们”）是博简App的个人信息处理者。请您仔细阅读本政策，特别是加粗条款以及“文件导入与外部AI解析”“公开展示”“账号注销”等章节。在您同意本政策前，我们不会发起微信或抖音授权、图形验证或短信验证码请求。 如有疑问，请联系个人信息保护负责人：admin@kelantech.cn 18998541278【通信地址，待补充】。',
      emphasized: true,
    ),
  ],
  sections: [
    LegalSection(
      id: 'collection',
      title: '一、我们如何收集和使用您的个人信息',
      blocks: [
        LegalParagraph(
          '我们遵循合法、正当、必要和最小化原则，仅收集实现服务功能所必要的信息。以下标注“可选”的信息，您拒绝提供不影响您登录及使用其他功能。',
        ),
        LegalSubheading('（一）账号注册与登录（按所选方式必要）'),
        LegalParagraph(
          '选择微信登录时，我们处理微信授权码及服务端校验得到的微信账号标识（OpenID／UnionID）、账号ID，用于识别账号、判断注册状态及完成登录。首次注册会获取您授权提供的昵称、头像，仅在您明确确认后创建账号并保存为初始个人资料；此后可自行修改或移除，后续登录不会覆盖您的修改。微信登录不会向我们提供您在微信绑定的手机号。',
        ),
        LegalParagraph(
          '选择抖音登录时，App 在您同意协议并主动操作后初始化抖音开放平台 SDK，处理应用及设备平台、系统版本等 SDK 运行信息与授权请求状态；服务端使用一次性授权码验证抖音账号标识（OpenID），用于识别账号、判断注册状态及完成登录。首次注册会获取您授权提供的昵称、头像，仅在您明确确认后创建账号并保存为初始个人资料；此后可自行修改或移除，后续登录不会覆盖您的修改。SDK 的可选行为统计关闭；不会向 App 返回抖音访问令牌，也不会自动读取或绑定您的手机号。',
        ),
        LegalSubheading('手机号绑定（可选）'),
        LegalParagraph(
          '仅在您主动选择绑定手机号时处理：手机号、图形挑战与滑块位移、短信验证码及其发送/验证状态。用于验证手机号归属、将手机号绑定到当前账号，以及短信限流与验证码校验。服务端保存手机号用于联系与安全验证，验证码与限流使用相应摘要。您可以暂时跳过手机号绑定，不影响登录及使用其他功能。',
        ),
        LegalSubheading('（二）登录会话（必要）'),
        LegalParagraph(
          '访问令牌、刷新令牌（服务端仅保存其摘要）、会话ID、登录及过期时间、撤销状态。用于保持登录、请求验证与设备管理。凭证保存于设备系统安全存储。',
        ),
        LegalSubheading('（三）设备信息（必要，自动收集）'),
        LegalParagraph(
          '应用初始化时读取：由安全随机数在本机生成的随机设备标识（不以IMEI、IMSI、MAC地址或广告标识生成）、平台、应用版本、设备型号与系统版本。用于设备绑定、会话展示与兼容适配。如您存在有效历史会话，启动时将自动加载业务数据并建立实时连接。',
        ),
        LegalSubheading('（四）网络与日志信息（必要，自动收集）'),
        LegalParagraph(
          '连接IP、请求标识、接口路径、方法、响应状态、耗时及安全事件。用于网络通信、限流、故障排查与账号安全。原始IP仅在连接处理、内存缓存及限流缓存中处理，不写入您的城市字段或任何公开接口。',
        ),
        LegalSubheading('（五）IP归属城市'),
        LegalParagraph(
          '登录后的请求触发，由服务端本地IP归属数据库推导城市（无法确定时采用省份或国家）。我们不使用GPS定位权限，亦不向在线定位服务查询。 该城市用于您的个人主页及作者信息展示（受您的公开状态控制）。',
        ),
        LegalSubheading('（六）个人资料（可选）'),
        LegalParagraph(
          '昵称、自我介绍、头像（可用系统图案或您指定的图片）、在职状态。账号ID、注册时间、公开/私密状态及IP推导城市由系统生成。',
        ),
        LegalSubheading('（七）简历信息（可选）'),
        LegalParagraph(
          '您主动填写的：姓名、性别、手机号、邮箱、出生日期（或年龄显示方式）、照片及裁剪信息；工作经历（公司、行业、职位、起止时间、在职状态、工作内容）；教育经历（学校、专业、学历、时间、在校经历、论文题目）；项目经历（名称、角色、时间、描述、成果、链接）；技能与证书；求职状态与意向（目标城市、职位、行业、薪资及偏好）；以及简历管理信息（名称、模板关联、创建/更新时间、修订版本、顺序、指点修改与采纳记录）。您可不上传简历照片、不使用导入、不发起求指点，仍可使用手动编辑的相应简历功能。 照片支持JPG/PNG/WebP、5MB以内，裁剪在本机完成后上传。简历删除将从您的简历库中移除该简历；后端以删除状态与删除时间标记处理，并非立即物理清除全部关联数据【最终清除及备份清理期限待补充】。',
        ),
        LegalSubheading('（八）文件导入与外部AI解析（可选，另行单独同意）'),
        LegalParagraph(
          '您通过系统文件选择器或微信转交指定文件（PDF/DOC/DOCX，20MB以内，我们不读取微信聊天记录，亦不遍历您的文件），点击“上传并解析”后：',
        ),
        LegalParagraph('文件上传至七牛对象存储，建立解析任务（记录文件名、大小、类型、用途、所属用户、对象标识及状态）；'),
        LegalParagraph(
          '后端将您导入的完整源文件（包括其中的文字、照片及其他全部内容）及文件名、文件类型发送给外部AI文件解析服务提供方，获取提取文字（当前最多保留30000字符）；',
          emphasized: true,
        ),
        LegalParagraph('后端将提取的简历文字发送给外部AI模型服务提供方，整理为结构化字段；', emphasized: true),
        LegalParagraph('解析结果进入待确认状态，经您检查、修改并确认保存后，才会创建简历。'),
        LegalParagraph(
          '该功能涉及向第三方提供您的个人信息（含可能包含于文件中的姓名、联系方式、经历等），我们将在您使用该功能时另行通过单独弹窗征得您的同意。 导入文件中如含身份证件号码等敏感信息，将一并传输，请您避免在导入文件中包含非必要敏感信息。取消导入不会自动创建简历；已上传文件、解析结果及服务商侧副本的清理期限：【待补充】。',
          emphasized: true,
        ),
        LegalSubheading('（九）公开展示与社区互动'),
        LegalParagraph(
          '公开状态下，您的个人主页可展示昵称、用户ID、头像、简介、城市、在职状态及注册时间；公开主页接口不返回您的手机号，并受公开状态及屏蔽关系控制。您可通过“公开个人介绍”开关控制公开状态；关闭该开关不会删除或撤回您已发布的文章、评论及其他公开投稿，需另行操作删除。 好友搜索按昵称或博简ID返回账号标识、昵称及好友关系状态。文章、评论、点赞、收藏、点踩等操作形成账号与内容的关联记录；站内通知将相应互动告知目标用户。',
          emphasized: true,
        ),
        LegalSubheading('（十）简历求指点'),
        LegalParagraph(
          '社区投稿经审核后公开显示；好友邀请向您选择的1至20位好友定向发送，后端校验好友关系。发送内容包括简历标题、您的提问、经过滤的简历快照（固定隐藏个人信息区、照片、项目链接、学校、公司、项目名称及证书颁发机构，隐藏字段的富文本亦被排除，展示前另有遮挡）及来源简历关联。剩余的时间、职位、经历描述、技能及求职意向仍将提供给接收方；简历标题、提问及您自由填写的描述可能包含身份线索，字段过滤不等于匿名化。 修改意见功能处理建议人身份、选中文本、定位、原文与替换内容、时间及采纳/拒绝状态；修订版本记录仅作者本人可访问。',
          emphasized: true,
        ),
        LegalSubheading('（十一）聊天与站内通知'),
        LegalParagraph(
          '文字聊天处理好友关系、会话成员、消息内容、发送者、时间、回复关联及已读状态。消息载荷采用服务端AES-256-GCM加密，在向会话成员返回时解密；该方式不属于端到端加密。 通知处理互动类型、关联对象、投递及已读记录。',
        ),
        LegalSubheading('（十二）积分与模板'),
        LegalParagraph(
          '用户ID、积分余额与账目、领取日期、订单ID、模板ID、价格、版本及购买状态。用于防重复领取、交易校验、权益登记。我们不收集充值支付凭证、提现银行资料或实名认证材料。',
        ),
        LegalSubheading('（十三）反馈、申诉与举报（可选）'),
        LegalParagraph(
          '意见反馈处理用户ID、类别及文字说明，当前不自动附带任何诊断文件；账号申诉处理账号对象及原因说明，联系方式由您自主填写；企业福利举报处理关联条目、原因及您提交的说明。',
        ),
      ],
    ),
    LegalSection(
      id: 'permissions',
      title: '二、设备权限与本地功能说明',
      blocks: [
        LegalTable(
          headers: ['系统功能', '用途'],
          rows: [
            ['网络（INTERNET）', '接口通信、实时连接、文件上传与图片下载'],
            ['系统文件选择器', '您主动选择导入文件、保存导出文件；不申请广泛存储/相册权限'],
            ['系统分享面板', '将导出文件交由您选择的应用'],
            ['剪贴板写入', '仅在您点击“复制博简ID”时写入；不自动读取剪贴板'],
            ['微信与抖音可见性查询（Android）', '用于微信文件转交及微信、抖音登录时查询对应客户端；不获取完整已安装应用列表'],
            ['通知与权限设置跳转', '引导您至系统设置'],
          ],
        ),
        LegalParagraph(
          '当前版本未声明相机、麦克风、通讯录及GPS定位权限，未接入任何广告或统计分析SDK；最终以应用发行包实际申请为准。 本地缓存与临时文件（图片缓存、裁剪、导出临时文件）可在设置页清理或于流程结束时自动清理；清理本机缓存不删除服务端数据。市场模板在本地WebView渲染，我们限制模板自带脚本、外部导航与网络资源加载。',
        ),
      ],
    ),
    LegalSection(
      id: 'sharing',
      title: '三、对外提供（委托处理与共享）',
      blocks: [
        LegalTable(
          headers: ['第三方', '数据与用途', '备注'],
          rows: [
            ['七牛对象存储', '简历源文件、头像、简历照片的上传存储与展示', '私有图片采用短期签名访问；存储地域待补充'],
            ['短信服务提供方【腾讯云/配置网关，待确认】', '手机号、验证码及有效期', '发送绑定验证码；启用主体与地域待补充'],
            [
              '微信开放平台 SDK（腾讯，Fluwx 接入）',
              '微信授权码、OpenID/UnionID，用于微信授权登录及识别账号；首次注册时获取授权昵称、头像作为初始资料',
              '仅在同意协议并主动选择微信登录后发起授权；经微信确认后获取账号标识',
            ],
            [
              '抖音开放平台 SDK',
              '抖音授权码、OpenID、授权状态及 SDK 运行所需应用与设备信息，用于授权登录及识别账号；首次注册时获取授权昵称、头像作为初始资料',
              '仅在同意协议并主动选择抖音登录后初始化；关闭可选行为统计，不自动获取手机号',
            ],
            [
              '外部AI文件解析及模型服务【主体待补充】',
              '完整导入文件及文件名；提取的简历文字',
              '解析与结构化整理；主体、地域、保留期限及是否用于模型训练：待补充；使用时另行单独同意',
            ],
          ],
        ),
        LegalParagraph(
          '您主动导出、分享文件或经外部浏览器打开链接的，接收方由您或系统选择。除上述情形及法定情形外，我们不会共享、转让您的个人信息；涉及合并、分立等情形将另行通知并要求承继方继续履行本政策。',
          emphasized: true,
        ),
      ],
    ),
    LegalSection(
      id: 'storage-and-security',
      title: '四、存储地点、期限与安全措施',
      blocks: [
        LegalParagraph(
          '4.1 存储地点：【待补充：业务数据库、文件、日志、备份及外部AI处理的实际国家/地区】。如存在向境外提供个人信息的情形，我们将依法履行数据出境程序并另行取得您的单独同意。',
          emphasized: true,
        ),
        LegalParagraph(
          '4.2 存储期限： 以实现处理目的所必需的最短时间为限；【各类数据（账号、简历及版本、导入文件与解析结果、聊天、交易、反馈、日志、备份）的分别保留期限待补充】。网络日志依法留存不少于六个月；法律另有规定的从其规定。',
        ),
        LegalParagraph(
          '4.3 安全措施（已实施）：全业务接口HTTPS传输；登录凭证与设备标识存于系统安全存储；服务端仅保存刷新令牌摘要；账号及简历读取校验归属或可见范围；聊天载荷服务端加密；私有图片短期签名链接；Android端禁止系统备份；模板运行环境限制外部脚本与网络资源。',
        ),
        LegalParagraph(
          '4.4 发生个人信息泄露、篡改、丢失等安全事件的，我们将立即启动应急处置，采取措施将危害降到最低，并及时以推送、站内通知等方式告知您事件基本情况、我们的处置措施及您可采取的减轻危害措施；依法需向监管部门报告的，我们将履行报告义务。',
        ),
      ],
    ),
    LegalSection(
      id: 'rights',
      title: '五、您的权利',
      blocks: [
        LegalParagraph(
          '您可通过应用内功能行使以下权利：查阅与更正个人资料；更换或移除头像、编辑或删除简历；控制公开介绍状态；取消点赞、收藏等互动；管理并退出登录设备；退出登录；撤回同意（相应功能随之不可用）；注销账号。复制权及个人信息导出：当前应用内暂无一键导出全部个人数据的入口，您可通过【客服/申诉渠道】提出请求，我们将在核实身份后通过合理方式向您提供。 我们将在收到请求后15个工作日内答复；无法满足的，将说明理由。您也可向网信、工信等主管部门投诉举报。',
        ),
      ],
    ),
    LegalSection(
      id: 'deletion',
      title: '六、账号注销',
      blocks: [
        LegalParagraph(
          '您可通过“账号安全—账号注销”输入确认语句提交申请。提交后立即撤销全部登录会话，注销于30日后执行；冷静期内您可通过【待补充：撤回渠道】撤回申请。 届满后我们将删除或匿名化您的账号信息及相关个人信息，法律要求留存的除外。【待补充：最终删除数据范围、保留例外、共享快照及历史互动记录处理、备份清理周期】。',
          emphasized: true,
        ),
      ],
    ),
    LegalSection(
      id: 'minors',
      title: '七、未成年人保护',
      blocks: [
        LegalParagraph(
          '本服务面向求职及职业发展用户，不面向未成年人提供服务。【待补充：最低使用年龄、年龄核验及监护人流程】。我们不在明知的情况下处理不满14周岁未成年人的个人信息；监护人发现其子女未经同意使用本服务的，可联系我们删除相关信息。',
        ),
      ],
    ),
    LegalSection(
      id: 'updates',
      title: '八、政策更新',
      blocks: [
        LegalParagraph('本政策如发生重大变更，我们将通过弹窗、站内通知等显著方式告知；涉及单独同意事项的，将另行征得您的同意。'),
      ],
    ),
    LegalSection(
      id: 'contact',
      title: '九、联系我们',
      blocks: [
        LegalParagraph(
          '个人信息保护负责人：冯子健；邮箱：fengzijian@kelantech.cn；电话：18998541278；通信地址：【　】。',
        ),
      ],
    ),
  ],
);
