import 'dart:convert';

const resumePrivacyMask = '▒▒▒▒▒▒';

/// Strip identifying fields before typesetting, semantics or image loading.
/// The mask is a drawing instruction, never the original private text.
Map<String, dynamic> privateGuidancePreview(Map<String, dynamic> input) {
  final result = jsonDecode(jsonEncode(input)) as Map<String, dynamic>;
  final snapshot = result['snapshot'];
  if (snapshot is! Map<String, dynamic>) return result;
  const identities = {
    'educations': 'institution',
    'work_experiences': 'company',
    'certifications': 'issuer',
  };
  for (final section in identities.entries) {
    for (final entry
        in snapshot[section.key] is List ? snapshot[section.key] as List : []) {
      if (entry is! Map) continue;
      entry[section.value] = resumePrivacyMask;
      entry.remove('${section.value}_rich');
    }
  }
  snapshot['personal_info'] = {
    'full_name': resumePrivacyMask,
    'phone': '$resumePrivacyMask$resumePrivacyMask',
  };
  if (snapshot['projects'] is List) {
    for (final entry in snapshot['projects'] as List) {
      if (entry is Map) {
        entry.remove('url');
        entry.remove('url_rich');
      }
    }
  }
  snapshot['app_privacy_photo'] = '${result['photo_url'] ?? ''}'.isNotEmpty;
  result['photo_url'] = '';
  result.remove('photo_file_id');
  return result;
}
