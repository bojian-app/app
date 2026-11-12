part of 'app_store.dart';

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

  /// Where the next page of top-level comments starts; empty at the end.
  String commentsCursor = '';
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
ResumeEditorProgress resumeDraftProgress(ResumeDraft draft) {
  Iterable<Map<String, dynamic>> entries(String key) =>
      (draft.source[key] as List? ?? []).whereType<Map>().map((value) {
        final entry = Map<String, dynamic>.from(value);
        // Imported resumes can contain rich text without a plain-text copy.
        for (final field in [
          'description',
          'achievements',
          'campus_experience',
        ]) {
          if ((entry[field]?.toString().trim() ?? '').isEmpty) {
            entry[field] = plainContent(entry['${field}_rich']);
          }
        }
        return entry;
      });
  return resumeEditorProgress(
    fields: {
      'name': draft.name,
      'phone': draft.phone,
      'email': draft.email,
      'position': draft.position,
      'city': draft.city,
    },
    work: entries('work_experiences'),
    projects: entries('projects'),
    education: entries('educations'),
    skills: entries('skills'),
  );
}

ResumeDraft decodeResume(Map<String, dynamic> v) {
  final content = cleanResumeGeneratedContent(
    (v['content'] as Map<String, dynamic>?) ?? {},
  );
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
  draft.progress = resumeDraftProgress(draft).fraction;
  return draft;
}

/// Shows the in-login phone step for [token]. Returns the next login response
/// and the proved phone, or null when the user backs out.
typedef LoginPhoneBinding =
    Future<({auth.LoginResponse response, String phone})?> Function(
      String token,
    );
