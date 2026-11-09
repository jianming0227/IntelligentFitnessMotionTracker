import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../logic/mascot_mood.dart';
import 'flick_painter.dart';

/// Target pose for each mood (same values as the design session's
/// `mascot_<mood>.png` exports).
const Map<MascotMood, FlickPose> flickPoses = {
  MascotMood.idle: FlickPose(),
  MascotMood.happy: FlickPose(
    smile: 1,
    armLeft: 70,
    armRight: 70,
    lift: -6,
    bounce: 14,
    wave: 10,
    breathAmp: 0.01,
  ),
  MascotMood.sleepy: FlickPose(
    eyelid: 0.55,
    smile: 0.1,
    armLeft: 20,
    armRight: 20,
    droop: 0.03,
    zzz: 1,
    sway: 3,
    breathAmp: 0.02,
    breathPeriod: 4.2,
  ),
  MascotMood.sad: FlickPose(
    eyelid: 0.3,
    lidTilt: 0.5,
    smile: -0.7,
    armLeft: 12,
    armRight: 12,
    droop: 0.06,
    breathAmp: 0.022,
    breathPeriod: 4.8,
  ),
};

/// Flick, the Progress-tab mascot, drawn and animated in code.
///
/// * [mood] switches with a 200 ms blend.
/// * Bump [celebrateToken] (any new value) to play the one-shot celebration.
/// * Tapping plays a wiggle; [onTap] fires too.
///
/// Honours "remove animations": holds the static mood pose, no loops.
class FlickMascot extends StatefulWidget {
  const FlickMascot({
    super.key,
    required this.mood,
    this.size = 140,
    this.celebrateToken,
    this.onTap,
  });

  final MascotMood mood;
  final double size;
  final Object? celebrateToken;
  final VoidCallback? onTap;

  @override
  State<FlickMascot> createState() => _FlickMascotState();
}

class _FlickMascotState extends State<FlickMascot>
    with SingleTickerProviderStateMixin {
  static const _blend = 0.2;
  static const _celebrateSecs = 1.5;
  static const _tapSecs = 0.6;

  late final Ticker _ticker;
  double _t = 0;

  late FlickPose _from;
  late FlickPose _to;
  double _blendStart = -1;
  double? _celebrateStart;
  double? _tapStart;
  double _nextBlink = 2.5;

  @override
  void initState() {
    super.initState();
    _from = _to = flickPoses[widget.mood]!;
    _ticker = createTicker((elapsed) {
      setState(() => _t = elapsed.inMicroseconds / 1e6);
    })
      ..start();
    // Celebrate if the card first appears with a fresh token.
    if (widget.celebrateToken != null) _celebrateStart = 0;
  }

  @override
  void didUpdateWidget(FlickMascot old) {
    super.didUpdateWidget(old);
    if (old.mood != widget.mood) {
      _from = _currentPose();
      _to = flickPoses[widget.mood]!;
      _blendStart = _t;
    }
    if (widget.celebrateToken != null &&
        widget.celebrateToken != old.celebrateToken) {
      _celebrateStart = _t;
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  FlickPose _currentPose() {
    if (_blendStart < 0) return _to;
    final k = ((_t - _blendStart) / _blend).clamp(0.0, 1.0);
    return FlickPose.lerp(_from, _to, Curves.easeInOut.transform(k));
  }

  double? _progress(double? start, double secs) {
    if (start == null) return null;
    final p = (_t - start) / secs;
    return p >= 1 ? null : p.clamp(0.0, 1.0);
  }

  double _blink() {
    if (_t > _nextBlink + 0.16) {
      _nextBlink = _t + 2.8 + math.Random().nextDouble() * 2.4;
    }
    final b = (_t - _nextBlink) / 0.16;
    return b < 0 || b > 1 ? 0 : math.sin(math.pi * b);
  }

  void _handleTap() {
    _tapStart = _t;
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.of(context).disableAnimations;
    if (still && _ticker.isActive) _ticker.stop();
    if (!still && !_ticker.isActive) _ticker.start();

    final celebrate = still ? null : _progress(_celebrateStart, _celebrateSecs);
    if (celebrate == null) _celebrateStart = null;
    final tap = still ? null : _progress(_tapStart, _tapSecs);
    if (tap == null) _tapStart = null;

    final pose = _currentPose();
    final frame = FlickFrame(
      pose: pose,
      time: still ? 0 : _t,
      blink: still ? 0 : _blink(),
      celebrate: celebrate,
      tap: tap,
    );

    return Semantics(
      label: 'Flick the mascot, feeling ${widget.mood.name}',
      button: true,
      child: GestureDetector(
        onTap: _handleTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox.square(
          dimension: widget.size,
          child: CustomPaint(painter: FlickPainter(frame)),
        ),
      ),
    );
  }
}
