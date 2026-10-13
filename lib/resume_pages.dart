import 'playful_refresh.dart';
import 'app_icons.dart';
import 'date_wheel_picker.dart';

import 'package:flutter/material.dart';

import 'dart:io';

import 'package:file_selector/file_selector.dart';

import 'resume_files.dart';
import 'resume_rename.dart';
import 'resume_delete.dart';
import 'resume_document.dart';
import 'resume_importer.dart';
import 'resume_photo.dart';
import 'resume_photo_crop.dart';
import 'resume_export.dart';
import 'resume_work_experience.dart';
import 'resume_education.dart';
import 'resume_additional_fields.dart';
import 'resume_templates.dart';
import 'resume_updated_label.dart';
import 'resume_market_document.dart';
import 'template_market.dart';
import 'resume_template_picker.dart';
import 'resume_guidance_share.dart';

import 'dart:async';

import 'api/bojian_api.dart';

import 'app_store.dart';
import 'design.dart';

class ResumeLibrary extends StatelessWidget {
  const ResumeLibrary({super.key, required this.store});
  final AppStore store;
  @override
  Widget build(BuildContext context) => PlayfulRefresh(
    hasError: () => store.errors['resumes'] != null,
    onRefresh: () => store.load('resumes'),
    child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 24),
      children: [
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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              Expanded(
                child: _actionCard(
                  label: '创建简历',
                  icon: AppIcons.add,
                  onTap: () => _create(context),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _actionCard(
                  label: '导入简历',
                  icon: AppIcons.importResume,
                  onTap: () => _import(context),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 18),
          child: InkWell(
            onTap: () => openPage(context, TemplateMarket(store: store)),
            borderRadius: BorderRadius.circular(18),
            child: const Panel(
              padding: EdgeInsets.all(14),
              child: Row(
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: Color(0xFFFFF4E5),
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
                          style: TextStyle(fontSize: 11, color: muted),
                        ),
                      ],
                    ),
                  ),
                  AppIcon(AppIcons.forward, color: muted, size: 14),
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
                style: const TextStyle(color: muted, fontSize: 11),
              ),
              const Spacer(),
              const Text('最近更新', style: TextStyle(color: muted, fontSize: 11)),
            ],
          ),
        ),
        DataStatus(
          store: store,
          section: 'resumes',
          empty: store.resumes.isEmpty,
          title: '创建你的第一份简历',
          subtitle: '从一份空白简历开始，逐步整理你的经历。',
        ),
        for (final resume in store.resumes)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
            child: _resumeCard(context, resume),
          ),
      ],
    ),
  );
  Widget _actionCard({
    required String label,
    required AppIconData icon,
    required VoidCallback onTap,
  }) => Material(
    color: Colors.white,
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
                color: const Color(0xFFEEF4FF),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Center(child: AppIcon(icon, size: 20, color: blue)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: ink,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _resumeCard(BuildContext context, ResumeDraft resume) {
    final layout = ResumeLayout.resolve(resume.template);
    final progress = resume.progress.clamp(0.0, 1.0);
    final progressColor = progress == 1 ? const Color(0xFF449581) : blue;
    return Material(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFE8EDF5)),
      ),
      child: InkWell(
        onTap: () =>
            openPage(context, ResumePreview(store: store, resumeId: resume.id)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ResumeInlineName(
                          key: ValueKey('resume-rename-${resume.id}'),
                          store: store,
                          resume: resume,
                        ),
                        if (resume.updatedAt case final DateTime updated) ...[
                          const SizedBox(height: 0),
                          Text(
                            '${resumeUpdatedLabel(updated)} 更新',
                            style: const TextStyle(
                              color: muted,
                              fontSize: 10.5,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  GestureDetector(
                    key: ValueKey('resume-arrow-${resume.id}'),
                    behavior: HitTestBehavior.opaque,
                    excludeFromSemantics: true,
                    onTap: () {},
                    child: const AppIcon(
                      AppIcons.forward,
                      color: ink,
                      size: 20,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => showModalBottomSheet<void>(
                          context: context,
                          isScrollControlled: true,
                          showDragHandle: false,
                          builder: (_) => ResumeTemplatePicker(
                            store: store,
                            resume: resume,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: muted,
                          minimumSize: const Size(0, 40),
                          padding: const EdgeInsets.symmetric(horizontal: 0),
                          textStyle: const TextStyle(fontSize: 11),
                        ),
                        icon: AppIcon(
                          AppIcons.templates,
                          size: 14,
                          color: layout.accent,
                        ),
                        label: Text('${resume.templateTitle} · 切换模板'),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(
                    '完善度 ${(progress * 100).round()}%',
                    style: const TextStyle(fontSize: 10, color: muted),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 3,
                        color: progressColor,
                        backgroundColor: const Color(0xFFEDF1F7),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Divider(height: 1, color: Color(0xFFEDF1F7)),
              const SizedBox(height: 2),
              Row(
                children: [
                  Expanded(
                    child: MenuAnchor(
                      style: MenuStyle(
                        backgroundColor: const WidgetStatePropertyAll(
                          Colors.white,
                        ),
                        surfaceTintColor: const WidgetStatePropertyAll(
                          Colors.transparent,
                        ),
                        elevation: const WidgetStatePropertyAll(4),
                        shape: WidgetStatePropertyAll(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        padding: const WidgetStatePropertyAll(
                          EdgeInsets.all(6),
                        ),
                      ),
                      menuChildren: [
                        MenuItemButton(
                          key: ValueKey('resume-guidance-${resume.id}'),
                          leadingIcon: const AppIcon(
                            AppIcons.guidanceRecipients,
                            size: 17,
                            color: blue,
                          ),
                          onPressed: () => openPage(
                            context,
                            ResumeGuidanceShare(store: store, resume: resume),
                          ),
                          child: const Text('请求优化'),
                        ),
                        MenuItemButton(
                          key: ValueKey('resume-ai-optimize-${resume.id}'),
                          leadingIcon: const AppIcon(
                            AppIcons.skills,
                            size: 17,
                            color: blue,
                          ),
                          onPressed: () => toast(context, 'AI简历优化即将上线'),
                          child: const Text('AI简历优化'),
                        ),
                      ],
                      builder: (context, controller, _) => _resumeAction(
                        '简历优化',
                        () => controller.isOpen
                            ? controller.close()
                            : controller.open(),
                        icon: AppIcons.guidanceRecipients,
                        dropdown: true,
                        key: ValueKey('resume-optimize-${resume.id}'),
                      ),
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 18,
                    color: const Color(0xFFE8EDF5),
                  ),
                  Expanded(
                    child: _resumeAction(
                      '删除',
                      () => confirmResumeDeletion(
                        context,
                        store: store,
                        resume: resume,
                      ),
                      icon: AppIcons.delete,
                      color: muted,
                      key: ValueKey('resume-delete-${resume.id}'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _resumeAction(
    String label,
    VoidCallback onTap, {
    Key? key,
    required AppIconData icon,
    Color color = blue,
    bool dropdown = false,
  }) => TextButton(
    key: key,
    onPressed: onTap,
    style: TextButton.styleFrom(
      minimumSize: const Size(0, 44),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      foregroundColor: color,
      overlayColor: Colors.transparent,
      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AppIcon(icon, size: 17, color: color),
        const SizedBox(width: 6),
        Flexible(child: Text(label, textAlign: TextAlign.center)),
        if (dropdown) ...[
          const SizedBox(width: 3),
          Icon(Icons.keyboard_arrow_down_rounded, size: 17, color: color),
        ],
      ],
    ),
  );

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
  const ResumeEditor({super.key, required this.store, required this.draft});
  final AppStore store;
  final ResumeDraft draft;
  @override
  State<ResumeEditor> createState() => _ResumeEditorState();
}

class _ResumeEditorState extends State<ResumeEditor> {
  final formKey = GlobalKey<FormState>();
  bool saving = false;
  bool pickingPhoto = false;
  bool photoRemoved = false;
  String? photoError;
  XFile? selectedPhoto;
  late ResumeDraft currentDraft = widget.draft.copy();

  @override
  void initState() {
    super.initState();
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
      setState(() {
        currentDraft.photoURL = detail.photoURL;
        currentDraft.photoFileID = detail.photoFileID;
        photoError = null;
      });
    } catch (_) {
      if (mounted) setState(() => photoError = '照片信息加载失败，请重试');
    }
  }

  Future<void> _pickPhoto() async {
    if (saving || pickingPhoto) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => pickingPhoto = true);
    try {
      final file = await openFile(acceptedTypeGroups: [resumePhotoTypes]);
      if (file == null) return;
      await validateResumePhoto(file);
      if (!mounted) return;
      final cropped = await Navigator.of(context).push<XFile>(
        MaterialPageRoute(builder: (_) => ResumePhotoCropPage(file: file)),
      );
      if (cropped == null) return;
      if (!mounted) {
        await discardResumePhotoCrop(cropped);
        return;
      }
      final previous = selectedPhoto;
      setState(() {
        selectedPhoto = cropped;
        photoRemoved = false;
        photoError = null;
      });
      await discardResumePhotoCrop(previous);
    } catch (e) {
      if (mounted) toast(context, e is ApiFailure ? e.message : '无法选择照片，请重试');
    } finally {
      if (mounted) setState(() => pickingPhoto = false);
    }
  }

  Widget _photoField() {
    final existing = !photoRemoved && currentDraft.photoFileID > 0;
    final hasPhoto = selectedPhoto != null || existing;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              width: 70,
              height: 84,
              child: selectedPhoto != null
                  ? Image.file(
                      File(selectedPhoto!.path),
                      fit: BoxFit.cover,
                      alignment: const Alignment(0, -0.35),
                    )
                  : existing && currentDraft.photoURL.isNotEmpty
                  ? Image.network(
                      currentDraft.photoURL,
                      fit: BoxFit.cover,
                      alignment: const Alignment(0, -0.35),
                      errorBuilder: (_, _, _) => TextButton(
                        onPressed: saving
                            ? null
                            : () {
                                NetworkImage(currentDraft.photoURL).evict();
                                _loadPhoto();
                              },
                        child: const Text(
                          '加载失败\n点击重试',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 10),
                        ),
                      ),
                    )
                  : const ColoredBox(
                      color: Color(0xFFF0F3F9),
                      child: Center(
                        child: AppIcon(
                          AppIcons.portrait,
                          color: muted,
                          size: 30,
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '简历头像',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 5),
                const Text(
                  '最大 5 MB',
                  style: TextStyle(color: muted, fontSize: 10),
                ),
                if (selectedPhoto != null || photoRemoved)
                  const Text(
                    '保存后生效',
                    style: TextStyle(color: blue, fontSize: 10),
                  ),
                Wrap(
                  spacing: 20,
                  children: [
                    TextButton(
                      onPressed: saving || pickingPhoto ? null : _pickPhoto,
                      child: Text(
                        pickingPhoto
                            ? '正在选择…'
                            : hasPhoto
                            ? '更换头像'
                            : '上传头像',
                      ),
                    ),
                    if (hasPhoto)
                      TextButton(
                        onPressed: saving
                            ? null
                            : () => setState(() {
                                unawaited(
                                  discardResumePhotoCrop(selectedPhoto),
                                );
                                selectedPhoto = null;
                                photoRemoved = true;
                              }),
                        child: const Text('移除'),
                      ),
                    if (photoError != null)
                      TextButton(
                        onPressed: saving ? null : _loadPhoto,
                        child: const Text('重试'),
                      ),
                  ],
                ),
                if (photoError != null)
                  Text(
                    photoError!,
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 10,
                    ),
                  ),
              ],
            ),
          ),
        ],
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

  final sectionKeys = List.generate(7, (_) => GlobalKey());
  int activeSection = 0;
  final sectionNames = ['基本信息', '求职意向', '工作经历', '教育经历', '项目经历', '专业技能', '证书'];

  void _jump(int index) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => activeSection = index);
    final target = sectionKeys[index].currentContext;
    if (target != null) {
      Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(currentDraft.id == 0 ? '创建简历' : '编辑简历'),
      actions: [
        const DismissKeyboardButton(),
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: TextButton(
            onPressed: saving || pickingPhoto ? null : _save,
            child: Text(
              saving ? '保存中…' : '保存',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    ),
    body: Form(
      key: formKey,
      child: Column(
        children: [
          SizedBox(
            height: 52,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: List.generate(
                  sectionNames.length,
                  (i) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(
                        sectionNames[i],
                        style: const TextStyle(fontSize: 12),
                      ),
                      selected: activeSection == i,
                      showCheckmark: false,
                      side: BorderSide.none,
                      backgroundColor: Colors.white,
                      selectedColor: const Color(0xFFE7EFFF),
                      labelStyle: TextStyle(
                        color: activeSection == i ? blue : muted,
                      ),
                      onSelected: (_) => _jump(i),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                Column(
                  children: [
                    _section(0, AppIcons.personalInfo, [
                      _photoField(),
                      _field('title', '简历名称'),
                      _field('name', '姓名'),
                      _personalFields(),
                      _pair(
                        _field('phone', '手机号码', keyboard: TextInputType.phone),
                        _field(
                          'email',
                          '邮箱',
                          keyboard: TextInputType.emailAddress,
                        ),
                      ),
                    ]),
                    _section(1, AppIcons.jobExpectation, [
                      _pair(_field('position', '意向职位'), _field('city', '意向城市')),
                      _pair(
                        _field('industry', '期望行业'),
                        _field('salary', '期望薪资'),
                      ),
                      _field(
                        'summary',
                        '求职偏好与个人介绍',
                        lines: 4,
                        hint: '填写你的专业方向、经验和优势',
                      ),
                    ]),
                    _section(2, AppIcons.work, [
                      for (var i = 0; i < workEntries.length; i++)
                        _workEntry(i),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: TextButton(
                          onPressed: saving
                              ? null
                              : () => setState(
                                  () =>
                                      workEntries.add(WorkExperienceFields({})),
                                ),
                          child: const Text('添加工作经历'),
                        ),
                      ),
                    ]),
                    _section(3, AppIcons.education, [
                      for (var i = 0; i < educationEntries.length; i++)
                        _educationEntry(i),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: TextButton(
                          onPressed: saving
                              ? null
                              : () => setState(
                                  () =>
                                      educationEntries.add(EducationFields({})),
                                ),
                          child: const Text('添加教育经历'),
                        ),
                      ),
                    ]),
                    _section(
                      4,
                      AppIcons.projects,
                      _additionalSection('projects', '项目经历'),
                    ),
                    _section(
                      5,
                      AppIcons.skills,
                      _additionalSection('skills', '技能'),
                    ),
                    _section(
                      6,
                      AppIcons.certificate,
                      _additionalSection('certifications', '证书'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
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
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: value,
          isExpanded: true,
          icon: const AppIcon(AppIcons.expand, size: 18, color: muted),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF8F9FC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE9EDF3)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE9EDF3)),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 13,
            ),
          ),
          style: const TextStyle(fontSize: 14, color: ink),
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
      }, (value) => setState(() => gender = value)),
      _field(
        'birth_date',
        '出生日期',
        hint: '例如：1996-08-15',
        onTap: _pickBirthDate,
      ),
      _choiceField('简历中显示', birthMode, const {
        'date': '出生日期',
        'age': '年龄',
      }, (value) => setState(() => birthMode = value)),
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
    setState(
      () => fields['birth_date']!.text =
          '${selected.year}-${selected.month.toString().padLeft(2, '0')}-${selected.day.toString().padLeft(2, '0')}',
    );
  }

  List<Widget> _additionalSection(String key, String title) {
    final list = additionalEntries[key]!;
    return [
      for (var index = 0; index < list.length; index++)
        Container(
          key: ObjectKey(list[index]),
          margin: const EdgeInsets.only(bottom: 18),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE9EDF3)),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '$title ${index + 1}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '上移$title',
                    onPressed: saving || index == 0
                        ? null
                        : () => _moveAdditional(key, index, index - 1),
                    icon: const AppIcon(AppIcons.moveUp, size: 18),
                  ),
                  IconButton(
                    tooltip: '下移$title',
                    onPressed: saving || index == list.length - 1
                        ? null
                        : () => _moveAdditional(key, index, index + 1),
                    icon: const AppIcon(AppIcons.moveDown, size: 18),
                  ),
                  IconButton(
                    tooltip: '删除$title',
                    onPressed: saving
                        ? null
                        : () => _removeAdditional(key, list[index], title),
                    icon: const AppIcon(
                      AppIcons.delete,
                      size: 18,
                      color: muted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              for (final field in additionalSchema[key]!)
                _field(
                  key == 'skills' && index == 0 && field.$1 == 'description'
                      ? 'skills'
                      : '$key-$index-${field.$1}',
                  field.$2,
                  controller: list[index].fields[field.$1],
                  lines: field.$3,
                  hint: field.$1 == 'date' || field.$1.endsWith('_date')
                      ? '例如：2023-06'
                      : null,
                  keyboard: field.$1 == 'url' ? TextInputType.url : null,
                ),
            ],
          ),
        ),
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextButton(
          onPressed: saving
              ? null
              : () => setState(() => list.add(_newEntry(key, {}))),
          child: Text('添加$title'),
        ),
      ),
    ];
  }

  void _moveAdditional(String key, int from, int to) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      final list = additionalEntries[key]!;
      final entry = list.removeAt(from);
      list.insert(to, entry);
    });
  }

  Future<void> _removeAdditional(
    String key,
    ResumeEntryFields entry,
    String title,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('删除这项$title？'),
        content: const Text('保存简历后生效。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => additionalEntries[key]!.remove(entry));
    WidgetsBinding.instance.addPostFrameCallback((_) => entry.dispose());
  }

  Widget _pair(Widget first, Widget second) => LayoutBuilder(
    builder: (_, constraints) => constraints.maxWidth >= 500
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

  Widget _section(int index, AppIconData icon, List<Widget> children) =>
      Container(
        key: sectionKeys[index],
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFF0F2F5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AppIcon(icon, size: 20, color: blue),
                const SizedBox(width: 10),
                Text(
                  sectionNames[index],
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ...children,
          ],
        ),
      );

  Widget _field(
    String key,
    String label, {
    int lines = 1,
    TextInputType? keyboard,
    String? hint,
    TextEditingController? controller,
    bool enabled = true,
    VoidCallback? onTap,
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
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: ink,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextFormField(
            key: ValueKey('resume-$key'),
            controller: fieldController,
            enabled: enabled && !saving,
            readOnly: pick != null,
            onTap: pick,
            minLines: lines,
            maxLines: lines == 1 ? 1 : null,
            keyboardType: keyboard,
            textInputAction: lines == 1
                ? TextInputAction.next
                : TextInputAction.newline,
            style: const TextStyle(fontSize: 14, height: 1.5),
            decoration: InputDecoration(
              hintText: dateField && enabled ? '请选择$label' : hint,
              suffixIcon: pick == null
                  ? null
                  : ValueListenableBuilder<TextEditingValue>(
                      valueListenable: fieldController!,
                      builder: (_, value, _) => value.text.isEmpty
                          ? const SizedBox(
                              width: 48,
                              child: Center(
                                child: AppIcon(
                                  AppIcons.date,
                                  size: 18,
                                  color: muted,
                                ),
                              ),
                            )
                          : IconButton(
                              tooltip: '清除$label',
                              onPressed: saving || !enabled
                                  ? null
                                  : () {
                                      dismissKeyboard();
                                      fieldController.clear();
                                    },
                              icon: const AppIcon(
                                AppIcons.clear,
                                size: 18,
                                color: muted,
                              ),
                            ),
                    ),
              hintStyle: const TextStyle(color: muted, fontSize: 12),
              filled: true,
              fillColor: const Color(0xFFF8F9FC),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 13,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE9EDF3)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE9EDF3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: blue),
              ),
            ),
            validator: (v) =>
                ['name', 'title', 'position'].contains(key) &&
                    (v == null || v.trim().isEmpty)
                ? '请填写$label'
                : null,
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
    if (!mounted || selected == null) return;
    controller.text =
        '${selected.year}-${selected.month.toString().padLeft(2, '0')}';
  }

  void _moveWork(int from, int to) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      final entry = workEntries.removeAt(from);
      workEntries.insert(to, entry);
    });
  }

  Future<void> _removeWork(WorkExperienceFields entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除这段工作经历？'),
        content: const Text('保存简历后生效。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => workEntries.remove(entry));
    // The keyed form fields must unmount before their controllers are disposed.
    WidgetsBinding.instance.addPostFrameCallback((_) => entry.dispose());
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
    );
    return Container(
      key: ObjectKey(entry),
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE9EDF3)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '经历 ${index + 1}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                tooltip: '上移',
                onPressed: saving || index == 0
                    ? null
                    : () => _moveWork(index, index - 1),
                icon: const AppIcon(AppIcons.moveUp, size: 18),
              ),
              IconButton(
                tooltip: '下移',
                onPressed: saving || index == workEntries.length - 1
                    ? null
                    : () => _moveWork(index, index + 1),
                icon: const AppIcon(AppIcons.moveDown, size: 18),
              ),
              IconButton(
                tooltip: '删除经历',
                onPressed: saving ? null : () => _removeWork(entry),
                icon: const AppIcon(AppIcons.delete, size: 18, color: muted),
              ),
            ],
          ),
          const SizedBox(height: 8),
          input('company', '公司名称'),
          input('position', '职位'),
          input('industry', '所属行业'),
          _pair(
            input('start_date', '开始时间', hint: '例如：2023-06'),
            input(
              'end_date',
              '结束时间',
              hint: entry.current ? '至今' : '例如：2025-12',
              enabled: !entry.current,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: saving
                  ? null
                  : () => setState(() => entry.current = !entry.current),
              child: Row(
                children: [
                  Checkbox(
                    value: entry.current,
                    onChanged: saving
                        ? null
                        : (value) =>
                              setState(() => entry.current = value ?? false),
                    visualDensity: VisualDensity.compact,
                  ),
                  const Text('目前仍在职', style: TextStyle(fontSize: 13)),
                ],
              ),
            ),
          ),
          input('description', '工作内容与成果', lines: 4, hint: '填写这一段经历的职责与成果'),
        ],
      ),
    );
  }

  void _moveEducation(int from, int to) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      final entry = educationEntries.removeAt(from);
      educationEntries.insert(to, entry);
    });
  }

  Future<void> _removeEducation(EducationFields entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除这段教育经历？'),
        content: const Text('保存简历后生效。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => educationEntries.remove(entry));
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
      bool enabled = true,
    }) => _field(
      'education-$index-$key',
      label,
      controller: entry.fields[key],
      lines: lines,
      hint: hint,
      enabled: enabled,
    );
    return Container(
      key: ObjectKey(entry),
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE9EDF3)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '经历 ${index + 1}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                tooltip: '上移',
                onPressed: saving || index == 0
                    ? null
                    : () => _moveEducation(index, index - 1),
                icon: const AppIcon(AppIcons.moveUp, size: 18),
              ),
              IconButton(
                tooltip: '下移',
                onPressed: saving || index == educationEntries.length - 1
                    ? null
                    : () => _moveEducation(index, index + 1),
                icon: const AppIcon(AppIcons.moveDown, size: 18),
              ),
              IconButton(
                tooltip: '删除经历',
                onPressed: saving ? null : () => _removeEducation(entry),
                icon: const AppIcon(AppIcons.delete, size: 18, color: muted),
              ),
            ],
          ),
          const SizedBox(height: 8),
          input('institution', '学校名称'),
          input('field_of_study', '专业'),
          input('degree', '学历'),
          _pair(
            input('start_date', '入学时间', hint: '例如：2019-09'),
            input('end_date', '毕业时间', hint: '例如：2023-06'),
          ),
          input('campus_experience', '在校经历', lines: 4, hint: '填写在校活动、荣誉与实践经历'),
          input('thesis_title', '毕业论文题目（选填）'),
          input('thesis_description', '毕业论文内容（选填）', lines: 3),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (saving || pickingPhoto) return;
    if (!formKey.currentState!.validate()) return;
    final draft = currentDraft.copy();
    draft.title = fields['title']!.text.trim();
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
        ].where((value) => value.trim().isNotEmpty).length /
        8;
    setState(() => saving = true);
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
      return;
    }
    if (saved) {
      Navigator.pop(context);
      toast(context, '简历已保存');
    } else {
      setState(() => saving = false);
    }
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
  final documentKey = GlobalKey<ResumeDocumentViewState>();
  final marketDocumentKey = GlobalKey<ResumeMarketDocumentViewState>();
  AppStore get store => widget.store;
  int get resumeId => widget.resumeId;
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
      return Scaffold(
        appBar: _toolbar(context, resume: resume),
        body: resume.usesMarketTemplate
            ? ResumeMarketDocumentView(
                key: marketDocumentKey,
                store: store,
                resume: resume,
              )
            : ResumeDocumentView(
                key: documentKey,
                resume: resume,
                store: store,
              ),
      );
    },
  );
  PreferredSizeWidget _toolbar(BuildContext context, {ResumeDraft? resume}) {
    final actionStyle = TextButton.styleFrom(
      foregroundColor: ink,
      minimumSize: const Size(0, 40),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
    return AppBar(
      leading: IconButton(
        icon: const AppIcon(AppIcons.back, size: 22),
        tooltip: '返回',
        onPressed: () => Navigator.maybePop(context),
      ),
      title: const Text('简历预览', maxLines: 1, overflow: TextOverflow.ellipsis),
      centerTitle: false,
      titleSpacing: 0,
      toolbarHeight: 56,
      leadingWidth: 56,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      foregroundColor: ink,
      titleTextStyle: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: ink,
      ),
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, thickness: 1, color: borderColor),
      ),
      actions: resume == null
          ? null
          : [
              TextButton(
                style: actionStyle,
                child: const Text('导出'),
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  showDragHandle: true,
                  builder: (_) => ResumeExportSheet(
                    store: store,
                    resume: resume,
                    capturePages:
                        ({required isCancelled, required onProgress}) async {
                          if (resume.usesMarketTemplate) {
                            final view = marketDocumentKey.currentState;
                            if (view == null) {
                              throw const ApiFailure("请等待预览加载完成");
                            }
                            return view.capturePages(
                              isCancelled: isCancelled,
                              onProgress: onProgress,
                            );
                          }
                          final view = documentKey.currentState;
                          if (view == null) throw const ApiFailure("请等待预览加载完成");
                          return view.capturePages(
                            isCancelled: isCancelled,
                            onProgress: onProgress,
                          );
                        },
                  ),
                ),
              ),
              const SizedBox(width: 6),
              TextButton(
                style: actionStyle,
                onPressed: () => openPage(
                  context,
                  ResumeEditor(store: store, draft: resume),
                ),
                child: const Text('编辑'),
              ),
              const SizedBox(width: 12),
            ],
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
                  name: store.name,
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
                              style: const TextStyle(
                                fontSize: 12,
                                color: muted,
                              ),
                            ),
                            trailing: busy
                                ? null
                                : const AppIcon(AppIcons.forward, size: 18),
                            onTap: busy ? null : () => use(resume),
                          ),
                      if (!widget.store.errors.containsKey('resumes') &&
                          widget.store.resumes.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            '你还没有简历，可以用这套模板创建一份。',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: muted, fontSize: 12),
                          ),
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

class ImportResume extends StatefulWidget {
  const ImportResume({
    super.key,
    required this.store,
    this.initialFile,
    this.pickFile,
    this.importer,
  });
  final AppStore store;
  final XFile? initialFile;
  final Future<XFile?> Function()? pickFile;
  final ResumeImporter? importer;
  @override
  State<ImportResume> createState() => _ImportResumeState();
}

class _ImportResumeState extends State<ImportResume> {
  final files = ResumeFiles.instance;
  XFile? selected;
  bool picking = false;
  bool busy = false;
  int operation = 0;
  String? stage, error;

  @override
  void initState() {
    super.initState();
    selected = widget.initialFile;
    files.activeImports++;
    files.incoming.addListener(receiveShared);
  }

  void receiveShared() {
    final file = files.incoming.value;
    if (file == null) return;
    operation++;
    setState(() {
      selected = file;
      busy = false;
      stage = null;
      error = null;
    });
    files.incoming.value = null;
  }

  Future<void> chooseLocal() async {
    if (picking || busy) return;
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
      error = null;
    });
    try {
      final draft =
          await (widget.importer ?? ResumeImporter(store: widget.store))
              .importFile(
                file,
                isCancelled: () => !mounted || token != operation,
                onProgress: (text) {
                  if (mounted && token == operation) {
                    setState(() => stage = text);
                  }
                },
              );
      if (!mounted || token != operation) return;
      toast(context, '文件已解析，请检查内容后保存');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ResumeEditor(store: widget.store, draft: draft),
        ),
      );
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

  Future<void> fromWeChat() => showModalBottomSheet<void>(
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
                  ? '在微信打开简历文件，通过“用其他应用打开”选择“博简”，即可带入文件。'
                  : '先将微信中的简历保存到“文件”，再选择已保存的文件上传。',
              style: const TextStyle(fontSize: 14, height: 1.7, color: muted),
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
            style: const TextStyle(fontSize: 12, color: muted),
          ),
        ),
        trailing: const AppIcon(AppIcons.forward, size: 16, color: muted),
        onTap: busy || picking ? null : onTap,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('导入简历')),
    body: ListView(
      padding: const EdgeInsets.all(22),
      children: [
        const Text(
          '选择简历文件',
          style: TextStyle(fontSize: 23, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        const Text(
          '支持 PDF、DOC、DOCX，文件不超过 20 MB。',
          style: TextStyle(fontSize: 13, color: muted, height: 1.7),
        ),
        const SizedBox(height: 24),
        source(
          '从微信文件上传',
          '导入聊天中收到的简历',
          AppIcons.wechat,
          const Color(0xFF509B87),
          fromWeChat,
        ),
        source('从本机文件上传', '选择手机或文件应用中的简历', AppIcons.folder, blue, chooseLocal),
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
                const AppIcon(AppIcons.attachment, color: blue, size: 30),
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
                          style: const TextStyle(fontSize: 12, color: muted),
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
            const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
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
              style: const TextStyle(fontSize: 13, color: Color(0xFFC74D4D)),
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
