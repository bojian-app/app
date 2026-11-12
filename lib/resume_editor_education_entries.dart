part of 'resume_pages.dart';

/// Education entries.
extension _ResumeEditorEducation on _ResumeEditorState {
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

  Future<void> _showEducationActions(BuildContext sectionContext) =>
      _showEntryActions(
        sectionContext,
        entries: educationEntries,
        index: _educationIndex,
        setIndex: (index) => _educationIndex = index,
        create: () => EducationFields({}),
        remove: _removeEducation,
        kind: 'education',
        label: '教育经历',
        start: (e) => e.fields['start_date']!.text,
        end: (e) => e.fields['end_date']!.text,
      );

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
}
