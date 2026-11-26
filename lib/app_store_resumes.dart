part of 'app_store.dart';

/// Resumes, templates and article drafts.
extension AppStoreResumes on AppStore {
  ResumeDraft createResume({String template = '', String? importedText}) =>
      ResumeDraft(
        id: 0,
        title: importedText == null ? '新的简历' : '导入的简历',
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

  Future<String> unpublishArticle(int id) async {
    final version = epoch;
    final response = await request(
      'PostArticlesIdUnpublish',
      path: {'id': '$id'},
    );
    final status = response.data['status']?.toString() ?? 'DRAFT';
    if (!alive || version != epoch) return status;
    stories.removeWhere((story) => story.id == id);
    _realtimeEvents.add({
      'type': 'article.updated',
      'data': {'article_id': id, 'status': status},
    });
    changed();
    return status;
  }

  Future<ResumeDraft> copyResume(int id) async {
    if (copyingResume) throw const ApiFailure('正在创建副本，请稍候');
    final version = epoch;
    copyingResume = true;
    changed();
    var success = false;
    try {
      final response = await request(
        'PostResumesIdCopies',
        path: {'id': '$id'},
      );
      if (!alive || epoch != version) throw const ApiFailure('账号已切换');
      final copied = decodeResume(response.data);
      if (copied.id <= 0 || copied.id == id) {
        throw const ApiFailure('副本结果无效，请刷新简历列表确认');
      }
      resumes.removeWhere((resume) => resume.id == copied.id);
      resumes.insert(0, copied);
      success = true;
      changed();
      return copied;
    } finally {
      void release() {
        if (!alive) return;
        copyingResume = false;
        changed();
      }

      // 成功后保持锁定，覆盖页面转场与新页面刚出现的阶段；失败则立即允许重试。
      if (success) {
        Timer(const Duration(seconds: 1), release);
      } else {
        release();
      }
    }
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

  /// Acquired templates, plus every paid one for members; authored drafts are excluded.
  Future<List<Map<String, dynamic>>> purchasedResumeTemplates() async {
    final result = await request('GetMeTemplates');
    final seen = <int>{};
    return items(result.data)
        .where(
          (row) =>
              (row['source'] == 'ACQUIRED' || row['source'] == 'MEMBER') &&
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
    final dom = await loadTemplatePreviewDOM(
      this,
      templateID,
      integer(design['version']),
      persist: true,
    );
    if ((dom.data['html'] as String? ?? '').trim().isEmpty &&
        !isResumeThemeSchema(dom.data['schema'])) {
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

  Future<int> createArticleDraft({
    required String title,
    required Map<String, dynamic> content,
    String visibility = 'PUBLIC',
    bool? followedRepliesOnly,
    required int expectedEpoch,
  }) async {
    final response = await request(
      'PostArticles',
      body: {
        'title': title,
        'content': content,
        'visibility': visibility,
        'followed_replies_only': ?followedRepliesOnly,
      },
      expectedEpoch: expectedEpoch,
    );
    final id = integer(response.data['id']);
    if (id <= 0) throw const ApiFailure('草稿保存结果无效，请重试');
    return id;
  }

  Future<void> saveArticleDraft({
    required int id,
    required String title,
    required Map<String, dynamic> content,
    int? resumeID,
    String? visibility,
    bool? followedRepliesOnly,
    required int expectedEpoch,
  }) async {
    await request(
      'PatchArticlesId',
      path: {'id': '$id'},
      body: {
        'title': title,
        'content': content,
        'resume_id': ?resumeID,
        'visibility': ?visibility,
        'followed_replies_only': ?followedRepliesOnly,
      },
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
    String visibility = 'PUBLIC',
    bool? followedRepliesOnly,
    void Function(int)? onDraftSaved,
  }) async {
    final version = epoch;
    final id = await createArticleDraft(
      title: title,
      content: content ?? richContent(text),
      visibility: visibility,
      followedRepliesOnly: followedRepliesOnly,
      expectedEpoch: version,
    );
    onDraftSaved?.call(id);
    return submitArticleDraft(id, expectedEpoch: version);
  }
}
