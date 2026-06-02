import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Shared chrome for the Login and Sign-up screens: hero photo on the upper
/// half, tab switcher + avatar over it, a large heading, then a form area
/// that floats on the surface color with social buttons + primary pill CTA
/// pinned to the bottom.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.activeTab,
    required this.heading,
    required this.subtitle,
    required this.fields,
    required this.primaryLabel,
    required this.onPrimary,
    required this.loading,
    required this.error,
  });

  /// `'login'` or `'signup'` — drives which tab shows the accent underline.
  final String activeTab;
  final Widget heading;
  final String subtitle;
  final List<Widget> fields;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final bool loading;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: cs.surface,
      resizeToAvoidBottomInset: true,
      body: Column(
        children: [
          // ── Hero panel — clipped to an asymmetric curve so it bleeds into
          //    the form panel below in a soft, non-straight divider.
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.52,
            child: ClipPath(
              clipper: _HeroCurveClipper(),
              child: Stack(
              fit: StackFit.expand,
              children: [
                _HeroImage(),
                // Bottom-darken gradient so the heading stays legible.
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x33000000),
                        Color(0x99000000),
                        Color(0xCC000000),
                      ],
                      stops: [0.0, 0.6, 1.0],
                    ),
                  ),
                ),
                SafeArea(
                  bottom: false,
                  // Bottom padding pushes content above the diagonal cut so
                  // the rising right edge never overlaps the subtitle.
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 90),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _AuthTab(
                              label: 'Login',
                              active: activeTab == 'login',
                              onTap: () => context.go('/login'),
                            ),
                            const SizedBox(width: 18),
                            _AuthTab(
                              label: 'Sign up',
                              active: activeTab == 'signup',
                              onTap: () => context.go('/register'),
                            ),
                          ],
                        ),
                        const Spacer(),
                        DefaultTextStyle(
                          // Base weight = regular so "Welcome back," reads
                          // light; the inner TextSpan for the name keeps
                          // its own bold w800 and stands out cleanly.
                          style: tt.displayMedium!.copyWith(
                            color: Colors.white,
                            fontSize: 30,
                            height: 1.15,
                            fontWeight: FontWeight.w300,
                          ),
                          child: heading,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          subtitle,
                          style: tt.bodyMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.75),
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 1),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            ),
          ),

          // ── Form panel ──────────────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              keyboardDismissBehavior:
                  ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < fields.length; i++) ...[
                    fields[i],
                    if (i < fields.length - 1) const SizedBox(height: 18),
                  ],
                  if (error != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      error!,
                      style: tt.bodyMedium?.copyWith(color: cs.error),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 24),
                  _ActionRow(
                    primaryLabel: primaryLabel,
                    onPrimary: onPrimary,
                    loading: loading,
                  ),
                  SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroImage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Image.asset(
      'assets/images/situp.png',
      fit: BoxFit.cover,
      alignment: Alignment.center,
      errorBuilder: (_, _, _) => DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              cs.surfaceContainerHighest,
              cs.primary.withValues(alpha: 0.45),
            ],
          ),
        ),
      ),
    );
  }
}

class _AuthTab extends StatelessWidget {
  const _AuthTab({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color =
        active ? Colors.white : Colors.white.withValues(alpha: 0.6);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 6),
          Container(
            width: label.length * 8.0,
            height: 2,
            color: active ? cs.primary : Colors.transparent,
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.primaryLabel,
    required this.onPrimary,
    required this.loading,
  });

  final String primaryLabel;
  final VoidCallback onPrimary;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerRight,
      child: SizedBox(
        width: 170,
        child: ElevatedButton(
          onPressed: loading ? null : onPrimary,
          child: loading
              ? SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: cs.onPrimary,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(primaryLabel),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right_rounded, size: 22),
                  ],
                ),
        ),
      ),
    );
  }
}

// ── Reusable underline-style field ────────────────────────────────────────────

/// Minimal underline-style text field used by both auth screens. Renders the
/// label above the input, a bottom border, and an optional trailing icon for
/// validation state (check / red X) or password visibility.
class AuthField extends StatelessWidget {
  const AuthField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.keyboardType,
    this.obscureText = false,
    this.isPassword = false,
    this.onTogglePassword,
    this.validator,
    this.textInputAction,
    this.onSubmitted,
    this.errorText,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final TextInputType? keyboardType;
  final bool obscureText;
  final bool isPassword;
  final VoidCallback? onTogglePassword;
  final String? Function(String?)? validator;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final hasError = errorText != null;
    final lineColor = hasError
        ? cs.error
        : cs.onSurface.withValues(alpha: 0.22);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              errorText!,
              style: tt.bodyMedium?.copyWith(
                color: cs.error,
                fontSize: 12,
              ),
            ),
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: TextFormField(
                controller: controller,
                keyboardType: keyboardType,
                obscureText: obscureText,
                textInputAction: textInputAction,
                onFieldSubmitted: onSubmitted,
                validator: validator,
                style: tt.bodyLarge?.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: cs.onSurface,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  filled: false,
                  // Reference uses the label itself as the placeholder.
                  hintText: label,
                  hintStyle: tt.bodyLarge?.copyWith(
                    fontSize: 16,
                    color: cs.onSurface.withValues(alpha: 0.45),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 0,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                  errorStyle: const TextStyle(height: 0),
                ),
              ),
            ),
            if (isPassword)
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  obscureText
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 20,
                  color: cs.onSurface.withValues(alpha: 0.55),
                ),
                onPressed: onTogglePassword,
              )
            else if (hasError)
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: cs.error,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.close_rounded,
                    size: 18, color: Colors.white),
              ),
          ],
        ),
        // Single straight underline that always spans the full field width.
        Container(height: 1, color: lineColor),
      ],
    );
  }
}

// ── Diagonal divider between the hero photo and the form panel ───────────────

/// Cuts the hero panel's bottom edge as a single straight diagonal that
/// inclines from a low point on the left to a higher point on the right.
///
/// Coordinates are fractions of [size.width] / [size.height] so the slope
/// stays visually identical across all screen widths.
class _HeroCurveClipper extends CustomClipper<Path> {
  // Vertical position of each corner of the diagonal (as a ratio of height).
  static const double _leftLowRatio = 1.0;    // left edge cuts at the bottom
  static const double _rightHighRatio = 0.80; // right edge cuts higher up

  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(w, 0)
      ..lineTo(w, h * _rightHighRatio)
      ..lineTo(0, h * _leftLowRatio)
      ..close();

    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

