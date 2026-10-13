import 'package:bojian_mobile/app_store.dart';
import 'package:bojian_mobile/resume_document.dart';
import 'package:bojian_mobile/resume_guidance_privacy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Old shared resumes are masked before drawing and accessibility', () {
    final input = <String, dynamic>{
      'title': '小林的简历',
      'question': '请联系 lin@example.com',
      'photo_url': 'https://example.com/private-avatar.jpg',
      'snapshot': {
        'personal_info': {
          'full_name': '小林',
          'phone': '13812345678',
          'email': 'lin@example.com',
          'birth_date': '1998-01-02',
          'gender': 'female',
          'address': '私人地址',
        },
        'educations': [
          {'institution': '青禾大学', 'degree': '本科', 'field_of_study': '计算机'},
        ],
        'work_experiences': [
          {
            'company': '云桥科技',
            'position': '前端',
            'description': '负责产品开发，服务云桥科技业务',
          },
        ],
        'projects': [
          {
            'name': '云桥协作平台',
            'description': '项目成果',
            'url': 'https://private.example.com',
            'url_rich': {'text': '个人主页'},
          },
        ],
      },
    };
    final masked = privateGuidancePreview(input);
    final snapshot = masked['snapshot'] as Map;
    expect((snapshot['personal_info'] as Map)['full_name'], resumePrivacyMask);
    expect(
      (snapshot['work_experiences'] as List).first['company'],
      resumePrivacyMask,
    );
    expect(
      (snapshot['educations'] as List).first['institution'],
      resumePrivacyMask,
    );
    expect((snapshot['projects'] as List).first['name'], '云桥协作平台');
    expect(
      (snapshot['work_experiences'] as List).first['description'],
      '负责产品开发，服务云桥科技业务',
    );
    expect(masked['question'], input['question']);
    expect(masked['photo_url'], '');
    expect(
      (input['snapshot'] as Map)['personal_info'],
      containsPair('full_name', '小林'),
    );
    final resume = decodeResume({
      'id': 0,
      'title': masked['title'],
      'content': masked['snapshot'],
    });
    final document = ResumeDocument(resume);
    addTearDown(document.dispose);
    final accessible = document.pages
        .expand((p) => p.ink)
        .map((i) => i.visibleText)
        .join('\n');
    expect(accessible, contains('隐私信息已隐藏'));
    expect(accessible, isNot(contains('小林')));
    expect(accessible, isNot(contains('▒')));
    expect(accessible, contains('负责产品开发'));
    expect(accessible, contains('项目成果'));
    expect(accessible, contains('云桥协作平台'));
    expect((snapshot['projects'] as List).first.containsKey('url'), isFalse);
    expect(accessible, contains('前端'));
    expect(accessible, contains('本科'));
    expect(accessible, contains('计算机'));
    expect(accessible, contains('负责产品开发，服务云桥科技业务'));
    expect(accessible, isNot(contains('青禾大学')));
    expect(document.pages.first.photo, isNotNull);
  });

  test(
    'New shares without private fields still use anonymous placeholders',
    () {
      final masked = privateGuidancePreview({
        'title': '前端简历',
        'snapshot': {
          'educations': [
            {'institution': '大学', 'degree': '本科'},
          ],
        },
      });
      final personal = (masked['snapshot'] as Map)['personal_info'] as Map;
      expect(personal['full_name'], resumePrivacyMask);
      expect(personal.containsKey('birth_date'), false);
      expect(personal.containsKey('gender'), false);
      expect((masked['snapshot'] as Map)['educations'], [
        {'institution': resumePrivacyMask, 'degree': '本科'},
      ]);
      expect(masked['photo_url'], '');
    },
  );
}
