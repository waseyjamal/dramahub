import 'package:flutter/material.dart';

/// Pulsing play button with continuous animation
class PulsingPlayButton extends StatefulWidget {
  final VoidCallback onTap;

  const PulsingPlayButton({super.key, required this.onTap});

  @override
  State<PulsingPlayButton> createState() => _PulsingPlayButtonState();
}

class _PulsingPlayButtonState extends State<PulsingPlayButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.08,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      // ✅ 3.5 — renamed getter to _buildChild to eliminate name collision
      builder: (context, child) {
        return Transform.scale(scale: _scaleAnimation.value, child: child);
      },
      child: GestureDetector(onTap: widget.onTap, child: _buildChild),
    );
  }

  // ✅ 3.5 — Renamed from `child` to `_buildChild`
  Widget get _buildChild {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: const Color(0xFFE50914),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE50914).withValues(alpha: 0.4),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: const Icon(Icons.play_arrow, color: Colors.white, size: 40),
    );
  }
}

/// Pulsing badge animation
class PulsingBadge extends StatefulWidget {
  final Widget child;

  const PulsingBadge({super.key, required this.child});

  @override
  State<PulsingBadge> createState() => _PulsingBadgeState();
}

class _PulsingBadgeState extends State<PulsingBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);

    _opacityAnimation = Tween<double>(
      begin: 0.6,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ✅ 5.17 — FadeTransition replaces Opacity widget
    // Opacity triggers full save-layer compositing every frame
    // FadeTransition uses the animation directly — no save-layer needed
    return FadeTransition(opacity: _opacityAnimation, child: widget.child);
  }
}

/// Glowing VIP badge animation
class GlowingVIPBadge extends StatefulWidget {
  final Widget child;

  const GlowingVIPBadge({super.key, required this.child});

  @override
  State<GlowingVIPBadge> createState() => _GlowingVIPBadgeState();
}

class _GlowingVIPBadgeState extends State<GlowingVIPBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(
      begin: 0.3,
      end: 0.5,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glowAnimation,
      // ✅ 5.16 — child built ONCE here, not recreated every frame
      child: widget.child,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: const Color(
                  0xFFF5C518,
                ).withValues(alpha: _glowAnimation.value),
                blurRadius: 12,
                spreadRadius: 2,
              ),
            ],
          ),
          child: child,
        );
      },
    );
  }
}
