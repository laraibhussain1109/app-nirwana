// lib/screens/trends_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/reading.dart';
import '../services/api_service.dart';
import '../utils/app_theme.dart';
import '../widgets/app_header.dart';
import '../widgets/nirwana_logo.dart';
import '../widgets/power_charts.dart';

class TrendsScreen extends StatefulWidget {
  const TrendsScreen({super.key});

  @override
  State<TrendsScreen> createState() => _TrendsScreenState();
}

class _TrendsScreenState extends State<TrendsScreen> {
  String? _node; // null until nodes are discovered from API
  int _windowHours = 24;
  bool _loading = false;
  List<Reading> _history = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final api = Provider.of<ApiService>(context, listen: false);
      final nodes = api.getKnownNodes();
      if (nodes.isNotEmpty && _node == null) {
        setState(() => _node = nodes.first);
      }
      _load();
    });
  }

  Future<void> _load() async {
    if (_loading || _node == null) return;

    setState(() => _loading = true);

    final api = Provider.of<ApiService>(context, listen: false);
    final data = await api.fetchNodeHistory(_node!);

    if (!mounted) return;
    setState(() {
      _history = data;
      _loading = false;
    });
  }

  List<Reading> get _windowed {
    if (_windowHours == 0) return _history;
    final cutoff = DateTime.now().subtract(Duration(hours: _windowHours));
    return _history.where((r) => r.created.isAfter(cutoff)).toList();
  }

  void _selectNode(String nodeId) {
    setState(() {
      _node = nodeId;
      _history = [];
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    final api = Provider.of<ApiService>(context);
    final nodes = api.getKnownNodes();

    // Auto-select first node when nodes become available
    if (_node == null && nodes.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _selectNode(nodes.first);
      });
    }

    final currentW = api.getTotalCurrentPowerW();
    final monthlyKwh = api.getMonthlyEnergyKwh();
    final allTimeKwh = api.getAllTimeEnergyKwh();
    final bill = api.getEstimatedBill();
    final aiBill = api.getAiPredictedBill();
    final aiKwh = api.getAiPredictedKwh();
    final carbon = api.getCarbonKg();
    final wh = _windowed;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppHeader(),
            const SizedBox(height: 16),

            Text(
              'Trends',
              style: TextStyle(
                color: t.textPrim,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Real-time consumption monitor',
              style: TextStyle(color: t.textSec, fontSize: 13),
            ),
            const SizedBox(height: 20),

            // Summary card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: t.dark
                      ? [const Color(0xFF0D2137), const Color(0xFF091828)]
                      : [const Color(0xFFE8F7FB), const Color(0xFFF0FAFE)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: t.accent.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: t.accent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: t.accent.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bolt_rounded, color: t.accent, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          'UNITS CONSUMED (THIS MONTH)',
                          style: TextStyle(
                            color: t.accent,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        monthlyKwh.toStringAsFixed(3),
                        style: TextStyle(
                          color: t.textPrim,
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          'kWh',
                          style: TextStyle(
                            color: t.textSec,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: t.accent.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${currentW >= 1000 ? "${(currentW / 1000).toStringAsFixed(2)} kW" : "${currentW.toStringAsFixed(0)} W"} live',
                          style: TextStyle(
                            color: t.accent,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _stat(
                        currentW >= 1000
                            ? '${(currentW / 1000).toStringAsFixed(2)}'
                            : currentW.toStringAsFixed(0),
                        currentW >= 1000 ? 'kW live' : 'W live',
                        t,
                      ),
                      _vDiv(t),
                      _stat(allTimeKwh.toStringAsFixed(2), 'kWh total', t),
                      _vDiv(t),
                      _stat('₹${bill.toStringAsFixed(0)}', 'est. bill', t),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: t.warning.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: t.warning.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline_rounded,
                            color: t.warning, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'Bill shown is before taxes.',
                          style: TextStyle(color: t.warning, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // AI Forecasting
            Container(
              padding: const EdgeInsets.all(20),
              decoration: t.cardDecoration(radius: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: t.accent.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.auto_graph_rounded,
                            color: t.accent, size: 16),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AI Forecasting',
                            style: TextStyle(
                              color: t.textPrim,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'avg daily × days in month × rate',
                            style: TextStyle(color: t.textSec, fontSize: 10),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _forecastTile(
                          'Predicted Bill',
                          '₹${aiBill.toStringAsFixed(0)}',
                          'avg daily ÷ ${DateTime.now().day} days × ${_daysInMonth()} days × ₹${api.ratePerUnit.toStringAsFixed(0)}/kWh',
                          t.success,
                          t,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _forecastTile(
                          'Predicted Usage',
                          aiKwh.toStringAsFixed(2),
                          'kWh projected end-of-month',
                          t.accent,
                          t,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: t.accent.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: t.accent.withOpacity(0.15)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline_rounded,
                            color: t.accent.withOpacity(0.6), size: 14),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Predictions extrapolate actual usage to full month.',
                            style: TextStyle(color: t.textSec, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // History charts
            Container(
              padding: const EdgeInsets.all(20),
              decoration: t.cardDecoration(radius: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'History Charts',
                    style: TextStyle(
                      color: t.textPrim,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Separate charts per metric, one node at a time',
                    style: TextStyle(color: t.textSec, fontSize: 12),
                  ),
                  const SizedBox(height: 14),

                  // Node selector
                  Row(
                    children: [
                      Text(
                        'Node:',
                        style: TextStyle(color: t.textSec, fontSize: 12),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: nodes.isEmpty
                            ? Text(
                          'Loading nodes…',
                          style: TextStyle(
                              color: t.textSec, fontSize: 11),
                        )
                            : SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: nodes
                                .map(
                                  (n) => Padding(
                                padding: const EdgeInsets.only(
                                    right: 6),
                                child: GestureDetector(
                                  onTap: () => _selectNode(n),
                                  child: AnimatedContainer(
                                    duration: const Duration(
                                        milliseconds: 200),
                                    padding:
                                    const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _node == n
                                          ? t.accent
                                          .withOpacity(0.12)
                                          : t.chipFill,
                                      borderRadius:
                                      BorderRadius.circular(14),
                                      border: Border.all(
                                        color: _node == n
                                            ? t.accent.withOpacity(
                                            0.4)
                                            : t.cardBorder,
                                      ),
                                    ),
                                    child: Text(
                                      n,
                                      style: TextStyle(
                                        color: _node == n
                                            ? t.accent
                                            : t.textSec,
                                        fontSize: 11,
                                        fontWeight: _node == n
                                            ? FontWeight.w700
                                            : FontWeight.w400,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            )
                                .toList(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _load,
                        child: Icon(Icons.refresh_rounded,
                            color: t.accent, size: 18),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Window chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final e in {
                          6: '6h',
                          12: '12h',
                          24: '24h',
                          168: '1w',
                          720: '1m',
                          0: 'All'
                        }.entries)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: GestureDetector(
                              onTap: () =>
                                  setState(() => _windowHours = e.key),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: _windowHours == e.key
                                      ? t.accent.withOpacity(0.12)
                                      : t.chipFill,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: _windowHours == e.key
                                        ? t.accent.withOpacity(0.4)
                                        : t.cardBorder,
                                  ),
                                ),
                                child: Text(
                                  e.value,
                                  style: TextStyle(
                                    color: _windowHours == e.key
                                        ? t.accent
                                        : t.textSec,
                                    fontSize: 11,
                                    fontWeight: _windowHours == e.key
                                        ? FontWeight.w700
                                        : FontWeight.w400,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Readings count
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: t.accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$_node  |  ${wh.length} readings in window',
                        style: TextStyle(color: t.textSec, fontSize: 11),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (_loading)
                    SizedBox(
                      height: 180,
                      child: Center(
                        child: CircularProgressIndicator(
                          color: t.accent,
                          strokeWidth: 2,
                        ),
                      ),
                    )
                  else ...[
                    _chartSection(
                      'Power (W)',
                      const Color(0xFF7C3AED),
                      PowerLineChart(data: wh),
                    ),
                    const SizedBox(height: 12),
                    _chartSection(
                      'Voltage (V)',
                      const Color(0xFF60A5FA),
                      VoltageLineChart(data: wh),
                    ),
                    const SizedBox(height: 12),
                    _chartSection(
                      'Current (A)',
                      const Color(0xFFF472B6),
                      CurrentLineChart(data: wh),
                    ),
                    const SizedBox(height: 12),
                    _chartSection(
                      'Energy kWh',
                      const Color(0xFF34D399),
                      EnergyLineChart(data: wh),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Environmental
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: t.dark ? const Color(0xFF0D2137) : const Color(0xFFEAFAF1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: t.success.withOpacity(0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: t.success.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: NirwanaLogo(
                            size: 28,
                            accentColor: t.success,
                            glowOpacity: 0.1,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Environmental Impact',
                        style: TextStyle(
                          color: t.textPrim,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '${carbon.toStringAsFixed(2)} kg ',
                          style: TextStyle(
                            color: t.textPrim,
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        TextSpan(
                          text: 'CO₂ this month',
                          style: TextStyle(
                            color: t.success,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'India grid factor: 0.82 kg CO₂/kWh  (CEA 2023)',
                    style: TextStyle(color: t.textSec, fontSize: 11),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.park_outlined, color: t.success, size: 18),
                      Icon(Icons.park_outlined, color: t.success, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        '≈ ${(carbon / 21).toStringAsFixed(1)} trees / month',
                        style: TextStyle(
                          color: t.success,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  int _daysInMonth() =>
      DateTime(DateTime.now().year, DateTime.now().month + 1, 0).day;

  Widget _stat(String val, String unit, AppTheme t) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          val,
          style: TextStyle(
            color: t.textPrim,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(unit, style: TextStyle(color: t.textSec, fontSize: 11)),
      ],
    ),
  );

  Widget _vDiv(AppTheme t) => Container(
    width: 1,
    height: 28,
    margin: const EdgeInsets.symmetric(horizontal: 10),
    color: t.divider,
  );

  Widget _forecastTile(
      String label,
      String value,
      String sub,
      Color color,
      AppTheme t,
      ) =>
      Container(
        padding: const EdgeInsets.all(14),
        decoration: t.cardDecoration(radius: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: t.textSec, fontSize: 12)),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              sub,
              style: TextStyle(color: color.withOpacity(0.65), fontSize: 10),
              maxLines: 2,
            ),
          ],
        ),
      );

  Widget _chartSection(String title, Color color, Widget chart) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            title,
            style: TextStyle(
              color: t.textSec,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      SizedBox(height: 180, child: chart),
    ],
  );

  AppTheme get t => AppTheme.of(context);
}