import 'package:flutter/material.dart';

/// The sole system template uses the former business-blue typesetter.
/// Legacy layout IDs all resolve here without changing resume content.
enum ResumeLayout {
  standard('standard', '标准模板', '蓝色标题与分隔线，清晰的分组与留白', Color(0xFF245EA8));

  const ResumeLayout(this.id, this.title, this.description, this.accent);
  final String id, title, description;
  final Color accent;
  static ResumeLayout resolve(dynamic id) => standard;
}
