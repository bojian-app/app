import 'user_display_name.dart';
import 'playful_refresh.dart';
export 'settings_page.dart' show SettingsPage;
import 'settings_page.dart';
export 'messages_page.dart' show MessagesPage;
import 'app_icons.dart';

import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';

import 'app_store.dart';
import 'design.dart';
import 'discovery.dart';
import 'resume_pages.dart';
import 'profile_points_card.dart';
import 'profile_avatar.dart';
import 'resume_photo.dart';
import 'resume_photo_crop.dart';
import 'sign_out_dialog.dart';

class AddFriendSheet extends StatefulWidget {
  const AddFriendSheet({super.key, required this.store});
  final AppStore store;
  @override
  State<AddFriendSheet> createState() => _AddFriendSheetState();
}

class _AddFriendSheetState extends State<AddFriendSheet> {
  final query = TextEditingController();
  List<Map<String, dynamic>> results = [];
  bool loading = false, searched = false;
  String? error;
  Future<void> search() async {
    if (query.text.trim().isEmpty) return;
    dismissKeyboard();
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final response = await widget.store.request(
        'GetUsersSearch',
        query: {'query': query.text.trim()},
      );
      if (mounted) {
        setState(() {
          results = items(response.data);
          searched = true;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: EdgeInsets.fromLTRB(
      24,
      8,
      24,
      24 + MediaQuery.viewInsetsOf(context).bottom,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '找到一起进步的人',
          style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: query,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => search(),
          decoration: InputDecoration(
            hintText: '搜索昵称或博简 ID',
            suffixIcon: IconButton(
              onPressed: loading ? null : search,
              tooltip: '搜索用户',
              icon: const AppIcon(AppIcons.search),
            ),
          ),
        ),
        const SizedBox(height: 20),
        if (loading) const Center(child: CircularProgressIndicator()),
        if (error != null) Text(error!, style: const TextStyle(color: muted)),
        if (searched && results.isEmpty && error == null)
          const Text('没有找到匹配的用户。', style: TextStyle(color: muted)),
        for (final user in results)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(userDisplayName(user['display_name'])),
            subtitle: Text('${user['public_id'] ?? ''}'),
            trailing: TextButton(
              onPressed: user['relationship'] != 'NONE'
                  ? null
                  : () async {
                      final sent = await runRequest(context, () async {
                        await widget.store.request(
                          'PostFriendRequests',
                          body: {
                            'addressee_id': integer(user['id']),
                            'message': '',
                          },
                        );
                      });
                      if (sent && mounted) {
                        setState(() => user['relationship'] = 'OUTGOING');
                      }
                    },
              child: Text(
                user['relationship'] == 'FRIEND'
                    ? '已是好友'
                    : user['relationship'] == 'OUTGOING'
                    ? '已申请'
                    : '添加',
              ),
            ),
          ),
      ],
    ),
  );
  @override
  void dispose() {
    query.dispose();
    super.dispose();
  }
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key, required this.store});
  final AppStore store;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) => PlayfulRefresh(
      hasError: () => store.errors['profile'] != null,
      onRefresh: () => store.load('profile'),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
        children: [
          if (store.isAuthenticated) ...[
            Semantics(
              label: '编辑个人资料',
              button: true,
              child: _ProfileSurface(
                onTap: () => openPage(context, ProfileEditor(store: store)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      ProfileAvatar(
                        seed: profileAvatarSeed(store),
                        url: store.avatarURL,
                        size: 36,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              userDisplayName(store.name),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (store.publicID.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                '用户 ID：${store.publicID}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: muted,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      const AppIcon(
                        AppIcons.profileEdit,
                        size: 18,
                        color: muted,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            ProfilePointsCard(store: store),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _shortcut(
                    context,
                    '我的文章',
                    AppIcons.article,
                    () => openPage(
                      context,
                      StorySearch(store: store, mineOnly: true),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _shortcut(
                    context,
                    '我的收藏',
                    AppIcons.bookmark,
                    () => openPage(
                      context,
                      StorySearch(store: store, savedOnly: true),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _ProfileSurface(
              child: Column(
                children: [
                  _menu(
                    context,
                    '模板市场',
                    AppIcons.templateMarket,
                    () => openPage(context, TemplateMarket(store: store)),
                  ),
                  const Divider(height: 1, indent: 58, endIndent: 18),
                  _menu(
                    context,
                    '身份认证',
                    AppIcons.identityVerification,
                    () => openPage(context, VerificationPage(store: store)),
                  ),
                  const Divider(height: 1, indent: 58, endIndent: 18),
                  _menu(
                    context,
                    '隐私与设置',
                    AppIcons.settings,
                    () => openPage(context, SettingsPage(store: store)),
                  ),
                ],
              ),
            ),
          ],
          if (!store.isAuthenticated || store.errors['profile'] != null)
            DataStatus(store: store, section: 'profile', empty: false),
          if (store.isAuthenticated) ...[
            SizedBox(
              height: 24,
              child: store.loading.contains('profile')
                  ? const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: LinearProgressIndicator(minHeight: 2),
                      ),
                    )
                  : null,
            ),
            _SignOutButton(store: store),
          ],
        ],
      ),
    ),
  );

  Widget _shortcut(
    BuildContext context,
    String label,
    AppIconData icon,
    VoidCallback onTap,
  ) => _ProfileSurface(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      child: Row(
        children: [
          AppIcon(icon, size: 22, color: blue),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _menu(
    BuildContext context,
    String label,
    AppIconData icon,
    VoidCallback onTap,
  ) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 3),
    minLeadingWidth: 22,
    leading: AppIcon(icon, size: 22, color: ink),
    title: Text(label, style: const TextStyle(fontSize: 14)),
    trailing: const AppIcon(AppIcons.forward, size: 16, color: muted),
    onTap: onTap,
  );
}

class _ProfileSurface extends StatelessWidget {
  const _ProfileSurface({required this.child, this.onTap});
  final Widget child;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: const BorderSide(color: borderColor),
    ),
    clipBehavior: Clip.antiAlias,
    child: onTap == null ? child : InkWell(onTap: onTap, child: child),
  );
}

class _SignOutButton extends StatefulWidget {
  const _SignOutButton({required this.store});
  final AppStore store;
  @override
  State<_SignOutButton> createState() => _SignOutButtonState();
}

class _SignOutButtonState extends State<_SignOutButton> {
  bool busy = false;
  @override
  Widget build(BuildContext context) => OutlinedButton(
    key: const ValueKey('account-sign-out'),
    style: OutlinedButton.styleFrom(
      foregroundColor: const Color(0xFFB75B5B),
      backgroundColor: Colors.white,
      side: const BorderSide(color: borderColor),
      minimumSize: const Size.fromHeight(48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    onPressed: busy
        ? null
        : () async {
            final confirmed = await showSignOutDialog(context);
            if (!context.mounted || confirmed != true) return;
            setState(() => busy = true);
            await runRequest(context, widget.store.endSession);
            if (mounted) setState(() => busy = false);
          },
    child: Text(busy ? '正在退出…' : '退出登录'),
  );
}

class ProfileEditor extends StatefulWidget {
  const ProfileEditor({super.key, required this.store});
  final AppStore store;
  @override
  State<ProfileEditor> createState() => _ProfileEditorState();
}

class _ProfileEditorState extends State<ProfileEditor> {
  late final name = TextEditingController(text: widget.store.name);
  late final bio = TextEditingController(text: widget.store.bio);
  bool saving = false, choosing = false;
  int? selectedAvatar;
  XFile? selectedPhoto;
  String get avatarSeed => profileAvatarSeed(widget.store);
  int? get currentSystemAvatar =>
      selectedAvatar ??
      (selectedPhoto != null
          ? null
          : storedSystemAvatar(widget.store.avatarURL) ??
                (widget.store.avatarURL.isEmpty
                    ? assignedAvatar(avatarSeed)
                    : null));

  Future<void> chooseAvatar() async {
    if (saving || choosing) return;
    dismissKeyboard();
    setState(() => choosing = true);
    try {
      final choice = await showModalBottomSheet<Object>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        backgroundColor: Colors.white,
        builder: (context) => ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .78,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '更换头像',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 20),
                const Text(
                  '系统头像',
                  style: TextStyle(fontSize: 12, color: muted),
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) => Wrap(
                    spacing: 12,
                    runSpacing: 14,
                    children: [
                      for (var i = 0; i < systemAvatarNames.length; i++)
                        SizedBox(
                          width: (constraints.maxWidth - 36) / 4,
                          child: Semantics(
                            selected: currentSystemAvatar == i,
                            child: InkWell(
                              key: ValueKey('system-avatar-$i'),
                              borderRadius: BorderRadius.circular(14),
                              onTap: () => Navigator.pop(context, i),
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(
                                        width: 2,
                                        color: currentSystemAvatar == i
                                            ? blue
                                            : Colors.transparent,
                                      ),
                                    ),
                                    child: ProfileAvatar(
                                      seed: '',
                                      variant: i,
                                      size:
                                          (constraints.maxWidth - 36) / 4 - 10,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    systemAvatarNames[i],
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.pop(context, 'upload'),
                    icon: const AppIcon(AppIcons.avatarUpload, size: 20),
                    label: const Text('上传自己的头像'),
                  ),
                ),
                const SizedBox(height: 8),
                const Center(
                  child: Text(
                    '支持 JPG、PNG、WebP，最大 5 MB',
                    style: TextStyle(fontSize: 11, color: muted),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      if (!mounted) return;
      if (choice is int) {
        final previous = selectedPhoto;
        setState(() {
          selectedAvatar = choice;
          selectedPhoto = null;
        });
        await discardResumePhotoCrop(previous);
      } else if (choice == 'upload') {
        final file = await openFile(acceptedTypeGroups: [resumePhotoTypes]);
        if (file == null || !mounted) return;
        await validateResumePhoto(file);
        if (!mounted) return;
        final cropped = await openPage<XFile>(
          context,
          ResumePhotoCropPage(file: file, aspectRatio: 1),
        );
        if (!mounted) {
          await discardResumePhotoCrop(cropped);
          return;
        }
        if (cropped != null) {
          final previous = selectedPhoto;
          setState(() {
            selectedPhoto = cropped;
            selectedAvatar = null;
          });
          await discardResumePhotoCrop(previous);
        }
      }
    } catch (e) {
      if (mounted) toast(context, '$e');
    } finally {
      if (mounted) setState(() => choosing = false);
    }
  }

  Future<void> saveProfile() async {
    if (saving || choosing) return;
    if (name.text.trim().isEmpty) {
      toast(context, '给自己取一个昵称吧');
      return;
    }
    dismissKeyboard();
    setState(() => saving = true);
    final epoch = widget.store.epoch;
    final saved = await runRequest(context, () async {
      XFile? generated;
      try {
        if (selectedAvatar != null) {
          generated = await createSystemAvatarFile(selectedAvatar!);
        }
        final photo = generated ?? selectedPhoto;
        if (photo != null) {
          await uploadProfileAvatar(widget.store, photo);
          if (mounted) {
            setState(() {
              selectedAvatar = null;
            });
          }
          await discardResumePhotoCrop(selectedPhoto);
          selectedPhoto = null;
        }
        if (epoch != widget.store.epoch) return;
        await widget.store.updateProfile(name.text.trim(), bio.text.trim());
      } finally {
        if (generated != null) await discardSystemAvatarFile(generated);
      }
    });
    if (!mounted || epoch != widget.store.epoch) return;
    if (saved) {
      setState(() => saving = false);
      Navigator.pop(context);
      toast(context, '个人资料已更新');
    } else {
      setState(() => saving = false);
    }
  }

  Widget _avatarSection() => _ProfileSurface(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            label: '更换个人头像',
            button: true,
            child: InkWell(
              onTap: saving || choosing ? null : chooseAvatar,
              borderRadius: BorderRadius.circular(30),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: canvasColor,
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(color: borderColor),
                    ),
                    child: ProfileAvatar(
                      seed: avatarSeed,
                      url: widget.store.avatarURL,
                      variant: selectedAvatar,
                      file: selectedPhoto,
                      size: 84,
                    ),
                  ),
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: blue,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                      ),
                      child: const AppIcon(
                        AppIcons.avatarEdit,
                        size: 13,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextButton(
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 36),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              textStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            onPressed: saving || choosing ? null : chooseAvatar,
            child: Text(choosing ? '选择中…' : '更换头像'),
          ),
        ],
      ),
    ),
  );

  Widget _profileField(
    TextEditingController controller,
    String label,
    int limit, {
    bool multiline = false,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) => Text(
              '${value.text.characters.length}/$limit',
              style: const TextStyle(fontSize: 10, color: muted),
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      TextField(
        key: ValueKey(multiline ? 'profile-bio' : 'profile-name'),
        controller: controller,
        enabled: !saving,
        textInputAction: multiline
            ? TextInputAction.newline
            : TextInputAction.next,
        minLines: multiline ? 4 : 1,
        maxLines: multiline ? 6 : 1,
        maxLength: limit,
        buildCounter: (
          _, {
          required currentLength,
          required isFocused,
          maxLength,
        }) => null,
        style: TextStyle(
          fontSize: multiline ? 14 : 16,
          height: 1.6,
          fontWeight: multiline ? FontWeight.w400 : FontWeight.w600,
        ),
        decoration: InputDecoration(
          hintText: multiline ? '介绍一下自己' : '填写你的昵称',
          fillColor: canvasColor,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 13,
          ),
        ),
      ),
    ],
  );

  Widget _detailsSection() => _ProfileSurface(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _profileField(name, '昵称', 20),
          const SizedBox(height: 20),
          const Divider(height: 1),
          const SizedBox(height: 20),
          _profileField(bio, '个人简介', 120, multiline: true),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('编辑个人资料'),
        actions: const [DismissKeyboardButton()],
      ),
      body: GestureDetector(
        onTap: dismissKeyboard,
        behavior: HitTestBehavior.translucent,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: LayoutBuilder(
              builder: (context, constraints) => ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                children: [
                  if (constraints.maxWidth >= 600)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(width: 190, child: _avatarSection()),
                        const SizedBox(width: 16),
                        Expanded(child: _detailsSection()),
                      ],
                    )
                  else ...[
                    _avatarSection(),
                    const SizedBox(height: 16),
                    _detailsSection(),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: borderColor)),
          ),
          child: SafeArea(
            top: false,
            child: Center(
              heightFactor: 1,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      key: const ValueKey('profile-save'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      onPressed: saving || choosing ? null : saveProfile,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (saving) ...[
                            const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            const SizedBox(width: 10),
                          ],
                          Text(saving ? '正在保存…' : '保存资料'),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  @override
  void dispose() {
    discardResumePhotoCrop(selectedPhoto);
    name.dispose();
    bio.dispose();
    super.dispose();
  }
}

class VerificationPage extends StatefulWidget {
  const VerificationPage({super.key, required this.store});
  final AppStore store;
  @override
  State<VerificationPage> createState() => _VerificationPageState();
}

class _VerificationPageState extends State<VerificationPage> {
  late Future<Map<String, dynamic>> result = load();
  Future<Map<String, dynamic>> load() async =>
      (await widget.store.request('GetMeIdentityVerification')).data;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('身份认证')),
    body: FutureBuilder(
      future: result,
      builder: (context, snapshot) => ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const AppIcon(AppIcons.identityVerification, size: 54, color: blue),
          const SizedBox(height: 24),
          if (snapshot.connectionState == ConnectionState.waiting)
            const Center(child: CircularProgressIndicator())
          else if (snapshot.hasError) ...[
            Text('${snapshot.error}'),
            TextButton(
              onPressed: () => setState(() => result = load()),
              child: const Text('重试'),
            ),
          ] else ...[
            Text(
              switch (snapshot.data?['status']) {
                'APPROVED' => '已认证',
                'PENDING' => '审核中',
                'REJECTED' => '认证未通过',
                _ => '尚未认证',
              },
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 18),
            const Text(
              '提交证件资料请使用博简桌面端，认证结果会同步到这里。',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, height: 1.8, color: muted),
            ),
          ],
        ],
      ),
    ),
  );
}
