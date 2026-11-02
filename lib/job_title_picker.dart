import 'package:flutter/material.dart';

import 'app_store.dart';
import 'resume_option_picker.dart';

Future<String?> showJobTitlePicker(
  BuildContext context, {
  required AppStore store,
  String initialValue = '',
  String title = '选择意向职位',
}) => showResumeOptionPicker(
  context,
  store: store,
  initialValue: initialValue,
  title: title,
);

class JobTitlePicker extends ResumeOptionPicker {
  const JobTitlePicker({
    super.key,
    required super.store,
    super.initialValue = '',
    super.title = '选择意向职位',
  });
}
