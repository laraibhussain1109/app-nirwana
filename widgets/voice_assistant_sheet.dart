// lib/widgets/voice_assistant_sheet.dart
//
// Full-screen voice assistant bottom sheet.
// Shows animated listening waves, transcript, and confirms relay commands.

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/voice_command_service.dart';
import '../utils/app_theme.dart';

/// Opens the voice assistant bottom sheet.
void showVoiceAssistant(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _VoiceSheet(),
  );
}

class _VoiceSheet extends StatefulWidget {
  const _VoiceSheet();
  @override
  State<_VoiceSheet> createState() => _VoiceSheetState();
}

class _VoiceSheetState extends State<_VoiceSheet>
    with SingleTickerProviderStateMixin {
  final _svc = VoiceCommandService();

  _State _state = _State.idle;
  String _transcript = '';
  String _statusMsg  = 'Tap the mic to start';
  VoiceCommand? _pendingCommand;
  bool _executing    = false;

  late AnimationController _waveCtrl;

  @override
  void initState() {
    super.initState();
    _waveCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 1200))
      ..repeat();
    _initSpeech();
  }

  @override
  void dispose() {
    _waveCtrl.dispose();
    _svc.cancelListening();
    super.dispose();
  }

  Future<void> _initSpeech() async {
    final ok = await _svc.init();
    if (mounted) {
      setState(() => _statusMsg = ok
          ? 'Tap the mic to start'
          : 'Microphone not available on this device');
    }
  }

  Future<void> _startListening() async {
    setState(() {
      _state      = _State.listening;
      _transcript = '';
      _statusMsg  = 'Listening…';
      _pendingCommand = null;
    });

    final api    = Provider.of<ApiService>(context, listen: false);
    final nodes  = api.getKnownNodes();

    await _svc.startListening(
      onResult: (text, isFinal) {
        if (!mounted) return;
        setState(() => _transcript = text);
        if (isFinal) {
          final cmd = VoiceCommandService.parse(text, nodes);
          if (cmd != null) {
            _resolveCommand(cmd, api);
          } else {
            setState(() {
              _state     = _State.notUnderstood;
              _statusMsg = 'Didn\'t catch that — try again';
            });
          }
        }
      },
      onDone: () {
        if (!mounted) return;
        if (_state == _State.listening) {
          setState(() {
            _state     = _State.notUnderstood;
            _statusMsg = 'Didn\'t catch that — try again';
          });
        }
      },
    );
  }

  void _resolveCommand(VoiceCommand cmd, ApiService api) {
    // If command has a direct node ID → confirm immediately
    if (cmd.nodeId != null) {
      setState(() {
        _state          = _State.confirm;
        _pendingCommand = cmd;
        _statusMsg      = 'Confirmed';
      });
      _executeCommand(cmd, api);
      return;
    }

    // Matched by device type → find all nodes matching that type
    final nodes     = api.getKnownNodes();
    final matching  = nodes.where((n) =>
    api.getDisplayName(n).toLowerCase() ==
        (cmd.deviceName ?? '').toLowerCase()).toList();

    if (matching.isEmpty) {
      setState(() {
        _state     = _State.notUnderstood;
        _statusMsg = 'No "${cmd.deviceName}" found';
      });
      return;
    }

    if (matching.length == 1) {
      final resolved = VoiceCommand(
        nodeId:      matching.first,
        action:      cmd.action,
        matchedText: cmd.matchedText,
        deviceName:  cmd.deviceName,
      );
      setState(() {
        _state          = _State.confirm;
        _pendingCommand = resolved;
        _statusMsg      = 'Confirmed';
      });
      _executeCommand(resolved, api);
      return;
    }

    // Multiple matching nodes → ask user to pick
    setState(() {
      _state          = _State.ambiguous;
      _statusMsg      = 'Which ${cmd.deviceName}?';
      _pendingCommand = cmd;
      _transcript     = matching.join(', ');
    });
  }

  Future<void> _executeCommand(VoiceCommand cmd, ApiService api) async {
    if (cmd.nodeId == null) return;
    setState(() { _executing = true; _state = _State.executing; });
    final relay = cmd.actionLabel;
    final ok    = await api.controlNode(cmd.nodeId!, relay);
    if (!mounted) return;
    setState(() {
      _executing = false;
      _state     = ok ? _State.success : _State.error;
      _statusMsg = ok
          ? '${api.getDisplayName(cmd.nodeId!)} turned ${relay.toLowerCase()}'
          : 'Failed to ${relay.toLowerCase()} — check connection';
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return Container(
      height: MediaQuery.of(context).size.height * 0.55,
      decoration: BoxDecoration(
          color: t.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32))),
      child: Column(children: [
        // Handle
        Container(
            width: 40, height: 4, margin: const EdgeInsets.only(top: 12, bottom: 20),
            decoration: BoxDecoration(color: t.divider, borderRadius: BorderRadius.circular(2))),

        // Header
        Text('Voice Assistant',
            style: TextStyle(color: t.textPrim, fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text('Say: "Turn on NODE_1" or "Turn off charger"',
            style: TextStyle(color: t.textSec, fontSize: 12),
            textAlign: TextAlign.center),

        const Spacer(),

        // Transcript bubble
        if (_transcript.isNotEmpty)
          AnimatedOpacity(
              opacity: 1, duration: const Duration(milliseconds: 300),
              child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 32),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                      color: t.accent.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: t.accent.withOpacity(0.2))),
                  child: Text(_transcript,
                      style: TextStyle(color: t.textPrim, fontSize: 15, fontWeight: FontWeight.w500),
                      textAlign: TextAlign.center))),

        const SizedBox(height: 16),

        // Status icon + message
        _StatusWidget(state: _state, accent: t.accent, waveCtrl: _waveCtrl),
        const SizedBox(height: 10),
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(_statusMsg,
                style: TextStyle(color: t.textSec, fontSize: 13),
                textAlign: TextAlign.center)),

        const Spacer(),

        // Mic button
        GestureDetector(
            onTap: _state == _State.listening ? _svc.stopListening : _startListening,
            child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 72, height: 72,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                        colors: _state == _State.listening
                            ? [Colors.red.shade400, Colors.red.shade600]
                            : [t.accent, t.accent.withOpacity(0.7)],
                        begin: Alignment.topLeft, end: Alignment.bottomRight),
                    boxShadow: [BoxShadow(
                        color: (_state == _State.listening ? Colors.red : t.accent).withOpacity(0.4),
                        blurRadius: 20, spreadRadius: 2)]),
                child: Icon(
                    _state == _State.listening ? Icons.stop_rounded : Icons.mic_rounded,
                    color: Colors.white, size: 30))),

        const SizedBox(height: 10),
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: TextStyle(color: t.textSec))),
        const SizedBox(height: 12),
      ]),
    );
  }
}

// ── State machine ─────────────────────────────────────────────────────────────

enum _State { idle, listening, confirm, executing, ambiguous, success, error, notUnderstood }

// ── Animated status widget ────────────────────────────────────────────────────

class _StatusWidget extends StatelessWidget {
  final _State state;
  final Color  accent;
  final AnimationController waveCtrl;

  const _StatusWidget({required this.state, required this.accent, required this.waveCtrl});

  @override
  Widget build(BuildContext context) {
    switch (state) {
      case _State.listening:
        return _WaveRings(ctrl: waveCtrl, color: accent);
      case _State.executing:
        return SizedBox(width: 40, height: 40,
            child: CircularProgressIndicator(color: accent, strokeWidth: 3));
      case _State.success:
        return Icon(Icons.check_circle_rounded, color: const Color(0xFF22C55E), size: 44);
      case _State.error:
        return Icon(Icons.error_outline_rounded, color: Colors.red, size: 44);
      case _State.notUnderstood:
        return Icon(Icons.hearing_disabled_outlined,
            color: const Color(0xFFF59E0B), size: 44);
      default:
        return Icon(Icons.assistant_rounded, color: accent, size: 44);
    }
  }
}

// ── Animated wave rings (listening state) ─────────────────────────────────────

class _WaveRings extends StatelessWidget {
  final AnimationController ctrl;
  final Color color;
  const _WaveRings({required this.ctrl, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: 60, height: 60,
        child: AnimatedBuilder(
            animation: ctrl,
            builder: (_, __) => CustomPaint(
                painter: _WavePainter(progress: ctrl.value, color: color))));
  }
}

class _WavePainter extends CustomPainter {
  final double progress;
  final Color  color;
  const _WavePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    for (int i = 0; i < 3; i++) {
      final phase  = (progress + i / 3) % 1.0;
      final radius = (phase * size.width / 2).clamp(4.0, size.width / 2);
      final opacity= (1.0 - phase).clamp(0.0, 0.6);
      canvas.drawCircle(centre, radius,
          Paint()..color = color.withOpacity(opacity)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
    }
    canvas.drawCircle(centre, 8,
        Paint()..color = color..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(covariant _WavePainter old) => old.progress != progress;
}
