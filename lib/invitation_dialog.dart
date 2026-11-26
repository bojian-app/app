import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:fluwx_no_pay/fluwx_no_pay.dart';
import 'package:share_plus/share_plus.dart';

import 'api/bojian_api.dart';
import 'app_store.dart';
import 'design.dart' show AppPageRoute, openPage, toast;
import 'design_shapes.dart';
import 'invitation_qr_panel.dart';
import 'invitation_scan_page.dart';
import 'wechat_login.dart';

Future<void> showInvitationDialog(BuildContext context, AppStore store) =>
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '关闭邀请弹窗',
      barrierColor: const Color(0xB3000000),
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (_, _, _) => InvitationDialog(store: store),
      transitionBuilder: (context, animation, _, child) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween(begin: .96, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          ),
          child: child,
        ),
      ),
    );

Future<void> scanAndBindInvitation(BuildContext context, AppStore store) async {
  if (!store.isAuthenticated) {
    toast(context, '请先登录，再扫描好友的邀请码');
    return;
  }
  final epoch = store.epoch;
  final code = await openPage<String>(context, const InvitationScanPage());
  if (code == null || !context.mounted || store.epoch != epoch) return;
  try {
    await _bindInvitation(store, code);
  } catch (error) {
    if (context.mounted && store.epoch == epoch) {
      toast(context, error is ApiFailure ? error.message : '绑定失败，请重新扫码');
    }
    return;
  }
  if (context.mounted && store.epoch == epoch) {
    await _showInvitationReward(context);
  }
}

Future<Map<String, dynamic>> _bindInvitation(
  AppStore store,
  String code,
) async {
  final result = await store.request(
    'PostInvitationsBind',
    body: {'invite_code': code},
  );
  return result.data;
}

Future<void> _showInvitationReward(BuildContext context) =>
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '关闭',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (_, _, _) => const _RewardSuccessDialog(),
    );

class InvitationDialog extends StatefulWidget {
  const InvitationDialog({super.key, required this.store});
  final AppStore store;

  @override
  State<InvitationDialog> createState() => _InvitationDialogState();
}

class _InvitationDialogState extends State<InvitationDialog> {
  static const ink = Color(0xFF2A315B);
  static const accent = Color(0xFF2867EE);
  static const rewardColors = [Color(0xFFFF7E57), Color(0xFFFF482C)];
  static const titleStyle = TextStyle(
    fontFamily: 'ResumeDocument',
    fontSize: 23,
    height: 1.2,
    fontWeight: FontWeight.w700,
    fontStyle: FontStyle.italic,
    letterSpacing: -.5,
    color: Colors.white,
  );
  static const titleGradient = LinearGradient(
    colors: [
      Color(0xFF5C9BFF),
      Color(0xFF2867EE),
      Color(0xFF1F56DB),
      Color(0xFF4F8DFF),
    ],
    stops: [0, .36, .72, 1],
  );

  /// The poster is laid out in the design's 375-wide coordinates and scaled
  /// to the screen as one piece.
  static const posterWidth = 375.0, posterHeight = 636.0;

  Map<String, dynamic>? data;
  String? error;
  bool imageBusy = false;
  String? actionMessage;
  Fluwx? wechat;
  late final int epoch;
  String get code => '${data?['invite_code'] ?? ''}'.trim();

  bool get canBind => data?['can_bind_invite_code'] == true;
  String get url => '${data?['download_url'] ?? ''}'.trim();
  String get invitationLink => Uri.parse(url)
      .replace(
        queryParameters: {
          ...Uri.parse(url).queryParameters,
          'invite_code': code,
        },
      )
      .toString();
  bool get current =>
      widget.store.isAuthenticated && widget.store.epoch == epoch;
  bool get ready =>
      current && code.isNotEmpty && Uri.tryParse(url)?.scheme == 'https';

  @override
  void initState() {
    super.initState();
    epoch = widget.store.epoch;
    load();
  }

  Future<void> load() async {
    setState(() => error = null);
    try {
      final result = await widget.store.request('GetInvitations');
      if (!mounted || !current) return;
      final value = result.data;
      if ('${value['invite_code'] ?? ''}'.trim().isEmpty ||
          Uri.tryParse('${value['download_url'] ?? ''}')?.scheme != 'https') {
        throw StateError('邀请信息暂不可用');
      }
      setState(() => data = value);
    } catch (_) {
      if (mounted && current) setState(() => error = '邀请信息加载失败，点击重试');
    }
  }

  Future<void> copyInvitation(bool link) async {
    if (!ready || imageBusy) return;
    await Clipboard.setData(ClipboardData(text: link ? invitationLink : code));
    if (mounted && current) {
      setState(() => actionMessage = link ? '邀请链接已复制' : '邀请码已复制');
    }
  }

  Future<void> imageAction(String action) async {
    if (!ready || imageBusy) return;
    setState(() {
      imageBusy = true;
      actionMessage = null;
    });
    try {
      final png = await createInvitationQrPng(code: code, link: invitationLink);
      if (!mounted || !current) return;
      if (action == 'save' && Platform.isAndroid) {
        final saved = await const MethodChannel(
          'cn.kelance.bojian/resume_files',
        ).invokeMethod<bool>('saveInvitationImage', {'bytes': png});
        if (mounted && current) {
          setState(() => actionMessage = saved == true ? '二维码已保存' : '已取消保存');
        }
      } else if (action == 'wechat' || action == 'timeline') {
        final sdk = wechat ??= Fluwx();
        if (!await sdk.registerApi(
              appId: NativeWeChatAuthorizer.appID,
              universalLink: NativeWeChatAuthorizer.universalLink,
            ) ||
            !await sdk.isWeChatInstalled) {
          throw StateError('请先安装微信，或使用更多分享');
        }
        if (!mounted || !current) return;
        final launched = await sdk.share(
          WeChatShareImageModel(
            WeChatImageToShare(uint8List: png),
            scene: action == 'timeline'
                ? WeChatScene.timeline
                : WeChatScene.session,
            title: '邀请你加入Z优简',
          ),
        );
        if (!launched) throw StateError('无法打开微信，请重试');
        if (mounted) setState(() => actionMessage = '已打开微信，请确认分享');
      } else {
        final box = context.findRenderObject() as RenderBox?;
        await SharePlus.instance.share(
          ShareParams(
            files: [
              XFile.fromData(png, mimeType: 'image/png', name: 'Z优简邀请二维码.png'),
            ],
            fileNameOverrides: ['Z优简邀请二维码.png'],
            title: '邀请你加入Z优简',
            text: '注册Z优简后，在“邀请好友”里填写我的邀请码：$code\n$invitationLink',
            sharePositionOrigin: box == null
                ? null
                : Rect.fromPoints(
                    box.localToGlobal(Offset.zero),
                    box.localToGlobal(box.size.bottomRight(Offset.zero)),
                  ),
          ),
        );
        if (mounted) {
          setState(
            () => actionMessage = action == 'save' ? '可在分享面板中保存图片' : '已打开分享面板',
          );
        }
      }
    } catch (e) {
      if (mounted && current) {
        setState(
          () =>
              actionMessage = e is StateError ? e.message : '操作暂未完成，请重试或使用更多分享',
        );
      }
    } finally {
      if (mounted) setState(() => imageBusy = false);
    }
  }

  Future<void> enterFriendCode() async {
    if (!current || !canBind) return;
    final summary = await showCupertinoDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _FriendCodeDialog(store: widget.store),
    );
    if (summary == null || !mounted || !current) return;
    setState(() {
      data = {...?data, ...summary};
      actionMessage = '已填写好友邀请码';
    });
    await _showInvitationReward(context);
  }

  /// Entry for entering a friend's code; it disappears once one is entered.
  Widget friendCodeEntry() => tap(
    key: const ValueKey('invitation-friend-code'),
    label: '填写好友邀请码',
    radius: 14,
    onTap: enterFriendCode,
    child: Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          text(
            '填写好友邀请码',
            size: 13,
            color: Colors.white,
            weight: FontWeight.w500,
          ),
          const Icon(Icons.chevron_right, size: 16, color: Colors.white),
        ],
      ),
    ),
  );

  Widget at(double x, double y, double width, double height, Widget child) =>
      Positioned(left: x, top: y, width: width, height: height, child: child);

  Widget text(
    String value, {
    double size = 12,
    Color color = ink,
    FontWeight weight = FontWeight.w400,
    String? family,
  }) => Text(
    value,
    maxLines: 1,
    softWrap: false,
    overflow: TextOverflow.ellipsis,
    style: TextStyle(
      fontFamily: family,
      fontSize: size,
      height: 1.3,
      fontWeight: weight,
      color: color,
    ),
  );

  /// Short gradient rule beside a centred caption, fading away from it.
  Widget rule({required bool leading}) => Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [
          const Color(0xFF545F94).withValues(alpha: 0),
          const Color(0xFF2A315B),
        ],
        begin: leading ? Alignment.centerLeft : Alignment.centerRight,
        end: leading ? Alignment.centerRight : Alignment.centerLeft,
      ),
    ),
  );

  Widget tap({
    required Key key,
    required String label,
    required VoidCallback? onTap,
    required Widget child,
    double radius = 20,
  }) => Semantics(
    button: true,
    label: label,
    enabled: onTap != null,
    excludeSemantics: true,
    child: Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(key: key, onTap: onTap, child: child),
    ),
  );

  Widget qr() {
    if (ready) {
      return Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Semantics(
          label: 'Z优简邀请下载二维码',
          image: true,
          child: CustomPaint(painter: InvitationQrPainter(invitationLink)),
        ),
      );
    }
    final message = !current ? '登录已失效，请关闭后重新登录' : error ?? '正在获取邀请信息…';
    return tap(
      key: const ValueKey('invitation-retry'),
      label: message,
      radius: 8,
      onTap: error != null && current ? load : null,
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Center(
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, height: 1.5, color: ink),
            ),
          ),
        ),
      ),
    );
  }

  Widget icon(String name, double width, double height) => SvgPicture.asset(
    'assets/invitation/icons/$name.svg',
    width: width,
    height: height,
    excludeFromSemantics: true,
  );

  Widget shareTarget(
    double x,
    String name,
    Widget glyph,
    String action,
    Key key,
  ) => at(
    x - 12,
    470,
    62,
    60,
    tap(
      key: key,
      label: name,
      radius: 12,
      onTap: ready && !imageBusy ? () => imageAction(action) : null,
      child: Column(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFD4E3FF).withValues(alpha: .7),
            ),
            child: Center(child: glyph),
          ),
          const SizedBox(height: 4),
          text(name, color: ink.withValues(alpha: .8)),
        ],
      ),
    ),
  );

  Widget poster() => SizedBox(
    key: const ValueKey('invitation-poster-ready'),
    width: posterWidth,
    height: posterHeight,
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        // Light spilling from behind the envelope past the panel edge.
        at(
          270,
          20,
          110,
          120,
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  Colors.white.withValues(alpha: .75),
                  Colors.white.withValues(alpha: 0),
                ],
              ),
            ),
          ),
        ),
        at(
          26,
          22,
          323,
          527.5,
          CustomPaint(
            painter: const _PanelPainter(),
            child: const SizedBox.expand(),
          ),
        ),
        at(36.5, 130, 303, 302.5, const _QrCard()),
        for (final (x, y) in const [(20.0, 93.5), (248.5, 6.5), (343.0, 60.5)])
          at(x, y, 11.5, 11.5, const CustomPaint(painter: _SparklePainter())),
        at(
          226.9,
          29.4,
          118.6,
          80.4,
          Transform.rotate(
            angle: 4 * math.pi / 180,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  'assets/invitation/reward-envelope-blank.png',
                  fit: BoxFit.contain,
                  excludeFromSemantics: true,
                ),
                // The reward printed on the letter: invitations pay out a
                // three-day trial pack, not points.
                const Positioned(
                  left: 40,
                  top: 9,
                  width: 44,
                  height: 33,
                  child: ExcludeSemantics(child: _EnvelopeReward()),
                ),
              ],
            ),
          ),
        ),
        at(48.5, 7.5, 67, 29.7, const _Badge()),
        at(
          50,
          41,
          200,
          28,
          Semantics(
            header: true,
            child: Stack(
              children: [
                Transform.translate(
                  offset: const Offset(0, 1.5),
                  child: ImageFiltered(
                    imageFilter: ui.ImageFilter.blur(sigmaX: .75, sigmaY: .75),
                    child: Text(
                      '邀请好友一起加入',
                      maxLines: 1,
                      softWrap: false,
                      style: titleStyle.copyWith(
                        color: Colors.white.withValues(alpha: .8),
                      ),
                    ),
                  ),
                ),
                ShaderMask(
                  blendMode: BlendMode.srcIn,
                  shaderCallback: titleGradient.createShader,
                  child: const Text(
                    '邀请好友一起加入',
                    maxLines: 1,
                    softWrap: false,
                    style: titleStyle,
                  ),
                ),
              ],
            ),
          ),
        ),
        at(49.5, 72.5, 180, 18.5, text('好友成功注册并绑定手机号', size: 13.2)),
        at(49.5, 90.5, 75, 19.5, text('你即可获得', size: 14.3)),
        at(
          124.5,
          101.5,
          98,
          5,
          const HighlightScribble(strokeWidth: 3.3, colors: rewardColors),
        ),
        at(
          123.5,
          88,
          100,
          22,
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: ShaderMask(
              blendMode: BlendMode.srcIn,
              shaderCallback: const LinearGradient(
                begin: Alignment(-1, -.44),
                end: Alignment(0, .47),
                colors: rewardColors,
              ).createShader,
              child: Text(
                '三天会员体验包',
                maxLines: 1,
                softWrap: false,
                style: const TextStyle(
                  fontFamily: 'ResumeDocument',
                  fontSize: 18,
                  height: 1.2,
                  fontWeight: FontWeight.w700,
                  fontStyle: FontStyle.italic,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
        at(
          36.5,
          143,
          303,
          22,
          Center(
            child: text(
              '我的二维码',
              size: 17,
              color: accent,
              weight: FontWeight.w700,
              family: 'ResumeDocument',
            ),
          ),
        ),
        at(80, 180, 22.5, 1, rule(leading: true)),
        at(272.5, 180, 22.5, 1, rule(leading: false)),
        at(
          106,
          171.5,
          163,
          17,
          FittedBox(
            fit: BoxFit.scaleDown,
            child: text(
              actionMessage ?? '扫码下载，注册后填写邀请码',
              color: actionMessage == null ? ink : accent,
            ),
          ),
        ),
        at(133, 200, 110, 110, qr()),
        at(
          98,
          323,
          179,
          27,
          tap(
            key: const ValueKey('invitation-copy-code'),
            label: '复制邀请码 $code',
            radius: 13.5,
            onTap: ready && !imageBusy ? () => copyInvitation(false) : null,
            child: Ink(
              decoration: BoxDecoration(
                color: const Color(0xFFD4E3FF).withValues(alpha: .7),
                borderRadius: BorderRadius.circular(13.5),
              ),
              padding: const EdgeInsets.only(left: 12, right: 12),
              child: Row(
                children: [
                  text('邀请码：'),
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: text(
                        code.isEmpty ? '——' : code,
                        size: 14,
                        color: accent,
                        weight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Container(
                    width: .5,
                    height: 10,
                    margin: const EdgeInsets.only(left: 6, right: 8),
                    color: accent.withValues(alpha: .4),
                  ),
                  icon('copy', 10, 10),
                  const SizedBox(width: 3),
                  text('复制', color: accent),
                ],
              ),
            ),
          ),
        ),
        at(
          52.5,
          370,
          130,
          40,
          tap(
            key: const ValueKey('invitation-save-qr'),
            label: '保存二维码',
            onTap: ready && !imageBusy ? () => imageAction('save') : null,
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF5C9BFF), Color(0xFF2867EE)],
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox.square(
                    dimension: 20,
                    child: Center(child: icon('save', 15, 14.5)),
                  ),
                  const SizedBox(width: 4),
                  text(
                    imageBusy ? '处理中…' : '保存二维码',
                    size: 14,
                    color: Colors.white,
                    weight: FontWeight.w500,
                  ),
                ],
              ),
            ),
          ),
        ),
        at(
          194.5,
          370,
          130,
          40,
          tap(
            key: const ValueKey('invitation-copy-link'),
            label: '复制链接',
            onTap: ready && !imageBusy ? () => copyInvitation(true) : null,
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: Colors.white.withValues(alpha: .7),
                border: Border.all(color: accent, width: .5),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox.square(
                    dimension: 20,
                    child: Center(child: icon('link', 14.5, 14.5)),
                  ),
                  const SizedBox(width: 4),
                  text(
                    '复制链接',
                    size: 14,
                    color: accent,
                    weight: FontWeight.w500,
                  ),
                ],
              ),
            ),
          ),
        ),
        at(132, 451, 22.5, 1, rule(leading: true)),
        at(222.5, 451, 22.5, 1, rule(leading: false)),
        at(
          154.5,
          442,
          68,
          19,
          Center(child: text('分享邀请', size: 14, weight: FontWeight.w500)),
        ),
        shareTarget(
          80.5,
          '微信',
          icon('wechat', 23, 19),
          'wechat',
          const ValueKey('invitation-wechat'),
        ),
        shareTarget(
          168.5,
          '朋友圈',
          icon('moments', 24, 24),
          'timeline',
          const ValueKey('invitation-timeline'),
        ),
        shareTarget(
          256.5,
          '更多',
          icon('more', 23, 5),
          'more',
          const ValueKey('invitation-more'),
        ),
        if (current && canBind) at(62.5, 558, 250, 28, friendCodeEntry()),
        at(
          172.5,
          602,
          30,
          30,
          tap(
            key: const ValueKey('invitation-close'),
            label: '关闭邀请弹窗',
            radius: 15,
            onTap: () => Navigator.pop(context),
            child: Ink(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: .4),
                border: Border.all(color: Colors.white, width: .5),
              ),
              child: Center(
                child: Transform.rotate(
                  angle: math.pi / 4,
                  child: const SizedBox.square(
                    dimension: 15,
                    child: Stack(
                      children: [
                        Center(
                          child: SizedBox(
                            width: 15,
                            height: 2,
                            child: ColoredBox(color: Colors.white),
                          ),
                        ),
                        Center(
                          child: SizedBox(
                            width: 2,
                            height: 15,
                            child: ColoredBox(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => Material(
    type: MaterialType.transparency,
    child: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = math.min(constraints.maxWidth, 480.0);
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: SizedBox(
                  width: width,
                  height: width * posterHeight / posterWidth,
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: MediaQuery.withNoTextScaling(child: poster()),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
}

/// Ticket panel traced from the design: a header inset on both sides that
/// dips under the envelope, stepping out to the full-width body.
class _PanelPainter extends CustomPainter {
  const _PanelPainter();

  static Path shape(Size size) {
    final w = size.width, h = size.height;
    return roundedPolygon([
      (const Offset(10, 0), 14),
      (const Offset(204, 0), 24),
      (const Offset(233, 30), 24),
      (Offset(w - 10, 30), 14),
      (Offset(w - 10, 96.75), 16),
      (Offset(w, 106.5), 16),
      (Offset(w, h), 12),
      (Offset(0, h), 12),
      (const Offset(0, 106.5), 16),
      (const Offset(10, 96.75), 16),
    ]);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final path = shape(size);
    final header = Rect.fromLTWH(0, 0, size.width, 154.5);
    canvas.drawPath(
      path,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFCFE0FF), Color(0xFFE6EFFF)],
          stops: [0, .64],
        ).createShader(header),
    );
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: const Alignment(-.56, -1.29),
          end: const Alignment(-.41, .27),
          colors: [
            const Color(0xFFB8FFF3).withValues(alpha: .5),
            const Color(0xFFB8FFF3).withValues(alpha: 0),
          ],
        ).createShader(header),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(_PanelPainter oldDelegate) => false;
}

/// Frosted card holding the QR code, crossed by a faint tilted ring.
class _QrCard extends StatelessWidget {
  const _QrCard();

  @override
  Widget build(BuildContext context) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.white.withValues(alpha: .8)),
      gradient: LinearGradient(
        begin: const Alignment(0, -.98),
        end: const Alignment(0, .46),
        colors: [
          const Color(0xFFF7FAFF).withValues(alpha: .51),
          const Color(0xFFEDF3FF).withValues(alpha: .24),
        ],
      ),
    ),
    child: Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: const Alignment(.78, -1.28),
                end: const Alignment(.62, -.23),
                colors: [
                  const Color(0xFFB7D0FF),
                  const Color(0xFFE0EAFD).withValues(alpha: 0),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          left: 2,
          top: 72.5,
          width: 416,
          height: 167.5,
          child: Transform.rotate(
            angle: -9 * math.pi / 180,
            child: Opacity(
              opacity: .5,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: .5),
                  gradient: LinearGradient(
                    begin: const Alignment(-.26, -1.28),
                    end: const Alignment(-.17, -.41),
                    colors: [
                      const Color(0xFFD0DFFD),
                      const Color(0xFFD0DFFD).withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

/// Tilted speech-bubble tag above the title.
class _Badge extends StatelessWidget {
  const _Badge();

  @override
  Widget build(BuildContext context) => Transform.rotate(
    angle: -10 * math.pi / 180,
    child: Stack(
      children: [
        Positioned.fill(
          child: SvgPicture.asset(
            'assets/invitation/icons/badge.svg',
            fit: BoxFit.fill,
            excludeFromSemantics: true,
          ),
        ),
        const Positioned(
          left: 0,
          right: 0,
          top: 3,
          height: 18,
          child: Center(
            child: Text(
              '邀请有礼',
              maxLines: 1,
              softWrap: false,
              style: TextStyle(
                fontFamily: 'ResumeDocument',
                fontSize: 13,
                height: 1.2,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

/// Four-pointed twinkle scattered around the panel.
class _SparklePainter extends CustomPainter {
  const _SparklePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final k = r * .18;
    final path = Path()
      ..moveTo(c.dx, c.dy - r)
      ..quadraticBezierTo(c.dx + k, c.dy - k, c.dx + r, c.dy)
      ..quadraticBezierTo(c.dx + k, c.dy + k, c.dx, c.dy + r)
      ..quadraticBezierTo(c.dx - k, c.dy + k, c.dx - r, c.dy)
      ..quadraticBezierTo(c.dx - k, c.dy - k, c.dx, c.dy - r)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFF5F9FF), Color(0xFFD8E5FE)],
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(_SparklePainter oldDelegate) => false;
}

class _EnvelopeReward extends StatelessWidget {
  const _EnvelopeReward();

  @override
  Widget build(BuildContext context) => MediaQuery.withNoTextScaling(
    child: ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFF2532F), Color(0xFFE8361F)],
      ).createShader,
      child: const FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '3天',
              style: TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w900,
                height: 1,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 2),
            Text(
              '体验包',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w900,
                height: 1,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Enters a friend's invitation code, typed or scanned from their QR code.
/// Pops the updated invitation summary once the server accepts it.
class _FriendCodeDialog extends StatefulWidget {
  const _FriendCodeDialog({required this.store});
  final AppStore store;

  @override
  State<_FriendCodeDialog> createState() => _FriendCodeDialogState();
}

class _FriendCodeDialogState extends State<_FriendCodeDialog> {
  final controller = TextEditingController();
  bool busy = false;
  String? error;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> scan() async {
    final code = await Navigator.of(context)
        .push<String>(AppPageRoute(builder: (_) => const InvitationScanPage()));
    if (mounted && code != null) {
      setState(() {
        controller.text = code;
        error = null;
      });
    }
  }

  Future<void> submit() async {
    final code = controller.text.trim();
    if (busy) return;
    if (code.isEmpty) {
      setState(() => error = '请输入好友的邀请码');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final summary = await _bindInvitation(widget.store, code);
      if (mounted) Navigator.pop(context, summary);
    } on ApiFailure catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) setState(() => error = '提交失败，请重试');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => CupertinoAlertDialog(
    title: const Text('填写好友邀请码'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        const Text(
          '每个账号只能填写一次，填写后不能修改。你绑定手机号后，好友获得三天会员体验包。',
          style: TextStyle(fontSize: 12),
        ),
        const SizedBox(height: 12),
        CupertinoTextField(
          key: const ValueKey('friend-invite-code'),
          controller: controller,
          placeholder: '好友邀请码',
          maxLength: 8,
          autocorrect: false,
          autofocus: true,
          enabled: !busy,
          textCapitalization: TextCapitalization.characters,
          padding: const EdgeInsets.all(12),
          onSubmitted: (_) => submit(),
          suffix: IconButton(
            key: const ValueKey('friend-invite-scan'),
            tooltip: '扫好友邀请二维码',
            onPressed: busy ? null : scan,
            icon: const Icon(Icons.qr_code_scanner, size: 20),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 8),
          Text(
            error!,
            style: const TextStyle(
              fontSize: 12,
              color: CupertinoColors.destructiveRed,
            ),
          ),
        ],
      ],
    ),
    actions: [
      CupertinoDialogAction(
        onPressed: busy ? null : () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      CupertinoDialogAction(
        key: const ValueKey('friend-invite-submit'),
        isDefaultAction: true,
        onPressed: busy ? null : submit,
        child: Text(busy ? '提交中…' : '确定'),
      ),
    ],
  );
}

/// Celebration shown after a friend's invitation code is accepted.
class _RewardSuccessDialog extends StatefulWidget {
  const _RewardSuccessDialog();

  @override
  State<_RewardSuccessDialog> createState() => _RewardSuccessDialogState();
}

class _RewardSuccessDialogState extends State<_RewardSuccessDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..forward();

  @override
  void initState() {
    super.initState();
    HapticFeedback.mediumImpact();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Center(
    child: Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      child: SizedBox(
        width: 280,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                key: const ValueKey('invite-reward-animation'),
                width: 160,
                height: 120,
                child: AnimatedBuilder(
                  animation: controller,
                  builder: (_, _) => CustomPaint(
                    painter: _RewardBurstPainter(controller.value),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '领取成功',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text(
                '邀请码已填写，好友将获得三天会员体验包',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Color(0xFF666666)),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('好的'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _RewardBurstPainter extends CustomPainter {
  const _RewardBurstPainter(this.t);
  final double t;

  static const colors = [
    Color(0xFF2F80ED),
    Color(0xFFFFB020),
    Color(0xFF27AE60),
    Color(0xFFEB5757),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final pop = Curves.elasticOut.transform((t / 0.5).clamp(0, 1));
    canvas.drawCircle(c, 38 * pop, Paint()..color = const Color(0xFF2F80ED));
    final check = Path()
      ..moveTo(c.dx - 15, c.dy)
      ..lineTo(c.dx - 4, c.dy + 11)
      ..lineTo(c.dx + 16, c.dy - 10);
    final draw = ((t - 0.3) / 0.3).clamp(0.0, 1.0);
    for (final m in check.computeMetrics()) {
      canvas.drawPath(
        m.extractPath(0, m.length * draw),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round
          ..color = Colors.white,
      );
    }
    final burst = ((t - 0.2) / 0.8).clamp(0.0, 1.0);
    final ease = Curves.easeOutCubic.transform(burst);
    for (var i = 0; i < 16; i++) {
      final a = i * math.pi * 2 / 16;
      final r = 46 + (i.isEven ? 26 : 14) * ease;
      canvas.drawCircle(
        c + Offset(math.cos(a), math.sin(a)) * r,
        (i.isEven ? 4 : 3) * (1 - burst),
        Paint()..color = colors[i % colors.length],
      );
    }
  }

  @override
  bool shouldRepaint(_RewardBurstPainter old) => old.t != t;
}
