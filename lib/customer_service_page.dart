import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' show Random, max;

import 'package:file_selector/file_selector.dart' show XFile;
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:vector_graphics/vector_graphics.dart' show AssetBytesLoader;

import 'api/bojian_api.dart';
import 'app_icons.dart';
import 'photo_source_sheet.dart';
import 'profile_avatar.dart';
import 'resume_importer.dart' show ResumeUpload, uploadResumeDocument;
import 'resume_photo.dart' show validateResumePhoto;
import 'support_attachment.dart';
import 'app_page_bar.dart';
import 'app_store.dart';
import 'confirmation_dialog.dart';
import 'design.dart';
import 'membership_page.dart' show MembershipWalletPage, membershipFaqs;
import 'order_history_page.dart';
import 'legal_document.dart';
import 'legal_document_page.dart';
import 'settings_page.dart'
    show AccountSecurityPage, SettingsPage, buildFeedbackPage;

typedef _TranscriptLine = ({String sender, String text, String? image});

typedef _Faq = (String question, String answer);

Widget _serviceIcon(String name, {double? size}) => SvgPicture(
  AssetBytesLoader('assets/customer_service/icons/$name.svg'),
  width: size,
  height: size,
  excludeFromSemantics: true,
);

String _orderIcon(String title, {Object? category}) => switch (category) {
  'AI_ADDON' => 'ai',
  'TEMPLATE' => 'template',
  _ => switch (title.trim()) {
    // 改名前的订单仍以“博简”开头。
    'Z优简会员月卡' || '博简会员月卡' || '会员月卡' || '月卡' => 'month_card',
    'Z优简会员年卡' || '博简会员年卡' || '会员年卡' || '年卡' => 'year_card',
    _ => 'wallet',
  },
};

const _chatAvatarSize = 32.0;
const _chatAvatarGap = 8.0;
const _bubbleWidthFactor = .88;
const _serviceHoursNotice = '您好！人工客服上班时间为法定工作日 09:00 - 18:00。';
const _feedbackIntro = '其他时段，您可以通过「';
const _feedbackLabel = '意见反馈';
const _feedbackOutro = '」留言。';
const _feedbackNotice = '$_feedbackIntro$_feedbackLabel$_feedbackOutro';
const _combinedGreeting = '$_serviceHoursNotice$_feedbackNotice';

// 服务端已保存的系统消息以正文标识，旧会话也使用当前展示文案。
const _systemNoticeCopy = {
  '人工客服的服务时间为每天北京时间 09:00–18:00。服务时间内会为你匹配空闲客服，非服务时间暂时无法接通人工客服。':
      _combinedGreeting,
  '已接通人工客服。轮到回复的一方五分钟内未回复，会话将自动结束。':
      '已为您接通人工客服，请描述您遇到的问题。若等待回复满 5 分钟，本次会话将自动结束。',
  '等待回复已超过五分钟，本次人工会话已结束。': '超过五分钟未回复，本次对话已结束',
};

const _templateFaqs = <_Faq>[
  (
    '付费模板怎么购买？',
    '在简历预览页点底部「模板」，选中带价格的付费模板，点「购买」即可永久拥有，不受会员到期影响。会员有效期内也可以免费使用付费模板。',
  ),
  ('会员能免费用付费模板吗？', '可以。会员有效期内所有付费模板都能直接使用；想在到期后继续使用，可以在切换模板处永久购买。'),
  ('之前用积分兑换的模板会失效吗？', '积分已下线。改版前兑换的模板在原有效期内继续可用；开通会员后所有付费模板都可直接使用。'),
];

const _orderFaqs = <_Faq>[
  ('怎么查看订单？', '在会员中心右上角点「订单」，可以查看会员和模板的购买记录与状态。'),
  (
    '付款后没到账怎么办？',
    '会员为虚拟服务，支付成功后立即生效。付款后 30 分钟内仍未到账，请通过客服中心的「意见反馈」联系我们，并描述付款时间和订单情况。',
  ),
  ('账号无法登录或被限制怎么办？', '请打开客服中心的「账号申诉」，描述遇到的问题并留下可联系的方式，我们核实后会尽快处理。'),
  ('导出简历要收费吗？', '编辑和导出简历（PDF、Word）本身不收费，收费的是部分付费模板和 AI 次数。'),
];

const _accountFaqs = <_Faq>[
  ('如何查询注册时间', '打开「我的」，点个人简介旁的「关于我」，在账号 ID 下方可以看到注册时间。'),
  ('账号处罚常见问题', '如果收到账号限制通知，请先查看通知中的原因。对结果有异议，可以回到客服中心点「账号申诉」，说明受影响的功能和发生时间。'),
  ('账号被处罚了我该怎么办', '在客服中心点「账号申诉」，写明遇到的限制、发生时间和可联系的方式，再提交核查。'),
  ('自主声明常见问题', '在发表动态页面点「内容声明」，可勾选原创，或标注含 AI 生成内容、内容为转载等情况。选好后确认，再发布动态。'),
  ('举报相关常见问题', '在相关内容的操作菜单中点「举报」，选择原因后提交。举报人信息不会向对方展示。处理结果可在站内通知中查看。'),
  ('账号实名相关问题', '打开「我的」右上角菜单。有「实名认证」入口时，可进入并按提示完成证件与人脸核验。已认证的账号会在个人资料中显示认证标识。'),
  ('私信常见问题', '在「发现」右上角打开消息，选择好友会话发送消息。你也可以先搜索对方并添加好友。'),
  ('如何找回账号', '用原先绑定的手机号和验证码登录，或选择之前使用的微信、抖音登录方式。请使用原账号的登录方式，以免进入其他账号。'),
  ('账号登录注册相关问题', '在登录页输入手机号和验证码，阅读并同意协议后点「登录」。如果手机号还未注册，确认创建账号后即可使用。'),
];
final _faqTabs = <String, List<_Faq>>{
  '热门问题': [..._accountFaqs, _orderFaqs[1]],
  '处罚违规': [_accountFaqs[1], _accountFaqs[2], _accountFaqs[3]],
  '举报问题': [_accountFaqs[4]],
  '账号功能': [_accountFaqs[0], ..._accountFaqs.skip(5)],
  '会员相关': [...membershipFaqs],
  '模板相关': [..._templateFaqs],
  '订单账号': [..._orderFaqs],
};

const _headerGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFFE7EDFF), Color(0xFFF7FBFF), Color(0xFFD4EBFF)],
);
const _darkHeaderGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF22283A), Color(0xFF25292F), Color(0xFF213348)],
);

const _warmHeaderGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFFF0E9FC), Color(0xFFFFFAF6), Color(0xFFFFE5D4)],
);
const _greenHeaderGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFFE3F5EA), Color(0xFFF7FCF9), Color(0xFFD2EFE0)],
);
const _greenDarkHeaderGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF1F2E26), Color(0xFF232A26), Color(0xFF1F3A2E)],
);
const _warmDarkHeaderGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF282332), Color(0xFF29252B), Color(0xFF382923)],
);

class _Message {
  const _Message(
    this.text, {
    this.fromUser = false,
    this.photo,
    this.agentNumber,
    this.imageUrl,
    this.feedbackDraft,
    this.actionLabel,
  });
  final String text;
  final XFile? photo;
  final String? imageUrl;
  final String? agentNumber;
  final bool fromUser;
  final String? actionLabel, feedbackDraft;
}

// 会话接口以可读文本保存订单摘要，恢复历史消息时也按相同格式渲染。
final _orderMessagePattern = RegExp(
  r'^咨询订单：(?<title>[^\n]+)\n(?:订单号：(?<number>[^\n]+)\n)?'
  r'(?:金额：)?(?<amount>(?:¥|[A-Z]{3} )\d+(?:\.\d+)?)'
  r'(?: · (?:待支付|已支付|已关闭|已退款 / 撤销|权益已过期|状态待确认))?'
  r'(?:\n支付日期：(?<date>\d{4}-\d{2}-\d{2}))?$',
);

final _legacyOrderInquiry = RegExp(r'^咨询订单：([^\n]+)，订单号：([^，\s]+)$');

/// 在线客服：常见问题自助解答，答不上来时引导到意见反馈。
class CustomerServicePage extends StatefulWidget {
  const CustomerServicePage({
    super.key,
    required this.store,
    this.embedded = false,
    this.onExit,
    this.uploadPhoto = uploadResumeDocument,
  });
  final AppStore store;

  /// 作为底部标签页显示：没有返回按钮，「结束会话」只清空对话。
  final bool embedded;
  final VoidCallback? onExit;
  final ResumeUpload uploadPhoto;
  @override
  State<CustomerServicePage> createState() => _CustomerServicePageState();
}

class _CustomerServicePageState extends State<CustomerServicePage> {
  late final _feedbackTap = TapGestureRecognizer()..onTap = openFeedback;
  final input = TextEditingController();
  final scroll = ScrollController();
  int followRequest = 0;
  int historyBeforeAnchor = 0;
  final messages = <_Message>[];
  ({XFile file, String mime, int epoch})? attachment;
  int? uploadedId;
  bool picking = false, sending = false;
  late int sessionEpoch;

  Timer? liveTimer;
  int liveVersion = 0;
  int? liveId;
  String liveStatus = '', liveError = '';
  bool opening = false, polling = false;
  int ahead = 0;
  bool agentTyping = false;
  bool? agentOnline;
  String? agentNumber;
  String waitingFor = '';
  List<_TranscriptLine> transcript = [];
  ({String content, int? fileId, String nonce})? pendingLive;
  bool get human => liveStatus == 'CONNECTED' || liveStatus == 'QUEUED';

  void resetLive() {
    liveTimer?.cancel();
    liveVersion++;
    liveId = null;
    liveStatus = '';
    liveError = '';
    opening = false;
    polling = false;
    ahead = 0;
    agentTyping = false;
    agentOnline = null;
    agentNumber = null;
    transcript = [];
    historyBeforeAnchor = 0;
    followRequest++;
    pendingLive = null;
  }

  void applyLive(Map<String, dynamic> data) {
    final id = integer(data['id']);
    if (id <= 0 ||
        !{
          'OFFLINE',
          'CONNECTED',
          'QUEUED',
          'CLOSED',
        }.contains(data['status'])) {
      throw const ApiFailure('人工客服连接暂不可用');
    }
    final rows = [
      for (final message in (data['messages'] as List).whereType<Map>())
        (
          sender: '${message['sender']}',
          text: '${message['text']}',
          image: message['image'] as String?,
        ),
    ];
    final status = data['status'] as String;
    final waiting = '${data['waiting_for'] ?? ''}';
    final count = integer(data['ahead']);
    final online = data['agent_online'] as bool?;
    final number = data['agent_number'] as String?;
    final typing = status == 'CONNECTED' && data['agent_typing'] == true;
    if (id == liveId &&
        status == liveStatus &&
        waiting == waitingFor &&
        count == ahead &&
        online == agentOnline &&
        number == agentNumber &&
        typing == agentTyping &&
        liveError.isEmpty &&
        listEquals(transcript, rows)) {
      return;
    }
    final changed = transcript.length != rows.length;
    final follow = !scroll.hasClients || scroll.position.extentAfter < 100;
    setState(() {
      // Start a restored, multi-screen history at its newest row without
      // laying out the intervening rows just to reach the bottom.
      if (liveId == null &&
          rows.length * 16 > MediaQuery.sizeOf(context).height) {
        historyBeforeAnchor = rows.length;
      }
      historyBeforeAnchor = historyBeforeAnchor.clamp(0, rows.length);
      liveId = id;
      liveStatus = status;
      liveError = '';
      waitingFor = waiting;
      ahead = count;
      agentOnline = online;
      agentNumber = number;
      agentTyping = typing;
      transcript = rows;
    });
    if (changed && follow) scrollToLatest();
    if (liveStatus == 'CLOSED') liveTimer?.cancel();
  }

  Future<void> enterConversation({
    _Message? question,
    _Message? localAnswer,
  }) async {
    if (opening || sending) return;
    final version = ++liveVersion;
    liveTimer?.cancel();
    final epoch = sessionEpoch;
    setState(() {
      browsing = false;
      opening = true;
    });
    try {
      if (!widget.store.isAuthenticated) throw const ApiFailure('请登录后使用人工客服');
      final response = await widget.store.request(
        liveId == null ? 'PostSupportSessions' : 'GetSupportSessionsId',
        path: liveId == null ? const {} : {'id': '$liveId'},
        expectedEpoch: epoch,
      );
      if (!mounted || version != liveVersion) return;
      applyLive(response.data);
    } catch (_) {
      if (mounted && version == liveVersion) {
        setState(() => liveError = '人工客服连接暂不可用，可继续自助咨询。');
      }
    } finally {
      if (mounted && version == liveVersion) setState(() => opening = false);
    }
    if (!mounted || version != liveVersion || browsing) return;
    if (liveId != null && liveStatus != 'CLOSED') {
      liveTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
        if (liveStatus == 'CONNECTED' || timer.tick.isEven) refreshLive();
      });
    }
    if (question != null) {
      if (human) {
        input.text = question.feedbackDraft ?? question.text;
        send();
      } else if (liveStatus != 'CLOSED') {
        say(question, localAnswer);
      }
    }
    scrollToLatest();
  }

  Future<void> refreshLive() async {
    if (polling ||
        sending ||
        opening ||
        browsing ||
        liveId == null ||
        !TickerMode.valuesOf(context).enabled ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.paused) {
      return;
    }
    final version = liveVersion;
    polling = true;
    try {
      final r = await widget.store.request(
        'GetSupportSessionsId',
        path: {'id': '$liveId'},
        expectedEpoch: sessionEpoch,
      );
      if (mounted && version == liveVersion && !sending) applyLive(r.data);
    } catch (_) {
      if (mounted && version == liveVersion) {
        setState(() {
          liveError = '连接中断，正在重新连接…';
          agentTyping = false;
        });
      }
    } finally {
      if (mounted) polling = false;
    }
  }

  Future<void> postLive(
    String text,
    int? fileId, {
    bool clearInput = true,
  }) async {
    final id = liveId;
    if (id == null || !human) throw const ApiFailure('会话已结束，请重新发起咨询');
    if (utf8.encode(text).length > 2000) throw const ApiFailure('消息过长，请缩短后重试');
    if (pendingLive?.content != text || pendingLive?.fileId != fileId) {
      pendingLive = (
        content: text,
        fileId: fileId,
        nonce:
            '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}',
      );
    }
    final version = ++liveVersion;
    final r = await widget.store.request(
      'PostSupportSessionsIdMessages',
      path: {'id': '$id'},
      expectedEpoch: sessionEpoch,
      body: {'text': text, 'file_id': ?fileId, 'nonce': pendingLive!.nonce},
    );
    if (!mounted || version != liveVersion || liveId != id) return;
    applyLive(r.data);
    pendingLive = null;
    if (clearInput) input.clear();
    scrollToLatest();
  }

  Future<void> sendLiveText(String text, {bool clearInput = true}) async {
    setState(() => sending = true);
    try {
      await postLive(text, null, clearInput: clearInput);
    } catch (e) {
      if (mounted) await showRequestFailure(context, e);
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  void initState() {
    super.initState();
    sessionEpoch = widget.store.epoch;
    widget.store.addListener(_sessionChanged);
  }

  void _sessionChanged() {
    if (widget.store.epoch == sessionEpoch) return;
    setState(() {
      resetLive();
      browsing = true;
      sessionEpoch = widget.store.epoch;
      recentOrders = loadRecentOrders();
      attachment = null;
      uploadedId = null;
      messages.clear();
      input.clear();
    });
  }

  String tab = _faqTabs.keys.first;
  bool showAll = false;
  late Future<List<Map<String, dynamic>>> recentOrders = loadRecentOrders();

  Future<List<Map<String, dynamic>>> loadRecentOrders() async {
    if (!widget.store.isAuthenticated) return [];
    final result = await widget.store.request(
      'GetMembershipOrderHistory',
      query: {'limit': '5'},
      expectedEpoch: sessionEpoch,
    );
    if (result.data['items'] is! List) throw const FormatException('缺少订单记录');
    return items(result.data);
  }

  Future<void> viewOrders() async {
    await openPage<void>(context, OrderHistoryPage(store: widget.store));
    if (!mounted) return;
    setState(() {
      recentOrders = loadRecentOrders();
    });
  }

  bool browsing = true;
  Color get pageColor =>
      context.isDark ? context.colors.canvas : const Color(0xfff8f8f8);

  List<_Faq> get current => _faqTabs[tab]!;
  List<_Faq> get visible => showAll
      ? {for (final entries in _faqTabs.values) ...entries}.toList()
      : current;

  @override
  void dispose() {
    liveTimer?.cancel();
    widget.store.removeListener(_sessionChanged);
    _feedbackTap.dispose();
    input.dispose();
    scroll.dispose();
    super.dispose();
  }

  void openFeedback({bool appeal = false, String initialText = ''}) =>
      openPage<void>(
        context,
        buildFeedbackPage(
          widget.store,
          appeal: appeal,
          initialText: initialText,
        ),
      );

  _Faq? match(String text) {
    Set<String> grams(String value) {
      final clean = value.replaceAll(RegExp(r'[\s，。？！、,.?!]'), '');
      return {
        for (var i = 0; i + 1 < clean.length; i++) clean.substring(i, i + 2),
      };
    }

    final wanted = grams(text);
    if (wanted.isEmpty) return null;
    _Faq? best;
    var bestScore = 1;
    for (final faq in {for (final list in _faqTabs.values) ...list}) {
      final score = grams(faq.$1).intersection(wanted).length;
      if (score > bestScore) {
        best = faq;
        bestScore = score;
      }
    }
    return best;
  }

  void say(_Message user, _Message? reply) {
    setState(() {
      browsing = false;
      messages.add(user);
      if (reply != null) messages.add(reply);
    });
    scrollToLatest();
  }

  void scrollToLatest() {
    final request = ++followRequest;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!scroll.hasClients || request != followRequest) return;
      final position = scroll.position;
      await position.animateTo(
        position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
      // Variable-height rows can revise the estimated end during an animation.
      while (mounted &&
          request == followRequest &&
          scroll.hasClients &&
          scroll.position == position &&
          position.extentAfter > 1) {
        position.jumpTo(position.maxScrollExtent);
        await WidgetsBinding.instance.endOfFrame;
      }
    });
  }

  Future<void> openFaq(_Faq faq) async {
    final resolved = await openPage<bool>(
      context,
      _FaqDetailPage(faq: faq, store: widget.store),
    );
    if (resolved == true && mounted) toast(context, '感谢你的反馈', success: true);
  }

  Future<void> _pickPhoto() async {
    if (picking || sending || opening || liveStatus == 'CLOSED') return;
    if (!widget.store.isAuthenticated) {
      toast(context, '请先登录后发送图片');
      return;
    }
    final epoch = sessionEpoch;
    bool current() => mounted && !browsing && sessionEpoch == epoch;
    setState(() => picking = true);
    dismissKeyboard();
    try {
      final file = await pickAppPhoto(context, isCurrent: current);
      if (file == null || !current()) return;
      final mime = await validateResumePhoto(file);
      if (current()) {
        setState(() {
          attachment = (file: file, mime: mime, epoch: epoch);
          uploadedId = null;
        });
      }
    } catch (e) {
      if (mounted && current()) await showRequestFailure(context, e);
    } finally {
      if (mounted) setState(() => picking = false);
    }
  }

  void _previewPhoto(XFile photo) {
    openPage<void>(
      context,
      Scaffold(
        backgroundColor: Colors.black,
        appBar: const AppPageBar(
          title: Text('查看图片'),
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
        ),
        body: SafeArea(
          child: InteractiveViewer(
            maxScale: 5,
            child: Center(
              child: Image.file(
                File(photo.path),
                fit: BoxFit.contain,
                cacheWidth: 1600,
                errorBuilder: (_, _, _) => const Text(
                  '图片暂时无法打开',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _sendPhoto() async {
    final photo = attachment;
    if (photo == null || sending || picking) return;
    final caption = input.text.trim();
    final description = caption.isEmpty ? '客服会话图片咨询' : '客服会话图片咨询：$caption';
    if (utf8.encode(supportContentWithPhotos(description, ['9' * 19])).length >
        2000) {
      toast(context, '图片说明过长，请适当缩短');
      return;
    }
    void checkSession() {
      if (!mounted ||
          attachment != photo ||
          widget.store.epoch != photo.epoch) {
        throw const ApiFailure('会话已变化，请重新选择图片');
      }
    }

    setState(() => sending = true);
    dismissKeyboard();
    try {
      final id =
          uploadedId ??
          await uploadSupportPhoto(
            widget.store,
            photo.file,
            photo.mime,
            epoch: photo.epoch,
            checkSession: checkSession,
            transfer: widget.uploadPhoto,
          );
      checkSession();
      uploadedId = id;
      if (human) {
        await postLive(caption, id);
        if (mounted && attachment == photo) {
          setState(() {
            attachment = null;
            uploadedId = null;
          });
        }
        return;
      }
      if (liveStatus == 'CLOSED') throw const ApiFailure('会话已结束，请重新发起咨询');
      final result = await widget.store.request(
        'PostFeedback',
        expectedEpoch: photo.epoch,
        body: {
          'category': 'INQUIRY',
          'content': supportContentWithPhotos(description, ['$id']),
          'diagnostic_consent': false,
        },
      );
      checkSession();
      final ticket = integer(result.data['id']);
      setState(() {
        input.clear();
        attachment = null;
        uploadedId = null;
        messages.add(_Message(caption, photo: photo.file, fromUser: true));
        messages.add(
          _Message(ticket > 0 ? '图片已提交给客服，工单号为 $ticket。' : '图片已提交给客服。'),
        );
      });
      if (!browsing) scrollToLatest();
    } catch (e) {
      if (mounted && attachment == photo) await showRequestFailure(context, e);
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  void send() {
    if (sending || picking || opening || liveStatus == 'CLOSED') return;
    if (attachment != null) {
      _sendPhoto();
      return;
    }
    final text = input.text.trim();
    if (text.isEmpty) return;
    if (human) {
      sendLiveText(text);
      return;
    }
    input.clear();
    final found = match(text);
    say(
      _Message(text, fromUser: true),
      found != null
          ? _Message(found.$2)
          : _Message(
              '这个问题我暂时回答不了。你可以提交意见反馈，我们会尽快处理。',
              actionLabel: '提交意见反馈',
              feedbackDraft: text,
            ),
    );
  }

  Future<void> finish() async {
    final ok = await showAppConfirmation(
      context,
      title: '结束会话',
      content: const Text('确定结束本次会话吗？'),
      cancelLabel: '取消',
      confirmLabel: '结束',
    );
    if (ok != true || !mounted) return;
    if (liveId != null && liveStatus != 'CLOSED') {
      final success = await runRequest(context, () async {
        await widget.store.request(
          'PostSupportSessionsIdEnd',
          path: {'id': '$liveId'},
          expectedEpoch: sessionEpoch,
        );
      });
      if (!mounted || !success) return;
    }
    resetLive();
    if (widget.embedded || !Navigator.canPop(context)) {
      setState(() {
        input.clear();
        attachment = null;
        uploadedId = null;
        messages.clear();
        browsing = true;
        tab = _faqTabs.keys.first;
        showAll = false;
      });
    } else {
      Navigator.of(context).pop();
    }
  }

  void goBack() {
    if (!browsing) {
      dismissKeyboard();
      liveTimer?.cancel();
      setState(() => browsing = true);
    } else if (widget.onExit != null) {
      widget.onExit!();
    } else {
      Navigator.maybePop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final interceptBack =
        TickerMode.valuesOf(context).enabled &&
        (!browsing || widget.onExit != null);
    return PopScope(
      canPop: !interceptBack,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && interceptBack) goBack();
      },
      child: AppPageSwitcher(
        depth: browsing ? 0 : 1,
        child: Scaffold(
          key: ValueKey(browsing ? 'support-center' : 'support-chat'),
          backgroundColor: pageColor,
          appBar: browsing
              ? null
              : AppPageBar(
                  leading: BackButton(onPressed: goBack),
                  title: Text(agentTyping ? '正在输入中...' : '客服小简'),
                  actions: [
                    Padding(
                      padding: const EdgeInsets.only(
                        right: appPageHorizontalPadding,
                      ),
                      child: TextButton(
                        onPressed: sending || picking || opening
                            ? null
                            : finish,
                        style: TextButton.styleFrom(
                          foregroundColor: colors.muted,
                          minimumSize: const Size(0, 48),
                          padding: EdgeInsets.zero,
                        ),
                        child: const Text('结束会话'),
                      ),
                    ),
                  ],
                ),
          body: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: browsing ? 680 : double.infinity,
              ),
              child: browsing
                  ? _helpCenter()
                  : SafeArea(
                      child: Column(
                        children: [
                          Expanded(
                            child: Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 680,
                                ),
                                child: SizedBox.expand(child: _conversation()),
                              ),
                            ),
                          ),
                          LayoutBuilder(
                            builder: (_, constraints) {
                              final inset =
                                  appPageHorizontalPadding +
                                  max(0.0, (constraints.maxWidth - 680) / 2);
                              return Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (MediaQuery.viewInsetsOf(context).bottom ==
                                      0)
                                    _chatOrders(inset),
                                  _inputBar(inset),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  LinearGradient get serviceGradient =>
      switch ((context.colors.palette, context.isDark)) {
        (AppAccent.warm, true) => _warmDarkHeaderGradient,
        (AppAccent.warm, false) => _warmHeaderGradient,
        (AppAccent.green, true) => _greenDarkHeaderGradient,
        (AppAccent.green, false) => _greenHeaderGradient,
        (AppAccent.blue, true) => _darkHeaderGradient,
        (AppAccent.blue, false) => _headerGradient,
      };

  Widget _helpCenter() {
    final palette = context.colors.palette;
    final gradient = serviceGradient;
    final textScale = MediaQuery.textScalerOf(context);
    final topInset = MediaQuery.paddingOf(context).top;
    final hasBack = widget.onExit != null || Navigator.canPop(context);
    const subtitleGap = 2.0;
    final subtitleHeight = textScale.scale(11) * 1.3;
    final toolbarHeight =
        (textScale.scale(20) * 1.3).clamp(40.0, double.infinity) +
        subtitleGap +
        subtitleHeight;
    const bannerHeight = 52.0;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Stack(
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: topInset + toolbarHeight + bannerHeight + 110,
          child: DecoratedBox(
            decoration: BoxDecoration(gradient: gradient),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    pageColor.withValues(alpha: 0),
                    pageColor.withValues(alpha: 0),
                    pageColor,
                  ],
                  stops: const [0, .55, 1],
                ),
              ),
            ),
          ),
        ),
        CustomScrollView(
          key: const PageStorageKey('service-help'),
          slivers: [
            SliverAppBar(
              pinned: true,
              toolbarHeight: toolbarHeight,
              expandedHeight: toolbarHeight + bannerHeight,
              centerTitle: false,
              titleSpacing: hasBack ? 0 : 16,
              title: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '客服中心',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 20,
                      height: 1.3,
                      fontWeight: FontWeight.w700,
                      color: switch ((palette, context.isDark)) {
                        (AppAccent.warm, true) => const Color(0xFFFFD4D0),
                        (AppAccent.warm, false) => const Color(0xFF641E28),
                        (AppAccent.green, true) => const Color(0xFFD6F3E2),
                        (AppAccent.green, false) => const Color(0xFF14452D),
                        (AppAccent.blue, true) => const Color(0xFFDBECFF),
                        (AppAccent.blue, false) => const Color(0xFF163C73),
                      },
                    ),
                  ),
                  const SizedBox(height: subtitleGap),
                  Text(
                    '账号、订单与会员服务',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.3,
                      fontWeight: FontWeight.normal,
                      color: context.colors.ink,
                    ),
                  ),
                ],
              ),
              leadingWidth: 52,
              elevation: 0,
              scrolledUnderElevation: 0,
              surfaceTintColor: Colors.transparent,
              backgroundColor: Colors.transparent,
              automaticallyImplyLeading: false,
              leading: hasBack
                  ? Padding(
                      padding: EdgeInsets.only(
                        bottom: subtitleGap + subtitleHeight,
                      ),
                      child: IconButton(
                        tooltip: '返回',
                        onPressed: goBack,
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 20,
                        ),
                      ),
                    )
                  : null,
              flexibleSpace: DecoratedBox(
                decoration: BoxDecoration(gradient: gradient),
                child: FlexibleSpaceBar(
                  collapseMode: CollapseMode.pin,
                  background: Stack(
                    children: [
                      Positioned(
                        right: 21,
                        bottom: -5,
                        height: 91,
                        width: 100,
                        child: Image.asset(
                          'assets/customer_service/assistant.webp',
                          fit: BoxFit.contain,
                          excludeFromSemantics: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(12, 0, 12, bottomInset + 84),
              sliver: SliverList.list(
                children: [
                  _shortcuts(),
                  const SizedBox(height: 8),
                  _orders(),
                  const SizedBox(height: 8),
                  _questions(),
                ],
              ),
            ),
          ],
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: _consultBar(bottomInset),
        ),
      ],
    );
  }

  Widget _cardTitle(String title, String link, VoidCallback action) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: context.colors.ink,
          ),
        ),
      ),
      TextButton(
        onPressed: action,
        style: TextButton.styleFrom(
          foregroundColor: context.colors.muted,
          padding: EdgeInsets.zero,
          minimumSize: const Size(48, 36),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(link, style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 2),
            const AppIcon(AppIcons.forward, size: 12),
          ],
        ),
      ),
    ],
  );

  Widget _orders() {
    final colors = context.colors;
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _cardTitle('订单', '查看全部', viewOrders),
            const SizedBox(height: 5),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: recentOrders,
              builder: (context, snapshot) {
                final orders = snapshot.data ?? [];
                if (snapshot.connectionState != ConnectionState.done ||
                    orders.isEmpty) {
                  final label = snapshot.connectionState != ConnectionState.done
                      ? '正在读取订单…'
                      : snapshot.hasError
                      ? '订单暂未加载，点此查看'
                      : '暂无订单记录';
                  return InkWell(
                    onTap: viewOrders,
                    child: Container(
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      constraints: const BoxConstraints(minHeight: 58),
                      decoration: BoxDecoration(
                        color: context.isDark
                            ? colors.inset
                            : const Color(0xfffafafa),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(fontSize: 13, color: colors.muted),
                      ),
                    ),
                  );
                }
                return _orderCarousel(orders, inChat: false);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _orderCarousel(
    List<Map<String, dynamic>> orders, {
    required bool inChat,
    double inset = 0,
  }) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(horizontal: inset),
      child: Row(
        children: [
          for (final (index, order) in orders.indexed)
            Padding(
              padding: EdgeInsets.only(
                right: index < orders.length - 1 ? 8 : 0,
              ),
              child: SizedBox(
                width:
                    (constraints.maxWidth - 2 * inset) *
                    (orders.length > 1 ? .79 : 1),
                child: _orderTile(order, inChat: inChat),
              ),
            ),
        ],
      ),
    ),
  );

  Widget _orderTile(Map<String, dynamic> order, {required bool inChat}) {
    final colors = context.colors;
    final title = '${order['title'] ?? '订单'}',
        number = '${order['order_no'] ?? ''}';
    final status = orderStatusLabel(order['status']),
        amount = orderAmountLabel(order);
    final paidAt = DateTime.tryParse('${order['paid_at'] ?? ''}')?.toLocal();
    final paidDate = paidAt == null ? null : orderDateLabel(paidAt);
    final icon = _orderIcon(title, category: order['category']);
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: context.isDark
            ? colors.inset
            : inChat
            ? colors.surface
            : const Color(0xfffafafa),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(6),
            ),
            child: _serviceIcon(icon),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  paidDate == null ? amount : '$amount · $paidDate',
                  semanticsLabel: paidDate == null
                      ? amount
                      : '$amount，支付日期 $paidDate',
                  style: TextStyle(fontSize: 11, color: colors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          TextButton(
            style: TextButton.styleFrom(
              backgroundColor: context.isDark
                  ? colors.surface
                  : const Color(0xffeeeeef),
              foregroundColor: colors.ink,
              minimumSize: const Size(44, 26),
              padding: const EdgeInsets.symmetric(horizontal: 9),
            ),
            onPressed:
                inChat &&
                    (sending ||
                        picking ||
                        opening ||
                        (!human && liveStatus != 'OFFLINE'))
                ? null
                : () {
                    final details = [
                      '咨询订单：$title',
                      if (number.isNotEmpty) '订单号：$number',
                      '金额：$amount',
                      if (paidDate != null) '支付日期：$paidDate',
                    ].join('\n');
                    final question = _Message(
                      inChat ? details : '咨询订单：$title',
                      fromUser: true,
                      feedbackDraft: details,
                    );
                    if (inChat && human) {
                      sendLiveText(details, clearInput: false);
                      return;
                    }
                    final answer = _Message(
                      '这笔「$title」的订单金额为 $amount，记录状态为「$status」。如需核对这笔交易，请在意见反馈中描述遇到的问题。',
                      feedbackDraft: [
                        '商品：$title',
                        if (number.isNotEmpty) '订单号：$number',
                        '遇到的问题：',
                      ].join('\n'),
                      actionLabel: '提交意见反馈',
                    );
                    if (inChat) {
                      say(question, answer);
                    } else {
                      enterConversation(
                        question: question,
                        localAnswer: answer,
                      );
                    }
                  },
            child: Text(
              inChat ? '发送' : '咨询',
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _consultBar(double bottomInset) => Container(
    padding: EdgeInsets.fromLTRB(20, 20, 24, bottomInset + 10),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          pageColor.withValues(alpha: 0),
          pageColor.withValues(alpha: .97),
          pageColor,
        ],
        stops: const [0, .38, 1],
      ),
    ),
    child: Row(
      children: [
        InkWell(
          onTap: openFeedback,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppIcon(AppIcons.feedback, size: 20, color: context.colors.ink),
                const SizedBox(height: 2),
                Text(
                  '意见反馈',
                  style: TextStyle(fontSize: 11, color: context.colors.ink),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 5),
        Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: switch (context.colors.palette) {
                  AppAccent.warm => const [
                    Color(0xFFEB365B),
                    Color(0xFFEB704C),
                  ],
                  AppAccent.green => const [
                    Color(0xFF1D9A62),
                    Color(0xFF2F8F6E),
                  ],
                  AppAccent.blue => const [
                    Color(0xFF2458D9),
                    Color(0xFF3078CA),
                  ],
                },
              ),
              borderRadius: const BorderRadius.all(Radius.circular(36)),
            ),
            child: FilledButton.icon(
              onPressed: enterConversation,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                shadowColor: Colors.transparent,
                minimumSize: const Size(0, 44),
              ),
              icon: _serviceIcon('chat', size: 17),
              label: Text(
                messages.isEmpty && liveId == null ? '发起新服务' : '继续咨询',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
  Widget _avatar(double size) => ClipOval(
    child: Image.asset(
      'assets/customer_service/assistant.webp',
      width: size,
      height: size,
      cacheWidth: (size * 3).ceil(),
      excludeFromSemantics: true,
    ),
  );

  Widget _shortcuts() {
    final entries = <(String, String, VoidCallback)>[
      ('账号信息', 'account', () => openFaq(_accountFaqs[0])),
      ('举报问题', 'report', () => openFaq(_accountFaqs[4])),
      (
        '安全中心',
        'security',
        () => openPage<void>(context, AccountSecurityPage(store: widget.store)),
      ),
      (
        '隐私保护',
        'privacy',
        () => openPage<void>(
          context,
          const LegalDocumentPage(kind: LegalDocumentKind.privacyPolicy),
        ),
      ),
      ('账号申诉', 'appeal', () => openFeedback(appeal: true)),
      ('内容声明', 'declaration', () => openFaq(_accountFaqs[3])),
      ('AI 次数', 'ai', () => openFaq(membershipFaqs[1])),
      (
        '我的卡包',
        'wallet',
        () =>
            openPage<void>(context, MembershipWalletPage(store: widget.store)),
      ),
      ('模板帮助', 'template', () => openFaq(_templateFaqs.first)),
      (
        '更多设置',
        'more',
        () => openPage<void>(context, SettingsPage(store: widget.store)),
      ),
    ];
    return Material(
      color: context.colors.surface,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 7, 8, 10),
        child: Column(
          children: [
            for (var start = 0; start < entries.length; start += 5)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final (label, icon, action)
                      in entries.skip(start).take(5))
                    Expanded(
                      child: InkWell(
                        onTap: action,
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          child: Column(
                            children: [
                              _serviceIcon(icon, size: 28),
                              const SizedBox(height: 7),
                              Text(
                                label,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  height: 1.4,
                                  color: context.colors.ink,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _questions() {
    final colors = context.colors;
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 5, 12, 6),
        child: Column(
          children: [
            _cardTitle(
              '常见问题',
              showAll ? '收起' : '查看更多',
              () => setState(() => showAll = !showAll),
            ),
            const SizedBox(height: 4),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final name in _faqTabs.keys)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(name),
                        selected: !showAll && name == tab,
                        onSelected: (_) => setState(() {
                          tab = name;
                          showAll = false;
                        }),
                        showCheckmark: false,
                        side: BorderSide.none,
                        shape: const StadiumBorder(),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                        backgroundColor: context.isDark
                            ? colors.inset
                            : const Color(0xfff8f8f8),
                        selectedColor: colors.accentSoft,
                        labelStyle: TextStyle(
                          fontSize: 12,
                          color: !showAll && name == tab
                              ? colors.accent
                              : colors.muted,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            for (final (i, faq) in visible.indexed)
              InkWell(
                onTap: () => openFaq(faq),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 18,
                        child: Text(
                          '${i + 1}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: switch (i) {
                              0 => colors.accent,
                              1 when colors.palette == AppAccent.green =>
                                context.isDark
                                    ? const Color(0xff9be0b9)
                                    : const Color(0xff2a8a57),
                              2 when colors.palette == AppAccent.green =>
                                context.isDark
                                    ? const Color(0xffb5e6a0)
                                    : const Color(0xff5a8a1f),
                              1 when colors.palette == AppAccent.warm =>
                                context.isDark
                                    ? const Color(0xffffb097)
                                    : const Color(0xffc85d37),
                              2 when colors.palette == AppAccent.warm =>
                                context.isDark
                                    ? const Color(0xffffcc91)
                                    : const Color(0xffae7524),
                              1 =>
                                context.isDark
                                    ? const Color(0xff82c6ff)
                                    : const Color(0xff2975c0),
                              2 =>
                                context.isDark
                                    ? const Color(0xff8bd8ff)
                                    : const Color(0xff267d9d),
                              _ => colors.ink,
                            },
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          faq.$1,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.4,
                            fontWeight: FontWeight.w500,
                            color: colors.ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _welcome() {
    final colors = context.colors;
    final questions = [
      (_orderFaqs.first, 'wallet'),
      (_templateFaqs.first, 'template'),
      (_accountFaqs.first, 'account'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: serviceGradient,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 12, 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '你好，我是小简',
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w700,
                          color: colors.ink,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '你想咨询什么问题？',
                        style: TextStyle(fontSize: 14, color: colors.ink),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Image.asset(
                  'assets/customer_service/assistant.webp',
                  width: 76,
                  height: 76,
                  cacheWidth: 228,
                  excludeFromSemantics: true,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Material(
          color: colors.surface,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
                child: Text(
                  '你可以这样问',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: colors.ink,
                  ),
                ),
              ),
              for (final (i, ((question, answer), icon))
                  in questions.indexed) ...[
                if (i != 0)
                  Divider(
                    height: 1,
                    indent: 48,
                    endIndent: 16,
                    color: colors.border,
                  ),
                InkWell(
                  onTap: () =>
                      say(_Message(question, fromUser: true), _Message(answer)),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          _serviceIcon(icon, size: 21),
                          const SizedBox(width: 11),
                          Expanded(
                            child: Text(
                              question,
                              style: TextStyle(fontSize: 14, color: colors.ink),
                            ),
                          ),
                          AppIcon(
                            AppIcons.forward,
                            size: 14,
                            color: colors.muted,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _systemNote(String text) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(color: context.colors.muted, fontSize: 13, height: 1.5),
    ),
  );

  Widget _serviceNotice(String text) {
    final copy = _systemNoticeCopy[text] ?? text;
    if (copy == _combinedGreeting) {
      return Column(
        children: [
          _serviceNotice(_serviceHoursNotice),
          _serviceNotice(_feedbackNotice),
        ],
      );
    }
    if (copy == _serviceHoursNotice || copy == _feedbackNotice) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _bubble(
          _Message(copy),
          fillWidth: true,
          content: copy == _feedbackNotice
              ? TextSpan(
                  children: [
                    const TextSpan(text: _feedbackIntro),
                    TextSpan(
                      text: _feedbackLabel,
                      recognizer: _feedbackTap,
                      style: TextStyle(
                        color: context.colors.accent,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                    const TextSpan(text: _feedbackOutro),
                  ],
                )
              : null,
        ),
      );
    }
    return _systemNote(copy);
  }

  Widget transcriptBubble(_TranscriptLine row) {
    if (row.sender == 'SYSTEM') return _serviceNotice(row.text);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _bubble(
        _Message(
          row.text,
          fromUser: row.sender == 'USER',
          agentNumber: row.sender == 'AGENT' ? agentNumber : null,
          imageUrl: row.image,
        ),
      ),
    );
  }

  Widget _conversation() => Listener(
    onPointerDown: (_) => followRequest++,
    child: CustomScrollView(
      controller: scroll,
      center: const ValueKey('chat-tail'),
      anchor: historyBeforeAnchor == 0 ? 0 : 1,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        if (historyBeforeAnchor > 0)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              appPageHorizontalPadding,
              18,
              appPageHorizontalPadding,
              0,
            ),
            sliver: SliverList.builder(
              itemCount: historyBeforeAnchor,
              itemBuilder: (_, index) =>
                  transcriptBubble(transcript[historyBeforeAnchor - 1 - index]),
            ),
          ),
        SliverPadding(
          key: const ValueKey('chat-tail'),
          padding: EdgeInsets.fromLTRB(
            appPageHorizontalPadding,
            historyBeforeAnchor == 0 ? 18 : 0,
            appPageHorizontalPadding,
            0,
          ),
          sliver: SliverList.builder(
            itemCount: transcript.length - historyBeforeAnchor,
            itemBuilder: (_, index) =>
                transcriptBubble(transcript[historyBeforeAnchor + index]),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(
            horizontal: appPageHorizontalPadding,
          ),
          sliver: SliverToBoxAdapter(
            child: Column(
              children: [
                if (transcript.isEmpty && !opening)
                  _serviceNotice(_combinedGreeting),
                if (liveError.isNotEmpty)
                  TextButton(
                    onPressed: opening ? null : enterConversation,
                    child: Text('$liveError 点击重试'),
                  ),
                if (opening) _systemNote('正在连接客服中心…'),
                if (liveStatus == 'OFFLINE')
                  _systemNote('当前为非服务时间，你可以使用自助咨询或提交意见反馈。'),
                if (liveStatus == 'QUEUED')
                  _systemNote(
                    ahead == 0 && agentOnline == false
                        ? '当前还没有客服在线。'
                        : '排队中，前面有 $ahead 人。你可以先描述问题。',
                  ),
                if (liveStatus == 'CONNECTED' && waitingFor == 'USER')
                  _systemNote('等待你回复'),
                if (liveStatus == 'CLOSED')
                  TextButton(
                    onPressed: () {
                      setState(() {
                        resetLive();
                        messages.clear();
                      });
                      enterConversation();
                    },
                    child: const Text('重新发起咨询'),
                  ),
                if (messages.isEmpty &&
                    !opening &&
                    !human &&
                    liveStatus != 'CLOSED')
                  _welcome(),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            appPageHorizontalPadding,
            0,
            appPageHorizontalPadding,
            18,
          ),
          sliver: SliverList.builder(
            itemCount: messages.length,
            itemBuilder: (_, index) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _bubble(messages[index]),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _bubble(
    _Message message, {
    InlineSpan? content,
    bool fillWidth = false,
  }) => Row(
    mainAxisAlignment: message.fromUser
        ? MainAxisAlignment.end
        : MainAxisAlignment.start,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (!message.fromUser) ...[
        _avatar(_chatAvatarSize),
        const SizedBox(width: _chatAvatarGap),
      ],
      Flexible(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final gutter = max(
              _chatAvatarSize + _chatAvatarGap,
              constraints.maxWidth * (1 - _bubbleWidthFactor),
            );
            return Padding(
              padding: message.fromUser
                  ? EdgeInsets.only(left: gutter)
                  : EdgeInsets.only(right: gutter),
              child: _bubbleBody(message, content, fillWidth: fillWidth),
            );
          },
        ),
      ),
      if (message.fromUser) ...[
        const SizedBox(width: _chatAvatarGap),
        ListenableBuilder(
          listenable: widget.store,
          builder: (_, _) => ProfileAvatar(
            seed: profileAvatarSeed(widget.store),
            url: widget.store.avatarURL,
            size: _chatAvatarSize,
          ),
        ),
      ],
    ],
  );

  Widget _bubbleBody(
    _Message message,
    InlineSpan? content, {
    required bool fillWidth,
  }) {
    final colors = context.colors;
    final user = message.fromUser;
    final hasImage =
        message.photo != null || (message.imageUrl?.isNotEmpty ?? false);
    if (user && !hasImage && message.text.startsWith('咨询订单：')) {
      final order = _orderMessagePattern.firstMatch(message.text);
      final legacy = order == null
          ? _legacyOrderInquiry.firstMatch(message.text)
          : null;
      if (order != null || legacy != null) {
        final title = order?.namedGroup('title') ?? legacy!.group(1)!;
        final number = order?.namedGroup('number') ?? legacy?.group(2);
        final amount = order?.namedGroup('amount');
        final date = order?.namedGroup('date');
        if (date != null || number == null) {
          return _sentOrderCard(title, number, amount, date);
        }
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: recentOrders,
          builder: (context, snapshot) {
            final match = snapshot.data
                ?.where((o) => o['order_no'] == number)
                .firstOrNull;
            final at = DateTime.tryParse('${match?['paid_at'] ?? ''}')
                ?.toLocal();
            return _sentOrderCard(
              title,
              number,
              amount ?? (match == null ? null : orderAmountLabel(match)),
              at == null ? null : orderDateLabel(at),
            );
          },
        );
      }
    }
    const thumbnailBounds = BoxConstraints(
      minWidth: 48,
      minHeight: 48,
      maxWidth: 160,
      maxHeight: 146,
    );
    const corner = Radius.circular(17);
    return Align(
      alignment: user ? Alignment.topRight : Alignment.topLeft,
      child: Container(
        width: fillWidth ? double.infinity : null,
        padding: hasImage
            ? EdgeInsets.zero
            : const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
        decoration: hasImage
            ? null
            : BoxDecoration(
                color: user ? colors.accentSoft : colors.surface,
                borderRadius: BorderRadius.only(
                  topLeft: user ? corner : const Radius.circular(4),
                  topRight: user ? const Radius.circular(4) : corner,
                  bottomLeft: corner,
                  bottomRight: corner,
                ),
              ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: user && hasImage
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            if (message.agentNumber case final number?)
              Text(
                '客服「${number.padLeft(4, '0')}」',
                style: TextStyle(fontSize: 12, color: colors.accent),
              ),
            if (message.imageUrl case final url? when url.isNotEmpty)
              InkWell(
                onTap: () => openPage<void>(
                  context,
                  Scaffold(
                    appBar: const AppPageBar(title: Text('查看图片')),
                    body: Center(
                      child: InteractiveViewer(child: Image.network(url)),
                    ),
                  ),
                ),
                child: ConstrainedBox(
                  constraints: thumbnailBounds,
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const Text('图片暂时无法显示'),
                  ),
                ),
              ),
            if (message.photo case final photo?)
              Semantics(
                container: true,
                button: true,
                label: '查看已发送的图片',
                child: InkWell(
                  onTap: () => _previewPhoto(photo),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: ConstrainedBox(
                      constraints: thumbnailBounds,
                      child: Image.file(
                        File(photo.path),
                        fit: BoxFit.contain,
                        cacheWidth: 400,
                        errorBuilder: (_, _, _) =>
                            const Icon(Icons.broken_image_outlined),
                      ),
                    ),
                  ),
                ),
              ),
            if (hasImage && message.text.isNotEmpty) const SizedBox(height: 6),
            if (message.text.isNotEmpty)
              Text.rich(
                content ?? TextSpan(text: message.text),
                style: TextStyle(fontSize: 16, height: 1.6, color: colors.ink),
              ),
            if (message.actionLabel != null)
              TextButton.icon(
                onPressed: () =>
                    openFeedback(initialText: message.feedbackDraft ?? ''),
                icon: const AppIcon(AppIcons.feedback, size: 16),
                label: Text(message.actionLabel!),
              ),
          ],
        ),
      ),
    );
  }

  Widget _sentOrderCard(
    String title,
    String? number,
    String? amount,
    String? date,
  ) {
    final colors = context.colors;
    final detailStyle = TextStyle(fontSize: 12, color: colors.muted);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _serviceIcon(_orderIcon(title), size: 20),
              Text(
                title,
                style: TextStyle(
                  color: colors.ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (amount != null)
                Text(
                  amount,
                  style: TextStyle(
                    color: colors.ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          if (number != null || date != null) const SizedBox(height: 5),
          if (number != null) Text('订单号：$number', style: detailStyle),
          if (date != null) Text('支付日期：$date', style: detailStyle),
        ],
      ),
    );
  }

  Widget _chatOrders(double inset) => FutureBuilder<List<Map<String, dynamic>>>(
    future: recentOrders,
    builder: (context, snapshot) {
      final orders = snapshot.data ?? [];
      if (snapshot.connectionState != ConnectionState.done || orders.isEmpty) {
        return const SizedBox.shrink();
      }
      return Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 8),
        child: _orderCarousel(orders, inChat: true, inset: inset),
      );
    },
  );

  Widget _inputBar(double inset) {
    final colors = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: inset, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (attachment case final photo?)
              Row(
                children: [
                  InkWell(
                    onTap: () => _previewPhoto(photo.file),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(7),
                      child: Image.file(
                        File(photo.file.path),
                        width: 42,
                        height: 42,
                        cacheWidth: 120,
                        fit: BoxFit.cover,
                        semanticLabel: '待发送图片',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      sending ? '正在发送给客服…' : '图片将提交给客服',
                      style: TextStyle(fontSize: 13, color: colors.ink),
                    ),
                  ),
                  IconButton(
                    tooltip: '移除待发送图片',
                    onPressed: sending
                        ? null
                        : () => setState(() {
                            attachment = null;
                            uploadedId = null;
                          }),
                    icon: const AppIcon(AppIcons.close, size: 16),
                  ),
                ],
              ),
            DecoratedBox(
              decoration: BoxDecoration(
                color: colors.inset,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(2, 2, 4, 2),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: '发送图片',
                      onPressed: sending || picking ? null : _pickPhoto,
                      icon: AppIcon(
                        AppIcons.imageCache,
                        size: 21,
                        color: colors.accent,
                      ),
                    ),
                    Expanded(
                      child: TextField(
                        controller: input,
                        readOnly: sending || opening || liveStatus == 'CLOSED',
                        minLines: 1,
                        maxLines: 3,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => send(),
                        style: TextStyle(fontSize: 15, color: colors.ink),
                        decoration: InputDecoration(
                          hintText: attachment != null
                              ? '添加图片说明（选填）'
                              : '输入你想咨询的问题',
                          filled: false,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 10),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: input,
                      builder: (context, value, _) => FilledButton(
                        onPressed:
                            sending ||
                                opening ||
                                liveStatus == 'CLOSED' ||
                                picking ||
                                (attachment == null &&
                                    value.text.trim().isEmpty)
                            ? null
                            : send,
                        style: FilledButton.styleFrom(
                          backgroundColor: colors.palette.seed,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: colors.surface,
                          disabledForegroundColor: colors.muted,
                          minimumSize: const Size(58, 34),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          shape: const StadiumBorder(),
                        ),
                        child: const Text('发送'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FaqDetailPage extends StatelessWidget {
  const _FaqDetailPage({required this.faq, required this.store});

  final _Faq faq;
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final style = OutlinedButton.styleFrom(
      minimumSize: const Size(0, 44),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
      foregroundColor: colors.ink,
      textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
      side: BorderSide(
        color: Color.alphaBlend(
          colors.ink.withValues(alpha: .12),
          colors.canvas,
        ),
      ),
      shape: const StadiumBorder(),
    );
    return Scaffold(
      backgroundColor: colors.canvas,
      appBar: AppPageBar(backgroundColor: colors.canvas),
      body: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    faq.$1,
                    style: TextStyle(
                      fontSize: 22,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                      color: colors.ink,
                    ),
                  ),
                ),
                const SizedBox(height: 26),
                Text(
                  faq.$2,
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.6,
                    color: Color.lerp(colors.ink, colors.canvas, .23),
                  ),
                ),
                const SizedBox(height: 26),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: style,
                        onPressed: () => Navigator.pop(context, true),
                        icon: const AppIcon(AppIcons.thumbUp, size: 17),
                        label: const Text('已解决'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: style,
                        onPressed: () => openPage<void>(
                          context,
                          buildFeedbackPage(
                            store,
                            initialText: '关于「${faq.$1}」，我还有以下问题：',
                          ),
                        ),
                        icon: const AppIcon(AppIcons.thumbDown, size: 17),
                        label: const Text('未解决'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
