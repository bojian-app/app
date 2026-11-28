import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'startup_run.dart';

/// One drawing cut from the source artwork. [crop] and [anchor] are in source
/// pixels, so the bundled file may have any resolution.
class StartupSprite {
  const StartupSprite(
    this.name, {
    required this.crop,
    required this.anchor,
    required this.scale,
    this.lift = 0,
  });
  final String name;
  final Rect crop;
  final Offset anchor;

  /// Scene units per source pixel.
  final double scale;

  /// How far above the floor this stride is, in source pixels.
  final double lift;

  String get asset => 'assets/startup/$name.webp';
}

/// In stride order; anchored on her torso so it stays put between frames.
const _run = [
  StartupSprite(
    'run_1',
    crop: Rect.fromLTWH(141, 192, 751, 992),
    anchor: Offset(485, 1180),
    scale: .7,
  ),
  StartupSprite(
    'run_2',
    crop: Rect.fromLTWH(3105, 334, 906, 850),
    anchor: Offset(3603, 1180),
    scale: .7,
    lift: 90,
  ),
  StartupSprite(
    'run_3',
    crop: Rect.fromLTWH(1058, 264, 913, 920),
    anchor: Offset(1531, 1180),
    scale: .7,
    lift: 50,
  ),
];

/// Anchored on her shoes.
const _offer = StartupSprite(
  'give_1',
  crop: Rect.fromLTWH(224, 90, 688, 1094),
  anchor: Offset(415, 1180),
  scale: .8,
);
const _relieved = StartupSprite(
  'give_2',
  crop: Rect.fromLTWH(1248, 90, 688, 1094),
  anchor: Offset(1439, 1180),
  scale: .8,
);

/// Anchored on the desk's left leg, which does not move between frames.
const _waiting = StartupSprite(
  'man_wait',
  crop: Rect.fromLTWH(150, 306, 716, 880),
  anchor: Offset(218, 1181),
  scale: .82,
);
const _reaching = StartupSprite(
  'man_reach',
  crop: Rect.fromLTWH(1174, 306, 716, 880),
  anchor: Offset(1242, 1181),
  scale: .82,
);
const _holding = StartupSprite(
  'man_hold',
  crop: Rect.fromLTWH(2198, 306, 716, 880),
  anchor: Offset(2266, 1181),
  scale: .82,
);

const _officeAsset = 'assets/startup/office.webp';

const startupSceneAssets = [
  _officeAsset,
  'assets/startup/run_1.webp',
  'assets/startup/run_2.webp',
  'assets/startup/run_3.webp',
  'assets/startup/give_1.webp',
  'assets/startup/give_2.webp',
  'assets/startup/man_wait.webp',
  'assets/startup/man_reach.webp',
  'assets/startup/man_hold.webp',
];

/// The visible part of the 2400 × 1600 office artwork.
const startupSceneSize = Size(1560, 1380);
const _top = 180.0;

const _girlX = 446.0, _girlFloor = 1440.0;
// The desk stands a little further back than she does.
const _deskX = 882.0, _deskFloor = 1390.0;

/// Distance covered by each running frame.
const _stride = 165.0;

// Sampled from the office artwork so the street joins it without a seam.
const _wall = Color(0xFFFDFDFD);
const _floor = Color(0xFFC1D6FE);
const _navy = Color(0xFF061C4E);
const _trim = Color(0xFF7094D0);
const _sky = Color(0xFFDDEBFE);
const _city = Color(0xFFC6DCFD);
const _accent = Color(0xFFFFC70A);

class StartupScenePainter extends CustomPainter {
  StartupScenePainter({
    required this.run,
    required this.images,
    required this.dark,
    super.repaint,
  });
  final StartupRun run;

  /// Empty until every piece has decoded.
  final Map<String, ui.Image> images;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / startupSceneSize.width);
    canvas.translate(0, -_top);
    _paintStreet(canvas);
    final office = run.officeX;
    if (office != null) _paintOffice(canvas, office);
    _paintGirl(canvas);
    if (run.stage == StartupStage.delivered) _paintSparkle(canvas);
    if (dark) {
      canvas.drawRect(
        Rect.fromLTWH(0, _top, startupSceneSize.width, startupSceneSize.height),
        Paint()..color = Colors.black.withValues(alpha: .16),
      );
    }
    canvas.restore();
  }

  /// Screen positions of a repeating prop that scrolls at [depth] × her speed.
  Iterable<double> _repeat(double period, double depth, [double phase = 0]) {
    final start = (phase - run.distance * depth) % period - period;
    return [
      for (var x = start; x < startupSceneSize.width + period; x += period) x,
    ];
  }

  void _paintStreet(Canvas canvas) {
    final width = startupSceneSize.width;
    final fill = Paint();
    canvas.drawRect(Rect.fromLTRB(0, _top, width, 1181), fill..color = _wall);
    for (final x in _repeat(900, .12, 200)) {
      fill.color = _sky;
      canvas.drawCircle(Offset(x + 90, 470), 62, fill);
      canvas.drawCircle(Offset(x + 180, 438), 86, fill);
      canvas.drawCircle(Offset(x + 275, 478), 54, fill);
      canvas.drawRRect(
        RRect.fromLTRBR(x, 470, x + 360, 532, const Radius.circular(31)),
        fill,
      );
    }
    for (final x in _repeat(960, .3)) {
      fill.color = _city;
      for (final block in const [
        Rect.fromLTRB(0, 900, 190, 1181),
        Rect.fromLTRB(150, 980, 330, 1181),
        Rect.fromLTRB(370, 760, 580, 1181),
        Rect.fromLTRB(620, 1010, 760, 1181),
        Rect.fromLTRB(730, 860, 900, 1181),
      ]) {
        canvas.drawRect(block.shift(Offset(x, 0)), fill);
      }
      fill.color = _wall;
      for (var y = 800.0; y < 950; y += 58) {
        canvas.drawRRect(
          RRect.fromLTRBR(
            x + 405,
            y,
            x + 545,
            y + 20,
            const Radius.circular(8),
          ),
          fill,
        );
      }
    }
    _paintBaseLine(canvas, width);
    canvas.drawRect(
      Rect.fromLTRB(0, 1200, width, _top + startupSceneSize.height),
      fill..color = _floor,
    );
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..color = _navy;
    for (final x in _repeat(1150, 1, 760)) {
      final pole = RRect.fromLTRBR(
        x,
        640,
        x + 30,
        1200,
        const Radius.circular(15),
      );
      final lamp = RRect.fromLTRBR(
        x - 42,
        570,
        x + 72,
        660,
        const Radius.circular(34),
      );
      canvas.drawRRect(pole, fill..color = _trim);
      canvas.drawRRect(pole, outline);
      canvas.drawRRect(lamp, fill..color = const Color(0xFFFFEA99));
      canvas.drawRRect(lamp, outline);
    }
    final dash = Paint()
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round
      ..color = _trim;
    for (final x in _repeat(620, 1)) {
      canvas.drawLine(Offset(x, 1374), Offset(x + 130, 1374), dash);
      canvas.drawLine(Offset(x + 55, 1500), Offset(x + 255, 1500), dash);
    }
  }

  void _paintBaseLine(Canvas canvas, double width) {
    final paint = Paint()..color = _navy;
    canvas.drawRect(Rect.fromLTRB(0, 1180, width, 1200), paint);
    canvas.drawRect(Rect.fromLTRB(0, 1185, width, 1193), paint..color = _trim);
  }

  void _paintOffice(Canvas canvas, double x) {
    final image = images[_officeAsset];
    if (image != null) {
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        Rect.fromLTWH(x, 0, 2400, 1600),
        Paint()..filterQuality = FilterQuality.medium,
      );
    }
    // The outside corner of the building, where the street ends.
    if (x > -30) {
      final corner = Rect.fromLTRB(x - 24, _top - 20, x + 16, 1200);
      canvas.drawRect(corner, Paint()..color = _trim);
      canvas.drawRect(
        corner,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 9
          ..color = _navy,
      );
    }
    final man = switch (run.stage) {
      StartupStage.running || StartupStage.offering => _waiting,
      StartupStage.reaching => _reaching,
      StartupStage.delivered => _holding,
    };
    _paintShadow(canvas, Offset(x + _deskX + 250, _deskFloor), 560);
    _paintSprite(canvas, man, Offset(x + _deskX, _deskFloor));
  }

  void _paintGirl(Canvas canvas) {
    if (run.stage == StartupStage.running) {
      final sprite = _run[(run.distance / _stride).floor() % _run.length];
      final lift = sprite.lift * sprite.scale;
      _paintShadow(canvas, const Offset(_girlX + 54, _girlFloor), 340 - lift);
      _paintSpeedLines(canvas);
      _paintSprite(canvas, sprite, Offset(_girlX + 54, _girlFloor - lift));
      return;
    }
    // A small dip as she pulls up at the desk.
    final settle = (run.arrivedFor / .18).clamp(0.0, 1.0);
    final squash = 1 - .045 * math.sin(settle * math.pi);
    _paintShadow(canvas, const Offset(_girlX, _girlFloor), 270);
    _paintSprite(
      canvas,
      run.stage == StartupStage.delivered ? _relieved : _offer,
      const Offset(_girlX, _girlFloor),
      stretch: squash,
    );
  }

  void _paintShadow(Canvas canvas, Offset centre, double width) {
    canvas.drawOval(
      Rect.fromCenter(center: centre, width: width, height: width * .12),
      Paint()..color = _trim.withValues(alpha: .28),
    );
  }

  void _paintSpeedLines(Canvas canvas) {
    final pace =
        ((run.speed - StartupRun.jogSpeed) /
                (StartupRun.sprintSpeed - StartupRun.jogSpeed))
            .clamp(0.0, 1.0);
    if (pace < .05) return;
    final paint = Paint()
      ..strokeWidth = 13
      ..strokeCap = StrokeCap.round
      ..color = _trim.withValues(alpha: .8 * pace);
    for (var i = 0; i < 3; i++) {
      final flicker = (run.distance / 420 + i * .37) % 1;
      final right = 275.0 - flicker * 80 + (i == 1 ? -30 : 0);
      final y = 900.0 + i * 170;
      canvas.drawLine(
        Offset(right - (70 + 130 * pace), y),
        Offset(right, y),
        paint,
      );
    }
  }

  void _paintSparkle(Canvas canvas) {
    final progress = (run.deliveredFor / .4).clamp(0.0, 1.0);
    if (progress >= 1) return;
    // Off the top left corner of the resume, clear of his face.
    final centre = Offset((run.officeX ?? 0) + _deskX + 105, 925);
    final paint = Paint()
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round
      ..color = _accent.withValues(alpha: 1 - progress * progress);
    final reach = 85 + 45 * Curves.easeOutCubic.transform(progress);
    for (final angle in const [-3.0, -2.45, -1.9]) {
      final direction = Offset(math.cos(angle), math.sin(angle));
      canvas.drawLine(
        centre + direction * reach,
        centre + direction * (reach + 52),
        paint,
      );
    }
  }

  /// Draws [sprite] with its anchor at [at].
  void _paintSprite(
    Canvas canvas,
    StartupSprite sprite,
    Offset at, {
    double stretch = 1,
  }) {
    final image = images[sprite.asset];
    if (image == null) return;
    final from = (sprite.crop.topLeft - sprite.anchor) * sprite.scale;
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromLTWH(
        at.dx + from.dx,
        at.dy + from.dy * stretch,
        sprite.crop.width * sprite.scale,
        sprite.crop.height * sprite.scale * stretch,
      ),
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  @override
  bool shouldRepaint(StartupScenePainter oldDelegate) =>
      oldDelegate.run != run ||
      oldDelegate.images != images ||
      oldDelegate.dark != dark;
}
