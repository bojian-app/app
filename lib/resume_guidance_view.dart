import 'content_report.dart';

import 'dart:async';

import 'content_moderation.dart';

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
import 'user_profile_page.dart';

class ResumeGuidanceView extends StatefulWidget {
  const ResumeGuidanceView({
    super.key,
    required this.store,
    required this.id,
    this.notification = false,
    this.initialData,
    this.reviewerKey,
    this.fromNotification = false,
    this.focusAnnotationID = 0,
  });
  final AppStore store;
  final int id;
  final bool notification;
  final Map<String, dynamic>? initialData;
  final String? reviewerKey;
  final bool fromNotification;
  final int focusAnnotationID;
  @override
  State<ResumeGuidanceView> createState() => _ResumeGuidanceViewState();
}

class _ResumeGuidanceViewState extends State<ResumeGuidanceView> {
  final guidance = GuidanceFlowController();
  Map<String, dynamic>? data;
  String? error;
  ResumeDraft? resume;
  List<Map<String, dynamic>> records = [];
  Timer? moderationTimer;
  StreamSubscription<Map<String, dynamic>>? removalSubscription;
  bool refreshingAnnotations = false;
  void submissionChanged() {
    if (!mounted) return;
    final local = widget.store.localContent(
      annotationMethod(widget.notification, 'Post'),
      widget.id,
    );
    setState(
      () => records = [
        ...local,
        ...records.where(
          (v) =>
              !v.containsKey('_method') &&
              !local.any((l) => l['id'] == v['id']),
        ),
      ],
    );
  }

  String? focusedReviewerKey;
  String? get reviewerKey => focusedReviewerKey ?? widget.reviewerKey;
  bool focusHandled = false, focusScheduled = false;
  bool guidanceAfterNotification = false;
  int? loadedEpoch;
  bool get ownerReview => data?['is_owner'] == true && widget.fromNotification;
  bool get ownerLanding => ownerReview && reviewerKey == null;
  bool get ownerDetail => data?['is_owner'] == true && !widget.fromNotification;
  List<Map<String, dynamic>> get reviewerRecords => records
      .where(
        (record) => ownerReview
            ? guidanceReviewerKey(record) == reviewerKey
            : !ownerDetail &&
                  integer(record['reviewer_id']) == widget.store.userID,
      )
      .toList();
  String? busyRecord, activeRecord;
  bool saving = false;
  String get draftKey =>
      '${widget.store.userID}:${widget.notification}:${widget.id}:$reviewerKey';
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

  void scheduleNotificationFocus() {
    if (focusHandled ||
        focusScheduled ||
        widget.focusAnnotationID <= 0 ||
        data == null ||
        resume == null ||
        loadedEpoch != widget.store.epoch) {
      return;
    }
    focusScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      focusScheduled = false;
      if (!mounted ||
          focusHandled ||
          loadedEpoch != widget.store.epoch ||
          ModalRoute.of(context)?.isCurrent != true) {
        return;
      }
      final animation = ModalRoute.of(context)?.animation;
      if (animation != null && animation.status != AnimationStatus.completed) {
        scheduleNotificationFocus();
        return;
      }
      unawaited(focusNotification());
    });
  }

  Future<void> focusNotification() async {
    final record = records
        .where(
          (record) =>
              record['legacy'] != true &&
              integer(record['id']) == widget.focusAnnotationID,
        )
        .firstOrNull;
    if (record == null || documentKey.currentState == null) {
      focusHandled = true;
      return;
    }
    focusHandled = true;
    final comment = '${record['replacement'] ?? ''}'.isEmpty;
    final key = comment
        ? 'comments:${jsonEncode([record['field_path'], record['selected_text'] ?? ''])}'
        : ownerReview &&
              (record['status'] == 'ACCEPTED' ||
                  staged.contains(integer(record['id'])))
        ? 'accepted:${guidanceRecordKey(record)}'
        : guidanceRecordKey(record);
    if (!comment) setState(() => activeRecord = guidanceRecordKey(record));
    documentKey.currentState!.focusReview(key, alignment: comment ? .05 : .18);
    if (!comment) return;
    WidgetsBinding.instance.ensureVisualUpdate();
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted ||
        loadedEpoch != widget.store.epoch ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    await showRegionComments(
      context,
      store: widget.store,
      id: widget.id,
      notification: widget.notification,
      owner: data!['is_owner'] == true,
      onCommentsLoaded: syncComments,
      legacyItems: records.where((record) => record['legacy'] == true).toList(),
      fieldPath: '${record['field_path'] ?? ''}',
      selected: '${record['selected_text'] ?? ''}',
      original: guidanceFieldText(
        data!['snapshot'] as Map? ?? {},
        '${record['field_path'] ?? ''}',
      ),
      focusAnnotationID: widget.focusAnnotationID,
    );
  }

  @override
  void initState() {
    super.initState();
    widget.store.addListener(submissionChanged);
    removalSubscription = widget.store.realtimeEvents.listen((event) {
      if (mounted &&
          guidanceRemovalAffects(event, widget.id, widget.notification)) {
        final payload = event['data'] as Map;
        if ({'ARTICLE', 'POST'}.contains(payload['subject_type'])) {
          setState(() {
            data = null;
            records = [];
            error = '该内容已撤回';
          });
          return;
        }
        refreshAnnotations();
      }
    });
    moderationTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted &&
          data != null &&
          widget.store.foreground &&
          ModalRoute.of(context)?.isCurrent == true &&
          (records.any(
                (r) =>
                    {'SENDING', 'QUEUED', 'PENDING'}.contains(contentStatus(r)),
              ) ||
              widget.store
                  .localContent(
                    annotationMethod(widget.notification, 'Post'),
                    widget.id,
                  )
                  .isNotEmpty)) {
        refreshAnnotations();
      }
    });
    if (widget.initialData != null) {
      applyInitial();
    } else {
      load();
    }
  }

  @override
  void dispose() {
    moderationTimer?.cancel();
    unawaited(removalSubscription?.cancel());
    widget.store.removeListener(submissionChanged);
    guidance.dispose();
    super.dispose();
  }

  Future<void> apply(Map<String, dynamic> value) async {
    final epoch = widget.store.epoch;
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
      if (!mounted) return;
      nextRecords =
          guidanceRecords(
                widget.store.mergeContent(
                  annotationMethod(widget.notification, 'Post'),
                  widget.id,
                  (response?.data['items'] as List? ?? [])
                      .whereType<Map>()
                      .map((v) => Map<String, dynamic>.from(v))
                      .toList(),
                ),
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
      final target = nextRecords
          .where(
            (record) =>
                record['legacy'] != true &&
                integer(record['id']) == widget.focusAnnotationID,
          )
          .firstOrNull;
      final targetReviewer = target == null
          ? widget.reviewerKey
          : guidanceReviewerKey(target);
      final id = integer(value['source_resume_id']);
      if (id > 0 && (!widget.fromNotification || targetReviewer != null)) {
        final original = await widget.store.request(
          'GetResumesId',
          path: {'id': '$id'},
        );
        fullResume = decodeResume(original.data);
      }
    } else {
      value = privateGuidancePreview(value);
    }
    if (!mounted || epoch != widget.store.epoch) return;
    setState(() {
      loadedEpoch = epoch;
      data = value;
      records = nextRecords;
      final target = records
          .where(
            (record) =>
                record['legacy'] != true &&
                integer(record['id']) == widget.focusAnnotationID,
          )
          .firstOrNull;
      focusedReviewerKey = owner && target != null
          ? guidanceReviewerKey(target)
          : null;
      if (reviewerKey != null) {
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
      toast(context, '已提交，审核状态可在我的指点记录中查看');
      submissionChanged();
      await refreshAnnotations();
    }
  }

  Future<void> refreshAnnotations() async {
    if (refreshingAnnotations || data == null) return;
    refreshingAnnotations = true;
    try {
      final result = await widget.store.request(
        annotationMethod(widget.notification, 'Get'),
        path: {'id': '${widget.id}'},
      );
      if (!mounted) return;
      final all = guidanceRecords(
        widget.store.mergeContent(
          annotationMethod(widget.notification, 'Post'),
          widget.id,
          (result.data['items'] as List? ?? [])
              .whereType<Map>()
              .map((v) => Map<String, dynamic>.from(v))
              .toList(),
        ),
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
      // Background refresh retries on the next tick without interrupting editing.
    } finally {
      refreshingAnnotations = false;
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
        setState(() {
          staged.add(integer(record['id']));
          guidanceAfterNotification = true;
        });
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
          statusLabel: !contentVisible(record)
              ? moderationLabel(contentStatus(record))
              : record['status'] == 'ACCEPTED'
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
      if (!ownerReview) {
        await openPage(
          context,
          GuidanceAnnotations(
            store: widget.store,
            id: widget.id,
            notification: widget.notification,
            owner: data!['is_owner'] == true,
            onChanged: refreshAnnotations,
            mineOnly: true,
            initialItems: records,
            currentSnapshot: data!['snapshot'] as Map?,
          ),
        );
        if (mounted) refreshAnnotations();
        return;
      }
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

  bool get hasOwnRewrites =>
      otherViewer && resume != null && ownRewritePreview.$2.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    ModalRoute.isCurrentOf(context);
    scheduleNotificationFocus();
    return GuidanceWalkthrough(
      store: widget.store,
      controller: guidance,
      id: ownerReview
          ? 'review-save'
          : hasOwnRewrites
          ? 'rewrite-preview'
          : 'reviewer',
      // A notification selects its own destination. A later adoption may
      // introduce comparison guidance without moving the initial destination.
      ready:
          data != null &&
          (widget.focusAnnotationID <= 0 || guidanceAfterNotification),
      steps: [
        if (ownerReview && staged.isNotEmpty)
          const GuidanceStep(
            'guidance-compare-region-',
            '按住改写，就能查看原文',
            '按住紫色文字对照原文，松开恢复。采纳目前只是预览，确认后点击右上角“保存”生成新简历，原简历会保留。',
            prefix: true,
            event: 'review.compared',
            gesture: GuidanceGesture.hold,
            optional: true,
            acknowledgeLabel: '知道了',
          )
        else if (hasOwnRewrites)
          const GuidanceStep(
            'guidance-compare-region-',
            '按住改写，就能查看原文',
            '按住改写后的文字对照原文，松开恢复。改写仅你和作者可见，作者采纳并保存后才会生成新简历。',
            prefix: true,
            event: 'reviewer.compared',
            gesture: GuidanceGesture.hold,
          )
        else if (otherViewer && data?['snapshot'] != null)
          const GuidanceStep(
            'resume-annotation-region-',
            '点这段文字开始指点',
            '点一下简历中的文字，就能查看评论或参与改写。隐藏的信息不能选中。',
            prefix: true,
            event: 'reviewer.selected',
          ),
      ],
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            ownerDetail
                ? '简历详情'
                : ownerReview && reviewerKey != null
                ? '审阅指点'
                : '简历指点',
          ),
          actions: [
            if (!widget.notification &&
                data != null &&
                data?['is_owner'] != true)
              ReportArticleButton(store: widget.store, articleID: widget.id),
            if (ownerReview && reviewerKey != null)
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
                          TextButton(
                            onPressed: load,
                            child: const Text('重新加载'),
                          ),
                        ],
                      ),
              )
            : ownerLanding
            ? GuidanceParticipantList(
                title: '${data!['title'] ?? '分享的简历'}',
                records: records,
                onReview: openReviewer,
                onRefresh: load,
                onOpenProfile: (person) => openUserProfile(
                  context,
                  store: widget.store,
                  userID: person.userID,
                ),
              )
            : Column(
                children: [
                  if (ownerReview && reviewerRecords.isNotEmpty)
                    GuidanceReviewHeading(
                      onOpenProfile: () => openUserProfile(
                        context,
                        store: widget.store,
                        userID: integer(reviewerRecords.first['reviewer_id']),
                      ),
                      participant: GuidanceParticipant(
                        reviewerKey!,
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
                            store: widget.store,
                            onAnnotationSelected: () =>
                                guidance.complete('reviewer.selected'),
                            onOriginalShown: () => guidance.complete(
                              ownerReview
                                  ? 'review.compared'
                                  : 'reviewer.compared',
                            ),
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
                                      key: ValueKey(
                                        'guidance-inline-note-$key',
                                      ),
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
      ),
    );
  }
}
