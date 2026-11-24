import 'app_page_bar.dart';
import 'user_display_name.dart';

import 'dart:io';
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'about_page.dart';
import 'ai_consent.dart';
import 'feedback_page.dart';
import 'app_appearance.dart';
import 'panel_sheet.dart';
import 'app_icons.dart';
import 'app_update.dart';
import 'account_deletion_dialog.dart';
import 'api/bojian_api.dart';
import 'app_store.dart';
import 'confirmation_dialog.dart';
import 'phone_binding_dialog.dart';
import 'design.dart';
import 'legal_document.dart';
import 'legal_document_page.dart';
import 'network_image_cache.dart';
import 'profile_avatar.dart';
import 'sign_out_dialog.dart';

const _rowPadding = 16.0;
const _avatarSize = 36.0;
const _labelOffset = _avatarSize + 12;
// Compact text buttons keep a 32pt-high tap area instead of Material's 48.
const _compactButtonSize = Size(40, 32);
const _settingsChannel = MethodChannel('cn.kelance.bojian/settings');

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.store});
  final AppStore store;
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool savingPrivacy = false;
  bool? aiConsent;
  int aiConsentUser = 0;
  bool signingOut = false;
  Timer? cacheRefresh;
  int imageCacheBytes = PaintingBinding.instance.imageCache.currentSizeBytes;
  int imageDiskBytes = 0;

  void refreshImageCache() {
    final bytes = PaintingBinding.instance.imageCache.currentSizeBytes;
    if (mounted && bytes != imageCacheBytes) {
      setState(() => imageCacheBytes = bytes);
    }
  }

  Future<void> refreshImageDisk() async {
    final bytes = await NetworkImageStore.instance.diskBytes();
    if (mounted && bytes != imageDiskBytes) {
      setState(() => imageDiskBytes = bytes);
    }
  }

  @override
  void dispose() {
    cacheRefresh?.cancel();
    super.dispose();
  }

  String version = '1.0.0';
  @override
  void initState() {
    super.initState();
    if (Platform.isAndroid || Platform.isIOS) _loadVersion();
    AppUpdates.instance.refresh(widget.store);
    refreshImageDisk();
    _loadAiConsent();
    // Images finish decoding after this page builds; ImageCache is not a Listenable.
    cacheRefresh = Timer.periodic(
      const Duration(seconds: 1),
      (_) => refreshImageCache(),
    );
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

  Future<void> _chooseAppearance<T extends Enum>({
    required String title,
    required List<T> choices,
    required T selected,
    required String Function(T) label,
    required Future<void> Function(T) save,
  }) async {
    Future<dynamic>? sheetClosed;
    final choice = await showPanelSheet<T>(
      context,
      builder: (context) => PanelSheet(
        title: title,
        child: ListView(
          children: [
            for (final item in choices)
              ListTile(
                selected: item == selected,
                leading: item is AppAccent
                    ? CircleAvatar(radius: 10, backgroundColor: item.seed)
                    : null,
                title: Text(label(item)),
                trailing: item == selected
                    ? AppIcon(AppIcons.confirm, color: context.colors.accent)
                    : null,
                onTap: () {
                  sheetClosed = ModalRoute.of(context)?.completed;
                  Navigator.pop(context, item);
                },
              ),
          ],
        ),
      ),
    );
    if (!mounted || choice == null || choice == selected) return;
    await sheetClosed;
    if (mounted) await runRequest(context, () => save(choice));
  }

  Future<void> _legal(LegalDocumentKind kind) async {
    await openPage<void>(context, LegalDocumentPage(kind: kind));
  }

  Future<void> _loadAiConsent() async {
    final user = widget.store.userID;
    final granted = await AiConsent.refresh(widget.store);
    if (mounted && user == widget.store.userID) {
      setState(() {
        aiConsent = granted;
        aiConsentUser = user;
      });
    }
  }

  Future<void> _aiConsent(bool value) async {
    if (value) {
      await AiConsent.ensure(context, widget.store);
    } else {
      final withdraw = await showAppConfirmation(
        context,
        title: '撤回 AI 功能授权？',
        content: const Text(
          '撤回后，我们不再向 DeepSeek 提供您的内容，AI 简历生成、优化、单段生成和简历导入将无法使用，下次使用时会再次征求您的同意。撤回不影响撤回前已进行的处理。',
        ),
        confirmLabel: '撤回',
        destructive: true,
      );
      if (!mounted || withdraw != true) return;
      await runRequest(context, () => AiConsent.withdraw(widget.store));
    }
    await _loadAiConsent();
  }

  Future<void> _privacy(bool value) async {
    setState(() => savingPrivacy = true);
    await runRequest(context, () => widget.store.setPublicProfile(value));
    if (mounted) setState(() => savingPrivacy = false);
  }

  Future<void> _signOut() async {
    final confirmed = await showSignOutDialog(context);
    if (!mounted || confirmed != true || !widget.store.isAuthenticated) return;
    setState(() => signingOut = true);
    await runRequest(context, widget.store.endSession);
    if (mounted) setState(() => signingOut = false);
  }

  Future<void> _clearImages() async {
    final clear = await showAppConfirmation(
      context,
      title: '清理图片缓存？',
      content: const Text('清理本机保存的图片后，再次查看时会重新加载。已保存的简历和文件不受影响。'),
      confirmLabel: '清理',
    );
    if (!mounted || clear != true) return;
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
    refreshImageCache();
    toast(context, '图片缓存已清理');
    await NetworkImageStore.instance.clear();
    await refreshImageDisk();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.store,
    builder: (context, _) {
      final store = widget.store;
      final total = imageCacheBytes + imageDiskBytes;
      final cached = total < 1024
          ? '$total B'
          : total < 1024 * 1024
          ? '${(total / 1024).toStringAsFixed(1)} KB'
          : '${(total / (1024 * 1024)).toStringAsFixed(1)} MB';
      return _SettingsListPage(
        title: '返回',
        backgroundColor: context.isDark ? null : Colors.white,
        children: [
          if (store.isAuthenticated) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                _rowPadding,
                0,
                _rowPadding,
                20,
              ),
              child: Row(
                children: [
                  ProfileAvatar(
                    seed: profileAvatarSeed(store),
                    url: store.avatarURL,
                    size: _avatarSize,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userDisplayName(store.name),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '用户 ID：${store.publicID.isEmpty ? store.userID : store.publicID}',
                          style: TextStyle(
                            fontSize: 11,
                            color: context.colors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(
                      alignment: Alignment.centerRight,
                      minimumSize: _compactButtonSize,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: EdgeInsets.zero,
                      textStyle: const TextStyle(fontSize: 13),
                    ),
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
                  onTap: () =>
                      openPage(context, AccountSecurityPage(store: store)),
                ),
                _SettingsRow(
                  key: const ValueKey('settings-ai-consent'),
                  icon: AppIcons.aiOptimize,
                  title: 'AI 功能授权',
                  trailing: _SettingsSwitch(
                    value: aiConsentUser == store.userID && aiConsent == true,
                    onChanged: aiConsent == null ? null : _aiConsent,
                  ),
                ),
                _SettingsRow(
                  icon: AppIcons.publicProfile,
                  title: '公开个人介绍',
                  trailing: savingPrivacy
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : _SettingsSwitch(
                          value: store.publicProfile,
                          onChanged: savingPrivacy ? null : _privacy,
                        ),
                ),
              ],
            ),
          ],
          ValueListenableBuilder<AppearanceChoice>(
            valueListenable: store.appearance,
            builder: (context, choice, _) => _SettingsGroup(
              '外观',
              children: [
                _SettingsRow(
                  icon: AppIcons.templates,
                  title: '主题色',
                  value: choice.accent.label,
                  onTap: () => _chooseAppearance<AppAccent>(
                    title: '主题色',
                    choices: AppAccent.values,
                    selected: choice.accent,
                    label: (item) => item.label,
                    save: (item) => store.appearance.update(accent: item),
                  ),
                ),
                _SettingsRow(
                  icon: AppIcons.monochrome,
                  title: '外观模式',
                  value: choice.mode.label,
                  onTap: () => _chooseAppearance<ThemeMode>(
                    title: '外观模式',
                    choices: ThemeMode.values,
                    selected: choice.mode,
                    label: (item) => item.label,
                    save: (item) => store.appearance.update(mode: item),
                  ),
                ),
              ],
            ),
          ),
          _SettingsGroup(
            '应用管理',
            children: [
              _SettingsRow(
                icon: AppIcons.notificationSettings,
                title: '通知设置',
                onTap: () => _systemSettings('openNotifications'),
              ),
              _SettingsRow(
                icon: AppIcons.permissions,
                title: '系统权限',
                onTap: () => _systemSettings('openPermissions'),
              ),
              _SettingsRow(
                icon: AppIcons.imageCache,
                title: '图片缓存',
                value: cached,
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
                  onTap: () => openPage(context, buildFeedbackPage(store)),
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
              ListenableBuilder(
                listenable: AppUpdates.instance,
                builder: (context, _) {
                  final updates = AppUpdates.instance;
                  return _SettingsRow(
                    icon: AppIcons.about,
                    title: '关于最优简',
                    value: updates.hasUpdate ? null : 'v$version',
                    trailing: updates.hasUpdate ? const _NewVersionTag() : null,
                    onTap: () => openPage(context, AboutPage(store: store)),
                  );
                },
              ),
            ],
          ),
          if (store.isAuthenticated)
            OutlinedButton(
              key: const ValueKey('settings-sign-out'),
              onPressed: signingOut ? null : _signOut,
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
                backgroundColor: context.colors.surface,
                side: BorderSide(color: context.colors.border),
                minimumSize: const Size.fromHeight(40),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ).withoutHover(),
              child: Text(signingOut ? '正在退出…' : '退出登录'),
            ),
        ],
      );
    },
  );
}

/// Settings sub-page: titled bar over a centred, width-limited list.
class _SettingsListPage extends StatelessWidget {
  const _SettingsListPage({
    required this.title,
    required this.children,
    this.actions,
    this.backgroundColor,
    this.padding = const EdgeInsets.fromLTRB(
      appPageHorizontalPadding - _rowPadding,
      16,
      appPageHorizontalPadding - _rowPadding,
      32,
    ),
  });

  final String title;
  final List<Widget> children;
  final List<Widget>? actions;
  final Color? backgroundColor;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: backgroundColor,
    appBar: AppPageBar(
      title: Text(title),
      actions: actions,
      backgroundColor: backgroundColor,
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: ListView(
          padding: padding,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: children,
        ),
      ),
    ),
  );
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup(
    this.title, {
    required this.children,
    this.dividerInset = _rowPadding + _labelOffset,
  });
  final String title;
  final List<Widget> children;
  final double dividerInset;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: _rowPadding, bottom: 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: context.colors.muted,
            ),
          ),
        ),
        Material(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(14),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0)
                  Padding(
                    padding: EdgeInsets.only(
                      left: dividerInset,
                      right: _rowPadding,
                    ),
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

/// Platform switch drawn at three quarters of its native size so a row
/// with a switch is no taller than one with a chevron.
class _SettingsSwitch extends StatelessWidget {
  const _SettingsSwitch({required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 24,
    child: FittedBox(
      alignment: Alignment.centerRight,
      child: Switch.adaptive(
        padding: EdgeInsets.zero,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        value: value,
        activeTrackColor: context.colors.palette.seed,
        onChanged: onChanged,
      ),
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
    this.titleColor,
  });
  final AppIconData? icon;
  final Color? titleColor;
  final String title;
  final String? subtitle, value;
  final VoidCallback? onTap;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: _rowPadding,
        vertical: 12,
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            SizedBox(
              width: _labelOffset,
              child: Align(
                alignment: Alignment.centerLeft,
                child: AppIcon(icon!, size: 18, color: context.colors.ink),
              ),
            ),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: titleColor ?? context.colors.ink,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 11,
                      color: context.colors.muted,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (value != null) ...[
            const SizedBox(width: 8),
            Text(
              value!,
              style: TextStyle(fontSize: 12, color: context.colors.muted),
            ),
          ],
          if (trailing != null)
            trailing!
          else if (onTap != null) ...[
            const SizedBox(width: 8),
            AppIcon(AppIcons.forward, size: 14, color: context.colors.muted),
          ],
        ],
      ),
    ),
  );
}

/// 意见反馈 / 账号申诉页，供在线客服等入口使用。
Widget buildFeedbackPage(
  AppStore store, {
  bool appeal = false,
  String initialText = '',
}) => appeal
    ? _AppealPage(store: store, initialText: initialText)
    : FeedbackPage(store: store, initialText: initialText);

class _AppealPage extends StatefulWidget {
  const _AppealPage({required this.store, this.initialText = ''});
  final String initialText;
  final AppStore store;
  @override
  State<_AppealPage> createState() => _AppealPageState();
}

class _AppealPageState extends State<_AppealPage> {
  late final text = TextEditingController.fromValue(
    TextEditingValue(
      text: widget.initialText,
      selection: TextSelection.collapsed(offset: widget.initialText.length),
    ),
  );
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
    if (utf8.encode(text.text.trim()).length > 1000) {
      toast(context, '反馈内容过长，请适当缩短');
      return;
    }
    dismissKeyboard();
    setState(() => sending = true);
    final done = await runRequest(context, () async {
      await widget.store.request(
        'PostAppeals',
        body: {
          'subject_type': 'USER',
          'subject_id': widget.store.userID,
          'reason': text.text.trim(),
        },
      );
    });
    if (!mounted) return;
    if (done) {
      Navigator.pop(context);
      toast(context, '申诉已提交');
    } else {
      setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => _SettingsListPage(
    title: '账号申诉',
    actions: const [DismissKeyboardButton()],
    padding: const EdgeInsets.symmetric(
      horizontal: appPageHorizontalPadding,
      vertical: 24,
    ),
    children: [
      Text(
        '请描述账号遇到的问题，并留下可联系的方式，便于核实和处理。',
        style: TextStyle(
          fontSize: 13,
          color: context.colors.muted,
          height: 1.6,
        ),
      ),
      const SizedBox(height: 20),
      TextField(
        controller: text,
        enabled: !sending,
        minLines: 8,
        maxLines: 14,
        maxLength: 300,
        decoration: InputDecoration(
          hintText: '问题描述与联系方式…',
          fillColor: context.colors.surface,
        ),
        style: const TextStyle(fontSize: 14, height: 1.7),
      ),
      const SizedBox(height: 20),
      FilledButton(
        onPressed: sending ? null : submit,
        child: Text(sending ? '正在提交…' : '提交申诉'),
      ),
    ],
  );
}

class AccountSecurityPage extends StatefulWidget {
  const AccountSecurityPage({super.key, required this.store});
  final AppStore store;
  @override
  State<AccountSecurityPage> createState() => _SecurityPageState();
}

class _SecurityPageState extends State<AccountSecurityPage> {
  Future<void> bindPhone() async {
    await showPhoneBindingDialog(context, store: widget.store);
    if (mounted) setState(() {});
  }

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
    final confirmed = await showAccountDeletionDialog(context);
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
    final confirmed = await showAppConfirmation(
      context,
      title: '退出该设备？',
      content: Text(current ? '当前设备将退出登录。' : '该设备需要重新登录后才能继续使用最优简。'),
      confirmLabel: '退出登录',
      destructive: true,
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
    'WEB' => '网页',
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
    final desktop = ['MACOS', 'WINDOWS', 'WEB'].contains(session['platform']);
    final reportedName = '${session['device_name'] ?? ''}'.trim();
    final reportedModel = '${session['device_model'] ?? ''}'.trim();
    final title = reportedName.isNotEmpty
        ? reportedName
        : reportedModel.isNotEmpty
        ? reportedModel
        : current
        ? widget.store.deviceMetadata.model.trim()
        : '';
    final reportedOS = '${session['os_version'] ?? ''}'.trim();
    final osVersion = reportedOS.isNotEmpty
        ? reportedOS
        : current
        ? widget.store.deviceMetadata.osVersion
        : '';
    final busy = revoking.contains(integer(session['id']));
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: _rowPadding,
        vertical: 10,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: _labelOffset,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: AppIcon(
                    desktop ? AppIcons.computer : AppIcons.phone,
                    size: 21,
                    color: context.colors.ink,
                  ),
                ),
              ),
              Expanded(
                child: Wrap(
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
                          color: context.colors.accent.withValues(alpha: .08),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          '当前设备',
                          style: TextStyle(
                            fontSize: 10,
                            color: context.colors.accent,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              TextButton(
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: _compactButtonSize,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  alignment: Alignment.centerRight,
                ),
                onPressed: busy ? null : () => revokeSession(session),
                child: Text(
                  busy ? '正在退出…' : '退出登录',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: _labelOffset, bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '系统：${platformName(session['platform'])}${osVersion.isEmpty ? '' : ' $osVersion'}',
                  style: TextStyle(fontSize: 11, color: context.colors.muted),
                ),
                const SizedBox(height: 4),
                Text(
                  '登录时间：${loginTime(session['logged_in_at'])}',
                  style: TextStyle(fontSize: 11, color: context.colors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => _SettingsListPage(
    title: '账号安全',
    children: [
      _SettingsGroup(
        '登录设备',
        children: [
          if (loading)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else if (error != null)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: _rowPadding,
                vertical: 20,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    error!,
                    style: TextStyle(fontSize: 12, color: context.colors.muted),
                  ),
                  const SizedBox(height: 8),
                  TextButton(onPressed: load, child: const Text('重新加载')),
                ],
              ),
            )
          else if (sessions.isEmpty)
            const EmptyState('暂无登录设备', '', compact: true)
          else
            for (final session in sessions) deviceRow(session),
        ],
      ),
      _SettingsGroup(
        '账号管理',
        dividerInset: _rowPadding,
        children: [
          ListenableBuilder(
            listenable: widget.store,
            builder: (_, _) => _SettingsRow(
              key: const ValueKey('security-phone-binding'),
              title: '手机号',
              value: widget.store.hasBoundPhone
                  ? widget.store.phoneMasked
                  : widget.store.phoneBindingChecked
                  ? '未绑定'
                  : '待获取',
              subtitle: '用于账号联系与安全验证',
              onTap: widget.store.hasBoundPhone ? null : bindPhone,
            ),
          ),
          _SettingsRow(
            title: '账号申诉',
            subtitle: '账号使用遇到问题，提交申诉协助处理',
            onTap: () => openPage(context, _AppealPage(store: widget.store)),
          ),
          _SettingsRow(
            title: deleting ? '正在申请注销…' : '账号注销',
            titleColor: Theme.of(context).colorScheme.error,
            subtitle: '注销后账号及相关数据将被删除，请先保存需要的内容',
            onTap: deleting ? null : deleteAccount,
          ),
        ],
      ),
    ],
  );
}

/// 设置里“关于最优简”的新版本提示：红点加文字。
class _NewVersionTag extends StatelessWidget {
  const _NewVersionTag();

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: Color(0xFFE5322D),
          shape: BoxShape.circle,
        ),
      ),
      const SizedBox(width: 6),
      Text('有新版本', style: TextStyle(fontSize: 12, color: context.colors.muted)),
    ],
  );
}
