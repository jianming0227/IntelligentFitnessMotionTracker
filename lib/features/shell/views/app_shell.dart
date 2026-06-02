import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// App-wide chrome: the screen `child` plus the floating bottom navigation
/// bar with five slots — Home, Train, [center launcher], Plan, Profile.
///
/// The center slot is an enlarged accent-coloured circle that emphasises the
/// "Start workout" entry point. Tapping it sends the user to the Train
/// (courses list) screen so they can pick a session.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  static const _sideTabs = <_NavTab>[
    _NavTab(path: '/home', icon: Icons.home_rounded),
    _NavTab(path: '/train', icon: Icons.fitness_center_rounded),
    // center slot is rendered separately
    _NavTab(path: '/plan', icon: Icons.calendar_month_rounded),
    _NavTab(path: '/profile', icon: Icons.person_rounded),
  ];

  int _activeIndex(String location) {
    for (var i = 0; i < _sideTabs.length; i++) {
      if (location.startsWith(_sideTabs[i].path)) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final cs = Theme.of(context).colorScheme;
    final activeIdx = _activeIndex(location);

    return Scaffold(
      body: child,
      // The launcher sits *above* the nav bar so it overflows the pill.
      extendBody: true,
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              // Pill nav bar
              Container(
                height: 64,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    _NavButton(
                      icon: _sideTabs[0].icon,
                      active: activeIdx == 0,
                      onTap: () => context.go(_sideTabs[0].path),
                    ),
                    _NavButton(
                      icon: _sideTabs[1].icon,
                      active: activeIdx == 1,
                      onTap: () => context.go(_sideTabs[1].path),
                    ),
                    const SizedBox(width: 72), // reserved for center launcher
                    _NavButton(
                      icon: _sideTabs[2].icon,
                      active: activeIdx == 2,
                      onTap: () => context.go(_sideTabs[2].path),
                    ),
                    _NavButton(
                      icon: _sideTabs[3].icon,
                      active: activeIdx == 3,
                      onTap: () => context.go(_sideTabs[3].path),
                    ),
                  ],
                ),
              ),

              // Centered launcher — pushed up so half overflows the pill.
              Positioned(
                top: -16,
                child: _LauncherButton(
                  onTap: () => context.go('/train'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavTab {
  const _NavTab({required this.path, required this.icon});
  final String path;
  final IconData icon;
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.icon,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fg = active ? cs.primary : cs.onSurface.withValues(alpha: 0.55);

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 24, color: fg),
                const SizedBox(height: 4),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: active ? 16 : 0,
                  height: 3,
                  decoration: BoxDecoration(
                    color: cs.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LauncherButton extends StatelessWidget {
  const _LauncherButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.primary,
      shape: const CircleBorder(),
      elevation: 6,
      shadowColor: cs.primary.withValues(alpha: 0.5),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 64,
          height: 64,
          child: Icon(
            Icons.play_arrow_rounded,
            color: cs.onPrimary,
            size: 32,
          ),
        ),
      ),
    );
  }
}
