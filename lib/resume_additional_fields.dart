import 'package:flutter/material.dart';

import 'app_store.dart';

class ResumeEntryFields {
  ResumeEntryFields(
    Map<String, dynamic> entry,
    List<String> keys, {
    this.richKeys = const [],
  }) : original = Map<String, dynamic>.from(entry) {
    for (final key in keys) {
      final value = entry[key]?.toString() ?? '';
      fields[key] = TextEditingController(
        text: value.isEmpty && richKeys.contains(key)
            ? plainContent(entry['${key}_rich'])
            : value,
      );
      initial[key] = fields[key]!.text.trim();
    }
  }
  final Map<String, dynamic> original;
  final List<String> richKeys;
  final fields = <String, TextEditingController>{};
  final initial = <String, String>{};

  Map<String, dynamic> toJson() {
    final result = <String, dynamic>{...original};
    for (final entry in fields.entries) {
      result[entry.key] = entry.value.text.trim();
      if (richKeys.contains(entry.key) &&
          result[entry.key] != initial[entry.key]) {
        result['${entry.key}_rich'] = null;
      }
    }
    return result;
  }

  void dispose() {
    for (final controller in fields.values) {
      controller.dispose();
    }
  }
}

String resumeGenderLabel(Object? value) => switch (value) {
  'male' || '男' => '男',
  'female' || '女' => '女',
  _ => '',
};

int? resumeAge(String value, {DateTime? now}) {
  final match = RegExp(r'^(\d{4})[-./](\d{1,2})[-./](\d{1,2})$')
      .firstMatch(value.trim());
  if (match == null) return null;
  final year = int.parse(match[1]!);
  final month = int.parse(match[2]!);
  final day = int.parse(match[3]!);
  final birth = DateTime(year, month, day);
  final current = now ?? DateTime.now();
  if (birth.year != year ||
      birth.month != month ||
      birth.day != day ||
      birth.isAfter(current)) {
    return null;
  }
  return current.year -
      year -
      (current.month < month || current.month == month && current.day < day
          ? 1
          : 0);
}

String resumeBirthLabel(Map personal, {DateTime? now}) {
  final value = personal['birth_date']?.toString() ?? '';
  if (personal['birth_date_display_mode'] == 'age') {
    final age = resumeAge(value, now: now);
    if (age != null) return '$age 岁';
  }
  return value;
}
