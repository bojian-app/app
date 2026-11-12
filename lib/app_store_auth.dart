part of 'app_store.dart';

/// Sign-in, account binding and session teardown.
extension AppStoreAuth on AppStore {
  Future<bool> signIn(
    String phone,
    String code, {
    String? nickname,
    Future<bool> Function()? confirmRegistration,
  }) async {
    phone = phone
        .trim()
        .replaceAll(RegExp(r'[ -]'), '')
        .replaceFirst(RegExp(r'^\+86'), '');
    if (!RegExp(r'^1[3-9]\d{9}$').hasMatch(phone) ||
        !RegExp(r'^\d{6}$').hasMatch(code)) {
      throw const ApiFailure('请输入正确的手机号和六位验证码');
    }
    await initialize();
    final version = epoch;
    final response = await api.login(phone, code, headers);
    return _resolveSignIn(
      response,
      version,
      nickname: nickname,
      verifiedPhone: phone,
      confirmRegistration: confirmRegistration,
    );
  }

  Future<bool> signInWithWeChat({
    Future<bool> Function()? confirmRegistration,
    LoginPhoneBinding? bindPhone,
  }) async {
    await initialize();
    final version = epoch;
    final code = await weChatAuthorizer.authorize();
    if (version != epoch || !alive) throw const ApiFailure('登录已取消');
    if (code == null) return false;
    final response = await api.loginWithWeChat(
      code,
      legalAgreementVersions,
      headers,
    );
    return _resolveSignIn(
      response,
      version,
      confirmRegistration: confirmRegistration,
      bindPhone: bindPhone,
    );
  }

  Future<bool> signInWithDouyin({
    Future<bool> Function()? confirmRegistration,
    LoginPhoneBinding? bindPhone,
  }) async {
    await initialize();
    final version = epoch;
    final code = await douyinAuthorizer.authorize();
    if (version != epoch || !alive) throw const ApiFailure('登录已取消');
    if (code == null) return false;
    final response = await api.loginWithDouyin(
      code,
      legalAgreementVersions,
      headers,
    );
    return _resolveSignIn(
      response,
      version,
      confirmRegistration: confirmRegistration,
      bindPhone: bindPhone,
    );
  }

  Future<auth.SMSResponse> sendPhoneBindingCode(
    String phone,
    String captchaToken,
  ) async {
    final version = epoch;
    final result = await request(
      'PostMePhoneSMSCodes',
      expectedEpoch: version,
      body: {
        'phone': phone,
        'captcha_token': captchaToken,
        'purpose': 'BIND_PHONE',
      },
    );
    return auth.SMSResponse(
      retryAfterSeconds: integer(result.data['retry_after_seconds']),
      deliveryStatus: result.data['delivery_status'] as String?,
      testCode: AppEnvironment.smsTestCode(phone, result.data['test_code']),
    );
  }

  Future<void> bindPhone(String phone, String code) async {
    if (!RegExp(r'^1[3-9]\d{9}$').hasMatch(phone) ||
        !RegExp(r'^\d{6}$').hasMatch(code)) {
      throw const ApiFailure('请输入正确的手机号和六位验证码');
    }
    if (pending.contains('bind-phone')) throw const ApiFailure('正在绑定手机号，请稍候');
    final version = epoch;
    await perform('bind-phone', () async {
      final result = await request(
        'PostMePhone',
        expectedEpoch: version,
        body: {'phone': phone, 'code': code},
      );
      final masked = result.data['phone_masked'];
      if (masked is! String ||
          !RegExp(r'^1[3-9]\d\*{4}\d{4}$').hasMatch(masked)) {
        throw const ApiFailure('手机号绑定结果暂未确认，请稍后重试');
      }
      ++_phoneBindingRevision;
      phoneMasked = masked;
      phoneBindingChecked = true;
      session = {...session!, 'phone_masked': masked};
      await persist(session, version);
      if (result.data['accounts_merged'] == true) {
        // Await in-flight loads before refreshing data moved by the transaction.
        await Future.wait(sectionRequests.values.toList());
        if (version == epoch && alive) await loadAll();
      }
      changed();
    });
  }

  /// Proves [phone] for a pending WeChat or Douyin login.
  Future<auth.LoginResponse> confirmLoginPhoneBinding(
    String token,
    String phone,
    String code,
  ) => api.confirmLoginPhoneBinding(
    token,
    phone,
    code,
    legalAgreementVersions,
    headers,
  );

  Future<bool> _resolveSignIn(
    auth.LoginResponse response,
    int version, {
    String? nickname,
    String? verifiedPhone,
    Future<bool> Function()? confirmRegistration,
    LoginPhoneBinding? bindPhone,
  }) async {
    if (version != epoch || !alive) throw const ApiFailure('登录已取消');
    if (response.phoneBindingRequired) {
      if (response.phoneBindingToken.isEmpty ||
          response.phoneBindingExpiresInSeconds <= 0 ||
          response.registrationRequired ||
          response.accessToken.isNotEmpty ||
          response.refreshToken.isNotEmpty ||
          response.hasUser()) {
        throw const ApiFailure('服务器返回的手机号验证信息无效');
      }
      if (bindPhone == null) throw const ApiFailure('请先验证手机号后再登录');
      final bound = await bindPhone(response.phoneBindingToken);
      if (version != epoch || !alive) throw const ApiFailure('登录已取消');
      if (bound == null) return false;
      response = bound.response;
      verifiedPhone = bound.phone;
      if (response.phoneBindingRequired) {
        throw const ApiFailure('服务器返回的登录信息无效');
      }
    }
    if (response.registrationRequired) {
      if (response.registrationToken.isEmpty ||
          response.registrationExpiresInSeconds <= 0 ||
          response.accessToken.isNotEmpty ||
          response.refreshToken.isNotEmpty ||
          response.hasUser()) {
        throw const ApiFailure('服务器返回的注册信息无效');
      }
      if (confirmRegistration == null) {
        throw const ApiFailure('该账号尚未注册，请确认注册后再登录');
      }
      final confirmed = await confirmRegistration();
      if (version != epoch || !alive) throw const ApiFailure('登录已取消');
      if (!confirmed) return false;
      response = await api.confirmRegistration(
        response.registrationToken,
        legalAgreementVersions,
        headers,
        inviteCode: registrationInviteCode,
      );
      registrationInviteCode = '';
    }
    await _finishSignIn(
      response,
      version,
      nickname: nickname,
      verifiedPhone: verifiedPhone,
    );
    return true;
  }

  Future<void> _finishSignIn(
    auth.LoginResponse response,
    int version, {
    String? nickname,
    String? verifiedPhone,
  }) async {
    if (response.registrationRequired ||
        response.accessToken.isEmpty ||
        response.refreshToken.isEmpty ||
        !response.hasUser() ||
        response.user.id.toInt() <= 0) {
      throw const ApiFailure('服务器返回的登录信息无效');
    }
    if (version != epoch || !alive) throw const ApiFailure('登录已取消');
    final next = {
      'access_token': response.accessToken,
      'refresh_token': response.refreshToken,
      'user_id': response.user.id.toInt(),
      if (verifiedPhone != null)
        'phone_masked':
            '${verifiedPhone.substring(0, 3)}****${verifiedPhone.substring(7)}',
    };
    await persist(next, version);
    if (version != epoch || !alive) return;
    session = next;
    sessionNotice = null;
    ipLocation = '';
    phoneMasked = '${next['phone_masked'] ?? ''}';
    phoneBindingChecked = phoneMasked.isNotEmpty;
    _identityVerified = null;
    _identityCompleted = null;
    ++_identityRevision;
    ++_phoneBindingRevision;
    userID = response.user.id.toInt();
    isGuest = false;
    await restoreContentSubmissions();
    // Profile setup failure must not turn a valid server login into a fake failure.
    if (nickname != null) {
      try {
        await updateProfile(nickname, '');
      } catch (e) {
        errors['profile'] = '登录成功，昵称未保存：$e';
      }
    }
    changed();
    unawaited(loadAll());
    if (foreground) realtime?.start();
  }

  void browseAsGuest() {
    isGuest = true;
    changed();
  }

  Future<void> endSession({
    bool remote = true,
    Map<String, String>? notice,
  }) async {
    final old = session;
    sessionNotice = notice;
    unawaited(realtime?.stop(resetCursor: true));
    _realtimeRefresh?.cancel();
    _realtimeRefresh = null;
    _dirtySections.clear();
    _jobSignals.clear();
    _deliveryTimer?.cancel();
    _deliveryTimer = null;
    _deliveryPending.clear();
    ++epoch;
    session = null;
    _identityVerified = null;
    _identityCompleted = null;
    ++_identityRevision;
    isGuest = false;
    name = '';
    bio = '';
    publicID = '';
    avatarURL = '';
    registeredAt = null;
    ipLocation = '';
    phoneMasked = '';
    phoneBindingChecked = false;
    ++_phoneBindingRevision;
    guidanceReviewDrafts.clear();
    contentSubmissions.clear();
    userID = 0;
    points = null;
    rewardPoints = null;
    rewardClaimed = false;
    rewardStatus = '';
    rewardDay = 0;
    rewardDays = [];
    registrationInviteCode = '';
    publicProfile = true;
    stories.clear();
    resumes.clear();
    resumesLoaded = false;
    inbox.clear();
    notificationUnreadCount = 0;
    friends.clear();
    friendRequests.clear();
    templates.clear();
    errors.clear();
    cursors.clear();
    loading.clear();
    loadingMore.clear();
    sectionRequests.clear();
    pending.clear();
    changed();
    await persist(null, epoch);
    if (remote && old != null) {
      try {
        await api.call(
          'PostAuthLogout',
          body: {},
          headers: {
            ...headers,
            'authorization': 'Bearer ${old['access_token']}',
          },
        );
      } catch (_) {
        /* Local credentials have already been removed. */
      }
    }
  }
}
