import 'package:bojian_mobile/app_store.dart';
import 'package:bojian_mobile/resume_market_document.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Market fields retain entry order and rich text',
    () async {
      final resume = ResumeDraft(
        id: 1,
        title: '模板测试',
        name: '张三 </script>',
        source: {
          'personal_info': {'gender': '不透露'},
          'job_expectation': {'preference': '求职意向'},
          'educations': [
            {
              'institution': '测试大学',
              'degree': '本科',
              'field_of_study': '计算机',
              'campus_experience': '经历',
            },
          ],
          'work_experiences': [
            for (var i = 0; i < 8; i++)
              {
                'company': '公司 $i',
                'position': '工程师',
                'start_date': '2020-01',
                'is_current': i == 0,
                'description': '旧正文',
                'description_rich': richContent(
                  List.filled(24, '真实工作内容与成果，保留换行和文字顺序。').join('\n'),
                ),
              },
          ],
        },
      );
      final fields = marketResumeFields(resume);
      expect(fields['gender'], '');
      expect(fields['educations'][0]['subtitle'], '本科');
      expect(fields['educations'][0]['auxiliary'], '计算机');
      expect(fields['work_experiences'][0]['end_date'], '至今');
      expect(fields['work_experiences'][1]['title'], '公司 1');
      expect(fields['work_experiences'][0]['detail'], isNot(contains('旧正文')));
    },
  );
}
