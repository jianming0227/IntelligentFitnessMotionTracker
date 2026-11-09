import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

/// Static pose of Flick. Every field blends linearly, so mood changes
/// cross-fade instead of snapping. Geometry mirrors
/// `design_source/mascot_layers.svg` (512 × 512 artboard).
@immutable
class FlickPose {
  const FlickPose({
    this.eyelid = 0,
    this.lidTilt = 0,
    this.smile = 0.35,
    this.armLeft = 35,
    this.armRight = 35,
    this.droop = 0,
    this.lift = 0,
    this.zzz = 0,
    this.breathAmp = 0.015,
    this.breathPeriod = 3.0,
    this.bounce = 0,
    this.sway = 0,
    this.wave = 0,
  });

  /// 0 eyes open … 1 closed.
  final double eyelid;

  /// > 0 lowers the outer lid corners (sad look).
  final double lidTilt;

  /// -1 frown … 1 big smile.
  final double smile;

  /// Arm angles in degrees from hanging straight down, outward positive.
  final double armLeft;
  final double armRight;

  /// Vertical squash, 0 … ~0.08.
  final double droop;

  /// Vertical offset in artboard px (negative = up).
  final double lift;

  /// Opacity of the floating z's.
  final double zzz;

  final double breathAmp;
  final double breathPeriod;

  /// Height of the happy hop in artboard px.
  final double bounce;

  /// Degrees of slow side-to-side sway.
  final double sway;

  /// Degrees of arm wave.
  final double wave;

  static FlickPose lerp(FlickPose a, FlickPose b, double t) {
    double l(double x, double y) => lerpDouble(x, y, t)!;
    return FlickPose(
      eyelid: l(a.eyelid, b.eyelid),
      lidTilt: l(a.lidTilt, b.lidTilt),
      smile: l(a.smile, b.smile),
      armLeft: l(a.armLeft, b.armLeft),
      armRight: l(a.armRight, b.armRight),
      droop: l(a.droop, b.droop),
      lift: l(a.lift, b.lift),
      zzz: l(a.zzz, b.zzz),
      breathAmp: l(a.breathAmp, b.breathAmp),
      breathPeriod: l(a.breathPeriod, b.breathPeriod),
      bounce: l(a.bounce, b.bounce),
      sway: l(a.sway, b.sway),
      wave: l(a.wave, b.wave),
    );
  }
}

/// Per-frame inputs on top of the pose.
@immutable
class FlickFrame {
  const FlickFrame({
    required this.pose,
    required this.time,
    this.blink = 0,
    this.celebrate,
    this.tap,
  });

  final FlickPose pose;

  /// Seconds since the widget started; drives the looping motion.
  final double time;

  /// 0 … 1 extra eyelid closure from a blink.
  final double blink;

  /// 0 … 1 progress of the celebrate one-shot, null when not playing.
  final double? celebrate;

  /// 0 … 1 progress of the tap wiggle, null when not playing.
  final double? tap;
}

class FlickPainter extends CustomPainter {
  FlickPainter(this.frame);

  final FlickFrame frame;

  static const orange = Color(0xFFFF9A2E);
  static const lime = Color(0xFFC8FF2D);
  static const ink = Color(0xFF14161B);

  static const _eyes = [Offset(216, 306), Offset(296, 306)];
  static const _eyeRx = 17.0, _eyeRy = 24.0;
  static const _shoulders = [Offset(140, 322), Offset(372, 322)];
  static const _armLen = 66.0;
  static const _base = Offset(256, 446);

  static final Path _body = Path()
    ..moveTo(256, 58)
    ..cubicTo(286, 120, 330, 140, 352, 120)
    ..cubicTo(392, 180, 396, 250, 388, 320)
    ..cubicTo(378, 400, 324, 446, 256, 446)
    ..cubicTo(188, 446, 134, 400, 124, 320)
    ..cubicTo(116, 250, 140, 196, 176, 156)
    ..cubicTo(186, 186, 204, 196, 220, 190)
    ..cubicTo(214, 140, 226, 96, 256, 58)
    ..close();

  static final Path _core = Path()
    ..moveTo(256, 230)
    ..cubicTo(280, 262, 330, 280, 330, 340)
    ..cubicTo(330, 390, 296, 416, 256, 416)
    ..cubicTo(216, 416, 182, 390, 182, 340)
    ..cubicTo(182, 290, 230, 270, 256, 230)
    ..close();

  static final Path _band = Path()
    ..moveTo(128, 228)
    ..cubicTo(190, 206, 322, 206, 384, 228)
    ..lineTo(388, 262)
    ..cubicTo(322, 242, 190, 242, 124, 262)
    ..close();

  static final Path _bandTail = Path()
    ..moveTo(384, 236)
    ..lineTo(432, 214)
    ..lineTo(426, 246)
    ..close()
    ..moveTo(384, 246)
    ..lineTo(424, 262)
    ..lineTo(404, 282)
    ..close();

  // x, y, w, h, rotation°, colour — same pieces as the SVG `confetti` group.
  static const _confetti = [
    (96.0, 120.0, 18.0, 10.0, 30.0, orange),
    (150.0, 70.0, 14.0, 14.0, -20.0, lime),
    (360.0, 64.0, 18.0, 10.0, 60.0, lime),
    (420.0, 130.0, 14.0, 14.0, 15.0, orange),
    (70.0, 220.0, 16.0, 9.0, -45.0, lime),
    (448.0, 236.0, 18.0, 10.0, 40.0, orange),
    (200.0, 40.0, 10.0, 10.0, 0.0, Color(0xFF39E08B)),
    (318.0, 30.0, 16.0, 9.0, -30.0, orange),
    (470.0, 330.0, 12.0, 12.0, 20.0, lime),
    (40.0, 330.0, 14.0, 8.0, 70.0, orange),
  ];

  Paint _fill(Color c) => Paint()..color = c;
  Paint _stroke(Color c, double w) => Paint()
    ..color = c
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide / 512;
    canvas.save();
    canvas.translate(
      (size.width - 512 * s) / 2,
      (size.height - 512 * s) / 2,
    );
    canvas.scale(s);

    final p = frame.pose;
    final t = frame.time;
    final cel = frame.celebrate;
    final tap = frame.tap;

    // ── motion ────────────────────────────────────────────────────────────
    var lift = p.lift;
    var squash = 0.0;
    if (p.bounce > 0) {
      final hop = (math.sin(math.pi * t / 0.55)).abs();
      lift -= p.bounce * hop;
      squash += 0.04 * (1 - hop) * (p.bounce / 14);
    }
    var armL = p.armLeft + p.wave * math.sin(2 * math.pi * t / 0.8);
    var armR = p.armRight - p.wave * math.sin(2 * math.pi * t / 0.8);
    var smile = p.smile;
    if (cel != null) {
      // Crouch, leap, land: 0-0.15 crouch, 0.15-0.65 airborne, then settle.
      final jump = cel < 0.15
          ? 0.0
          : cel < 0.65
              ? math.sin(math.pi * (cel - 0.15) / 0.5)
              : 0.0;
      final crouch = cel < 0.15
          ? math.sin(math.pi * cel / 0.15)
          : cel > 0.65
              ? math.sin(math.pi * (cel - 0.65) / 0.35) * 0.6
              : 0.0;
      lift -= 70 * jump;
      squash += 0.08 * crouch;
      final up = Curves.easeOut.transform((cel / 0.2).clamp(0.0, 1.0)) *
          (1 - Curves.easeIn.transform(((cel - 0.8) / 0.2).clamp(0.0, 1.0)));
      armL = lerpDouble(armL, 145, up)!;
      armR = lerpDouble(armR, 145, up)!;
      smile = lerpDouble(smile, 1, up)!;
    }
    final breath = p.breathAmp * math.sin(2 * math.pi * t / p.breathPeriod);
    final scaleY = 1 - p.droop - squash + breath;
    final scaleX = 1 + squash * 0.6 - breath * 0.4;
    var rot = p.sway * math.sin(2 * math.pi * t / 3.6);
    if (tap != null) rot += 9 * math.sin(4 * math.pi * tap) * (1 - tap);
    final flicker = 0.025 * math.sin(2 * math.pi * t / 0.9) +
        0.012 * math.sin(2 * math.pi * t / 0.37);

    // ── shadow ────────────────────────────────────────────────────────────
    final shadowScale = (1 + lift / 160).clamp(0.4, 1.1);
    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(256, 458),
        width: 208 * shadowScale,
        height: 28 * shadowScale,
      ),
      _fill(ink.withValues(alpha: 0.18)),
    );

    // ── character ────────────────────────────────────────────────────────
    canvas.save();
    canvas.translate(_base.dx, _base.dy + lift);
    canvas.rotate(rot * math.pi / 180);
    canvas.scale(scaleX, scaleY);
    canvas.translate(-_base.dx, -_base.dy);

    // Flame flicker: skew the WHOLE character around its base, so the core,
    // arms, headband and face move with the flame instead of the body
    // sliding underneath them.
    canvas.save();
    canvas.translate(_base.dx, _base.dy);
    canvas.transform(Matrix4.skewX(flicker).storage);
    canvas.translate(-_base.dx, -_base.dy);
    canvas.drawPath(_body, _fill(orange));
    canvas.drawPath(_body, _stroke(ink, 14));
    canvas.drawPath(_core, _fill(lime));

    for (final (i, a) in [(0, armL), (1, armR)]) {
      final sh = _shoulders[i];
      final dir = i == 0 ? -1 : 1;
      final r = a * math.pi / 180;
      final hand = sh + Offset(dir * _armLen * math.sin(r), _armLen * math.cos(r));
      canvas.drawLine(sh, hand, _stroke(ink, 32));
      canvas.drawLine(sh, hand, _stroke(orange, 16));
    }

    canvas.drawPath(_bandTail, _fill(lime));
    canvas.drawPath(_bandTail, _stroke(ink, 10));
    canvas.drawPath(_band, _fill(lime));
    canvas.drawPath(_band, _stroke(ink, 12));

    final lid = (p.eyelid + frame.blink).clamp(0.0, 1.0);
    for (var i = 0; i < 2; i++) {
      final c = _eyes[i];
      final eyeRect =
          Rect.fromCenter(center: c, width: 2 * _eyeRx, height: 2 * _eyeRy);
      canvas.drawOval(eyeRect, _fill(ink));
      canvas.drawCircle(c + const Offset(6, -9), 6, _fill(Colors.white));
      if (lid > 0.01 || p.lidTilt > 0.01) _drawLid(canvas, i, lid, p.lidTilt);
    }

    final my = 352 - 6 * smile;
    final mouth = Path()
      ..moveTo(230, my)
      ..quadraticBezierTo(256, 352 + 30 * smile, 282, my);
    canvas.drawPath(mouth, _stroke(ink, 12));
    canvas.restore(); // flicker skew
    canvas.restore(); // character transform

    // ── z's ───────────────────────────────────────────────────────────────
    if (p.zzz > 0.01) _drawZzz(canvas, t, p.zzz);

    // ── confetti burst ────────────────────────────────────────────────────
    if (cel != null) _drawConfetti(canvas, cel);

    canvas.restore();
  }

  void _drawLid(Canvas canvas, int i, double eyelid, double tilt) {
    final c = _eyes[i];
    final top = c.dy - _eyeRy - 2;
    final h = 2 * _eyeRy * eyelid + 2;
    final outer = i == 0 ? c.dx - _eyeRx - 3 : c.dx + _eyeRx + 3;
    final inner = i == 0 ? c.dx + _eyeRx + 3 : c.dx - _eyeRx - 3;
    final ho = h + 18 * tilt;
    final hi = math.max(2.0, h - 14 * tilt);
    final bow = 8 * eyelid;
    final ctrl = Offset(c.dx, top + (ho + hi) / 2 + bow);
    final edge = Path()
      ..moveTo(outer, top + ho)
      ..quadraticBezierTo(ctrl.dx, ctrl.dy, inner, top + hi);
    final shape = Path()
      ..moveTo(outer, top - 4)
      ..lineTo(outer, top + ho)
      ..quadraticBezierTo(ctrl.dx, ctrl.dy, inner, top + hi)
      ..lineTo(inner, top - 4)
      ..close();
    canvas.save();
    canvas.clipPath(Path()
      ..addOval(Rect.fromCenter(
          center: c, width: 2 * _eyeRx + 4, height: 2 * _eyeRy + 4)));
    canvas.drawPath(shape, _fill(lime));
    canvas.drawPath(edge, _stroke(ink, 6));
    canvas.restore();
  }

  void _drawZzz(Canvas canvas, double t, double opacity) {
    const zs = [(370.0, 150.0, 22.0, 14.0), (404.0, 104.0, 28.0, 16.0), (440.0, 50.0, 34.0, 18.0)];
    for (final (i, (x, y, size, w)) in zs.indexed) {
      // Each z drifts up and fades on a staggered 3 s cycle.
      final phase = ((t / 3.0) + i / 3) % 1.0;
      final a = opacity * math.sin(math.pi * phase);
      final dy = -14 * phase;
      final z = Path()
        ..moveTo(x, y + dy)
        ..relativeLineTo(size, 0)
        ..relativeLineTo(-size, size)
        ..relativeLineTo(size, 0);
      canvas.drawPath(z, _stroke(ink.withValues(alpha: a), w));
      canvas.drawPath(z, _stroke(Colors.white.withValues(alpha: a), w - 6));
    }
  }

  void _drawConfetti(Canvas canvas, double cel) {
    // Pieces burst out from behind Flick, then fall and fade.
    final burst = Curves.easeOutCubic.transform((cel / 0.45).clamp(0.0, 1.0));
    final fade = 1 - ((cel - 0.7) / 0.3).clamp(0.0, 1.0);
    if (fade <= 0) return;
    const origin = Offset(256, 240);
    for (final (i, (x, y, w, h, r, color)) in _confetti.indexed) {
      final target = Offset(x, y);
      final pos = Offset.lerp(origin, target, burst)! +
          Offset(0, 120 * math.pow(cel, 2).toDouble());
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate((r + 360 * cel * (i.isEven ? 1 : -1)) * math.pi / 180);
      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: w * 1.6, height: h * 1.6),
        const Radius.circular(3),
      );
      canvas.drawRRect(rect, _fill(color.withValues(alpha: fade)));
      canvas.drawRRect(rect, _stroke(ink.withValues(alpha: fade), 3));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(FlickPainter old) => true;
}
