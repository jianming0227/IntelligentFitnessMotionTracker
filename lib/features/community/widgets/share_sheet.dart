import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/utils/app_log.dart';
import '../../../core/utils/display_name.dart';
import '../../../core/utils/friendly_error.dart';
import '../../auth/providers/auth_providers.dart';
import '../logic/community_format.dart';
import '../providers/community_providers.dart';
import 'community_common.dart';
import 'share_card.dart';

/// Share sheet for a finished workout: pick a card (stats or own photo),
/// then share it to other apps, or post it to the community (online users).
Future<void> showShareSheet(
  BuildContext context, {
  required ShareCardData data,
  String? workoutSessionId,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => _ShareSheet(data: data, workoutSessionId: workoutSessionId),
);

class _ShareSheet extends ConsumerStatefulWidget {
  const _ShareSheet({required this.data, this.workoutSessionId});

  final ShareCardData data;
  final String? workoutSessionId;

  @override
  ConsumerState<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends ConsumerState<_ShareSheet> {
  final _cardKey = GlobalKey();
  final _caption = TextEditingController();
  ShareTemplate _template = ShareTemplate.stats;
  File? _photo;
  bool _busy = false;

  /// Photo card picked but no photo yet: nothing to share.
  bool get _ready => _template == ShareTemplate.stats || _photo != null;

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      if (source == ImageSource.camera &&
          !(await Permission.camera.request()).isGranted) {
        _toast('Camera permission is needed to take a photo.');
        return;
      }
      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (picked != null && mounted) {
        setState(() => _photo = File(picked.path));
      }
    } catch (e) {
      AppLog.warn('Community', 'Photo pick failed: $e');
      _toast('Could not open the photo.');
    }
  }

  /// The card as a 1080 × 1350 PNG.
  Future<Uint8List> _capture() async {
    final boundary =
        _cardKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(
      pixelRatio: 1080 / ShareCard.size.width,
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return bytes!.buffer.asUint8List();
  }

  Future<void> _shareOut() async {
    setState(() => _busy = true);
    try {
      final png = await _capture();
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/fitform_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(png, flush: true);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'image/png')],
          text: 'My ${widget.data.exerciseName} workout on FitForm',
        ),
      );
    } catch (e) {
      AppLog.warn('Community', 'Share failed: $e');
      _toast('Could not share the card.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _post() async {
    // Display name first (asked once, saved to profiles.full_name).
    var name = await ref.read(displayNameProvider.future);
    if (name == null) {
      if (!mounted) return;
      final email = ref.read(supabaseServiceProvider).currentUser?.email;
      name = await askDisplayName(
        context,
        initial: displayNameFromEmail(email),
      );
      if (name == null) return;
      try {
        await ref.read(displayNameProvider.notifier).save(name);
      } catch (e) {
        _toast(friendlyError(e));
        return;
      }
    }

    setState(() => _busy = true);
    try {
      final png = await _capture();
      final caption = _caption.text.trim();
      final post = await ref
          .read(communityRepositoryProvider)
          .createPost(
            authorName: name,
            exerciseName: widget.data.exerciseName,
            stats: widget.data.stats,
            caption: caption.isEmpty ? null : caption,
            imagePng: png,
            workoutSessionId: widget.workoutSessionId,
          );
      ref.read(feedProvider.notifier).prepend(post);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Posted to the community')),
      );
    } catch (e) {
      AppLog.error('Community', 'Post failed', e);
      _toast(friendlyError(e));
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final online = ref.watch(isOnlineUserProvider);
    final media = MediaQuery.of(context);
    // Card preview width: fits small phones and leaves room for the controls.
    final previewWidth = (media.size.width - 40).clamp(200.0, 280.0);

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Share workout',
                style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              SegmentedButton<ShareTemplate>(
                showSelectedIcon: false,
                // App lime instead of the theme's secondary container.
                style: SegmentedButton.styleFrom(
                  selectedBackgroundColor: cs.primary,
                  selectedForegroundColor: cs.onPrimary,
                ),
                segments: const [
                  ButtonSegment(
                    value: ShareTemplate.stats,
                    label: Text('Stats'),
                    icon: Icon(Icons.bar_chart_rounded, size: 18),
                  ),
                  ButtonSegment(
                    value: ShareTemplate.photo,
                    label: Text('Photo'),
                    icon: Icon(Icons.photo_outlined, size: 18),
                  ),
                ],
                selected: {_template},
                onSelectionChanged: _busy
                    ? null
                    : (s) => setState(() => _template = s.first),
              ),
              const SizedBox(height: 16),
              Center(
                child: SizedBox(
                  width: previewWidth,
                  child: AspectRatio(
                    aspectRatio: ShareCard.size.aspectRatio,
                    child: _ready
                        ? FittedBox(
                            child: RepaintBoundary(
                              key: _cardKey,
                              child: ShareCard(
                                data: widget.data,
                                template: _template,
                                photo: _photo,
                              ),
                            ),
                          )
                        : _PhotoPlaceholder(
                            onPick: () => _pickPhoto(ImageSource.gallery),
                          ),
                  ),
                ),
              ),
              if (_template == ShareTemplate.photo) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _busy
                            ? null
                            : () => _pickPhoto(ImageSource.gallery),
                        icon: const Icon(
                          Icons.photo_library_outlined,
                          size: 18,
                        ),
                        label: const Text('Gallery'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _busy
                            ? null
                            : () => _pickPhoto(ImageSource.camera),
                        icon: const Icon(Icons.photo_camera_outlined, size: 18),
                        label: const Text('Camera'),
                      ),
                    ),
                  ],
                ),
              ],
              if (online) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: _caption,
                  enabled: !_busy,
                  maxLength: maxCaptionLength,
                  minLines: 1,
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'Add a caption (optional)',
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      onPressed: _busy || !_ready ? null : _shareOut,
                      icon: const Icon(Icons.ios_share_rounded, size: 18),
                      label: const Text('Share'),
                    ),
                  ),
                  if (online) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                        ),
                        onPressed: _busy || !_ready ? null : _post,
                        icon: _busy
                            ? SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: cs.onPrimary,
                                ),
                              )
                            : const Icon(Icons.send_rounded, size: 18),
                        label: const Text('Post'),
                      ),
                    ),
                  ],
                ],
              ),
              if (!online) ...[
                const SizedBox(height: 12),
                const CommunitySignInNotice(compact: true),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotoPlaceholder extends StatelessWidget {
  const _PhotoPlaceholder({required this.onPick});
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final muted = cs.onSurface.withValues(alpha: 0.55);
    return Material(
      color: cs.onSurface.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onPick,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_photo_alternate_outlined, size: 36, color: muted),
              const SizedBox(height: 8),
              Text(
                'Pick a photo',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
