// lib/services/voice_command_service.dart
//
// In-app voice recognition for relay control.
// Uses the `speech_to_text` Flutter package.
//
// Add to pubspec.yaml:
//   speech_to_text: ^7.0.0
//
// Add to AndroidManifest.xml (inside <manifest>):
//   <uses-permission android:name="android.permission.RECORD_AUDIO"/>
//
// Understands commands like:
//   "turn on NODE_1"     "turn off NODE_3"
//   "switch on NODE_2"   "switch off NODE_1"
//   "LED bulb on"        "air conditioner off"
//   "turn on the iron"   "switch off kettle"

import 'package:speech_to_text/speech_to_text.dart';

class VoiceCommandService {
  final SpeechToText _stt = SpeechToText();
  bool _initialized = false;

  /// Returns true if speech recognition is available on this device.
  Future<bool> init() async {
    if (_initialized) return true;
    _initialized = await _stt.initialize(
      onError: (e) {},
      onStatus: (_) {},
    );
    return _initialized;
  }

  bool get isAvailable => _initialized;
  bool get isListening => _stt.isListening;

  /// Starts listening. Calls [onResult] with each interim/final transcript.
  /// Calls [onDone] with the final transcript when the user stops speaking.
  Future<void> startListening({
    required void Function(String transcript, bool isFinal) onResult,
    required void Function() onDone,
  }) async {
    if (!_initialized) await init();
    if (!_initialized) return;

    await _stt.listen(
      onResult: (result) {
        onResult(result.recognizedWords, result.finalResult);
        if (result.finalResult) onDone();
      },
      listenFor: const Duration(seconds: 10),
      pauseFor: const Duration(seconds: 2),
      localeId: 'en_IN',          // Indian English accent works best
      listenOptions: SpeechListenOptions(
        partialResults: true,
        cancelOnError: false,
      ),
    );
  }

  Future<void> stopListening() => _stt.stop();
  Future<void> cancelListening() => _stt.cancel();

  // ── Command parsing ─────────────────────────────────────────────────────────

  /// Parses a voice transcript into a [VoiceCommand].
  /// Returns null if the transcript is not a recognised relay command.
  static VoiceCommand? parse(String transcript, List<String> knownNodeIds) {
    final t = transcript.toLowerCase().trim();

    // Detect action (on / off)
    RelayAction? action;
    if (RegExp(r'\b(turn on|switch on|enable|activate|on)\b').hasMatch(t)) {
      action = RelayAction.on;
    } else if (RegExp(r'\b(turn off|switch off|disable|deactivate|off)\b').hasMatch(t)) {
      action = RelayAction.off;
    }
    if (action == null) return null;

    // Try to match a known node ID directly (e.g. "node 1", "node_1", "node one")
    for (final nodeId in knownNodeIds) {
      final normalised = nodeId.toLowerCase()
          .replaceAll('_', ' ')
          .replaceAll('node', 'node ').trim();
      if (t.contains(normalised) || t.contains(nodeId.toLowerCase())) {
        return VoiceCommand(nodeId: nodeId, action: action, matchedText: nodeId);
      }
    }

    // Try to match by device type name → pick the first matching node by power range
    final deviceMatch = _matchByDeviceName(t);
    if (deviceMatch != null) {
      return VoiceCommand(nodeId: null, action: action,
          matchedText: deviceMatch, deviceName: deviceMatch);
    }

    return null;
  }

  static String? _matchByDeviceName(String t) {
    if (t.contains('bulb') || t.contains('led') || t.contains('light')) return 'LED Bulb';
    if (t.contains('charger') || t.contains('mobile') || t.contains('phone')) return 'Charger';
    if (t.contains('iron')) return 'Electric Iron';
    if (t.contains('kettle') || t.contains('water heater') || t.contains('boil')) return 'Electric Kettle';
    if (t.contains('heater') || t.contains('room heater')) return 'Electric Heater';
    if (t.contains('ac') || t.contains('air condition') || t.contains('conditioner') ||
        t.contains('cooler') || t.contains('air con')) return 'Air Conditioner';
    if (t.contains('fan')) return 'Fan';
    if (t.contains('tv') || t.contains('television')) return 'TV';
    if (t.contains('fridge') || t.contains('refrigerator')) return 'Fridge';
    return null;
  }
}

enum RelayAction { on, off }

class VoiceCommand {
  /// The matched node ID (if directly named), or null if matched by device type.
  final String? nodeId;
  final RelayAction action;
  final String matchedText;
  final String? deviceName; // set when matched by device type name

  const VoiceCommand({
    required this.nodeId,
    required this.action,
    required this.matchedText,
    this.deviceName,
  });

  String get actionLabel => action == RelayAction.on ? 'ON' : 'OFF';
}
