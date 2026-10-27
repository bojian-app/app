import 'package:flutter/material.dart';

/// Editor roles use the 12 / 14 / 18 size scale documented in
/// docs/resume-editor-typography.md. Flutter applies system text scaling.
abstract final class ResumeEditorTypography {
  static const caption = TextStyle(fontSize: 12, height: 1.5);
  static const body = TextStyle(fontSize: 14, height: 1.5);
  static const action = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.5,
  );
  static const entryTitle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.5,
  );
  static const title = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.4,
  );
}
