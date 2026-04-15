// lib/widgets/metric_card.dart
import 'package:flutter/material.dart';
import '../models/reading.dart';
import '../utils/app_theme.dart';
import 'nirwana_logo.dart';

class MetricCard extends StatelessWidget {
  final Reading reading;
  const MetricCard({super.key, required this.reading});

  @override
  Widget build(BuildContext context) {
    final t      = AppTheme.of(context);
    final health = _score();
    final hc     = health >= 75 ? t.success : health >= 50 ? t.warning : t.error;
    final isOn   = reading.relay.toUpperCase() == 'ON';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: t.cardDecoration(radius: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Health row
        Row(children: [
          SizedBox(width: 52, height: 52,
              child: Stack(alignment: Alignment.center, children: [
                CircularProgressIndicator(
                    value: (health / 100).clamp(0.0, 1.0),
                    strokeWidth: 5,
                    valueColor: AlwaysStoppedAnimation<Color>(hc),
                    backgroundColor: t.chipFill),
                Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('$health', style: TextStyle(color: hc, fontSize: 13, fontWeight: FontWeight.w800)),
                  Text('%', style: TextStyle(color: t.textSec, fontSize: 8)),
                ]),
              ])),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(health >= 75 ? 'Healthy' : health >= 50 ? 'Fair' : 'Poor',
                style: TextStyle(color: hc, fontSize: 13, fontWeight: FontWeight.w700)),
            Text(reading.nodeid, style: TextStyle(color: t.textSec, fontSize: 11)),
          ]),
          const Spacer(),
          Row(children: [
            Container(width: 7, height: 7,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isOn ? t.success : t.textSec)),
            const SizedBox(width: 5),
            Text(isOn ? 'ON' : 'OFF',
                style: TextStyle(
                    color: isOn ? t.success : t.textSec,
                    fontSize: 11, fontWeight: FontWeight.w600)),
          ]),
        ]),
        const SizedBox(height: 12),
        Divider(color: t.divider, height: 1),
        const SizedBox(height: 12),
        // Metrics grid
        Row(children: [
          _tile(Icons.bolt_rounded, 'Voltage', '${reading.voltage.toStringAsFixed(1)} V', t),
          const SizedBox(width: 8),
          _tile(Icons.electric_meter_outlined, 'Current', '${reading.current.toStringAsFixed(3)} A', t),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          _tile(Icons.power_outlined, 'Power', '${reading.power.toStringAsFixed(1)} W', t),
          const SizedBox(width: 8),
          _tile(Icons.energy_savings_leaf_outlined, 'Energy', '${reading.energy.toStringAsFixed(3)} kWh', t),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          _tile(Icons.compress_rounded, 'Power Factor', reading.pf.toStringAsFixed(2), t),
          const SizedBox(width: 8),
          _tile(Icons.waves_outlined, 'Frequency', '${reading.frequency.toStringAsFixed(1)} Hz', t),
        ]),
      ]),
    );
  }

  int _score() {
    double s = 100;
    // Voltage: India rated 190–220 V
    if (reading.voltage < 190) s -= ((190 - reading.voltage) * 0.5).clamp(0, 30);
    else if (reading.voltage > 220) s -= ((reading.voltage - 220) * 0.5).clamp(0, 30);
    // Power factor
    if (reading.pf < 0.85) s -= ((0.85 - reading.pf) * 133).clamp(0, 20);
    // Frequency
    s -= ((reading.frequency - 50).abs() * 50).clamp(0, 15);
    if (reading.relay.toUpperCase() != 'ON') s -= 10;
    return s.clamp(0, 100).round();
  }

  Widget _tile(IconData icon, String label, String value, AppTheme t) => Expanded(
      child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(color: t.chipFill, borderRadius: BorderRadius.circular(10),
              border: Border.all(color: t.cardBorder)),
          child: Row(children: [
            Icon(icon, color: t.accent, size: 14),
            const SizedBox(width: 7),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(value, style: TextStyle(color: t.textPrim, fontSize: 12, fontWeight: FontWeight.w700)),
              Text(label, style: TextStyle(color: t.textSec, fontSize: 10)),
            ])),
          ])));
}
