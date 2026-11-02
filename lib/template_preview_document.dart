import 'template_preview_data.dart';
export 'template_preview_data.dart';

import 'dart:convert';

import 'app_store.dart';
import 'resume_market_document.dart';
import 'resume_native_export.dart';

const templatePreviewFontAssets = resumeDocumentFontAssets;
const traceTemplatePreview = bool.fromEnvironment(
  'BOJIAN_TRACE_TEMPLATE_PREVIEW',
);

String templatePreviewDocument({
  required Map<String, dynamic> dom,
  required String rendererScript,
  required String previewScript,
  String photo = '',
  String author = '',
  int initialPage = 0,
  bool showPageActions = true,
}) => marketDocumentHtml(
  dom: dom,
  resume: ResumeDraft(id: 0, title: '模板示例'),
  fields: templatePreviewFields,
  photo: photo,
  captureScript: traceTemplatePreview ? 'window.bojianTrace=true;' : '',
  rendererScript: rendererScript,
  marketplacePreview: true,
  previewScript:
      'window.bojianPreviewOptions=${jsonEncode({'author': author, 'initialPage': initialPage, 'showPageActions': showPageActions}).replaceAll('<', r'\u003c')};\n$previewScript',
  fontStyles: resumeDocumentFontStyles,
);
