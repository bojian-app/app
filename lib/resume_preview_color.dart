import 'package:flutter/material.dart';

/// Rec. 709 luminance matches CSS grayscale(1); alpha and geometry stay intact.
const resumeGrayscaleFilter = ColorFilter.matrix([
  .2126,
  .7152,
  .0722,
  0,
  0,
  .2126,
  .7152,
  .0722,
  0,
  0,
  .2126,
  .7152,
  .0722,
  0,
  0,
  0,
  0,
  0,
  1,
  0,
]);

class ResumePreviewColor extends StatelessWidget {
  const ResumePreviewColor({
    super.key,
    required this.monochrome,
    required this.child,
  });
  final bool monochrome;
  final Widget child;

  @override
  Widget build(BuildContext context) => ColorFiltered(
    colorFilter: monochrome
        ? resumeGrayscaleFilter
        : const ColorFilter.mode(Colors.transparent, BlendMode.dst),
    child: child,
  );
}
