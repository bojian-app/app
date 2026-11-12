part of 'resume_pages.dart';

/// Work experience entries and their AI descriptions.
extension _ResumeEditorWork on _ResumeEditorState {
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

  Future<void> _showWorkActions(BuildContext sectionContext) =>
      _showEntryActions(
        sectionContext,
        entries: workEntries,
        index: _workIndex,
        setIndex: (index) => _workIndex = index,
        create: () => WorkExperienceFields({}),
        remove: _removeWork,
        kind: 'work',
        label: '工作经历',
        start: (e) => e.fields['start_date']!.text,
        end: (e) => e.fields['end_date']!.text,
      );

  /// Shared add / delete / sort menu for repeatable resume entries.
  Future<void> _showEntryActions<T>(
    BuildContext sectionContext, {
    required List<T> entries,
    required int index,
    required void Function(int index) setIndex,
    required T Function() create,
    required Future<void> Function(T entry) remove,
    required String kind,
    required String label,
    required String Function(T entry) start,
    String Function(T entry)? end,
    bool sortable = true,
  }) async {
    if (saving || _entryActionsOpen) return;
    dismissKeyboard();
    final session = _sectionSession;
    final entry = entries.isEmpty ? null : entries[index];
    _entryActionsOpen = true;
    String? action;
    try {
      action = await showAppActionSheet(
        sectionContext,
        builder: (_) => ResumeEntryActionsSheet(
          canDelete: entry != null,
          canSort: sortable && entries.length > 1,
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
        entries.add(create());
        setIndex(entries.length - 1);
      });
    } else if (action == 'delete' && entry != null && entries.contains(entry)) {
      await remove(entry);
    } else if (action == 'sort') {
      await _sortEntries(entries, label, start, end, entry, setIndex);
    }
  }

  Future<void> _sortEntries<T>(
    List<T> list,
    String label,
    String Function(T entry) start,
    String Function(T entry)? end,
    T? current,
    void Function(int index) setIndex,
  ) async {
    final session = _sectionSession;
    final confirmed = await showAppConfirmation(
      context,
      title: '按时间排序$label？',
      content: Text('将按时间由近到远重新排列全部$label，保存本页后生效。'),
      confirmLabel: '排序',
    );
    if (!mounted || confirmed != true || session != _sectionSession) return;
    if (saving) return;
    _update(() {
      sortByRecency(list, start, end);
      final index = current == null ? -1 : list.indexOf(current);
      setIndex(index < 0 ? 0 : index);
    });
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
}
