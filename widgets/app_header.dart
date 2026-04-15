// lib/widgets/app_header.dart
import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import 'nirwana_logo.dart';

class AppHeader extends StatelessWidget {
  const AppHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return Row(children: [
      NirwanaLogo(size: 38, accentColor: t.accent, glowOpacity: 0.15),
      const SizedBox(width: 10),
      // My Home pill
      Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
              color: t.chipFill,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: t.cardBorder)),
          child: Row(children: [
            Icon(Icons.home_outlined, color: t.iconSec, size: 14),
            const SizedBox(width: 5),
            Text('My Home', style: TextStyle(
                color: t.textPrim, fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(width: 3),
            Icon(Icons.keyboard_arrow_down_rounded, color: t.textSec, size: 14),
          ])),
      const Spacer(),
      // Add button
      _iconBtn(Icons.add_rounded, t),
      const SizedBox(width: 6),
      // Notification bell with dot
      Stack(children: [
        _iconBtn(Icons.notifications_outlined, t),
        Positioned(right: 7, top: 7,
            child: Container(
              width: 8, height: 8,
              decoration: BoxDecoration(
                  color: t.warning, shape: BoxShape.circle,
                  border: Border.all(color: t.bg, width: 1.5)),
            )),
      ]),
    ]);
  }

  Widget _iconBtn(IconData icon, AppTheme t) => Container(
      width: 36, height: 36,
      decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: t.chipFill,
          border: Border.all(color: t.cardBorder)),
      child: Icon(icon, color: t.textPrim, size: 17));
}
