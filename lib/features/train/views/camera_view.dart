import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
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
  // ── FR-2.1: Camera — live feed capture ──────────────────────────────────────
  List<CameraDescription> _cameras = [];
  CameraController? _controller;
  int _cameraIndex = 0;
  bool _permissionDenied = false;

  // ── FR-2.1: ML Kit pose detector — 33 skeletal landmark extraction ───────────
  final _detector = PoseDetector(
    options: PoseDetectorOptions(mode: PoseDetectionMode.stream),
  );
  bool _isDetecting = false;
  List<Pose> _poses = [];
  double? _currentAngle;

  // ── FR-2.4: Rep counter state ────────────────────────────────────────────────
  bool _isDown = false;
  int _repCount = 0;
  int _currentSet = 1;
  static const int _totalSets = 3;
  static const int _targetReps = 10;

  // ── FR-3.1: Per-set metrics collection ──────────────────────────────────────
  // Tracks per-rep durations and green-zone frame ratio for SetMetrics packaging.
  DateTime? _repStartTime;
  final List<int> _currentRepDurations = [];
  int _greenFrames = 0;
  int _totalFrames = 0;
  final List<SetMetrics> _completedSets = [];

  // FR-2.4: TUT — tracks when the joint entered the target zone to accumulate ms.
  DateTime? _tutZoneEnteredAt;
  int _tutMs = 0;

  // True while the coaching bottom sheet is visible — pauses rep counting.
  bool _sessionPaused = false;

  // ── FR-2.3: TTS corrective voice-overs ──────────────────────────────────────
  final FlutterTts _tts = FlutterTts();
  // Timestamp of the last spoken cue — enforces the 4 s debounce.
  DateTime? _lastCueAt;
  // How long the angle has continuously been outside the target zone.
  DateTime? _badFormSince;

  // ── UI ──────────────────────────────────────────────────────────────────────
  bool _showGauge = true;

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
      (c) => c.lensDirection == CameraLensDirection.back,
    );
    if (_cameraIndex == -1) _cameraIndex = 0;

    await _startController();
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
      if (poses.isNotEmpty) {
        angle = _jointAngle(poses.first);
        if (angle != null) {
          // FR-3.1: Track how many frames the joint is within the target zone
          _totalFrames++;
          final inZone = angle >= widget.exercise.targetAngleMin &&
              angle <= widget.exercise.targetAngleMax;
          if (inZone) {
            _greenFrames++;
            // FR-2.4: Accumulate TUT — add elapsed ms since entering the zone
            final now = DateTime.now();
            _tutZoneEnteredAt ??= now;
            _tutMs += now.difference(_tutZoneEnteredAt!).inMilliseconds;
            _tutZoneEnteredAt = now;
          } else {
            _tutZoneEnteredAt = null;
          }
          _checkBadForm(angle);
          _countRep(angle);
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

  // FR-2.1: Convert raw NV21 camera frame into an InputImage for ML Kit.
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

  // FR-2.3: Fires a TTS correction cue when the joint angle has been outside
  // the target zone continuously for >1.5 s. Debounced to once per 4 s.
  void _checkBadForm(double angle) {
    final inZone = angle >= widget.exercise.targetAngleMin &&
        angle <= widget.exercise.targetAngleMax;

    if (inZone) {
      _badFormSince = null;
      return;
    }

    final now = DateTime.now();
    _badFormSince ??= now;

    final badDuration = now.difference(_badFormSince!);
    if (badDuration.inMilliseconds < 1500) return;

    final debounceOk = _lastCueAt == null ||
        now.difference(_lastCueAt!).inSeconds >= 4;
    if (!debounceOk) return;

    _lastCueAt = now;
    _badFormSince = now; // reset so the next cue waits another 1.5 s

    final cues = widget.exercise.id == 'bicep_curl'
        ? [
            'Full extension at the bottom',
            'Squeeze at the top',
            'Keep your elbow still',
          ]
        : [
            'Go deeper',
            'Keep your chest up',
            'Knees track over toes',
          ];

    final cue = cues[DateTime.now().second % cues.length];
    _tts.speak(cue);
  }

  // FR-2.2: Routes to the correct angle calculation based on the exercise.
  double? _jointAngle(Pose pose) {
    if (widget.exercise.id == 'bicep_curl') return _elbowAngle(pose);
    return _kneeAngle(pose);
  }

  // FR-2.2: Knee angle (hip → knee → ankle) — used for squats.
  double? _kneeAngle(Pose pose) {
    final hip = pose.landmarks[PoseLandmarkType.leftHip];
    final knee = pose.landmarks[PoseLandmarkType.leftKnee];
    final ankle = pose.landmarks[PoseLandmarkType.leftAnkle];
    if (hip == null || knee == null || ankle == null) return null;

    final ba = Offset(hip.x - knee.x, hip.y - knee.y);
    final bc = Offset(ankle.x - knee.x, ankle.y - knee.y);
    final cosA =
        (ba.dx * bc.dx + ba.dy * bc.dy) / (ba.distance * bc.distance);
    return acos(cosA.clamp(-1.0, 1.0)) * 180 / pi;
  }

  // FR-2.2: Elbow angle (shoulder → elbow → wrist) — used for bicep curls.
  double? _elbowAngle(Pose pose) {
    final shoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final elbow = pose.landmarks[PoseLandmarkType.leftElbow];
    final wrist = pose.landmarks[PoseLandmarkType.leftWrist];
    if (shoulder == null || elbow == null || wrist == null) return null;

    final ba = Offset(shoulder.x - elbow.x, shoulder.y - elbow.y);
    final bc = Offset(wrist.x - elbow.x, wrist.y - elbow.y);
    final cosA =
        (ba.dx * bc.dx + ba.dy * bc.dy) / (ba.distance * bc.distance);
    return acos(cosA.clamp(-1.0, 1.0)) * 180 / pi;
  }

  // FR-2.4 / FR-3.1: Rep counter that also records per-rep duration for fatigue
  // index calculation. A rep = angle drops below targetAngleMax (down phase)
  // then rises back above 160° (standing phase).
  void _countRep(double angle) {
    if (_sessionPaused) return;

    if (!_isDown && angle < widget.exercise.targetAngleMax) {
      _isDown = true;
      _repStartTime = DateTime.now(); // start timing this rep
    } else if (_isDown && angle > 160) {
      _isDown = false;

      // FR-3.1: Log how long this rep took
      if (_repStartTime != null) {
        _currentRepDurations
            .add(DateTime.now().difference(_repStartTime!).inMilliseconds);
        _repStartTime = null;
      }

      _repCount++;
      if (_repCount >= _targetReps) {
        _onSetComplete();
      } else {
        setState(() {}); // update rep display
      }
    }
  }

  // FR-3.1: Package set metrics and show the coaching bottom sheet.
  void _onSetComplete() {
    _sessionPaused = true;

    // Fatigue index: (last rep duration / first rep duration) - 1
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

    // Reset per-set counters
    _greenFrames = 0;
    _totalFrames = 0;
    _tutMs = 0;
    _tutZoneEnteredAt = null;
    _currentRepDurations.clear();

    setState(() {});

    // Show coaching sheet — "Continue" either starts the next set or ends session
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
          Navigator.of(context).pop(); // dismiss sheet
          if (_currentSet < _totalSets) {
            setState(() {
              _repCount = 0;
              _currentSet++;
              _sessionPaused = false;
            });
          } else {
            // All sets done — navigate to session summary (disposes camera)
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

  Future<void> _flipCamera() async {
    if (_cameras.length < 2) return;
    await _controller?.stopImageStream();
    _controller?.dispose();
    _cameraIndex = (_cameraIndex + 1) % _cameras.length;
    await _startController();
  }

  @override
  void dispose() {
    _controller?.stopImageStream();
    _controller?.dispose();
    _detector.close();
    _tts.stop();
    super.dispose();
  }

  // ── Build ────────────────────────────────────────────────────────────────────

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
    // previewSize comes in landscape; swap for portrait
    final imageSize = previewSize != null
        ? Size(previewSize.height, previewSize.width)
        : Size.zero;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ① FR-2.1: Live camera preview
          CameraPreview(_controller!),

          // ② FR-2.1: 33-landmark skeleton overlay
          if (_poses.isNotEmpty)
            CustomPaint(
              painter: PosePainter(
                poses: _poses,
                imageSize: imageSize,
                cameraLensDirection: _cameras[_cameraIndex].lensDirection,
              ),
            ),

          // ③ HUD controls
          SafeArea(
            child: Column(
              children: [
                _topBar(context),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 40, vertical: 8),
                  // FR-2.2: Real-time form evaluation gauge
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _topBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: () => context.pop(),
          ),
          Expanded(
            child: Text(
              widget.exercise.name.toUpperCase(),
              textAlign: TextAlign.center,
              style: AppTextStyles.titleMedium.copyWith(
                color: Colors.white,
                letterSpacing: 2,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_android_rounded,
                color: Colors.white),
            onPressed: _flipCamera,
          ),
        ],
      ),
    );
  }

  Widget _bottomPanel() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // FR-2.4: Rep count display
          Text(
            '$_repCount',
            style: AppTextStyles.display.copyWith(
              fontSize: 72,
              color: Colors.white,
            ),
          ),
          Text('reps', style: AppTextStyles.bodyMedium),

          const SizedBox(height: 16),

          // FR-2.4: Set progress dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_totalSets, (i) {
              final done = i < _currentSet - 1;
              final active = i == _currentSet - 1;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 5),
                width: active ? 14 : 10,
                height: active ? 14 : 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done
                      ? AppColors.secondary
                      : active
                          ? AppColors.primary
                          : AppColors.border,
                ),
              );
            }),
          ),
          const SizedBox(height: 4),
          Text(
            'Set $_currentSet of $_totalSets',
            style: AppTextStyles.caption,
          ),

          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => context.pop(),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text('STOP SESSION'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _permissionScreen() {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.camera_alt_outlined,
                  color: AppColors.textMuted, size: 64),
              const SizedBox(height: 24),
              Text('Camera access needed', style: AppTextStyles.titleMedium),
              const SizedBox(height: 8),
              Text(
                'FitForm needs the camera to track your form. Enable it in Settings.',
                style: AppTextStyles.bodyMedium,
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
}
