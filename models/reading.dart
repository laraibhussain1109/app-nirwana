// lib/models/reading.dart
//
// Maps the JSON returned by:
//   GET /api/pzem/latest/<nodeId>/
//   GET /api/pzemreadings/?nodeid=<nodeId>
//
// Key field notes (from web dashboard reference):
//   • Use `created`      for timestamps — it is proper ISO-8601 (has T separator).
//   • `timestamp_ist`    has a space separator ("2026-03-29 13:41:54") which Dart
//     DateTime.tryParse rejects, so we only use it as a last-resort fallback.
//   • `health`           is returned directly by the API — no client-side calculation.
//   • `relay`            is "ON" or "OFF" string.

class Reading {
  final int?     id;
  final String   nodeid;
  final double   voltage;
  final double   current;
  final double   power;
  final double   energy;
  final double   pf;
  final double   frequency;
  final String   relay;
  final DateTime created;      // primary timestamp — proper ISO 8601
  final int      health;       // 0-100, returned by API

  const Reading({
    this.id,
    required this.nodeid,
    required this.voltage,
    required this.current,
    required this.power,
    required this.energy,
    required this.pf,
    required this.frequency,
    required this.relay,
    required this.created,
    required this.health,
  });

  /// Legacy getter so existing code that references `timestampIST` still compiles.
  DateTime get timestampIST => created;

  Reading copyWith({
    int?     id,
    String?  nodeid,
    double?  voltage,
    double?  current,
    double?  power,
    double?  energy,
    double?  pf,
    double?  frequency,
    String?  relay,
    DateTime? created,
    int?     health,
  }) => Reading(
    id:        id        ?? this.id,
    nodeid:    nodeid    ?? this.nodeid,
    voltage:   voltage   ?? this.voltage,
    current:   current   ?? this.current,
    power:     power     ?? this.power,
    energy:    energy    ?? this.energy,
    pf:        pf        ?? this.pf,
    frequency: frequency ?? this.frequency,
    relay:     relay     ?? this.relay,
    created:   created   ?? this.created,
    health:    health    ?? this.health,
  );

  factory Reading.fromJson(Map<String, dynamic> json) {
    return Reading(
      id:        json['id'] as int?,
      nodeid:    json['nodeid']?.toString() ?? json['node_id']?.toString() ?? 'NODE_?',
      voltage:   _toDouble(json['voltage']),
      current:   _toDouble(json['current']),
      power:     _toDouble(json['power']),
      energy:    _toDouble(json['energy']),
      pf:        _toDouble(json['pf']),
      frequency: _toDouble(json['frequency']),
      relay:     json['relay']?.toString() ?? 'OFF',
      // Prefer `created` (ISO 8601 with T) over `timestamp_ist` (space-separated)
      created:   _parseTs(json['created']?.toString())
          ?? _parseTs(_normalise(json['timestamp_ist']?.toString()))
          ?? DateTime.now(),
      // API returns health directly; fall back to 0 if absent (older firmware)
      health:    (json['health'] as num?)?.toInt() ?? 0,
    );
  }

  static double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  static DateTime? _parseTs(String? s) {
    if (s == null || s.isEmpty) return null;
    return DateTime.tryParse(s);
  }

  /// Convert "2026-03-29 13:41:54" → "2026-03-29T13:41:54" so Dart can parse it.
  static String? _normalise(String? s) {
    if (s == null || s.isEmpty) return null;
    return s.contains('T') ? s : s.replaceFirst(' ', 'T');
  }
}
