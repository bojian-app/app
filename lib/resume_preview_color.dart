import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Lightness of a color with [lightness] (0–1) after a typical monochrome
/// laser print: drivers weigh channels by Rec. 601 luma, toner spread darkens
/// the midtones, and the faintest tints fall below the first halftone dot.
double printedLightness(double lightness) {
  final ink = 1 - lightness.clamp(0.0, 1.0);
  final t = ((ink - .03) / .05).clamp(0.0, 1.0);
  return 1 - (ink + .6 * ink * (1 - ink)) * t * t * (3 - 2 * t);
}

/// Rec. 601 luma, the weighting print drivers use for grayscale.
const _printLuma = [.299, .587, .114];

/// Fallback without shader filters: the print luma without the tone curve.
final _printGrayMatrix = ColorFilter.matrix([
  for (var row = 0; row < 3; row++) ...[..._printLuma, 0, 0],
  0,
  0,
  0,
  1,
  0,
]);

/// SVG filter `#print-gray` for HTML previews, the same simulation as
/// [ResumePreviewColor].
final resumePrintGraySvg = () {
  final table = [
    for (var i = 0; i <= 32; i++) printedLightness(i / 32).toStringAsFixed(4),
  ].join(' ');
  final luma = _printLuma.join(' ');
  return '<svg width="0" height="0" style="position:absolute" aria-hidden="true">'
      '<filter id="print-gray" color-interpolation-filters="sRGB">'
      '<feColorMatrix type="matrix" values="$luma 0 0 $luma 0 0 $luma 0 0 0 0 0 1 0"/>'
      '<feComponentTransfer>'
      '<feFuncR type="table" tableValues="$table"/>'
      '<feFuncG type="table" tableValues="$table"/>'
      '<feFuncB type="table" tableValues="$table"/>'
      '</feComponentTransfer></filter></svg>';
}();

/// CSS filter value of the black-and-white print preview.
const resumePrintGrayCss = 'url(#print-gray)';

ui.FragmentShader? _printGrayShader;
final _printGrayLoad = ui.FragmentProgram.fromAsset('shaders/print_gray.frag')
    .then((program) => _printGrayShader = program.fragmentShader());

/// Shows its child as a monochrome print would come out when [monochrome].
/// The widget tree stays the same either way, so toggling keeps the child's
/// state.
class ResumePreviewColor extends StatefulWidget {
  const ResumePreviewColor({
    super.key,
    required this.monochrome,
    required this.child,
  });
  final bool monochrome;
  final Widget child;

  @override
  State<ResumePreviewColor> createState() => _ResumePreviewColorState();
}

class _ResumePreviewColorState extends State<ResumePreviewColor> {
  @override
  void initState() {
    super.initState();
    if (_printGrayShader == null && ui.ImageFilter.isShaderFilterSupported) {
      _printGrayLoad.then((_) {
        if (mounted) setState(() {});
      }, onError: (_) {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final shader = ui.ImageFilter.isShaderFilterSupported
        ? _printGrayShader
        : null;
    return ColorFiltered(
      colorFilter: widget.monochrome && shader == null
          ? _printGrayMatrix
          : const ColorFilter.mode(Colors.transparent, BlendMode.dst),
      child: ImageFiltered(
        enabled: widget.monochrome && shader != null,
        imageFilter: shader == null
            ? ui.ImageFilter.matrix(Matrix4.identity().storage)
            : ui.ImageFilter.shader(shader),
        child: widget.child,
      ),
    );
  }
}
