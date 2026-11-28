part of 'app_store.dart';

/// Inbox, friends, profile and rewards.
extension AppStoreSocial on AppStore {
  Future<void> markRead(InboxItem item) async {
    if (item.read) return;
    final version = epoch;
    await request(
      'PostNotificationsRead',
      body: {
        'ids': [item.id],
      },
    );
    if (!alive || version != epoch) return;
    item.read = true;
    notificationUnreadCount = (notificationUnreadCount - 1).clamp(0, 1 << 31);
    changed();
  }

  Future<void> markAllRead() async {
    final version = epoch;
    await request('PostNotificationsReadAll', body: {});
    if (!alive || version != epoch) return;
    for (final item in inbox) {
      item.read = true;
    }
    notificationUnreadCount = 0;
    changed();
  }

  /// Clearing hides a notification from the inbox; the server keeps the row
  /// for anything still linked to it.
  Future<void> clearNotification(InboxItem item) async {
    final version = epoch;
    await request('DeleteNotificationsId', path: {'id': '${item.id}'});
    if (!alive || version != epoch) return;
    inbox.removeWhere((value) => value.id == item.id);
    if (!item.read) {
      notificationUnreadCount = (notificationUnreadCount - 1).clamp(0, 1 << 31);
    }
    changed();
  }

  Future<void> clearAllNotifications() async {
    final version = epoch;
    await request('PostNotificationsClear', body: {});
    if (!alive || version != epoch) return;
    inbox.clear();
    cursors.remove('messages');
    notificationUnreadCount = 0;
    changed();
  }

  Future<void> acceptFriend(int id) async {
    await request('PostFriendRequestsIdAccept', path: {'id': '$id'}, body: {});
    await load('messages');
  }

  Future<void> updateProfile(
    String newName,
    String newBio, {
    bool updateName = true,
    bool updateBio = true,
  }) async {
    final version = epoch;
    final v = await request(
      'PatchMe',
      body: {if (updateName) 'nickname': newName, if (updateBio) 'bio': newBio},
    );
    if (version != epoch || !alive) return;
    if (v.data.containsKey('avatar_url')) {
      avatarURL = v.data['avatar_url'] as String? ?? '';
    }
    name = v.data['nickname'] as String? ?? (updateName ? newName : name);
    bio = v.data['bio'] as String? ?? (updateBio ? newBio : bio);
    changed();
  }

  Future<void> setPublicProfile(bool value) async {
    final v = await request(
      'PatchMe',
      body: {'profile_visibility': value ? 'PUBLIC' : 'PRIVATE'},
    );
    publicProfile = v.data['profile_visibility'] == 'PUBLIC';
    changed();
  }
}
