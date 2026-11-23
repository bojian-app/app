// 把 App 内置的《用户协议》《隐私政策》导出为 JSON，供官网 /terms、/privacy 使用，
// 保证官网链接与 App 内文本一致。用法：
//   dart run tool/export_legal_documents.dart ../website/app/legal-documents.json
import 'dart:convert';
import 'dart:io';

import 'package:bojian_mobile/legal_document.dart';

Map<String, Object> _block(LegalBlock block) => switch (block) {
  LegalParagraph(:final text, :final emphasized) => {
    'type': 'paragraph',
    'text': text,
    'emphasized': emphasized,
  },
  LegalSubheading(:final text) => {'type': 'subheading', 'text': text},
  LegalTable(:final headers, :final rows) => {
    'type': 'table',
    'headers': headers,
    'rows': rows,
  },
};

Map<String, Object> _document(LegalDocument document) => {
  'title': document.title,
  'metadata': document.metadata,
  'introduction': [for (final p in document.introduction) _block(p)],
  'sections': [
    for (final section in document.sections)
      {
        'id': section.id,
        'title': section.title,
        'blocks': [for (final block in section.blocks) _block(block)],
      },
  ],
};

void main(List<String> args) {
  final output = args.isEmpty ? '../website/app/legal-documents.json' : args.first;
  final json = const JsonEncoder.withIndent('  ').convert({
    'versions': legalAgreementVersions,
    'terms': _document(userAgreementDocument),
    'privacy': _document(privacyPolicyDocument),
  });
  File(output).writeAsStringSync('$json\n');
  stdout.writeln('wrote $output');
}
