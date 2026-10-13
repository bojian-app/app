import 'dart:io';

import 'package:bojian_mobile/app_store.dart';
import 'package:bojian_mobile/resume_market_document.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Market fields retain entry order and rich text, with safe HTML payload',
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
      final html = marketDocumentHtml(
        dom: {
          'html':
              '<h1>{{name}}</h1><p>{{#if preference}}</p><p>{{preference}}</p><p>{{/if}}</p>'
              '<p>{{#work_experiences}}</p><h2>{{title}}</h2><p>{{subtitle}} · {{start_date}}—{{end_date}}</p><p>{{detail}}</p><p>{{/work_experiences}}</p>'
              '<p>{{#if phone}}电话：{{phone}}{{/if}}</p>',
          'css': '@page {size:A4;margin:12mm} p{font-size:14px;line-height:1.5} h1{color:#245ea8}',
        },
        resume: resume,
        captureScript: File('assets/templates/html2canvas.min.js')
            .readAsStringSync(),
        rendererScript: File('assets/templates/market_renderer.js')
            .readAsStringSync(),
      );
      expect(html, isNot(contains('张三 </script>')));
      expect(html, contains(r'张三 \u003c/script>'));
      expect(html, contains("img-src data:"));
      // Standalone DOM fixture for browser pagination and capture QA.
      await Directory('build/previews').create(recursive: true);
      await File('build/previews/market-template-qa.html').writeAsString(html);
    },
  );
}
