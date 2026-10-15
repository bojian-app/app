import 'dart:convert';
import 'dart:math' as math;

import 'guidance_inline_note.dart';
import 'guidance_help.dart';
import 'guidance_region_comments.dart';

import 'package:flutter/material.dart';

import 'app_store.dart';
import 'article_rich_content.dart';
import 'design.dart';
import 'resume_document.dart';
import 'resume_guidance_privacy.dart';
import 'resume_guidance_annotations.dart';
import 'resume_guidance_review.dart';

const _fieldLabels = {
  'full_name': '姓名',
  'phone': '手机号',
  'email': '邮箱',
  'birth_date': '出生日期',
  'gender': '性别',
  'position': '职位',
  'city': '城市',
  'industry': '行业',
  'salary': '薪资',
  'preference': '求职意向',
  'institution': '学校',
  'degree': '学历',
  'field_of_study': '专业',
  'start_date': '开始时间',
  'end_date': '结束时间',
  'campus_experience': '校园经历',
  'thesis_title': '论文题目',
  'thesis_description': '论文描述',
  'company': '公司',
  'current': '在职状态',
  'description': '内容',
  'name': '名称',
  'role': '担任角色',
  'url': '链接',
  'achievements': '成果',
  'issuer': '颁发机构',
  'date': '日期',
};
const _sectionLabels = {
  'personal_info': '个人信息',
  'job_expectation': '求职意向',
  'educations': '教育经历',
  'work_experiences': '工作经历',
  'projects': '项目经历',
  'skills': '专业技能',
  'certifications': '证书荣誉',
};

class ResumeGuidanceView extends StatefulWidget {
  const ResumeGuidanceView({
    super.key,
    required this.store,
    required this.id,
    this.notification = false,
    this.initialData,
    this.reviewerKey,
    this.fromNotification = false,
  });
  final AppStore store;
  final int id;
  final bool notification;
  final Map<String, dynamic>? initialData;
  final String? reviewerKey;
  final bool fromNotification;
  @override
  State<ResumeGuidanceView> createState() => _ResumeGuidanceViewState();
}

class _ResumeGuidanceViewState extends State<ResumeGuidanceView> {
  Map<String, dynamic>? data;
  String? error;
  ResumeDraft? resume;
  List<Map<String, dynamic>> records = [];
  bool get ownerReview => data?['is_owner'] == true && widget.fromNotification;
  bool get ownerLanding => ownerReview && widget.reviewerKey == null;
  bool get ownerDetail => data?['is_owner'] == true && !widget.fromNotification;
  List<Map<String, dynamic>> get reviewerRecords => records
      .where(
        (record) => ownerReview
            ? guidanceReviewerKey(record) == widget.reviewerKey
            : !ownerDetail &&
                  integer(record['reviewer_id']) == widget.store.userID,
      )
      .toList();
  String? busyRecord, activeRecord;
  bool saving = false;
  String get draftKey =>
      '${widget.store.userID}:${widget.notification}:${widget.id}:${widget.reviewerKey}';
  Set<int> get staged =>
      widget.store.guidanceReviewDrafts.putIfAbsent(draftKey, () => <int>{});
  List<Map<String, dynamic>> get visibleRecords => reviewerRecords
      .where(
        (v) =>
            '${v['replacement'] ?? ''}'.isEmpty ||
            (v['status'] != 'ACCEPTED' && !staged.contains(integer(v['id']))),
      )
      .toList();
  bool get otherViewer => data?['is_owner'] != true;

  ResumeDraft? ownPreviewBase;
  List<Map<String, dynamic>>? ownPreviewSource;
  (ResumeDraft, List<Map<String, dynamic>>)? ownPreviewCache;

  (ResumeDraft, List<Map<String, dynamic>>) get ownRewritePreview {
    if (identical(ownPreviewBase, resume) &&
        identical(ownPreviewSource, records) &&
        ownPreviewCache != null) {
      return ownPreviewCache!;
    }
    var preview = resume!;
    final shown = <Map<String, dynamic>>[];
    final ranges = <String, List<(int, int)>>{};
    final rewrites =
        reviewerRecords
            .where((record) => '${record['replacement'] ?? ''}'.isNotEmpty)
            .toList()
          ..sort((a, b) {
            if ((a['legacy'] == true) != (b['legacy'] == true)) {
              return a['legacy'] == true ? 1 : -1;
            }
            return integer(b['id']).compareTo(integer(a['id']));
          });
    for (final record in rewrites) {
      final path = '${record['field_path'] ?? ''}';
      final value = guidanceFieldText(resume!.source, path);
      final selected = '${record['selected_text'] ?? ''}'.isEmpty
          ? value
          : '${record['selected_text']}';
      final replacement = '${record['replacement']}';
      if (selected.isEmpty || value.isEmpty) continue;
      var start = value.indexOf(selected);
      var length = selected.length;
      final needsReplacement = selected.allMatches(value).length == 1;
      if (!needsReplacement) {
        if (replacement.allMatches(value).length != 1) continue;
        start = value.indexOf(replacement);
        length = replacement.length;
      }
      final occupied = ranges.putIfAbsent(path, () => []);
      if (occupied.any(
        (range) => start < range.$2 && range.$1 < start + length,
      )) {
        continue;
      }
      final item = {
        ...record,
        'selected_text': selected,
        'preview_applied': needsReplacement,
      };
      if (needsReplacement) {
        try {
          preview = guidanceDraftResume(preview, [item]);
        } on StateError {
          continue;
        }
      }
      occupied.add((start, start + length));
      shown.add(item);
    }
    ownPreviewBase = resume;
    ownPreviewSource = records;
    return ownPreviewCache = (preview, shown);
  }

  ResumeDraft get displayResume => otherViewer
      ? ownRewritePreview.$1
      : staged.isEmpty
      ? resume!
      : guidanceDraftResume(
          resume!,
          reviewerRecords
              .where((record) => staged.contains(integer(record['id'])))
              .toList(),
        );

  String previewQuote(String path, String quote) {
    if (!otherViewer || quote.isEmpty) return quote;
    for (final record in ownRewritePreview.$2.where(
      (record) =>
          record['preview_applied'] == true && record['field_path'] == path,
    )) {
      final selected = '${record['selected_text']}';
      if (selected.allMatches(quote).length == 1) {
        quote = quote.replaceFirst(selected, '${record['replacement']}');
      } else if (selected.contains(quote)) {
        quote = '${record['replacement']}';
      }
    }
    return quote;
  }

  String canonicalSelection(String path, String quote) {
    if (!otherViewer) return quote;
    for (final record in ownRewritePreview.$2.where(
      (record) =>
          record['preview_applied'] == true && record['field_path'] == path,
    )) {
      final replacement = '${record['replacement']}';
      if (replacement.allMatches(quote).length == 1) {
        quote = quote.replaceFirst(replacement, '${record['selected_text']}');
      }
    }
    return quote;
  }

  final documentKey = GlobalKey<ResumeDocumentViewState>();
  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      applyInitial();
    } else {
      load();
    }
  }

  Future<void> apply(Map<String, dynamic> value) async {
    ResumeDraft? fullResume;
    var nextRecords = <Map<String, dynamic>>[];
    final owner = value['is_owner'] == true;
    if (owner && !widget.fromNotification) {
      value = {...value, 'suggestions': <dynamic>[]};
    } else {
      final response = widget.store.isAuthenticated
          ? await widget.store.request(
              annotationMethod(widget.notification, 'Get'),
              path: {'id': '${widget.id}'},
            )
          : null;
      nextRecords =
          guidanceRecords(
                response?.data['items'] as List? ?? [],
                value['suggestions'] as List? ?? [],
              )
              .where(
                (record) =>
                    owner ||
                    '${record['replacement'] ?? ''}'.isEmpty ||
                    integer(record['reviewer_id']) == widget.store.userID,
              )
              .toList();
    }
    if (owner) {
      final id = integer(value['source_resume_id']);
      if (id > 0 && (!widget.fromNotification || widget.reviewerKey != null)) {
        final original = await widget.store.request(
          'GetResumesId',
          path: {'id': '$id'},
        );
        fullResume = decodeResume(original.data);
      }
    } else {
      value = privateGuidancePreview(value);
    }
    if (!mounted) return;
    setState(() {
      data = value;
      records = nextRecords;
      if (widget.reviewerKey != null) {
        staged.retainWhere(
          (id) => reviewerRecords.any(
            (v) => integer(v['id']) == id && v['status'] == 'PENDING',
          ),
        );
      }
      error = null;
      resume =
          fullResume ??
          decodeResume({
            'id': 0,
            'title': value['title'] ?? '分享的简历',
            'content': value['snapshot'] ?? <String, dynamic>{},
            'photo_url': value['photo_url'] ?? '',
          });
    });
  }

  Future<void> applyInitial() async {
    try {
      await apply(widget.initialData!);
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    }
  }

  Future<void> load() async {
    try {
      final result = await widget.store.request(
        widget.notification
            ? 'GetNotificationsIdGuidance'
            : 'GetArticlesIdGuidance',
        path: {'id': '${widget.id}'},
      );
      await apply(result.data);
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    }
  }

  Future<void> feedback() async {
    final snapshot = data!['snapshot'] as Map? ?? {};
    final fields = <String, String>{};
    for (final section in _sectionLabels.entries) {
      if (section.key == 'personal_info') continue;
      final value = snapshot[section.key];
      final entries = value is List
          ? value
          : value is Map
          ? [value]
          : [];
      for (var i = 0; i < entries.length; i++) {
        if (entries[i] is! Map) continue;
        final entry = entries[i] as Map;
        final identity =
            entry['company'] ?? entry['institution'] ?? entry['name'];
        final group = value is List
            ? '${section.value} · ${identity == null || '$identity'.isEmpty ? '${i + 1}' : identity}'
            : section.value;
        for (final field in entry.keys) {
          if ('${entry[field] ?? ''}'.contains(resumePrivacyMask) ||
              !_fieldLabels.containsKey(field) ||
              '${entry[field] ?? ''}'.isEmpty) {
            continue;
          }
          fields['${section.key}.${value is List ? '$i.' : ''}$field'] =
              '$group / ${_fieldLabels[field]}';
        }
      }
    }
    if (fields.isEmpty) {
      toast(context, '这份简历没有可点评的内容');
      return;
    }
    final sent = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _GuidanceFeedback(
        store: widget.store,
        id: widget.id,
        notification: widget.notification,
        fields: fields,
      ),
    );
    if (sent == true && mounted) {
      toast(context, '建议已发送');
      await load();
    }
  }

  Future<void> annotate(String path, String selected, bool replace) async {
    selected = canonicalSelection(path, selected);
    if (!replace) {
      await showRegionComments(
        context,
        store: widget.store,
        id: widget.id,
        notification: widget.notification,
        owner: false,
        onCommentsLoaded: syncComments,
        fieldPath: path,
        selected: selected,
        original: guidanceFieldText(data!['snapshot'] as Map, path),
      );
      return;
    }
    final sent = await composeGuidanceAnnotation(
      context,
      store: widget.store,
      id: widget.id,
      notification: widget.notification,
      snapshot: data!['snapshot'] as Map,
      fieldPath: path,
      selectedText: selected,
      replace: replace,
    );
    if (sent == true && mounted) {
      toast(context, replace ? '替换建议已发送，等待作者确认' : '评论已发送');
      await refreshAnnotations();
    }
  }

  Future<void> refreshAnnotations() async {
    try {
      final result = await widget.store.request(
        annotationMethod(widget.notification, 'Get'),
        path: {'id': '${widget.id}'},
      );
      if (!mounted) return;
      final all = guidanceRecords(
        result.data['items'] as List? ?? [],
        data!['suggestions'] as List? ?? [],
      );
      setState(
        () => records = all
            .where(
              (record) =>
                  data!['is_owner'] == true ||
                  '${record['replacement'] ?? ''}'.isEmpty ||
                  integer(record['reviewer_id']) == widget.store.userID,
            )
            .toList(),
      );
    } catch (e) {
      if (mounted) toast(context, '$e');
    }
  }

  Future<void> openReviewer(GuidanceParticipant participant) async {
    await openPage(
      context,
      ResumeGuidanceView(
        store: widget.store,
        id: widget.id,
        notification: widget.notification,
        initialData: data,
        reviewerKey: participant.key,
        fromNotification: true,
      ),
    );
    if (mounted) await load();
  }

  Future<void> decideInline(Map<String, dynamic> record, bool accept) async {
    if (busyRecord != null || saving) return;
    if (accept) {
      try {
        guidanceDraftResume(resume!, [
          ...reviewerRecords.where((v) => staged.contains(integer(v['id']))),
          record,
        ]);
        setState(() => staged.add(integer(record['id'])));
      } catch (e) {
        toast(context, '$e');
      }
      return;
    }
    setState(() => busyRecord = guidanceRecordKey(record));
    final sent = await runRequest(
      context,
      () => widget.store.request(
        annotationMethod(widget.notification, 'Post', decision: true),
        path: {'id': '${widget.id}', 'annotation_id': '${record['id']}'},
        body: {'status': accept ? 'ACCEPTED' : 'REJECTED'},
      ),
    );
    if (!mounted) return;
    if (sent) {
      await load();
    }
    if (mounted) setState(() => busyRecord = null);
  }

  Future<void> saveReview() async {
    if (saving || staged.isEmpty) return;
    final ids = staged.toList()..sort();
    setState(() => saving = true);
    final sent = await runRequest(
      context,
      () => widget.store.request(
        annotationMethod(widget.notification, 'Post', decision: true),
        path: {'id': '${widget.id}', 'annotation_id': '${ids.first}'},
        body: {'status': 'ACCEPTED', 'annotation_ids': ids},
      ),
    );
    if (!mounted) return;
    if (sent) {
      setState(() => staged.clear());
      await load();
      await widget.store.load('resumes');
      if (mounted) toast(context, '已保存为新简历，原简历已保留');
    }
    if (mounted) setState(() => saving = false);
  }

  double documentScale(BuildContext context) =>
      math.min(680.0, MediaQuery.sizeOf(context).width - 24) /
      resumePaperSize.width;

  List<ResumeReviewNote> inlineNotes(BuildContext context) {
    final scale = documentScale(context);
    final width = (resumePaperSize.width - resumePaperMargin * 2) * scale;
    return [
      for (final record in visibleRecords.where(
        (v) => '${v['replacement'] ?? ''}'.isNotEmpty,
      ))
        ResumeReviewNote(
          key: guidanceRecordKey(record),
          fieldPath: '${record['field_path'] ?? ''}',
          selectedText: '${record['selected_text'] ?? ''}',
          height: math.min(
            guidanceNoteHeight(
                  context,
                  record,
                  width,
                  canDecide: ownerReview,
                  paperScale: scale,
                ) /
                scale,
            resumePaperSize.height - 100,
          ),
        ),
    ];
  }

  Map<String, List<Map<String, dynamic>>> get commentGroups {
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final record in records.where(
      (v) => '${v['replacement'] ?? ''}'.isEmpty,
    )) {
      final key = jsonEncode([
        record['field_path'],
        record['selected_text'] ?? '',
      ]);
      groups.putIfAbsent(key, () => []).add(record);
    }
    return groups;
  }

  List<Map<String, dynamic>> get acceptedRecords => reviewerRecords
      .where(
        (record) =>
            '${record['replacement'] ?? ''}'.isNotEmpty &&
            (record['status'] == 'ACCEPTED' ||
                staged.contains(integer(record['id']))),
      )
      .toList();

  List<ResumeReviewHighlight> get reviewHighlights => [
    if (otherViewer)
      for (final record in ownRewritePreview.$2)
        ResumeReviewHighlight(
          key: guidanceRecordKey(record),
          fieldPath: '${record['field_path']}',
          text: '${record['replacement']}',
          color: guidanceReplacementColor,
          label: '改写',
          colorText: true,
          originalText: '${record['selected_text']}',
          statusLabel: record['status'] == 'ACCEPTED'
              ? '已采纳'
              : record['status'] == 'REJECTED'
              ? '未采纳'
              : '待采纳',
        ),
    if (!otherViewer)
      for (final record in visibleRecords.where(
        (v) => '${v['replacement'] ?? ''}'.isNotEmpty,
      ))
        ResumeReviewHighlight(
          key: guidanceRecordKey(record),
          fieldPath: '${record['field_path'] ?? ''}',
          text: '${record['selected_text'] ?? ''}',
          color: guidanceReplacementColor,
          label: '改写',
          colorText: true,
        ),
    if (!otherViewer)
      for (final record in acceptedRecords)
        ResumeReviewHighlight(
          key: 'accepted:${guidanceRecordKey(record)}',
          fieldPath: '${record['field_path'] ?? ''}',
          text: '${record['replacement'] ?? ''}',
          color: guidanceReplacementColor,
          label: '按住查看原文',
          originalText: '${record['selected_text'] ?? ''}',
          colorText: true,
        ),
    for (final group in commentGroups.entries)
      ResumeReviewHighlight(
        key: 'comments:${group.key}',
        fieldPath: '${group.value.first['field_path'] ?? ''}',
        text: previewQuote(
          '${group.value.first['field_path'] ?? ''}',
          '${group.value.first['selected_text'] ?? ''}',
        ),
        sourceText: '${group.value.first['selected_text'] ?? ''}',
        color: guidanceCommentColor,
        label: '评论',
        isWavy: true,
        commentCount: group.value.length,
      ),
  ];

  void syncComments(List<Map<String, dynamic>> comments) {
    if (!mounted) return;
    final next = [
      ...records.where(
        (record) =>
            record['legacy'] == true ||
            '${record['replacement'] ?? ''}'.isNotEmpty,
      ),
      ...guidanceRecords(comments, []),
    ];
    if (jsonEncode(next) != jsonEncode(records)) setState(() => records = next);
  }

  Future<void> openReviewMarks(List<ResumeReviewHighlight> marks) async {
    final comments = marks.where((v) => v.commentCount > 0);
    if (comments.isEmpty) {
      if (!ownerReview) return;
      setState(() => activeRecord = marks.first.key);
      return;
    }
    final mark = comments.first;
    await showRegionComments(
      context,
      store: widget.store,
      id: widget.id,
      notification: widget.notification,
      owner: data!['is_owner'] == true,
      onCommentsLoaded: syncComments,
      legacyItems: records.where((v) => v['legacy'] == true).toList(),
      fieldPath: mark.fieldPath,
      selected: mark.sourceText ?? mark.text,
      original: guidanceFieldText(
        data!['snapshot'] as Map? ?? {},
        mark.fieldPath,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => GuidanceWalkthrough(
    store: widget.store,
    id: ownerLanding
        ? 'participants'
        : ownerReview
        ? 'review'
        : ownerDetail
        ? 'author-detail'
        : 'reviewer',
    ready: data != null,
    steps: [
      if (ownerLanding) ...[
        const GuidanceStep(
          'guidance-participant-',
          '选择一位指点者',
          '点击这里，逐位查看对方的评论和改写建议。列表可下拉刷新。',
          prefix: true,
        ),
      ] else if (ownerDetail) ...[
        const GuidanceStep(
          'tour-document',
          '这是你的简历预览',
          '上下滑动阅读，双指缩放。要处理大家的建议，请从“消息 → 系统通知”进入指点通知，再选择参与者。',
        ),
      ] else if (ownerReview) ...[
        const GuidanceStep(
          'tour-document',
          '对照原文审阅',
          '上下滑动查看建议。波浪线表示评论，点击评论标记可以回复；改写内容会附在原文附近。',
        ),
        const GuidanceStep(
          'guidance-inline-note-',
          '比较这条改写',
          '这里展示对方建议的文字。早期建议如提示手动调整，请到简历编辑页修改。',
          prefix: true,
        ),
        const GuidanceStep(
          'tour-accept',
          '先采纳，预览效果',
          '点击“采纳”可预览替换后的简历；按住替换后的文字查看原文。原文变化或建议重叠时，请核对后手动调整。',
        ),
        const GuidanceStep(
          'tour-reject',
          '不适合可以不采纳',
          '点击“不采纳”会直接提交这个决定。评论不用采纳，点击对应评论即可交流。',
        ),
        const GuidanceStep(
          'tour-save',
          '最后一定要保存',
          '采纳后点击这里，才会保存为新简历，原简历会保留。没有待保存的采纳内容时按钮不可用。完成后可返回查看其他人的建议。',
        ),
      ] else ...[
        const GuidanceStep(
          'tour-document',
          '先看看这份简历',
          '上下滑动阅读，双指捏合缩放，放大后拖动查看。隐藏的个人信息不能选中或改写。',
        ),
        const GuidanceStep(
          'resume-annotation-region-',
          '点这段文字开始指点',
          '点击简历文字区域，会出现“查看评论”和“参与改写”。点击菜单外可取消选中。',
          prefix: true,
        ),
        const GuidanceStep(
          'resume-annotation-region-',
          '评论，说说你的看法',
          '选中后点击“查看评论”，就能讨论这段内容。已有讨论会显示波浪线和评论数量，点击标记也能进入。',
          prefix: true,
        ),
        const GuidanceStep(
          'resume-annotation-region-',
          '改写，给出具体写法',
          '选中后点击“参与改写”。提交后仅你和作者可见，等待作者采纳；按住改写后的文字可对照原文。',
          prefix: true,
        ),
        const GuidanceStep(
          'tour-feedback',
          '也可以按项目给建议',
          '点击这里，选择简历项目后填写建议。这类建议不会直接替换原文。',
        ),
      ],
    ],
    child: Scaffold(
      appBar: AppBar(
        title: Text(
          ownerDetail
              ? '简历详情'
              : ownerReview && widget.reviewerKey != null
              ? '审阅指点'
              : '简历指点',
        ),
        actions: [
          if (ownerReview && widget.reviewerKey != null)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: TextButton(
                key: const ValueKey('tour-save'),
                onPressed: staged.isEmpty || saving ? null : saveReview,
                child: saving
                    ? const SizedBox(
                        width: 17,
                        height: 17,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('保存'),
              ),
            ),
        ],
      ),
      body: data == null
          ? Center(
              child: error == null
                  ? const CircularProgressIndicator(strokeWidth: 2)
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(error!),
                        TextButton(onPressed: load, child: const Text('重新加载')),
                      ],
                    ),
            )
          : ownerLanding
          ? GuidanceParticipantList(
              title: '${data!['title'] ?? '分享的简历'}',
              records: records,
              onReview: openReviewer,
              onRefresh: load,
            )
          : Column(
              children: [
                if (ownerReview && reviewerRecords.isNotEmpty)
                  GuidanceReviewHeading(
                    participant: GuidanceParticipant(
                      widget.reviewerKey!,
                      reviewerRecords,
                    ),
                  ),
                if (data!['is_owner'] != true &&
                    '${data!['question'] ?? ''}'.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${data!['question']}',
                        style: const TextStyle(fontSize: 13, height: 1.6),
                      ),
                    ),
                  ),
                Expanded(
                  key: const ValueKey('tour-document'),
                  child: data!['snapshot'] == null
                      ? SingleChildScrollView(
                          padding: const EdgeInsets.all(20),
                          child: ArticleRichBody(
                            content: Map<String, dynamic>.from(
                              data!['legacy_content'] as Map? ?? {},
                            ),
                          ),
                        )
                      : ResumeDocumentView(
                          key: documentKey,
                          resume: displayResume,
                          onAnnotate: data!['is_owner'] == true
                              ? null
                              : annotate,
                          reviewNotes: ownerReview
                              ? inlineNotes(context)
                              : const [],
                          reviewNoteBuilder: ownerReview
                              ? (context, key) {
                                  final record = reviewerRecords.firstWhere(
                                    (v) => guidanceRecordKey(v) == key,
                                  );
                                  return GuidanceInlineNote(
                                    key: ValueKey('guidance-inline-note-$key'),
                                    record: record,
                                    paperScale: documentScale(context),
                                    canDecide: ownerReview,
                                    busy: busyRecord == key,
                                    disabled: busyRecord != null || saving,
                                    active: activeRecord == key,
                                    onDecide: (accept) =>
                                        decideInline(record, accept),
                                  );
                                }
                              : null,
                          reviewHighlights: ownerDetail
                              ? const []
                              : reviewHighlights,
                          onReviewTap: ownerDetail ? null : openReviewMarks,
                        ),
                ),
              ],
            ),
      bottomNavigationBar: data?['can_review'] == true
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton(
                  key: const ValueKey('tour-feedback'),
                  onPressed: feedback,
                  child: const Text('给出建议'),
                ),
              ),
            )
          : null,
    ),
  );
}

class _GuidanceFeedback extends StatefulWidget {
  const _GuidanceFeedback({
    required this.store,
    required this.id,
    required this.notification,
    required this.fields,
  });
  final AppStore store;
  final int id;
  final bool notification;
  final Map<String, String> fields;
  @override
  State<_GuidanceFeedback> createState() => _GuidanceFeedbackState();
}

class _GuidanceFeedbackState extends State<_GuidanceFeedback> {
  final suggestion = TextEditingController();
  late String field = widget.fields.keys.first;
  String? lastPayload, key;
  bool sending = false;
  @override
  void dispose() {
    suggestion.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (sending || suggestion.text.trim().isEmpty) return;
    final body = {
      'items': [
        {
          'field_path': field,
          'suggestion': suggestion.text.trim(),
          'replacement': '',
        },
      ],
    };
    final payload = jsonEncode(body);
    if (payload != lastPayload) {
      lastPayload = payload;
      key =
          'mobile-feedback-${widget.id}-${DateTime.now().microsecondsSinceEpoch}';
    }
    setState(() => sending = true);
    final sent = await runRequest(
      context,
      () => widget.store.request(
        widget.notification
            ? 'PostNotificationsIdGuidanceSubmissions'
            : 'PostArticlesIdGuidanceSubmissions',
        path: {'id': '${widget.id}'},
        body: body,
        extra: {'idempotency-key': key!},
      ),
    );
    if (!mounted) return;
    if (sent) {
      Navigator.pop(context, true);
    } else {
      setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => GuidanceWalkthrough(
    store: widget.store,
    id: 'feedback',
    steps: const [
      GuidanceStep('tour-feedback-field', '选好建议对应的项目', '展开这里，选择你想点评的简历内容。'),
      GuidanceStep(
        'tour-feedback-input',
        '写下具体建议',
        '说明哪里可以改进、为什么，以及怎么修改。这里是文字建议，不会直接替换原文。',
      ),
      GuidanceStep(
        'tour-feedback-send',
        '确认后发送',
        '点击“发送建议”提交。发送失败时输入会保留，可检查网络后重试。',
      ),
    ],
    child: PopScope(
      canPop: !sending,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            20,
            24,
            20,
            20 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '给出建议',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                key: const ValueKey('tour-feedback-field'),
                initialValue: field,
                isExpanded: true,
                decoration: const InputDecoration(labelText: '针对哪一项'),
                items: widget.fields.entries
                    .map(
                      (e) => DropdownMenuItem(
                        value: e.key,
                        child: Text(
                          e.value,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: sending ? null : (v) => setState(() => field = v!),
              ),
              const SizedBox(height: 16),
              TextField(
                key: const ValueKey('tour-feedback-input'),
                controller: suggestion,
                enabled: !sending,
                minLines: 3,
                maxLines: 6,
                maxLength: 10000,
                decoration: const InputDecoration(hintText: '写下具体的修改建议'),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const ValueKey('tour-feedback-send'),
                  onPressed: sending ? null : submit,
                  child: Text(sending ? '正在发送…' : '发送建议'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
