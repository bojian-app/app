import 'dart:convert';

import 'package:bojian_mobile/api/bojian_api.dart';
import 'package:bojian_mobile/resume_native_export.dart';

/// Test fixture: builds an export layout from a captured JSON page model.
ResumeExportLayout marketExportLayout(
  List data, {
  Map? wordModel,
  bool requiresWordFlow = false,
}) {
  if (data.isEmpty || data.length > 30) throw const ApiFailure('模板导出页数无效');
  double n(Map value, String key) => (value[key] as num).toDouble();
  return ResumeExportLayout(
    [
      for (final page in data.cast<Map>())
        ResumeExportPage(
          background: page['background'] is String
              ? ResumeExportPicture(
                  base64Decode(page['background'] as String),
                  0,
                  0,
                  595.28,
                  841.89,
                )
              : null,
          lines: [
            for (final line in (page['lines'] as List).cast<Map>())
              ResumeExportLine(
                top: n(line, 'top'),
                height: n(line, 'height'),
                baseline: n(line, 'baseline'),
                paragraphId: line['paragraph_id'] as String?,
                paragraphLeft: (line['paragraph_left'] as num?)?.toDouble(),
                paragraphWidth: (line['paragraph_width'] as num?)?.toDouble(),
                spans: [
                  for (final span in (line['spans'] as List).cast<Map>())
                    ResumeExportSpan(
                      text: span['text'] as String,
                      wordText: span['word_text'] as String?,
                      x: n(span, 'x'),
                      width: n(span, 'width'),
                      size: n(span, 'size'),
                      color: (span['color'] as num).toInt(),
                      bold: span['bold'] == true,
                      weight: (span['weight'] as num?)?.toInt(),
                      italic: span['italic'] == true,
                      underline: span['underline'] == true,
                      strike: span['strike'] == true,
                    ),
                ],
              ),
          ],
          rules: [
            for (final rule in (page['rules'] as List).cast<Map>())
              ResumeExportRule(
                n(rule, 'x'),
                n(rule, 'y'),
                n(rule, 'width'),
                n(rule, 'thickness'),
                (rule['color'] as num).toInt(),
                height: n(rule, 'height'),
              ),
          ],
          pictures: [
            for (final image in (page['pictures'] as List).cast<Map>())
              ResumeExportPicture(
                base64Decode(image['data'] as String),
                n(image, 'x'),
                n(image, 'y'),
                n(image, 'width'),
                n(image, 'height'),
              ),
          ],
        ),
    ],
    requiresWordFlow: requiresWordFlow || wordModel != null,
    wordLayout: wordModel == null
        ? null
        : ResumeExportLayout(
            [
              ResumeExportPage(
                wordFlow: true,
                lines: [
                  for (final raw in (wordModel['lines'] as List).cast<Map>())
                    ResumeExportLine(
                      top: n(raw, 'top'),
                      height: n(raw, 'height'),
                      baseline: n(raw, 'baseline'),
                      paragraphId: raw['paragraph_id'] as String?,
                      paragraphField: raw['paragraph_field'] as String?,
                      paragraphLeft: n(raw, 'paragraph_left'),
                      paragraphWidth: n(raw, 'paragraph_width'),
                      paragraphBottom: n(raw, 'paragraph_bottom'),
                      paragraphAlignRight: raw['paragraph_align_right'] == true,
                      spans: [
                        for (final span in (raw['spans'] as List).cast<Map>())
                          ResumeExportSpan(
                            text: span['text'] as String,
                            x: n(span, 'x'),
                            width: n(span, 'width'),
                            size: n(span, 'size'),
                            color: (span['color'] as num).toInt(),
                            weight: (span['weight'] as num).toInt(),
                            italic: span['italic'] == true,
                            underline: span['underline'] == true,
                            strike: span['strike'] == true,
                          ),
                      ],
                    ),
                ],
                rules: [
                  for (final raw in (wordModel['rules'] as List).cast<Map>())
                    ResumeExportRule(
                      n(raw, 'x'),
                      n(raw, 'y'),
                      n(raw, 'width'),
                      n(raw, 'thickness'),
                      (raw['color'] as num).toInt(),
                    ),
                ],
                pictures: [
                  for (final raw in (wordModel['pictures'] as List).cast<Map>())
                    ResumeExportPicture(
                      base64Decode(raw['data'] as String),
                      n(raw, 'x'),
                      n(raw, 'y'),
                      n(raw, 'width'),
                      n(raw, 'height'),
                    ),
                ],
              ),
            ],
            wordMargins: (wordModel['margins'] as Map).map(
              (key, value) =>
                  MapEntry(key as String, (value as num).toDouble()),
            ),
          ),
  );
}
