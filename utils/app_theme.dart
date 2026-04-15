// lib/utils/app_theme.dart
//
// Usage in any widget:
//   final t = AppTheme.of(context);
//   t.bg, t.card, t.textPrim, t.textSec, t.accent, t.border, ...
//
// No more hardcoded dark-only Color(0xFF0A1628) etc. scattered everywhere.

import 'package:flutter/material.dart';

class AppTheme {
  final bool dark;
  final Color accent;      // primary color
  final Color bg;          // scaffold background
  final Color card;        // card/container fill
  final Color cardBorder;  // card border
  final Color textPrim;    // primary text
  final Color textSec;     // secondary text
  final Color textHint;    // hint / disabled text
  final Color divider;     // dividers
  final Color inputFill;   // text field background
  final Color chipFill;    // unselected chip background
  final Color iconSec;     // secondary icon tint
  final Color success;
  final Color warning;
  final Color error;

  const AppTheme._({
    required this.dark,
    required this.accent,
    required this.bg,
    required this.card,
    required this.cardBorder,
    required this.textPrim,
    required this.textSec,
    required this.textHint,
    required this.divider,
    required this.inputFill,
    required this.chipFill,
    required this.iconSec,
    required this.success,
    required this.warning,
    required this.error,
  });

  factory AppTheme.of(BuildContext context) {
    final th   = Theme.of(context);
    final isDark = th.brightness == Brightness.dark;
    final accent = th.colorScheme.primary;

    return isDark
        ? AppTheme._(
      dark:       true,
      accent:     accent,
      bg:         const Color(0xFF0A1628),
      card:       Colors.white.withOpacity(0.05),
      cardBorder: Colors.white.withOpacity(0.09),
      textPrim:   const Color(0xFFF0F0F0),
      textSec:    const Color(0xFFA0A0A0),
      textHint:   Colors.white38,
      divider:    Colors.white.withOpacity(0.08),
      inputFill:  const Color(0xFF122136),
      chipFill:   Colors.white.withOpacity(0.06),
      iconSec:    Colors.white54,
      success:    const Color(0xFF22C55E),
      warning:    const Color(0xFFF59E0B),
      error:      const Color(0xFFEF4444),
    )
        : AppTheme._(
      dark:       false,
      accent:     accent,
      bg:         const Color(0xFFF5F7FA),
      card:       Colors.white,
      cardBorder: Colors.black.withOpacity(0.07),
      textPrim:   const Color(0xFF1A2332),
      textSec:    const Color(0xFF6B7B8D),
      textHint:   Colors.black38,
      divider:    Colors.black.withOpacity(0.07),
      inputFill:  const Color(0xFFF0F2F5),
      chipFill:   Colors.black.withOpacity(0.05),
      iconSec:    Colors.black45,
      success:    const Color(0xFF16A34A),
      warning:    const Color(0xFFD97706),
      error:      const Color(0xFFDC2626),
    );
  }

  // Shorthand for card decoration
  BoxDecoration cardDecoration({double radius = 16, bool glow = false, Color? glowColor}) =>
      BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: cardBorder),
        boxShadow: glow && glowColor != null
            ? [BoxShadow(color: glowColor.withOpacity(0.15), blurRadius: 16)]
            : dark
            ? []
            : [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 2))],
      );
}
