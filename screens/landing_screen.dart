// lib/screens/landing_screen.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../models/reading.dart';
import 'dashboard_screen.dart';
import 'trends_screen.dart';
import 'devices_screen.dart';
import 'profile_screen.dart';
import '../widgets/schedule_dialog.dart';
import '../widgets/nirwana_logo.dart';
import '../widgets/voice_assistant_sheet.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});
  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  int _navIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      const _HomeTab(),
      const TrendsScreen(),
      const DevicesScreen(),
      const ProfileScreen(),
    ];
    return Scaffold(
      body: IndexedStack(index: _navIndex, children: pages),
      bottomNavigationBar: _BottomNav(
        currentIndex: _navIndex,
        onTap: (i) => setState(() => _navIndex = i),
      ),
    );
  }
}

// ─── Home Tab ────────────────────────────────────────────────────────────────

class _HomeTab extends StatefulWidget {
  const _HomeTab();
  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  int _carouselIdx = 0;
  final _pageCtrl  = PageController();

  bool  get _dark   => Theme.of(context).brightness == Brightness.dark;
  Color get _accent => Theme.of(context).colorScheme.primary;
  Color get _bg     => Theme.of(context).scaffoldBackgroundColor;
  Color get _onBg   => _dark ? Colors.white : const Color(0xFF1A2332);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final api = Provider.of<ApiService>(context, listen: false);
      api.fetchLatestAll();
      // history loaded on-demand per node in DashboardScreen
      api.fetchServerSchedules();
    });
  }

  @override
  Widget build(BuildContext context) {
    final api    = Provider.of<ApiService>(context);
    final nodes  = api.getKnownNodes()..sort();
    final active = nodes.where((n) => api.isNodeOnline(n)).length;
    final totalW      = api.getTotalCurrentPowerW();
    final monthlyKwh  = api.getMonthlyEnergyKwh();
    final allTimeKwh  = api.getAllTimeEnergyKwh();
    final bill        = api.getEstimatedBill();
    final carbon      = api.getCarbonKg();

    return SafeArea(child: Column(children: [
      // ── App bar ─────────────────────────────────────────────────────────
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        child: Row(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _logoCircle(42),
            const SizedBox(height: 2),
            Text('CO₂: ${carbon.toStringAsFixed(1)} kg',
                style: TextStyle(color: _accent, fontSize: 9, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(width: 10),
          _pill(Icons.home_outlined, 'My Home', Icons.keyboard_arrow_down_rounded),
          const Spacer(),
          _circleBtn(Icons.add_rounded, () => _showAddDialog(context, api)),
          const SizedBox(width: 8),
          Stack(children: [
            _circleBtn(Icons.notifications_outlined, () {}),
            Positioned(right: 8, top: 8,
                child: Container(width: 8, height: 8,
                    decoration: const BoxDecoration(color: Color(0xFFFF9800), shape: BoxShape.circle))),
          ]),
        ]),
      ),
      const SizedBox(height: 12),

      // ── Carousel ────────────────────────────────────────────────────────
      SizedBox(
        height: 138,
        child: PageView(
          controller: _pageCtrl,
          onPageChanged: (i) => setState(() => _carouselIdx = i),
          children: [
            _EnergyCard(
                currentW: totalW,
                monthlyKwh: monthlyKwh,
                allTimeKwh: allTimeKwh,
                bill: bill,
                dark: _dark, accent: _accent),
            _CarbonCard(
                carbon: carbon,
                monthlyKwh: monthlyKwh,
                dark: _dark, accent: _accent),
          ],
        ),
      ),
      const SizedBox(height: 8),
      Row(mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(2, (i) => AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: _carouselIdx == i ? 20 : 6, height: 5,
            decoration: BoxDecoration(
                color: _carouselIdx == i ? _accent : Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(3)),
          ))),
      const SizedBox(height: 14),

      // ── Header ──────────────────────────────────────────────────────────
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(children: [
          Text('Home Devices',
              style: TextStyle(color: _onBg, fontSize: 18, fontWeight: FontWeight.w800)),
          const Spacer(),
          Text('$active active',
              style: TextStyle(color: _accent, fontSize: 13, fontWeight: FontWeight.w600)),
        ]),
      ),
      const SizedBox(height: 10),

      // ── Grid ────────────────────────────────────────────────────────────
      Expanded(
        child: nodes.isEmpty
            ? Center(child: CircularProgressIndicator(color: _accent))
            : GridView.builder(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            mainAxisExtent: 310, // fixed px height avoids overflow on all densities
          ),
          itemCount: nodes.length,
          itemBuilder: (_, i) {
            final id      = nodes[i];
            final reading = api.latest[id];
            final health  = reading != null ? api.computeHealthScore(reading) : 100;
            return _DeviceCard(
              nodeId:    id,
              label:     api.getDisplayName(id),
              reading:   reading,
              health:    health,
              dark:      _dark,
              accent:    _accent,
              isOnline:  api.isNodeOnline(id),
              lastSeen:  api.lastSeenLabel(id),
              onTap:    () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => DashboardScreen(nodeId: id))),
              onToggle: (d) => api.controlNode(id, d),
              onSchedule: () => showScheduleDialog(context, id),
              onRename: () => _showRenameDialog(context, api, id),
            );
          },
        ),
      ),
    ]));
  }

  // ── helpers ───────────────────────────────────────────────────────────────
  Widget _logoCircle(double size) => NirwanaLogo(
      size: size, accentColor: _accent, glowOpacity: 0.18);

  Widget _pill(IconData a, String label, IconData b) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: BoxDecoration(
        color: (_dark ? Colors.white : Colors.black).withOpacity(0.06),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: (_dark ? Colors.white : Colors.black).withOpacity(0.1))),
    child: Row(children: [
      Icon(a, color: _dark ? Colors.white70 : Colors.black54, size: 14),
      const SizedBox(width: 5),
      Text(label, style: TextStyle(color: _onBg, fontSize: 12, fontWeight: FontWeight.w600)),
      const SizedBox(width: 3),
      Icon(b, color: _dark ? Colors.white38 : Colors.black38, size: 14),
    ]),
  );

  Widget _circleBtn(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
        width: 38, height: 38,
        decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: (_dark ? Colors.white : Colors.black).withOpacity(0.06),
            border: Border.all(color: (_dark ? Colors.white : Colors.black).withOpacity(0.1))),
        child: Icon(icon, color: _onBg, size: 18)),
  );

  Future<void> _showAddDialog(BuildContext ctx, ApiService api) async {
    final c = TextEditingController();
    await showDialog(context: ctx, builder: (d) => AlertDialog(
      title: Text('Add Device', style: TextStyle(color: _onBg, fontWeight: FontWeight.w700)),
      content: TextField(controller: c,
          decoration: const InputDecoration(labelText: 'Node ID (e.g. NODE_4)')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')),
        ElevatedButton(
            onPressed: () { if (c.text.isNotEmpty) { api.addNodePlaceholder(c.text.trim()); Navigator.pop(d); } },
            child: const Text('Add')),
      ],
    ));
  }

  Future<void> _showRenameDialog(BuildContext ctx, ApiService api, String nodeId) async {
    // Pre-fill with existing user-set name (not auto-detected)
    final existing = api.displayNames[nodeId] ?? '';
    final ctrl = TextEditingController(text: existing);
    final reading = api.latest[nodeId];
    final autoName = reading != null
        ? _autoDetectName(reading.power, reading.relay)
        : null;

    await showDialog(context: ctx, builder: (d) => AlertDialog(
      title: Text('Rename Device', style: TextStyle(color: _onBg, fontWeight: FontWeight.w700)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        if (autoName != null)
          Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(children: [
                Icon(Icons.auto_fix_high_rounded, size: 14,
                    color: Theme.of(ctx).colorScheme.primary),
                const SizedBox(width: 6),
                Expanded(child: Text('Auto-detected: $autoName',
                    style: TextStyle(fontSize: 12,
                        color: Theme.of(ctx).colorScheme.primary))),
              ])),
        TextField(
            controller: ctrl,
            decoration: InputDecoration(
              labelText: 'Custom name',
              hintText: autoName ?? nodeId,
              helperText: 'Leave blank to use auto-detected name',
              helperMaxLines: 2,
            )),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')),
        // Reset to auto-detect
        if (api.displayNames.containsKey(nodeId))
          TextButton(
              onPressed: () {
                api.displayNames.remove(nodeId);
                api.notifyListeners();
                Navigator.pop(d);
              },
              child: Text('Reset', style: TextStyle(color: Theme.of(ctx).colorScheme.error))),
        ElevatedButton(
            onPressed: () {
              final name = ctrl.text.trim();
              if (name.isNotEmpty) {
                api.setDisplayName(nodeId, name);
              } else {
                // Empty = remove custom name, fall back to auto-detect
                api.displayNames.remove(nodeId);
                api.notifyListeners();
              }
              Navigator.pop(d);
            },
            child: const Text('Save')),
      ],
    ));
  }

  /// Returns auto-detected device name based on power (W) — same thresholds as ApiService.
  static String? _autoDetectName(double w, String relay) {
    if (relay.toUpperCase() != 'ON') return null;
    if (w >= 3    && w <= 9)    return 'LED Bulb';
    if (w >= 10   && w <= 120)  return 'Charger';
    if (w >= 300  && w <= 750)  return 'Electric Iron';
    if (w >= 751  && w <= 1200) return 'Electric Kettle';
    if (w >= 1201 && w <= 2000) return 'Electric Heater';
    if (w >= 2001 && w <= 4500) return 'Air Conditioner';
    return null;
  }
}

// ─── Carousel Cards ───────────────────────────────────────────────────────────

class _EnergyCard extends StatelessWidget {
  /// [currentW]    — live total power draw right now (sum of latest.power for all nodes)
  /// [monthlyKwh]  — energy consumed this calendar month (delta of cumulative register)
  /// [allTimeKwh]  — sum of latest cumulative energy registers across all nodes
  /// [bill]        — monthlyKwh × ratePerUnit
  final double currentW, monthlyKwh, allTimeKwh, bill;
  final bool dark; final Color accent;
  const _EnergyCard({
    required this.currentW, required this.monthlyKwh,
    required this.allTimeKwh, required this.bill,
    required this.dark, required this.accent});

  @override
  Widget build(BuildContext context) {
    final sub   = dark ? Colors.white54  : Colors.black45;
    final title = dark ? Colors.white60  : Colors.black54;
    final body  = dark ? Colors.white    : Colors.black87;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
        decoration: BoxDecoration(
            color: (dark ? Colors.white : Colors.black).withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: (dark ? Colors.white : Colors.black).withOpacity(0.09))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Energy Consumption', style: TextStyle(color: title, fontSize: 11)),
            const SizedBox(height: 4),
            // Current live power
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(currentW >= 1000
                  ? '${(currentW / 1000).toStringAsFixed(2)} kW'
                  : '${currentW.toStringAsFixed(0)} W',
                  style: TextStyle(color: body, fontSize: 24,
                      fontWeight: FontWeight.w900, height: 1.1)),
              const SizedBox(width: 6),
              Padding(padding: const EdgeInsets.only(bottom: 2),
                  child: Text('live', style: TextStyle(color: sub, fontSize: 10))),
            ]),
            const SizedBox(height: 5),
            // Monthly kWh + bill on same row
            Row(children: [
              Text('${monthlyKwh.toStringAsFixed(3)} kWh',
                  style: TextStyle(color: sub, fontSize: 11, fontWeight: FontWeight.w600)),
              Text(' this month', style: TextStyle(color: sub, fontSize: 10)),
            ]),
            const SizedBox(height: 2),
            Row(children: [
              Text('₹${bill.toStringAsFixed(0)} est. bill',
                  style: TextStyle(color: accent, fontSize: 11, fontWeight: FontWeight.w700)),
              const SizedBox(width: 8),
              Text('• ${allTimeKwh.toStringAsFixed(2)} kWh all-time',
                  style: TextStyle(color: sub, fontSize: 10)),
            ]),
          ])),
          const SizedBox(width: 12),
          Container(width: 48, height: 48,
              decoration: BoxDecoration(
                  color: accent.withOpacity(0.15), borderRadius: BorderRadius.circular(14)),
              child: Icon(Icons.bolt_rounded, color: accent, size: 24)),
        ]),
      ),
    );
  }
}

class _CarbonCard extends StatelessWidget {
  final double carbon, monthlyKwh;
  final bool dark; final Color accent;
  const _CarbonCard({required this.carbon, required this.monthlyKwh,
    required this.dark, required this.accent});

  @override
  Widget build(BuildContext context) {
    final sub  = dark ? Colors.white54  : Colors.black45;
    final body = dark ? Colors.white    : Colors.black87;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
        decoration: BoxDecoration(
            gradient: LinearGradient(
                colors: dark
                    ? [const Color(0xFF0D2137), const Color(0xFF091828)]
                    : [const Color(0xFFE8F7FB), const Color(0xFFF0FAFE)],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: accent.withOpacity(0.18))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Carbon Footprint', style: TextStyle(color: dark ? Colors.white60 : Colors.black54, fontSize: 11)),
            const SizedBox(height: 4),
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('${carbon.toStringAsFixed(2)} kg',
                  style: TextStyle(color: body, fontSize: 24, fontWeight: FontWeight.w900, height: 1.1)),
              const SizedBox(width: 6),
              Padding(padding: const EdgeInsets.only(bottom: 2),
                  child: Text('CO₂', style: TextStyle(color: sub, fontSize: 10))),
            ]),
            const SizedBox(height: 5),
            Text('Based on ${monthlyKwh.toStringAsFixed(3)} kWh this month',
                style: TextStyle(color: sub, fontSize: 10)),
            const SizedBox(height: 2),
            Text('India grid factor: 0.82 kg CO₂ / kWh  (CEA 2023)',
                style: TextStyle(color: sub.withOpacity(0.7), fontSize: 9)),
          ])),
          const SizedBox(width: 12),
          Container(width: 48, height: 48,
              decoration: BoxDecoration(
                  color: accent.withOpacity(0.12), borderRadius: BorderRadius.circular(14)),
              child: Padding(padding: const EdgeInsets.all(11),
                  child: Image.asset('assets/icons/ng_logo.png', fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Icon(Icons.eco_rounded, color: accent, size: 22)))),
        ]),
      ),
    );
  }
}

// ─── Device Card with Health Donut ───────────────────────────────────────────

class _DeviceCard extends StatefulWidget {
  final String nodeId, label;
  final Reading? reading;
  final int health;
  final bool dark, isOnline;
  final Color accent;
  final VoidCallback onTap, onSchedule, onRename;
  final String lastSeen;
  final Future<bool> Function(String) onToggle;

  const _DeviceCard({
    required this.nodeId, required this.label, required this.reading,
    required this.health, required this.dark, required this.accent,
    required this.isOnline, required this.lastSeen,
    required this.onTap, required this.onToggle,
    required this.onSchedule, required this.onRename,
  });

  @override
  State<_DeviceCard> createState() => _DeviceCardState();
}

class _DeviceCardState extends State<_DeviceCard> {
  bool _loading = false;
  bool? _localOn;

  @override
  void initState() {
    super.initState();
    _localOn = (widget.reading?.relay ?? 'OFF').toUpperCase() == 'ON';
  }

  @override
  void didUpdateWidget(covariant _DeviceCard old) {
    super.didUpdateWidget(old);
    _localOn = (widget.reading?.relay ?? 'OFF').toUpperCase() == 'ON';
  }

  Future<void> _toggle() async {
    setState(() => _loading = true);
    final desired = (_localOn ?? false) ? 'OFF' : 'ON';
    setState(() => _localOn = desired == 'ON');
    final ok = await widget.onToggle(desired);
    if (!ok && mounted) setState(() => _localOn = !(_localOn ?? false));
    if (mounted) setState(() => _loading = false);
  }

  Color _healthColor() {
    if (widget.health >= 75) return const Color(0xFF22C55E);
    if (widget.health >= 50) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  String _healthLabel() {
    if (widget.health >= 75) return 'Good';
    if (widget.health >= 50) return 'Fair';
    return 'Poor';
  }

  IconData _icon() {
    // Use the centralised smart icon picker from ApiService
    return ApiService.getDeviceIcon(
      widget.label,
      widget.reading?.power ?? 0,
      widget.reading?.relay ?? 'OFF',
    );
  }

  @override
  Widget build(BuildContext context) {
    final reading  = widget.reading;
    final isOn     = _localOn ?? false;
    // isOnline: relay ON *and* last update within 5 min (from ApiService.isNodeOnline)
    final isOnline = widget.isOnline;
    final isStale  = isOn && !isOnline;
    final hc       = _healthColor();
    final border   = widget.dark ? Colors.white : Colors.black;
    final statusColor = isOnline
        ? const Color(0xFF22C55E)
        : (isStale ? const Color(0xFFF59E0B) : Colors.grey);
    final statusText = isOnline ? 'Online' : (isStale ? 'Stale' : 'Offline');

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: (widget.dark ? Colors.white : Colors.black).withOpacity(0.04),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: isOn ? widget.accent.withOpacity(0.3) : border.withOpacity(0.09)),
          boxShadow: isOn
              ? [BoxShadow(color: widget.accent.withOpacity(0.07), blurRadius: 16)]
              : [],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Row: icon + three-dot
          Row(children: [
            Container(width: 34, height: 34,
                decoration: BoxDecoration(
                    color: isOn ? widget.accent.withOpacity(0.14) : border.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(_icon(),
                    color: isOn ? widget.accent : (widget.dark ? Colors.white54 : Colors.black45),
                    size: 18)),
            const Spacer(),
            GestureDetector(
                onTap: widget.onRename,
                child: Icon(Icons.more_vert_rounded,
                    color: widget.dark ? Colors.white38 : Colors.black38, size: 18)),
          ]),
          const SizedBox(height: 6),

          // Name + status
          Text(widget.label,
              style: TextStyle(
                  color: widget.dark ? Colors.white : Colors.black87,
                  fontSize: 12, fontWeight: FontWeight.w700),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Row(children: [
            Container(width: 6, height: 6,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: statusColor.withOpacity(0.9))),
            const SizedBox(width: 4),
            Text(statusText,
                style: TextStyle(
                    color: statusColor,
                    fontSize: 10)),
          ]),
          const SizedBox(height: 6),

          // Power reading
          Text(reading != null ? '${(reading.power / 1000).toStringAsFixed(2)} kW' : '— kW',
              style: TextStyle(
                  color: widget.dark ? Colors.white : Colors.black87,
                  fontSize: 17, fontWeight: FontWeight.w800)),
          Text('Current usage',
              style: TextStyle(
                  color: widget.dark ? Colors.white38 : Colors.black38,
                  fontSize: 10)),
          const SizedBox(height: 8),

          // ── Health Donut ───────────────────────────────────────────────
          Center(
            child: SizedBox(
              width: 64, height: 64,
              child: Stack(alignment: Alignment.center, children: [
                // Background ring
                SizedBox(width: 64, height: 64,
                    child: CircularProgressIndicator(
                        value: 1.0,
                        strokeWidth: 7,
                        valueColor: AlwaysStoppedAnimation<Color>(
                            border.withOpacity(0.07)))),
                // Health arc
                SizedBox(width: 64, height: 64,
                    child: CircularProgressIndicator(
                        value: (widget.health / 100).clamp(0.0, 1.0),
                        strokeWidth: 7,
                        valueColor: AlwaysStoppedAnimation<Color>(hc),
                        backgroundColor: Colors.transparent)),
                // Centre text
                Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('${widget.health}%',
                      style: TextStyle(color: hc, fontSize: 13, fontWeight: FontWeight.w800)),
                  Text(_healthLabel(),
                      style: TextStyle(
                          color: widget.dark ? Colors.white38 : Colors.black38,
                          fontSize: 8)),
                ]),
              ]),
            ),
          ),
          const SizedBox(height: 8),

          // Toggle
          Row(children: [
            Text('Power',
                style: TextStyle(
                    color: widget.dark ? Colors.white54 : Colors.black45,
                    fontSize: 11)),
            const Spacer(),
            _loading
                ? SizedBox(width: 16, height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: widget.accent))
                : GestureDetector(
              onTap: _toggle,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 40, height: 22,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                    color: isOn ? widget.accent : border.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(11)),
                child: AnimatedAlign(
                  duration: const Duration(milliseconds: 200),
                  alignment: isOn ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    width: 16, height: 16,
                    decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 3)]),
                  ),
                ),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}

// ─── Bottom Navigation ────────────────────────────────────────────────────────

class _TabItem {
  final IconData icon, activeIcon;
  final String label;
  const _TabItem(this.icon, this.activeIcon, this.label);
}

class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  const _BottomNav({required this.currentIndex, required this.onTap});

  static const List<_TabItem> _tabs = [
    _TabItem(Icons.home_outlined,           Icons.home_rounded,           'Home'),
    _TabItem(Icons.trending_up_outlined,    Icons.trending_up_rounded,    'Trends'),
    _TabItem(Icons.devices_outlined,        Icons.devices_rounded,        'Devices'),
    _TabItem(Icons.person_outline_rounded,  Icons.person_rounded,         'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    final dark   = Theme.of(context).brightness == Brightness.dark;
    final accent = Theme.of(context).colorScheme.primary;
    final bg     = dark ? const Color(0xFF0D1828) : Colors.white;
    final border = (dark ? Colors.white : Colors.black).withOpacity(0.08);

    return Container(
      height: 72,
      decoration: BoxDecoration(
          color: bg,
          border: Border(top: BorderSide(color: border))),
      child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,          // allows ComingSoon badge to overflow nav bar top
          children: [
            Row(children: [
              _tile(0, accent, dark),
              _tile(1, accent, dark),
              const SizedBox(width: 72),
              _tile(2, accent, dark),
              _tile(3, accent, dark),
            ]),
            // Centre mic FAB — Voice Assistant (relay control via speech)
            Positioned(
              top: 6,
              child: GestureDetector(
                onTap: () => showVoiceAssistant(context),
                child: Container(
                    width: 52, height: 52,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                            colors: [accent, accent.withOpacity(0.65)],
                            begin: Alignment.topLeft, end: Alignment.bottomRight),
                        boxShadow: [
                          BoxShadow(color: accent.withOpacity(0.45), blurRadius: 16, spreadRadius: 2)]),
                    child: const Icon(Icons.assistant_rounded, color: Colors.white, size: 26)),
              ),
            ),
          ]),
    );
  }

  Widget _tile(int idx, Color accent, bool dark) {
    final active = currentIndex == idx;
    final tab    = _tabs[idx];
    final color  = active ? accent : (dark ? Colors.white38 : Colors.black38);
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(idx),
        behavior: HitTestBehavior.opaque,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(active ? tab.activeIcon : tab.icon, color: color, size: 22),
          const SizedBox(height: 3),
          Text(tab.label,
              style: TextStyle(color: color, fontSize: 10,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w400)),
          const SizedBox(height: 2),
          Container(width: 4, height: 4,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: active ? accent : Colors.transparent)),
        ]),
      ),
    );
  }
}
