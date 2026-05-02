// lib/screens/dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../models/reading.dart';
import '../widgets/power_charts.dart';
import '../widgets/schedule_dialog.dart';
import '../utils/app_theme.dart';
import '../services/file_downloader.dart';
import '../services/monthly_report_pdf.dart';

class DashboardScreen extends StatefulWidget {
  static const routeName = '/dashboard';
  final String? nodeId;
  const DashboardScreen({super.key, this.nodeId});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // Chart window (hours)
  int _windowHours = 24;
  bool _loadingHistory = false;
  List<Reading> _history = [];

  bool _relayLoading = false;
  bool _reportDownloading = false;
  String _runtimePeriod = 'daily';
  String _reportPeriod = 'monthly';

  String get _nodeId {
    if (widget.nodeId != null && widget.nodeId!.isNotEmpty) return widget.nodeId!;
    // Fallback: first node in the live discovered list (never hardcoded)
    final api = Provider.of<ApiService>(context, listen: false);
    final nodes = api.getKnownNodes();
    return nodes.isNotEmpty ? nodes.first : '';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAll());
  }

  Future<void> _loadAll() async {
    final api = Provider.of<ApiService>(context, listen: false);
    api.fetchLatest(_nodeId);
    await _loadHistory(api);
  }

  Future<void> _loadHistory(ApiService api) async {
    if (_loadingHistory) return;
    setState(() => _loadingHistory = true);
    final data = await api.fetchNodeHistory(_nodeId);
    if (mounted) setState(() { _history = data; _loadingHistory = false; });
  }

  List<Reading> get _windowedHistory {
    if (_windowHours == 0) return _history;
    final cutoff = DateTime.now().subtract(Duration(hours: _windowHours));
    return _history.where((r) => r.created.isAfter(cutoff)).toList();
  }

  DateTime _periodStart(String period, DateTime now) {
    switch (period) {
      case 'daily': return DateTime(now.year, now.month, now.day);
      case 'weekly': return now.subtract(const Duration(days: 7));
      case 'monthly': return DateTime(now.year, now.month, 1);
      case 'quarterly':
        final qStartMonth = (((now.month - 1) ~/ 3) * 3) + 1;
        return DateTime(now.year, qStartMonth, 1);
      case 'half-yearly': return DateTime(now.year, now.month <= 6 ? 1 : 7, 1);
      case 'annually': return DateTime(now.year, 1, 1);
      default: return DateTime(now.year, now.month, 1);
    }
  }

  double _calculateRuntimeHours(List<Reading> data) {
    if (data.length < 2) return 0;
    final sorted = [...data]..sort((a, b) => a.created.compareTo(b.created));
    double hours = 0;
    for (var i = 1; i < sorted.length; i++) {
      final prev = sorted[i - 1];
      final curr = sorted[i];
      if (prev.relay.toUpperCase() != 'ON') continue;
      var dtSeconds = curr.created.difference(prev.created).inSeconds;
      if (dtSeconds <= 0) continue;
      if (dtSeconds > 20) dtSeconds = 8;
      hours += dtSeconds / 3600.0;
    }
    return hours;
  }

  @override
  Widget build(BuildContext context) {
    final t       = AppTheme.of(context);
    final api     = Provider.of<ApiService>(context);
    final reading = api.latest[_nodeId];
    final isOn    = reading?.relay.toUpperCase() == 'ON';
    final isOnline = api.isNodeOnline(_nodeId);
    final isStale = isOn && !isOnline;
    final statusColor = isOnline
        ? const Color(0xFF22C55E)
        : (isStale ? const Color(0xFFF59E0B) : t.textSec);
    final statusText = isOnline ? 'Online' : (isStale ? 'Stale' : 'Offline');
    final health  = reading?.health ?? 0;
    final name    = api.getDisplayName(_nodeId);
    final wh      = _windowedHistory;

    return Scaffold(
        backgroundColor: t.bg,
        body: SafeArea(
            child: CustomScrollView(slivers: [
              // ── App bar ────────────────────────────────────────────────────────
              SliverToBoxAdapter(child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(children: [
                    _circleBtn(context, Icons.arrow_back_rounded, () => Navigator.pop(context), t),
                    const SizedBox(width: 12),
                    Expanded(child: Text(name, style: TextStyle(
                        color: t.textPrim, fontSize: 18, fontWeight: FontWeight.w800))),
                    // Online/Offline/Stale
                    Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: statusColor.withOpacity(0.35))),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Container(width: 7, height: 7,
                              decoration: BoxDecoration(shape: BoxShape.circle,
                                  color: statusColor)),
                          const SizedBox(width: 5),
                          Text(statusText,
                              style: TextStyle(color: statusColor,
                                  fontSize: 12, fontWeight: FontWeight.w600)),
                        ])),
                    const SizedBox(width: 8),
                    _circleBtn(context, Icons.refresh_rounded, () {
                      api.fetchLatest(_nodeId);
                      _loadHistory(api);
                    }, t),
                  ]))),

              const SliverToBoxAdapter(child: SizedBox(height: 16)),

              // ── Hero card ──────────────────────────────────────────────────────
              SliverToBoxAdapter(child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: t.cardDecoration(radius: 20, glow: isOn, glowColor: t.accent),
                      child: Column(children: [
                        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Container(width: 44, height: 44,
                              decoration: BoxDecoration(
                                  color: t.accent.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                              child: Icon(
                                  ApiService.getDeviceIcon(
                                    name,
                                    reading?.power ?? 0,
                                    reading?.relay ?? 'OFF',
                                  ),
                                  color: t.accent, size: 22)),
                          const SizedBox(width: 14),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(reading != null ? '${reading.power.toStringAsFixed(2)} W' : '— W',
                                style: TextStyle(color: t.textPrim, fontSize: 26, fontWeight: FontWeight.w900)),
                            Text('Current Power Draw', style: TextStyle(color: t.textSec, fontSize: 13)),
                            const SizedBox(height: 6),
                            Row(mainAxisSize: MainAxisSize.min, children: [
                              Container(
                                  width: 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: statusColor)),
                              const SizedBox(width: 5),
                              Text(statusText,
                                  style: TextStyle(
                                      color: statusColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600)),
                            ]),
                          ])),
                          SizedBox(width: 64, height: 64,
                              child: PowerDonut(health: health)),
                        ]),
                        const SizedBox(height: 16),
                        Divider(color: t.divider, height: 1),
                        const SizedBox(height: 14),
                        // 6-metric grid
                        Column(children: [
                          Row(children: [
                            _metric(Icons.bolt_rounded,               'Voltage',
                                '${reading?.voltage.toStringAsFixed(2) ?? '—'} V', t),
                            const SizedBox(width: 8),
                            _metric(Icons.electric_meter_outlined,    'Current',
                                '${reading?.current.toStringAsFixed(3) ?? '—'} A', t),
                          ]),
                          const SizedBox(height: 8),
                          Row(children: [
                            _metric(Icons.compress_rounded,           'Power Factor',
                                reading?.pf.toStringAsFixed(2) ?? '—', t),
                            const SizedBox(width: 8),
                            _metric(Icons.waves_outlined,             'Frequency',
                                '${reading?.frequency.toStringAsFixed(2) ?? '—'} Hz', t),
                          ]),
                          const SizedBox(height: 8),
                          Row(children: [
                            _metric(Icons.energy_savings_leaf_outlined, 'Energy (all-time)',
                                '${reading?.energy.toStringAsFixed(3) ?? '—'} kWh', t),
                            const SizedBox(width: 8),
                            _metric(Icons.access_time_rounded,        'Last update',
                                reading != null ? _fmtTime(reading.created) : '—', t),
                          ]),
                        ]),
                      ])))),

              const SliverToBoxAdapter(child: SizedBox(height: 16)),

              // ── Window chips ────────────────────────────────────────────────────
              SliverToBoxAdapter(child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Power History', style: TextStyle(
                        color: t.textPrim, fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 10),
                    SingleChildScrollView(scrollDirection: Axis.horizontal,
                        child: Row(children: [
                          for (final e in {6: '6h', 12: '12h', 24: '1d', 168: '1w', 720: '1m', 0: 'All'}.entries)
                            Padding(padding: const EdgeInsets.only(right: 8),
                                child: _chip(e.value, _windowHours == e.key, t,
                                        () => setState(() => _windowHours = e.key))),
                        ])),
                  ]))),

              const SliverToBoxAdapter(child: SizedBox(height: 12)),

              // ── Charts ──────────────────────────────────────────────────────────
              SliverToBoxAdapter(child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(children: [
                    _chartCard('Power (W)', _loadingHistory ? null : PowerLineChart(data: wh), t),
                    const SizedBox(height: 12),
                    // Summary strip
                    Row(children: [
                      _summTile('Avg Power',
                          wh.isEmpty ? '—' : '${(wh.map((r) => r.power).reduce((a,b)=>a+b) / wh.length).toStringAsFixed(1)} W',
                          false, t),
                      const SizedBox(width: 8),
                      _summTile('Peak Power',
                          wh.isEmpty ? '—' : '${wh.map((r) => r.power).reduce((a,b)=>a>b?a:b).toStringAsFixed(1)} W',
                          true, t),
                      const SizedBox(width: 8),
                      _summTile('Readings', '${wh.length}', false, t),
                    ]),
                    const SizedBox(height: 12),
                    _chartCard('Voltage (V)', _loadingHistory ? null : VoltageLineChart(data: wh), t),
                    const SizedBox(height: 12),
                    _chartCard('Current (A)', _loadingHistory ? null : CurrentLineChart(data: wh), t),
                    const SizedBox(height: 12),
                    _chartCard('Energy kWh (cumulative)', _loadingHistory ? null : EnergyLineChart(data: wh), t),
                    const SizedBox(height: 16),

                    // Actions
                    Row(children: [
                      Expanded(child: _actionBtn(Icons.bar_chart_rounded, 'Usage Report', false, t, _reportDownloading ? null : _downloadUsageReport, loading: _reportDownloading)),
                      const SizedBox(width: 12),
                      Expanded(child: _actionBtn(Icons.schedule_rounded, 'Schedule', true, t,
                              () => showScheduleDialog(context, _nodeId))),
                    ]),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: t.cardDecoration(radius: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Runtime Calculator', style: TextStyle(color: t.textPrim, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: _runtimePeriod,
                                  items: const [
                                    DropdownMenuItem(value: 'daily', child: Text('Daily')),
                                    DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                                    DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                                    DropdownMenuItem(value: 'quarterly', child: Text('Quarterly')),
                                  ],
                                  onChanged: (v) => setState(() => _runtimePeriod = v ?? 'daily'),
                                  decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                '${_calculateRuntimeHours(_history.where((r) => !r.created.isBefore(_periodStart(_runtimePeriod, DateTime.now()))).toList()).toStringAsFixed(2)} h',
                                style: TextStyle(color: t.textPrim, fontWeight: FontWeight.w800, fontSize: 16),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<String>(
                            value: _reportPeriod,
                            items: const [
                              DropdownMenuItem(value: 'monthly', child: Text('PDF Period: Monthly')),
                              DropdownMenuItem(value: 'quarterly', child: Text('PDF Period: Quarterly')),
                              DropdownMenuItem(value: 'half-yearly', child: Text('PDF Period: Half-Yearly')),
                              DropdownMenuItem(value: 'annually', child: Text('PDF Period: Annually')),
                            ],
                            onChanged: (v) => setState(() => _reportPeriod = v ?? 'monthly'),
                            decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Power toggle
                    Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        decoration: t.cardDecoration(radius: 16),
                        child: Row(children: [
                          Text('Relay',
                              style: TextStyle(color: t.textPrim, fontSize: 15, fontWeight: FontWeight.w600)),
                          const SizedBox(width: 8),
                          Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                  color: isOn ? t.success.withOpacity(0.12) : t.chipFill,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: isOn ? t.success.withOpacity(0.3) : t.cardBorder)),
                              child: Text(reading?.relay ?? '—',
                                  style: TextStyle(color: isOn ? t.success : t.textSec,
                                      fontSize: 12, fontWeight: FontWeight.w700))),
                          const Spacer(),
                          // Show spinner while relay request is in flight
                          _relayLoading || reading == null
                              ? SizedBox(width: 24, height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2.5, color: t.accent))
                              : Switch(
                              value: isOn,
                              onChanged: (_) async {
                                setState(() => _relayLoading = true);
                                await api.toggleNode(_nodeId);
                                if (mounted) setState(() => _relayLoading = false);
                              },
                              thumbColor: WidgetStateProperty.resolveWith((s) =>
                              s.contains(WidgetState.selected)
                                  ? (t.dark ? const Color(0xFF0A1628) : Colors.white)
                                  : Colors.grey),
                              trackColor: WidgetStateProperty.resolveWith((s) =>
                              s.contains(WidgetState.selected) ? t.accent : Colors.grey.withOpacity(0.3))),
                        ])),
                    const SizedBox(height: 24),
                  ]))),
            ])));
  }



  Future<void> _downloadUsageReport() async {
    final now = DateTime.now();
    final periodStart = _periodStart(_reportPeriod, now);
    final monthly = _history.where((r) => !r.created.isBefore(periodStart)).toList()
      ..sort((a, b) => a.created.compareTo(b.created));

    if (monthly.length < 2) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not enough data in selected period to generate usage report.')),
      );
      return;
    }

    final api = Provider.of<ApiService>(context, listen: false);
    final monthlyUsage = ((monthly.last.energy - monthly.first.energy).clamp(0.0, double.infinity) as num).toDouble();
    final totalConsumption = (monthly.last.energy.clamp(0.0, double.infinity) as num).toDouble();

    double runtimeHours = 0;
    final weekly = <double>[0, 0, 0, 0, 0];

    for (var i = 1; i < monthly.length; i++) {
      final prev = monthly[i - 1];
      final curr = monthly[i];
      var dtHours = curr.created.difference(prev.created).inSeconds / 3600.0;
      if (dtHours < 0) continue;
      if (dtHours > (20 / 3600.0)) dtHours = (8 / 3600.0);
      if (prev.relay.toUpperCase() != 'ON') continue;

      runtimeHours += dtHours;
      final weekIndex = ((prev.created.day - 1) ~/ 7).clamp(0, weekly.length - 1);
      weekly[weekIndex] += dtHours;
    }

    final predictedUsage = monthlyUsage;

    final report = MonthlyUsageReport(
      nodeId: _nodeId,
      deviceName: api.getDisplayName(_nodeId),
      monthLabel: _periodLabel(now),
      monthlyUsageKwh: monthlyUsage,
      predictedUsageKwh: predictedUsage,
      totalRunHours: runtimeHours,
      totalConsumptionKwh: totalConsumption,
      weeklyRunHours: weekly,
    );

    setState(() => _reportDownloading = true);
    try {
      final bytes = buildMonthlyUsagePdf(report);
      final fileName = 'usage_report_${_nodeId.toLowerCase()}_${_reportPeriod}_${now.year}_${now.month.toString().padLeft(2, '0')}.pdf';
      final savedPath = await downloadBytes(bytes, fileName);

      if (!mounted) return;
      if (savedPath != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Usage report saved: $savedPath')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save report. Please check storage permissions.')),
        );
      }
    } finally {
      if (mounted) setState(() => _reportDownloading = false);
    }
  }

  String _monthName(int month) {
    const names = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return names[(month - 1).clamp(0, 11)];
  }

  String _periodLabel(DateTime now) {
    switch (_reportPeriod) {
      case 'quarterly':
        final q = ((now.month - 1) ~/ 3) + 1;
        return 'Q$q ${now.year}';
      case 'half-yearly':
        return '${now.month <= 6 ? 'H1' : 'H2'} ${now.year}';
      case 'annually':
        return '${now.year}';
      case 'monthly':
      default:
        return '${_monthName(now.month)} ${now.year}';
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  String _fmtTime(DateTime dt) {
    final l = dt.toLocal();
    return '${l.hour.toString().padLeft(2,'0')}:${l.minute.toString().padLeft(2,'0')}';
  }

  Widget _circleBtn(BuildContext ctx, IconData icon, VoidCallback onTap, AppTheme t) =>
      GestureDetector(onTap: onTap,
          child: Container(width: 38, height: 38,
              decoration: BoxDecoration(shape: BoxShape.circle, color: t.chipFill,
                  border: Border.all(color: t.cardBorder)),
              child: Icon(icon, color: t.textPrim, size: 18)));

  Widget _metric(IconData icon, String label, String value, AppTheme t) => Expanded(
      child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(color: t.chipFill, borderRadius: BorderRadius.circular(10),
              border: Border.all(color: t.cardBorder)),
          child: Row(children: [
            Icon(icon, color: t.accent, size: 14),
            const SizedBox(width: 7),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(value, style: TextStyle(color: t.textPrim, fontSize: 12, fontWeight: FontWeight.w700),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(label, style: TextStyle(color: t.textSec, fontSize: 10)),
            ])),
          ])));

  Widget _chip(String label, bool sel, AppTheme t, VoidCallback onTap) =>
      GestureDetector(onTap: onTap,
          child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                  color: sel ? t.accent.withOpacity(0.12) : t.chipFill,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: sel ? t.accent.withOpacity(0.4) : t.cardBorder)),
              child: Text(label, style: TextStyle(
                  color: sel ? t.accent : t.textSec,
                  fontSize: 12, fontWeight: sel ? FontWeight.w700 : FontWeight.w400))));

  Widget _chartCard(String title, Widget? child, AppTheme t) => Container(
      padding: const EdgeInsets.all(16),
      decoration: t.cardDecoration(radius: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(color: t.textSec, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        SizedBox(height: 180,
            child: child ?? Center(child: CircularProgressIndicator(color: t.accent, strokeWidth: 2))),
      ]));

  Widget _summTile(String label, String value, bool highlight, AppTheme t) => Expanded(
      child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
          decoration: BoxDecoration(
              color: highlight ? t.accent.withOpacity(0.08) : t.chipFill,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: highlight ? t.accent.withOpacity(0.3) : t.cardBorder)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(color: highlight ? t.accent : t.textSec, fontSize: 10)),
            const SizedBox(height: 3),
            Text(value, style: TextStyle(color: highlight ? t.accent : t.textPrim,
                fontSize: 12, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
          ])));

  Widget _actionBtn(
    IconData icon,
    String label,
    bool primary,
    AppTheme t,
    VoidCallback? onTap, {
    bool loading = false,
  }) =>
      GestureDetector(
          onTap: onTap,
          child: AnimatedOpacity(
              duration: const Duration(milliseconds: 120),
              opacity: onTap == null ? 0.7 : 1.0,
              child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(
                      color: primary ? t.accent.withOpacity(0.1) : t.chipFill,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: primary ? t.accent.withOpacity(0.3) : t.cardBorder)),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    if (loading)
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: primary ? t.accent : t.iconSec),
                      )
                    else
                      Icon(icon, color: primary ? t.accent : t.iconSec, size: 18),
                    const SizedBox(width: 8),
                    Text(loading ? 'Generating...' : label,
                        style: TextStyle(color: primary ? t.accent : t.iconSec,
                            fontSize: 13, fontWeight: FontWeight.w600)),
                  ]))));
}
