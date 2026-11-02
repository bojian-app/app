import 'package:bojian_mobile/app_store.dart';
import 'package:bojian_mobile/resume_editor_progress.dart';
import 'package:flutter_test/flutter_test.dart';

ResumeEditorProgress progress({
  Map<String, String> fields = const {},
  List<Map<String, dynamic>> work = const [],
  List<Map<String, dynamic>> projects = const [],
  List<Map<String, dynamic>> education = const [],
  List<Map<String, dynamic>> skills = const [],
}) => resumeEditorProgress(
  fields: fields,
  work: work,
  projects: projects,
  education: education,
  skills: skills,
);

void main() {
  test('Basic information is one group requiring name and either contact', () {
    for (final fields in [
      <String, String>{},
      {'name': '李明'},
      {'phone': '13812345678'},
      {'email': 'user@example.com'},
      {'name': '李明', 'phone': '  ', 'email': '\n'},
    ]) {
      expect(progress(fields: fields).filled, 0);
    }
    for (final fields in [
      {'name': '李明', 'phone': '13812345678'},
      {'name': '李明', 'email': 'user@example.com'},
      {'name': '李明', 'phone': '13812345678', 'email': 'user@example.com'},
      // Completeness checks presence; format validation belongs to the input flow.
      {'name': '李明', 'phone': '123'},
    ]) {
      expect(progress(fields: fields).filled, 1);
    }
  });
  test('Job intention requires both position and city; summary is ignored', () {
    expect(
      progress(fields: {'position': '开发', 'summary': '完整的自我评价'}).filled,
      0,
    );
    expect(progress(fields: {'city': '广州'}).filled, 0);
    expect(progress(fields: {'position': '开发', 'city': '广州'}).filled, 1);
    expect(progress(fields: {'position': '开发', 'city': ' \n '}).filled, 0);
  });
  const work = {
    'company': '测试公司',
    'position': '开发',
    'start_date': '2022-01',
    'end_date': '2025-01',
    'description': '开发业务系统',
  };
  const project = {
    'name': '业务平台',
    'role': '开发',
    'start_date': '2023-01',
    'end_date': '2024-01',
    'description': '项目背景',
    'achievements': '交付业务流程',
  };
  const education = {
    'institution': '测试大学',
    'field_of_study': '计算机',
    'start_date': '2018-09',
    'end_date': '2022-06',
    'campus_experience': '课程实践',
  };
  const skill = {'name': 'Flutter', 'description': '跨平台应用开发'};
  const fields = {
    'name': '李明',
    'email': 'user@example.com',
    'position': '开发',
    'city': '广州',
  };
  test('All required fields in the same record are needed; excluded fields do not matter', () {
    expect(
      progress(
        fields: fields,
        work: [work],
        projects: [project],
        education: [education],
        skills: [skill],
      ).percent,
      100,
    );
    final groups = {
      'work': work,
      'projects': project,
      'education': education,
      'skills': skill,
    };
    for (final group in groups.entries) {
      for (final key in group.value.keys) {
        final partial = Map<String, dynamic>.of(group.value)..[key] = ' ';
        final rows = [
          partial,
          {key: group.value[key]},
        ];
        final result = progress(
          fields: fields,
          work: group.key == 'work' ? rows : [work],
          projects: group.key == 'projects' ? rows : [project],
          education: group.key == 'education' ? rows : [education],
          skills: group.key == 'skills' ? rows : [skill],
        );
        expect(
          result.filled,
          5,
          reason: 'Missing ${group.key}.$key must not earn full score',
        );
      }
    }
    expect(
      progress(
        fields: fields,
        work: [work, work],
        projects: [project],
        education: [education],
        skills: [skill],
      ).filled,
      6,
    );
  });
  test('Current employment does not require an end date', () {
    expect(
      progress(
        work: [
          {...work, 'end_date': '', 'current': true},
        ],
      ).filled,
      1,
    );
    expect(
      progress(
        work: [
          {...work, 'end_date': '', 'current': false},
        ],
      ).filled,
      0,
    );
  });
  test('Excluded-only values, empty records and hints cannot earn points', () {
    expect(
      progress(
        fields: {'name': '姓名', 'phone': '待填写', 'summary': '自我评价'},
        work: [
          {},
          {'industry': '软件', 'current': true},
        ],
        projects: [
          {'url': 'https://example.com'},
        ],
        education: [
          {'degree': '本科', 'thesis_title': '论文', 'thesis_description': '内容'},
        ],
        skills: [
          {'name': '技能'},
        ],
      ).percent,
      0,
    );
  });
  test('Loading and saving use required fields and rich text consistently', () {
    final content = <String, dynamic>{
      'personal_info': {'full_name': '李明', 'email': 'user@example.com'},
      'job_expectation': {'position': '开发', 'city': '广州'},
      'work_experiences': [
        {...work, 'description': '', 'description_rich': richContent('工作内容')},
      ],
      'projects': [project],
      'educations': [education],
      'skills': [skill],
    };
    final draft = decodeResume({'content': content});
    expect(draft.progress, 1);
    content['certifications'] = [
      {'name': '证书'},
    ];
    (content['job_expectation'] as Map)['preference'] = '自我评价';
    expect(decodeResume({'content': content}).progress, 1);
    content['projects'] = [
      {...project, 'start_date': ''},
    ];
    expect(decodeResume({'content': content}).progress, 5 / 6);
  });
}
