import 'package:flutter/material.dart';

import 'app_store.dart';

/// Keeps each entry's imported metadata and rich text while editing its fields.
class WorkExperienceFields {
  WorkExperienceFields(Map<String, dynamic> entry)
    : original = Map<String, dynamic>.from(entry),
      current = entry['current'] == true {
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
    initialDescription = fields['description']!.text.trim();
  }
  late final String initialDescription;
  final Map<String, dynamic> original;
  final Map<String, TextEditingController> fields = {};
  bool current;

  Map<String, dynamic> toJson() {
    final result = <String, dynamic>{...original, 'current': current};
    for (final entry in fields.entries) {
      result[entry.key] = entry.value.text.trim();
    }
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
