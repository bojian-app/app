import 'content_moderation.dart';
import 'app_appearance.dart';
import 'user_display_name.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import 'api/bojian_api.dart';
import 'app_environment.dart';
import 'api/generated/auth.pb.dart' as auth;
import 'legal_document.dart';
import 'wechat_login.dart';
import 'douyin_login.dart';
import 'resume_templates.dart';
import 'resume_theme.dart';
import 'resume_editor_progress.dart';
import 'resume_generated_text.dart';
import 'template_preview_cache.dart';
import 'realtime_client.dart';
import 'device_metadata.dart';

part 'app_store_models.dart';
part 'app_store_auth.dart';
part 'app_store_articles.dart';
part 'app_store_content.dart';
part 'app_store_social.dart';
part 'app_store_resumes.dart';

class AppStore extends ChangeNotifier {
  AppStore({
    ApiGateway? api,
    SessionStorage? storage,
    this.realtimeConnector,
    WeChatAuthorizer? weChatAuthorizer,
    DouyinAuthorizer? douyinAuthorizer,
  }) : api = api ?? BojianApi(),
       storage = storage ?? SecureSessionStorage(),
       weChatAuthorizer = weChatAuthorizer ?? NativeWeChatAuthorizer(),
       douyinAuthorizer = douyinAuthorizer ?? NativeDouyinAuthorizer();
  final WeChatAuthorizer weChatAuthorizer;

  /// Asks whether to abort a pending account deletion by signing in.
  Future<bool> Function(DateTime? executeAfter)? confirmDeletionCancel;
  final DouyinAuthorizer douyinAuthorizer;
  final guidanceReviewDrafts = <String, Set<int>>{};
  final ApiGateway api;
  final SessionStorage storage;
  late final appearance = AppAppearance(storage);
  final RealtimeConnector? realtimeConnector;
  final _realtimeEvents = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get realtimeEvents => _realtimeEvents.stream;
  Future<void> waitForJobUpdate(
    String type,
    int id,
    Future<void> Function(Duration) fallback,
  ) async {
    final jobKey = '$type:$id';
    if (_jobSignals.remove(jobKey)) return;
    if (realtime?.socket == null) {
      await fallback(const Duration(milliseconds: 1500));
      return;
    }
    final version = epoch;
    final ready = Completer<void>();
    void finish() {
      if (!ready.isCompleted) ready.complete();
    }

    void sessionChanged() {
      if (!alive || version != epoch) finish();
    }

    final subscription = realtimeEvents.listen((event) {
      final data = event['data'] is Map ? event['data'] as Map : const {};
      if (event['type'] == 'job.updated' &&
          data['job_type'] == type &&
          integer(data['job_id']) == id) {
        _jobSignals.remove(jobKey);
        finish();
      }
    }, onDone: finish);
    addListener(sessionChanged);
    final timeout = Timer(const Duration(seconds: 10), finish);
    try {
      await ready.future;
    } finally {
      timeout.cancel();
      removeListener(sessionChanged);
      await subscription.cancel();
    }
    if (!alive || version != epoch) throw const ApiFailure('登录状态已变化，请重新登录');
  }

  final _deliveryPending = <int>{};
  Timer? _deliveryTimer;
  bool _delivering = false;

  void _scheduleDelivery({Duration delay = const Duration(milliseconds: 200)}) {
    if (!alive ||
        !foreground ||
        !isAuthenticated ||
        _deliveryPending.isEmpty ||
        _deliveryTimer != null ||
        _delivering) {
      return;
    }
    final version = epoch;
    _deliveryTimer = Timer(delay, () async {
      _deliveryTimer = null;
      _delivering = true;
      final batch = _deliveryPending.take(8).toList();
      var failed = false;
      await Future.wait(
        batch.map((id) async {
          try {
            await request(
              'PostNotificationsIdDelivery',
              path: {'id': '$id'},
              body: {},
            );
            if (version == epoch) _deliveryPending.remove(id);
          } catch (_) {
            failed = true;
            // Keep the receipt for a bounded retry; delivery failure must not
            // block incoming chat or a session invalidation frame.
          }
        }),
      );
      _delivering = false;
      if (alive) {
        _scheduleDelivery(
          delay: failed && version == epoch
              ? const Duration(seconds: 30)
              : const Duration(milliseconds: 200),
        );
      }
    });
  }

  final _jobSignals = <String>{};
  final _dirtySections = <String>{};
  Timer? _realtimeRefresh;
  bool foreground = true;
  Map<String, String>? sessionNotice;
  late final RealtimeClient? realtime =
      api is BojianApi || realtimeConnector != null
      ? RealtimeClient(
          baseURL: api is BojianApi
              ? (api as BojianApi).baseURL
              : Uri.parse(AppEnvironment.apiBaseURL),
          credentials: () async =>
              (await request('PostRealtimeToken', body: {})).data,
          connect:
              realtimeConnector ??
              (Platform.isAndroid && api is BojianApi
                  ? (uri) => HttpRealtimeSocket.connect(
                      (api as BojianApi).client,
                      uri,
                    )
                  : NativeRealtimeSocket.connect),
          onEvent: _receiveRealtime,
          onFailure: (error) {
            final message = error is SocketException
                ? error.osError?.message ?? error.message
                : error is HandshakeException
                ? error.osError?.message ?? 'TLS handshake failed'
                : error is WebSocketException
                ? error.message.split('?').first
                : error.runtimeType.toString();
            debugPrint('Bojian realtime transport: $message');
          },
          onConnected: () {
            if (!alive || !isAuthenticated) return;
            debugPrint('Bojian realtime connected');
            _realtimeEvents.add({'type': 'connection.ready'});
            _scheduleDelivery();
            _scheduleRealtimeRefresh({
              if (errors.containsKey('feed')) 'feed',
              'messages',
              'resumes',
              'profile',
              'templates',
            });
          },
        )
      : null;

  void setForeground(bool value) {
    foreground = value;
    if (!alive) return;
    if (value && isAuthenticated) {
      realtime?.start();
      _scheduleDelivery();
    } else {
      _deliveryTimer?.cancel();
      _deliveryTimer = null;
      unawaited(realtime?.stop());
    }
  }

  Future<void> _receiveRealtime(Map<String, dynamic> event) async {
    if (!alive || !isAuthenticated) return;
    final type = event['type'];
    if (type == 'SESSION_INVALID') {
      await endSession(
        remote: false,
        notice: {
          'title': '${event['title'] ?? '登录已失效'}',
          'message': '${event['message'] ?? '请重新登录。'}',
        },
      );
      return;
    }
    if (type == 'SYSTEM_NOTIFICATION' || type == 'notification.created') {
      final data = event['data'] is Map ? event['data'] as Map : const {};
      final id = integer(data['notification_id']);
      if (id > 0) {
        _deliveryPending.add(id);
        _scheduleDelivery();
      }
    }
    if (type == 'job.updated') {
      final data = event['data'] is Map ? event['data'] as Map : const {};
      if (_jobSignals.length >= 200) _jobSignals.remove(_jobSignals.first);
      _jobSignals.add('${data['job_type']}:${data['job_id']}');
    }
    if (type == 'content.removed') {
      final data = event['data'] is Map ? event['data'] as Map : const {};
      final subject = '${data['subject_type']}';
      final id = integer(data['subject_id']);
      if (subject == 'ARTICLE' || subject == 'POST') {
        stories.removeWhere((story) => story.id == integer(data['article_id']));
      }
      contentSubmissions.removeWhere(
        (row) =>
            integer(row['id']) == id &&
            (subject == 'COMMENT'
                ? row['_method'] == 'PostArticlesIdComments'
                : subject == 'GUIDANCE_ANNOTATION' &&
                      '${row['_method']}'.contains('Annotations')),
      );
      unawaited(saveContentSubmissions().catchError((Object _) {}));
      changed();
    }
    _realtimeEvents.add(event);
    final sections = switch (type) {
      'SYSTEM_NOTIFICATION' ||
      'notification.created' ||
      'notification.read' => {'messages'},
      'friend_request.created' ||
      'friend_request.updated' ||
      'friendship.ended' => {'messages'},
      'job.updated' || 'resume.updated' => {'resumes'},
      'content.removed' ||
      'article.updated' ||
      'article.comment' ||
      'article.reaction' => {'messages'},
      'template.updated' => {'templates'},
      'account.updated' => {'profile'},
      _ => <String>{},
    };
    if (const {
      'article.comment',
      'article.reaction',
      'content.removed',
    }.contains(type)) {
      final data = event['data'] is Map ? event['data'] as Map : const {};
      final id = integer(data['article_id']);
      if (stories.any((story) => story.id == id)) {
        sections.add('article-metrics:$id');
      }
    }
    _scheduleRealtimeRefresh(sections);
  }

  void _scheduleRealtimeRefresh(Set<String> sections) {
    _dirtySections.addAll(sections);
    if (_realtimeRefresh != null || _dirtySections.isEmpty) return;
    final version = epoch;
    _realtimeRefresh = Timer(const Duration(milliseconds: 200), () async {
      _realtimeRefresh = null;
      if (!alive || !foreground || !isAuthenticated || version != epoch) return;
      final dirty = _dirtySections.toList();
      _dirtySections.clear();
      // Wait for an older HTTP request before fetching an event's newer state.
      await Future.wait(
        dirty.map((section) async {
          final previous = sectionRequests[section];
          if (previous != null) await previous;
          if (alive && isAuthenticated && version == epoch) {
            if (section.startsWith('article-metrics:')) {
              await refreshArticleMetrics(int.parse(section.split(':').last));
            } else {
              await load(section);
            }
          }
        }),
      );
    });
  }

  String deviceID = '';
  Map<String, dynamic>? session;
  int epoch = 0;

  /// 创建副本进行中或刚完成的冷却期；跨页面共享，避免跳转到副本页后再次触发。
  bool copyingResume = false;
  bool alive = true;
  bool restoring = true;
  bool isGuest = false;
  bool get isAuthenticated => session != null;
  bool? _identityVerified;
  // 一个账号只能完成一次实名认证，证件过期后也不能重新认证。
  bool? _identityCompleted;
  int _identityRevision = 0;
  bool get identityVerified => _identityVerified == true;
  bool get canApplyDeveloperVerification => _identityCompleted == false;

  // Only called after the server confirms and persists a successful face result.
  void recordIdentityVerificationSuccess({
    required int verificationID,
    required int expectedEpoch,
  }) {
    if (!alive ||
        !isAuthenticated ||
        epoch != expectedEpoch ||
        verificationID <= 0) {
      return;
    }
    ++_identityRevision;
    _identityVerified = true;
    _identityCompleted = true;
    changed();
  }

  String name = '', bio = '', publicID = '', avatarURL = '';
  DateTime? registeredAt;
  String ipLocation = '';
  String phoneMasked = '';
  bool phoneBindingChecked = false;
  bool get hasBoundPhone => phoneMasked.isNotEmpty;
  int _phoneBindingRevision = 0;
  int userID = 0;

  bool publicProfile = true;
  final stories = <Story>[];
  final resumes = <ResumeDraft>[];
  bool resumesLoaded = false;
  final inbox = <InboxItem>[];
  int notificationUnreadCount = 0;
  final friends = <Map<String, dynamic>>[];
  final friendRequests = <Map<String, dynamic>>[];
  final templates = <Map<String, dynamic>>[];
  final loading = <String>{};
  final sectionRequests = <String, Future<void>>{};
  final errors = <String, String>{};
  final cursors = <String, String>{};

  /// Sections fetching a further page, as opposed to a first load or refresh.
  final loadingMore = <String>{};
  final pending = <String>{};
  Future<void>? initialization;
  DeviceMetadata deviceMetadata = const DeviceMetadata();
  Future<void>? refreshing;
  Future<void> storageQueue = Future.value();

  void changed() {
    if (alive) notifyListeners();
  }

  Future<void> persist(Map<String, dynamic>? value, int version) {
    return storageQueue = storageQueue.catchError((_) {}).then((_) async {
      if (epoch == version) {
        await storage.write(
          'bojian.session',
          value == null ? null : jsonEncode(value),
        );
      }
    });
  }

  Future<void> initialize() => initialization ??= _initialize();
  Future<void> _initialize() async {
    final version = epoch;
    deviceMetadata = await DeviceMetadata.read();
    try {
      // 已有安装沿用原设备 ID，避免刷新令牌失效；全新安装在 Android 上
      // 使用重装后不变的标识，同一台手机不会在登录设备里重复出现。
      deviceID =
          await storage.read('bojian.device-id') ??
          (deviceMetadata.stableID.isNotEmpty
              ? 'a-${deviceMetadata.stableID}'
              : newDeviceID());
      await storage.write('bojian.device-id', deviceID);
      final raw = await storage.read('bojian.session');
      if (version != epoch || !alive) return;
      if (raw != null) {
        final stored = jsonDecode(raw) as Map<String, dynamic>;
        if (stored['access_token'] is! String ||
            (stored['access_token'] as String).isEmpty ||
            stored['refresh_token'] is! String ||
            (stored['refresh_token'] as String).isEmpty ||
            integer(stored['user_id']) <= 0) {
          await storage.write('bojian.session', null);
          throw const ApiFailure('登录信息已失效');
        }
        session = stored;
        userID = integer(stored['user_id']);
        phoneMasked = '${stored['phone_masked'] ?? ''}';
        phoneBindingChecked = phoneMasked.isNotEmpty;
      }
    } catch (_) {
      errors['session'] = '无法读取安全登录状态，请重新登录';
    } finally {
      restoring = false;
      changed();
    }
    if (isAuthenticated) {
      await restoreContentSubmissions();
      unawaited(loadAll());
      if (foreground) realtime?.start();
    }
  }

  Map<String, String> get headers => {
    ...deviceMetadata.headers,
    'x-device-id': deviceID,
    'x-platform': Platform.isIOS
        ? 'IOS'
        : Platform.isAndroid
        ? 'ANDROID'
        : Platform.isMacOS
        ? 'MACOS'
        : 'WINDOWS',
    'x-app-version': '1.0.0',
    'accept-language': 'zh-Hans',
  };
  Future<ApiDocument> request(
    String method, {
    Map<String, String> path = const {},
    Map<String, String> query = const {},
    Map<String, dynamic>? body,
    Map<String, String> extra = const {},
    bool authenticated = true,
    int? expectedEpoch,
  }) => _withSession(
    (headers) => api.call(
      method,
      path: path,
      query: query,
      body: body,
      headers: headers,
    ),
    extra: extra,
    authenticated: authenticated,
    expectedEpoch: expectedEpoch,
  );

  Future<ApiDocument> upload(
    String method, {
    Map<String, String> path = const {},
    required Map<String, String> fields,
    required ApiUploadFile file,
    int? expectedEpoch,
  }) => _withSession(
    (headers) => api.upload(
      method,
      path: path,
      fields: fields,
      file: file,
      headers: headers,
    ),
    expectedEpoch: expectedEpoch,
  );

  Future<ApiDocument> _withSession(
    Future<ApiDocument> Function(Map<String, String> headers) call, {
    Map<String, String> extra = const {},
    bool authenticated = true,
    int? expectedEpoch,
  }) async {
    await initialize();
    if (expectedEpoch != null && expectedEpoch != epoch) {
      throw const ApiFailure('账号已切换，请重试');
    }
    if (authenticated && !isAuthenticated) throw const ApiFailure('请先登录');
    final version = epoch;
    Future<ApiDocument> send() => call({
      ...headers,
      if (authenticated) 'authorization': 'Bearer ${session!['access_token']}',
      ...extra,
    });
    try {
      final result = await send();
      if (!alive || version != epoch) throw const ApiFailure('账号已切换，请重试');
      return result;
    } on ApiFailure catch (e) {
      if (!e.unauthenticated || !authenticated || version != epoch) rethrow;
      try {
        await (refreshing ??= _refresh(
          version,
        )).whenComplete(() => refreshing = null);
        if (!alive || version != epoch) throw const ApiFailure('登录已失效，请重新登录');
        final result = await send();
        if (!alive || version != epoch) throw const ApiFailure('账号已切换，请重试');
        return result;
      } on ApiFailure catch (error) {
        if (error.unauthenticated && version == epoch) {
          await endSession(remote: false);
        }
        rethrow;
      }
    }
  }

  Future<void> refreshGuidanceParticipants(Story story) async {
    final version = epoch;
    try {
      final result = await request(
        'GetArticlesId',
        path: {'id': '${story.id}'},
      );
      if (!alive ||
          version != epoch ||
          integer(result.data['id']) != story.id) {
        return;
      }
      final count = decodeGuidanceParticipantCount(
        result.data['guidance_participant_count'],
      );
      if (count == null) return;
      story.guidanceParticipantCount = count;
      for (final cached in stories.where((item) => item.id == story.id)) {
        cached.guidanceParticipantCount = count;
      }
      changed();
    } catch (_) {
      // A failed refresh keeps the last confirmed total, never a fabricated 0.
    }
  }

  Future<void> _refresh(int version) async {
    final token = await api.refresh(
      session!['refresh_token'] as String,
      headers,
    );
    if (version != epoch || !alive) throw const ApiFailure('账号已切换，请重试');
    session = {
      ...session!,
      'access_token': token.accessToken,
      'refresh_token': token.refreshToken,
    };
    await persist(session, version);
  }

  Future<void> loadAll() async => Future.wait(
    [
      'feed',
      'resumes',
      'messages',
      'profile',
      'identity',
      'templates',
    ].map(load),
  );
  Future<void> load(String section, {bool more = false}) {
    final existing = sectionRequests[section];
    if (existing != null) return existing;
    if (more && (cursors[section] ?? '').isEmpty) return Future.value();
    final version = epoch;
    final future = _load(section, more: more);
    sectionRequests[section] = future;
    return future.whenComplete(() {
      if (version == epoch) sectionRequests.remove(section);
    });
  }

  Future<void> _load(String section, {bool more = false}) async {
    if (!isAuthenticated) {
      errors[section] = '登录后即可查看';
      changed();
      return;
    }
    final version = epoch;
    loading.add(section);
    if (more) loadingMore.add(section);
    errors.remove(section);
    changed();
    final query = <String, String>{
      'limit': '30',
      if (more && (cursors[section] ?? '').isNotEmpty)
        'cursor': cursors[section]!,
    };
    try {
      switch (section) {
        case 'feed':
          final v = await request('GetFeed', query: query);
          if (version != epoch || !alive) return;
          if (!more) stories.clear();
          stories.addAll(items(v.data).map(decodeStory));
          cursors[section] = v.nextCursor;
        case 'resumes':
          final v = await request('GetResumes', query: query);
          if (version != epoch || !alive) return;
          if (!more) resumes.clear();
          resumes.addAll(items(v.data).map(decodeResume));
          resumesLoaded = true;
          cursors[section] = v.nextCursor;
        case 'messages':
          final v = await request('GetNotifications', query: query);
          if (version != epoch || !alive) return;
          if (!more) inbox.clear();
          for (final row in items(v.data)) {
            final payload = row['payload'] as Map? ?? {};
            final type = row['type']?.toString() ?? '';
            final title = payload['title']?.toString().trim() ?? '';
            final body = payload['body']?.toString().trim() ?? '';
            final item = InboxItem(
              title.isNotEmpty
                  ? title
                  : switch (type) {
                      'RESUME_GUIDANCE' => '简历修改邀请',
                      'RESUME_GUIDANCE_FEEDBACK' => '简历优化建议',
                      'FRIEND_REQUEST' => '好友申请通知',
                      'ARTICLE_LIKE' => '收到新的赞',
                      'ARTICLE_APPROVED' => '文章审核通过',
                      'ARTICLE_REJECTED' => '文章审核未通过',
                      'ARTICLE_COMMENT' => '收到新的评论',
                      'REPORT_RESOLVED' => '举报已成立',
                      'REPORT_DISMISSED' => '举报未成立',
                      'REPORT_CONTENT_REMOVED' => '内容已被撤回',
                      'COMMENT_REPLY' => '收到新的回复',
                      _ => '系统通知',
                    },
              body,
              row['created_at']?.toString() ?? '',
              0,
              id: integer(row['id']),
              type: type,
              subjectID: integer(row['subject_id']),
              actorID: integer(row['actor_id']),
              actorName: userDisplayName(
                (row['actor'] as Map?)?['display_name'],
              ),
              actorAvatarURL: '${(row['actor'] as Map?)?['avatar_url'] ?? ''}',
              feedbackType: '${payload['feedback_type'] ?? ''}',
              annotationID: integer(payload['annotation_id']),
              reviewReason: '${payload['review_reason'] ?? ''}',
              subjectType: '${row['subject_type'] ?? ''}',
              read: row['read_at'] != null,
            );
            final existing = inbox.indexWhere((value) => value.id == item.id);
            if (existing >= 0) {
              inbox[existing] = item;
            } else {
              inbox.add(item);
            }
          }
          notificationUnreadCount = v.data['unread_count'] == null
              ? inbox.where((item) => !item.read).length
              : integer(v.data['unread_count']);
          cursors[section] = v.nextCursor;
        case 'identity':
          final revision = _identityRevision;
          final result = await request('GetMeIdentityVerification');
          if (version != epoch || !alive || revision != _identityRevision) {
            return;
          }
          final status = result.data['status'];
          if (!const {
            'NOT_VERIFIED',
            'PENDING',
            'REJECTED',
            'EXPIRED',
            'VERIFIED',
          }.contains(status)) {
            throw const ApiFailure('认证状态暂不可用，请稍后重试');
          }
          final validUntil = result.data['valid_until'];
          if (status == 'VERIFIED' &&
              (validUntil is! String ||
                  DateTime.tryParse(validUntil) == null)) {
            throw const ApiFailure('认证有效期无效，请稍后重试');
          }
          final today = DateTime.now()
              .toUtc()
              .add(const Duration(hours: 8))
              .toIso8601String()
              .substring(0, 10);
          _identityCompleted = status == 'VERIFIED' || status == 'EXPIRED';
          _identityVerified =
              status == 'VERIFIED' &&
              (validUntil as String).compareTo(today) >= 0;
        case 'profile':
          final phoneRevision = _phoneBindingRevision;
          final v = await request('GetMe');
          if (version != epoch || !alive) return;
          name = v.data['nickname'] as String? ?? '';
          bio = v.data['bio'] as String? ?? '';
          publicID = v.data['public_id'] as String? ?? '';
          avatarURL = v.data['avatar_url'] as String? ?? '';
          registeredAt = DateTime.tryParse('${v.data['created_at'] ?? ''}');
          ipLocation = '${v.data['city'] ?? ''}'.trim();
          publicProfile = v.data['profile_visibility'] == 'PUBLIC';
          if (phoneRevision == _phoneBindingRevision) {
            phoneMasked = '${v.data['phone_masked'] ?? ''}'.trim();
            phoneBindingChecked = true;
          }
          changed();
        case 'templates':
          final v = await request('GetTemplates', query: query);
          if (version != epoch || !alive) return;
          if (!more) templates.clear();
          templates.addAll(items(v.data));
          cursors[section] = v.nextCursor;
      }
    } catch (e) {
      if (version == epoch && alive) errors[section] = '$e';
    } finally {
      if (version == epoch) {
        loading.remove(section);
        loadingMore.remove(section);
        changed();
      }
    }
  }

  final contentSubmissions = <Map<String, dynamic>>[];
  Future<void> contentWrites = Future.value();
  @override
  void dispose() {
    alive = false;
    appearance.dispose();
    ++epoch;
    _realtimeRefresh?.cancel();
    _deliveryTimer?.cancel();
    unawaited(realtime?.stop(resetCursor: true));
    unawaited(_realtimeEvents.close());
    unawaited(api.close());
    super.dispose();
  }
}
