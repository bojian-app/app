import 'package:flutter/material.dart';

import 'app_store.dart';

class EducationFields {
  EducationFields(Map<String, dynamic> entry)
    : original = Map<String, dynamic>.from(entry) {
    for (final key in [
      'institution',
      'degree',
      'field_of_study',
      'start_date',
      'end_date',
      'campus_experience',
      'thesis_title',
      'thesis_description',
    ]) {
      final value = entry[key]?.toString() ?? '';
      fields[key] = TextEditingController(
        text: richKeys.contains(key) && value.isEmpty
            ? plainContent(entry['${key}_rich'])
            : value,
      );
      initialValues[key] = fields[key]!.text.trim();
    }
  }
  static const richKeys = ['campus_experience', 'thesis_description'];
  final Map<String, dynamic> original;
  final Map<String, TextEditingController> fields = {};
  final Map<String, String> initialValues = {};

  Map<String, dynamic> toJson() {
    final result = <String, dynamic>{...original};
    for (final entry in fields.entries) {
      result[entry.key] = entry.value.text.trim();
      if (richKeys.contains(entry.key) &&
          result[entry.key] != initialValues[entry.key]) {
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
