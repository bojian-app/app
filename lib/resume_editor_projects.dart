part of 'resume_pages.dart';

/// Project, certificate, skill and other repeatable entries.
extension _ResumeEditorProjects on _ResumeEditorState {
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
  ) {
    final dated = key == 'certifications';
    return _showEntryActions<ResumeEntryFields>(
      sectionContext,
      entries: additionalEntries[key]!,
      index: _additionalIndex(key),
      setIndex: (index) => _setAdditionalIndex(key, index),
      create: () => _newEntry(key, {}),
      remove: (entry) => _removeAdditional(key, entry, label),
      kind: kind,
      label: label,
      sortable: key != 'skills',
      start: (e) => e.fields[dated ? 'date' : 'start_date']!.text,
      end: dated ? null : (e) => e.fields['end_date']!.text,
    );
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
}
