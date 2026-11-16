import 'dart:async';

import 'package:flutter/material.dart';

import 'api/bojian_api.dart';
import 'app_icons.dart';
import 'app_page_bar.dart';
import 'app_store.dart';
import 'design.dart';
import 'membership_page.dart';
import 'resume_pages.dart';
import 'resume_ai_optimization_models.dart';
import 'resume_ai_optimization_widgets.dart';

class ResumeAIOptimizationPage extends StatefulWidget {
  const ResumeAIOptimizationPage({
    super.key,
    required this.store,
    required this.resume,
  });
  final AppStore store;
  final ResumeDraft resume;
  @override
  State<ResumeAIOptimizationPage> createState() =>
      _ResumeAIOptimizationPageState();
}

class _ResumeAIOptimizationPageState extends State<ResumeAIOptimizationPage>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  late final int accountEpoch;
  Timer? timer;
  int? jobId;
  int requestGeneration = 0;
  bool loading = true, busy = false, polling = false, saved = false;
  bool restoring = false;
  String status = '', summary = '';
  String? error, errorCode;
  int? appliedCount;
  PolishDiagnosis? diagnosis;
  List<PolishChange> changes = [];
  List<PolishIssue> issues = [];
  final selected = <String, bool>{};
  final issueKeys = <int, GlobalKey>{};

  /// Which part of the result is open; the diagnosis card is the overview.
  PolishView view = PolishView.overview;

  /// 0 = diagnosis card shown, 1 = folded away.
  late final AnimationController fold = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );
  PageController pages = PageController();
  int page = 0;
  bool get valid =>
      mounted && widget.store.alive && widget.store.epoch == accountEpoch;
  bool get running => status == 'QUEUED' || status == 'RUNNING';
  bool get reviewing => status == 'WAITING_CONFIRMATION' && !saved;
  bool get foreground =>
      WidgetsBinding.instance.lifecycleState == null ||
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
  Map<String, dynamic> get source =>
      widget.store.resumes
          .where((r) => r.id == widget.resume.id)
          .firstOrNull
          ?.source ??
      widget.resume.source;

  @override
  void initState() {
    super.initState();
    accountEpoch = widget.store.epoch;
    WidgetsBinding.instance.addObserver(this);
    widget.store.addListener(accountChanged);
    restore();
  }

  void accountChanged() {
    if (widget.store.epoch != accountEpoch && mounted) {
      timer?.cancel();
      setState(() {});
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    timer?.cancel();
    if (state == AppLifecycleState.resumed && running) unawaited(poll());
  }

  @override
  void dispose() {
    fold.dispose();
    pages.dispose();
    timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    widget.store.removeListener(accountChanged);
    super.dispose();
  }

  Future<ApiDocument> request(
    String method, {
    Map<String, dynamic>? body,
    bool resumePath = false,
  }) => widget.store.request(
    method,
    path: {'id': '${resumePath ? widget.resume.id : jobId}'},
    body: body,
    expectedEpoch: accountEpoch,
  );

  void fail(Object e) {
    error = e is ApiFailure ? e.message : '网络异常，请检查网络后重试';
    errorCode = e is ApiFailure ? e.code : null;
  }

  void clearError() {
    error = null;
    errorCode = null;
  }

  GlobalKey issueKey(int index) => issueKeys.putIfAbsent(index, GlobalKey.new);

  void resetResult() {
    changes = [];
    issues = [];
    diagnosis = null;
    summary = '';
    selected.clear();
    issueKeys.clear();
    view = PolishView.overview;
    fold.value = 0;
    page = 0;
  }

  /// Changes in resume order: work, projects, education, skills, ...
  List<(PolishChange, PolishLocation)> get ordered => [
    for (final change in changes)
      (change, PolishLocation.resolve(change.path, source)),
  ]..sort((a, b) => a.$2.order.compareTo(b.$2.order));

  /// Folds the diagnosis card away, then shows [next].
  Future<void> open(PolishView next, {int? issue}) async {
    if (view == next) return;
    if (next == PolishView.changes) {
      pages.dispose();
      pages = PageController(initialPage: page);
    }
    if (view == PolishView.overview) await fold.forward();
    if (!mounted) return;
    setState(() => view = next);
    if (issue != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => scrollTo(issueKey(issue)),
      );
    }
  }

  void showOverview() {
    if (view == PolishView.overview) return;
    setState(() => view = PolishView.overview);
    fold.reverse();
  }

  /// Records the choice on [index] and turns to the next suggestion.
  void decide(int index, String path, bool adopt) {
    choose([path], adopt);
    Future<void>.delayed(const Duration(milliseconds: 180), () {
      if (!mounted || view != PolishView.changes || page != index) return;
      if (!pages.hasClients) return;
      pages.animateToPage(
        index + 1,
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> restore() async {
    if (!valid || restoring || busy) return;
    restoring = true;
    setState(() {
      loading = true;
      saved = false;
      appliedCount = null;
      clearError();
    });
    try {
      final result = await request('GetResumesIdPolishJobs', resumePath: true);
      if (!valid) return;
      final id = integer(result.data['id']);
      if (id > 0) {
        jobId = id;
        await poll();
      } else {
        await start();
      }
    } catch (e) {
      if (valid) setState(() => fail(e));
    } finally {
      restoring = false;
      if (valid) setState(() => loading = false);
    }
  }

  Future<void> start() async {
    if (!valid || busy) return;
    setState(() {
      busy = true;
      loading = false;
      jobId = null;
      status = '';
      clearError();
      resetResult();
    });
    try {
      final response = await request(
        'PostResumesIdPolishJobs',
        resumePath: true,
        // Let the server use the latest saved resume and its target position.
        body: const {},
      );
      if (!valid) return;
      jobId = integer(response.data['id']);
      if (jobId! <= 0) throw const ApiFailure('优化任务创建失败，请重试');
      setState(() => status = '${response.data['status']}');
      await poll();
    } catch (e) {
      if (!mounted || !valid) return;
      if (await showMembershipRequired(context, widget.store, e)) return;
      if (valid) setState(() => fail(e));
    } finally {
      if (valid) setState(() => busy = false);
    }
  }

  Future<void> poll() async {
    if (!valid || jobId == null) return;
    if (polling) {
      if (running && foreground) {
        timer = Timer(const Duration(seconds: 1), poll);
      }
      return;
    }
    timer?.cancel();
    final generation = requestGeneration;
    polling = true;
    try {
      final response = await request('GetPolishJobsId');
      if (!valid || generation != requestGeneration) return;
      final data = response.data;
      final next = '${data['status']}';
      final result = data['comparisons'];
      if (next == 'WAITING_CONFIRMATION' &&
          (result is! Map || result['changes'] is! List)) {
        throw const ApiFailure('优化结果无效，请放弃后重新优化');
      }
      setState(() {
        status = next;
        clearError();
        if (status == 'WAITING_CONFIRMATION') {
          result as Map;
          summary = '${result['summary'] ?? ''}'.trim();
          diagnosis = PolishDiagnosis.from(result['diagnosis']);
          changes = (result['changes'] as List)
              .whereType<Map>()
              .map(PolishChange.from)
              .where((c) => c.path.isNotEmpty)
              .toList();
          issues = (result['issues'] is List ? result['issues'] as List : [])
              .whereType<Map>()
              .map(PolishIssue.from)
              .where((i) => i.message.isNotEmpty || i.question.isNotEmpty)
              .toList();
          final decisions = data['decisions'];
          for (final change in changes) {
            selected.putIfAbsent(
              change.path,
              () => decisions is Map && decisions[change.path] is bool
                  ? decisions[change.path] as bool
                  : true,
            );
          }
        }
        if (status == 'FAILED' || status == 'TIMED_OUT') {
          error = '${data['error_message'] ?? ''}'.trim().isEmpty
              ? '本次优化未能完成，请稍后重新优化'
              : '${data['error_message']}';
        }
        if (status == 'SUCCEEDED') saved = true;
      });
      if (saved) await refreshResume();
    } catch (e) {
      if (valid && generation == requestGeneration) setState(() => fail(e));
    } finally {
      polling = false;
      if (valid &&
          generation == requestGeneration &&
          running &&
          foreground &&
          error == null) {
        timer = Timer(const Duration(seconds: 3), poll);
      }
    }
  }

  Future<void> discard() async {
    if (!valid || busy || jobId == null) return;
    requestGeneration++;
    timer?.cancel();
    setState(() {
      busy = true;
      clearError();
    });
    try {
      await request('PostPolishJobsIdDiscard');
      if (!valid) return;
      setState(() {
        jobId = null;
        status = 'CANCELED';
        resetResult();
      });
    } catch (e) {
      if (valid) setState(() => fail(e));
    } finally {
      if (valid) setState(() => busy = false);
    }
  }

  Future<void> reanalyze() async {
    if (!valid || busy || restoring) return;
    if (jobId != null) await discard();
    if (valid && jobId == null) await restore();
  }

  Future<void> refreshResume() async {
    final response = await widget.store.request(
      'GetResumesId',
      path: {'id': '${widget.resume.id}'},
      expectedEpoch: accountEpoch,
    );
    if (!valid) return;
    final fresh = decodeResume(response.data);
    final index = widget.store.resumes.indexWhere(
      (r) => r.id == widget.resume.id,
    );
    if (index >= 0) widget.store.resumes[index] = fresh;
    widget.store.changed();
  }

  /// Keeps choices on the server so leaving and returning restores them.
  Future<void> saveDecisions() async {
    final id = jobId;
    if (!valid || id == null || !reviewing) return;
    final body = {'decisions': Map<String, bool>.of(selected)};
    try {
      await widget.store.request(
        'PutPolishJobsIdDecisions',
        path: {'id': '$id'},
        body: body,
        expectedEpoch: accountEpoch,
      );
    } catch (_) {
      // Choices still live on this page and are sent again when saving.
    }
  }

  void choose(Iterable<String> paths, bool adopt) {
    if (busy) return;
    setState(() {
      for (final path in paths) {
        selected[path] = adopt;
      }
    });
    unawaited(saveDecisions());
  }

  Future<void> apply() async {
    final count = selected.values.where((v) => v).length;
    if (!valid || busy || count == 0) return;
    setState(() {
      busy = true;
      clearError();
    });
    try {
      await request(
        'PostPolishJobsIdApply',
        body: {'decisions': Map<String, bool>.of(selected)},
      );
      if (!valid) return;
      setState(() {
        saved = true;
        appliedCount = count;
        status = 'SUCCEEDED';
      });
      await refreshResume();
    } catch (e) {
      if (valid) setState(() => fail(e));
    } finally {
      if (valid) setState(() => busy = false);
    }
  }

  void scrollTo(GlobalKey key) {
    final target = key.currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(
      target,
      alignment: .02,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  /// Issues about the same experience entry (or the same field) as [path].
  List<int> relatedIssues(String path) {
    String entry(String p) => p.split('.').take(2).join('.');
    final target = entry(path);
    return [
      for (var i = 0; i < issues.length; i++)
        if (entry(issues[i].path) == target) i,
    ];
  }

  Future<void> openEditor() async {
    if (!valid || busy) return;
    final adopted = selected.values.where((v) => v).length;
    if (reviewing && adopted > 0) {
      final choice = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('先保存已采纳的修改？'),
          content: Text('修改简历后，未保存的 $adopted 项修改将无法采纳。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'edit'),
              child: const Text('直接去编辑'),
            ),
            FilledButton(
              key: const ValueKey('resume-ai-save-then-edit'),
              onPressed: () => Navigator.pop(context, 'save'),
              child: const Text('先保存'),
            ),
          ],
        ),
      );
      if (!valid || choice == null) return;
      if (choice == 'save') {
        await apply();
        if (!valid || !saved) return;
      }
    }
    final current =
        widget.store.resumes
            .where((r) => r.id == widget.resume.id)
            .firstOrNull ??
        widget.resume;
    final revision = current.revision;
    if (!mounted) return;
    await openPage(context, ResumeEditor(store: widget.store, draft: current));
    if (!valid) return;
    final after = widget.store.resumes
        .where((r) => r.id == widget.resume.id)
        .firstOrNull;
    if (after != null && after.revision != revision && reviewing) {
      setState(() {
        error = '简历已更新，请重新优化';
        errorCode = 'AI_BASELINE_CHANGED';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final inReview = valid && !loading && reviewing;
    return PopScope(
      canPop: !inReview || view == PolishView.overview,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) showOverview();
      },
      child: Scaffold(
        appBar: AppPageBar(
          title: PolishRollingTitle(inReview ? reviewTitle : 'AI 简历优化'),
        ),
        backgroundColor: colors.surface,
        body: !valid
            ? const Center(child: Text('账号已切换，请返回后重新进入'))
            : loading
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 20),
                    Text('正在读取优化记录…', style: TextStyle(color: colors.muted)),
                  ],
                ),
              )
            : inReview
            ? reviewBody(context)
            // A single column (not a lazy list) so jump links can always find
            // their target; the page holds at most a few dozen cards.
            : SingleChildScrollView(
                key: const ValueKey('resume-ai-list'),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: content(context),
                ),
              ),
      ),
    );
  }

  List<Widget> content(BuildContext context) {
    final colors = context.colors;
    if (saved) {
      return [
        PolishStatusCard(
          icon: AppIcons.done,
          iconColor: colors.success,
          iconBackground: colors.successSoft,
          title: '已保存',
          message: appliedCount == null
              ? '采纳的修改已写入简历'
              : '已写入 $appliedCount 项修改',
          children: [
            if (issues.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colors.warningSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '还有 ${issues.length} 项待补充：'
                  '${issues.take(3).map((i) => PolishLocation.resolve(i.path, source).title).toSet().join('、')}'
                  '${issues.length > 3 ? ' 等' : ''}',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.6,
                    color: colors.ink,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            FilledButton(
              onPressed: busy ? null : () => Navigator.pop(context),
              child: const Text('返回简历'),
            ),
          ],
        ),
      ];
    }
    final banner = error == null
        ? null
        : PolishErrorBanner(
            message: error!,
            actionLabel: errorCode == 'AI_BASELINE_CHANGED'
                ? '重新优化'
                : jobId != null
                ? '重试'
                : null,
            onAction: busy || restoring
                ? null
                : errorCode == 'AI_BASELINE_CHANGED'
                ? reanalyze
                : poll,
          );
    if (running || (busy && jobId == null && !reviewing)) {
      return [
        ?banner,
        PolishProgressCard(
          step: jobId == null
              ? PolishStep.start
              : status == 'QUEUED'
              ? PolishStep.queued
              : PolishStep.analyzing,
          onCancel: busy || jobId == null ? null : discard,
        ),
      ];
    }
    // While reviewing, errors are shown beside the save button instead.
    final failed = status == 'FAILED' || status == 'TIMED_OUT';
    return [
      PolishStatusCard(
        icon: status == 'CANCELED' ? AppIcons.aiOptimize : AppIcons.error,
        iconColor: status == 'CANCELED' ? colors.accent : context.polishWarning,
        iconBackground: status == 'CANCELED'
            ? colors.accentSoft
            : colors.warningSoft,
        title: status == 'CANCELED'
            ? '本次优化已取消'
            : failed
            ? '本次优化未能完成'
            : '暂时无法开始优化',
        message: error ?? '',
        children: [
          FilledButton(
            key: const ValueKey('resume-ai-retry'),
            onPressed: busy || restoring ? null : restore,
            child: const Text('重新优化'),
          ),
        ],
      ),
    ];
  }

  Widget reviewBody(BuildContext context) {
    final banner = error == null
        ? null
        : PolishErrorBanner(
            message: error!,
            actionLabel: errorCode == 'AI_BASELINE_CHANGED' ? '重新优化' : null,
            onAction: busy || restoring ? null : reanalyze,
          );
    final Widget body = switch (view) {
      PolishView.overview => SingleChildScrollView(
        key: const ValueKey('resume-ai-list'),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ?banner,
            PolishFold(
              animation: fold,
              child: PolishDiagnosisCard(
                summary: summary,
                diagnosis: diagnosis,
                changeCount: changes.length,
                issueCount: issues.length,
                onReanalyze: busy || restoring ? null : reanalyze,
                onShowChanges: () => open(PolishView.changes),
                onShowIssues: () => open(PolishView.issues),
              ),
            ),
          ],
        ),
      ),
      PolishView.changes => changesView(context, banner),
      PolishView.issues => issuesView(context),
    };
    return PolishEntrance(key: ValueKey(view), child: body);
  }

  String get reviewTitle => switch (view) {
    PolishView.overview => 'AI 简历优化',
    PolishView.changes =>
      page < changes.length ? '修改建议 ${page + 1}/${changes.length}' : '修改建议',
    PolishView.issues => '待补充信息',
  };

  Widget changesView(BuildContext context, Widget? banner) {
    final colors = context.colors;
    final rows = ordered;
    final total = rows.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
          child: Row(
            children: [
              for (var i = 0; i < total; i++) ...[
                if (i > 0) const SizedBox(width: 4),
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 240),
                    height: 4,
                    decoration: BoxDecoration(
                      color: i < page
                          ? (selected[rows[i].$1.path] ?? false)
                                ? colors.accent
                                : colors.muted.withValues(alpha: .45)
                          : i == page
                          ? colors.accent.withValues(alpha: .4)
                          : colors.inset,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: PageView.builder(
            key: const ValueKey('resume-ai-pages'),
            controller: pages,
            itemCount: total + 1,
            onPageChanged: (i) => setState(() => page = i),
            itemBuilder: (context, i) {
              if (i == total) return finishPage(context, banner);
              final (change, location) = rows[i];
              final related = relatedIssues(change.path);
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                child: PolishChangeCard(
                  key: ValueKey('resume-ai-change-${change.path}'),
                  change: change,
                  location: location,
                  adopted: selected[change.path] ?? false,
                  onChanged: busy ? null : (v) => decide(i, change.path, v),
                  relatedIssues: related.length,
                  onShowIssues: related.isEmpty
                      ? null
                      : () => open(PolishView.issues, issue: related.first),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget finishPage(BuildContext context, Widget? banner) {
    final colors = context.colors;
    final adopted = selected.values.where((v) => v).length;
    return SingleChildScrollView(
      key: const ValueKey('resume-ai-finish'),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      child: PolishCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '已看完 ${changes.length} 处修改',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: colors.ink,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '采纳 $adopted 处，忽略 ${changes.length - adopted} 处',
              style: TextStyle(fontSize: 14, color: colors.muted),
            ),
            const SizedBox(height: 20),
            ?banner,
            FilledButton(
              key: const ValueKey('resume-ai-apply'),
              onPressed: busy || adopted == 0 ? null : apply,
              child: Text(busy ? '正在保存…' : '保存到简历'),
            ),
            if (issues.isNotEmpty) ...[
              const SizedBox(height: 10),
              OutlinedButton(
                key: const ValueKey('resume-ai-finish-issues'),
                onPressed: () => open(PolishView.issues),
                child: Text('查看 ${issues.length} 项待补充'),
              ),
            ],
            const SizedBox(height: 6),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: colors.muted),
              onPressed: busy ? null : discard,
              child: const Text('放弃本次结果'),
            ),
          ],
        ),
      ),
    );
  }

  Widget issuesView(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Expanded(
        child: SingleChildScrollView(
          key: const ValueKey('resume-ai-issues'),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < issues.length; i++)
                PolishIssueCard(
                  key: issueKey(i),
                  issue: issues[i],
                  location: PolishLocation.resolve(issues[i].path, source),
                  onEdit: busy ? null : openEditor,
                ),
              if (changes.isEmpty)
                Center(
                  child: TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: context.colors.muted,
                    ),
                    onPressed: busy ? null : discard,
                    child: const Text('放弃本次结果'),
                  ),
                ),
            ],
          ),
        ),
      ),
    ],
  );
}
