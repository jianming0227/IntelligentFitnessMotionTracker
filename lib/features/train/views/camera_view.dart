import 'dart:async';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../session/views/session_summary_view.dart';
import '../models/exercise.dart';
import '../models/set_metrics.dart';
import '../widgets/coaching_sheet.dart';
import '../widgets/form_gauge.dart';
import '../widgets/pose_painter.dart';

class CameraView extends StatefulWidget {
  const CameraView({super.key, required this.exercise});

  final Exercise exercise;

  @override
  State<CameraView> createState() => _CameraViewState();
}

class _CameraViewState extends State<CameraView> {
  // ── FR-2.1: Camera ──────────────────────────────────────────────────────────
  List<CameraDescription> _cameras = [];
  CameraController? _controller;
  int _cameraIndex = 0;
  bool _permissionDenied = false;

  // ── FR-2.1: ML Kit pose detector ────────────────────────────────────────────
  final _detector = PoseDetector(
    options: PoseDetectorOptions(mode: PoseDetectionMode.stream),
  );
  bool _isDetecting = false;
  List<Pose> _poses = [];
  double? _currentAngle;

  // ── FR-2.4: Rep counter state ───────────────────────────────────────────────
  bool _isDown = false;
  int _repCount = 0;
  int _currentSet = 1;
  static const int _totalSets = 3;
  static const int _targetReps = 10;

  // ── FR-3.1: Per-set metrics ─────────────────────────────────────────────────
  DateTime? _repStartTime;
  DateTime? _phaseEnteredAt; // when current down/up phase began
  final List<int> _currentRepDurations = [];
  int _greenFrames = 0;
  int _totalFrames = 0;
  final List<SetMetrics> _completedSets = [];

  // FR-2.4: TUT — time the joint spent in the form-gauge green zone.
  DateTime? _tutZoneEnteredAt;
  int _tutMs = 0;

  // ── Session lifecycle ───────────────────────────────────────────────────────
  bool _sessionPaused = false; // true while bottom sheet visible or counting down
  bool _sessionStarted = false;
  DateTime? _gestureStartAt;
  int _gestureCountdown = 3;
  DateTime? _setStartTime;
  Duration _setElapsed = Duration.zero;
  Timer? _setTicker;

  // Inter-set rest countdown (5-4-3-2-1 overlay before next set).
  int? _restCountdown;
  Timer? _restTimer;

  // ── TTS ─────────────────────────────────────────────────────────────────────
  final FlutterTts _tts = FlutterTts();
  bool _ttsEnabled = true;
  DateTime? _lastCueAt;
  DateTime? _badFormSince;
  DateTime? _lastMotivationAt;

  // ── UI ──────────────────────────────────────────────────────────────────────
  bool _showGauge = true;

  // ── Pre-session body detection gate ─────────────────────────────────────────
  // Phase 1: user must step back until key landmarks are confident.
  // Phase 2: body confirmed → hand gesture prompt unlocks.
  bool _bodyInFrame = false;
  bool _bodyTtsSpoken = false; // prevents repeating "show hand" on re-entry

  // ── Mid-session body tracking ────────────────────────────────────────────────
  // True whenever the key joints drop below confidence during an active set.
  // Rep counting and form scoring are gated on this being false.
  bool _bodyLostDuringSession = false;

  // ────────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);

    final status = await Permission.camera.request();
    if (!status.isGranted) {
      if (mounted) setState(() => _permissionDenied = true);
      return;
    }
    _cameras = await availableCameras();
    if (_cameras.isEmpty) return;

    _cameraIndex = _cameras.indexWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
    );
    if (_cameraIndex == -1) _cameraIndex = 0;

    await _startController();
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted && _ttsEnabled) {
        _tts.speak('Stand back from the phone so your full body is visible');
      }
    });
  }

  Future<void> _startController() async {
    final ctrl = CameraController(
      _cameras[_cameraIndex],
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.nv21,
    );
    _controller = ctrl;
    await ctrl.initialize();
    if (!mounted) return;
    await ctrl.startImageStream(_processFrame);
    setState(() {});
  }

  Future<void> _processFrame(CameraImage image) async {
    if (_isDetecting || !mounted || _sessionPaused) return;
    _isDetecting = true;
    try {
      final input = _toInputImage(image);
      if (input == null) return;

      final poses = await _detector.processImage(input);
      if (!mounted) return;

      double? angle;
      if (!_sessionStarted) {
        // Pre-session: gate on poses being detected at all.
        if (poses.isNotEmpty) {
          _checkBodyInFrame(poses.first);
          if (_bodyInFrame) {
            _checkGesture(poses.first);
          } else {
            _gestureStartAt = null;
            _gestureCountdown = 3;
          }
        }
      } else {
        // Active session: must process even when poses is empty so that body-
        // loss is detected (angle == null) and the overlay shows correctly.
        final pose = poses.isNotEmpty ? poses.first : null;
        angle = pose != null ? _jointAngle(pose) : null;

        if (angle != null) {
          // Body confirmed — clear lost state on transition.
          if (_bodyLostDuringSession) {
            setState(() => _bodyLostDuringSession = false);
          }
          _totalFrames++;
          final inZone = angle >= widget.exercise.targetAngleMin &&
              angle <= widget.exercise.targetAngleMax;
          if (inZone) {
            _greenFrames++;
            final now = DateTime.now();
            _tutZoneEnteredAt ??= now;
            _tutMs += now.difference(_tutZoneEnteredAt!).inMilliseconds;
            _tutZoneEnteredAt = now;
          } else {
            _tutZoneEnteredAt = null;
          }
          _checkBadForm(angle);
          _countRep(angle);
        } else {
          // Body lost or low-confidence — pause tracking, notify once per event.
          _tutZoneEnteredAt = null;
          if (!_bodyLostDuringSession) {
            _bodyLostDuringSession = true;
            if (_ttsEnabled) {
              _tts.speak('Step back. Keep your full body visible to continue');
            }
          }
        }
      }

      setState(() {
        _poses = poses;
        _currentAngle = angle;
      });
    } catch (_) {
      // silently skip unprocessable frames
    } finally {
      _isDetecting = false;
    }
  }

  InputImage? _toInputImage(CameraImage image) {
    final camera = _cameras[_cameraIndex];
    final rotation =
        InputImageRotationValue.fromRawValue(camera.sensorOrientation);
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (rotation == null || format == null || image.planes.isEmpty) return null;

    final plane = image.planes.first;
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  // ── TTS coaching ────────────────────────────────────────────────────────────
  void _checkBadForm(double angle) {
    final inZone = angle >= widget.exercise.targetAngleMin &&
        angle <= widget.exercise.targetAngleMax;

    if (inZone) {
      _badFormSince = null;
      if (_ttsEnabled) _maybeSpeakMotivation();
      return;
    }
    if (!_ttsEnabled) return;

    final now = DateTime.now();
    _badFormSince ??= now;
    if (now.difference(_badFormSince!).inMilliseconds < 1500) return;

    final debounceOk =
        _lastCueAt == null || now.difference(_lastCueAt!).inSeconds >= 4;
    if (!debounceOk) return;

    _lastCueAt = now;
    _badFormSince = now;
    final cues = widget.exercise.id == 'bicep_curl'
        ? ['Full extension at the bottom', 'Squeeze at the top', 'Keep your elbow still']
        : ['Go deeper', 'Keep your chest up', 'Knees track over toes'];
    _tts.speak(cues[DateTime.now().second % cues.length]);
  }

  void _maybeSpeakMotivation() {
    final now = DateTime.now();
    if (_lastMotivationAt != null &&
        now.difference(_lastMotivationAt!).inSeconds < 10) {
      return;
    }
    _lastMotivationAt = now;
    const cues = ['Great form!', 'Keep it up!', 'Looking strong!', 'Perfect pace!'];
    _tts.speak(cues[now.second % cues.length]);
  }

  // ── Body-in-frame gate ──────────────────────────────────────────────────────
  void _checkBodyInFrame(Pose pose) {
    // Reuse the same confidence-gated angle check: if the exercise-specific
    // joints (knee for squat, elbow for curl) are all confident, the user is
    // standing far enough back for the full movement to be tracked.
    final inFrame = _jointAngle(pose) != null;

    if (inFrame && !_bodyTtsSpoken) {
      _bodyTtsSpoken = true;
      if (_ttsEnabled) {
        _tts.speak('Full body detected. Show your open hand to start');
      }
    }

    if (inFrame != _bodyInFrame) {
      setState(() => _bodyInFrame = inFrame);
    }
  }

  // ── Joint angles + landmark confidence ──────────────────────────────────────

  /// Returns the angle in degrees only if all three landmarks meet the
  /// per-exercise confidence threshold. Low-confidence frames are dropped so
  /// they can't toggle the rep state machine.
  double? _jointAngle(Pose pose) {
    if (widget.exercise.id == 'bicep_curl') return _elbowAngle(pose);
    return _kneeAngle(pose);
  }

  double? _kneeAngle(Pose pose) {
    final hip = pose.landmarks[PoseLandmarkType.leftHip];
    final knee = pose.landmarks[PoseLandmarkType.leftKnee];
    final ankle = pose.landmarks[PoseLandmarkType.leftAnkle];
    if (!_landmarksConfident([hip, knee, ankle])) return null;
    return _angleAt(hip!, knee!, ankle!);
  }

  double? _elbowAngle(Pose pose) {
    final shoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final elbow = pose.landmarks[PoseLandmarkType.leftElbow];
    final wrist = pose.landmarks[PoseLandmarkType.leftWrist];
    if (!_landmarksConfident([shoulder, elbow, wrist])) return null;
    return _angleAt(shoulder!, elbow!, wrist!);
  }

  double _angleAt(PoseLandmark a, PoseLandmark b, PoseLandmark c) {
    final ba = Offset(a.x - b.x, a.y - b.y);
    final bc = Offset(c.x - b.x, c.y - b.y);
    final cosA =
        (ba.dx * bc.dx + ba.dy * bc.dy) / (ba.distance * bc.distance);
    return acos(cosA.clamp(-1.0, 1.0)) * 180 / pi;
  }

  bool _landmarksConfident(List<PoseLandmark?> lms) {
    final threshold = widget.exercise.minLandmarkConfidence;
    for (final l in lms) {
      if (l == null) return false;
      if (l.likelihood < threshold) return false;
    }
    return true;
  }

  // ── Gesture start ───────────────────────────────────────────────────────────
  bool _isOpenHand(Pose pose) {
    bool handOpen(
      PoseLandmark? wrist,
      PoseLandmark? thumb,
      PoseLandmark? index,
      PoseLandmark? pinky,
    ) {
      if (wrist == null || thumb == null || index == null || pinky == null) {
        return false;
      }
      return thumb.y < wrist.y && index.y < wrist.y && pinky.y < wrist.y;
    }

    return handOpen(
          pose.landmarks[PoseLandmarkType.leftWrist],
          pose.landmarks[PoseLandmarkType.leftThumb],
          pose.landmarks[PoseLandmarkType.leftIndex],
          pose.landmarks[PoseLandmarkType.leftPinky],
        ) ||
        handOpen(
          pose.landmarks[PoseLandmarkType.rightWrist],
          pose.landmarks[PoseLandmarkType.rightThumb],
          pose.landmarks[PoseLandmarkType.rightIndex],
          pose.landmarks[PoseLandmarkType.rightPinky],
        );
  }

  void _checkGesture(Pose pose) {
    if (!_isOpenHand(pose)) {
      _gestureStartAt = null;
      _gestureCountdown = 3;
      return;
    }
    final now = DateTime.now();
    _gestureStartAt ??= now;
    final elapsed = now.difference(_gestureStartAt!).inSeconds;
    _gestureCountdown = (3 - elapsed).clamp(0, 3);
    if (elapsed >= 3) {
      _beginSet(); // also flips _sessionStarted
      if (_ttsEnabled) _tts.speak('Starting now');
    }
  }

  // ── Rep counter (hardened) ──────────────────────────────────────────────────
  //
  // Three guards reject false positives:
  //   1. Landmark confidence — frames with low likelihood produce no angle.
  //   2. Strict thresholds   — angle must cross [repBottomAngleStrict] or
  //                            [repTopAngleStrict] which sit *tighter* than
  //                            the form gauge green zone.
  //   3. Min phase duration  — once entered, a phase must persist at least
  //                            [exercise.minRepDurationMs] before the opposite
  //                            phase can fire. Kills sub-second jitter.
  void _countRep(double angle) {
    if (_sessionPaused || !_sessionStarted) return;

    final ex = widget.exercise;
    final bool atBottom;
    final bool atTop;
    if (ex.id == 'bicep_curl') {
      atBottom = angle > ex.repBottomAngleStrict; // arm extended
      atTop = angle < ex.repTopAngleStrict;        // arm curled
    } else {
      atBottom = angle < ex.repBottomAngleStrict;  // squat depth
      atTop = angle > ex.repTopAngleStrict;        // standing
    }

    final now = DateTime.now();
    final phaseAgeMs = _phaseEnteredAt == null
        ? 0
        : now.difference(_phaseEnteredAt!).inMilliseconds;

    if (!_isDown && atBottom && phaseAgeMs >= ex.minRepDurationMs) {
      _isDown = true;
      _phaseEnteredAt = now;
      _repStartTime = now;
    } else if (_isDown && atTop && phaseAgeMs >= ex.minRepDurationMs) {
      _isDown = false;
      _phaseEnteredAt = now;
      if (_repStartTime != null) {
        _currentRepDurations
            .add(now.difference(_repStartTime!).inMilliseconds);
        _repStartTime = null;
      }
      _repCount++;
      if (_repCount >= _targetReps) {
        _onSetComplete();
      } else {
        setState(() {});
      }
    } else {
      // If the state isn't ready to flip, still anchor the phase start the
      // first time we land in a recognisable position so the guard works.
      _phaseEnteredAt ??= now;
    }
  }

  // ── Set lifecycle ───────────────────────────────────────────────────────────
  void _beginSet() {
    _sessionStarted = true;
    _setStartTime = DateTime.now();
    _setElapsed = Duration.zero;
    _phaseEnteredAt = null;
    _setTicker?.cancel();
    _setTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _setStartTime == null) return;
      setState(() {
        _setElapsed = DateTime.now().difference(_setStartTime!);
      });
    });
    setState(() {});
  }

  void _onSetComplete() {
    _sessionPaused = true;
    _setTicker?.cancel();

    final durations = List<int>.from(_currentRepDurations);
    final fatigueIndex = (durations.length >= 2)
        ? ((durations.last / durations.first) - 1).clamp(0.0, 2.0)
        : 0.0;

    final formScore =
        _totalFrames > 0 ? (_greenFrames / _totalFrames).clamp(0.0, 1.0) : 0.0;

    final metrics = SetMetrics(
      setNumber: _currentSet,
      repsCompleted: _repCount,
      formScore: formScore,
      fatigueIndex: fatigueIndex,
      repDurationsMs: durations,
      completedAt: DateTime.now(),
      tutMs: _tutMs,
    );

    _completedSets.add(metrics);

    _greenFrames = 0;
    _totalFrames = 0;
    _tutMs = 0;
    _tutZoneEnteredAt = null;
    _currentRepDurations.clear();
    setState(() {});

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CoachingSheet(
        exerciseName: widget.exercise.name,
        metrics: metrics,
        onContinue: () {
          Navigator.of(context).pop();
          if (_currentSet < _totalSets) {
            _startRestCountdown();
          } else {
            context.go(
              '/session/summary',
              extra: SessionSummaryData(
                exerciseName: widget.exercise.name,
                sets: _completedSets,
              ),
            );
          }
        },
      ),
    );
  }

  /// 5-second between-set countdown. Rep counting stays paused; the overlay
  /// counts down and the next set begins automatically (or the user skips).
  void _startRestCountdown() {
    final secs = widget.exercise.restBetweenSetsSec.clamp(3, 60);
    setState(() {
      _repCount = 0;
      _currentSet++;
      _restCountdown = secs;
      _sessionPaused = true;
    });
    if (_ttsEnabled) _tts.speak('Rest. Next set in $secs seconds.');

    _restTimer?.cancel();
    _restTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      final next = (_restCountdown ?? 1) - 1;
      if (next <= 0) {
        t.cancel();
        _skipRest();
      } else {
        setState(() => _restCountdown = next);
      }
    });
  }

  void _skipRest() {
    _restTimer?.cancel();
    setState(() {
      _restCountdown = null;
      _sessionPaused = false;
    });
    if (_ttsEnabled) _tts.speak('Go!');
    _beginSet();
  }

  Future<void> _flipCamera() async {
    if (_cameras.length < 2) return;
    await _controller?.stopImageStream();
    _controller?.dispose();
    _cameraIndex = (_cameraIndex + 1) % _cameras.length;
    await _startController();
  }

  @override
  void dispose() {
    _setTicker?.cancel();
    _restTimer?.cancel();
    _controller?.stopImageStream();
    _controller?.dispose();
    _detector.close();
    _tts.stop();
    super.dispose();
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_permissionDenied) return _permissionScreen();

    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final previewSize = _controller!.value.previewSize;
    // previewSize comes in landscape; portrait swap for the painter.
    final imageSize = previewSize != null
        ? Size(previewSize.height, previewSize.width)
        : Size.zero;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ① FR-2.1: Camera preview — aspect-ratio-preserving cover fit so
          //   the feed isn't stretched vertically on phones whose screen
          //   aspect differs from the camera sensor (most do).
          _CoverCameraPreview(
            controller: _controller!,
            imageSize: imageSize,
          ),

          // ② FR-2.1: 33-landmark skeleton overlay
          if (_poses.isNotEmpty)
            CustomPaint(
              painter: PosePainter(
                poses: _poses,
                imageSize: imageSize,
                cameraLensDirection: _cameras[_cameraIndex].lensDirection,
              ),
            ),

          // ③ HUD
          SafeArea(
            child: Column(
              children: [
                _topBar(context),
                if (_sessionStarted) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 40, vertical: 8),
                    child: FormGauge(
                      angle: _currentAngle,
                      minAngle: widget.exercise.targetAngleMin,
                      maxAngle: widget.exercise.targetAngleMax,
                      visible: _showGauge,
                      onTap: () => setState(() => _showGauge = !_showGauge),
                    ),
                  ),
                  const Spacer(),
                  _bottomPanel(),
                ] else
                  _gesturePrompt(),
              ],
            ),
          ),

          // ④ Body-lost warning — shown mid-session when landmarks drop below
          //    confidence. Rest overlay takes priority if both somehow coincide.
          if (_sessionStarted && _bodyLostDuringSession && _restCountdown == null)
            _bodyLostOverlay(),

          // ⑤ Inter-set rest overlay
          if (_restCountdown != null) _restOverlay(),
        ],
      ),
    );
  }

  Widget _topBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
      child: Row(
        children: [
          _HudIcon(
            icon: Icons.arrow_back_rounded,
            onTap: () => context.pop(),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              children: [
                Text(
                  widget.exercise.name.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                  ),
                ),
                if (_sessionStarted)
                  Text(
                    _formatDuration(_setElapsed),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 12,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          _HudIcon(
            icon: _ttsEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
            onTap: () {
              setState(() => _ttsEnabled = !_ttsEnabled);
              if (!_ttsEnabled) _tts.stop();
            },
          ),
          const SizedBox(width: 4),
          _HudIcon(
            icon: Icons.flip_camera_android_rounded,
            onTap: _flipCamera,
          ),
        ],
      ),
    );
  }

  Widget _bottomPanel() {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'REPS',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 11,
                        letterSpacing: 1.6,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '$_repCount / $_targetReps',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'SET',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 11,
                      letterSpacing: 1.6,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '$_currentSet / $_totalSets',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Rep progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _repCount / _targetReps,
              minHeight: 6,
              backgroundColor: Colors.white.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation(cs.primary),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.3)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.stop_rounded, size: 18),
                  label: const Text('END'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _gesturePrompt() {
    final cs = Theme.of(context).colorScheme;
    const shadow = Shadow(blurRadius: 10, color: Colors.black87);

    // ── Phase 1: body not yet confirmed ──────────────────────────────────────
    if (!_bodyInFrame) {
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.accessibility_new_rounded,
                size: 80,
                color: Colors.white.withValues(alpha: 0.85),
                shadows: const [shadow],
              ),
              const SizedBox(height: 20),
              const Text(
                'Step back from the phone',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  shadows: [shadow],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Make sure your full body is visible\nso the AI can track your form',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 14,
                  height: 1.5,
                  shadows: const [shadow],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              // Pulsing indicator to show the camera is actively scanning
              _ScanningDot(color: cs.primary),
            ],
          ),
        ),
      );
    }

    // ── Phase 2: body confirmed, waiting for hand gesture ────────────────────
    final holding = _gestureStartAt != null;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.back_hand_outlined,
              size: 80,
              color: holding ? cs.primary : Colors.white,
              shadows: const [shadow],
            ),
            const SizedBox(height: 20),
            Text(
              holding ? 'Hold still…' : 'Show open hand to start',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
                shadows: [shadow],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            if (holding)
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: cs.primary, width: 3),
                  color: cs.primary.withValues(alpha: 0.25),
                ),
                child: Center(
                  child: Text(
                    '$_gestureCountdown',
                    style: TextStyle(
                      color: cs.primary,
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      shadows: const [shadow],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _bodyLostOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.55),
        child: SafeArea(
          child: Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.82),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.orange.withValues(alpha: 0.7),
                  width: 1.5,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.accessibility_new_rounded,
                    color: Colors.orange,
                    size: 56,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Full body not detected',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Step back so your full body is\nvisible to resume tracking',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.72),
                      fontSize: 14,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  const _ScanningDot(color: Colors.orange),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _restOverlay() {
    final cs = Theme.of(context).colorScheme;
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.75),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'NEXT UP',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 12,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Set $_currentSet of $_totalSets',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 28),
                Container(
                  width: 160,
                  height: 160,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: cs.primary, width: 4),
                  ),
                  child: Text(
                    '${_restCountdown ?? 0}',
                    style: TextStyle(
                      color: cs.primary,
                      fontSize: 72,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                TextButton(
                  onPressed: _skipRest,
                  child: const Text(
                    'Skip rest',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _permissionScreen() {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.camera_alt_outlined,
                  color: cs.onSurface.withValues(alpha: 0.5), size: 64),
              const SizedBox(height: 24),
              Text(
                'Camera access needed',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'FitForm needs the camera to track your form. Enable it in Settings.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: openAppSettings,
                child: const Text('Open Settings'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final mm = d.inMinutes.toString().padLeft(2, '0');
    final ss = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }
}

/// Camera preview wrapped in `FittedBox(BoxFit.cover)` so the sensor's native
/// aspect ratio is preserved. The phone screen and sensor are rarely the same
/// aspect — without this, `StackFit.expand` stretches the preview vertically.
class _CoverCameraPreview extends StatelessWidget {
  const _CoverCameraPreview({
    required this.controller,
    required this.imageSize,
  });

  final CameraController controller;
  final Size imageSize;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: imageSize.width,
            height: imageSize.height,
            child: CameraPreview(controller),
          ),
        ),
      ),
    );
  }
}

/// Pulsing dot shown during Phase 1 to indicate the camera is actively
/// scanning for the user's body landmarks.
class _ScanningDot extends StatefulWidget {
  const _ScanningDot({required this.color});
  final Color color;

  @override
  State<_ScanningDot> createState() => _ScanningDotState();
}

class _ScanningDotState extends State<_ScanningDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: widget.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Scanning…',
            style: TextStyle(
              color: widget.color,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

/// Small dark-glass HUD icon button used along the top bar.
class _HudIcon extends StatelessWidget {
  const _HudIcon({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.4),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, size: 20, color: Colors.white),
        ),
      ),
    );
  }
}
