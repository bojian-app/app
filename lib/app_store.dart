import 'content_moderation.dart';
import 'user_display_name.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import 'api/bojian_api.dart';
import 'api/generated/auth.pb.dart' as auth;
import 'legal_document.dart';
import 'wechat_login.dart';
import 'douyin_login.dart';
import 'resume_templates.dart';
import 'realtime_client.dart';
import 'device_metadata.dart';

class ArticleComment {
  const ArticleComment({
    required this.id,
    required this.authorID,
    required this.author,
    required this.content,
    this.avatarURL = '',
    this.createdAt,
    this.deleted = false,
    this.likes = 0,
    this.dislikes = 0,
    this.liked = false,
    this.disliked = false,
    this.replyCount = 0,
    this.parentID,
    this.replyToName = '',
    this.status = 'VISIBLE',
    this.reviewReason = '',
    this.replyToID,
    this.local,
  });
  final int id, authorID;
  final String author, content, avatarURL;
  final DateTime? createdAt;
  final bool deleted;
  final int likes, dislikes, replyCount;
  final bool liked, disliked;
  final int? parentID;
  final String replyToName;
  final String status, reviewReason;
  final int? replyToID;
  final Map<String, dynamic>? local;
  bool get visible => status == 'VISIBLE';
  ArticleComment withReaction(Map<String, dynamic> row) => ArticleComment(
    id: id,
    authorID: authorID,
    author: author,
    content: content,
    avatarURL: avatarURL,
    createdAt: createdAt,
    deleted: deleted,
    parentID: parentID,
    replyToName: replyToName,
    status: status,
    reviewReason: reviewReason,
    replyToID: replyToID,
    local: local,
    replyCount: replyCount,
    likes: integer(row["like_count"]),
    dislikes: integer(row["dislike_count"]),
    liked: row["is_liked"] == true,
    disliked: row["is_disliked"] == true,
  );

  factory ArticleComment.fromJson(Map<String, dynamic> row) {
    final author = row['author'] as Map? ?? {};
    return ArticleComment(
      id: integer(row['id']),
      status: '${row['moderation_status'] ?? row['status'] ?? 'VISIBLE'}',
      reviewReason: '${row['review_reason'] ?? ''}',
      replyToID: row['reply_to_id'] == null
          ? null
          : integer(row['reply_to_id']),
      local: row.containsKey('_method') ? row : null,
      authorID: integer(author['id']),
      author: userDisplayName(author['display_name']),
      content: '${row['content'] ?? ''}',
      avatarURL: '${author['avatar_url'] ?? ''}',
      createdAt: DateTime.tryParse('${row['created_at']}'),
      deleted: row['is_deleted'] == true,
      likes: integer(row['like_count']),
      dislikes: integer(row['dislike_count']),
      liked: row['is_liked'] == true,
      disliked: row['is_disliked'] == true,
      replyCount: integer(row['reply_count']),
      parentID: row['parent_id'] == null ? null : integer(row['parent_id']),
      replyToName: row['reply_to'] is Map
          ? userDisplayName((row['reply_to'] as Map)['display_name'])
          : '',
    );
  }
}

class Story {
  Story({
    required this.id,
    required this.title,
    required this.author,
    required this.role,
    required this.category,
    required this.excerpt,
    required this.paragraphs,
    this.likes = 0,
    this.content = const {},
    this.comments = const [],
    this.commentCount = 0,
    this.cover = 0,
    this.liked = false,
    this.saved = false,
    this.authorID = 0,
    this.authorAvatarURL = '',
    this.publishedAt = '',
    this.hasGuidance = false,
    this.guidanceParticipantCount,
  });
  final int id;
  final String title, role, category, excerpt;
  String author;
  final List<String> paragraphs;
  final Map<String, dynamic> content;
  final int cover;
  final int authorID;
  final String authorAvatarURL;
  final String publishedAt;
  final bool hasGuidance;
  int likes;
  bool liked, saved;
  List<ArticleComment> comments;
  int commentCount;
  int? guidanceParticipantCount;
}

class ResumeDraft {
  ResumeDraft({
    required this.id,
    required this.title,
    this.name = '',
    this.position = '',
    this.city = '',
    this.phone = '',
    this.email = '',
    this.summary = '',
    this.experience = '',
    this.education = '',
    this.skills = '',
    this.template = '',
    this.progress = 0,
    this.revision = 0,
    this.source = const {},
    this.importID,
    this.photoURL = '',
    this.photoFileID = 0,
    this.updatedAt,
    this.marketTemplateID = 0,
  });
  final int id;
  final int marketTemplateID;
  bool get usesMarketTemplate => marketTemplateID > 0;
  String get templateTitle => usesMarketTemplate
      ? source['app_template_name'] as String? ?? '已购买模板'
      : ResumeLayout.standard.title;
  final DateTime? updatedAt;
  String photoURL;
  int photoFileID;
  final int? importID;
  int revision;
  Map<String, dynamic> source;
  String title,
      name,
      position,
      city,
      phone,
      email,
      summary,
      experience,
      education,
      skills,
      template;
  double progress;
  ResumeDraft copy() => ResumeDraft(
    id: id,
    revision: revision,
    source: jsonDecode(jsonEncode(source)) as Map<String, dynamic>,
    importID: importID,
    photoURL: photoURL,
    photoFileID: photoFileID,
    updatedAt: updatedAt,
    marketTemplateID: marketTemplateID,
    title: title,
    name: name,
    position: position,
    city: city,
    phone: phone,
    email: email,
    summary: summary,
    experience: experience,
    education: education,
    skills: skills,
    template: template,
    progress: progress,
  );
}

class InboxItem {
  InboxItem(
    this.title,
    this.body,
    this.time,
    this.kind, {
    this.read = false,
    this.id = 0,
    this.type = '',
    this.subjectID = 0,
    this.subjectType = '',
    this.actorID = 0,
    this.actorName = '',
    this.actorAvatarURL = '',
    this.feedbackType = '',
    this.annotationID = 0,
    this.reviewReason = '',
  });
  final String type;
  final int subjectID, actorID, annotationID;
  final String subjectType;
  final String actorName, actorAvatarURL, feedbackType;
  final String reviewReason;
  final String title, body, time;
  final int kind, id;
  bool read;
}

int integer(dynamic value) =>
    value is int ? value : int.tryParse('$value') ?? 0;
List<Map<String, dynamic>> items(Map<String, dynamic> data) =>
    (data['items'] as List? ?? []).cast<Map<String, dynamic>>();
String plainContent(dynamic content) {
  if (content is String) return content;
  if (content is! Map) return '';
  return (content['blocks'] as List? ?? [])
      .map((block) {
        if (block is! Map) return '';
        return (block['spans'] as List? ?? [])
            .map((span) => span['text'] ?? '')
            .join();
      })
      .join('\n');
}

Map<String, dynamic> richContent(String text) => {
  'blocks': text
      .split('\n')
      .map(
        (line) => {
          'kind': 'paragraph',
          'spans': [
            {'text': line},
          ],
        },
      )
      .toList(),
};

int? decodeGuidanceParticipantCount(dynamic value) {
  final count = int.tryParse('$value');
  return count == null || count < 0 ? null : count;
}

Story decodeStory(Map<String, dynamic> v) {
  final author = v['author'] as Map? ?? {};
  final content = v['content'];
  final guidance =
      v['resume_id'] != null ||
      (content is Map && content['kind'] == 'RESUME_GUIDANCE');
  final body = plainContent(v['content']);
  return Story(
    id: integer(v['id']),
    title: v['title'] as String? ?? '',
    author: userDisplayName(author['display_name']),
    authorID: integer(author['id'] ?? v['author_id']),
    authorAvatarURL: author['avatar_url']?.toString() ?? '',
    role: author['city'] as String? ?? '',
    category: guidance ? '简历求指点' : '经验分享',
    hasGuidance: guidance,
    guidanceParticipantCount: decodeGuidanceParticipantCount(
      v['guidance_participant_count'],
    ),
    excerpt: body,
    paragraphs: body.split('\n'),
    content: content is Map
        ? Map<String, dynamic>.from(content)
        : richContent(body),
    likes: integer(v['like_count']),
    commentCount: integer(v['comment_count']),
    liked: v['is_liked'] == true,
    saved: v['is_favorited'] == true,
    publishedAt: v['published_at'] as String? ?? '',
  );
}

String entriesText(dynamic entries, String detail) => (entries as List? ?? [])
    .map(
      (v) => [
        v['company'] ?? v['institution'] ?? v['name'] ?? '',
        v['position'] ?? v['degree'] ?? '',
        v[detail] ?? '',
      ].where((s) => '$s'.isNotEmpty).join('\n'),
    )
    .join('\n\n');
ResumeDraft decodeResume(Map<String, dynamic> v) {
  final content = (v['content'] as Map<String, dynamic>?) ?? {};
  final personal = content['personal_info'] as Map? ?? {};
  final job = content['job_expectation'] as Map? ?? {};
  final draft = ResumeDraft(
    id: integer(v['id']),
    revision: integer(v['revision']),
    photoURL: v['photo_url'] is String ? v['photo_url'] as String : '',
    photoFileID: integer(v['photo_file_id']),
    updatedAt: DateTime.tryParse(v['updated_at']?.toString() ?? ''),
    source: content,
    template: ResumeLayout.resolve(content['app_layout']).id,
    marketTemplateID:
        content['app_layout'] == 'standard' ||
            content['app_layout'] == 'business_blue' ||
            content['app_layout'] == 'compact'
        ? 0
        : integer(v['template_id']),
    title: v['title'] as String? ?? '',
    name: personal['full_name'] as String? ?? '',
    phone: personal['phone'] as String? ?? '',
    email: personal['email'] as String? ?? '',
    position: job['position'] as String? ?? '',
    city: job['city'] as String? ?? '',
    summary: job['preference'] as String? ?? '',
    experience: entriesText(content['work_experiences'], 'description'),
    education: entriesText(content['educations'], 'campus_experience'),
    skills: entriesText(content['skills'], 'description'),
  );
  draft.progress =
      [
        draft.name,
        draft.position,
        draft.phone,
        draft.email,
        draft.summary,
        draft.experience,
        draft.education,
        draft.skills,
      ].where((v) => v.trim().isNotEmpty).length /
      8;
  return draft;
}

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
  final DouyinAuthorizer douyinAuthorizer;
  final guidanceReviewDrafts = <String, Set<int>>{};
  final ApiGateway api;
  final SessionStorage storage;
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
              : Uri.parse('https://bojian.kelance.cn/api/v1'),
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
              'chats',
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
      'message.created' || 'message.read' => {'chats'},
      'SYSTEM_NOTIFICATION' ||
      'notification.created' ||
      'notification.read' => {'messages'},
      'friend_request.created' ||
      'friend_request.updated' ||
      'friendship.ended' => {'messages', 'chats'},
      'job.updated' || 'resume.updated' => {'resumes'},
      'content.removed' ||
      'article.updated' ||
      'article.comment' ||
      'article.reaction' => {'messages'},
      'wallet.updated' ||
      'recharge_orders.updated' ||
      'withdrawals.updated' => {'profile', 'templates'},
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
  bool alive = true;
  bool restoring = true;
  bool isGuest = false;
  bool get isAuthenticated => session != null;
  bool? _identityVerified;
  int _identityRevision = 0;
  bool get identityVerified => _identityVerified == true;
  bool get canApplyDeveloperVerification => _identityVerified == false;

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
  int? points;
  int? rewardPoints;
  bool rewardClaimed = false;
  bool publicProfile = true;
  final stories = <Story>[];
  final resumes = <ResumeDraft>[];
  bool resumesLoaded = false;
  final inbox = <InboxItem>[];
  final conversations = <Map<String, dynamic>>[];
  int notificationUnreadCount = 0;
  final friends = <Map<String, dynamic>>[];
  final friendRequests = <Map<String, dynamic>>[];
  final templates = <Map<String, dynamic>>[];
  final loading = <String>{};
  final sectionRequests = <String, Future<void>>{};
  final errors = <String, String>{};
  final cursors = <String, String>{};
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
      deviceID = await storage.read('bojian.device-id') ?? newDeviceID();
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
  }) async {
    await initialize();
    if (expectedEpoch != null && expectedEpoch != epoch) {
      throw const ApiFailure('账号已切换，请重试');
    }
    if (authenticated && !isAuthenticated) throw const ApiFailure('请先登录');
    final version = epoch;
    Future<ApiDocument> send() => api.call(
      method,
      path: path,
      query: query,
      body: body,
      headers: {
        ...headers,
        if (authenticated)
          'authorization': 'Bearer ${session!['access_token']}',
        ...extra,
      },
    );
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

  Future<bool> signIn(
    String phone,
    String code, {
    String? nickname,
    Future<bool> Function()? confirmRegistration,
  }) async {
    await initialize();
    final version = epoch;
    final response = await api.login(phone, code, headers);
    return _resolveSignIn(
      response,
      version,
      nickname: nickname,
      confirmRegistration: confirmRegistration,
    );
  }

  Future<bool> signInWithWeChat({
    Future<bool> Function()? confirmRegistration,
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
    );
  }

  Future<bool> signInWithDouyin({
    Future<bool> Function()? confirmRegistration,
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
      changed();
    });
  }

  Future<bool> _resolveSignIn(
    auth.LoginResponse response,
    int version, {
    String? nickname,
    Future<bool> Function()? confirmRegistration,
  }) async {
    if (version != epoch || !alive) throw const ApiFailure('登录已取消');
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
      );
    }
    await _finishSignIn(response, version, nickname: nickname);
    return true;
  }

  Future<void> _finishSignIn(
    auth.LoginResponse response,
    int version, {
    String? nickname,
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
    };
    await persist(next, version);
    if (version != epoch || !alive) return;
    session = next;
    sessionNotice = null;
    ipLocation = '';
    phoneMasked = '';
    phoneBindingChecked = false;
    _identityVerified = null;
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
    publicProfile = true;
    stories.clear();
    resumes.clear();
    resumesLoaded = false;
    inbox.clear();
    conversations.clear();
    notificationUnreadCount = 0;
    friends.clear();
    friendRequests.clear();
    templates.clear();
    errors.clear();
    cursors.clear();
    loading.clear();
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

  Future<void> loadAll() async => Future.wait(
    [
      'feed',
      'resumes',
      'messages',
      'chats',
      'profile',
      'identity',
      'templates',
    ].map(load),
  );
  Future<void> load(String section, {bool more = false}) {
    final existing = sectionRequests[section];
    if (existing != null) return existing;
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
        case 'chats':
          final v = await request('GetConversations', query: query);
          if (version != epoch || !alive) return;
          if (!more) conversations.clear();
          for (final row in items(v.data)) {
            final existing = conversations.indexWhere(
              (value) => integer(value['id']) == integer(row['id']),
            );
            if (existing >= 0) {
              conversations[existing] = row;
            } else {
              conversations.add(row);
            }
          }
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
          final w = await request('GetWallet');
          if (w.data['available_points'] == null) {
            throw const ApiFailure('积分数据暂不可用，请稍后重试');
          }
          points = integer(w.data['available_points']);
          final reward = await request('GetWalletDailyReward');
          rewardPoints = integer(reward.data['points']);
          rewardClaimed = reward.data['claimable'] != true;
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
        changed();
      }
    }
  }

  int get unread =>
      notificationUnreadCount +
      conversations.fold<int>(
        0,
        (count, row) => count + integer(row['unread_count']),
      );
  Future<T?> perform<T>(String key, Future<T> Function() action) async {
    if (pending.contains(key)) return null;
    pending.add(key);
    changed();
    final version = epoch;
    try {
      return await action();
    } finally {
      if (version == epoch) {
        pending.remove(key);
        changed();
      }
    }
  }

  void _syncReaction(Story story, {required bool like}) {
    for (final entry in stories) {
      if (entry.id == story.id) {
        if (like) {
          entry.liked = story.liked;
          entry.likes = story.likes;
        } else {
          entry.saved = story.saved;
        }
      }
    }
    changed();
  }

  Future<void> like(Story story) async => perform('like-${story.id}', () async {
    final version = epoch;
    final previous = story.liked;
    final previousCount = story.likes;
    final desired = !previous;
    story.liked = desired;
    story.likes = (previousCount + (desired ? 1 : -1)).clamp(0, 1 << 31);
    _syncReaction(story, like: true);
    try {
      final v = await request(
        desired ? 'PutArticlesIdLike' : 'DeleteArticlesIdLike',
        path: {'id': '${story.id}'},
        body: {},
      );
      if (!alive || version != epoch) return;
      story.liked = (v.data['is_liked'] ?? v.data['active'] ?? desired) == true;
      story.likes = v.data.containsKey('like_count')
          ? integer(v.data['like_count'])
          : (previousCount +
                    (story.liked == previous
                        ? 0
                        : story.liked
                        ? 1
                        : -1))
                .clamp(0, 1 << 31);
      _syncReaction(story, like: true);
    } catch (_) {
      if (alive && version == epoch) {
        story.liked = previous;
        story.likes = previousCount;
        _syncReaction(story, like: true);
      }
      rethrow;
    }
  });
  Future<void> bookmark(Story story) async =>
      perform('bookmark-${story.id}', () async {
        final version = epoch;
        final previous = story.saved;
        final desired = !previous;
        story.saved = desired;
        _syncReaction(story, like: false);
        try {
          final v = await request(
            desired ? 'PutArticlesIdFavorite' : 'DeleteArticlesIdFavorite',
            path: {'id': '${story.id}'},
            body: {},
          );
          if (!alive || version != epoch) return;
          story.saved =
              (v.data['is_favorited'] ?? v.data['active'] ?? desired) == true;
          _syncReaction(story, like: false);
        } catch (_) {
          if (alive && version == epoch) {
            story.saved = previous;
            _syncReaction(story, like: false);
          }
          rethrow;
        }
      });
  Future<void> refreshArticleMetrics(int id) async {
    final version = epoch;
    try {
      final response = await request('GetArticlesId', path: {'id': '$id'});
      if (!alive || version != epoch) return;
      for (final story in stories.where((story) => story.id == id)) {
        if (response.data.containsKey('comment_count')) {
          story.commentCount = integer(response.data['comment_count']);
        }
        if (!pending.contains('like-$id')) {
          if (response.data.containsKey('like_count')) {
            story.likes = integer(response.data['like_count']);
          }
          if (response.data.containsKey('is_liked')) {
            story.liked = response.data['is_liked'] == true;
          }
        }
      }
      changed();
    } catch (_) {
      // Keep the existing counts on temporary failures; pull-to-refresh retries.
    }
  }

  Future<void> article(Story story) async {
    final version = epoch;
    final v = await request(
      'GetArticlesIdComments',
      path: {'id': '${story.id}'},
      query: {'limit': '50'},
    );
    if (!alive || version != epoch) return;
    mergeContent('PostArticlesIdComments', story.id, items(v.data));
    story.comments = items(v.data).map(ArticleComment.fromJson).toList();
    story.commentCount = v.data.containsKey('total')
        ? integer(v.data['total'])
        : story.comments.fold<int>(
            0,
            (sum, c) => sum + (c.deleted ? 0 : 1) + c.replyCount,
          );
    for (final entry in stories) {
      if (entry.id == story.id) entry.commentCount = story.commentCount;
    }
    changed();
  }

  Future<ArticleComment?> reactToComment(
    Story story,
    ArticleComment comment, {
    required bool dislike,
  }) => perform("comment-reaction-${story.id}-${comment.id}", () async {
    final remove = dislike ? comment.disliked : comment.liked;
    final result = await request(
      "${remove ? 'Delete' : 'Put'}ArticlesIdCommentsCommentID${dislike ? 'Dislike' : 'Like'}",
      path: {"id": "${story.id}", "commentID": "${comment.id}"},
      body: {},
    );
    final updated = comment.withReaction(result.data);
    story.comments = story.comments
        .map((c) => c.id == updated.id ? updated : c)
        .toList();
    changed();
    return updated;
  });

  final contentSubmissions = <Map<String, dynamic>>[];
  Future<void> contentWrites = Future.value();
  Future<void> saveContentSubmissions() {
    final uid = userID;
    final value = jsonEncode(contentSubmissions);
    return contentWrites = contentWrites
        .catchError((_) {})
        .then((_) => storage.write('bojian.content-outbox.$uid', value));
  }

  Future<void> restoreContentSubmissions() async {
    final version = epoch;
    try {
      final raw = await storage.read('bojian.content-outbox.$userID');
      if (version != epoch || !alive || raw == null) return;
      contentSubmissions.clear();
      for (final row in (jsonDecode(raw) as List).whereType<Map>()) {
        final item = Map<String, dynamic>.from(row);
        if (item['moderation_status'] == 'SENDING') {
          item['moderation_status'] = 'FAILED';
        }
        contentSubmissions.add(item);
      }
      changed();
    } catch (_) {
      /* Server-accepted submissions are also loaded from lists. */
    }
  }

  Map<String, dynamic> enqueueContent(
    String method,
    int id,
    Map<String, dynamic> body, {
    Map<String, dynamic> display = const {},
  }) {
    final now = DateTime.now();
    final row = <String, dynamic>{
      ...body,
      ...display,
      'id': -now.microsecondsSinceEpoch,
      'created_at': now.toUtc().toIso8601String(),
      'reviewer_id': userID,
      'reviewer_name': name,
      'reviewer_avatar_url': avatarURL,
      'author': {'id': userID, 'display_name': name, 'avatar_url': avatarURL},
      '_method': method,
      '_scope_id': id,
      '_body': body,
      'request_key': newDeviceID(),
      'moderation_status': 'SENDING',
      'status': 'PENDING',
    };
    contentSubmissions.add(row);
    changed();
    unawaited(sendContent(row));
    return row;
  }

  Future<void> sendContent(Map<String, dynamic> row) async {
    final version = epoch;
    row['moderation_status'] = 'SENDING';
    changed();
    try {
      await saveContentSubmissions();
      if (version != epoch || !alive) return;
      final response = await request(
        '${row['_method']}',
        path: {'id': '${row['_scope_id']}'},
        body: Map<String, dynamic>.from(row['_body'] as Map),
        extra: {'idempotency-key': '${row['request_key']}'},
        expectedEpoch: version,
      );
      if (version != epoch || !alive) return;
      row['id'] = response.data['id'] ?? row['id'];
      row['moderation_status'] = response.data['status'] ?? 'QUEUED';
      row['moderation'] = response.data['moderation'];
      row['review_reason'] = response.data['review_reason'];
    } catch (e) {
      if (version != epoch || !alive) return;
      row['moderation_status'] = 'FAILED';
      row['review_reason'] = '$e';
    }
    if (version != epoch || !alive) return;
    unawaited(saveContentSubmissions().catchError((Object _) {}));
    changed();
  }

  List<Map<String, dynamic>> mergeContent(
    String method,
    int id,
    List<Map<String, dynamic>> remote,
  ) {
    final local = contentSubmissions
        .where((v) => v['_method'] == method && v['_scope_id'] == id)
        .toList();
    final acknowledged = local
        .where(
          (v) => remote.any(
            (r) =>
                (integer(v['id']) > 0 && r['id'] == v['id']) ||
                (r['request_key'] != null &&
                    r['request_key'] == v['request_key']),
          ),
        )
        .toList();
    if (acknowledged.isNotEmpty) {
      contentSubmissions.removeWhere(acknowledged.contains);
      unawaited(saveContentSubmissions().catchError((Object _) {}));
    }
    return [
      ...local.where((v) => !acknowledged.contains(v)).toList().reversed,
      ...remote,
    ];
  }

  List<Map<String, dynamic>> localContent(String method, int id) =>
      contentSubmissions
          .where((v) => v['_method'] == method && v['_scope_id'] == id)
          .toList();
  Future<SubmissionStatus?> comment(
    Story story,
    String text, {
    int? replyToID,
  }) async {
    enqueueContent('PostArticlesIdComments', story.id, {
      'content': text,
      'reply_to_id': ?replyToID,
    });
    return SubmissionStatus.queued;
  }

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

  Future<void> readConversation(int id, int messageID) async {
    final version = epoch;
    await request(
      'PostConversationsIdRead',
      path: {'id': '$id'},
      body: {'message_id': messageID},
    );
    if (!alive || version != epoch) return;
    for (final row in conversations) {
      if (integer(row['id']) == id &&
          integer(row['last_message_id']) <= messageID) {
        row['unread_count'] = 0;
      }
    }
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
  ResumeDraft createResume({String template = '', String? importedText}) =>
      ResumeDraft(
        id: 0,
        title: importedText == null ? '新的简历' : '导入的简历',
        name: name,
        summary: importedText ?? '',
        template: template,
      );
  Future<ResumeDraft> updateResume(ResumeDraft draft) async {
    late ResumeDraft result;
    final content =
        jsonDecode(jsonEncode(draft.source)) as Map<String, dynamic>;
    final old = decodeResume({'id': draft.id, 'content': draft.source});
    content['personal_info'] = {
      ...?content['personal_info'] as Map<String, dynamic>?,
      'full_name': draft.name,
      'phone': draft.phone.replaceAll(' ', ''),
      'email': draft.email,
    };
    content['job_expectation'] = {
      ...?content['job_expectation'] as Map<String, dynamic>?,
      'position': draft.position,
      'city': draft.city,
      'preference': draft.summary,
    };
    if (draft.summary != old.summary) {
      (content['job_expectation'] as Map)['preference_rich'] = null;
    }
    for (final entry in [
      (
        key: 'work_experiences',
        value: draft.experience,
        old: old.experience,
        detail: 'description',
      ),
      (
        key: 'educations',
        value: draft.education,
        old: old.education,
        detail: 'campus_experience',
      ),
      (
        key: 'skills',
        value: draft.skills,
        old: old.skills,
        detail: 'description',
      ),
    ]) {
      if (entry.value != entry.old) {
        if ((content[entry.key] as List? ?? []).length > 1) {
          throw const ApiFailure('该简历含多条结构化经历，请使用桌面端编辑此段；原内容已保留');
        }
        final list = content[entry.key] as List? ?? [];
        content[entry.key] = entry.value.trim().isEmpty
            ? []
            : [
                {
                  if (list.isNotEmpty) ...list.first as Map<String, dynamic>,
                  entry.detail: entry.value,
                  '${entry.detail}_rich': null,
                },
              ];
      }
    }
    if (draft.id > 0 && draft.revision <= 0) {
      throw const ApiFailure('简历版本缺失，请刷新后重试');
    }
    if (draft.id == 0 && draft.importID != null) {
      final confirmed = await request(
        'PostResumeImportsIdConfirm',
        path: {'id': '${draft.importID}'},
        body: {'content': content},
      );
      final id = integer(confirmed.data['resume_id']);
      if (id <= 0) throw const ApiFailure('导入确认结果无效，请重试');
      final saved = await request('GetResumesId', path: {'id': '$id'});
      final revision = integer(saved.data['revision']);
      if (revision <= 0) throw const ApiFailure('简历版本缺失，请刷新后重试');
      final response = await request(
        'PatchResumesId',
        path: {'id': '$id'},
        body: {'title': draft.title, 'content': content},
        extra: {'if-match': '"revision-$revision"'},
      );
      result = decodeResume(response.data);
    } else {
      final response = await request(
        draft.id == 0 ? 'PostResumes' : 'PatchResumesId',
        path: draft.id == 0 ? {} : {'id': '${draft.id}'},
        body: {
          'title': draft.title,
          'content': content,
          if (draft.id == 0 && draft.marketTemplateID > 0)
            'template_id': draft.marketTemplateID,
        },
        extra: draft.id == 0
            ? {}
            : {'if-match': '"revision-${draft.revision}"'},
      );
      result = decodeResume(response.data);
    }
    await load('resumes');
    return result;
  }

  Future<void> deleteResume(int id) async {
    final version = epoch;
    await request('DeleteResumesId', path: {'id': '$id'});
    if (!alive || epoch != version) return;
    resumes.removeWhere((resume) => resume.id == id);
    changed();
  }

  Future<void> renameResume(int id, String title) async {
    final name = title.trim();
    if (name.isEmpty || name.runes.length > 160) {
      throw const ApiFailure('请输入 1–160 个字的简历名称');
    }
    final version = epoch;
    final detail = await request('GetResumesId', path: {'id': '$id'});
    if (!alive || epoch != version) throw const ApiFailure('账号已切换，请重试');
    final revision = integer(detail.data['revision']);
    if (revision <= 0) throw const ApiFailure('简历版本缺失，请刷新后重试');
    final response = await request(
      'PatchResumesId',
      path: {'id': '$id'},
      body: {'title': name},
      extra: {'if-match': '"revision-$revision"'},
    );
    if (!alive || epoch != version) return;
    final index = resumes.indexWhere((draft) => draft.id == id);
    if (index >= 0) resumes[index] = decodeResume(response.data);
    changed();
  }

  Future<void> changeResumeLayout(int id, ResumeLayout layout) async {
    final version = epoch;
    final detail = await request('GetResumesId', path: {'id': '$id'});
    if (!alive || epoch != version) throw const ApiFailure('账号已切换，请重试');
    final revision = integer(detail.data['revision']);
    if (revision <= 0) throw const ApiFailure('简历版本缺失，请刷新后重试');
    final content = jsonDecode(
      jsonEncode(detail.data['content'] ?? {}),
    ) as Map<String, dynamic>;
    content['app_layout'] = layout.id;
    content.remove('app_template_name');
    final response = await request(
      'PatchResumesId',
      path: {'id': '$id'},
      body: {'content': content},
      extra: {'if-match': '"revision-$revision"'},
    );
    if (!alive || epoch != version) return;
    final updated = decodeResume(response.data);
    final index = resumes.indexWhere((draft) => draft.id == id);
    if (index >= 0) resumes[index] = updated;
    changed();
    await load('resumes');
  }

  /// Only acquired marketplace templates are offered; authored drafts are excluded.
  Future<List<Map<String, dynamic>>> purchasedResumeTemplates() async {
    final result = await request('GetMeTemplates');
    final seen = <int>{};
    return items(result.data)
        .where(
          (row) =>
              row['source'] == 'ACQUIRED' &&
              integer(row['id']) > 0 &&
              seen.add(integer(row['id'])),
        )
        .toList();
  }

  Future<void> changeResumeMarketTemplate(int id, int templateID) async {
    final version = epoch;
    final owned = await purchasedResumeTemplates();
    final matching = owned.where((row) => integer(row['id']) == templateID);
    if (matching.isEmpty) throw const ApiFailure('该模板未购买或已不可用，请刷新后重试');
    final design = matching.first;
    final dom = await request('GetTemplatesIdDom', path: {'id': '$templateID'});
    if ((dom.data['html'] as String? ?? '').trim().isEmpty) {
      throw const ApiFailure('模板尚未生成可用版面，请稍后重试');
    }
    final detail = await request('GetResumesId', path: {'id': '$id'});
    if (!alive || version != epoch) throw const ApiFailure('账号已切换，请重试');
    final revision = integer(detail.data['revision']);
    if (revision <= 0) throw const ApiFailure('简历版本缺失，请刷新后重试');
    final content = jsonDecode(
      jsonEncode(detail.data['content'] ?? {}),
    ) as Map<String, dynamic>;
    content['app_layout'] = 'market';
    content['app_template_name'] = design['name'];
    final result = await request(
      'PatchResumesId',
      path: {'id': '$id'},
      body: {'content': content, 'template_id': templateID},
      extra: {'if-match': '"revision-$revision"'},
    );
    if (!alive || version != epoch) return;
    final index = resumes.indexWhere((draft) => draft.id == id);
    if (index >= 0) resumes[index] = decodeResume(result.data);
    changed();
    await load('resumes');
  }

  Future<void> saveArticleDraft({
    required int id,
    required String title,
    required Map<String, dynamic> content,
    int? resumeID,
    required int expectedEpoch,
  }) async {
    await request(
      'PatchArticlesId',
      path: {'id': '$id'},
      body: {'title': title, 'content': content, 'resume_id': ?resumeID},
      expectedEpoch: expectedEpoch,
    );
  }

  Future<SubmissionStatus> submitArticleDraft(
    int id, {
    required int expectedEpoch,
  }) async {
    final result = await request(
      'PostArticlesIdPublish',
      path: {'id': '$id'},
      body: {'content_policy_confirmed': true, 'public_fields_confirmed': true},
      expectedEpoch: expectedEpoch,
    );
    final status = submissionStatus(
      result.data,
      fallback: SubmissionStatus.pending,
    );
    unawaited(load('feed'));
    return status;
  }

  Future<SubmissionStatus> publish(
    String title,
    String text,
    String category, {
    Map<String, dynamic>? content,
    void Function(int)? onDraftSaved,
  }) async {
    final version = epoch;
    final draft = await request(
      'PostArticles',
      body: {
        'title': title,
        'content': content ?? richContent(text),
        'visibility': 'PUBLIC',
      },
    );
    final id = integer(draft.data['id']);
    if (id <= 0) throw const ApiFailure('草稿保存结果无效，请重试');
    onDraftSaved?.call(id);
    return submitArticleDraft(id, expectedEpoch: version);
  }

  @override
  void dispose() {
    alive = false;
    ++epoch;
    _realtimeRefresh?.cancel();
    _deliveryTimer?.cancel();
    unawaited(realtime?.stop(resetCursor: true));
    unawaited(_realtimeEvents.close());
    unawaited(api.close());
    super.dispose();
  }
}
