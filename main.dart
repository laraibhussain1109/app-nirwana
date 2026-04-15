// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/api_service.dart';
import 'screens/login_screen.dart';
import 'screens/landing_screen.dart';
import 'screens/dashboard_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Transparent status bar on all platforms
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor:           Colors.transparent,
    statusBarIconBrightness:  Brightness.light,
    statusBarBrightness:      Brightness.dark,
  ));
  runApp(const NirwanaApp());
}

class NirwanaApp extends StatelessWidget {
  const NirwanaApp({super.key});

  // ── Accent colour (single source of truth) ──────────────────────────────────
  static const _cyan     = Color(0xFF00D9FF);
  static const _cyanDark = Color(0xFF0099CC); // deeper for light-bg readability

  // ── Shared text theme ────────────────────────────────────────────────────────
  static TextTheme _textTheme(Color body) => TextTheme(
    displayLarge:  TextStyle(color: body, fontWeight: FontWeight.w900),
    displayMedium: TextStyle(color: body, fontWeight: FontWeight.w800),
    headlineLarge: TextStyle(color: body, fontWeight: FontWeight.w800),
    headlineMedium:TextStyle(color: body, fontWeight: FontWeight.w700),
    titleLarge:    TextStyle(color: body, fontWeight: FontWeight.w700),
    titleMedium:   TextStyle(color: body, fontWeight: FontWeight.w600),
    bodyLarge:     TextStyle(color: body),
    bodyMedium:    TextStyle(color: body),
  );

  // ── Dark theme ───────────────────────────────────────────────────────────────
  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: 'Inter',
    scaffoldBackgroundColor: const Color(0xFF0A1628),
    colorScheme: const ColorScheme.dark(
      primary:          _cyan,
      secondary:        Color(0xFF4FC3F7),
      surface:          Color(0xFF0D1E2E),
      error:            Color(0xFFFF4444),
      onPrimary:        Color(0xFF0A1628),
      onSurface:        Color(0xFFEFF6FF),
    ),
    textTheme: _textTheme(const Color(0xFFEFF6FF)),
    cardTheme: CardThemeData(
      color: const Color(0xFF0D1E2E),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF0A1628),
      elevation: 0,
      scrolledUnderElevation: 0,
      iconTheme: IconThemeData(color: Color(0xFFEFF6FF)),
      titleTextStyle: TextStyle(
          color: Color(0xFFEFF6FF), fontSize: 18, fontWeight: FontWeight.w700),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) =>
      s.contains(WidgetState.selected) ? const Color(0xFF0A1628) : Colors.grey.shade600),
      trackColor: WidgetStateProperty.resolveWith((s) =>
      s.contains(WidgetState.selected) ? _cyan : Colors.grey.shade800),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: _cyan,
        foregroundColor: const Color(0xFF0A1628),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFFEFF6FF),
        side: const BorderSide(color: Color(0xFF1E3A5F)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF112030),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      hintStyle: const TextStyle(color: Color(0xFF4A6A8A)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: const Color(0xFF0D1E2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 0,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Color(0xFF0D1828),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    ),
    dividerTheme: DividerThemeData(color: Colors.white.withOpacity(0.06), thickness: 1),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: const Color(0xFF0D1E2E),
      contentTextStyle: const TextStyle(color: Color(0xFFEFF6FF)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      behavior: SnackBarBehavior.floating,
    ),
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
      TargetPlatform.iOS:     CupertinoPageTransitionsBuilder(),
    }),
  );

  // ── Light theme ──────────────────────────────────────────────────────────────
  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    fontFamily: 'Inter',
    scaffoldBackgroundColor: const Color(0xFFF5F7FA),
    colorScheme: const ColorScheme.light(
      primary:          _cyanDark,
      secondary:        Color(0xFF2196F3),
      surface:          Colors.white,
      error:            Color(0xFFD32F2F),
      onPrimary:        Colors.white,
      onSurface:        Color(0xFF1A2332),
    ),
    textTheme: _textTheme(const Color(0xFF1A2332)),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      shadowColor: Colors.black.withOpacity(0.06),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFFF5F7FA),
      elevation: 0,
      scrolledUnderElevation: 0,
      iconTheme: IconThemeData(color: Color(0xFF1A2332)),
      titleTextStyle: TextStyle(
          color: Color(0xFF1A2332), fontSize: 18, fontWeight: FontWeight.w700),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) =>
      s.contains(WidgetState.selected) ? Colors.white : Colors.grey.shade400),
      trackColor: WidgetStateProperty.resolveWith((s) =>
      s.contains(WidgetState.selected) ? _cyanDark : Colors.grey.shade300),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: _cyanDark,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF1A2332),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFF1F5F9),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 4,
      shadowColor: Colors.black.withOpacity(0.08),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    ),
    dividerTheme: DividerThemeData(color: Colors.black.withOpacity(0.06), thickness: 1),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: Colors.white,
      contentTextStyle: const TextStyle(color: Color(0xFF1A2332)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      behavior: SnackBarBehavior.floating,
    ),
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
      TargetPlatform.iOS:     CupertinoPageTransitionsBuilder(),
    }),
  );

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ApiService(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'NirwanaGrid',
        themeMode:  ThemeMode.system,
        theme:      lightTheme,
        darkTheme:  darkTheme,
        home: const _SplashGate(),
        routes: {DashboardScreen.routeName: (ctx) => const DashboardScreen()},
      ),
    );
  }

}

/// Checks SharedPreferences on cold start.
/// If a session cookie exists → go straight to LandingScreen.
/// Otherwise → show LoginScreen.
class _SplashGate extends StatefulWidget {
  const _SplashGate();
  @override
  State<_SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<_SplashGate> {
  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final prefs  = await SharedPreferences.getInstance();
    // Check for persisted Bearer token — present means user is still logged in.
    final token = prefs.getString('bearer_token');
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (_, __, ___) =>
        (token != null && token.isNotEmpty)
            ? const LandingScreen()
            : const LoginScreen(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Brief branded splash while we read prefs
    final accent = const Color(0xFF00D9FF);
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A1628) : const Color(0xFFF5F7FA),
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 88, height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withOpacity(0.12),
              border: Border.all(color: accent.withOpacity(0.3), width: 1.5),
              boxShadow: [BoxShadow(
                  color: accent.withOpacity(0.25), blurRadius: 32, spreadRadius: 4)],
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Image.asset('assets/icons/ng_logo.png',
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) =>
                      Icon(Icons.electric_bolt_rounded, color: accent, size: 36)),
            ),
          ),
          const SizedBox(height: 20),
          Text('NirwanaGrid',
              style: TextStyle(color: accent, fontSize: 18,
                  fontWeight: FontWeight.w800, letterSpacing: 2)),
          const SizedBox(height: 28),
          SizedBox(width: 24, height: 24,
              child: CircularProgressIndicator(
                  color: accent, strokeWidth: 2.5)),
        ]),
      ),
    );
  }
}
