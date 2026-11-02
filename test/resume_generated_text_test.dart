import 'package:bojian_mobile/app_store.dart';
import 'package:bojian_mobile/design.dart';
import 'package:bojian_mobile/resume_generated_text.dart';
import 'package:bojian_mobile/resume_pages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

void main() {
  test('Legacy annotations are removed without changing original data or real body text', () {
    final source = <String, dynamic>{
      'job_expectation': {'city': '杭州（建议）', 'preference': '岗位示例中的能力侧重：团队协作'},
      'projects': [
        {'name': '【岗位示例·非实际履历】订单系统', 'description': '收集客户建议，优化业务流程'},
      ],
      'work_experiences': [
        {'position': '【岗位示例·非实际履历】开发工程师'},
      ],
      'educations': [
        {'campus_experience': '【学习示例·非实际学历】课程实践'},
      ],
      'skills': [
        {'description': '示例方案中的能力应用：接口设计'},
      ],
    };
    final draft = decodeResume({'content': source});
    expect(draft.city, '杭州');
    expect(draft.source['job_expectation']['city'], '杭州');
    expect(draft.source['projects'][0]['name'], '订单系统');
    expect(draft.source['projects'][0]['description'], '收集客户建议，优化业务流程');
    expect(draft.source['work_experiences'][0]['position'], '开发工程师');
    expect(draft.source['educations'][0]['campus_experience'], '课程实践');
    expect(draft.source['skills'][0]['description'], '接口设计');
    expect(source['job_expectation']['city'], '杭州（建议）');
    expect(cleanResumeGeneratedText('上海 ( 建议 ) ', city: true), '上海');
  });
  for (final contact in [
    ('', 'example@bojian.com', '邮箱：example@bojian.com'),
    ('13812345678', 'example@bojian.com', '电话：13812345678'),
    ('', '', '添加电话或邮箱'),
  ]) {
    testWidgets('Overview contact fallback ${contact.$3}', (tester) async {
      final store = await testStore(authenticated: true);
      addTearDown(store.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: ResumeEditor(
            store: store,
            draft: ResumeDraft(
              id: 0,
              title: '简历',
              name: '好名字',
              phone: contact.$1,
              email: contact.$2,
            ),
          ),
        ),
      );
      expect(find.text(contact.$3), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
