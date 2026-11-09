import 'dart:async';

import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

import '../data/exercise_tutorials.dart';
import '../data/model_viewer_bridge.dart';

/// Exercise-detail hero: the animated 3D demo, framed per exercise and not
/// interactive (so the page doesn't fight the user's swipes). Tapping it
/// opens the fullscreen viewer where the model can be rotated and zoomed.
///
/// The poster (a still of the opening muscle-highlight pause) covers the
/// WebGL view while it loads, then fades out as soon as `<model-viewer>`
/// reports `load` (a timer is only the fallback). It sits ON TOP of the model and
/// is removed once faded: left underneath a transparent model it showed
/// through as a frozen "ghost" frame behind the moving man.
///
/// With "remove animations" on, only the poster is shown.
class TutorialModelHero extends StatefulWidget {
  const TutorialModelHero({
    super.key,
    required this.tutorial,
    required this.fallback,
    this.onTap,
  });

  final ExerciseTutorial tutorial;
  final Widget fallback;
  final VoidCallback? onTap;

  @override
  State<TutorialModelHero> createState() => _TutorialModelHeroState();
}

class _TutorialModelHeroState extends State<TutorialModelHero> {
  // Fallback only: normally the poster fades on the model's `load` event.
  // The clip opens with a 1.4 s still pause that matches the poster, so the
  // hand-over is invisible either way.
  static const _posterHold = Duration(milliseconds: 4000);
  static const _posterFade = Duration(milliseconds: 350);

  Timer? _timer;
  bool _showPoster = true;
  bool _posterGone = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(_posterHold, _hidePoster);
  }

  void _hidePoster() {
    _timer?.cancel();
    if (mounted && _showPoster) setState(() => _showPoster = false);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.of(context).disableAnimations;
    final t = widget.tutorial;
    final poster = Image.asset(
      t.poster,
      fit: BoxFit.cover,
      alignment: const Alignment(0, -0.3),
      errorBuilder: (_, _, _) => widget.fallback,
    );

    return Semantics(
      button: widget.onTap != null,
      label: '3D exercise demo. Tap to rotate and zoom with form cues.',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF111317), Color(0xFF000000)],
            ),
          ),
          child: still
              ? poster
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    // IgnorePointer: the platform view would otherwise
                    // swallow the tap meant for the GestureDetector above.
                    IgnorePointer(
                      child: ModelViewer(
                        src: t.model,
                        alt: 'Animated 3D exercise demonstration',
                        autoPlay: true,
                        animationName: t.animation,
                        cameraControls: false,
                        disableZoom: true,
                        disablePan: true,
                        disableTap: true,
                        interactionPrompt: InteractionPrompt.none,
                        // Per-exercise framing, kept above the info panel
                        // that overlaps the bottom of the hero.
                        cameraOrbit: t.heroOrbit,
                        cameraTarget: t.heroTarget,
                        fieldOfView: t.heroFieldOfView,
                        exposure: 1.1,
                        shadowIntensity: 1,
                        environmentImage: 'neutral',
                        backgroundColor: Colors.transparent,
                        loading: Loading.eager,
                        debugLogging: false,
                        relatedJs: modelViewerBridgeJs,
                        javascriptChannels:
                            modelViewerChannels(onLoaded: _hidePoster),
                      ),
                    ),
                    if (!_posterGone)
                      IgnorePointer(
                        child: AnimatedOpacity(
                          opacity: _showPoster ? 1 : 0,
                          duration: _posterFade,
                          onEnd: () {
                            if (!_showPoster && mounted) {
                              setState(() => _posterGone = true);
                            }
                          },
                          child: poster,
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}
