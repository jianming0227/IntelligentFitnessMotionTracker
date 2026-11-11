import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

import '../data/exercise_tutorials.dart';
import '../data/model_viewer_bridge.dart';
import '../models/exercise.dart';

/// Fullscreen 3D demo (route `/train/tutorial`, extra: [Exercise]).
/// Drag to rotate, pinch to zoom. The exercise title sits at the top; timed
/// form cues are captioned at the bottom, driven by the model's own
/// animation clock (reported from `<model-viewer>`), so they stay in sync
/// however long the model takes to load.
class TutorialFullscreenView extends ConsumerStatefulWidget {
  const TutorialFullscreenView({super.key, required this.exercise});

  final Exercise exercise;

  @override
  ConsumerState<TutorialFullscreenView> createState() =>
      _TutorialFullscreenViewState();
}

class _TutorialFullscreenViewState
    extends ConsumerState<TutorialFullscreenView> {
  // Last animation time reported by the page, and when it arrived; between
  // reports (every 200 ms) the time is extrapolated so captions stay smooth.
  double? _animTime;
  final _sinceReport = Stopwatch();
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(
      const Duration(milliseconds: 200),
      (_) => setState(() {}),
    );
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  void _onTime(double seconds) {
    _animTime = seconds;
    _sinceReport
      ..reset()
      ..start();
  }

  /// Null until the model has loaded and started playing: no caption before
  /// the animation is actually running.
  Duration? get _clock {
    final t = _animTime;
    if (t == null) return null;
    return Duration(
      milliseconds: (t * 1000).round() + _sinceReport.elapsedMilliseconds,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tutorial = tutorialFor(widget.exercise.id);
    final cues = tutorial?.cues ?? const <TutorialCue>[];
    final tt = Theme.of(context).textTheme;
    final clock = _clock;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF111317), Color(0xFF000000)],
              ),
            ),
          ),
          if (tutorial == null)
            Center(
              child: Text(
                '3D demo unavailable',
                style: tt.bodyLarge?.copyWith(color: Colors.white70),
              ),
            )
          else
            ModelViewer(
              src: tutorial.model,
              alt: '3D ${widget.exercise.name} demonstration',
              autoPlay: true,
              animationName: tutorial.animation,
              cameraControls: true, // drag to rotate, pinch to zoom
              disablePan: true,
              interactionPrompt: InteractionPrompt.auto,
              cameraOrbit: tutorial.fullOrbit,
              cameraTarget: tutorial.fullTarget,
              // Zoom limits: close enough to see the grip, never inside him.
              minCameraOrbit: 'auto 20deg 1.2m',
              maxCameraOrbit: 'auto 100deg 7m',
              fieldOfView: '30deg',
              exposure: 1.1,
              shadowIntensity: 1,
              environmentImage: 'neutral',
              backgroundColor: Colors.transparent,
              loading: Loading.eager,
              debugLogging: false,
              relatedJs: modelViewerBridgeJs,
              javascriptChannels: modelViewerChannels(onTime: _onTime),
            ),
          // Exercise title, pinned to the top (a Row left un-positioned in an
          // expanded Stack gets the full screen height and centres itself).
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  children: [
                    Material(
                      color: Colors.white.withValues(alpha: 0.15),
                      shape: const CircleBorder(),
                      child: IconButton(
                        tooltip: 'Close',
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                        ),
                        onPressed: () => context.pop(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${widget.exercise.name} demo',
                            style: tt.titleMedium?.copyWith(
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'Drag to rotate · pinch to zoom',
                            style: tt.bodyMedium?.copyWith(
                              color: Colors.white60,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (tutorial != null && cues.isNotEmpty && clock != null)
            Positioned(
              left: 24,
              right: 24,
              bottom: 40 + MediaQuery.of(context).padding.bottom,
              child: IgnorePointer(
                child: _CueCaption(
                  cue: cueAt(cues, clock, loopSeconds: tutorial.loopSeconds),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CueCaption extends StatelessWidget {
  const _CueCaption({required this.cue});

  final TutorialCue? cue;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = cue?.text;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: text == null
          ? const SizedBox.shrink()
          : Container(
              key: ValueKey(text),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: cs.primary.withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.tips_and_updates_rounded,
                    color: cs.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      text,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
