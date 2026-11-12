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

  Future<void> acceptFriend(int id) async {
    await request('PostFriendRequestsIdAccept', path: {'id': '$id'}, body: {});
    await load('messages');
  }

  Future<void> updateProfile(
    String newName,
    String newBio, {
    bool updateName = true,
  }) async {
    final version = epoch;
    final v = await request(
      'PatchMe',
      body: {if (updateName) 'nickname': newName, 'bio': newBio},
    );
    if (version != epoch || !alive) return;
    if (v.data.containsKey('avatar_url')) {
      avatarURL = v.data['avatar_url'] as String? ?? '';
    }
    name = v.data['nickname'] as String? ?? (updateName ? newName : name);
    bio = v.data['bio'] as String? ?? newBio;
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

  Future<int?> claimReward() async => perform<int>('reward', () async {
    final version = epoch;
    final response = await request(
      'PostWalletDailyRewardClaims',
      body: {},
      extra: {
        'idempotency-key':
            'mobile-daily-$userID-${DateTime.now().toUtc().add(const Duration(hours: 8)).toIso8601String().substring(0, 10)}',
      },
    );
    if (version != epoch || !alive) return 0;
    if (integer(response.data['id']) <= 0 || response.data['points'] is! num) {
      throw const ApiFailure('领取结果暂不可用，请刷新积分后重试');
    }
    rewardClaimed = true;
    rewardPoints = integer(response.data['points']);
    if (response.data['reward'] case final Map data) {
      readReward(Map<String, dynamic>.from(data));
    }
    final wallet = response.data['wallet'];
    if (wallet is Map && wallet['available_points'] is num) {
      points = integer(wallet['available_points']);
    }
    changed();
    // The claim response already confirms the reward and normally includes the
    // authoritative balance. Refresh only the wallet when it is missing, so
    // claiming does not put the entire profile page back into a loading state.
    if (wallet is! Map || wallet['available_points'] is! num) {
      try {
        final balance = await request('GetWallet');
        if (version == epoch &&
            alive &&
            balance.data['available_points'] is num) {
          points = integer(balance.data['available_points']);
          changed();
        }
      } catch (_) {
        // A balance refresh failure must not undo a confirmed claim or invent
        // a new balance. The next profile refresh can fetch the real balance.
      }
    }
    return response.data['deduplicated'] == true
        ? 0
        : integer(response.data['points']);
  });
}
