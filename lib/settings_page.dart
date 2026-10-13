import 'user_display_name.dart';

import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_icons.dart';
import 'account_deletion_sheet.dart';
import 'api/bojian_api.dart';
import 'app_store.dart';
import 'design.dart';
import 'legal_document.dart';
import 'legal_document_page.dart';
import 'profile_avatar.dart';

const _settingsChannel = MethodChannel('cn.kelance.bojian/settings');

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.store});
  final AppStore store;
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool savingPrivacy = false;
  String version = '1.0.0';
  @override
  void initState() {
    super.initState();
    if (Platform.isAndroid) _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await _settingsChannel.invokeMapMethod<String, dynamic>(
        'appInfo',
      );
      if (mounted && info?['version'] is String) {
        setState(() => version = info!['version']);
      }
    } on PlatformException {
      /* The installed client version remains available. */
    } on MissingPluginException {
      /* Unsupported host. */
    }
  }

  Future<void> _systemSettings(String action) async {
    await runRequest(context, () async {
      if (Platform.isAndroid) {
        await _settingsChannel.invokeMethod<void>(action);
      } else if (Platform.isIOS) {
        if (!await launchUrl(Uri.parse('app-settings:'))) {
          throw const ApiFailure('无法打开系统设置');
        }
      } else {
        throw const ApiFailure('请在设备系统设置中管理应用权限与通知');
      }
    });
  }

  Future<void> _legal(LegalDocumentKind kind) async {
    await openPage<void>(context, LegalDocumentPage(kind: kind));
  }

  Future<void> _privacy(bool value) async {
    setState(() => savingPrivacy = true);
    await runRequest(context, () => widget.store.setPublicProfile(value));
    if (mounted) setState(() => savingPrivacy = false);
  }

  Future<void> _clearImages() async {
    final clear = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清理图片缓存？'),
        content: const Text('清理临时图片后，再次查看时会重新加载。已保存的简历和文件不受影响。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('清理'),
          ),
        ],
      ),
    );
    if (!mounted || clear != true) return;
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
    setState(() {});
    toast(context, '图片缓存已清理');
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.store,
    builder: (context, _) {
      final store = widget.store;
      final cached =
          PaintingBinding.instance.imageCache.currentSizeBytes / (1024 * 1024);
      return Scaffold(
        appBar: AppBar(title: const Text('隐私与设置')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              children: [
                if (store.isAuthenticated) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 28),
                    child: Row(
                      children: [
                        ProfileAvatar(
                          seed: profileAvatarSeed(store),
                          url: store.avatarURL,
                          size: 42,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                userDisplayName(store.name),
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '用户 ID：${store.publicID.isEmpty ? store.userID : store.publicID}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () async {
                            await Clipboard.setData(
                              ClipboardData(
                                text: store.publicID.isEmpty
                                    ? '${store.userID}'
                                    : store.publicID,
                              ),
                            );
                            if (context.mounted) toast(context, '用户 ID 已复制');
                          },
                          child: const Text('复制'),
                        ),
                      ],
                    ),
                  ),
                  _SettingsGroup(
                    '账号与隐私',
                    children: [
                      _SettingsRow(
                        icon: AppIcons.accountSecurity,
                        title: '账号安全',
                        subtitle: '管理登录设备与账号',
                        onTap: () =>
                            openPage(context, _SecurityPage(store: store)),
                      ),
                      _SettingsRow(
                        icon: AppIcons.publicProfile,
                        title: '公开个人介绍',
                        subtitle: '允许其他用户查看你的简介',
                        trailing: savingPrivacy
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Switch.adaptive(
                                value: store.publicProfile,
                                activeTrackColor: blue,
                                onChanged: savingPrivacy ? null : _privacy,
                              ),
                      ),
                    ],
                  ),
                ],
                _SettingsGroup(
                  '应用管理',
                  children: [
                    _SettingsRow(
                      icon: AppIcons.notificationSettings,
                      title: '通知设置',
                      subtitle: '管理系统通知的显示方式',
                      onTap: () => _systemSettings('openNotifications'),
                    ),
                    _SettingsRow(
                      icon: AppIcons.permissions,
                      title: '系统权限',
                      subtitle: '查看与管理博简的设备权限',
                      onTap: () => _systemSettings('openPermissions'),
                    ),
                    _SettingsRow(
                      icon: AppIcons.imageCache,
                      title: '图片缓存',
                      value: '${cached.toStringAsFixed(1)} MB',
                      onTap: _clearImages,
                    ),
                  ],
                ),
                _SettingsGroup(
                  '帮助与关于',
                  children: [
                    if (store.isAuthenticated)
                      _SettingsRow(
                        icon: AppIcons.feedback,
                        title: '意见反馈',
                        onTap: () =>
                            openPage(context, _FeedbackPage(store: store)),
                      ),
                    _SettingsRow(
                      key: const ValueKey('settings-user-agreement'),
                      icon: AppIcons.terms,
                      title: '用户协议',
                      onTap: () => _legal(LegalDocumentKind.userAgreement),
                    ),
                    _SettingsRow(
                      key: const ValueKey('settings-privacy-policy'),
                      icon: AppIcons.privacyPolicy,
                      title: '隐私政策',
                      onTap: () => _legal(LegalDocumentKind.privacyPolicy),
                    ),
                    _SettingsRow(
                      icon: AppIcons.about,
                      title: '关于博简',
                      value: 'v$version',
                      onTap: () => showModalBottomSheet<void>(
                        context: context,
                        showDragHandle: true,
                        builder: (_) => SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '博简',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '版本 $version',
                                  style: const TextStyle(
                                    color: muted,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                const Text(
                                  '简历创建与优化、模板选择，以及求职经验交流。',
                                  style: TextStyle(fontSize: 14, height: 1.7),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup(
    this.title, {
    required this.children,
    this.dividerInset = 54,
  });
  final String title;
  final List<Widget> children;
  final double dividerInset;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 10),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: muted,
            ),
          ),
        ),
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0)
                  Padding(
                    padding: EdgeInsets.only(left: dividerInset, right: 16),
                    child: const Divider(height: 1),
                  ),
                children[i],
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    super.key,
    this.icon,
    required this.title,
    this.subtitle,
    this.value,
    this.onTap,
    this.trailing,
    this.titleColor = ink,
  });
  final AppIconData? icon;
  final Color titleColor;
  final String title;
  final String? subtitle, value;
  final VoidCallback? onTap;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
      child: Row(
        children: [
          if (icon != null) ...[
            AppIcon(icon!, size: 20, color: ink),
            const SizedBox(width: 14),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: titleColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 5),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      fontSize: 11,
                      color: muted,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (value != null) ...[
            const SizedBox(width: 8),
            Text(value!, style: const TextStyle(fontSize: 12, color: muted)),
          ],
          if (trailing != null)
            trailing!
          else if (onTap != null) ...[
            const SizedBox(width: 8),
            const AppIcon(AppIcons.forward, size: 16, color: muted),
          ],
        ],
      ),
    ),
  );
}

class _FeedbackPage extends StatefulWidget {
  const _FeedbackPage({required this.store, this.appeal = false});
  final AppStore store;
  final bool appeal;
  @override
  State<_FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<_FeedbackPage> {
  final text = TextEditingController();
  String category = 'BUG';
  bool sending = false;
  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (sending) return;
    if (text.text.trim().isEmpty) {
      toast(context, '请填写反馈内容');
      return;
    }
    if (utf8.encode(text.text.trim()).length > (widget.appeal ? 1000 : 2000)) {
      toast(context, '反馈内容过长，请适当缩短');
      return;
    }
    dismissKeyboard();
    setState(() => sending = true);
    final done = await runRequest(context, () async {
      await widget.store.request(
        widget.appeal ? 'PostAppeals' : 'PostFeedback',
        body: widget.appeal
            ? {
                'subject_type': 'USER',
                'subject_id': widget.store.userID,
                'reason': text.text.trim(),
              }
            : {
                'category': category,
                'content': text.text.trim(),
                'diagnostic_consent': false,
              },
      );
    });
    if (!mounted) return;
    if (done) {
      Navigator.pop(context);
      toast(context, widget.appeal ? '申诉已提交' : '反馈已提交');
    } else {
      setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.appeal ? '账号申诉' : '意见反馈'),
      actions: const [DismissKeyboardButton()],
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: ListView(
          padding: const EdgeInsets.all(24),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            if (widget.appeal)
              const Text(
                '请描述账号遇到的问题，并留下可联系的方式，便于核实和处理。',
                style: TextStyle(fontSize: 13, color: muted, height: 1.6),
              )
            else
              Wrap(
                spacing: 8,
                children: [
                  for (final choice in {
                    'BUG': '遇到问题',
                    'SUGGESTION': '功能建议',
                  }.entries)
                    ChoiceChip(
                      label: Text(choice.value),
                      selected: category == choice.key,
                      onSelected: sending
                          ? null
                          : (_) => setState(() => category = choice.key),
                    ),
                ],
              ),
            const SizedBox(height: 20),
            TextField(
              controller: text,
              enabled: !sending,
              minLines: 8,
              maxLines: 14,
              maxLength: widget.appeal ? 300 : 600,
              decoration: InputDecoration(
                hintText: widget.appeal ? '问题描述与联系方式…' : '描述你遇到的问题或建议…',
                fillColor: Colors.white,
              ),
              style: const TextStyle(fontSize: 14, height: 1.7),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: sending ? null : submit,
              child: Text(
                sending
                    ? '正在提交…'
                    : widget.appeal
                    ? '提交申诉'
                    : '提交反馈',
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _SecurityPage extends StatefulWidget {
  const _SecurityPage({required this.store});
  final AppStore store;
  @override
  State<_SecurityPage> createState() => _SecurityPageState();
}

class _SecurityPageState extends State<_SecurityPage> {
  List<Map<String, dynamic>> sessions = [];
  final revoking = <int>{};
  String? error;
  bool loading = true, deleting = false;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await widget.store.request('GetMeSessions');
      if (mounted) {
        setState(() {
          sessions = items(result.data);
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> deleteAccount() async {
    final confirmed = await showAccountDeletionSheet(context);
    if (!mounted || confirmed != true) return;
    setState(() => deleting = true);
    final done = await runRequest(context, () async {
      await widget.store.request('DeleteMeAccount', body: {'confirmed': true});
      await widget.store.endSession(remote: false);
    });
    if (!mounted) return;
    if (done) {
      Navigator.popUntil(context, (route) => route.isFirst);
      toast(context, '注销申请已提交');
    } else {
      setState(() => deleting = false);
    }
  }

  Future<void> revokeSession(Map<String, dynamic> session) async {
    final id = integer(session['id']);
    if (revoking.contains(id)) return;
    final current = session['is_current'] == true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('退出该设备？'),
        content: Text(current ? '当前设备将退出登录。' : '该设备需要重新登录后才能继续使用博简。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('退出登录'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    setState(() => revoking.add(id));
    final done = await runRequest(context, () async {
      await widget.store.request('DeleteMeSessionsId', path: {'id': '$id'});
      if (current) await widget.store.endSession(remote: false);
    });
    if (!mounted) return;
    setState(() => revoking.remove(id));
    if (!done) return;
    if (current) {
      Navigator.popUntil(context, (route) => route.isFirst);
    } else {
      setState(() => sessions.removeWhere((v) => integer(v['id']) == id));
      toast(context, '该设备已退出登录');
    }
  }

  String platformName(dynamic platform) => switch (platform) {
    'ANDROID' => 'Android',
    'IOS' => 'iOS',
    'MACOS' => 'macOS',
    'WINDOWS' => 'Windows',
    _ => '未知系统',
  };

  String loginTime(dynamic value) {
    final date = DateTime.tryParse('$value')?.toLocal();
    if (date == null) return '暂无记录';
    String two(int n) => '$n'.padLeft(2, '0');
    return '${date.year}/${two(date.month)}/${two(date.day)} ${two(date.hour)}:${two(date.minute)}';
  }

  Widget deviceRow(Map<String, dynamic> session) {
    final current = session['is_current'] == true;
    final desktop = ['MACOS', 'WINDOWS'].contains(session['platform']);
    final reportedModel =
        '${session['device_model'] ?? session['device_name'] ?? ''}'.trim();
    final title = reportedModel.isNotEmpty
        ? reportedModel
        : current
        ? widget.store.deviceMetadata.model
        : '';
    final reportedOS = '${session['os_version'] ?? ''}'.trim();
    final osVersion = reportedOS.isNotEmpty
        ? reportedOS
        : current
        ? widget.store.deviceMetadata.osVersion
        : '';
    final busy = revoking.contains(integer(session['id']));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: AppIcon(
              desktop ? AppIcons.computer : AppIcons.phone,
              size: 21,
              color: ink,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      title.isEmpty
                          ? '${platformName(session['platform'])} 设备'
                          : title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (current)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: blue.withValues(alpha: .08),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: const Text(
                          '当前设备',
                          style: TextStyle(fontSize: 10, color: blue),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 7),
                Text(
                  '系统：${platformName(session['platform'])}${osVersion.isEmpty ? '' : ' $osVersion'}',
                  style: const TextStyle(fontSize: 11, color: muted),
                ),
                const SizedBox(height: 4),
                Text(
                  '登录时间：${loginTime(session['logged_in_at'])}',
                  style: const TextStyle(fontSize: 11, color: muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          TextButton(
            onPressed: busy ? null : () => revokeSession(session),
            child: Text(
              busy ? '正在退出…' : '退出登录',
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('账号安全')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          children: [
            _SettingsGroup(
              '登录设备',
              children: [
                if (loading)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else if (error != null)
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          error!,
                          style: const TextStyle(fontSize: 12, color: muted),
                        ),
                        const SizedBox(height: 8),
                        TextButton(onPressed: load, child: const Text('重新加载')),
                      ],
                    ),
                  )
                else if (sessions.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      '暂无登录设备',
                      style: TextStyle(fontSize: 13, color: muted),
                    ),
                  )
                else
                  for (final session in sessions) deviceRow(session),
              ],
            ),
            _SettingsGroup(
              '账号管理',
              dividerInset: 16,
              children: [
                _SettingsRow(
                  title: '账号申诉',
                  subtitle: '账号使用遇到问题，提交申诉协助处理',
                  onTap: () => openPage(
                    context,
                    _FeedbackPage(store: widget.store, appeal: true),
                  ),
                ),
                _SettingsRow(
                  title: deleting ? '正在申请注销…' : '账号注销',
                  titleColor: const Color(0xFFB75B5B),
                  subtitle: '注销后账号及相关数据将被删除，请先保存需要的内容',
                  onTap: deleting ? null : deleteAccount,
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
