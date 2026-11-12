part of 'resume_pages.dart';

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
                minimum: const EdgeInsets.fromLTRB(
                  appPageHorizontalPadding,
                  12,
                  appPageHorizontalPadding,
                  12,
                ),
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
            appPageHorizontalPadding,
            12,
            appPageHorizontalPadding,
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
          decoration: _underlineDecoration(),
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

  bool _entryActionsOpen = false;

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
