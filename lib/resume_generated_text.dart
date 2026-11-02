/// Removes legacy AI annotations from saved editable fields, never their body.
String cleanResumeGeneratedText(String value, {bool city = false}) {
  var text = value.trim();
  final prefix = RegExp(
    r'^(?:【(?:岗位示例[·・：:]?非实际履历|岗位示例|学习示例[·・：:]?非实际学历|学习示例)】|岗位示例中的能力侧重[：:]|示例方案中的能力应用[：:]|示例方案涉及[：:]?|岗位示例[：:]|学习示例[：:])\s*',
  );
  while (prefix.hasMatch(text)) {
    text = text.replaceFirst(prefix, '').trimLeft();
  }
  if (city) {
    text = text.replaceFirst(RegExp(r'\s*[（(]\s*建议\s*[）)]\s*$'), '').trim();
  }
  return text;
}

Map<String, dynamic> cleanResumeGeneratedContent(Map<String, dynamic> content) {
  final result = Map<String, dynamic>.from(content);
  final job = content['job_expectation'];
  if (job is Map) {
    result['job_expectation'] = {
      ...job,
      if (job['city'] is String)
        'city': cleanResumeGeneratedText(job['city'], city: true),
      if (job['preference'] is String)
        'preference': cleanResumeGeneratedText(job['preference']),
    };
  }
  for (final key in ['work_experiences', 'projects', 'educations', 'skills']) {
    if (content[key] is! List) continue;
    result[key] = (content[key] as List).map((row) {
      if (row is! Map) return row;
      return <String, dynamic>{
        for (final item in row.entries)
          item.key.toString(): item.value is String
              ? cleanResumeGeneratedText(item.value)
              : item.value,
      };
    }).toList();
  }
  return result;
}
