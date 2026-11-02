import 'package:flutter_test/flutter_test.dart';
import 'package:bojian_mobile/app_store.dart';
import 'package:bojian_mobile/resume_market_document.dart';

void main() {
  test('V2 fields preserve order, age label, thesis title and rich text', () {
    final fields = marketResumeFields(decodeResume({'content': {
      'app_section_order': ['projects', 'educations'],
      'personal_info': {'full_name': '示例', 'birth_date': '2000-01-01', 'birth_date_display_mode': 'age'},
      'educations': [{'institution': '示例大学', 'thesis_title': '论文标题', 'thesis_description_rich': {'blocks': [{'kind': 'paragraph', 'spans': [{'text': '论文正文', 'bold': true}]}]}}],
      'certifications': [{'name': '证书', 'date': '2024-05-06'}],
      'work_experiences': [{'company': '公司', 'current': true}],
    }}));
    expect(fields['birth_date_label'], '年龄');
    expect((fields['section_order'] as List).first, 'projects');
    final education = (fields['educations'] as List).single as Map;
    expect(education['secondary_detail'], '论文标题\n论文正文');
    expect((education['secondary_detail_rich']['blocks'] as List).length, 2);
    expect((fields['certifications'] as List).single['start_date'], '2024-05-06');
    expect((fields['work_experiences'] as List).single['end_date'], '至今');
    expect(marketTemplateProtocol({'schema': {'protocol_version': 2}}), 2);
    expect(marketTemplateProtocol({'html': '<p>{{name}}</p>'}), 1);
  });
}
