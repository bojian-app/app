part of 'discovery.dart';

const _discoveryAvatarSize = 24.0;

class _DiscoveryAvatarMenu extends StatelessWidget {
  const _DiscoveryAvatarMenu({
    required this.store,
    required this.onOpenProfile,
    required this.onOpenMembership,
    required this.onOpenService,
    required this.onScan,
  });

  final AppStore store;
  final VoidCallback? onOpenProfile, onOpenMembership, onOpenService, onScan;

  @override
  Widget build(BuildContext context) => _DiscoveryMenuButton(
    key: const ValueKey('discovery-profile'),
    tooltip: '我的',
    items: [
      _headerMenuItem(
        'discovery-create-story',
        '发布新动态',
        AppIcons.createArticle,
        () {
          if (!store.isAuthenticated) {
            store.endSession();
            return;
          }
          openPage(context, StoryComposer(store: store));
        },
      ),
      _headerMenuItem('discovery-add-resume', '添加简历', AppIcons.addResume, () {
        if (!store.isAuthenticated) {
          store.endSession();
          return;
        }
        ResumeLibrary(store: store).showAddOptions(context);
      }),
      const PopupMenuDivider(),
      if (onOpenProfile != null)
        _headerMenuItem(
          'discovery-my-page',
          '个人资料',
          AppIcons.userAccount,
          onOpenProfile,
        ),
      if (onOpenMembership != null)
        _headerMenuItem(
          'discovery-membership',
          '成为会员',
          AppIcons.honourStar,
          onOpenMembership,
        ),
      if (onOpenService != null)
        _headerMenuItem(
          'discovery-service',
          '在线客服',
          AppIcons.headset,
          onOpenService,
        ),
      _headerMenuItem('discovery-scan', '扫一扫', AppIcons.scan, onScan),
    ],
    icon: UpdateBadge(
      child: ProfileAvatar(
        seed: profileAvatarSeed(store),
        url: store.avatarURL,
        size: _discoveryAvatarSize,
        borderRadius: _discoveryAvatarSize / 2,
      ),
    ),
  );
}

PopupMenuItem<VoidCallback> _headerMenuItem(
  String key,
  String label,
  AppIconData icon,
  VoidCallback? action,
) => PopupMenuItem<VoidCallback>(
  key: ValueKey(key),
  value: action,
  enabled: action != null,
  height: 44,
  padding: const EdgeInsets.symmetric(horizontal: 14),
  child: Row(
    spacing: 10,
    children: [
      AppIcon(icon, size: 18),
      Flexible(child: Text(label, style: const TextStyle(fontSize: 14))),
    ],
  ),
);

class _DiscoveryMenuButton extends StatelessWidget {
  const _DiscoveryMenuButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.items,
  });

  final String tooltip;
  final Widget icon;
  final List<PopupMenuEntry<VoidCallback>> items;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<VoidCallback>(
      tooltip: tooltip,
      position: PopupMenuPosition.under,
      offset: const Offset(0, 2),
      padding: EdgeInsets.zero,
      style: IconButton.styleFrom(
        minimumSize: const Size.square(32),
        fixedSize: const Size.square(32),
        tapTargetSize: MaterialTapTargetSize.padded,
        visualDensity: VisualDensity.standard,
      ),
      constraints: const BoxConstraints(minWidth: 124, maxWidth: 200),
      color: context.colors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      // The route uses one duration both ways, so a short one makes the menu
      // vanish the moment an entry is chosen instead of lingering for 300 ms.
      popUpAnimationStyle: const AnimationStyle(
        duration: Duration(milliseconds: 100),
        curve: Curves.easeOutCubic,
      ),
      onOpened: dismissKeyboard,
      onSelected: (action) => action(),
      itemBuilder: (_) => items,
      icon: icon,
    );
  }
}
