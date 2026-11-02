import 'package:flutter/material.dart';

import 'app_store.dart';

/// Keeps each entry's imported metadata and rich text while editing its fields.
class WorkExperienceFields {
  WorkExperienceFields(Map<String, dynamic> entry)
    : original = Map<String, dynamic>.from(entry) {
    for (final key in [
      'company',
      'position',
      'industry',
      'start_date',
      'end_date',
      'description',
    ]) {
      final value = entry[key]?.toString() ?? '';
      fields[key] = TextEditingController(
        text: key == 'description' && value.isEmpty
            ? plainContent(entry['description_rich'])
            : value,
      );
    }
    if (entry['current'] == true) fields['end_date']!.text = '至今';
    initialDescription = fields['description']!.text.trim();
  }
  late final String initialDescription;
  final Map<String, dynamic> original;
  final Map<String, TextEditingController> fields = {};
  bool get current => fields['end_date']!.text.trim() == '至今';

  String? dateRangeError({DateTime? today}) {
    final startText = fields['start_date']!.text.trim();
    final endText = fields['end_date']!.text.trim();
    if (startText.isEmpty || endText.isEmpty) return null;
    final start = parseWorkDate(startText, today: today);
    final end = parseWorkDate(endText, today: today);
    if (start == null || end == null) return '请选择有效的起止日期';
    return end.isAfter(start) ? null : '结束时间必须晚于开始时间';
  }

  Map<String, dynamic> toJson() {
    final result = <String, dynamic>{...original, 'current': current};
    for (final entry in fields.entries) {
      result[entry.key] = entry.value.text.trim();
    }
    if (current) result['end_date'] = '';
    if (result['description'] != initialDescription) {
      result['description_rich'] = null;
    }
    return result;
  }

  void dispose() {
    for (final controller in fields.values) {
      controller.dispose();
    }
  }
}

/// Formats display dates without changing the full date stored in the resume.
String formatResumeMonth(Object? value) {
  final text = value?.toString().trim() ?? '';
  if (text.isEmpty || text == '至今') return text;
  final date = parseWorkDate(text.replaceAll('/', '-').replaceAll('.', '-'));
  if (date == null) return text;
  return '${date.year.toString().padLeft(4, '0')}/${date.month.toString().padLeft(2, '0')}';
}

// Existing month-only records remain readable until the user edits them.
DateTime? parseWorkDate(String value, {DateTime? today}) {
  value = value.trim();
  if (value == '至今') {
    final now = today ?? DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }
  final match = RegExp(r'^(\d{4})-(\d{1,2})(?:-(\d{1,2}))?$').firstMatch(value);
  if (match == null) return null;
  final year = int.parse(match[1]!);
  final month = int.parse(match[2]!);
  final day = int.parse(match[3] ?? '1');
  final result = DateTime(year, month, day);
  return result.year == year && result.month == month && result.day == day
      ? result
      : null;
}
