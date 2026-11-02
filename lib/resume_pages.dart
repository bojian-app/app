import 'resume_module_order.dart';
import 'resume_module_drag.dart';
import 'resume_photo_image.dart';
import 'app_page_bar.dart';
import 'app_action_sheet.dart';
import 'playful_refresh.dart';
import 'app_icons.dart';
import 'date_wheel_picker.dart';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;

import 'dart:io';

import 'package:file_selector/file_selector.dart';

import 'resume_files.dart';
import 'app_photo_picker.dart';
import 'resume_add_sheet.dart';
import 'resume_assistance_page.dart';
import 'resume_document.dart';
import 'resume_preview_trace.dart';
import 'route_transition_snapshot.dart';
import 'resume_importer.dart';
import 'resume_photo.dart';
import 'resume_photo_actions.dart';
import 'resume_preview_controls.dart';
import 'resume_rename.dart';
import 'resume_delete.dart';
import 'resume_photo_crop.dart';
import 'resume_export.dart';
import 'resume_work_experience.dart';
import 'resume_education.dart';
import 'resume_editor_progress.dart';
import 'resume_editor_sections.dart';
import 'resume_editor_typography.dart';
import 'resume_option_picker.dart';
import 'resume_additional_fields.dart';
import 'resume_updated_label.dart';
import 'resume_market_document.dart';
import 'template_market.dart';
import 'resume_template_picker.dart';
import 'resume_thumbnail.dart';
import 'resume_user_share.dart';
import 'resume_post_composer.dart';
import 'resume_preview_color.dart';
import 'resume_link_share.dart';
import 'resume_ai_optimization_page.dart';

import 'dart:async';

import 'api/bojian_api.dart';

import 'app_store.dart';
import 'design.dart';
import 'confirmation_dialog.dart';

class ResumeLibrary extends StatelessWidget {
  const ResumeLibrary({super.key, required this.store, this.embedded = false});
  final AppStore store;
  final bool embedded;
  @override
  Widget build(BuildContext context) => PlayfulRefresh(
    hasError: () => store.errors['resumes'] != null,
    onRefresh: () => store.load('resumes'),
    child: ListView(
      key: PageStorageKey(embedded ? 'profile-resumes' : 'resume-library'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.only(top: embedded ? 8 : 0, bottom: 24),
      children: [
        if (!embedded) ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 18, 24, 16),
            child: Text(
              '我的简历',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                letterSpacing: -.5,
              ),
            ),
          ),
        ],
        if (!embedded)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Expanded(
                  child: _actionCard(
                    context,
                    label: '创建简历',
                    icon: AppIcons.add,
                    onTap: () => _create(context),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _actionCard(
                    context,
                    label: '导入简历',
                    icon: AppIcons.importResume,
                    onTap: () => _import(context),
                  ),
                ),
              ],
            ),
          ),
        if (!embedded) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 14, 24, 18),
            child: InkWell(
              onTap: () => openPage(context, TemplateMarket(store: store)),
              borderRadius: BorderRadius.circular(18),
              child: Panel(
                padding: EdgeInsets.all(14),
                child: Row(
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: (context.isDark
                            ? context.colors.warningSoft
                            : Color(0xFFFFF4E5)),
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(10),
                        child: AppIcon(
                          AppIcons.templateMarket,
                          color: Color(0xFFD69B4C),
                          size: 22,
                        ),
                      ),
                    ),
                    SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '找到适合你的模版',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            '逛逛模板市场，让经历更出彩',
                            style: TextStyle(
                              fontSize: 11,
                              color: context.colors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    AppIcon(
                      AppIcons.forward,
                      color: context.colors.muted,
                      size: 14,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
            child: Row(
              children: [
                const Text(
                  '简历库',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 8),
                Text(
                  '${store.resumes.length} 份',
                  style: TextStyle(color: context.colors.muted, fontSize: 11),
                ),
                const Spacer(),
                Text(
                  '最近更新',
                  style: TextStyle(color: context.colors.muted, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
        if (embedded) const SizedBox(height: 4),
        DataStatus(
          store: store,
          section: 'resumes',
          empty: store.resumes.isEmpty,
          title: embedded ? '这里还没有内容' : '创建你的第一份简历',
          subtitle: embedded ? '下拉刷新，查看最新内容。' : '从一份空白简历开始，逐步整理你的经历。',
        ),
        for (final resume in store.resumes)
          Padding(
            padding: EdgeInsets.fromLTRB(
              embedded ? 20 : 32,
              0,
              embedded ? 20 : 32,
              12,
            ),
            child: _resumeCard(context, resume),
          ),
      ],
    ),
  );
  Widget _actionCard(
    BuildContext context, {
    required String label,
    required AppIconData icon,
    required VoidCallback onTap,
  }) => Material(
    color: context.colors.surface,
    clipBehavior: Clip.antiAlias,
    borderRadius: BorderRadius.circular(18),
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: (context.isDark
                    ? context.colors.accentSoft
                    : const Color(0xFFEEF4FF)),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Center(
                child: AppIcon(icon, size: 20, color: context.colors.accent),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: context.colors.ink,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _resumeCard(BuildContext context, ResumeDraft resume) {
    final progress = resume.progress.clamp(0.0, 1.0);
    final progressColor = progress == 1
        ? const Color(0xFF449581)
        : context.colors.accent;
    return Material(
      color: context.colors.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: context.colors.border),
      ),
      child: InkWell(
        key: ValueKey('resume-card-${resume.id}'),
        onTap: () =>
            openPage(context, ResumePreview(store: store, resumeId: resume.id)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final thumbnailWidth = (constraints.maxWidth * .32).clamp(
                72.0,
                110.0,
              );
              final thumbnailHeight =
                  (thumbnailWidth - 2) / resumePaperSize.aspectRatio + 2;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  SizedBox(
                    width: thumbnailWidth,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(color: context.colors.border),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(1),
                        child: ResumeCardThumbnail(
                          key: ValueKey(
                            'resume-thumbnail-${identityHashCode(store)}-${store.epoch}-${resume.id}-${resume.marketTemplateID}',
                          ),
                          store: store,
                          resume: resume,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: thumbnailHeight),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                resume.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: ResumeEditorTypography.entryTitle
                                    .copyWith(color: context.colors.ink),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                resume.updatedAt == null
                                    ? '尚未记录更新时间'
                                    : '${resumeUpdatedLabel(resume.updatedAt!)} 更新',
                                style: ResumeEditorTypography.caption.copyWith(
                                  color: context.colors.muted,
                                ),
                              ),
                              const SizedBox(height: 6),
                              _resumeDetail(
                                context,
                                AppIcons.work,
                                resume.position.trim().isEmpty
                                    ? '求职岗位待填写'
                                    : resume.position.trim(),
                              ),
                              const SizedBox(height: 6),
                              SizedBox(
                                width: double.infinity,
                                child: Wrap(
                                  alignment: WrapAlignment.spaceBetween,
                                  spacing: 8,
                                  runSpacing: 4,
                                  children: [
                                    Text(
                                      '完善度',
                                      style: ResumeEditorTypography.caption
                                          .copyWith(
                                            color: context.colors.muted,
                                          ),
                                    ),
                                    Text(
                                      '${(progress * 100).round()}%',
                                      style: ResumeEditorTypography.entryTitle
                                          .copyWith(color: progressColor),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 3),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: progress,
                                  minHeight: 4,
                                  color: progressColor,
                                  backgroundColor: context.colors.accentSoft,
                                ),
                              ),
                            ],
                          ),
                          Align(
                            alignment: Alignment.bottomRight,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    '查看简历',
                                    style: ResumeEditorTypography.caption
                                        .copyWith(
                                          color: context.colors.accent,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                AppIcon(
                                  AppIcons.forward,
                                  size: 14,
                                  color: context.colors.accent,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _resumeDetail(BuildContext context, AppIconData icon, String text) =>
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(icon, size: 14, color: context.colors.muted),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: ResumeEditorTypography.caption.copyWith(
                color: context.colors.ink,
              ),
            ),
          ),
        ],
      );

  Future<void> showAddOptions(BuildContext context) async {
    final epoch = store.epoch;
    final source = await showResumeAddSheet(context);
    if (!context.mounted ||
        source == null ||
        !store.isAuthenticated ||
        epoch != store.epoch) {
      return;
    }
    switch (source) {
      case ResumeAddSource.assistance:
        openPage(context, ResumeAssistancePage(store: store));
      case ResumeAddSource.manual:
        _create(context);
      case ResumeAddSource.wechat:
        openPage(
          context,
          ImportResume(store: store, initialSource: ResumeImportSource.wechat),
        );
      case ResumeAddSource.local:
        openPage(
          context,
          ImportResume(store: store, initialSource: ResumeImportSource.local),
        );
    }
  }

  void _create(BuildContext context) {
    if (!store.isAuthenticated) {
      store.endSession();
      return;
    }
    final draft = store.createResume();
    openPage(context, ResumeEditor(store: store, draft: draft));
  }

  void _import(BuildContext context) =>
      openPage(context, ImportResume(store: store));
}

class ResumeEditor extends StatefulWidget {
  const ResumeEditor({
    super.key,
    required this.store,
    required this.draft,
    this.onSaved,
  });
  final AppStore store;
  final ResumeDraft draft;
  final VoidCallback? onSaved;
  @override
  State<ResumeEditor> createState() => _ResumeEditorState();
}

class _ResumeEditorState extends State<ResumeEditor> {
  static const _fieldActionExtent = 48.0;

  final _sectionRevision = ValueNotifier(0);
  int? _editingSection;
  int _sectionSession = 0;
  XFile? _retainedSectionPhoto;

  void _update(VoidCallback change) {
    if (!mounted) return;
    setState(change);
    _sectionRevision.value++;
  }

  Future<void> _discardEditablePhoto(XFile? file) async {
    if (!identical(file, _retainedSectionPhoto)) {
      await discardResumePhotoCrop(file);
    }
  }

  late final int _accountEpoch;
  bool _allowImportLeave = false;
  bool _checkingImportLeave = false;
  bool get _unsavedImport =>
      currentDraft.id == 0 && currentDraft.importID != null;

  Future<void> _saveImportedResume() async {
    if (!_unsavedImport || saving) return;
    if (!await _save() || !mounted) return;
    toast(context, '简历已保存');
    widget.onSaved?.call();
  }

  Future<void> _confirmImportLeave() async {
    if (saving || _checkingImportLeave || !_unsavedImport) return;
    _checkingImportLeave = true;
    final leave = await showAppConfirmation(
      context,
      title: '导入的简历尚未保存',
      content: const Text('可以继续校对并点击底部“保存简历”。若暂时返回，可在“导入简历”的待保存记录中继续校对解析结果。'),
      confirmLabel: '暂不保存，返回',
      cancelLabel: '继续校对',
    );
    _checkingImportLeave = false;
    if (!mounted || leave != true || saving) return;
    setState(() => _allowImportLeave = true);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) Navigator.of(context).pop();
  }

  bool saving = false;
  bool pickingPhoto = false;
  bool _photoActionsOpen = false;
  bool photoRemoved = false;
  String? photoError;
  XFile? selectedPhoto;
  late ResumeDraft currentDraft = widget.draft.copy();
  late List<String> _moduleOrder = resumeModuleOrder(widget.draft.source);
  final _moduleScroll = ScrollController();
  final _moduleDragKeys = <String, GlobalKey>{};
  String? _draggingModule;
  bool _moduleDragMoved = false;
  double _beforeDragOffset = 0;

  Future<Offset?> _prepareModuleDrag(String module) async {
    if (!mounted) return null;
    _beforeDragOffset = _moduleScroll.offset;
    setState(() {
      _draggingModule = module;
      _moduleDragMoved = false;
    });
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || _draggingModule != module) return null;
    final target = _moduleDragKeys[module]?.currentContext;
    if (target == null || !target.mounted) return null;
    await Scrollable.ensureVisible(target, alignment: .4);
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || _draggingModule != module) return null;
    if (!target.mounted) return null;
    final box = target.findRenderObject() as RenderBox?;
    return box != null && box.attached
        ? box.localToGlobal(box.size.center(Offset.zero))
        : null;
  }

  void _finishModuleDrag() {
    if (!mounted || _draggingModule == null) return;
    final module = _draggingModule!;
    final moved = _moduleDragMoved;
    setState(() => _draggingModule = null);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_moduleScroll.hasClients) return;
      if (!moved) {
        _moduleScroll.jumpTo(
          _beforeDragOffset.clamp(0, _moduleScroll.position.maxScrollExtent),
        );
      } else {
        final target = _moduleDragKeys[module]?.currentContext;
        if (target != null) Scrollable.ensureVisible(target, alignment: .1);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _accountEpoch = widget.store.epoch;
    _loadPhoto();
  }

  Future<void> _loadPhoto() async {
    if (currentDraft.id <= 0) return;
    final epoch = widget.store.epoch;
    try {
      final response = await widget.store.request(
        'GetResumesId',
        path: {'id': '${currentDraft.id}'},
      );
      if (!mounted || epoch != widget.store.epoch) return;
      final detail = decodeResume(response.data);
      _update(() {
        currentDraft.photoURL = detail.photoURL;
        currentDraft.photoFileID = detail.photoFileID;
        photoError = null;
      });
    } catch (_) {
      if (mounted) _update(() => photoError = '照片信息加载失败，请重试');
    }
  }

  Future<void> _pickPhoto() async {
    if (saving || pickingPhoto) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final session = _sectionSession;
    final epoch = widget.store.epoch;
    _update(() => pickingPhoto = true);
    bool isCurrent() =>
        mounted && session == _sectionSession && epoch == widget.store.epoch;
    try {
      final file = await pickAppGalleryPhoto();
      if (file == null || !isCurrent()) return;
      await validateResumePhoto(file);
      if (!mounted || !isCurrent()) return;
      final cropped = await Navigator.of(context).push<XFile>(
        MaterialPageRoute(builder: (_) => ResumePhotoCropPage(file: file)),
      );
      if (cropped == null) return;
      if (!isCurrent()) {
        await discardResumePhotoCrop(cropped);
        return;
      }
      final previous = selectedPhoto;
      _update(() {
        selectedPhoto = cropped;
        photoRemoved = false;
        photoError = null;
      });
      await _discardEditablePhoto(previous);
    } catch (e) {
      if (mounted) toast(context, e is ApiFailure ? e.message : '无法选择照片，请重试');
    } finally {
      if (mounted) _update(() => pickingPhoto = false);
    }
  }

  Future<void> _showPhotoActions() async {
    if (saving || pickingPhoto || _photoActionsOpen || _editingSection != 0) {
      return;
    }
    dismissKeyboard();
    final session = _sectionSession;
    final epoch = widget.store.epoch;
    _photoActionsOpen = true;
    final ResumePhotoAction? action;
    try {
      action = await showResumePhotoActions(
        context,
        hasPhoto:
            selectedPhoto != null ||
            (!photoRemoved && currentDraft.photoFileID > 0),
      );
    } finally {
      _photoActionsOpen = false;
    }
    if (!mounted ||
        action == null ||
        session != _sectionSession ||
        epoch != widget.store.epoch ||
        _editingSection != 0) {
      return;
    }
    switch (action) {
      case ResumePhotoAction.modify:
        await _pickPhoto();
      case ResumePhotoAction.delete:
        final previous = selectedPhoto;
        _update(() {
          selectedPhoto = null;
          photoRemoved = true;
          photoError = null;
        });
        await _discardEditablePhoto(previous);
    }
  }

  Widget _photoField({bool compact = false}) {
    final existing = !photoRemoved && currentDraft.photoFileID > 0;
    return Semantics(
      button: true,
      label: compact ? '编辑基本信息' : '编辑照片',
      child: InkWell(
        onTap: saving || pickingPhoto
            ? null
            : compact
            ? () => _openSection(0)
            : _showPhotoActions,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: compact ? 76 : 48,
          height: compact ? 100 : 64,
          foregroundDecoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: context.colors.border),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: selectedPhoto != null
                ? Image.file(
                    File(selectedPhoto!.path),
                    fit: BoxFit.cover,
                    alignment: const Alignment(0, -.35),
                  )
                : existing && currentDraft.photoURL.isNotEmpty
                ? Image(
                    image: ResizeImage(
                      ResumePhotoImage(
                        currentDraft.photoURL,
                        fileID: currentDraft.photoFileID,
                      ),
                      width: 280,
                    ),
                    fit: BoxFit.cover,
                    alignment: const Alignment(0, -.35),
                    errorBuilder: (_, _, _) => TextButton(
                      onPressed: saving
                          ? null
                          : () {
                              ResizeImage(
                                ResumePhotoImage(
                                  currentDraft.photoURL,
                                  fileID: currentDraft.photoFileID,
                                ),
                                width: 280,
                              ).evict();
                              _loadPhoto();
                            },
                      child: const Text(
                        '加载失败\n点击重试',
                        textAlign: TextAlign.center,
                        style: ResumeEditorTypography.caption,
                      ),
                    ),
                  )
                : ColoredBox(
                    color: context.isDark
                        ? context.colors.inset
                        : const Color(0xFFF0F2F4),
                    child: Center(
                      child: AppIcon(
                        AppIcons.portrait,
                        size: 42,
                        color: context.colors.muted.withValues(alpha: .5),
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  late final Map<String, TextEditingController> fields = {
    'title': TextEditingController(text: widget.draft.title),
    'name': TextEditingController(text: widget.draft.name),
    'position': TextEditingController(text: widget.draft.position),
    'city': TextEditingController(text: widget.draft.city),
    'phone': TextEditingController(text: widget.draft.phone),
    'email': TextEditingController(text: widget.draft.email),
    'summary': TextEditingController(text: widget.draft.summary),
    'birth_date': TextEditingController(
      text:
          (widget.draft.source['personal_info'] as Map?)?['birth_date']
              ?.toString() ??
          '',
    ),
    'industry': TextEditingController(
      text:
          (widget.draft.source['job_expectation'] as Map?)?['industry']
              ?.toString() ??
          '',
    ),
    'salary': TextEditingController(
      text:
          (widget.draft.source['job_expectation'] as Map?)?['salary']
              ?.toString() ??
          '',
    ),
  };
  late final List<WorkExperienceFields> workEntries = [
    for (final entry in currentDraft.source['work_experiences'] as List? ?? [])
      if (entry is Map) WorkExperienceFields(Map<String, dynamic>.from(entry)),
    if ((currentDraft.source['work_experiences'] as List? ?? []).isEmpty &&
        currentDraft.experience.trim().isNotEmpty)
      WorkExperienceFields({'description': currentDraft.experience}),
  ];
  int _workIndex = 0;
  int _projectIndex = 0;
  int _educationIndex = 0;
  int _skillIndex = 0;
  int _certificateIndex = 0;
  final Set<WorkExperienceFields> _generatingWork = {};
  final Map<ResumeEntryFields, String> _generatingProject = {};

  late final List<EducationFields> educationEntries = [
    for (final entry in currentDraft.source['educations'] as List? ?? [])
      if (entry is Map) EducationFields(Map<String, dynamic>.from(entry)),
    if ((currentDraft.source['educations'] as List? ?? []).isEmpty &&
        currentDraft.education.trim().isNotEmpty)
      EducationFields({'campus_experience': currentDraft.education}),
  ];
  late String gender = switch ((widget.draft.source['personal_info']
      as Map?)?['gender']) {
    'male' || '男' => 'male',
    'female' || '女' => 'female',
    _ => 'undisclosed',
  };
  late String birthMode =
      (widget.draft.source['personal_info']
              as Map?)?['birth_date_display_mode'] ==
          'age'
      ? 'age'
      : 'date';
  static const additionalSchema = <String, List<(String, String, int)>>{
    'projects': [
      ('name', '项目名称', 1),
      ('role', '担任角色', 1),
      ('url', '项目链接', 1),
      ('start_date', '开始时间', 1),
      ('end_date', '结束时间', 1),
      ('description', '项目描述', 4),
      ('achievements', '项目成果', 3),
    ],
    'skills': [('name', '技能名称', 1), ('description', '技能说明与熟练程度', 3)],
    'certifications': [
      ('name', '证书名称', 1),
      ('issuer', '颁发机构', 1),
      ('date', '颁发时间', 1),
    ],
  };
  ResumeEntryFields _newEntry(String key, Map<String, dynamic> source) =>
      ResumeEntryFields(
        source,
        additionalSchema[key]!.map((field) => field.$1).toList(),
        richKeys: key == 'certifications'
            ? []
            : ['description', if (key == 'projects') 'achievements'],
      );
  late final Map<String, List<ResumeEntryFields>> additionalEntries = {
    for (final key in additionalSchema.keys)
      key: [
        for (final entry in widget.draft.source[key] as List? ?? [])
          if (entry is Map) _newEntry(key, Map<String, dynamic>.from(entry)),
        if (key == 'skills' &&
            (widget.draft.source[key] as List? ?? []).isEmpty &&
            widget.draft.skills.isNotEmpty)
          _newEntry(key, {'description': widget.draft.skills}),
      ],
  };

  @override
  void dispose() {
    _moduleScroll.dispose();
    _sectionRevision.dispose();
    if (!identical(_retainedSectionPhoto, selectedPhoto)) {
      unawaited(discardResumePhotoCrop(_retainedSectionPhoto));
    }
    if (!saving) unawaited(discardResumePhotoCrop(selectedPhoto));
    for (final c in fields.values) {
      c.dispose();
    }
    for (final entry in workEntries) {
      entry.dispose();
    }
    for (final entry in educationEntries) {
      entry.dispose();
    }
    for (final list in additionalEntries.values) {
      for (final entry in list) {
        entry.dispose();
      }
    }
    super.dispose();
  }

  final sectionNames = ['基本信息', ...resumeModules.map((entry) => entry.$2)];

  Future<void> _reorderModules(int from, int to) async {
    if (saving || pickingPhoto || _editingSection != null) return;
    if (from == to || !_moduleDragMoved) return;
    final previous = List<String>.of(_moduleOrder);
    _update(() => _moduleOrder.insert(to, _moduleOrder.removeAt(from)));
    final saved = await _save();
    if (!mounted) return;
    if (!saved) _update(() => _moduleOrder = previous);
    if (saved) widget.onSaved?.call();
  }

  Future<void> _openSection(
    int index, {
    bool showErrors = false,
    int initialWorkIndex = 0,
    int initialProjectIndex = 0,
    int initialEducationIndex = 0,
    int initialAdditionalIndex = 0,
  }) async {
    if (saving || pickingPhoto || _editingSection != null) return;
    dismissKeyboard();
    final originalFields = {
      for (final entry in fields.entries) entry.key: entry.value.text,
    };
    final originalGender = gender;
    final originalBirthMode = birthMode;
    final originalPhoto = selectedPhoto;
    final originalRemoved = photoRemoved;
    final originalPhotoError = photoError;
    final originalWork = [for (final entry in workEntries) entry.toJson()];
    final originalEducation = [
      for (final entry in educationEntries) entry.toJson(),
    ];
    final originalAdditional = {
      for (final entry in additionalEntries.entries)
        entry.key: [for (final row in entry.value) row.toJson()],
    };
    _editingSection = index;
    _sectionSession++;
    if (index == 3) {
      final invalid = workEntries.indexWhere((e) => e.dateRangeError() != null);
      _workIndex = showErrors && invalid >= 0
          ? invalid
          : workEntries.isEmpty
          ? 0
          : initialWorkIndex.clamp(0, workEntries.length - 1);
    }
    if (index == 4) {
      _projectIndex = _projects.isEmpty
          ? 0
          : initialProjectIndex.clamp(0, _projects.length - 1);
    }
    if (index == 5) {
      _educationIndex = educationEntries.isEmpty
          ? 0
          : initialEducationIndex.clamp(0, educationEntries.length - 1);
    }
    if (index == 6 || index == 7) {
      final key = index == 6 ? 'skills' : 'certifications';
      final list = additionalEntries[key]!;
      _setAdditionalIndex(
        key,
        list.isEmpty ? 0 : initialAdditionalIndex.clamp(0, list.length - 1),
      );
    }
    if (index == 0) _retainedSectionPhoto = originalPhoto;
    final route = MaterialPageRoute<bool>(
      builder: (_) => ResumeSectionEditorPage(
        title: sectionNames[index],
        changes: _sectionRevision,
        isBusy: () =>
            saving ||
            pickingPhoto ||
            _generatingWork.isNotEmpty ||
            _generatingProject.isNotEmpty,
        fields: () => _sectionFields(index),
        body: index == 3
            ? _workPager
            : index == 4
            ? _projectPager
            : index == 5
            ? _educationPager
            : index == 6
            ? () => _additionalPager('skills', 'skill', '专业技能')
            : index == 7
            ? () => _additionalPager('certifications', 'certificate', '证书')
            : null,
        validate: index == 3
            ? _validateWorkSection
            : index == 4
            ? _validateProjectSection
            : null,
        onSave: _save,
        onMore: index == 3
            ? _showWorkActions
            : index == 4
            ? _showProjectActions
            : index == 5
            ? _showEducationActions
            : index == 6
            ? (context) =>
                  _showAdditionalActions(context, 'skills', 'skill', '专业技能')
            : index == 7
            ? (context) => _showAdditionalActions(
                context,
                'certifications',
                'certificate',
                '证书',
              )
            : null,
        showErrors: showErrors,
      ),
    );
    final accepted = await Navigator.of(context).push(route);
    await route.completed;
    _sectionSession++;
    if (!mounted) return;
    _generatingWork.clear();
    _generatingProject.clear();
    if (accepted != true) {
      for (final entry in originalFields.entries) {
        fields[entry.key]!.text = entry.value;
      }
      gender = originalGender;
      birthMode = originalBirthMode;
      if (index == 0) {
        if (!identical(selectedPhoto, originalPhoto)) {
          await discardResumePhotoCrop(selectedPhoto);
        }
        selectedPhoto = originalPhoto;
        photoRemoved = originalRemoved;
        photoError = originalPhotoError;
      } else if (index == 3) {
        for (final entry in workEntries) {
          entry.dispose();
        }
        workEntries
          ..clear()
          ..addAll(originalWork.map(WorkExperienceFields.new));
      } else if (index == 5) {
        for (final entry in educationEntries) {
          entry.dispose();
        }
        educationEntries
          ..clear()
          ..addAll(originalEducation.map(EducationFields.new));
      } else if (index == 4 || index == 6 || index == 7) {
        final key = {4: 'projects', 6: 'skills', 7: 'certifications'}[index]!;
        for (final entry in additionalEntries[key]!) {
          entry.dispose();
        }
        additionalEntries[key]!
          ..clear()
          ..addAll(
            originalAdditional[key]!.map((entry) => _newEntry(key, entry)),
          );
      }
    } else if (index == 0 && !identical(originalPhoto, selectedPhoto)) {
      await discardResumePhotoCrop(originalPhoto);
    }
    _retainedSectionPhoto = null;
    _editingSection = null;
    _update(() {});
    if (accepted == true && mounted) {
      toast(context, '简历已保存');
      widget.onSaved?.call();
    }
  }

  List<Widget> _sectionFields(int index) => switch (index) {
    0 => [_basicInformation()],
    1 => [
      _field(
        'position',
        '意向职位',
        hint: '搜索或输入意向职位',
        pickerIcon: AppIcons.search,
        onTap: () =>
            _pickOption(fields['position']!, ResumeOptionKind.position),
      ),
      _field(
        'city',
        '意向城市',
        hint: '搜索或输入意向城市',
        pickerIcon: AppIcons.search,
        onTap: () => _pickOption(fields['city']!, ResumeOptionKind.city),
      ),
      _field(
        'industry',
        '期望行业',
        hint: '搜索或输入期望行业',
        pickerIcon: AppIcons.search,
        onTap: () =>
            _pickOption(fields['industry']!, ResumeOptionKind.industry),
      ),
      _field('salary', '期望薪资'),
    ],
    2 => [
      _field(
        'summary',
        '自我评价与求职偏好',
        lines: 8,
        hint: '具备较强的沟通协调能力、组织执行能力和服务意识，做事严谨细致，注重工作效率与结果。了解企业人力资源管理的基本流程，熟悉招聘辅助、员工入离职手续办理、员工档案管理、考勤统计及日常人事事务处理等工作内容。具有良好的保密意识和责任心，能够妥善处理日常工作中的沟通协调问题，具备较强的团队合作精神。',
      ),
    ],
    3 => [],
    4 => [],
    5 => [],
    _ => [],
  };

  Iterable<TextEditingController> get _allEditorFields sync* {
    yield* fields.values;
    for (final entry in workEntries) {
      yield* entry.fields.values;
    }
    for (final entry in educationEntries) {
      yield* entry.fields.values;
    }
    for (final list in additionalEntries.values) {
      for (final entry in list) {
        yield* entry.fields.values;
      }
    }
  }

  Widget _completionCard() => ListenableBuilder(
    listenable: Listenable.merge(_allEditorFields.toList()),
    builder: (context, _) {
      final progress = resumeEditorProgress(
        fields: fields.map((key, c) => MapEntry(key, c.text)),
        work: workEntries.map((e) => e.toJson()),
        projects: additionalEntries['projects']!.map((e) => e.toJson()),
        education: educationEntries.map((e) => e.toJson()),
        skills: additionalEntries['skills']!.map((e) => e.toJson()),
      );
      return Semantics(
        label: '已填写 ${progress.filled}/${progress.total} 项基础内容',
        child: Container(
          key: const ValueKey('resume-editor-completeness'),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      '简历完整度',
                      style: ResumeEditorTypography.entryTitle,
                    ),
                  ),
                  Text(
                    '${progress.percent}%',
                    key: const ValueKey('resume-editor-completeness-percent'),
                    style: ResumeEditorTypography.body.copyWith(
                      color: context.colors.accent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: progress.fraction,
                  minHeight: 4,
                  color: context.colors.accent,
                  backgroundColor: context.colors.accentSoft,
                ),
              ),
            ],
          ),
        ),
      );
    },
  );

  Widget _basicInformation() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      InkWell(
        key: const ValueKey('resume-photo-entry'),
        onTap: saving || pickingPhoto ? null : _showPhotoActions,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '头像',
                  style: ResumeEditorTypography.caption.copyWith(
                    color: context.colors.muted,
                  ),
                ),
              ),
              _photoField(),
            ],
          ),
        ),
      ),
      if (photoError != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            photoError!,
            style: ResumeEditorTypography.caption.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ),
      Divider(height: 24, color: context.colors.border),
      _field('name', '姓名'),
      _field('phone', '手机号码', keyboard: TextInputType.phone),
      _field('email', '邮箱', keyboard: TextInputType.emailAddress),
      _field('title', '简历名称'),
      ExpansionTile(
        key: const ValueKey('resume-editor-more-personal'),
        maintainState: true,
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(top: 12),
        shape: const Border(),
        collapsedShape: const Border(),
        collapsedTextColor: context.colors.muted,
        textColor: context.colors.ink,
        iconColor: context.colors.muted,
        collapsedIconColor: context.colors.muted,
        title: const Text('更多基本信息', style: ResumeEditorTypography.action),
        children: [_personalFields()],
      ),
    ],
  );

  Widget _overviewText(String text, {bool muted = false}) => Text(
    text,
    style: ResumeEditorTypography.body.copyWith(
      color: muted ? context.colors.muted : context.colors.ink,
    ),
  );

  Widget _basicSummary() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                fields['name']!.text.trim().isEmpty
                    ? '填写姓名'
                    : fields['name']!.text,
                style: ResumeEditorTypography.title.copyWith(
                  color: fields['name']!.text.trim().isEmpty
                      ? context.colors.muted
                      : context.colors.ink,
                ),
              ),
              const SizedBox(height: 12),
              _overviewText(
                fields['phone']!.text.trim().isNotEmpty
                    ? '电话：${fields['phone']!.text.trim()}'
                    : fields['email']!.text.trim().isNotEmpty
                    ? '邮箱：${fields['email']!.text.trim()}'
                    : '添加电话或邮箱',
                muted:
                    fields['phone']!.text.trim().isEmpty &&
                    fields['email']!.text.trim().isEmpty,
              ),
              const SizedBox(height: 8),
              Text(
                '上传真实个人头像，提升获面机会',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ResumeEditorTypography.caption.copyWith(
                  color: context.colors.muted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        _photoField(compact: true),
      ],
    );
  }

  Widget _overviewContent(int index) {
    if (index == 0) return _basicSummary();
    if (index == 1) {
      final position = fields['position']!.text.trim();
      final details = [
        ('city', '意向城市', AppIcons.location),
        ('salary', '期望薪资', null),
        ('industry', '期望行业', AppIcons.industry),
      ].where((item) => fields[item.$1]!.text.trim().isNotEmpty).toList();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ResumeOverviewEntry(
            title: position.isEmpty ? '填写意向职位' : position,
            titleMuted: position.isEmpty,
          ),
          if (details.isNotEmpty) ...[
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) => Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final (key, label, icon) in details)
                    Semantics(
                      label: '$label：${fields[key]!.text.trim()}',
                      excludeSemantics: true,
                      child: Container(
                        key: ValueKey('resume-expectation-$key'),
                        constraints: BoxConstraints(
                          maxWidth: constraints.maxWidth,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: context.colors.inset,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (key == 'salary')
                              SizedBox.square(
                                dimension: 14,
                                child: Center(
                                  child: Text(
                                    '¥',
                                    textScaler: TextScaler.noScaling,
                                    style: TextStyle(
                                      fontSize: 14,
                                      height: 1,
                                      fontWeight: FontWeight.w500,
                                      color: context.colors.muted,
                                    ),
                                  ),
                                ),
                              )
                            else
                              AppIcon(
                                icon!,
                                size: 14,
                                color: context.colors.muted,
                              ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                fields[key]!.text.trim(),
                                style: ResumeEditorTypography.caption.copyWith(
                                  color: context.colors.ink,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      );
    }
    if (index == 2) {
      final summary = fields['summary']!.text.trim();
      return _overviewText(
        summary.isEmpty ? '介绍你的专业方向、经验和优势' : summary,
        muted: summary.isEmpty,
      );
    }
    final List<Map<String, dynamic>> entries;
    final String titleKey;
    final List<String> metaKeys;
    final List<String> descriptionKeys;
    switch (index) {
      case 3:
        entries = workEntries.map((e) => e.toJson()).toList();
        titleKey = 'company';
        metaKeys = ['position'];
        descriptionKeys = ['description'];
      case 5:
        entries = educationEntries.map((e) => e.toJson()).toList();
        titleKey = 'institution';
        metaKeys = ['degree', 'field_of_study'];
        descriptionKeys = [
          'campus_experience',
          'thesis_title',
          'thesis_description',
        ];
      default:
        final key = {4: 'projects', 6: 'skills', 7: 'certifications'}[index]!;
        entries = additionalEntries[key]!.map((e) => e.toJson()).toList();
        titleKey = 'name';
        metaKeys = index == 4 ? ['role'] : ['issuer'];
        descriptionKeys = ['description', 'achievements'];
    }
    if (entries.isEmpty) {
      return _overviewText('添加${sectionNames[index]}', muted: true);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < entries.length; i++) ...[
          if (i > 0) Divider(height: 24, color: context.colors.border),
          ResumeOverviewEntry(
            key: index == 3
                ? ValueKey('resume-overview-work-$i')
                : index == 4
                ? ValueKey('resume-overview-project-$i')
                : index == 5
                ? ValueKey('resume-overview-education-$i')
                : index == 6
                ? ValueKey('resume-overview-skill-$i')
                : index == 7
                ? ValueKey('resume-overview-certificate-$i')
                : null,
            onTap: index == 3 && !saving
                ? () => _openSection(3, initialWorkIndex: i)
                : index == 4 && !saving
                ? () => _openSection(4, initialProjectIndex: i)
                : index == 5 && !saving
                ? () => _openSection(5, initialEducationIndex: i)
                : (index == 6 || index == 7) && !saving
                ? () => _openSection(index, initialAdditionalIndex: i)
                : null,
            title: entries[i][titleKey]?.toString().trim() ?? '',
            meta: [
              for (final key in metaKeys)
                entries[i][key]?.toString().trim() ?? '',
              [
                formatResumeMonth(entries[i]['start_date']),
                entries[i]['current'] == true
                    ? '至今'
                    : formatResumeMonth(entries[i]['end_date']),
              ].where((v) => v.isNotEmpty).join(' ~ '),
              formatResumeMonth(entries[i]['date']),
            ].where((v) => v.isNotEmpty).toList(),
            description: [
              for (final key in descriptionKeys)
                entries[i][key]?.toString().trim() ?? '',
            ].where((v) => v.isNotEmpty).join('\n'),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving && (!_unsavedImport || _allowImportLeave),
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) unawaited(_confirmImportLeave());
    },
    child: Scaffold(
      backgroundColor: context.colors.canvas,
      appBar: AppPageBar(
        title: ValueListenableBuilder<TextEditingValue>(
          valueListenable: fields['title']!,
          builder: (context, value, _) => Text(
            value.text.trim().isEmpty ? '未命名简历' : value.text.trim(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
      bottomNavigationBar: _unsavedImport
          ? Material(
              color: context.colors.surface,
              child: SafeArea(
                top: false,
                minimum: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: FilledButton(
                  key: const ValueKey('resume-import-save'),
                  onPressed: saving || pickingPhoto
                      ? null
                      : _saveImportedResume,
                  child: Text(saving ? '保存中…' : '保存简历'),
                ),
              ),
            )
          : null,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const [0, .45, 1],
            colors: context.isDark
                ? [
                    context.colors.canvas,
                    context.colors.canvas,
                    context.colors.canvas,
                  ]
                : [
                    const Color(0xFFE8F3FF),
                    context.colors.canvas,
                    context.colors.canvas,
                  ],
          ),
        ),
        child: ReorderableListView.builder(
          key: const ValueKey('resume-modules'),
          scrollController: _moduleScroll,
          scrollCacheExtent: _draggingModule == null
              ? null
              : const ScrollCacheExtent.pixels(10000),
          buildDefaultDragHandles: false,
          padding: EdgeInsets.fromLTRB(
            8,
            12,
            8,
            12 + MediaQuery.paddingOf(context).bottom,
          ),
          header: Column(
            children: [
              _completionCard(),
              ResumeOverviewCard(
                key: const ValueKey('resume-overview-section-0'),
                label: '编辑基本信息',
                onEdit: saving ? null : () => _openSection(0),
                child: _basicSummary(),
              ),
            ],
          ),
          itemCount: _moduleOrder.length,
          onReorderItem: _reorderModules,
          proxyDecorator: (child, index, animation) => ResumeModuleDragProxy(
            onFinished: _finishModuleDrag,
            child: child,
          ),
          itemBuilder: (context, position) {
            final module = _moduleOrder[position];
            final index =
                resumeModules.indexWhere((entry) => entry.$1 == module) + 1;
            return ResumeModuleDragListener(
              key: ValueKey('resume-module-$module'),
              index: position,
              prepare: () => _prepareModuleDrag(module),
              onMove: () => _moduleDragMoved = true,
              onCancel: _finishModuleDrag,
              enabled:
                  !saving &&
                  !pickingPhoto &&
                  _generatingWork.isEmpty &&
                  _generatingProject.isEmpty &&
                  _draggingModule == null,
              child: Semantics(
                key: _moduleDragKeys.putIfAbsent(module, () => GlobalKey()),
                hint: '长按拖动调整模块顺序',
                child: ResumeOverviewCard(
                  key: ValueKey('resume-overview-section-$index'),
                  label: '编辑${sectionNames[index]}',
                  title: sectionNames[index],
                  draggable: true,
                  compact: _draggingModule != null,
                  onEdit: saving ? null : () => _openSection(index),
                  child: _overviewContent(index),
                ),
              ),
            );
          },
        ),
      ),
    ),
  );

  Widget _fieldTrailingIcon(AppIconData icon) => SizedBox.square(
    dimension: _fieldActionExtent,
    child: Center(child: AppIcon(icon, size: 18, color: context.colors.muted)),
  );

  Widget _choiceField(
    String label,
    String value,
    Map<String, String> options,
    ValueChanged<String> onChanged,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: ResumeEditorTypography.caption.copyWith(
            color: context.colors.muted,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: value,
          isExpanded: true,
          icon: _fieldTrailingIcon(AppIcons.expand),
          iconSize: 18,
          decoration: InputDecoration(
            filled: false,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 8),
            border: UnderlineInputBorder(
              borderSide: BorderSide(color: context.colors.border),
            ),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: context.colors.border),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: context.colors.accent),
            ),
          ),
          style: ResumeEditorTypography.body.copyWith(
            color: context.colors.ink,
          ),
          items: [
            for (final option in options.entries)
              DropdownMenuItem(value: option.key, child: Text(option.value)),
          ],
          onChanged: saving
              ? null
              : (selected) {
                  if (selected != null) onChanged(selected);
                },
        ),
      ],
    ),
  );

  Widget _personalFields() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _choiceField('性别', gender, const {
        'undisclosed': '不透露',
        'male': '男',
        'female': '女',
      }, (value) => _update(() => gender = value)),
      _field(
        'birth_date',
        '出生日期',
        hint: '例如：1996-08-15',
        onTap: _pickBirthDate,
      ),
      _choiceField('简历中显示', birthMode, const {
        'date': '出生日期',
        'age': '年龄',
      }, (value) => _update(() => birthMode = value)),
    ],
  );

  Future<void> _pickBirthDate() async {
    if (saving) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final now = DateTime.now();
    final parsed = DateTime.tryParse(
      fields['birth_date']!.text.replaceAll('.', '-').replaceAll('/', '-'),
    );
    final first = DateTime(1900);
    final initial =
        parsed != null && !parsed.isBefore(first) && !parsed.isAfter(now)
        ? parsed
        : DateTime(now.year - 25, 1, 1);
    final selected = await showDateWheelPicker(
      context,
      title: '选择出生日期',
      initialDate: initial,
      firstDate: first,
      lastDate: now,
    );
    if (!mounted || selected == null) return;
    _update(
      () => fields['birth_date']!.text =
          '${selected.year}-${selected.month.toString().padLeft(2, '0')}-${selected.day.toString().padLeft(2, '0')}',
    );
  }

  List<ResumeEntryFields> get _projects => additionalEntries['projects']!;

  String? _projectDateError(ResumeEntryFields entry) {
    final startText = entry.fields['start_date']!.text.trim();
    final endText = entry.fields['end_date']!.text.trim();
    if (startText.isEmpty || endText.isEmpty) return null;
    final start = parseWorkDate(startText);
    final end = parseWorkDate(endText);
    if (start == null || end == null) return '请选择有效的起止日期';
    return end.isAfter(start) ? null : '结束时间必须晚于开始时间';
  }

  bool _validateProjectSection() {
    final invalid = _projects.indexWhere((e) => _projectDateError(e) != null);
    if (invalid < 0) return true;
    dismissKeyboard();
    _update(() => _projectIndex = invalid);
    return false;
  }

  Widget _projectPager() => ResumeEntryPager(
    entryKind: 'project',
    entryLabel: '项目经历',
    count: _projects.length,
    index: _projectIndex,
    onChanged: (index) => _update(() => _projectIndex = index),
    itemKey: (index) => ObjectKey(_projects[index]),
    itemBuilder: _projectEntry,
    emptyState: const EmptyState('还没有项目经历', '通过右上角“更多”添加项目经历', compact: true),
  );

  Future<void> _showProjectActions(BuildContext context) =>
      _showAdditionalActions(context, 'projects', 'project', '项目经历');

  int _additionalIndex(String key) => switch (key) {
    'projects' => _projectIndex,
    'skills' => _skillIndex,
    _ => _certificateIndex,
  };

  void _setAdditionalIndex(String key, int index) {
    switch (key) {
      case 'projects':
        _projectIndex = index;
      case 'skills':
        _skillIndex = index;
      case 'certifications':
        _certificateIndex = index;
    }
  }

  Future<void> _showAdditionalActions(
    BuildContext sectionContext,
    String key,
    String kind,
    String label,
  ) async {
    if (saving || _entryActionsOpen) return;
    dismissKeyboard();
    final session = _sectionSession;
    final list = additionalEntries[key]!;
    final entry = list.isEmpty ? null : list[_additionalIndex(key)];
    _entryActionsOpen = true;
    String? action;
    try {
      action = await showAppActionSheet(
        sectionContext,
        builder: (_) => ResumeEntryActionsSheet(
          canDelete: entry != null,
          entryKind: kind,
          entryLabel: label,
        ),
      );
    } finally {
      _entryActionsOpen = false;
    }
    if (!mounted || session != _sectionSession || saving) return;
    if (action == 'add') {
      _update(() {
        list.add(_newEntry(key, {}));
        _setAdditionalIndex(key, list.length - 1);
      });
    } else if (action == 'delete' && entry != null && list.contains(entry)) {
      await _removeAdditional(key, entry, label);
    }
  }

  Widget _projectEntry(int index) {
    final entry = _projects[index];
    Widget input(String key, String label, {int lines = 1, String? hint}) =>
        _field(
          'projects-$index-$key',
          label,
          controller: entry.fields[key],
          lines: lines,
          hint: hint,
          alignInput: lines == 1,
          keyboard: key == 'url' ? TextInputType.url : null,
        );
    return Container(
      key: ObjectKey(entry),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          input('name', '项目名称'),
          _pair(input('role', '担任角色'), input('url', '项目链接'), compact: true),
          _pair(
            _field(
              'projects-$index-start_date',
              '开始时间',
              controller: entry.fields['start_date'],
              alignInput: true,
              onTap: () => _pickExperienceDate(entry.fields, end: false),
            ),
            _field(
              'projects-$index-end_date',
              '结束时间',
              controller: entry.fields['end_date'],
              alignInput: true,
              onTap: () => _pickExperienceDate(entry.fields, end: true),
              validator: (_) => _projectDateError(entry),
            ),
            compact: true,
          ),
          _projectGeneratedField(
            entry,
            index,
            'description',
            '项目描述',
            4,
            '填写项目背景、业务定位与建设目标',
          ),
          _projectGeneratedField(
            entry,
            index,
            'achievements',
            '项目成果',
            3,
            '填写项目取得的实际成果',
          ),
        ],
      ),
    );
  }

  Map<String, String> _projectGenerationInput(
    ResumeEntryFields entry,
    String field,
  ) => {
    'project_name': entry.fields['name']!.text.trim(),
    'role': entry.fields['role']!.text.trim(),
    if (field == 'achievements')
      'description': entry.fields['description']!.text.trim(),
  };

  Widget _projectGeneratedField(
    ResumeEntryFields entry,
    int index,
    String field,
    String label,
    int lines,
    String hint,
  ) => _field(
    'projects-$index-$field',
    label,
    controller: entry.fields[field],
    lines: lines,
    hint: hint,
    labelAction: ListenableBuilder(
      listenable: Listenable.merge([
        entry.fields['name']!,
        entry.fields['role']!,
        if (field == 'achievements') entry.fields['description']!,
      ]),
      builder: (context, _) {
        final ready = _projectGenerationInput(
          entry,
          field,
        ).values.every((value) => value.isNotEmpty);
        final pending = _generatingProject[entry] == field;
        return TextButton(
          key: ValueKey('projects-$index-$field-ai-generate'),
          onPressed: !ready || saving || _generatingProject.containsKey(entry)
              ? null
              : () => _generateProjectText(entry, field),
          style: TextButton.styleFrom(
            foregroundColor: context.colors.accent,
            backgroundColor: context.colors.accentSoft,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            minimumSize: const Size(0, 32),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(
            pending ? '生成中…' : 'AI生成',
            style: ResumeEditorTypography.caption.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      },
    ),
  );

  Future<void> _generateProjectText(
    ResumeEntryFields entry,
    String field,
  ) async {
    if (saving || _generatingProject.containsKey(entry)) return;
    final input = _projectGenerationInput(entry, field);
    if (input.values.any((value) => value.isEmpty)) return;
    dismissKeyboard();
    final session = _sectionSession;
    final epoch = widget.store.epoch;
    final previous = entry.fields[field]!.text;
    bool isCurrent() =>
        mounted &&
        session == _sectionSession &&
        epoch == widget.store.epoch &&
        _projects.contains(entry);
    _update(() => _generatingProject[entry] = field);
    try {
      final result = await widget.store.request(
        field == 'description'
            ? 'PostResumeProjectDescriptions'
            : 'PostResumeProjectAchievements',
        body: input,
      );
      if (!mounted || !isCurrent()) return;
      final currentInput = _projectGenerationInput(entry, field);
      if (entry.fields[field]!.text != previous ||
          input.entries.any((item) => currentInput[item.key] != item.value)) {
        toast(context, '内容已修改，未覆盖当前输入，请重新生成');
        return;
      }
      final text = result.data[field];
      if (text is! String || text.trim().isEmpty) {
        throw const ApiFailure('未获取到生成内容，请重试');
      }
      _update(() => entry.fields[field]!.text = text.trim());
    } catch (error) {
      if (mounted && isCurrent()) {
        toast(context, error is ApiFailure ? error.message : '生成失败，请稍后重试');
      }
    } finally {
      if (mounted) _update(() => _generatingProject.remove(entry));
    }
  }

  Widget _additionalPager(String key, String kind, String label) {
    final list = additionalEntries[key]!;
    return ResumeEntryPager(
      entryKind: kind,
      entryLabel: label,
      count: list.length,
      index: _additionalIndex(key),
      onChanged: (index) => _update(() => _setAdditionalIndex(key, index)),
      itemKey: (index) => ObjectKey(list[index]),
      itemBuilder: (index) => _additionalEntry(key, index),
      emptyState: EmptyState('还没有$label', '通过右上角“更多”添加$label', compact: true),
    );
  }

  Widget _additionalEntry(String key, int index) {
    final entry = additionalEntries[key]![index];
    Widget input(String field, String label, {int lines = 1}) => _field(
      key == 'skills' && index == 0 && field == 'description'
          ? 'skills'
          : '$key-$index-$field',
      label,
      controller: entry.fields[field],
      lines: lines,
      alignInput: lines == 1,
    );
    return Container(
      key: ObjectKey(entry),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: key == 'skills'
            ? [
                input('name', '技能名称'),
                input('description', '技能说明与熟练程度', lines: 3),
              ]
            : [
                input('name', '证书名称'),
                _pair(
                  input('issuer', '颁发机构'),
                  input('date', '颁发时间'),
                  compact: true,
                ),
              ],
      ),
    );
  }

  Future<void> _removeAdditional(
    String key,
    ResumeEntryFields entry,
    String title,
  ) async {
    final confirmed = await showAppConfirmation(
      context,
      title: '删除这项$title？',
      content: const Text('保存本页后生效。'),
      confirmLabel: '删除',
      destructive: true,
    );
    if (!mounted || confirmed != true) return;
    FocusManager.instance.primaryFocus?.unfocus();
    _update(() {
      additionalEntries[key]!.remove(entry);
      final list = additionalEntries[key]!;
      _setAdditionalIndex(
        key,
        list.isEmpty ? 0 : _additionalIndex(key).clamp(0, list.length - 1),
      );
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => entry.dispose());
  }

  Widget _pair(Widget first, Widget second, {bool compact = false}) =>
      LayoutBuilder(
        builder: (context, constraints) =>
            constraints.maxWidth >=
                (compact
                    ? 280 * MediaQuery.textScalerOf(context).scale(14) / 14
                    : 500)
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: first),
                  const SizedBox(width: 16),
                  Expanded(child: second),
                ],
              )
            : Column(children: [first, second]),
      );

  Future<void> _pickOption(
    TextEditingController controller,
    ResumeOptionKind kind,
  ) async {
    if (saving || pickingPhoto) return;
    final session = _sectionSession;
    final value = await showResumeOptionPicker(
      context,
      store: widget.store,
      initialValue: controller.text,
      kind: kind,
    );
    if (!mounted || session != _sectionSession || value == null) return;
    _update(() => controller.text = value);
  }

  Widget _field(
    String key,
    String label, {
    int lines = 1,
    TextInputType? keyboard,
    String? hint,
    int? hintMaxLines,
    TextEditingController? controller,
    bool enabled = true,
    VoidCallback? onTap,
    AppIconData? pickerIcon,
    bool alignInput = false,
    Widget? labelAction,
    String? Function(String?)? validator,
  }) {
    final dateField =
        key == 'birth_date' || key.endsWith('-date') || key.endsWith('_date');
    final fieldController = controller ?? fields[key];
    final pick =
        onTap ?? (dateField ? () => _pickMonth(fieldController!, label) : null);
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: ResumeEditorTypography.caption.copyWith(
                      color: context.colors.muted,
                    ),
                  ),
                ),
                if (labelAction != null) ...[
                  const SizedBox(width: 12),
                  labelAction,
                ],
              ],
            ),
          ),
          TextFormField(
            key: ValueKey('resume-$key'),
            validator: validator,
            controller: fieldController,
            enabled: enabled && !saving,
            readOnly: pick != null,
            textAlignVertical: alignInput ? TextAlignVertical.center : null,
            onTap: pick,
            minLines: lines,
            maxLines: lines == 1 ? 1 : null,
            keyboardType: keyboard,
            textInputAction: lines == 1
                ? TextInputAction.next
                : TextInputAction.newline,
            style: ResumeEditorTypography.body.copyWith(
              color: context.colors.ink,
            ),
            decoration: InputDecoration(
              constraints: alignInput
                  ? const BoxConstraints(minHeight: _fieldActionExtent)
                  : null,
              hintMaxLines: hintMaxLines,
              hintText: dateField && enabled
                  ? (alignInput ? '选择日期' : '请选择$label')
                  : hint,
              suffixIcon: pick == null
                  ? (alignInput
                        ? const SizedBox(width: 0, height: _fieldActionExtent)
                        : null)
                  : ValueListenableBuilder<TextEditingValue>(
                      valueListenable: fieldController!,
                      builder: (_, value, _) => value.text.isEmpty
                          ? _fieldTrailingIcon(pickerIcon ?? AppIcons.date)
                          : IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints.tightFor(
                                width: _fieldActionExtent,
                                height: _fieldActionExtent,
                              ),
                              tooltip: '清除$label',
                              onPressed: saving || !enabled
                                  ? null
                                  : () {
                                      dismissKeyboard();
                                      fieldController.clear();
                                    },
                              icon: AppIcon(
                                AppIcons.close,
                                size: 18,
                                color: context.colors.muted,
                              ),
                            ),
                    ),
              suffixIconConstraints: BoxConstraints.tightFor(
                width: alignInput && pick == null ? 0 : _fieldActionExtent,
                height: _fieldActionExtent,
              ),
              hintStyle: ResumeEditorTypography.body.copyWith(
                color: context.colors.muted,
              ),
              errorMaxLines: 3,
              errorStyle: ResumeEditorTypography.caption.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
              filled: false,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              border: UnderlineInputBorder(
                borderSide: BorderSide(color: context.colors.border),
              ),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: context.colors.border),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: context.colors.accent),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickMonth(
    TextEditingController controller,
    String label,
  ) async {
    if (saving) return;
    final session = _sectionSession;
    final now = DateTime.now();
    final parts = controller.text.split(RegExp(r'[-./]'));
    final year = parts.isNotEmpty ? int.tryParse(parts[0]) : null;
    final month = parts.length > 1 ? int.tryParse(parts[1]) : null;
    final selected = await showDateWheelPicker(
      context,
      title: '选择$label',
      initialDate:
          year != null && (month == null || (month >= 1 && month <= 12))
          ? DateTime(year, month ?? 1)
          : DateTime(now.year, now.month),
      firstDate: DateTime(1900),
      lastDate: DateTime(now.year + 20, 12),
      monthOnly: true,
    );
    if (!mounted || session != _sectionSession) return;
    if (selected != null) {
      controller.text =
          '${selected.year}-${selected.month.toString().padLeft(2, '0')}';
    }
  }

  Future<void> _pickWorkDate(WorkExperienceFields entry, {required bool end}) =>
      _pickExperienceDate(entry.fields, end: end);

  Future<void> _pickExperienceDate(
    Map<String, TextEditingController> dateFields, {
    required bool end,
  }) async {
    if (saving) return;
    final session = _sectionSession;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final key = end ? 'end_date' : 'start_date';
    final selected = await showDateWheelPicker(
      context,
      title: end ? '选择结束时间' : '选择开始时间',
      initialDate: parseWorkDate(dateFields[key]!.text, today: today) ?? today,
      firstDate: DateTime(1900),
      lastDate: DateTime(now.year + 20, 12, 31),
    );
    if (!mounted || session != _sectionSession || selected == null) return;
    final day = DateTime(selected.year, selected.month, selected.day);
    final other = parseWorkDate(
      dateFields[end ? 'start_date' : 'end_date']!.text,
    );
    if (other != null && (end ? !day.isAfter(other) : !other.isAfter(day))) {
      toast(context, '结束时间必须晚于开始时间');
      return;
    }
    final currentNow = DateTime.now();
    final currentToday = DateTime(
      currentNow.year,
      currentNow.month,
      currentNow.day,
    );
    _update(
      () => dateFields[key]!.text = end && day == currentToday
          ? '至今'
          : '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}',
    );
  }

  Future<void> _removeWork(WorkExperienceFields entry) async {
    final confirmed = await showAppConfirmation(
      context,
      title: '删除这段工作经历？',
      content: const Text('保存本页后生效。'),
      confirmLabel: '删除',
      destructive: true,
    );
    if (!mounted || confirmed != true) return;
    FocusManager.instance.primaryFocus?.unfocus();
    _update(() {
      workEntries.remove(entry);
      _workIndex = workEntries.isEmpty
          ? 0
          : _workIndex.clamp(0, workEntries.length - 1);
    });
    // The keyed form fields must unmount before their controllers are disposed.
    WidgetsBinding.instance.addPostFrameCallback((_) => entry.dispose());
  }

  bool _validateWorkSection() {
    final invalid = workEntries.indexWhere((e) => e.dateRangeError() != null);
    if (invalid < 0) return true;
    dismissKeyboard();
    _update(() => _workIndex = invalid);
    return false;
  }

  Widget _workPager() => ResumeEntryPager(
    count: workEntries.length,
    index: _workIndex,
    onChanged: (index) => _update(() => _workIndex = index),
    itemKey: (index) => ObjectKey(workEntries[index]),
    itemBuilder: (index) => _workEntry(index),
    emptyState: const EmptyState('还没有工作经历', '通过右上角“更多”添加工作经历', compact: true),
  );

  bool _entryActionsOpen = false;

  Map<String, String> _workGenerationInput(WorkExperienceFields entry) => {
    'company_name': entry.fields['company']!.text.trim(),
    'job_title': entry.fields['position']!.text.trim(),
    'industry': entry.fields['industry']!.text.trim(),
    'start_date': entry.fields['start_date']!.text.trim(),
    'end_date': entry.fields['end_date']!.text.trim(),
  };

  Future<void> _generateWorkDescription(WorkExperienceFields entry) async {
    if (saving || _generatingWork.contains(entry)) return;
    final input = _workGenerationInput(entry);
    if (input['job_title']!.isEmpty) {
      toast(context, '请先填写职位');
      return;
    }
    dismissKeyboard();
    final session = _sectionSession;
    final epoch = widget.store.epoch;
    final previous = entry.fields['description']!.text;
    bool isCurrent() =>
        mounted &&
        session == _sectionSession &&
        epoch == widget.store.epoch &&
        workEntries.contains(entry);
    _update(() => _generatingWork.add(entry));
    try {
      final result = await widget.store.request(
        'PostResumeWorkDescriptions',
        body: input,
      );
      if (!mounted || !isCurrent()) return;
      final currentInput = _workGenerationInput(entry);
      if (entry.fields['description']!.text != previous ||
          input.entries.any((item) => currentInput[item.key] != item.value)) {
        toast(context, '内容已修改，未覆盖当前输入，请重新生成');
        return;
      }
      final text = result.data['description'];
      if (text is! String || text.trim().isEmpty) {
        throw const ApiFailure('未获取到生成内容，请重试');
      }
      _update(() => entry.fields['description']!.text = text.trim());
    } catch (error) {
      if (mounted && isCurrent()) {
        toast(context, error is ApiFailure ? error.message : '生成失败，请稍后重试');
      }
    } finally {
      if (mounted) _update(() => _generatingWork.remove(entry));
    }
  }

  Future<void> _showWorkActions(BuildContext sectionContext) async {
    if (saving || _entryActionsOpen) return;
    dismissKeyboard();
    final session = _sectionSession;
    final entry = workEntries.isEmpty ? null : workEntries[_workIndex];
    _entryActionsOpen = true;
    String? action;
    try {
      action = await showAppActionSheet(
        sectionContext,
        builder: (_) => ResumeEntryActionsSheet(canDelete: entry != null),
      );
    } finally {
      _entryActionsOpen = false;
    }
    if (!mounted || session != _sectionSession || saving) return;
    if (action == 'add') {
      _update(() {
        workEntries.add(WorkExperienceFields({}));
        _workIndex = workEntries.length - 1;
      });
    } else if (action == 'delete' &&
        entry != null &&
        workEntries.contains(entry)) {
      await _removeWork(entry);
    }
  }

  Widget _workEntry(int index) {
    final entry = workEntries[index];
    Widget input(
      String key,
      String label, {
      int lines = 1,
      String? hint,
      bool enabled = true,
    }) => _field(
      'work-$index-$key',
      label,
      controller: entry.fields[key],
      lines: lines,
      hint: hint,
      enabled: enabled,
      alignInput: lines == 1,
    );
    return Container(
      key: ObjectKey(entry),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          input('company', '公司名称'),
          _pair(
            _field(
              'work-$index-position',
              '职位',
              controller: entry.fields['position'],
              alignInput: true,
              hint: '选择职位',
              pickerIcon: AppIcons.search,
              onTap: () => _pickOption(
                entry.fields['position']!,
                ResumeOptionKind.position,
              ),
            ),
            _field(
              'work-$index-industry',
              '所属行业',
              controller: entry.fields['industry'],
              alignInput: true,
              hint: '选择行业',
              pickerIcon: AppIcons.search,
              onTap: () => _pickOption(
                entry.fields['industry']!,
                ResumeOptionKind.industry,
              ),
            ),
            compact: true,
          ),
          _pair(
            _field(
              'work-$index-start_date',
              '开始时间',
              controller: entry.fields['start_date'],
              alignInput: true,
              onTap: () => _pickWorkDate(entry, end: false),
            ),
            _field(
              'work-$index-end_date',
              '结束时间',
              controller: entry.fields['end_date'],
              alignInput: true,
              onTap: () => _pickWorkDate(entry, end: true),
              validator: (_) => entry.dateRangeError(),
            ),
            compact: true,
          ),
          _field(
            'work-$index-description',
            '工作内容与成果',
            controller: entry.fields['description'],
            lines: 4,
            hint: '填写这一段经历的职责与成果',
            labelAction: TextButton(
              key: ValueKey('work-$index-ai-generate'),
              onPressed: saving || _generatingWork.contains(entry)
                  ? null
                  : () => _generateWorkDescription(entry),
              style: TextButton.styleFrom(
                foregroundColor: context.colors.accent,
                backgroundColor: context.colors.accentSoft,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                _generatingWork.contains(entry) ? '生成中…' : 'AI生成',
                style: ResumeEditorTypography.caption.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _educationPager() => ResumeEntryPager(
    entryKind: 'education',
    entryLabel: '教育经历',
    count: educationEntries.length,
    index: _educationIndex,
    onChanged: (index) => _update(() => _educationIndex = index),
    itemKey: (index) => ObjectKey(educationEntries[index]),
    itemBuilder: _educationEntry,
    emptyState: const EmptyState('还没有教育经历', '通过右上角“更多”添加教育经历', compact: true),
  );

  Future<void> _showEducationActions(BuildContext sectionContext) async {
    if (saving || _entryActionsOpen) return;
    dismissKeyboard();
    final session = _sectionSession;
    final entry = educationEntries.isEmpty
        ? null
        : educationEntries[_educationIndex];
    _entryActionsOpen = true;
    String? action;
    try {
      action = await showAppActionSheet(
        sectionContext,
        builder: (_) => ResumeEntryActionsSheet(
          canDelete: entry != null,
          entryKind: 'education',
          entryLabel: '教育经历',
        ),
      );
    } finally {
      _entryActionsOpen = false;
    }
    if (!mounted || session != _sectionSession || saving) return;
    if (action == 'add') {
      _update(() {
        educationEntries.add(EducationFields({}));
        _educationIndex = educationEntries.length - 1;
      });
    } else if (action == 'delete' &&
        entry != null &&
        educationEntries.contains(entry)) {
      await _removeEducation(entry);
    }
  }

  Future<void> _removeEducation(EducationFields entry) async {
    final confirmed = await showAppConfirmation(
      context,
      title: '删除这段教育经历？',
      content: const Text('保存本页后生效。'),
      confirmLabel: '删除',
      destructive: true,
    );
    if (!mounted || confirmed != true) return;
    FocusManager.instance.primaryFocus?.unfocus();
    _update(() {
      educationEntries.remove(entry);
      _educationIndex = educationEntries.isEmpty
          ? 0
          : _educationIndex.clamp(0, educationEntries.length - 1);
    });
    // The keyed form fields must unmount before their controllers are disposed.
    WidgetsBinding.instance.addPostFrameCallback((_) => entry.dispose());
  }

  Widget _educationEntry(int index) {
    final entry = educationEntries[index];
    Widget input(
      String key,
      String label, {
      int lines = 1,
      String? hint,
      int? hintMaxLines,
      bool enabled = true,
    }) => _field(
      'education-$index-$key',
      label,
      controller: entry.fields[key],
      lines: lines,
      hint: hint,
      hintMaxLines: hintMaxLines,
      enabled: enabled,
      alignInput: lines == 1,
    );
    return Container(
      key: ObjectKey(entry),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          input('institution', '学校名称'),
          _pair(
            input('field_of_study', '专业'),
            input('degree', '学历'),
            compact: true,
          ),
          _pair(
            input('start_date', '入学时间', hint: '例如：2019-09'),
            input('end_date', '毕业时间', hint: '例如：2023-06'),
            compact: true,
          ),
          input(
            'campus_experience',
            '在校经历',
            lines: 4,
            hint:
                'GPA：3.6 / 4.0（专业前 15%）\n'
                '主修课程：组织行为学、招聘与人才测评、薪酬与绩效管理、\n'
                '培训与开发、劳动法与劳动关系、人力资源管理概论\n'
                '荣誉奖项：校级一等奖学金（2024）、"挑战杯"创业计划赛上海市三等奖（2023）\n'
                '语言能力：CET-6（580）、英语流利，可作工作语言',
          ),
          input(
            'thesis_title',
            '毕业论文题目（选填）',
            hint: '《中小企业员工绩效考核体系优化研究》',
            hintMaxLines: 3,
          ),
          input(
            'thesis_description',
            '毕业论文内容（选填）',
            lines: 3,
            hint: '以中小企业人力资源管理为研究对象，围绕员工绩效考核体系展开研究，结合绩效管理相关理论，分析企业在绩效指标设置、考核流程、考核公平性及绩效结果应用等方面存在的问题，并提出优化绩效考核指标、完善绩效反馈机制、建立绩效激励制度等改进建议，以提升企业绩效管理水平和员工工作积极性。',
          ),
        ],
      ),
    );
  }

  Future<bool> _save() async {
    if (widget.store.epoch != _accountEpoch) {
      toast(context, '账号已切换，请返回后重新进入');
      return false;
    }
    if (_projects.any((entry) => _projectDateError(entry) != null)) {
      toast(context, '请先修正项目经历的起止日期');
      return false;
    }
    if (saving ||
        pickingPhoto ||
        _generatingWork.isNotEmpty ||
        _generatingProject.isNotEmpty) {
      return false;
    }
    if (workEntries.any((entry) => entry.dateRangeError() != null)) {
      toast(context, '请先修正工作经历：结束时间必须晚于开始时间');
      return false;
    }
    final draft = currentDraft.copy();
    draft.source[resumeModuleOrderKey] = List<String>.of(_moduleOrder);
    draft.title = fields['title']!.text.trim();
    if (draft.title.isEmpty) draft.title = '未命名简历';
    draft.name = fields['name']!.text.trim();
    draft.position = fields['position']!.text.trim();
    draft.city = fields['city']!.text.trim();
    draft.phone = fields['phone']!.text.trim();
    draft.email = fields['email']!.text.trim();
    draft.summary = fields['summary']!.text.trim();
    draft.source['work_experiences'] = workEntries
        .map((entry) => entry.toJson())
        .toList();
    draft.experience = decodeResume({'content': draft.source}).experience;
    draft.source['educations'] = educationEntries
        .map((entry) => entry.toJson())
        .toList();
    draft.education = decodeResume({'content': draft.source}).education;
    draft.source['personal_info'] = {
      ...?draft.source['personal_info'] as Map<String, dynamic>?,
      'birth_date': fields['birth_date']!.text.trim(),
      'birth_date_display_mode': birthMode,
      'gender': gender,
    };
    draft.source['job_expectation'] = {
      ...?draft.source['job_expectation'] as Map<String, dynamic>?,
      'industry': fields['industry']!.text.trim(),
      'salary': fields['salary']!.text.trim(),
    };
    for (final entry in additionalEntries.entries) {
      draft.source[entry.key] = entry.value.map((row) => row.toJson()).toList();
    }
    draft.skills = decodeResume({'content': draft.source}).skills;
    draft.progress = resumeDraftProgress(draft).fraction;
    _update(() => saving = true);
    final saved = await runRequest(context, () async {
      currentDraft = await widget.store.updateResume(draft);
      if (selectedPhoto != null) {
        currentDraft = await uploadResumePhoto(
          widget.store,
          currentDraft,
          selectedPhoto!,
        );
        await discardResumePhotoCrop(selectedPhoto);
        selectedPhoto = null;
      } else if (photoRemoved) {
        await widget.store.request(
          'DeleteResumesIdPhoto',
          path: {'id': '${currentDraft.id}'},
        );
        final detail = await widget.store.request(
          'GetResumesId',
          path: {'id': '${currentDraft.id}'},
        );
        currentDraft = decodeResume(detail.data);
        photoRemoved = false;
        await widget.store.load('resumes');
      }
    });
    if (!mounted) {
      await discardResumePhotoCrop(selectedPhoto);
      return false;
    }
    _update(() => saving = false);
    return saved;
  }
}

class ResumePreview extends StatefulWidget {
  const ResumePreview({super.key, required this.store, required this.resumeId});
  final AppStore store;
  final int resumeId;
  @override
  State<ResumePreview> createState() => _ResumePreviewState();
}

class _ResumePreviewState extends State<ResumePreview> {
  late final ResumePreviewTrace previewTrace;
  @override
  void initState() {
    super.initState();
    previewTrace = ResumePreviewTrace(widget.resumeId);
  }

  @override
  void dispose() {
    previewTrace.dispose();
    super.dispose();
  }

  final documentKey = GlobalKey<ResumeDocumentViewState>();
  final marketDocumentKey = GlobalKey<ResumeMarketDocumentViewState>();
  AppStore get store => widget.store;
  int get resumeId => widget.resumeId;

  bool openingActions = false;
  bool copying = false;
  bool monochrome = false;
  Future<void> showActions() async {
    if (openingActions) return;
    openingActions = true;
    final epoch = store.epoch;
    try {
      final current = store.resumes.where((r) => r.id == resumeId).firstOrNull;
      if (current == null) return;
      final action = await showAppActionSheet(
        context,
        builder: (_) =>
            ResumeActionsSheet(title: current.title, monochrome: monochrome),
      );
      if (!mounted ||
          action == null ||
          store.epoch != epoch ||
          !store.isAuthenticated) {
        return;
      }
      final resume = store.resumes.where((r) => r.id == resumeId).firstOrNull;
      if (resume == null) return;
      if (action == 'share-to-user') {
        openPage(context, ResumeUserShare(store: store, resume: resume));
      } else if (action == 'share-post') {
        openPage(context, ResumePostComposer(store: store, resume: resume));
      } else if (action == 'monochrome-preview') {
        setState(() => monochrome = !monochrome);
      } else if (action == 'request-help') {
        await showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (_) => ResumeLinkShare(store: store, resume: resume),
        );
      } else if (action == 'rename') {
        await showResumeRenameDialog(context, store: store, resume: resume);
      } else if (action == 'ai-optimize') {
        await openPage(
          context,
          ResumeAIOptimizationPage(store: store, resume: resume),
        );
      } else if (action == 'download') {
        export(resume);
      } else if (action == 'delete') {
        await confirmResumeDeletion(context, store: store, resume: resume);
        if (mounted &&
            store.epoch == epoch &&
            !store.resumes.any((r) => r.id == resumeId) &&
            ModalRoute.of(context)?.isCurrent == true) {
          await Navigator.maybePop(context);
        }
      }
    } finally {
      openingActions = false;
    }
  }

  bool switchingResume = false;

  Future<void> switchResume() async {
    if (switchingResume || !store.isAuthenticated) return;
    switchingResume = true;
    final epoch = store.epoch;
    try {
      final selected = await showModalBottomSheet<int>(
        context: context,
        useRootNavigator: true,
        useSafeArea: true,
        isScrollControlled: true,
        showDragHandle: false,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black.withValues(alpha: .4),
        builder: (_) => _ResumeSwitchSheet(store: store, currentId: resumeId),
      );
      if (!mounted ||
          selected == null ||
          selected == resumeId ||
          store.epoch != epoch ||
          !store.isAuthenticated ||
          !store.resumes.any((r) => r.id == selected)) {
        return;
      }
      if (ModalRoute.of(context)?.isCurrent != true) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => ResumePreview(store: store, resumeId: selected),
        ),
      );
    } finally {
      switchingResume = false;
    }
  }

  Future<void> createCopy(ResumeDraft resume) async {
    if (copying || !store.isAuthenticated) return;
    final epoch = store.epoch;
    setState(() => copying = true);
    toast(context, '正在创建副本…');
    try {
      final copied = await store.copyResume(resume.id);
      if (!mounted ||
          store.epoch != epoch ||
          ModalRoute.of(context)?.isCurrent != true) {
        return;
      }
      toast(context, '副本已创建，原简历已保留');
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => ResumePreview(store: store, resumeId: copied.id),
        ),
      );
    } catch (error) {
      if (mounted && store.epoch == epoch) {
        await showRequestFailure(context, error);
      }
    } finally {
      if (mounted) setState(() => copying = false);
    }
  }

  String documentIdentity(ResumeDraft resume) =>
      '${resume.id}:${resume.revision}:${resume.marketTemplateID}';

  void chooseTemplate(ResumeDraft resume) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: false,
    clipBehavior: Clip.antiAlias,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) =>
        ResumeTemplatePicker(store: store, resume: resume, heightFactor: .6),
  );

  void export(ResumeDraft resume) => showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    isScrollControlled: true,
    showDragHandle: false,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: .4),
    builder: (_) => ResumeExportSheet(
      store: store,
      resume: resume,
      captureLayout: ({required isCancelled, required onProgress}) async {
        final current = store.resumes
            .where((r) => r.id == resumeId)
            .firstOrNull;
        if (current == null ||
            documentIdentity(current) != documentIdentity(resume)) {
          throw const ApiFailure('简历已更新，请重新下载');
        }
        if (resume.usesMarketTemplate) {
          final view = marketDocumentKey.currentState;
          if (view == null) throw const ApiFailure('请等待预览加载完成');
          return view.captureLayout(
            isCancelled: isCancelled,
            onProgress: onProgress,
          );
        }
        final view = documentKey.currentState;
        if (view == null) throw const ApiFailure('请等待预览加载完成');
        return view.captureLayout(
          isCancelled: isCancelled,
          onProgress: onProgress,
        );
      },
    ),
  );

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (context, _) {
      final matches = store.resumes.where((r) => r.id == resumeId);
      if (matches.isEmpty) {
        return Scaffold(
          appBar: _toolbar(context),
          body: const EmptyState('简历暂不可用', '请返回列表刷新后重试。'),
        );
      }
      final resume = matches.first;
      return RouteTransitionSnapshot(
        child: Scaffold(
          appBar: _toolbar(context, resume: resume),
          body: resume.usesMarketTemplate
              ? ResumeMarketDocumentView(
                  key: marketDocumentKey,
                  store: store,
                  resume: resume,
                  monochrome: monochrome,
                )
              : ResumePreviewColor(
                  monochrome: monochrome,
                  child: ResumeDocumentView(
                    key: documentKey,
                    resume: resume,
                    store: store,
                  ),
                ),
          bottomNavigationBar: ResumePreviewTools(
            onEdit: () =>
                openPage(context, ResumeEditor(store: store, draft: resume)),
            onTemplate: () => chooseTemplate(resume),
            onSwitchResume: switchResume,
            onCopy: copying ? null : () => createCopy(resume),
          ),
        ),
      );
    },
  );

  PreferredSizeWidget _toolbar(BuildContext context, {ResumeDraft? resume}) =>
      AppPageBar(
        title: Text(
          resume?.title ?? '简历预览',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          ResumePreviewActions(
            onMore: resume == null || copying ? null : showActions,
            onClose: () => Navigator.maybePop(context),
          ),
        ],
      );
}

class _ResumeSwitchSheet extends StatelessWidget {
  const _ResumeSwitchSheet({required this.store, required this.currentId});
  final AppStore store;
  final int currentId;

  @override
  Widget build(BuildContext context) => Material(
    key: const ValueKey('resume-switch-sheet'),
    color: context.colors.inset,
    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
    clipBehavior: Clip.antiAlias,
    child: SafeArea(
      top: false,
      child: SizedBox(
        height: (MediaQuery.sizeOf(context).height * .4).clamp(260, 360),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            children: [
              Row(
                children: [
                  const SizedBox(width: 48),
                  const Expanded(
                    child: Text(
                      '切换简历',
                      textAlign: TextAlign.center,
                      style: ResumeEditorTypography.title,
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('resume-switch-close'),
                    tooltip: '关闭',
                    constraints: const BoxConstraints.tightFor(
                      width: 48,
                      height: 48,
                    ),
                    onPressed: () => Navigator.pop(context),
                    icon: const AppIcon(AppIcons.close, size: 22),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: AnimatedBuilder(
                  animation: store,
                  builder: (context, _) => SingleChildScrollView(
                    child: Material(
                      color: context.colors.surface,
                      borderRadius: BorderRadius.circular(12),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (var i = 0; i < store.resumes.length; i++) ...[
                            if (i > 0)
                              Divider(
                                height: 1,
                                indent: 54,
                                endIndent: 16,
                                color: context.colors.border,
                              ),
                            resumeRow(context, store.resumes[i]),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget resumeRow(BuildContext context, ResumeDraft resume) {
    final selected = resume.id == currentId;
    return ListTile(
      key: ValueKey('resume-switch-${resume.id}'),
      selected: selected,
      selectedColor: context.colors.ink,
      selectedTileColor: context.colors.accentSoft,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      minLeadingWidth: 22,
      horizontalTitleGap: 16,
      leading: AppIcon(AppIcons.resume, size: 22, color: context.colors.ink),
      title: Text(
        resume.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: ResumeEditorTypography.action,
      ),
      subtitle: Text(
        selected
            ? '当前简历'
            : resume.updatedAt == null
            ? '尚未记录更新时间'
            : '${resumeUpdatedLabel(resume.updatedAt!)} 更新',
        style: ResumeEditorTypography.caption.copyWith(
          color: context.colors.muted,
        ),
      ),
      trailing: AppIcon(
        selected ? AppIcons.confirm : AppIcons.forward,
        size: 18,
        color: selected ? context.colors.accent : context.colors.muted,
      ),
      onTap: () => Navigator.pop(context, resume.id),
    );
  }
}

class TemplateMarket extends StatelessWidget {
  const TemplateMarket({super.key, required this.store});
  final AppStore store;
  @override
  Widget build(BuildContext context) => TemplateMarketView(
    store: store,
    onUseTemplate: (context, template) {
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => _MarketResumeChooser(
          store: store,
          template: template,
          onSelected: (resume) {
            openPage(context, ResumePreview(store: store, resumeId: resume.id));
          },
          onCreate: () {
            openPage(
              context,
              ResumeEditor(
                store: store,
                draft: ResumeDraft(
                  id: 0,
                  title: '我的简历',
                  marketTemplateID: integer(template['id']),
                  source: {
                    'app_layout': 'market',
                    'app_template_name': template['name'],
                  },
                ),
              ),
            );
          },
        ),
      );
    },
  );
}

class _MarketResumeChooser extends StatefulWidget {
  const _MarketResumeChooser({
    required this.store,
    required this.template,
    required this.onSelected,
    required this.onCreate,
  });
  final AppStore store;
  final Map<String, dynamic> template;
  final ValueChanged<ResumeDraft> onSelected;
  final VoidCallback onCreate;
  @override
  State<_MarketResumeChooser> createState() => _MarketResumeChooserState();
}

class _MarketResumeChooserState extends State<_MarketResumeChooser> {
  bool loading = true, busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => loading = true);
    await widget.store.load('resumes');
    if (mounted) {
      setState(() {
        loading = false;
        error = widget.store.errors['resumes'];
      });
    }
  }

  Future<void> use(ResumeDraft resume) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.store.changeResumeMarketTemplate(
        resume.id,
        integer(widget.template['id']),
      );
      if (!mounted) return;
      final matching = widget.store.resumes.where((row) => row.id == resume.id);
      if (matching.isEmpty) throw const ApiFailure('简历暂不可用，请刷新');
      final updated = matching.first;
      Navigator.pop(context);
      widget.onSelected(updated);
    } catch (e) {
      if (mounted) {
        setState(() => error = e is ApiFailure ? e.message : '模板应用失败，请重试');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * .65,
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '选择要使用的简历',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                error!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
            ),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      if (widget.store.errors.containsKey('resumes'))
                        TextButton(onPressed: load, child: const Text('重新加载'))
                      else
                        for (final resume in widget.store.resumes)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              resume.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              resume.templateTitle,
                              style: TextStyle(
                                fontSize: 12,
                                color: context.colors.muted,
                              ),
                            ),
                            trailing: busy
                                ? null
                                : const AppIcon(AppIcons.forward, size: 18),
                            onTap: busy ? null : () => use(resume),
                          ),
                      if (!widget.store.errors.containsKey('resumes') &&
                          widget.store.resumes.isEmpty)
                        const EmptyState(
                          '你还没有简历',
                          '可以用这套模板创建一份。',
                          compact: true,
                        ),
                    ],
                  ),
          ),
          if (busy)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: busy || loading
                    ? null
                    : () {
                        Navigator.pop(context);
                        widget.onCreate();
                      },
                child: const Text('创建新简历'),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

enum ResumeImportSource { wechat, local }

class ImportResume extends StatefulWidget {
  const ImportResume({
    super.key,
    required this.store,
    this.initialFile,
    this.initialSource,
    this.pickFile,
    this.importer,
    this.onSaved,
  });
  final AppStore store;
  final XFile? initialFile;
  final ResumeImportSource? initialSource;
  final Future<XFile?> Function()? pickFile;
  final ResumeImporter? importer;
  final VoidCallback? onSaved;
  @override
  State<ImportResume> createState() => _ImportResumeState();
}

class _ImportResumeState extends State<ImportResume> {
  late final int accountEpoch;
  List<Map<String, dynamic>> pendingImports = [];
  String? pendingError;
  bool loadingPending = false;
  bool _sourceOpened = false;

  Future<void> loadPending() async {
    if (loadingPending) return;
    setState(() {
      loadingPending = true;
      pendingError = null;
    });
    try {
      final result = await widget.store.request(
        'GetResumeImportsPending',
        expectedEpoch: accountEpoch,
      );
      if (!mounted || widget.store.epoch != accountEpoch) return;
      setState(() => pendingImports = items(result.data));
    } catch (e) {
      if (mounted && widget.store.epoch == accountEpoch) {
        setState(() => pendingError = '$e');
      }
    } finally {
      if (mounted) setState(() => loadingPending = false);
    }
  }

  void openReview(ResumeDraft draft) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ResumeEditor(
          store: widget.store,
          draft: draft,
          onSaved: widget.onSaved,
        ),
      ),
    );
  }

  Future<void> resumePending(int id) async {
    if (busy || picking || widget.store.epoch != accountEpoch) return;
    final token = ++operation;
    setState(() {
      busy = true;
      stage = '正在恢复解析结果…';
      phase = ResumeImportPhase.ready;
      error = null;
    });
    try {
      final draft =
          await (widget.importer ?? ResumeImporter(store: widget.store))
              .resumeImport(id);
      if (!mounted ||
          token != operation ||
          widget.store.epoch != accountEpoch) {
        return;
      }
      openReview(draft);
    } catch (e) {
      if (mounted && token == operation) setState(() => error = '$e');
    } finally {
      if (mounted && token == operation) {
        setState(() {
          busy = false;
          stage = null;
        });
      }
    }
  }

  final files = ResumeFiles.instance;
  XFile? selected;
  bool picking = false;
  bool busy = false;
  int operation = 0;
  String? stage, error;
  ResumeImportPhase phase = ResumeImportPhase.reading;

  @override
  void initState() {
    super.initState();
    accountEpoch = widget.store.epoch;
    selected = widget.initialFile;
    files.activeImports++;
    files.incoming.addListener(receiveShared);
    if (selected != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && operation == 0) upload();
      });
    }
    if (selected == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await loadPending();
        if (!mounted ||
            operation != 0 ||
            selected != null ||
            pendingImports.isNotEmpty ||
            _sourceOpened) {
          return;
        }
        switch (widget.initialSource) {
          case ResumeImportSource.wechat:
            fromWeChat();
          case ResumeImportSource.local:
            chooseLocal();
          case null:
            break;
        }
      });
    }
  }

  void receiveShared() {
    final file = files.incoming.value;
    if (file == null) return;
    files.incoming.value = null;
    if (selected?.path == file.path) return;
    operation++;
    setState(() {
      selected = file;
      busy = false;
      stage = null;
      error = null;
    });
    upload();
  }

  Future<void> chooseLocal() async {
    if (picking || busy) return;
    _sourceOpened = true;
    setState(() {
      picking = true;
      error = null;
    });
    try {
      final file = await (widget.pickFile ?? files.pickLocal)();
      if (mounted && file != null) setState(() => selected = file);
    } catch (_) {
      if (mounted) setState(() => error = '无法读取文件，请重新选择');
    } finally {
      if (mounted) setState(() => picking = false);
    }
  }

  void cancel() {
    operation++;
    setState(() {
      busy = false;
      stage = null;
    });
  }

  Future<void> upload() async {
    final file = selected;
    if (file == null || busy || picking) return;
    final token = ++operation;
    setState(() {
      busy = true;
      stage = '正在读取文件…';
      phase = ResumeImportPhase.reading;
      error = null;
    });
    try {
      final draft =
          await (widget.importer ?? ResumeImporter(store: widget.store))
              .importFile(
                file,
                isCancelled: () => !mounted || token != operation,
                onPhase: (value) {
                  if (mounted && token == operation) {
                    setState(() => phase = value);
                  }
                },
                onProgress: (text) {
                  if (mounted && token == operation) {
                    setState(() => stage = text);
                  }
                },
              );
      if (!mounted || token != operation) return;
      toast(context, '文件已解析，请检查内容后保存');
      openReview(draft);
    } on ImportCancelled {
      // Leaving or cancelling the page must not continue creating an import.
    } catch (e) {
      if (mounted && token == operation) setState(() => error = '$e');
    } finally {
      if (mounted && token == operation) {
        setState(() {
          busy = false;
          stage = null;
        });
      }
    }
  }

  Future<void> fromWeChat() {
    _sourceOpened = true;
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '从微信文件上传',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 14),
              Text(
                Platform.isAndroid
                    ? '在微信打开简历文件 → 点击右上角“…” → 用其他应用打开 → 选择“博简”。返回后会自动上传并解析，无需再次选择文件。'
                    : '先将微信中的简历保存到“文件”，再选择已保存的文件上传。',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.7,
                  color: context.colors.muted,
                ),
              ),
              const SizedBox(height: 22),
              if (Platform.isAndroid) ...[
                FilledButton(
                  onPressed: () async {
                    try {
                      await files.openWeChat();
                      if (sheetContext.mounted) Navigator.pop(sheetContext);
                    } catch (_) {
                      if (mounted) toast(context, '无法打开微信，请确认已安装微信');
                    }
                  },
                  child: const Text('前往微信'),
                ),
                const SizedBox(height: 8),
              ],
              TextButton(
                onPressed: () {
                  Navigator.pop(sheetContext);
                  chooseLocal();
                },
                child: const Text('选择已保存的微信文件'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget source(
    String title,
    String subtitle,
    AppIconData icon,
    Color color,
    VoidCallback onTap,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Panel(
      padding: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: AppIcon(icon, color: color, size: 28),
        title: Text(
          title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text(
            subtitle,
            style: TextStyle(fontSize: 12, color: context.colors.muted),
          ),
        ),
        trailing: AppIcon(
          AppIcons.forward,
          size: 16,
          color: context.colors.muted,
        ),
        onTap: busy || picking ? null : onTap,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppPageBar(title: const Text('导入简历')),
    body: ListView(
      padding: const EdgeInsets.all(22),
      children: [
        Text(
          busy ? '正在导入简历' : '选择简历文件',
          style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Text(
          '支持 PDF、DOC、DOCX，文件不超过 20 MB。',
          style: TextStyle(
            fontSize: 13,
            color: context.colors.muted,
            height: 1.7,
          ),
        ),
        const SizedBox(height: 24),
        if (!busy && pendingImports.isNotEmpty) ...[
          const Text(
            '待保存的导入简历',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text('之前解析的内容还在，可继续校对并保存。'),
          const SizedBox(height: 12),
          for (final record in pendingImports)
            source(
              '${record['name'] ?? '导入的简历'}',
              '继续校对并保存',
              AppIcons.edit,
              context.colors.accent,
              () => resumePending(integer(record['id'])),
            ),
          const SizedBox(height: 16),
        ],
        if (!busy && pendingError != null)
          TextButton(
            onPressed: loadingPending ? null : loadPending,
            child: const Text('待保存记录加载失败，点击重试'),
          ),
        if (!busy)
          source(
            '从微信文件上传',
            '导入聊天中收到的简历',
            AppIcons.wechat,
            const Color(0xFF509B87),
            fromWeChat,
          ),
        if (!busy)
          source(
            '从本机文件上传',
            '选择手机或文件应用中的简历',
            AppIcons.folder,
            blue,
            chooseLocal,
          ),
        if (picking)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
        if (selected != null) ...[
          const SizedBox(height: 12),
          Panel(
            child: Row(
              children: [
                AppIcon(
                  AppIcons.attachment,
                  color: context.colors.accent,
                  size: 30,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        selected!.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 5),
                      FutureBuilder<int>(
                        future: selected!.length(),
                        builder: (context, snapshot) => Text(
                          snapshot.hasData
                              ? '${(snapshot.data! / 1024 / 1024).toStringAsFixed(2)} MB'
                              : '已选择文件',
                          style: TextStyle(
                            fontSize: 12,
                            color: context.colors.muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            key: const ValueKey('resume-upload'),
            onPressed: busy || picking ? null : upload,
            child: Text(busy ? stage ?? '正在处理…' : '上传并解析'),
          ),
          if (busy) ...[
            const SizedBox(height: 16),
            Panel(
              key: const ValueKey('resume-import-progress'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const LinearProgressIndicator(),
                  const SizedBox(height: 12),
                  Semantics(liveRegion: true, child: Text(stage ?? '正在处理…')),
                  const SizedBox(height: 12),
                  for (final step in ResumeImportPhase.values)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Icon(
                            step.index < phase.index
                                ? Icons.check_circle
                                : step == phase
                                ? Icons.pending
                                : Icons.radio_button_unchecked,
                            size: 18,
                            color: step.index <= phase.index
                                ? context.colors.accent
                                : context.colors.muted,
                          ),
                          const SizedBox(width: 8),
                          Text(switch (step) {
                            ResumeImportPhase.reading => '读取文件',
                            ResumeImportPhase.uploading => '上传文件',
                            ResumeImportPhase.parsing => 'AI 识别与整理',
                            ResumeImportPhase.ready => '进入内容校对',
                          }),
                        ],
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    '解析时间取决于文件大小和内容复杂度，请稍候。',
                    style: TextStyle(fontSize: 12, color: context.colors.muted),
                  ),
                ],
              ),
            ),
            TextButton(onPressed: cancel, child: const Text('取消导入')),
          ],
        ],
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(
              error!,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
      ],
    ),
  );

  @override
  void dispose() {
    operation++;
    files.activeImports--;
    files.incoming.removeListener(receiveShared);
    super.dispose();
  }
}
