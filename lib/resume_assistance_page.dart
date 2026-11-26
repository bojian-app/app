import 'app_page_bar.dart';

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_selector/file_selector.dart';

import 'ai_consent.dart';
import 'api/bojian_api.dart';
import 'app_store.dart';
import 'design.dart';
import 'membership_page.dart';
import 'resume_creation.dart';
import 'resume_creation_answers.dart';
import 'resume_document.dart';
import 'resume_files.dart';
import 'resume_importer.dart';
import 'resume_pages.dart';
import 'job_title_picker.dart';

enum _AnswerTags { skills, certificates, projects, activities, traits }

class ResumeAssistancePage extends StatefulWidget {
  const ResumeAssistancePage({
    super.key,
    required this.store,
    this.pickReferenceFile,
    this.referenceImporter,
  });
  final AppStore store;
  final Future<XFile?> Function()? pickReferenceFile;
  final ResumeImporter? referenceImporter;

  @override
  State<ResumeAssistancePage> createState() => _ResumeAssistancePageState();
}

class _ResumeAssistancePageState extends State<ResumeAssistancePage> {
  final additional = TextEditingController();
  final reference = TextEditingController();
  String? referenceName, referenceProgress, referenceError;
  bool referenceBusy = false, referencePicking = false;
  int referenceOperation = 0;
  final scroll = ScrollController();
  final answers = ResumeCreationAnswers();
  final questionKeys = List.generate(7, (_) => GlobalKey());
  late final submission = ResumeCreationController(widget.store);
  int step = 0, prompt = 0;
  bool skillsConfirmed = false, certificatesConfirmed = false;
  bool experienceConfirmed = false;
  String? error;
  Timer? pollTimer;
  int? jobId;
  int jobEpoch = 0, polls = 0;
  bool checking = false, failed = false, delayed = false;
  String jobStatus = 'QUEUED';
  ResumeDraft? result;

  // App theme tokens keep this flow consistent with the rest of the app.
  Color get accent => context.colors.accent;
  Color get soft => context.colors.accentSoft;
  Color get background => context.colors.surface;
  String get generationDescription {
    return [
      answers.describe(additional.text),
      if (reference.text.trim().isNotEmpty)
        '本人上传的参考简历：\n${reference.text.trim()}',
    ].join('\n\n');
  }

  bool get canGenerate =>
      !referenceBusy &&
      !referencePicking &&
      generationDescription.runes.length <= 5000 &&
      step == 6 &&
      skillsConfirmed &&
      certificatesConfirmed &&
      (answers.identity == '职场人' || experienceConfirmed) &&
      answers.identity.isNotEmpty &&
      answers.position.isNotEmpty;

  @override
  void dispose() {
    pollTimer?.cancel();
    referenceOperation++;
    reference.dispose();
    additional.dispose();
    scroll.dispose();
    submission.dispose();
    super.dispose();
  }

  void advance(int next) {
    setState(() {
      step = math.max(step, next);
      error = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final target = questionKeys[next].currentContext;
      if (target != null) {
        Scrollable.ensureVisible(
          target,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          alignment: .08,
        );
      }
    });
  }

  Future<void> submit() async {
    if (submission.submitting || !canGenerate) return;
    FocusManager.instance.primaryFocus?.unfocus();
    if (!await AiConsent.ensure(context, widget.store) || !mounted) return;
    setState(() => error = null);
    try {
      final id = await submission.submit(generationDescription);
      if (!mounted || id == null) return;
      setState(() {
        jobId = id;
        jobStatus = 'QUEUED';
        jobEpoch = widget.store.epoch;
        polls = 0;
        failed = false;
        delayed = false;
      });
      unawaited(checkJob());
    } catch (e) {
      if (!mounted || !widget.store.isAuthenticated) return;
      if (await showMembershipRequired(context, widget.store, e)) return;
      if (mounted) setState(() => error = '$e');
    }
  }

  bool get validJob =>
      mounted &&
      widget.store.alive &&
      widget.store.isAuthenticated &&
      jobEpoch == widget.store.epoch;

  Future<void> checkJob() async {
    if (checking || jobId == null || !validJob) return;
    pollTimer?.cancel();
    setState(() {
      checking = true;
      error = null;
      delayed = false;
    });
    try {
      final task = await widget.store.request(
        'GetResumeCreationJobsId',
        expectedEpoch: jobEpoch,
        path: {'id': '$jobId'},
      );
      if (!validJob) return;
      jobStatus = task.data['status'] as String? ?? '';
      if (jobStatus == 'SUCCEEDED') {
        final resumeId = integer(task.data['resume_id']);
        if (resumeId <= 0) throw const ApiFailure('简历结果暂不可用，请重试查看');
        final saved = await widget.store.request(
          'GetResumesId',
          expectedEpoch: jobEpoch,
          path: {'id': '$resumeId'},
        );
        if (!validJob) return;
        setState(() => result = decodeResume(saved.data));
        unawaited(widget.store.load('resumes'));
      } else if (jobStatus == 'FAILED') {
        submission.resetFailedJob();
        setState(() {
          failed = true;
          error = '这次生成未完成，已保留填写内容，请返回修改或重试。';
        });
      } else if (jobStatus == 'QUEUED' || jobStatus == 'RUNNING') {
        polls++;
        if (polls >= 60) {
          setState(() => delayed = true);
        } else {
          pollTimer = Timer(
            const Duration(seconds: 2),
            () => unawaited(checkJob()),
          );
        }
      } else {
        throw const ApiFailure('暂时无法确认生成进度，请重试查看');
      }
    } catch (e) {
      if (validJob) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => checking = false);
    }
  }

  void returnToAnswers() {
    pollTimer?.cancel();
    setState(() {
      jobId = null;
      error = null;
      failed = false;
      delayed = false;
    });
  }

  Future<String?> chooseText(String title, List<String> options) =>
      showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        backgroundColor: context.colors.surface,
        builder: (context) =>
            _SearchChoices(title: title, options: options, accent: accent),
      );

  Set<String> tagSelection(_AnswerTags kind) => switch (kind) {
    _AnswerTags.skills => answers.skills,
    _AnswerTags.certificates => answers.certificates,
    _AnswerTags.projects => answers.projectTypes,
    _AnswerTags.activities => answers.activities,
    _AnswerTags.traits => answers.traits,
  };

  String tagAddLabel(_AnswerTags kind) => switch (kind) {
    _AnswerTags.skills => '添加技能',
    _AnswerTags.certificates => '添加其他证书',
    _AnswerTags.projects => '添加项目经历',
    _AnswerTags.activities => '添加其他活动',
    _AnswerTags.traits => '添加特征',
  };

  void confirmTags(_AnswerTags kind, bool confirmed) {
    switch (kind) {
      case _AnswerTags.skills:
      case _AnswerTags.traits:
        skillsConfirmed = confirmed;
      case _AnswerTags.certificates:
        certificatesConfirmed = confirmed;
      case _AnswerTags.projects:
      case _AnswerTags.activities:
        experienceConfirmed = confirmed;
    }
  }

  Future<void> addChoice(_AnswerTags kind) async {
    final selected = tagSelection(kind);
    if (selected.length >= 12) {
      toast(context, '最多选择12项，请保留与目标岗位相关的内容');
      return;
    }
    final value = await chooseText(tagAddLabel(kind), const []);
    if (value == null || !mounted) return;
    setState(() {
      selected.add(value);
      confirmTags(kind, false);
    });
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([additional, reference, submission]),
    builder: (context, _) {
      if (result != null) return AppPageSwitcher(depth: 2, child: resultPage());
      if (jobId != null) {
        return AppPageSwitcher(depth: 1, child: generatingPage());
      }
      return AppPageSwitcher(depth: 0, child: questionnairePage());
    },
  );

  Widget questionnairePage() => Scaffold(
    key: const ValueKey('resume-assistance-questionnaire'),
    backgroundColor: background,
    appBar: AppPageBar(title: const Text('AI生成简历')),
    bottomNavigationBar: bottomBar(generateButton()),
    body: SafeArea(
      top: false,
      bottom: false,
      child: SingleChildScrollView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(
          appPageHorizontalPadding,
          12,
          appPageHorizontalPadding,
          16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            questionnaireProgress(),
            const SizedBox(height: 14),
            questionnaire(),
            if (generationDescription.runes.length > 5000)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  '填写内容和参考资料共${generationDescription.runes.length}字，请编辑精简至5000字以内后生成。',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    height: 1.5,
                  ),
                ),
              ),
            if (error != null) errorMessage(),
          ],
        ),
      ),
    ),
  );

  Widget questionnaireProgress() {
    final current = (step + 1).clamp(1, 7);
    return Row(
      children: [
        Text(
          '问答进度',
          style: TextStyle(fontSize: 12, color: context.colors.muted),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: current / 7,
              minHeight: 4,
              color: accent,
              backgroundColor: context.colors.border,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$current/7',
          style: TextStyle(
            fontSize: 12,
            color: accent,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  InputDecoration compactField(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(
      fontSize: 13,
      height: 1.55,
      color: context.colors.muted,
    ),
    filled: true,
    fillColor: context.colors.inset,
    isDense: true,
    contentPadding: const EdgeInsets.all(12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: accent, width: 1.2),
    ),
  );

  /// Content-width option used for multi-select answers.
  Widget pill(
    String label, {
    required bool selected,
    required VoidCallback? onTap,
    IconData? icon,
  }) => Material(
    color: selected ? soft : context.colors.inset,
    shape: StadiumBorder(
      side: BorderSide(
        color: selected ? accent : Colors.transparent,
        width: 1.2,
      ),
    ),
    child: InkWell(
      customBorder: const StadiumBorder(),
      onTap: submission.submitting ? null : onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 14,
                color: selected ? accent : context.colors.muted,
              ),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.3,
                  color: selected ? accent : context.colors.ink,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget questionnaire() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      question(
        0,
        '选择你的身份',
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final width = gridItemWidth(context, constraints, 3);
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (title, imageAsset) in [
                    ('在校生', 'assets/resume_ai/identity-student.webp'),
                    ('应届生', 'assets/resume_ai/identity-graduate.webp'),
                    ('职场人', 'assets/resume_ai/identity-professional.webp'),
                  ])
                    SizedBox(
                      width: width,
                      child: choice(title, answers.identity == title, () {
                        if (answers.identity != title) {
                          answers.identity = title;
                          answers.years = '';
                          answers.position = '';
                          answers.major = '';
                          answers.skills.clear();
                          answers.certificates.clear();
                          answers.projectTypes.clear();
                          answers.activities.clear();
                          answers.traits.clear();
                          skillsConfirmed = false;
                          certificatesConfirmed = false;
                          experienceConfirmed = false;
                          step = 0;
                          prompt = 0;
                        }
                        advance(1);
                      }, imageAsset: imageAsset),
                    ),
                ],
              );
            },
          ),
        ],
      ),
      if (answers.identity.isNotEmpty) bubble('我是${answers.identity}'),
      for (var index = 1; index <= step; index++) ...questionStage(index),
    ],
  );

  List<Widget> questionStage(int index) {
    final professional = answers.identity == '职场人';
    final student = answers.identity == '在校生';
    if (index == 1 && professional) {
      return [
        question(
          1,
          '请选择你的工作年限',
          children: [
            choiceGrid(
              ['初级[1–3年]', '中级[3–5年]', '高级[5–10年]', '资深[10年+]'],
              (value) => answers.years == value,
              (value) {
                answers.years = value;
                advance(2);
              },
            ),
          ],
        ),
        if (answers.years.isNotEmpty) bubble('我的工作年限是${answers.years}'),
      ];
    }
    final roleIndex = professional || student ? 2 : 1;
    final majorIndex = professional
        ? 3
        : student
        ? 1
        : 2;
    if (index == roleIndex) {
      return [
        question(
          index,
          '选择你的意向岗位',
          children: [
            searchEntry(
              '搜索意向岗位',
              () => choosePositionAt(index),
              key: const ValueKey('resume-position-search'),
            ),
          ],
        ),
        if (answers.position.isNotEmpty)
          bubble('我想要找${answers.position}方向相关的工作'),
      ];
    }
    if (index == majorIndex) {
      return [
        question(
          index,
          '选择你所学的专业',
          skip: professional
              ? () {
                  answers.major = '';
                  advance(index + 1);
                }
              : null,
          children: [
            searchEntry('搜索专业', () => chooseMajorAt(index)),
            const SizedBox(height: 12),
            choiceGrid(
              resumeCreationMajors.take(6).toList(),
              (value) => answers.major == value,
              (value) {
                answers.major = value;
                advance(index + 1);
              },
            ),
          ],
        ),
        if (step > index)
          bubble(answers.major.isEmpty ? '暂不填写专业' : '我所学的专业是${answers.major}'),
      ];
    }
    if (index == 3 && !professional) {
      return tagQuestion(
        index,
        student ? _AnswerTags.activities : _AnswerTags.projects,
        student ? '选择你参加过的校园活动（多选）' : '选择你参与过的项目（多选）',
        student ? resumeCampusActivities : resumeGraduateProjects,
        experienceConfirmed,
        student ? '我参加过的校园活动有' : '我参与过的项目类别有',
      );
    }
    if (index == 4) {
      return tagQuestion(
        index,
        student ? _AnswerTags.traits : _AnswerTags.skills,
        student ? '请选择符合你的性格特征（多选）' : '请选择符合你的软技能（多选）',
        student
            ? resumeStudentTraits
            : professional
            ? resumeCreationSoftSkills
            : resumeGraduateSkills,
        skillsConfirmed,
        student ? '我的性格特征是' : '我具有的软技能是',
      );
    }
    if (index == 5) {
      return tagQuestion(
        index,
        _AnswerTags.certificates,
        '请选择你获得过的资格证书（多选）',
        resumeCreationCertificates,
        certificatesConfirmed,
        '我获得过的资格证书有',
      );
    }
    return [
      question(
        6,
        '还有经历想补充吗？详细说说～',
        children: [
          Text(
            '补充真实经历可生成个人简历；暂不填写将生成完整岗位示例，供你修改',
            style: TextStyle(
              color: context.colors.muted,
              fontSize: 12,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            key: const ValueKey('resume-assistance-additional'),
            controller: additional,
            minLines: 5,
            maxLines: 12,
            maxLength: 3000,
            keyboardType: TextInputType.multiline,
            style: const TextStyle(fontSize: 14, height: 1.55),
            decoration: compactField(
              '写写你的工作、实习或项目经历。\n\n项目背景与目标：\n我负责的工作与具体行动：\n实际成果或反馈：\n\n也可以补充姓名、邮箱、学校和起止时间。',
            ),
          ),
          referenceControl(),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 4, 2, 4),
            decoration: BoxDecoration(
              color: soft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.auto_awesome_outlined, color: accent, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '推荐词：${resumeProjectPrompts(answers.position)[prompt % 3]}',
                    style: TextStyle(color: accent, fontSize: 13, height: 1.5),
                  ),
                ),
                IconButton(
                  tooltip: '换一个提示',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => setState(() => prompt++),
                  icon: Icon(Icons.refresh, color: accent, size: 18),
                ),
              ],
            ),
          ),
        ],
      ),
      Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(
          '已收到你的信息，点击生成简历',
          textAlign: TextAlign.center,
          style: TextStyle(color: context.colors.muted, fontSize: 12),
        ),
      ),
    ];
  }

  Future<void> choosePositionAt(int index) async {
    final value = await showJobTitlePicker(
      context,
      store: widget.store,
      initialValue: answers.position,
      title: '选择意向岗位',
    );
    if (value == null || !mounted) return;
    answers.position = value;
    prompt = 0;
    advance(index + 1);
  }

  Future<void> chooseMajorAt(int index) async {
    final value = await chooseText('选择所学专业', resumeCreationMajors);
    if (value == null || !mounted) return;
    answers.major = value;
    advance(index + 1);
  }

  List<Widget> tagQuestion(
    int index,
    _AnswerTags kind,
    String title,
    List<String> options,
    bool confirmed,
    String reply,
  ) {
    final selected = tagSelection(kind);
    return [
      question(
        index,
        title,
        skip: () {
          selected.clear();
          confirmTags(kind, true);
          advance(index + 1);
        },
        children: [
          multiChoices(kind, options),
          confirmChoices(() {
            confirmTags(kind, true);
            advance(index + 1);
          }),
        ],
      ),
      if (confirmed)
        bubble(selected.isEmpty ? '暂不填写这一项' : '$reply${selected.join('、')}'),
    ];
  }

  Widget question(
    int index,
    String title, {
    required List<Widget> children,
    VoidCallback? skip,
  }) {
    final done = step > index;
    return Container(
      key: questionKeys[index],
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done ? soft : accent,
                ),
                child: done
                    ? Icon(Icons.check_rounded, size: 14, color: accent)
                    : Text(
                        '${index + 1}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: context.isDark ? Colors.black : Colors.white,
                        ),
                      ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                    color: context.colors.ink,
                  ),
                ),
              ),
              if (skip != null)
                InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: submission.submitting ? null : skip,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 4,
                    ),
                    child: Text(
                      '跳过',
                      style: TextStyle(
                        color: context.colors.muted,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  /// The confirmed answer, shown as a quiet line under its question.
  Widget bubble(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 4, 14),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(Icons.subdirectory_arrow_right, size: 16, color: accent),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 13, height: 1.45, color: accent),
          ),
        ),
      ],
    ),
  );

  /// Width of one cell in an 8pt-gapped grid; large text gets a single
  /// full-width column.
  double gridItemWidth(
    BuildContext context,
    BoxConstraints constraints,
    int columns,
  ) => MediaQuery.textScalerOf(context).scale(14) > 22
      ? constraints.maxWidth
      : (constraints.maxWidth - 8 * (columns - 1)) / columns;

  Widget bottomBar(Widget child) => SafeArea(
    top: false,
    minimum: const EdgeInsets.fromLTRB(
      appPageHorizontalPadding,
      8,
      appPageHorizontalPadding,
      10,
    ),
    child: child,
  );

  Widget choiceGrid(
    List<String> values,
    bool Function(String) selected,
    void Function(String) pick,
  ) => LayoutBuilder(
    builder: (context, constraints) {
      final width = gridItemWidth(context, constraints, 2);
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final value in values)
            SizedBox(
              width: width,
              child: choice(value, selected(value), () => pick(value)),
            ),
        ],
      );
    },
  );

  Widget choice(
    String title,
    bool selected,
    VoidCallback action, {
    String? imageAsset,
  }) => Material(
    color: selected ? soft : context.colors.inset,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(
        color: selected ? accent : Colors.transparent,
        width: 1.2,
      ),
    ),
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: submission.submitting ? null : action,
      child: Padding(
        padding: imageAsset == null
            ? const EdgeInsets.symmetric(horizontal: 10, vertical: 11)
            : const EdgeInsets.fromLTRB(6, 8, 6, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (imageAsset != null) ...[
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Image.asset(
                    imageAsset,
                    height: 64,
                    width: 64,
                    cacheWidth: 256,
                    fit: BoxFit.contain,
                    excludeFromSemantics: true,
                  ),
                  if (selected)
                    Positioned(
                      right: -10,
                      top: -2,
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: accent,
                        ),
                        child: Icon(
                          Icons.check_rounded,
                          size: 12,
                          color: context.isDark ? Colors.black : Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
            ],
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected ? accent : context.colors.ink,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget searchEntry(String hint, VoidCallback action, {Key? key}) => Material(
    key: key,
    color: context.colors.inset,
    borderRadius: BorderRadius.circular(10),
    child: InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: submission.submitting ? null : action,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        child: Row(
          children: [
            Icon(Icons.search, size: 19, color: context.colors.muted),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                hint,
                style: TextStyle(fontSize: 14, color: context.colors.muted),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: context.colors.muted,
            ),
          ],
        ),
      ),
    ),
  );

  Widget multiChoices(_AnswerTags kind, List<String> defaults) {
    final selected = tagSelection(kind);
    final options = {...defaults, ...selected}.toList();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final value in options)
          pill(
            value,
            selected: selected.contains(value),
            icon: selected.contains(value)
                ? Icons.check_rounded
                : Icons.add_rounded,
            onTap: () {
              if (!selected.contains(value) && selected.length >= 12) {
                toast(context, '最多选择12项');
                return;
              }
              setState(() {
                selected.contains(value)
                    ? selected.remove(value)
                    : selected.add(value);
                confirmTags(kind, false);
              });
            },
          ),
        Material(
          color: Colors.transparent,
          shape: StadiumBorder(
            side: BorderSide(color: accent.withValues(alpha: .5)),
          ),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: submission.submitting ? null : () => addChoice(kind),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.edit_outlined, size: 14, color: accent),
                  const SizedBox(width: 4),
                  Text(
                    tagAddLabel(kind),
                    style: TextStyle(fontSize: 13, height: 1.3, color: accent),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget confirmChoices(VoidCallback confirm) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Align(
      alignment: Alignment.centerRight,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: context.colors.palette.seed,
          foregroundColor: Colors.white,
          minimumSize: const Size(72, 34),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
        ).withoutHover(),
        onPressed: confirm,
        child: const Text('确认'),
      ),
    ),
  );

  Widget generateButton() => FilledButton(
    key: const ValueKey('resume-assistance-submit'),
    onPressed: submission.submitting || !canGenerate ? null : submit,
    style: FilledButton.styleFrom(
      foregroundColor: Colors.white,
      backgroundColor: context.colors.palette.seed,
      disabledBackgroundColor: context.colors.palette.seed.withValues(
        alpha: context.isDark ? .3 : .28,
      ),
      disabledForegroundColor: Colors.white.withValues(alpha: .95),
      minimumSize: const Size.fromHeight(48),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ).withoutHover(),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.auto_fix_high_outlined, size: 19),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            submission.submitting
                ? '提交中…'
                : canGenerate
                ? '生成简历'
                : '完成问答后生成简历',
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );

  Widget errorMessage() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Text(
      error!,
      key: const ValueKey('resume-assistance-error'),
      style: TextStyle(
        fontSize: 13,
        height: 1.5,
        color: Theme.of(context).colorScheme.error,
      ),
    ),
  );

  Widget generatingPage() {
    final waiting = !failed && error == null && !delayed;
    final title = failed
        ? '简历生成未完成'
        : delayed
        ? '简历仍在生成中'
        : jobStatus == 'QUEUED'
        ? '已提交，正在等待生成'
        : 'AI正在生成简历';
    final subtitle = failed
        ? '已保留你填写的内容，可返回修改后重新生成'
        : delayed
        ? '这次用时较长，可以稍后继续查看结果'
        : null;
    return Scaffold(
      key: const ValueKey('resume-assistance-generation'),
      backgroundColor: background,
      appBar: AppPageBar(title: const Text('AI生成简历')),
      bottomNavigationBar: bottomBar(
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (failed)
              primaryAction(returnToAnswers, '返回修改或重试')
            else if (error != null || delayed)
              primaryAction(
                checking
                    ? null
                    : () {
                        polls = 0;
                        unawaited(checkJob());
                      },
                '继续查看生成结果',
              ),
            TextButton(
              onPressed: () => Navigator.maybePop(context),
              style: TextButton.styleFrom(
                foregroundColor: accent,
                minimumSize: const Size.fromHeight(44),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ).withoutHover(),
              child: Text(failed ? '返回' : '返回，完成后通知我'),
            ),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: appPageHorizontalPadding,
              vertical: 16,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: math.max(0, constraints.maxHeight - 32),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: _ResumeWritingAnimation(
                      animate: waiting,
                      failed: failed,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: context.colors.ink,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: context.colors.muted,
                      ),
                    )
                  else
                    _ResumeWritingTips(animate: waiting),
                  if (!failed) ...[
                    const SizedBox(height: 18),
                    Text(
                      '可以先返回做别的事，完成后会通过消息通知你',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.5,
                        color: context.colors.muted,
                      ),
                    ),
                  ],
                  if (error != null && !failed) errorMessage(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget primaryAction(VoidCallback? onPressed, String label) => FilledButton(
    onPressed: onPressed,
    style: FilledButton.styleFrom(
      foregroundColor: Colors.white,
      backgroundColor: context.colors.palette.seed,
      minimumSize: const Size.fromHeight(48),
      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ).withoutHover(),
    child: Text(label),
  );

  Future<void> pickReference() async {
    if (referenceBusy || referencePicking || submission.submitting) return;
    if (!await AiConsent.ensure(context, widget.store) || !mounted) return;
    final operation = ++referenceOperation;
    final epoch = widget.store.epoch;
    setState(() {
      referencePicking = true;
      referenceError = null;
    });
    try {
      final file =
          await (widget.pickReferenceFile ?? ResumeFiles.instance.pickLocal)();
      if (!mounted || operation != referenceOperation || file == null) return;
      if (epoch != widget.store.epoch || !widget.store.isAuthenticated) {
        throw const ApiFailure('登录状态已变化，请重新选择参考文件');
      }
      setState(() {
        referenceBusy = true;
        referenceProgress = '正在读取参考文件…';
      });
      final draft =
          await (widget.referenceImporter ??
                  ResumeImporter(store: widget.store))
              .importFile(
                file,
                isCancelled: () => !mounted || operation != referenceOperation,
                onProgress: (value) {
                  if (mounted && operation == referenceOperation) {
                    setState(() => referenceProgress = value);
                  }
                },
              );
      if (!mounted || operation != referenceOperation) return;
      var parsed = resumeReferenceText(draft.source);
      final importId = draft.importID ?? 0;
      if (importId > 0) {
        final original = await widget.store.request(
          'GetResumeImportsId',
          expectedEpoch: epoch,
          path: {'id': '$importId'},
        );
        if (!mounted ||
            operation != referenceOperation ||
            epoch != widget.store.epoch) {
          return;
        }
        final raw = original.data['unresolved_source_text'];
        if (raw is String && raw.trim().isNotEmpty) parsed = raw.trim();
      }
      if (parsed.isEmpty) throw const ApiFailure('参考文件中没有可用文字，请换一个文件或直接描述经历');
      setState(() {
        referenceName = file.name;
        reference.text = parsed;
      });
    } on ImportCancelled {
      // Parsing is cancelled without confirming or creating an imported resume.
    } catch (e) {
      if (mounted && operation == referenceOperation) {
        setState(() => referenceError = '$e');
      }
    } finally {
      if (mounted && operation == referenceOperation) {
        setState(() {
          referencePicking = false;
          referenceBusy = false;
          referenceProgress = null;
        });
      }
    }
  }

  void cancelReference() {
    referenceOperation++;
    setState(() {
      referencePicking = false;
      referenceBusy = false;
      referenceProgress = null;
    });
  }

  Widget referenceControl() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (referenceBusy || referencePicking)
        Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: accent),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                referenceProgress ?? '正在选择参考文件…',
                style: TextStyle(color: context.colors.muted, fontSize: 12),
              ),
            ),
            TextButton(onPressed: cancelReference, child: const Text('取消')),
          ],
        )
      else
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const ValueKey('resume-reference-pick'),
            onPressed: submission.submitting ? null : pickReference,
            icon: const Icon(Icons.upload_file_outlined, size: 19),
            label: const Text('上传参考简历（可选）'),
          ),
        ),
      if (referenceName != null)
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: soft,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '已解析：$referenceName',
                style: TextStyle(color: accent, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 7),
              Text(
                reference.text,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, height: 1.5),
              ),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                children: [
                  TextButton(
                    onPressed: submission.submitting ? null : editReference,
                    child: const Text('查看与编辑'),
                  ),
                  TextButton(
                    onPressed: submission.submitting
                        ? null
                        : () => setState(() {
                            referenceName = null;
                            reference.clear();
                            referenceError = null;
                          }),
                    child: const Text('移除'),
                  ),
                ],
              ),
            ],
          ),
        ),
      if (referenceError != null)
        Text(
          referenceError!,
          style: TextStyle(
            color: Theme.of(context).colorScheme.error,
            fontSize: 12,
            height: 1.5,
          ),
        ),
    ],
  );

  Future<void> editReference() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: DraggableScrollableSheet(
          initialChildSize: .75,
          minChildSize: .4,
          maxChildSize: .9,
          expand: false,
          builder: (context, controller) => ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            children: [
              const Text(
                '参考简历内容',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const Text(
                '保留与目标岗位相关的事实；此处编辑只用于本次生成。',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reference,
                minLines: 10,
                maxLines: null,
                maxLength: 5000,
                maxLengthEnforcement: MaxLengthEnforcement.none,
                keyboardType: TextInputType.multiline,
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('完成'),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget resultPage() => Scaffold(
    key: const ValueKey('resume-assistance-result'),
    appBar: AppPageBar(title: const Text('生成的简历')),
    body: ResumeDocumentView(resume: result!, store: widget.store),
    bottomNavigationBar: SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '已保存到我的简历，请核对个人信息和经历后使用',
            style: TextStyle(color: context.colors.muted, fontSize: 12),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pushReplacement(
                context,
                AppPageRoute<void>(
                  builder: (_) =>
                      ResumeEditor(store: widget.store, draft: result!),
                ),
              ),
              child: const Text('编辑简历'),
            ),
          ),
        ],
      ),
    ),
  );
}

class _SearchChoices extends StatefulWidget {
  const _SearchChoices({
    required this.title,
    required this.options,
    required this.accent,
  });
  final String title;
  final List<String> options;
  final Color accent;
  @override
  State<_SearchChoices> createState() => _SearchChoicesState();
}

class _SearchChoicesState extends State<_SearchChoices> {
  final text = TextEditingController();
  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: LayoutBuilder(
      builder: (context, constraints) {
        final keyboard = MediaQuery.viewInsetsOf(context).bottom;
        final height = math.min(
          MediaQuery.sizeOf(context).height * .65,
          math.max(0.0, constraints.maxHeight - keyboard - 16),
        );
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, keyboard + 16),
          child: SizedBox(
            height: height,
            child: ListView(
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: text,
                  maxLength: 60,
                  autofocus: widget.options.isEmpty,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (value) {
                    if (value.trim().isNotEmpty) {
                      Navigator.pop(context, value.trim());
                    }
                  },
                  decoration: const InputDecoration(
                    hintText: '搜索或输入自定义内容',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
                const SizedBox(height: 6),
                if (text.text.trim().isNotEmpty)
                  ListTile(
                    title: Text('使用“${text.text.trim()}”'),
                    leading: Icon(
                      Icons.add_circle_outline,
                      color: widget.accent,
                    ),
                    onTap: () => Navigator.pop(context, text.text.trim()),
                  ),
                for (final value in widget.options.where(
                  (v) =>
                      v.toLowerCase().contains(text.text.trim().toLowerCase()),
                ))
                  ListTile(
                    title: Text(value),
                    onTap: () => Navigator.pop(context, value),
                  ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

/// Whether the platform asked for reduced motion.
bool _reduceMotion(BuildContext context) =>
    MediaQuery.maybeDisableAnimationsOf(context) ?? false;

/// A resume page writing itself: lines fill in behind a pencil while the
/// page bobs and sparkles twinkle. Reduced motion shows the finished page.
class _ResumeWritingAnimation extends StatefulWidget {
  const _ResumeWritingAnimation({required this.animate, required this.failed});
  final bool animate, failed;

  @override
  State<_ResumeWritingAnimation> createState() =>
      _ResumeWritingAnimationState();
}

class _ResumeWritingAnimationState extends State<_ResumeWritingAnimation>
    with SingleTickerProviderStateMixin {
  late final controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3600),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    sync();
  }

  @override
  void didUpdateWidget(covariant _ResumeWritingAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    sync();
  }

  void sync() {
    if (widget.animate && !_reduceMotion(context)) {
      if (!controller.isAnimating) controller.repeat();
    } else {
      controller.stop();
      controller.value = 1;
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ExcludeSemantics(
      child: SizedBox(
        width: 220,
        height: 190,
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) => CustomPaint(
            painter: _ResumeWritingPainter(
              progress: controller.value,
              moving: controller.isAnimating,
              accent: widget.failed ? colors.muted : colors.accent,
              soft: widget.failed ? colors.inset : colors.accentSoft,
              paper: colors.surface,
              line: colors.border,
              ink: colors.ink,
              shadow: context.isDark
                  ? Colors.black.withValues(alpha: .4)
                  : const Color(0x1F2867EE),
            ),
          ),
        ),
      ),
    );
  }
}

class _ResumeWritingPainter extends CustomPainter {
  _ResumeWritingPainter({
    required this.progress,
    required this.moving,
    required this.accent,
    required this.soft,
    required this.paper,
    required this.line,
    required this.ink,
    required this.shadow,
  });
  final double progress;
  final bool moving;
  final Color accent, soft, paper, line, ink, shadow;

  // Relative widths of the text lines written on the page.
  static const lines = [.62, .9, .78, .0, .5, .86, .7];

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final wave = moving ? math.sin(progress * math.pi * 2) : 0.0;
    // Soft backdrop blob.
    canvas.drawCircle(center, 82, Paint()..color = soft);

    // Sparkles twinkle on their own phases around the page.
    final sparkles = [
      (const Offset(-86, -56), 9.0, 0.0),
      (const Offset(84, -40), 7.0, .33),
      (const Offset(-74, 58), 6.0, .66),
      (const Offset(90, 52), 10.0, .5),
    ];
    for (final (offset, radius, phase) in sparkles) {
      final pulse = moving
          ? (math.sin((progress + phase) * math.pi * 4) + 1) / 2
          : .7;
      drawSparkle(
        canvas,
        center + offset,
        radius * (.55 + .45 * pulse),
        Paint()..color = accent.withValues(alpha: .35 + .55 * pulse),
      );
    }

    // The page floats gently and leans a little.
    canvas.save();
    canvas.translate(center.dx, center.dy + wave * 4);
    canvas.rotate(-.06 + wave * .015);
    final page = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: 112, height: 144),
      const Radius.circular(12),
    );
    canvas.drawRRect(
      page.shift(const Offset(0, 6)),
      Paint()
        ..color = shadow
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    canvas.drawRRect(page, Paint()..color = paper);

    // Header: avatar and name bar.
    final left = page.left + 14;
    canvas.drawCircle(
      Offset(left + 9, page.top + 22),
      9,
      Paint()..color = accent.withValues(alpha: .85),
    );
    final bar = Paint()
      ..color = accent
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 5;
    canvas.drawLine(
      Offset(left + 25, page.top + 18),
      Offset(left + 62, page.top + 18),
      bar,
    );
    canvas.drawLine(
      Offset(left + 25, page.top + 27),
      Offset(left + 48, page.top + 27),
      bar
        ..color = line
        ..strokeWidth = 4,
    );

    // Body lines are written one after another during each cycle; the last
    // fifth of the cycle holds the finished page before it starts over.
    final width = page.width - 28;
    final written = moving ? math.min(1.0, progress / .8) : 1.0;
    final count = lines.where((w) => w > 0).length;
    var done = written * count;
    Offset? pen;
    for (var index = 0; index < lines.length; index++) {
      final y = page.top + 48 + index * 12.0;
      if (lines[index] == 0) {
        continue;
      }
      final full = width * lines[index];
      canvas.drawLine(
        Offset(left, y),
        Offset(left + full, y),
        Paint()
          ..color = line
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 4,
      );
      final share = done.clamp(0.0, 1.0);
      if (share > 0) {
        final end = Offset(left + full * share, y);
        canvas.drawLine(
          Offset(left, y),
          end,
          Paint()
            ..color = index == 3 || index == 4
                ? accent.withValues(alpha: .8)
                : ink.withValues(alpha: .55)
            ..strokeCap = StrokeCap.round
            ..strokeWidth = 4,
        );
        if (share < 1) pen ??= end;
      }
      done -= 1;
    }
    if (moving && written < 1 && pen != null) drawPencil(canvas, pen);
    canvas.restore();
  }

  void drawSparkle(Canvas canvas, Offset c, double r, Paint paint) {
    final path = Path()
      ..moveTo(c.dx, c.dy - r)
      ..quadraticBezierTo(c.dx, c.dy, c.dx + r, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + r)
      ..quadraticBezierTo(c.dx, c.dy, c.dx - r, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - r)
      ..close();
    canvas.drawPath(path, paint);
  }

  void drawPencil(Canvas canvas, Offset tip) {
    canvas.save();
    canvas.translate(tip.dx, tip.dy);
    canvas.rotate(-math.pi / 4);
    final body = RRect.fromRectAndRadius(
      const Rect.fromLTWH(8, -4, 30, 8),
      const Radius.circular(2),
    );
    canvas.drawRRect(body, Paint()..color = accent);
    canvas.drawRect(
      const Rect.fromLTWH(34, -4, 4, 8),
      Paint()..color = const Color(0xFFFFB4A8),
    );
    final cone = Path()
      ..moveTo(0, 0)
      ..lineTo(8, -4)
      ..lineTo(8, 4)
      ..close();
    canvas.drawPath(cone, Paint()..color = const Color(0xFFF6D7A7));
    canvas.drawCircle(Offset.zero, 1.6, Paint()..color = ink);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ResumeWritingPainter old) =>
      old.progress != progress ||
      old.moving != moving ||
      old.accent != accent ||
      old.paper != paper;
}

/// Light-hearted lines that rotate while the resume is being written.
class _ResumeWritingTips extends StatefulWidget {
  const _ResumeWritingTips({required this.animate});
  final bool animate;

  @override
  State<_ResumeWritingTips> createState() => _ResumeWritingTipsState();
}

class _ResumeWritingTipsState extends State<_ResumeWritingTips> {
  static const tips = [
    '正在翻阅你的经历，挑出闪光点',
    '正在把“做过”写成“做成”',
    '正在给项目成果找准数字',
    '正在斟酌每一个动词',
    '正在排版，让 HR 一眼看到重点',
  ];
  Timer? timer;
  int index = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    sync();
  }

  @override
  void didUpdateWidget(covariant _ResumeWritingTips oldWidget) {
    super.didUpdateWidget(oldWidget);
    sync();
  }

  void sync() {
    final run = widget.animate && !_reduceMotion(context);
    if (run && timer == null) {
      timer = Timer.periodic(
        const Duration(milliseconds: 2800),
        (_) => setState(() => index = (index + 1) % tips.length),
      );
    } else if (!run) {
      timer?.cancel();
      timer = null;
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: 13,
      height: 1.5,
      color: context.colors.muted,
    );
    if (_reduceMotion(context) || !widget.animate) {
      return Text(
        '正在整理工作经历、项目经历和专业技能',
        textAlign: TextAlign.center,
        style: style,
      );
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, .35),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: Text(
        tips[index],
        key: ValueKey(index),
        textAlign: TextAlign.center,
        style: style,
      ),
    );
  }
}
