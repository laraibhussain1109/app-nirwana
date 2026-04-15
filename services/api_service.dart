// lib/services/api_service.dart
//
// API usage mirrors the working web dashboard (document index 6).
//
// Endpoints:
//   GET  /api/pzem/latest/<nodeId>/           → latest reading + health
//   GET  /api/pzem/control/<nodeId>/           → current relay state
//   POST /api/pzem/control/<nodeId>/           → {relay: "ON"/"OFF"}
//   GET  /api/pzemreadings/?nodeid=<nodeId>    → history for one node
//   GET  /api/pzem/schedules/?nodeid=<nodeId>  → schedules for one node
//   POST /api/pzem/schedules/                  → {nodeid, action, execute_at}
//   DELETE /api/pzem/schedules/<id>/           → cancel schedule

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import '../models/reading.dart';

class ApiService with ChangeNotifier {
  // ── Config ──────────────────────────────────────────────────────────────────
  static const String _base   = 'https://slhlab.pythonanywhere.com';
  String get base => _base;

  // ── State ───────────────────────────────────────────────────────────────────
  final Map<String, Reading> latest          = {};
  // Per-node history cache: nodeId → sorted readings (oldest→newest)
  final Map<String, List<Reading>> nodeHistory = {};
  List<ServerSchedule> serverSchedules       = [];

  // Node registry
  final Set<String>         userAddedNodes = {};
  final Map<String, String> displayNames   = {};

  // ── Rate per unit (₹/kWh) ──────────────────────────────────────────────────
  double _ratePerUnit = 10.0;
  double get ratePerUnit => _ratePerUnit;

  // ── Bearer token (replaces session cookie + X-API-KEY) ────────────────────
  // Obtained from POST /api/login/ response: { "token": "...", "token_type": "Bearer" }
  String? _bearerToken;

  /// True when the user is authenticated (token is present in memory + prefs).
  bool get isLoggedIn => _bearerToken != null && _bearerToken!.isNotEmpty;

  // ── Race-condition guards ───────────────────────────────────────────────────
  final Set<String> _pendingSchedulePosts = {};
  final Set<String> _fetchingNodeHistory  = {};

  SharedPreferences? _prefs;
  Timer?             _pollTimer;

  ApiService() { _init(); }

  // ── Init ────────────────────────────────────────────────────────────────────
  Future<void> _init() async {
    _prefs        = await SharedPreferences.getInstance();
    _ratePerUnit  = _prefs!.getDouble('ratePerUnit') ?? 10.0;
    _bearerToken  = _prefs!.getString('bearer_token'); // persisted across restarts
    await _loadDisplayNames();
    if (isLoggedIn) {
      startPolling(const Duration(seconds: 5));
      unawaited(_bootstrap());
    }
  }

  void startPolling(Duration interval) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(interval, (_) async {
      await fetchLatestAll();
      await fetchServerSchedules();
    });
  }
  void stopPolling() { _pollTimer?.cancel(); _pollTimer = null; }

  // ── Token helpers ────────────────────────────────────────────────────────────

  /// Called by LoginScreen after a successful login response.
  /// Persists the token to SharedPreferences so the app remembers the user.
  Future<void> saveToken(String token) async {
    _bearerToken = token;
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setString('bearer_token', token);
    startPolling(const Duration(seconds: 5));
    unawaited(_bootstrap());
    notifyListeners();
  }

  /// Called on sign-out — clears token from memory and storage.
  Future<void> clearSession() async {
    _bearerToken = null;
    stopPolling();
    latest.clear();
    nodeHistory.clear();
    serverSchedules.clear();
    userAddedNodes.clear();
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.remove('bearer_token');
    notifyListeners();
  }

  // Keep old name for compatibility with SplashGate which checks session_cookie key
  Future<void> saveSession(String ignored) async {
    // No-op: session is now tracked by bearer token, not cookie.
    // LoginScreen calls saveToken() directly; this stub avoids compile errors.
  }

  /// Authorization header used by every authenticated request.
  String get _authValue => 'Bearer $_bearerToken';

  /// Headers for POST/DELETE requests that send a JSON body.
  Map<String, String> get _authHeaders => {
    'Content-Type': 'application/json',
    if (_bearerToken != null) 'Authorization': _authValue,
  };

  /// Headers for GET requests (no Content-Type needed).
  Map<String, String> get _sessionHeaders => {
    if (_bearerToken != null) 'Authorization': _authValue,
  };

  bool get _hasValidToken => _bearerToken != null && _bearerToken!.isNotEmpty;

  // ── Rate per unit ────────────────────────────────────────────────────────────
  Future<void> setRatePerUnit(double rate) async {
    _ratePerUnit = rate;
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setDouble('ratePerUnit', rate);
    notifyListeners();
  }

  // ── Node helpers ─────────────────────────────────────────────────────────────
  void addNodePlaceholder(String nodeId) {
    if (nodeId.isEmpty) return;
    userAddedNodes.add(nodeId);
    displayNames.putIfAbsent(nodeId, () => nodeId);
    notifyListeners();
  }

  /// Returns the display name for a node.
  ///
  /// Priority order:
  ///   1. User-set name (via setDisplayName) — always wins if present.
  ///   2. Auto-detected name from live power reading (wattage ranges below).
  ///   3. Raw node ID as fallback.
  ///
  /// Wattage auto-detection (matches only when relay is ON):
  ///   3–9 W    → LED Bulb
  ///   10–120 W → Charger
  ///   300–750 W → Electric Iron
  ///   751–1200 W → Electric Kettle
  ///   1201–2000 W → Electric Heater
  ///   2001–4500 W → Air Conditioner
  String getDisplayName(String nodeId) {
    // 1. User-set or previously-cached name takes priority
    if (displayNames.containsKey(nodeId)) return displayNames[nodeId]!;

    // 2. Auto-detect from live power reading and CACHE the result so it
    //    persists when the relay is later turned off.
    final reading = latest[nodeId];
    if (reading != null && reading.relay.toUpperCase() == 'ON') {
      final w    = reading.power;
      String? detected;
      if (w >= 3    && w <= 9)    detected = 'LED Bulb';
      if (w >= 10   && w <= 120)  detected = 'Charger';
      if (w >= 450  && w <= 1200) detected = 'Electric Iron';
      if (w >= 1201 && w <= 1500) detected = 'Electric Kettle';
      if (w >= 1501 && w <= 2000) detected = 'Electric Heater';
      if (w >= 2001 && w <= 4500) detected = 'Air Conditioner';

      if (detected != null) {
        // Cache it so it survives relay-off and app restarts
        displayNames[nodeId] = detected;
        _persistDisplayNames(); // fire-and-forget
        return detected;
      }
    }

    // 3. Raw node ID
    return nodeId;
  }

  /// Returns the icon for a node based on its detected device type.
  /// Matches the same logic as getDisplayName auto-detection.
  static IconData getDeviceIcon(String displayName, double powerW, String relay) {
    // If relay is on and power matches a known range, use that icon
    if (relay.toUpperCase() == 'ON') {
      if (powerW >= 3    && powerW <= 9)    return Icons.lightbulb_outline_rounded;
      if (powerW >= 10   && powerW <= 120)  return Icons.battery_charging_full_rounded;
      if (powerW >= 450  && powerW <= 1200) return Icons.iron_outlined;
      if (powerW >= 1201 && powerW <= 1500) return Icons.local_cafe_outlined;
      if (powerW >= 1501 && powerW <= 2000) return Icons.whatshot_outlined;
      if (powerW >= 2001 && powerW <= 4500) return Icons.ac_unit_rounded;
    }
    // Fallback: guess from display name text
    final l = displayName.toLowerCase();
    if (l.contains('bulb') || l.contains('light') || l.contains('lamp')) return Icons.lightbulb_outline_rounded;
    if (l.contains('charge') || l.contains('charger'))                   return Icons.battery_charging_full_rounded;
    if (l.contains('iron'))                                               return Icons.iron_outlined;
    if (l.contains('kettle') || l.contains('coffee'))                    return Icons.local_cafe_outlined;
    if (l.contains('heater') || l.contains('heat'))                      return Icons.whatshot_outlined;
    if (l.contains('ac') || l.contains('air') || l.contains('cooler'))   return Icons.ac_unit_rounded;
    if (l.contains('fridge') || l.contains('refrig'))                    return Icons.kitchen_outlined;
    if (l.contains('tv') || l.contains('television'))                    return Icons.tv_outlined;
    if (l.contains('fan'))                                                return Icons.wind_power_outlined;
    if (l.contains('pump'))                                               return Icons.water_outlined;
    if (l.contains('washer') || l.contains('washing'))                   return Icons.local_laundry_service_outlined;
    return Icons.power_outlined;
  }

  void setDisplayName(String nodeId, String name) {
    if (nodeId.isEmpty) return;
    if (name.isEmpty) {
      displayNames.remove(nodeId);
    } else {
      displayNames[nodeId] = name;
    }
    _persistDisplayNames();
    notifyListeners();
  }

  void removeDisplayName(String nodeId) {
    displayNames.remove(nodeId);
    _persistDisplayNames();
    notifyListeners();
  }

  Future<void> _persistDisplayNames() async {
    _prefs ??= await SharedPreferences.getInstance();
    // Persist as JSON string: { "NODE_1": "LED Bulb", "NODE_3": "My Iron" }
    final json = Map<String, String>.from(displayNames);
    await _prefs!.setString('display_names', jsonEncode(json));
  }

  Future<void> _loadDisplayNames() async {
    _prefs ??= await SharedPreferences.getInstance();
    final raw = _prefs!.getString('display_names');
    if (raw == null || raw.isEmpty) return;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      m.forEach((k, v) => displayNames[k] = v.toString());
    } catch (_) {}
  }

  List<String> getKnownNodes() {
    // Build entirely from real API data + user-added nodes.
    // No hardcoded IDs — nodes appear as the API reports them.
    final s = <String>{};
    s.addAll(latest.keys);
    s.addAll(nodeHistory.keys);
    s.addAll(userAddedNodes);
    // If nothing has loaded yet, return empty so the UI shows a loading state
    // instead of fake NODE_1/2/3 placeholders.
    return s.toList()..sort();
  }

  // ── Energy / Bill / Carbon ───────────────────────────────────────────────────
  /// Live power draw across all nodes (sum of latest.power).
  double getTotalCurrentPowerW() =>
      latest.values.fold(0.0, (s, r) => s + r.power);

  /// All-time energy: sum of latest cumulative energy registers.
  double getAllTimeEnergyKwh() =>
      latest.values.fold(0.0, (s, r) => s + r.energy);

  /// Monthly energy: for each node, delta of energy register this calendar month.
  double getMonthlyEnergyKwh() {
    final monthStart = DateTime(DateTime.now().year, DateTime.now().month, 1);
    double total = 0;
    for (final id in getKnownNodes()) {
      final readings = (nodeHistory[id] ?? [])
          .where((r) => !r.created.isBefore(monthStart))
          .toList();
      if (readings.length >= 2) {
        // readings are sorted oldest→newest; delta = last - first
        final delta = readings.last.energy - readings.first.energy;
        total += delta.clamp(0.0, double.infinity);
      }
      // If < 2 readings this month → contribute 0 (don't use all-time value)
    }
    return total;
  }

  double getEstimatedBill() => getMonthlyEnergyKwh() * _ratePerUnit;

  /// AI-predicted end-of-month bill.
  /// = (monthly kWh so far ÷ days elapsed) × days in month × rate
  double getAiPredictedBill() {
    final now          = DateTime.now();
    final dayOfMonth   = now.day.clamp(1, 31).toDouble();
    final daysInMonth  = DateTime(now.year, now.month + 1, 0).day.toDouble();
    final monthly      = getMonthlyEnergyKwh();
    if (monthly == 0) return 0;
    return (monthly / dayOfMonth) * daysInMonth * _ratePerUnit;
  }

  double getAiPredictedKwh() {
    final now         = DateTime.now();
    final dayOfMonth  = now.day.clamp(1, 31).toDouble();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day.toDouble();
    final monthly     = getMonthlyEnergyKwh();
    if (monthly == 0) return 0;
    return (monthly / dayOfMonth) * daysInMonth;
  }

  /// CO₂ footprint: India grid factor 0.82 kg CO₂/kWh (CEA 2023).
  double getCarbonKg() => getMonthlyEnergyKwh() * 0.82;

  // ── Health score (from API — no client-side calculation) ────────────────────
  int computeHealthScore(Reading r) => r.health;

  // ── Online status ─────────────────────────────────────────────────────────
  /// A node is "online" only when:
  ///   1. relay == "ON", AND
  ///   2. last reading received within the past 15 minutes.
  /// If the reading is stale (>15 min old) the device is considered offline
  /// regardless of relay state.
  static const Duration _staleThreshold = Duration(minutes: 15);

  bool isNodeOnline(String nodeId) {
    final r = latest[nodeId];
    if (r == null) return false;
    if (r.relay.toUpperCase() != 'ON') return false;
    final age = DateTime.now().difference(r.created);
    return age <= _staleThreshold;
  }

  /// Returns a human-readable staleness string, e.g. "2 min ago", "3 h ago".
  String lastSeenLabel(String nodeId) {
    final r = latest[nodeId];
    if (r == null) return 'Never';
    final age = DateTime.now().difference(r.created).abs();
    if (age.inSeconds < 60)  return '\${age.inSeconds}s ago';
    if (age.inMinutes < 60)  return '\${age.inMinutes}m ago';
    if (age.inHours   < 24)  return '\${age.inHours}h ago';
    return '\${age.inDays}d ago';
  }

  // ── Latest fetch ─────────────────────────────────────────────────────────────
  /// GET /api/pzem/latest/<nodeId>/
  /// Mirrors: const LATEST = node => `${API_BASE}/api/pzem/latest/${node}/`;
  Future<Reading?> fetchLatest(String nodeId) async {
    if (!_hasValidToken) return null;
    try {
      final res = await http
          .get(Uri.parse('$_base/api/pzem/latest/$nodeId/'), headers: _sessionHeaders)
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final d = jsonDecode(res.body);
        if (d is Map) {
          final m = Map<String, dynamic>.from(d);
          if (m['found'] == false) return null;
          // Control endpoint is the authoritative source for relay AND health.
          // GET /api/pzem/control/<nodeId>/ returns:
          //   { relay, health, voltage, current, power, energy, pf, frequency, ... }
          final ctrl  = await _fetchControl(nodeId);
          final relay  = ctrl?['relay']?.toString()  ?? m['relay']?.toString()  ?? 'OFF';
          final health = (ctrl?['health'] as num?)?.toInt()
              ?? (m['health']    as num?)?.toInt()
              ?? 0;
          final r = Reading.fromJson({...m, 'relay': relay, 'health': health});
          latest[nodeId] = r;
          notifyListeners();
          return r;
        }
      }
    } catch (e) { if (kDebugMode) print('fetchLatest $nodeId: $e'); }
    return null;
  }

  Future<void> fetchLatestAll() async {
    if (!_hasValidToken) return;
    await Future.wait(getKnownNodes().map(fetchLatest));
  }

  /// GET /api/pzem/control/<nodeId>/
  Future<Map<String, dynamic>?> _fetchControl(String nodeId) async {
    if (!_hasValidToken) return null;
    try {
      final res = await http
          .get(Uri.parse('$_base/api/pzem/control/$nodeId/'),
          headers: _sessionHeaders)
          .timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final d = jsonDecode(res.body);
        if (d is Map) return Map<String, dynamic>.from(d);
      }
    } catch (_) {}
    return null;
  }

  // ── Node-specific history ────────────────────────────────────────────────────
  /// GET /api/pzemreadings/?nodeid=<nodeId>
  /// Mirrors: const url = `${READINGS()}?nodeid=${encodeURIComponent(selectedNode)}`;
  Future<List<Reading>> fetchNodeHistory(String nodeId) async {
    if (!_hasValidToken) return nodeHistory[nodeId] ?? [];
    // Race-condition guard: skip if already fetching this node
    if (_fetchingNodeHistory.contains(nodeId)) {
      return nodeHistory[nodeId] ?? [];
    }
    _fetchingNodeHistory.add(nodeId);

    try {
      final url = Uri.parse('$_base/api/pzemreadings/?nodeid=$nodeId');
      final res = await http.get(url, headers: _sessionHeaders).timeout(const Duration(seconds: 20));
      if (res.statusCode == 200) {
        final d = jsonDecode(res.body);
        if (d is List) {
          final readings = (d as List<dynamic>)
              .map((e) {
            try { return Reading.fromJson(Map<String, dynamic>.from(e as Map)); }
            catch (_) { return null; }
          })
              .whereType<Reading>()
              .toList()
          // Sort oldest → newest (same as web dashboard: .reverse())
            ..sort((a, b) => a.created.compareTo(b.created));
          nodeHistory[nodeId] = readings;
          notifyListeners();
          return readings;
        }
      }
    } catch (e) { if (kDebugMode) print('fetchNodeHistory($nodeId): $e'); }
    finally { _fetchingNodeHistory.remove(nodeId); }
    return nodeHistory[nodeId] ?? [];
  }

  /// Returns cached history for a node filtered by time window.
  List<Reading> getHistoryForNode(String nodeId, {Duration? window}) {
    final all = nodeHistory[nodeId] ?? [];
    if (window == null) return all;
    final cutoff = DateTime.now().subtract(window);
    return all.where((r) => r.created.isAfter(cutoff)).toList();
  }

  // ── Control (relay toggle) ───────────────────────────────────────────────────
  /// POST /api/pzem/control/<nodeId>/  body: {relay: "ON"/"OFF"}
  /// Mirrors: postRelay(node, relay) in web dashboard.
  Future<bool> controlNode(String nodeId, String desiredRelay) async {
    if (!_hasValidToken) return false;
    try {
      final res = await http.post(
        Uri.parse('$_base/api/pzem/control/$nodeId/'),
        headers: _authHeaders,
        body: jsonEncode({'relay': desiredRelay}),
      ).timeout(const Duration(seconds: 12));

      if (res.statusCode >= 200 && res.statusCode < 300) {
        // Refresh latest after toggle (mirrors web dashboard fetchControl after toggle)
        await fetchLatest(nodeId);
        return true;
      }
      if (kDebugMode) print('controlNode HTTP ${res.statusCode}: ${res.body}');
    } catch (e) { if (kDebugMode) print('controlNode: $e'); }
    return false;
  }

  /// Toggle relay: reads current state then POSTs opposite.
  /// Mirrors: toggleRelay() in web dashboard.
  Future<bool> toggleNode(String nodeId) async {
    final current = latest[nodeId]?.relay.toUpperCase() ?? 'OFF';
    return controlNode(nodeId, current == 'ON' ? 'OFF' : 'ON');
  }

  // ── Schedules ────────────────────────────────────────────────────────────────
  /// POST /api/pzem/schedules/
  /// Body: { "nodeid": "NODE_1", "action": "ON", "execute_at": "<ISO-8601>" }
  Future<ServerSchedule?> postSchedule({
    required String   nodeId,
    required String   action,       // "ON" or "OFF"
    required DateTime executeAt,
  }) async {
    if (!_hasValidToken) return null;
    // Dedup key — prevents double-tap race condition
    final key = '$nodeId-$action-${executeAt.toIso8601String()}';
    if (_pendingSchedulePosts.contains(key)) return null;
    _pendingSchedulePosts.add(key);

    try {
      final res = await http.post(
        Uri.parse('$_base/api/pzem/schedules/'),
        headers: _authHeaders,
        body: jsonEncode({
          'nodeid':     nodeId,
          'action':     action,
          'execute_at': executeAt.toUtc().toIso8601String(),
        }),
      ).timeout(const Duration(seconds: 12));

      if (res.statusCode >= 200 && res.statusCode < 300) {
        if (kDebugMode) print('Schedule posted: ${res.body}');
        final s = ServerSchedule.tryParse(jsonDecode(res.body));
        await fetchServerSchedules();
        return s;
      }
      if (kDebugMode) print('postSchedule HTTP ${res.statusCode}: ${res.body}');
    } catch (e) { if (kDebugMode) print('postSchedule: $e'); }
    finally { _pendingSchedulePosts.remove(key); }
    return null;
  }

  /// GET /api/pzem/schedules/?nodeid=<nodeId>
  /// Fetches all schedules (all statuses) for all known nodes.
  Future<void> fetchServerSchedules({String? nodeId}) async {
    if (!_hasValidToken) return;
    try {
      final uri = nodeId != null
          ? Uri.parse('$_base/api/pzem/schedules/?nodeid=$nodeId')
          : Uri.parse('$_base/api/pzem/schedules/');
      final res = await http.get(uri, headers: _sessionHeaders)
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final d    = jsonDecode(res.body);
        final list = d is List ? d : (d is Map ? d['results'] ?? [] : []);
        serverSchedules = (list as List)
            .map((e) => ServerSchedule.tryParse(e))
            .whereType<ServerSchedule>()
            .toList()
          ..sort((a, b) => b.executeAt.compareTo(a.executeAt));
        notifyListeners();
      }
    } catch (e) { if (kDebugMode) print('fetchServerSchedules: $e'); }
  }

  /// DELETE /api/pzem/schedules/<id>/
  /// Returns null on success, error string on failure.
  Future<String?> cancelSchedule(int scheduleId) async {
    if (!_hasValidToken) return 'Not authenticated';
    try {
      final res = await http.delete(
        Uri.parse('$_base/api/pzem/schedules/$scheduleId/'),
        headers: _authHeaders,
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode >= 200 && res.statusCode < 300) {
        serverSchedules.removeWhere((s) => s.id == scheduleId);
        notifyListeners();
        return null; // success
      }
      // Parse error detail from response (e.g. "only pending schedules can be cancelled")
      try {
        final body = jsonDecode(res.body);
        return (body['detail'] ?? body['error'] ?? 'Error ${res.statusCode}').toString();
      } catch (_) { return 'Error ${res.statusCode}'; }
    } catch (e) { return e.toString(); }
  }

  List<ServerSchedule> getSchedulesForNode(String nodeId) =>
      serverSchedules.where((s) => s.nodeId == nodeId).toList();

  List<ServerSchedule> getPendingSchedules() =>
      serverSchedules.where((s) => s.isPending).toList();

  List<ServerSchedule> getExecutedSchedules() =>
      serverSchedules.where((s) => s.isExecuted).toList();

  void disposeService() { _pollTimer?.cancel(); }

  /// Discover nodes from the control/schedules API, then load all data.
  /// Avoids hardcoding any node IDs.
  Future<void> _bootstrap() async {
    if (!_hasValidToken) return;
    // 1. Fetch schedules first — they contain nodeids of all monitored nodes.
    await fetchServerSchedules();
    // Collect node IDs found in schedules
    for (final s in serverSchedules) {
      if (s.nodeId.isNotEmpty) userAddedNodes.add(s.nodeId);
    }
    // 2. Fetch all readings overview to discover active nodes
    await _discoverNodesFromReadings();
    // 3. Now fetch latest for every discovered node in parallel
    await Future.wait(getKnownNodes().map(fetchLatest));
    notifyListeners();
  }

  /// Hits /api/pzemreadings/?format=json with a small limit to discover node IDs
  /// without downloading the entire history.
  Future<void> _discoverNodesFromReadings() async {
    if (!_hasValidToken) return;
    try {
      // Fetch a small slice — enough to discover all active node IDs
      final res = await http
          .get(Uri.parse('$_base/api/pzemreadings/?format=json'), headers: _sessionHeaders)
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final d = jsonDecode(res.body);
        if (d is List) {
          for (final item in d) {
            final nodeId = (item as Map)['nodeid']?.toString() ?? '';
            if (nodeId.isNotEmpty) userAddedNodes.add(nodeId);
          }
          notifyListeners();
        }
      }
    } catch (e) { if (kDebugMode) print('_discoverNodesFromReadings: $e'); }
  }
}

// ── Schedule status ──────────────────────────────────────────────────────────
enum ScheduleStatus { pending, executed, cancelled }

// ── ServerSchedule model ─────────────────────────────────────────────────────
class ServerSchedule {
  final int            id;
  final String         nodeId;
  final String         action;     // "ON" or "OFF"
  final DateTime       executeAt;  // UTC
  final ScheduleStatus status;
  final DateTime       created;

  const ServerSchedule({
    required this.id,
    required this.nodeId,
    required this.action,
    required this.executeAt,
    required this.status,
    required this.created,
  });

  // Convenience getters
  bool get isPending   => status == ScheduleStatus.pending;
  bool get isExecuted  => status == ScheduleStatus.executed;
  bool get isCancelled => status == ScheduleStatus.cancelled;

  // Legacy aliases — keep old callers compiling
  String   get relay         => action;
  bool     get executed      => isExecuted;
  DateTime get scheduledTime => executeAt;  // old name
  DateTime? get executedAt   => isExecuted ? executeAt : null;

  static ScheduleStatus _parseStatus(String s) {
    switch (s.toUpperCase()) {
      case 'EXECUTED':  return ScheduleStatus.executed;
      case 'CANCELLED':
      case 'CANCELED':  return ScheduleStatus.cancelled;
      default:          return ScheduleStatus.pending;
    }
  }

  static DateTime _parseDate(dynamic v) {
    if (v == null) return DateTime.now();
    final s = v.toString();
    return DateTime.tryParse(s) ?? DateTime.tryParse(s.replaceFirst(' ', 'T')) ?? DateTime.now();
  }

  static ServerSchedule? tryParse(dynamic raw) {
    try {
      if (raw is! Map) return null;
      final m = Map<String, dynamic>.from(raw);
      return ServerSchedule(
        id:        (m['id'] as num?)?.toInt() ?? 0,
        nodeId:    m['nodeid']?.toString() ?? m['node_id']?.toString() ?? '',
        action:    m['action']?.toString() ?? m['relay']?.toString() ?? 'ON',
        executeAt: _parseDate(m['execute_at'] ?? m['scheduled_time']),
        status:    _parseStatus(m['status']?.toString() ?? ''),
        created:   _parseDate(m['created_at'] ?? m['created']),
      );
    } catch (_) { return null; }
  }
}
