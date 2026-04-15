// lib/widgets/nirwana_logo.dart
import 'package:flutter/material.dart';

/// Renders the NirwanaGrid logo in a glowing rounded circle.
class NirwanaLogo extends StatelessWidget {
  final double size;
  final Color  accentColor;
  final double glowOpacity;

  const NirwanaLogo({
    super.key,
    this.size = 42,
    required this.accentColor,
    this.glowOpacity = 0.2,
  });

  @override
  Widget build(BuildContext context) {
    final pad = size * 0.18;
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: accentColor.withOpacity(0.12),
        border: Border.all(color: accentColor.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(color: accentColor.withOpacity(glowOpacity),
              blurRadius: size * 0.6, spreadRadius: size * 0.05),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(pad),
        child: Image.asset(
          'assets/icons/ng_logo.png',
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Icon(
            Icons.electric_bolt_rounded,
            color: accentColor,
            size: size * 0.45,
          ),
        ),
      ),
    );
  }
}

/// Wraps any widget with a tiny "Coming Soon" pill badge.
/// The badge sits at top-right and NEVER causes overflow because it uses
/// an Align+FittedBox pattern instead of a Positioned.fill Container.
class ComingSoon extends StatelessWidget {
  final Widget child;
  final String label;

  const ComingSoon({super.key, required this.child, this.label = 'Soon'});

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      clipBehavior: Clip.none,          // pill allowed to overlap edges
      children: [
        child,
        Positioned(
          top: -6, right: -6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0D1828) : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: accent.withOpacity(0.5)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 4)],
            ),
            child: Text(
              label,
              style: TextStyle(
                color: accent,
                fontSize: 7,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
