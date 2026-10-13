import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import 'design.dart';

const resumePhotoAspectRatio = 5 / 6;

Rect initialResumePhotoCrop(
  Size size, {
  double aspectRatio = resumePhotoAspectRatio,
}) {
  final width = math.min(size.width, size.height * aspectRatio) * .85;
  return Rect.fromCenter(
    center: size.center(Offset.zero),
    width: width,
    height: width / aspectRatio,
  );
}

Rect constrainResumePhotoCrop(
  Rect crop,
  Size size, {
  double aspectRatio = resumePhotoAspectRatio,
}) {
  final maximum = math.min(size.width, size.height * aspectRatio);
  final width = crop.width.clamp(math.min(40.0, maximum), maximum).toDouble();
  final height = width / aspectRatio;
  return Rect.fromLTWH(
    crop.left.clamp(0.0, size.width - width),
    crop.top.clamp(0.0, size.height - height),
    width,
    height,
  );
}

/// Produces the actual selected pixels, so every client and export uses the crop.
Future<XFile> writeResumePhotoCrop(
  ui.Image image,
  Rect crop, {
  double aspectRatio = resumePhotoAspectRatio,
}) async {
  final source = constrainResumePhotoCrop(
    crop,
    Size(image.width.toDouble(), image.height.toDouble()),
    aspectRatio: aspectRatio,
  );
  final width = math.min(1000, source.width.floor()).clamp(1, 1000);
  final height = (width / aspectRatio).round().clamp(1, 1200);
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawImageRect(
    image,
    source,
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    Paint()..filterQuality = FilterQuality.high,
  );
  final picture = recorder.endRecording();
  ui.Image? cropped;
  try {
    cropped = await picture.toImage(width, height);
    final data = await cropped.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) throw StateError('Unable to encode photo');
    final directory = await Directory.systemTemp.createTemp(
      'bojian-resume-photo-',
    );
    final file = File('${directory.path}/resume-photo.png');
    try {
      await file.writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
      return XFile(file.path);
    } catch (_) {
      await directory.delete(recursive: true);
      rethrow;
    }
  } finally {
    cropped?.dispose();
    picture.dispose();
  }
}

Future<void> discardResumePhotoCrop(XFile? file) async {
  if (file == null) return;
  final directory = File(file.path).parent;
  if (!directory.path
      .split(Platform.pathSeparator)
      .last
      .startsWith('bojian-resume-photo-')) {
    return;
  }
  try {
    if (await directory.exists()) await directory.delete(recursive: true);
  } catch (_) {
    /* Temporary cache can be reclaimed later. */
  }
}

class ResumePhotoCropPage extends StatefulWidget {
  const ResumePhotoCropPage({
    super.key,
    required this.file,
    this.aspectRatio = resumePhotoAspectRatio,
  });
  final double aspectRatio;
  final XFile file;
  @override
  State<ResumePhotoCropPage> createState() => _ResumePhotoCropPageState();
}

class _ResumePhotoCropPageState extends State<ResumePhotoCropPage> {
  ui.Image? image;
  Rect? crop;
  bool saving = false;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final bytes = await widget.file.readAsBytes();
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: 2048,
        allowUpscaling: false,
      );
      late ui.Image loaded;
      try {
        loaded = (await codec.getNextFrame()).image;
      } finally {
        codec.dispose();
      }
      if (!mounted) {
        loaded.dispose();
        return;
      }
      setState(() {
        image = loaded;
        crop = initialResumePhotoCrop(
          Size(loaded.width.toDouble(), loaded.height.toDouble()),
          aspectRatio: widget.aspectRatio,
        );
      });
    } catch (_) {
      if (mounted) setState(() => error = '无法读取照片，请返回重新选择');
    }
  }

  Future<void> _confirm() async {
    if (saving || image == null || crop == null) return;
    setState(() => saving = true);
    // Keep a separate image handle alive if the page is dismissed while encoding.
    final source = image!.clone();
    try {
      final file = await writeResumePhotoCrop(
        source,
        crop!,
        aspectRatio: widget.aspectRatio,
      );
      if (!mounted) {
        await discardResumePhotoCrop(file);
        return;
      }
      Navigator.pop(context, file);
    } catch (_) {
      if (mounted) {
        setState(() => saving = false);
        toast(context, '裁剪失败，请重试');
      }
    } finally {
      source.dispose();
    }
  }

  @override
  void dispose() {
    image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF171A21),
    appBar: AppBar(
      title: Text(widget.aspectRatio == 1 ? '裁剪头像' : '裁剪简历照片'),
      actions: [
        TextButton(
          onPressed: image == null || saving ? null : _confirm,
          child: Text(saving ? '处理中…' : '使用照片'),
        ),
      ],
    ),
    body: SafeArea(
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              '拖动裁剪框调整位置，拖动右下角或双指调整大小',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
          Expanded(
            child: error != null
                ? Center(
                    child: Text(
                      error!,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  )
                : image == null
                ? const Center(child: CircularProgressIndicator())
                : ResumePhotoCropCanvas(
                    image: image!,
                    aspectRatio: widget.aspectRatio,
                    onChanged: (value) => crop = value,
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              widget.aspectRatio == 1 ? '头像 · 1:1' : '简历照片 · 5:6',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
        ],
      ),
    ),
  );
}

class ResumePhotoCropCanvas extends StatefulWidget {
  const ResumePhotoCropCanvas({
    super.key,
    required this.image,
    required this.onChanged,
    this.aspectRatio = resumePhotoAspectRatio,
  });
  final double aspectRatio;
  final ui.Image image;
  final ValueChanged<Rect> onChanged;
  @override
  State<ResumePhotoCropCanvas> createState() => _ResumePhotoCropCanvasState();
}

class _ResumePhotoCropCanvasState extends State<ResumePhotoCropCanvas> {
  late Rect crop = initialResumePhotoCrop(
    sourceSize,
    aspectRatio: widget.aspectRatio,
  );
  Rect? start;
  Offset focal = Offset.zero;
  bool resizing = false;
  bool dragging = false;
  Size get sourceSize =>
      Size(widget.image.width.toDouble(), widget.image.height.toDouble());

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scale = math.min(
        (constraints.maxWidth - 32) / sourceSize.width,
        (constraints.maxHeight - 32) / sourceSize.height,
      );
      final imageRect = Rect.fromCenter(
        center: Offset(constraints.maxWidth / 2, constraints.maxHeight / 2),
        width: sourceSize.width * scale,
        height: sourceSize.height * scale,
      );
      final screenCrop = Rect.fromLTWH(
        imageRect.left + crop.left * scale,
        imageRect.top + crop.top * scale,
        crop.width * scale,
        crop.height * scale,
      );
      return GestureDetector(
        key: const ValueKey('resume-photo-crop-area'),
        behavior: HitTestBehavior.opaque,
        onScaleStart: (details) {
          start = crop;
          focal = details.localFocalPoint;
          resizing = (focal - screenCrop.bottomRight).distance <= 28;
          dragging = screenCrop.inflate(12).contains(focal);
        },
        onScaleUpdate: (details) {
          if (start == null || !dragging) return;
          final delta = (details.localFocalPoint - focal) / scale;
          Rect next;
          if (resizing && details.pointerCount == 1) {
            final width =
                start!.width + (delta.dx + delta.dy * widget.aspectRatio) / 2;
            next = Rect.fromLTWH(
              start!.left,
              start!.top,
              width,
              width / widget.aspectRatio,
            );
          } else if (details.pointerCount > 1) {
            final width = start!.width * details.scale;
            next = Rect.fromCenter(
              center: start!.center + delta,
              width: width,
              height: width / widget.aspectRatio,
            );
          } else {
            next = start!.shift(delta);
          }
          setState(
            () => crop = constrainResumePhotoCrop(
              next,
              sourceSize,
              aspectRatio: widget.aspectRatio,
            ),
          );
          widget.onChanged(crop);
        },
        onScaleEnd: (_) => start = null,
        child: RepaintBoundary(
          child: CustomPaint(
            size: Size(constraints.maxWidth, constraints.maxHeight),
            painter: ResumePhotoCropPainter(
              widget.image,
              imageRect,
              screenCrop,
            ),
          ),
        ),
      );
    },
  );
}

class ResumePhotoCropPainter extends CustomPainter {
  ResumePhotoCropPainter(this.image, this.imageRect, this.crop);
  final ui.Image image;
  final Rect imageRect;
  final Rect crop;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      imageRect,
      Paint()..filterQuality = FilterQuality.medium,
    );
    final mask = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRect(crop);
    canvas.drawPath(mask, Paint()..color = const Color(0xA6000000));
    canvas.drawRect(
      crop,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    final grid = Paint()
      ..color = Colors.white38
      ..strokeWidth = 1;
    for (var i = 1; i < 3; i++) {
      canvas.drawLine(
        Offset(crop.left + crop.width * i / 3, crop.top),
        Offset(crop.left + crop.width * i / 3, crop.bottom),
        grid,
      );
      canvas.drawLine(
        Offset(crop.left, crop.top + crop.height * i / 3),
        Offset(crop.right, crop.top + crop.height * i / 3),
        grid,
      );
    }
    canvas.drawCircle(crop.bottomRight, 11, Paint()..color = Colors.white);
    canvas.drawLine(
      crop.bottomRight + const Offset(-4, 4),
      crop.bottomRight + const Offset(4, -4),
      Paint()
        ..color = const Color(0xFF171A21)
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant ResumePhotoCropPainter oldDelegate) =>
      image != oldDelegate.image ||
      imageRect != oldDelegate.imageRect ||
      crop != oldDelegate.crop;
}
