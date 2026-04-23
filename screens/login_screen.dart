// lib/screens/login_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../widgets/nirwana_logo.dart';
import 'landing_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool   _obscure  = true;
  bool   _remember = false;
  bool   _loading  = false;
  String? _error;

  late AnimationController _fadeCtrl;
  late Animation<double>   _fadeAnim;

  static const _base = 'https://slhlab.pythonanywhere.com';
  static const _apiKey = 'Chutiya@123';

  bool  get _dark    => Theme.of(context).brightness == Brightness.dark;
  Color get _accent  => Theme.of(context).colorScheme.primary;
  Color get _bg      => _dark ? const Color(0xFF0A1628) : const Color(0xFFF5F7FA);
  Color get _card    => _dark ? const Color(0xFF0D1E2E) : Colors.white;
  Color get _tp      => _dark ? const Color(0xFFEFF6FF) : const Color(0xFF1A2332);
  Color get _ts      => _dark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
  Color get _input   => _dark ? const Color(0xFF112030) : const Color(0xFFF1F5F9);
  Color get _border  => _dark ? Colors.white.withOpacity(0.07) : Colors.black.withOpacity(0.07);

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() { _userCtrl.dispose(); _passCtrl.dispose(); _fadeCtrl.dispose(); super.dispose(); }

  Future<void> _signIn() async {
    FocusScope.of(context).unfocus();
    if (_userCtrl.text.trim().isEmpty || _passCtrl.text.isEmpty) {
      setState(() => _error = 'Please enter your username and password.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final res = await http.post(
        Uri.parse('$_base/api/login/'),
        headers: {
          'Content-Type': 'application/json',
          'X-API-KEY': _apiKey,
        },
        body: jsonEncode({'username': _userCtrl.text.trim(), 'password': _passCtrl.text}),
      ).timeout(const Duration(seconds: 12));

      if (!mounted) return;

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        if (data['detail']?.toString().toLowerCase().contains('success') == true) {
          // Extract Bearer token from login response:
          // { "detail": "login successful", "token": "...", "token_type": "Bearer", "user": {...} }
          final token = data['token']?.toString() ?? '';
          if (token.isNotEmpty && mounted) {
            await Provider.of<ApiService>(context, listen: false).saveToken(token);
          }
          if (!mounted) return;
          Navigator.of(context).pushReplacement(
              PageRouteBuilder(
                transitionDuration: const Duration(milliseconds: 400),
                pageBuilder: (_, __, ___) => const LandingScreen(),
                transitionsBuilder: (_, anim, __, child) =>
                    FadeTransition(opacity: anim, child: child),
              ));
          return;
        }
      }
      // Parse error
      String msg = 'Invalid username or password.';
      try {
        final b = jsonDecode(res.body);
        if (b is Map) msg = b['detail']?.toString() ?? b['error']?.toString() ?? msg;
      } catch (_) {}
      setState(() => _error = msg);
    } catch (_) {
      if (mounted) setState(() => _error = 'Connection failed. Check your internet.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: _bg,
      body: Stack(children: [
        // Ambient glow background
        Positioned(
          top: -100, left: -80,
          child: Container(
            width: 320, height: 320,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  _accent.withOpacity(_dark ? 0.12 : 0.06),
                  Colors.transparent,
                ])),
          ),
        ),
        Positioned(
          bottom: -60, right: -60,
          child: Container(
            width: 240, height: 240,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  _accent.withOpacity(_dark ? 0.08 : 0.04),
                  Colors.transparent,
                ])),
          ),
        ),

        SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: size.width > 600 ? size.width * 0.2 : 28,
                vertical: 32,
              ),
              child: FadeTransition(
                opacity: _fadeAnim,
                child: Column(children: [
                  // Logo + branding
                  NirwanaLogo(size: 88, accentColor: _accent, glowOpacity: _dark ? 0.25 : 0.12),
                  const SizedBox(height: 24),
                  Text('NirwanaGrid',
                      style: TextStyle(
                          color: _accent, fontSize: 13, fontWeight: FontWeight.w700,
                          letterSpacing: 2.5)),
                  const SizedBox(height: 8),
                  Text('Welcome Back',
                      style: TextStyle(color: _tp, fontSize: 28, fontWeight: FontWeight.w800,
                          letterSpacing: -0.5)),
                  const SizedBox(height: 6),
                  Text('Sign in to monitor your energy systems',
                      style: TextStyle(color: _ts, fontSize: 14),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 40),

                  // Card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: _card,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: _border),
                      boxShadow: _dark ? [] : [
                        BoxShadow(color: Colors.black.withOpacity(0.06),
                            blurRadius: 24, offset: const Offset(0, 8)),
                      ],
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      // Username
                      _label('Username'),
                      const SizedBox(height: 8),
                      _field(ctrl: _userCtrl, hint: 'Enter your username',
                          icon: Icons.person_outline_rounded, action: TextInputAction.next),
                      const SizedBox(height: 18),

                      // Password
                      _label('Password'),
                      const SizedBox(height: 8),
                      _field(
                        ctrl: _passCtrl, hint: 'Enter your password',
                        icon: Icons.lock_outline_rounded,
                        obscure: _obscure,
                        action: TextInputAction.done,
                        onSubmit: (_) => _signIn(),
                        suffix: IconButton(
                          onPressed: () => setState(() => _obscure = !_obscure),
                          icon: Icon(
                              _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              color: _ts, size: 20),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Remember / Forgot
                      Row(children: [
                        SizedBox(width: 20, height: 20,
                            child: Checkbox(
                              value: _remember,
                              onChanged: (v) => setState(() => _remember = v ?? false),
                              activeColor: _accent,
                              side: BorderSide(color: _ts.withOpacity(0.4)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                            )),
                        const SizedBox(width: 8),
                        Text('Remember me', style: TextStyle(color: _ts, fontSize: 13)),
                        const Spacer(),
                        GestureDetector(
                            onTap: () {},
                            child: Text('Forgot Password?',
                                style: TextStyle(color: _accent, fontSize: 13, fontWeight: FontWeight.w600))),
                      ]),

                      // Error
                      AnimatedSize(
                        duration: const Duration(milliseconds: 250),
                        child: _error != null
                            ? Padding(
                            padding: const EdgeInsets.only(top: 14),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.red.withOpacity(0.25))),
                              child: Row(children: [
                                const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 18),
                                const SizedBox(width: 10),
                                Expanded(child: Text(_error!,
                                    style: const TextStyle(color: Colors.redAccent, fontSize: 13))),
                              ]),
                            ))
                            : const SizedBox.shrink(),
                      ),

                      const SizedBox(height: 24),

                      // Sign In button
                      SizedBox(
                        width: double.infinity, height: 52,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _signIn,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _accent,
                            foregroundColor: _dark ? const Color(0xFF0A1628) : Colors.white,
                            disabledBackgroundColor: _accent.withOpacity(0.45),
                            elevation: 0,
                            shadowColor: _accent.withOpacity(0.3),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: _loading
                              ? SizedBox(width: 22, height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2.5,
                                  color: _dark ? const Color(0xFF0A1628) : Colors.white))
                              : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Text('Sign In',
                                style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w700,
                                  color: _dark ? const Color(0xFF0A1628) : Colors.white,
                                )),
                            const SizedBox(width: 8),
                            Icon(Icons.arrow_forward_rounded, size: 18,
                                color: _dark ? const Color(0xFF0A1628) : Colors.white),
                          ]),
                        ),
                      ),
                    ]),
                  ),

                  const SizedBox(height: 28),

                  // Footer
                  Text('Account access is managed by your administrator.',
                      style: TextStyle(color: _ts, fontSize: 12), textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Text('© 2026 NirwanaGrid · All rights reserved',
                      style: TextStyle(color: _ts.withOpacity(0.5), fontSize: 11),
                      textAlign: TextAlign.center),
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _label(String text) => Text(text,
      style: TextStyle(color: _ts, fontSize: 13, fontWeight: FontWeight.w500));

  Widget _field({
    required TextEditingController ctrl,
    required String hint,
    required IconData icon,
    bool obscure = false,
    TextInputAction action = TextInputAction.next,
    ValueChanged<String>? onSubmit,
    Widget? suffix,
  }) => Container(
    decoration: BoxDecoration(
        color: _input,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border)),
    child: TextField(
      controller: ctrl,
      obscureText: obscure,
      textInputAction: action,
      onSubmitted: onSubmit,
      style: TextStyle(color: _tp, fontSize: 15),
      decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: _ts.withOpacity(0.5)),
          prefixIcon: Icon(icon, color: _ts, size: 20),
          suffixIcon: suffix,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16)),
    ),
  );
}
