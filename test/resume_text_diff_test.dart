import 'package:bojian_mobile/resume_ai_optimization_models.dart';
import 'package:bojian_mobile/resume_text_diff.dart';
import 'package:flutter_test/flutter_test.dart';

String join(Iterable<TextDiffSegment> s) => s.map((v) => v.text).join();

void main() {
  test('diff reconstructs both versions and marks additions', () {
    const before = '负责开发预约页面，使用 Vue 实现表单。';
    const after = '负责开发预约与审批页面，使用 Vue 实现表单并校验时间冲突。';
    final diff = TextDiff.compare(before, after)!;
    expect(join(diff.original), before);
    expect(join(diff.revised), after);
    expect(diff.readable, isTrue);
    final inserted = diff.segments
        .where((s) => s.kind == TextDiffKind.insert)
        .map((s) => s.text)
        .join();
    expect(inserted, contains('审批'));
    expect(inserted, contains('校验时间冲突'));
    expect(inserted, isNot(contains('Vue')));
  });

  test('latin words and numbers stay whole', () {
    final diff = TextDiff.compare('使用 React 18 开发', '使用 Vue 18 开发')!;
    expect(
      diff.segments
          .where((s) => s.kind != TextDiffKind.equal)
          .map((s) => s.text),
      containsAll(['React', 'Vue']),
    );
  });

  test('whole-section changes retain their text and token similarity', () {
    final paragraph = '提升转化率。' * 2500;
    final same = TextDiff.compare(paragraph, paragraph)!;
    expect(same.segments.single.text, paragraph);
    expect(same.similarity, 1);
    expect(TextDiff.compare('', '')!.segments, isEmpty);
    for (final (before, after) in [
      ('', paragraph),
      (paragraph, ''),
      ('目标。', '目标。$paragraph'),
      ('$paragraph。', '新增。'),
    ]) {
      final diff = TextDiff.compare(before, after)!;
      expect(join(diff.original), before);
      expect(join(diff.revised), after);
      expect(diff.readable, isFalse);
      if (before.isEmpty || after.isEmpty) expect(diff.similarity, 0);
    }
  });

  test('complete rewrites are not marked token by token', () {
    final diff = TextDiff.compare('做网站', '主导支付结算系统重构上线')!;
    expect(diff.readable, isFalse);
  });

  test('locations use resume names and editor wording', () {
    final source = {
      'work_experiences': [
        {'company': '博简科技', 'position': '前端工程师'},
      ],
      'projects': [
        {'name': ''},
      ],
    };
    expect(
      PolishLocation.resolve('work_experiences.0.description', source).title,
      '博简科技 · 前端工程师 · 工作内容',
    );
    expect(
      PolishLocation.resolve('projects.0.achievements', source).title,
      '第 1 段 · 项目成果',
    );
    final self = PolishLocation.resolve('job_expectation.preference', source);
    expect(self.section, '自我评价');
    expect(self.title, '自我评价');
  });

  test('short shared fragments between edits merge into one phrase', () {
    const before = '全链路业务体系：搭建站点入驻、数据统计业务全链路体系，支撑线下设备智能化管控和亿级业务稳定运营。';
    const after =
        '全链路业务参与落地：全程参与站点入驻、数据统计等业务模块的需求设计与开发落地，支撑线下设备智能化管控与亿级业务稳定运营。';
    final diff = TextDiff.compare(before, after)!;
    expect(join(diff.original), before);
    expect(join(diff.revised), after);
    final s = diff.segments;
    for (var i = 1; i < s.length - 1; i++) {
      if (s[i].kind == TextDiffKind.equal &&
          s[i - 1].kind != TextDiffKind.equal &&
          s[i + 1].kind != TextDiffKind.equal) {
        expect(s[i].text.runes.length, greaterThan(3), reason: s[i].text);
      }
    }
  });

  test('length note only appears when the rewrite clearly trims or grows', () {
    PolishChange change(String before, String after) =>
        PolishChange(path: 'p', before: before, after: after, reason: '');
    expect(change('一二三四五六七八九十', '• 一二三四五六七八九').lengthNote, isNull);
    expect(change('一二三四五六七八九十', '一二三四').lengthNote, '原 10 字 → 4 字');
  });
}
