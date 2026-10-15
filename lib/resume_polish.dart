import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'api/bojian_api.dart';
import 'app_store.dart';

// Only existing narrative fields may be adopted. Identity, dates, ordering,
// templates, photos and unknown metadata always come from the user's snapshot.
const polishSections = <String, (String, List<String>, List<String>)>{
  'job_expectation': ('求职期望', ['preference'], []),
  'work_experiences': (
    '工作经历',
    ['description'],
    ['company', 'position', 'start_date', 'end_date'],
  ),
  'projects': (
    '项目经历',
    ['description', 'achievements'],
    ['name', 'role', 'start_date', 'end_date'],
  ),
  'educations': (
    '教育经历',
    ['campus_experience', 'thesis_description'],
    [
      'institution',
      'degree',
      'field_of_study',
      'start_date',
      'end_date',
      'thesis_title',
    ],
  ),
  'skills': ('专业技能', ['description'], ['name']),
};
const _labels = {
  'preference': '个人优势与期望',
  'description': '经历描述',
  'achievements': '项目成果',
  'campus_experience': '校园经历',
  'thesis_description': '论文描述',
};

Map<String, dynamic> _clone(Map value) =>
    Map<String, dynamic>.from(jsonDecode(jsonEncode(value)) as Map);

String _text(Map row, String field) {
  final rich = row['${field}_rich'];
  if (rich is Map &&
      rich['blocks'] is List &&
      (rich['blocks'] as List).isNotEmpty) {
    return plainContent(rich).trim();
  }
  return row[field] is String ? (row[field] as String).trim() : '';
}

class ResumePolishChange {
  const ResumePolishChange(this.path, this.title, this.before, this.after);
  final String path, title, before, after;
}

List<ResumePolishChange> resumePolishChanges(Map original, Map proposed) {
  final changes = <ResumePolishChange>[];
  for (final section in polishSections.entries) {
    final old = original[section.key];
    final next = proposed[section.key];
    final rows = old is List ? old : (old is Map ? [old] : []);
    final candidates = next is List ? next : (next is Map ? [next] : []);
    if (rows.isEmpty || candidates.isEmpty) continue;
    if (rows.length != candidates.length || (old is List) != (next is List)) {
      throw const ApiFailure('优化结果改变了经历结构，请重新生成');
    }
    for (var i = 0; i < rows.length; i++) {
      if (rows[i] is! Map || candidates[i] is! Map) {
        throw const ApiFailure('优化结果格式不完整，请重新生成');
      }
      final row = rows[i] as Map;
      final candidate = candidates[i] as Map;
      for (final anchor in section.value.$3) {
        if ('${row[anchor] ?? ''}' != '${candidate[anchor] ?? ''}') {
          throw const ApiFailure('优化结果改变了经历中的基本信息，请重新生成');
        }
      }
      for (final field in section.value.$2) {
        final before = _text(row, field);
        // A provider may update either the plain field or the rich document.
        final raw = candidate[field];
        final after =
            raw is String && raw.trim() != '${row[field] ?? ''}'.trim()
            ? raw.trim()
            : _text(candidate, field);
        if (before.isEmpty || after.isEmpty || before == after) continue;
        if (after.length > 30000) throw const ApiFailure('优化结果过长，请缩小优化范围后重试');
        final name = section.value.$3.isEmpty
            ? ''
            : '${row[section.value.$3.first] ?? ''}'.trim();
        final label = section.key == 'skills'
            ? '技能说明'
            : (_labels[field] ?? '内容');
        changes.add(
          ResumePolishChange(
            '${section.key}${old is List ? '.$i' : ''}.$field',
            '${section.value.$1}${name.isEmpty ? '' : ' · $name'} · $label',
            before,
            after,
          ),
        );
      }
    }
  }
  return changes;
}

Map<String, dynamic> applyResumePolishChanges(
  Map original,
  List<ResumePolishChange> changes,
  Set<String> selected,
) {
  final content = _clone(original);
  for (final change in changes.where((c) => selected.contains(c.path))) {
    final parts = change.path.split('.');
    dynamic row = content;
    for (final part in parts.take(parts.length - 1)) {
      row = row is List ? row[int.parse(part)] : row[part];
    }
    row[parts.last] = change.after;
    // Never leave stale rich-text runs shadowing the newly accepted text.
    if (row.containsKey('${parts.last}_rich')) row['${parts.last}_rich'] = null;
  }
  return content;
}

enum ResumePolishPhase { setup, generating, review, saved }

class _PolishStopped implements Exception {}

class ResumePolishController extends ChangeNotifier {
  ResumePolishController(
    this.store,
    this.resumeID, {
    this.wait = Future<void>.delayed,
    this.maxPolls = 120,
  }) : epoch = store.epoch,
       owner = store.userID {
    store.addListener(_sessionChanged);
  }
  final AppStore store;
  final int resumeID, epoch, owner, maxPolls;
  final Future<void> Function(Duration) wait;
  ResumePolishPhase phase = ResumePolishPhase.setup;
  bool busy = false, conflict = false, _disposed = false;
  bool cancelRequested = false;
  String? error;
  int? jobID;
  Map<String, dynamic>? baseline, pendingSave;
  String instructions = '';
  List<ResumePolishChange> changes = [];
  Set<String> selected = {};
  List<dynamic>? _restoredSelection;
  Future<void> _storageQueue = Future.value();
  bool get validSession =>
      store.alive &&
      store.epoch == epoch &&
      store.userID == owner &&
      store.isAuthenticated;
  String get _key => 'bojian.resume-polish.$owner.$resumeID';

  void _check() {
    if (_disposed) throw _PolishStopped();
    if (!validSession) throw const ApiFailure('登录状态已变化，请返回后重新打开');
  }

  void _emit() {
    if (!_disposed) notifyListeners();
  }

  void _sessionChanged() {
    if (validSession || _disposed) return;
    changes = [];
    selected = {};
    baseline = null;
    phase = ResumePolishPhase.setup;
    error = '登录状态已变化，请返回后重新打开';
    _emit();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (busy || _disposed) return;
    busy = true;
    error = null;
    _emit();
    try {
      _check();
      await action();
    } on _PolishStopped {
      // Closing the page stops local polling; the persisted task can be reopened.
    } catch (e) {
      if (!_disposed) error = e is ApiFailure ? e.message : '操作失败，请稍后重试';
    } finally {
      busy = false;
      cancelRequested = false;
      _emit();
    }
  }

  Future<void> _persist() {
    final value = jsonEncode({
      'job_id': jobID,
      'baseline': baseline,
      'instructions': instructions,
      'selected': phase == ResumePolishPhase.review
          ? selected.toList()
          : _restoredSelection,
      'pending_save': pendingSave,
    });
    return _storageQueue = _storageQueue.catchError((_) {}).then((_) async {
      if (validSession) await store.storage.write(_key, value);
    });
  }

  Future<void> _clear() async {
    await _storageQueue.catchError((_) {});
    if (validSession) await store.storage.write(_key, null);
  }

  Future<Map<String, dynamic>> _current() async {
    final result = await store.request(
      'GetResumesId',
      path: {'id': '$resumeID'},
    );
    _check();
    if (integer(result.data['id']) != resumeID ||
        integer(result.data['revision']) <= 0 ||
        result.data['content'] is! Map) {
      throw const ApiFailure('简历暂不可用，请返回列表刷新');
    }
    return _clone(result.data);
  }

  Future<void> initialize() => _run(() async {
    final cached = await store.storage.read(_key);
    _check();
    if (cached == null) return;
    final record = jsonDecode(cached) as Map;
    final id = integer(record['job_id']);
    if (id <= 0 || record['baseline'] is! Map) {
      await _clear();
      return;
    }
    jobID = id;
    baseline = _clone(record['baseline'] as Map);
    if (integer(baseline!['id']) != resumeID) {
      throw const ApiFailure('优化记录无效，请放弃后重新生成');
    }
    instructions = '${record['instructions'] ?? ''}';
    _restoredSelection = record['selected'] is List
        ? record['selected'] as List
        : null;
    pendingSave = record['pending_save'] is Map
        ? _clone(record['pending_save'] as Map)
        : null;
    if (pendingSave != null) {
      final current = await _current();
      if (_sameContent(current['content'], pendingSave)) {
        await _saved(current);
        return;
      }
    }
    await _poll();
  });

  Future<void> start(String direction) => _run(() async {
    if (jobID != null) throw const ApiFailure('请先查看或放弃当前优化结果');
    baseline = await _current();
    final source = baseline!['content'] as Map;
    final hasText = polishSections.entries.any((section) {
      final data = source[section.key];
      final rows = data is List ? data : [data];
      return rows.whereType<Map>().any(
        (row) => section.value.$2.any((field) => _text(row, field).isNotEmpty),
      );
    });
    if (!hasText) throw const ApiFailure('请先填写工作经历、项目经历、技能描述或个人优势，再进行优化');
    instructions = direction.trim();
    if (instructions.length > 1000) throw const ApiFailure('优化要求请控制在 1000 字以内');
    final response = await store.request(
      'PostResumesIdPolishJobs',
      path: {'id': '$resumeID'},
      body: {
        'instructions':
            '仅优化已有的求职期望 preference、工作经历 description、项目 description/achievements、教育 campus_experience/thesis_description 和技能 description。不得修改姓名、联系方式、公司、职位、学校、日期、名称、数字、模板及其他字段，不得增删或调整经历顺序，不补充原文未提供的事实。若字段同时有富文本和纯文本，请同步其文字。保持完整 JSON 结构。用户要求：${instructions.isEmpty ? '表达更清晰、专业、简洁，突出原文已有的职责与成果。' : instructions}',
      },
    );
    // Persist even if the page was closed while the creation request was in flight.
    final id = integer(response.data['id']);
    if (id <= 0) throw const ApiFailure('未能创建优化任务，请重试');
    jobID = id;
    phase = ResumePolishPhase.generating;
    await _persist();
    _check();
    final current = await _current();
    if (current['revision'] != baseline!['revision']) {
      conflict = true;
      throw const ApiFailure('简历刚刚发生了修改，请放弃本次任务后重新优化');
    }
    await _poll();
  });

  Future<void> refresh() => _run(_poll);
  Future<void> _poll() async {
    if (jobID == null) return;
    phase = ResumePolishPhase.generating;
    _emit();
    final deadline = DateTime.now().add(const Duration(minutes: 3));
    for (var i = 0; i < maxPolls; i++) {
      _check();
      if (cancelRequested) {
        await _discardCurrent();
        return;
      }
      if (DateTime.now().isAfter(deadline)) break;
      final result = await store.request(
        'GetPolishJobsId',
        path: {'id': '$jobID'},
      );
      _check();
      if (cancelRequested) {
        await _discardCurrent();
        return;
      }
      if (integer(result.data['resume_id']) != resumeID) {
        throw const ApiFailure('优化任务与当前简历不匹配');
      }
      switch (result.data['status']) {
        case 'WAITING_CONFIRMATION':
          final output = result.data['comparisons'];
          if (output is! Map || output.isEmpty) {
            throw const ApiFailure('AI 未返回有效内容，请放弃后重新生成');
          }
          changes = resumePolishChanges(baseline!['content'] as Map, output);
          selected = changes
              .map((c) => c.path)
              .where(
                (p) =>
                    _restoredSelection == null ||
                    _restoredSelection!.contains(p),
              )
              .toSet();
          phase = ResumePolishPhase.review;
          await _persist();
          return;
        case 'QUEUED':
        case 'RUNNING':
          await store.waitForJobUpdate('POLISH', jobID!, wait);
        case 'FAILED':
        case 'TIMED_OUT':
          throw const ApiFailure('本次 AI 优化未完成，请放弃后重新生成');
        case 'CANCELED':
          throw const ApiFailure('本次优化已结束，请放弃本地记录后重新生成');
        case 'SUCCEEDED':
          final current = await _current();
          await _saved(current);
          return;
        default:
          throw const ApiFailure('优化任务状态暂不可用，请稍后查看');
      }
    }
    _check();
    if (cancelRequested) {
      await _discardCurrent();
      return;
    }
    throw const ApiFailure('优化仍在处理中，可稍后继续查看，不必重复生成');
  }

  Future<void> select(String path, bool value) async {
    if (busy || !validSession || phase != ResumePolishPhase.review) return;
    value ? selected.add(path) : selected.remove(path);
    _emit();
    try {
      await _persist();
    } catch (_) {
      error = '选择暂未保存到本机，请保持此页打开';
      _emit();
    }
  }

  Map<String, dynamic> get proposedContent =>
      applyResumePolishChanges(baseline!['content'] as Map, changes, selected);
  ResumeDraft get preview =>
      decodeResume({...baseline!, 'content': proposedContent});

  Future<void> save() => _run(() async {
    if (phase != ResumePolishPhase.review || selected.isEmpty) {
      throw const ApiFailure('请至少选择一项修改');
    }
    final content = proposedContent;
    final current = await _current();
    if (pendingSave != null && _sameContent(current['content'], pendingSave)) {
      await _saved(current);
      return;
    }
    if (current['revision'] != baseline!['revision'] ||
        !_sameContent(current['content'], baseline!['content'])) {
      conflict = true;
      throw const ApiFailure('简历已在其他位置更新。原内容未被覆盖，请放弃本次结果后重新优化');
    }
    pendingSave = content;
    await _persist();
    _check();
    // The legacy apply endpoint replaces the entire AI output and ignores
    // per-field decisions. Use the revision-guarded resume writer instead.
    final response = await store.request(
      'PatchResumesId',
      path: {'id': '$resumeID'},
      body: {'content': content},
      extra: {'if-match': '"revision-${baseline!['revision']}"'},
    );
    _check();
    if (integer(response.data['id']) != resumeID ||
        integer(response.data['revision']) <= integer(baseline!['revision'])) {
      throw const ApiFailure('保存结果暂未确认，请重试以核实状态');
    }
    await _saved({...current, ...response.data});
  });

  Future<void> _saved(Map<String, dynamic> record) async {
    _check();
    final resume = decodeResume(record);
    final index = store.resumes.indexWhere((r) => r.id == resumeID);
    if (index >= 0) {
      store.resumes[index] = resume;
    } else {
      store.resumes.add(resume);
    }
    phase = ResumePolishPhase.saved;
    store.changed();
    // Close the unused full-replacement job after the selected edits are saved.
    // Cleanup failures must never report a successfully saved resume as failed.
    try {
      if (jobID != null) {
        await store.request(
          'PostPolishJobsIdDiscard',
          path: {'id': '$jobID'},
          body: {},
        );
      }
    } catch (_) {}
    try {
      await _clear();
    } catch (_) {}
  }

  Future<void> discard() {
    if (busy && phase == ResumePolishPhase.generating && validSession) {
      cancelRequested = true;
      _emit();
      return Future.value();
    }
    return _run(_discardCurrent);
  }

  Future<void> _discardCurrent() async {
    // A lost PATCH response may already have committed the edits. Reconcile it
    // before clearing the receipt instead of implying the save was abandoned.
    if (pendingSave != null) {
      final current = await _current();
      if (_sameContent(current['content'], pendingSave)) {
        await _saved(current);
        return;
      }
    }
    if (jobID != null) {
      try {
        await store.request(
          'PostPolishJobsIdDiscard',
          path: {'id': '$jobID'},
          body: {},
        );
      } on ApiFailure catch (e) {
        if (e.code != 'JOB_STATE_CONFLICT' &&
            e.code != 'POLISH_JOB_NOT_FOUND') {
          rethrow;
        }
      }
      _check();
    }
    await _clear();
    jobID = null;
    baseline = null;
    pendingSave = null;
    changes = [];
    selected = {};
    _restoredSelection = null;
    conflict = false;
    cancelRequested = false;
    phase = ResumePolishPhase.setup;
  }

  @override
  void dispose() {
    _disposed = true;
    store.removeListener(_sessionChanged);
    super.dispose();
  }
}

bool _sameContent(dynamic a, dynamic b) {
  if (a is Map && b is Map) {
    return a.length == b.length &&
        a.keys.every(
          (key) => b.containsKey(key) && _sameContent(a[key], b[key]),
        );
  }
  if (a is List && b is List) {
    return a.length == b.length &&
        List.generate(
          a.length,
          (i) => i,
        ).every((i) => _sameContent(a[i], b[i]));
  }
  return a == b;
}
