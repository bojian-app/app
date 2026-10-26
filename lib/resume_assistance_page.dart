import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_selector/file_selector.dart';

import 'api/bojian_api.dart';
import 'app_store.dart';
import 'design.dart';
import 'resume_creation.dart';
import 'resume_creation_answers.dart';
import 'resume_document.dart';
import 'resume_files.dart';
import 'resume_importer.dart';
import 'resume_pages.dart';

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
  final description = TextEditingController();
  final additional = TextEditingController();
  final reference = TextEditingController();
  String? referenceName, referenceProgress, referenceError;
  bool referenceBusy = false, referencePicking = false;
  int referenceOperation = 0;
  final scroll = ScrollController();
  final answers = ResumeCreationAnswers();
  final questionKeys = List.generate(7, (_) => GlobalKey());
  late final submission = ResumeCreationController(widget.store);
  bool quick = false;
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

  Color get purple =>
      context.isDark ? const Color(0xFFB79AFF) : const Color(0xFF8048F4);
  Color get soft =>
      context.isDark ? const Color(0xFF332744) : const Color(0xFFF4EEFF);
  Color get background =>
      context.isDark ? context.colors.canvas : const Color(0xFFF8F7FF);
  String get generationDescription {
    final base = quick
        ? description.text.trim()
        : answers.describe(additional.text);
    return [
      base,
      if (reference.text.trim().isNotEmpty)
        '本人上传的参考简历：\n${reference.text.trim()}',
    ].join('\n\n');
  }

  bool get canGenerate =>
      !referenceBusy &&
      !referencePicking &&
      generationDescription.runes.length <= 5000 &&
      (quick
          ? generationDescription.trim().runes.length >= 10
          : step == 6 &&
                skillsConfirmed &&
                certificatesConfirmed &&
                (answers.identity == '职场人' || experienceConfirmed) &&
                answers.identity.isNotEmpty &&
                answers.position.isNotEmpty);

  @override
  void dispose() {
    pollTimer?.cancel();
    referenceOperation++;
    reference.dispose();
    description.dispose();
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
      if (!mounted || quick) return;
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
      if (mounted && widget.store.isAuthenticated) setState(() => error = '$e');
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
            _SearchChoices(title: title, options: options, accent: purple),
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
    listenable: Listenable.merge([
      description,
      additional,
      reference,
      submission,
    ]),
    builder: (context, _) {
      if (result != null) return resultPage();
      if (jobId != null) return generatingPage();
      return Scaffold(
        backgroundColor: background,
        appBar: AppBar(
          title: const Text('AI生成简历'),
          backgroundColor: context.colors.surface,
          surfaceTintColor: Colors.transparent,
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: generateButton(),
        ),
        body: SafeArea(
          top: false,
          bottom: false,
          child: SingleChildScrollView(
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                modeTabs(),
                const SizedBox(height: 20),
                if (quick) quickForm() else questionnaire(),
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
    },
  );

  Widget modeTabs() => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: context.colors.inset,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        for (final (value, title, icon) in [
          (false, '问答创建', Icons.forum_outlined),
          (true, '快速生成', Icons.auto_fix_high_outlined),
        ])
          Expanded(
            child: TextButton(
              key: ValueKey(
                value ? 'resume-mode-quick' : 'resume-mode-questions',
              ),
              onPressed: submission.submitting
                  ? null
                  : () => setState(() {
                      quick = value;
                      error = null;
                    }),
              style: TextButton.styleFrom(
                foregroundColor: quick == value ? purple : context.colors.ink,
                backgroundColor: quick == value
                    ? context.colors.surface
                    : Colors.transparent,
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(11),
                ),
              ).withoutHover(),
              child: Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                children: [
                  Icon(icon, size: 21),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
  );

  Widget quickForm() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '聊聊你的经历，AI帮你整理成简历',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('resume-assistance-description'),
              controller: description,
              enabled: !submission.submitting,
              minLines: 8,
              maxLines: 16,
              maxLength: 5000,
              keyboardType: TextInputType.multiline,
              decoration: const InputDecoration(
                hintText: '可以写求职岗位、教育背景、工作或实习经历。\n\n项目写清：为什么做、你负责什么、怎样推进、取得了哪些实际成果。\n\n还可以补充姓名、邮箱和已取得的证书。至少10字。',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: EdgeInsets.zero,
              ),
            ),
            referenceControl(),
          ],
        ),
      ),
      const SizedBox(height: 18),
      Text(
        '试试这样开始',
        style: TextStyle(fontSize: 13, color: context.colors.muted),
      ),
      const SizedBox(height: 10),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final (label, text) in [
            ('零经验 · 市场营销实习', '我是市场营销专业在校生，希望寻找市场营销实习。请结合我的课程和校园活动经历整理简历：'),
            ('应届生 · 产品经理', '我是应届毕业生，求职方向是产品经理。我的专业、课程项目和实习经历如下：'),
            ('职场人 · 新媒体运营', '我希望应聘新媒体运营，有以下工作和项目经历。项目目标、我的具体工作和实际成果是：'),
            ('开发工程师 · 项目经历', '我希望应聘开发工程师。以下是我参与的项目、使用的技术、负责的模块和解决的问题：'),
          ])
            ActionChip(
              label: Text(label),
              onPressed: submission.submitting
                  ? null
                  : () {
                      description.text = text;
                      description.selection = TextSelection.collapsed(
                        offset: text.length,
                      );
                    },
            ),
        ],
      ),
    ],
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
              final largeText = MediaQuery.textScalerOf(context).scale(14) > 22;
              final width = largeText
                  ? constraints.maxWidth
                  : (constraints.maxWidth - 20) / 3;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final (title, imageAsset) in [
                    ('在校生', 'assets/resume_ai/identity-student.png'),
                    ('应届生', 'assets/resume_ai/identity-graduate.png'),
                    ('职场人', 'assets/resume_ai/identity-professional.png'),
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
            const SizedBox(height: 12),
            choiceGrid(
              resumeCreationPositions.take(6).toList(),
              (value) => answers.position == value,
              (value) {
                answers.position = value;
                prompt = 0;
                advance(index + 1);
              },
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => choosePositionAt(index),
              child: Text('更多岗位', style: TextStyle(color: purple)),
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
              height: 1.6,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('resume-assistance-additional'),
            controller: additional,
            minLines: 7,
            maxLines: 14,
            maxLength: 3000,
            keyboardType: TextInputType.multiline,
            decoration: InputDecoration(
              hintText: '写写你的工作、实习或项目经历。\n\n项目背景与目标：\n我负责的工作与具体行动：\n实际成果或反馈：\n\n也可以补充姓名、邮箱、学校和起止时间。',
              fillColor: context.colors.inset,
              contentPadding: const EdgeInsets.all(14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: context.colors.border),
              ),
            ),
          ),
          referenceControl(),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.auto_awesome_outlined, color: purple, size: 20),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  '推荐词：${resumeProjectPrompts(answers.position)[prompt % 3]}',
                  style: TextStyle(color: purple, height: 1.6),
                ),
              ),
              IconButton(
                tooltip: '换一个提示',
                onPressed: () => setState(() => prompt++),
                icon: Icon(Icons.refresh, color: purple),
              ),
            ],
          ),
        ],
      ),
      Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          '已收到你的信息，点击生成简历',
          textAlign: TextAlign.center,
          style: TextStyle(color: context.colors.muted, fontSize: 13),
        ),
      ),
    ];
  }

  Future<void> choosePositionAt(int index) async {
    final value = await chooseText('选择意向岗位', resumeCreationPositions);
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
  }) => Container(
    key: questionKeys[index],
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: context.colors.surface,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                '${index + 1}/7',
                style: TextStyle(color: purple, fontSize: 14),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  height: 1.45,
                ),
              ),
            ),
            if (skip != null)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: InkWell(
                  onTap: submission.submitting ? null : skip,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      '跳过',
                      style: TextStyle(
                        color: context.colors.muted,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 18),
        ...children,
      ],
    ),
  );

  Widget bubble(String text) => Align(
    alignment: Alignment.centerRight,
    child: Container(
      margin: const EdgeInsets.only(left: 26, bottom: 22),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: context.isDark
              ? [const Color(0xFF463156), const Color(0xFF3B2F5C)]
              : [const Color(0xFFF1D9FF), const Color(0xFFDFC6FF)],
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 15, height: 1.5, color: context.colors.ink),
      ),
    ),
  );

  Widget choiceGrid(
    List<String> values,
    bool Function(String) selected,
    void Function(String) pick,
  ) => LayoutBuilder(
    builder: (context, constraints) {
      final largeText = MediaQuery.textScalerOf(context).scale(14) > 22;
      final width = largeText
          ? constraints.maxWidth
          : (constraints.maxWidth - 12) / 2;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
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
  }) => TextButton(
    onPressed: submission.submitting ? null : action,
    style: TextButton.styleFrom(
      foregroundColor: selected ? purple : context.colors.ink,
      backgroundColor: selected
          ? soft
          : context.colors.inset.withValues(alpha: .65),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 17),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected
              ? purple.withValues(alpha: .18)
              : context.colors.border,
        ),
      ),
    ).withoutHover(),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (imageAsset != null) ...[
          Image.asset(
            imageAsset,
            height: 100,
            width: 100,
            cacheWidth: 400,
            fit: BoxFit.contain,
            excludeFromSemantics: true,
          ),
          const SizedBox(height: 12),
        ],
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        ),
      ],
    ),
  );

  Widget searchEntry(String hint, VoidCallback action, {Key? key}) =>
      OutlinedButton.icon(
        key: key,
        onPressed: submission.submitting ? null : action,
        style: OutlinedButton.styleFrom(
          alignment: Alignment.centerLeft,
          foregroundColor: context.colors.muted,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
          side: BorderSide(color: purple),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: const Icon(Icons.search),
        label: Text(hint),
      );

  Widget multiChoices(_AnswerTags kind, List<String> defaults) {
    final selected = tagSelection(kind);
    final options = {...defaults, ...selected}.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        choiceGrid(
          options
              .map((value) => '${selected.contains(value) ? '✓' : '＋'} $value')
              .toList(),
          (value) => selected.contains(value.substring(2)),
          (display) {
            final value = display.substring(2);
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
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => addChoice(kind),
            icon: Icon(Icons.add, color: purple),
            label: Text(tagAddLabel(kind), style: TextStyle(color: purple)),
          ),
        ),
      ],
    );
  }

  Widget confirmChoices(VoidCallback confirm) => Padding(
    padding: const EdgeInsets.only(top: 14),
    child: Align(
      alignment: Alignment.centerRight,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: purple,
          foregroundColor: context.isDark ? Colors.black : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
        ),
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
      backgroundColor: const Color(0xFF854DF5),
      disabledBackgroundColor: purple.withValues(alpha: .3),
      padding: const EdgeInsets.symmetric(vertical: 17, horizontal: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ).withoutHover(),
    child: Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      children: [
        const Icon(Icons.auto_fix_high_outlined, size: 24),
        Text(
          submission.submitting ? '提交中…' : '生成简历',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );

  Widget errorMessage() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
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

  Widget generatingPage() => Scaffold(
    backgroundColor: background,
    appBar: AppBar(title: const Text('AI生成简历')),
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!failed && error == null && !delayed)
                CircularProgressIndicator(color: purple),
              if (failed) Icon(Icons.refresh, color: purple, size: 44),
              const SizedBox(height: 24),
              Text(
                failed
                    ? '简历生成未完成'
                    : delayed
                    ? '简历仍在生成中'
                    : jobStatus == 'QUEUED'
                    ? '已提交，正在等待生成'
                    : 'AI正在生成简历',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              Text(
                '我们会结合你的求职方向，整理工作经历、项目经历和专业技能。\n你可以留在此页查看结果，也可以返回，完成后会通过消息通知你。',
                style: TextStyle(color: context.colors.muted, height: 1.7),
                textAlign: TextAlign.center,
              ),
              if (error != null) errorMessage(),
              const SizedBox(height: 24),
              if (failed)
                FilledButton(
                  onPressed: returnToAnswers,
                  child: const Text('返回修改或重试'),
                )
              else if (error != null || delayed)
                FilledButton(
                  onPressed: checking
                      ? null
                      : () {
                          polls = 0;
                          unawaited(checkJob());
                        },
                  child: const Text('继续查看生成结果'),
                ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.maybePop(context),
                child: const Text('返回，完成后通知我'),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Future<void> pickReference() async {
    if (referenceBusy || referencePicking || submission.submitting) return;
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
              child: CircularProgressIndicator(strokeWidth: 2, color: purple),
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
            label: Text(quick ? '上传简历作为参考' : '参考文件'),
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
                style: TextStyle(color: purple, fontWeight: FontWeight.w500),
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

  bool get generatedRoleExample =>
      (result?.source['projects'] as List? ?? const []).whereType<Map>().any(
        (project) => '${project['name'] ?? ''}'.contains('岗位示例'),
      );

  Widget resultPage() => Scaffold(
    appBar: AppBar(title: const Text('生成的简历')),
    body: ResumeDocumentView(resume: result!, store: widget.store),
    bottomNavigationBar: SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            generatedRoleExample
                ? '岗位示例已保存，请按真实经历修改后使用'
                : '已保存到我的简历，请核对并完善个人信息和项目内容',
            style: TextStyle(color: context.colors.muted, fontSize: 12),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute<void>(
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
