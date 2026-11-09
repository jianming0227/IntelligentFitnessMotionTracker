import 'package:model_viewer_plus/model_viewer_plus.dart';

/// Tiny bridge from the `<model-viewer>` page back to Flutter.
///
/// * `MvLoad` posts once when the model has loaded (and its autoplay starts).
/// * `MvTime` posts the animation's `currentTime` (seconds) every 200 ms.
///
/// Channels are created by webview_flutter as `window.<name>.postMessage`.
const String modelViewerBridgeJs = '''
(function () {
  var mv = document.querySelector('model-viewer');
  if (!mv) return;
  function send(ch, msg) {
    try { if (window[ch]) window[ch].postMessage(msg); } catch (e) {}
  }
  mv.addEventListener('load', function () { send('MvLoad', 'load'); });
  setInterval(function () {
    if (mv.loaded) send('MvTime', String(mv.currentTime));
  }, 200);
})();
''';

Set<JavascriptChannel> modelViewerChannels({
  void Function()? onLoaded,
  void Function(double seconds)? onTime,
}) => {
  if (onLoaded != null)
    JavascriptChannel('MvLoad', onMessageReceived: (_) => onLoaded()),
  if (onTime != null)
    JavascriptChannel(
      'MvTime',
      onMessageReceived: (m) {
        final t = double.tryParse(m.message);
        if (t != null) onTime(t);
      },
    ),
};
