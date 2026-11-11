import 'package:flutter/material.dart';

import '../logic/community_format.dart';

/// Round avatar with the name's first letter.
class InitialAvatar extends StatelessWidget {
  const InitialAvatar({super.key, required this.name, this.size = 40});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: Text(
        initialOf(name),
        style: TextStyle(
          color: cs.primary,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.42,
        ),
      ),
    );
  }
}

/// Shown instead of Community content for offline demo / signed-out users.
class CommunitySignInNotice extends StatelessWidget {
  const CommunitySignInNotice({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final muted = cs.onSurface.withValues(alpha: 0.6);
    final text = Text(
      'Sign in with an account to see and share workouts with the community.',
      style: tt.bodyMedium?.copyWith(color: muted, height: 1.4),
      textAlign: compact ? TextAlign.start : TextAlign.center,
    );
    if (compact) {
      return Row(
        children: [
          Icon(Icons.lock_outline_rounded, size: 20, color: muted),
          const SizedBox(width: 12),
          Expanded(child: text),
        ],
      );
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.groups_outlined, size: 48, color: muted),
            const SizedBox(height: 16),
            Text('Community needs an account', style: tt.titleMedium),
            const SizedBox(height: 8),
            text,
          ],
        ),
      ),
    );
  }
}

/// Asks for a display name (1-40 characters). Returns the cleaned name, or
/// null when cancelled.
Future<String?> askDisplayName(BuildContext context, {String initial = ''}) =>
    showDialog<String>(
      context: context,
      builder: (_) => _DisplayNameDialog(initial: initial),
    );

class _DisplayNameDialog extends StatefulWidget {
  const _DisplayNameDialog({required this.initial});
  final String initial;

  @override
  State<_DisplayNameDialog> createState() => _DisplayNameDialogState();
}

class _DisplayNameDialogState extends State<_DisplayNameDialog> {
  late final _ctrl = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final valid = validDisplayName(_ctrl.text);
    return AlertDialog(
      title: const Text('Display name'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Shown on your community posts.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ctrl,
            autofocus: true,
            maxLength: 40,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(hintText: 'Your name'),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) {
              if (valid != null) Navigator.of(context).pop(valid);
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: valid == null
              ? null
              : () => Navigator.of(context).pop(valid),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
