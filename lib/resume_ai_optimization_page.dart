import 'dart:async';

import 'package:flutter/material.dart';

import 'api/bojian_api.dart';
import 'app_page_bar.dart';
import 'app_store.dart';
import 'design.dart';

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
    with WidgetsBindingObserver {
  late final int accountEpoch;
  Timer? timer;
  int? jobId;
  int requestGeneration = 0;
  bool loading = true, busy = false, polling = false, saved = false;
  bool restoring = false;
  String status = '', summary = '';
  String? error;
  List<Map<String, dynamic>> changes = [];
  final selected = <String, bool>{};
  bool get valid =>
      mounted && widget.store.alive && widget.store.epoch == accountEpoch;
  bool get running => status == 'QUEUED' || status == 'RUNNING';
  bool get foreground =>
      WidgetsBinding.instance.lifecycleState == null ||
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

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

  Future<void> restore() async {
    if (!valid || restoring || busy) return;
    restoring = true;
    setState(() {
      loading = true;
      error = null;
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
      if (valid) setState(() => error = '$e');
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
      error = null;
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
      setState(() {
        status = '${response.data['status']}';
        changes = [];
        selected.clear();
      });
      await poll();
    } catch (e) {
      if (valid) setState(() => error = '$e');
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
        error = null;
        if (status == 'WAITING_CONFIRMATION') {
          summary = '${result['summary'] ?? ''}';
          changes = (result['changes'] as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          final decisions = data['decisions'];
          for (final change in changes) {
            final path = '${change['path']}';
            selected.putIfAbsent(
              path,
              () => decisions is Map && decisions[path] is bool
                  ? decisions[path] as bool
                  : true,
            );
          }
        }
        if (status == 'FAILED' || status == 'TIMED_OUT') {
          error = '${data['error_message'] ?? '优化失败，请重新尝试'}';
        }
        if (status == 'SUCCEEDED') saved = true;
      });
      if (saved) await refreshResume();
    } catch (e) {
      if (valid && generation == requestGeneration) {
        setState(() => error = '$e');
      }
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
      error = null;
    });
    try {
      await request('PostPolishJobsIdDiscard');
      if (!valid) return;
      setState(() {
        jobId = null;
        status = 'CANCELED';
        changes = [];
        selected.clear();
      });
    } catch (e) {
      if (valid) setState(() => error = '$e');
    } finally {
      if (valid) setState(() => busy = false);
    }
  }

  Future<void> reanalyze() async {
    if (!valid || busy || restoring) return;
    await discard();
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

  Future<void> apply() async {
    if (!valid || busy || !selected.values.any((v) => v)) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await request(
        'PostPolishJobsIdApply',
        body: {'decisions': Map<String, bool>.of(selected)},
      );
      if (!valid) return;
      setState(() {
        saved = true;
        status = 'SUCCEEDED';
      });
      await refreshResume();
    } catch (e) {
      if (valid) setState(() => error = '$e');
    } finally {
      if (valid) setState(() => busy = false);
    }
  }

  String label(String path) {
    final parts = path.split('.');
    const groups = {
      'work_experiences': '工作经历',
      'projects': '项目经历',
      'educations': '教育经历',
      'skills': '专业技能',
      'job_expectation': '自我评价',
      'certifications': '证书',
    };
    const fields = {
      'description': '内容',
      'achievements': '项目成果',
      'campus_experience': '在校经历',
      'thesis_description': '论文内容',
    };
    final group = groups[parts.first] ?? '简历';
    final index = parts.length > 1 ? int.tryParse(parts[1]) : null;
    return '$group${index == null ? '' : ' · 第 ${index + 1} 项'}${fields[parts.last] == null ? '' : ' · ${fields[parts.last]}'}';
  }

  Widget card(List<Widget> children) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Material(
      color: context.colors.surface,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    ),
  );
  Widget paragraph(String text, {bool muted = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(
      text,
      style: TextStyle(
        height: 1.6,
        color: muted ? context.colors.muted : context.colors.ink,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final count = selected.values.where((v) => v).length;
    return Scaffold(
      appBar: const AppPageBar(title: Text('AI 简历优化')),
      backgroundColor: context.colors.inset,
      body: !valid
          ? const Center(child: Text('账号已切换，请返回后重新进入'))
          : loading
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 20),
                  Text('正在准备 AI 优化…'),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (error != null)
                  card([
                    paragraph(error!),
                    if (jobId != null && !saved)
                      TextButton(
                        onPressed: busy ? null : poll,
                        child: const Text('重新获取任务状态'),
                      ),
                  ]),
                if (saved)
                  card([
                    const Icon(Icons.check_circle_outline, size: 44),
                    const SizedBox(height: 16),
                    paragraph('已保存采纳的建议'),
                    paragraph('可以返回简历预览，继续编辑和下载。', muted: true),
                    FilledButton(
                      onPressed: busy ? null : () => Navigator.pop(context),
                      child: const Text('返回简历'),
                    ),
                  ])
                else if (running || (busy && jobId == null))
                  card([
                    if (error == null)
                      const Center(child: CircularProgressIndicator()),
                    const SizedBox(height: 20),
                    paragraph(
                      jobId == null
                          ? '正在开始 AI 优化'
                          : status == 'QUEUED'
                          ? '正在等待 AI 优化'
                          : '正在逐项分析简历内容',
                    ),
                    paragraph(
                      '生成后可查看前后对比并选择采纳。你可以先返回，稍后从 AI 优化继续查看。',
                      muted: true,
                    ),
                    TextButton(
                      onPressed: busy ? null : discard,
                      child: const Text('取消本次优化'),
                    ),
                  ])
                else if (status == 'WAITING_CONFIRMATION') ...[
                  card([
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            '优化结果',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        TextButton(
                          key: const ValueKey('resume-ai-reanalyze'),
                          onPressed: busy || restoring ? null : reanalyze,
                          child: const Text('重新分析'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    paragraph(
                      summary.isEmpty ? '请对比原文和优化后的内容，选择需要采纳的修改。' : summary,
                    ),
                    paragraph('AI 可能理解有误，请核对职责、技术和成果后再采纳。', muted: true),
                    if (changes.isEmpty) paragraph('本次没有可采纳的修改。'),
                    if (changes.isNotEmpty)
                      Row(
                        children: [
                          Expanded(
                            child: Text('已选择 $count / ${changes.length} 项'),
                          ),
                          TextButton(
                            onPressed: busy
                                ? null
                                : () => setState(() {
                                    for (final c in changes) {
                                      selected['${c['path']}'] =
                                          count != changes.length;
                                    }
                                  }),
                            child: Text(
                              count == changes.length ? '取消全选' : '全选',
                            ),
                          ),
                        ],
                      ),
                  ]),
                  for (final change in changes)
                    card([
                      CheckboxListTile(
                        key: ValueKey('resume-ai-change-${change['path']}'),
                        contentPadding: EdgeInsets.zero,
                        activeColor: context.colors.accent,
                        title: Text(
                          label('${change['path']}'),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        value: selected[change['path']] ?? false,
                        onChanged: busy
                            ? null
                            : (v) => setState(
                                () =>
                                    selected['${change['path']}'] = v ?? false,
                              ),
                      ),
                      paragraph('原文', muted: true),
                      SelectableText(
                        '${change['before']}',
                        style: const TextStyle(height: 1.6),
                      ),
                      const Divider(height: 32),
                      Text(
                        '优化后',
                        style: TextStyle(
                          color: context.colors.accent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SelectableText(
                        '${change['after']}',
                        style: const TextStyle(height: 1.6),
                      ),
                    ]),
                  TextButton(
                    onPressed: busy ? null : discard,
                    child: const Text('放弃本次结果'),
                  ),
                ] else
                  card([
                    paragraph(status == 'CANCELED' ? '本次优化已取消' : '暂时未能完成优化'),
                    paragraph('重新尝试时，会根据当前简历和求职岗位直接优化。', muted: true),
                    FilledButton(
                      key: const ValueKey('resume-ai-retry'),
                      onPressed: busy || restoring ? null : restore,
                      child: const Text('重新优化'),
                    ),
                  ]),
                const SizedBox(height: 24),
              ],
            ),
      bottomNavigationBar:
          valid &&
              status == 'WAITING_CONFIRMATION' &&
              changes.isNotEmpty &&
              !saved
          ? Material(
              color: context.colors.surface,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: FilledButton(
                    key: const ValueKey('resume-ai-apply'),
                    onPressed: busy || count == 0 ? null : apply,
                    child: Text(busy ? '正在保存…' : '采纳并保存 $count 项'),
                  ),
                ),
              ),
            )
          : null,
    );
  }
}
