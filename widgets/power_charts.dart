// lib/widgets/power_charts.dart
//
// Line charts that mirror the web dashboard's Chart.js behaviour:
//   • X-axis: DateTime from reading.created (proper ISO timestamps)
//   • Smooth bezier curve, filled area, no point dots
//   • Auto-scaling Y axis
//   • Falls back to a demo sparkline when data is empty

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/reading.dart';

// ─── Public chart widgets ─────────────────────────────────────────────────────

class PowerLineChart extends StatelessWidget {
  final List<Reading> data;
  const PowerLineChart({super.key, required this.data});
  @override
  Widget build(BuildContext context) =>
      _LineChart(points: data.map((r) => _P(r.created, r.power)).toList(),
          color: const Color(0xFF7C3AED), label: 'W');
}

class VoltageLineChart extends StatelessWidget {
  final List<Reading> data;
  const VoltageLineChart({super.key, required this.data});
  @override
  Widget build(BuildContext context) =>
      _LineChart(points: data.map((r) => _P(r.created, r.voltage)).toList(),
          color: const Color(0xFF60A5FA), label: 'V');
}

class CurrentLineChart extends StatelessWidget {
  final List<Reading> data;
  const CurrentLineChart({super.key, required this.data});
  @override
  Widget build(BuildContext context) =>
      _LineChart(points: data.map((r) => _P(r.created, r.current)).toList(),
          color: const Color(0xFFF472B6), label: 'A');
}

class EnergyLineChart extends StatelessWidget {
  final List<Reading> data;
  const EnergyLineChart({super.key, required this.data});
  @override
  Widget build(BuildContext context) =>
      _LineChart(points: data.map((r) => _P(r.created, r.energy)).toList(),
          color: const Color(0xFF34D399), label: 'kWh');
}

// ─── Internal data point ──────────────────────────────────────────────────────

class _P {
  final DateTime t;
  final double y;
  const _P(this.t, this.y);
  double get x => t.millisecondsSinceEpoch.toDouble();
}

// ─── Core chart widget ────────────────────────────────────────────────────────

class _LineChart extends StatelessWidget {
  final List<_P> points;
  final Color    color;
  final String   label;

  const _LineChart({required this.points, required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (points.isEmpty) {
      return _EmptyChart(color: color, isDark: isDark);
    }
    return LayoutBuilder(builder: (_, constraints) {
      return Stack(children: [
        CustomPaint(
          size: Size(constraints.maxWidth, constraints.maxHeight),
          painter: _ChartPainter(points: points, color: color, isDark: isDark),
        ),
        // Y-axis labels (right side)
        Positioned(
          top: 0, right: 0, bottom: 18,
          child: _YAxis(points: points, color: color, isDark: isDark),
        ),
        // X-axis labels (bottom)
        Positioned(
          bottom: 0, left: 0, right: 0, height: 18,
          child: _XAxis(points: points, isDark: isDark),
        ),
      ]);
    });
  }
}

// ─── Chart Painter ────────────────────────────────────────────────────────────

class _ChartPainter extends CustomPainter {
  final List<_P> points;
  final Color    color;
  final bool     isDark;

  const _ChartPainter({required this.points, required this.color, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    const lPad = 4.0;
    const rPad = 44.0; // space for Y labels
    const tPad = 6.0;
    const bPad = 20.0; // space for X labels

    final w = size.width  - lPad - rPad;
    final h = size.height - tPad - bPad;
    if (w <= 0 || h <= 0) return;

    final minX = points.map((p) => p.x).reduce(math.min);
    final maxX = points.map((p) => p.x).reduce(math.max);
    final rawMinY = points.map((p) => p.y).reduce(math.min);
    final rawMaxY = points.map((p) => p.y).reduce(math.max);
    final rangeX  = (maxX - minX).abs() < 1 ? 1.0 : maxX - minX;
    // Add 10% padding to Y range so the line doesn't hug the edges
    final yPad    = (rawMaxY - rawMinY) * 0.1;
    final minY    = rawMinY - yPad;
    final maxY    = rawMaxY + yPad + 1e-9;
    final rangeY  = maxY - minY;

    Offset toCanvas(_P p) => Offset(
      lPad + (p.x - minX) / rangeX * w,
      tPad + h - (p.y - minY) / rangeY * h,
    );

    final pts = points.map(toCanvas).toList();

    // ── Grid lines ──────────────────────────────────────────────────────────
    final gridPaint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withOpacity(0.05)
      ..strokeWidth = 1;
    for (int i = 0; i <= 4; i++) {
      final y = tPad + h * (1 - i / 4);
      canvas.drawLine(Offset(lPad, y), Offset(lPad + w, y), gridPaint);
    }

    // ── Fill ────────────────────────────────────────────────────────────────
    final fillPath = Path()
      ..moveTo(pts.first.dx, tPad + h)
      ..lineTo(pts.first.dx, pts.first.dy);
    for (int i = 1; i < pts.length; i++) {
      final cp = (pts[i - 1].dx + pts[i].dx) / 2;
      fillPath.cubicTo(cp, pts[i - 1].dy, cp, pts[i].dy, pts[i].dx, pts[i].dy);
    }
    fillPath.lineTo(pts.last.dx, tPad + h);
    fillPath.close();

    canvas.drawPath(fillPath, Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [color.withOpacity(0.18), color.withOpacity(0.0)],
      ).createShader(Rect.fromLTWH(0, tPad, size.width, h))
      ..style = PaintingStyle.fill);

    // ── Line ────────────────────────────────────────────────────────────────
    final linePath = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (int i = 1; i < pts.length; i++) {
      final cp = (pts[i - 1].dx + pts[i].dx) / 2;
      linePath.cubicTo(cp, pts[i - 1].dy, cp, pts[i].dy, pts[i].dx, pts[i].dy);
    }
    canvas.drawPath(linePath, Paint()
      ..color        = color
      ..style        = PaintingStyle.stroke
      ..strokeWidth  = 2.0
      ..strokeCap    = StrokeCap.round
      ..strokeJoin   = StrokeJoin.round);

    // ── Last-point glow dot ─────────────────────────────────────────────────
    canvas.drawCircle(pts.last, 5, Paint()..color = color.withOpacity(0.25));
    canvas.drawCircle(pts.last, 3, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _ChartPainter old) =>
      old.points != points || old.color != color;
}

// ─── Y-axis labels ────────────────────────────────────────────────────────────

class _YAxis extends StatelessWidget {
  final List<_P> points;
  final Color    color;
  final bool     isDark;

  const _YAxis({required this.points, required this.color, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final minY = points.map((p) => p.y).reduce(math.min);
    final maxY = points.map((p) => p.y).reduce(math.max);
    final range = (maxY - minY).abs() < 1e-9 ? 1.0 : maxY - minY;

    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(5, (i) {
        final val = maxY - (range * i / 4);
        return Text(
          _fmt(val),
          style: TextStyle(
            color: (isDark ? Colors.white : Colors.black).withOpacity(0.3),
            fontSize: 9,
          ),
        );
      }),
    );
  }

  static String _fmt(double v) {
    if (v.abs() >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    if (v.abs() >= 1)    return v.toStringAsFixed(1);
    return v.toStringAsFixed(3);
  }
}

// ─── X-axis labels ────────────────────────────────────────────────────────────

class _XAxis extends StatelessWidget {
  final List<_P> points;
  final bool     isDark;

  const _XAxis({required this.points, required this.isDark});

  @override
  Widget build(BuildContext context) {
    const n = 4;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(n + 1, (i) {
        final idx = (i / n * (points.length - 1)).round().clamp(0, points.length - 1);
        final dt  = points[idx].t.toLocal();
        return Text(
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}',
          style: TextStyle(
            color: (isDark ? Colors.white : Colors.black).withOpacity(0.25),
            fontSize: 9,
          ),
        );
      }),
    );
  }
}

// ─── Empty / demo chart ───────────────────────────────────────────────────────

class _EmptyChart extends StatelessWidget {
  final Color color;
  final bool  isDark;

  const _EmptyChart({required this.color, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DemoPainter(color: color, isDark: isDark),
    );
  }
}

class _DemoPainter extends CustomPainter {
  final Color color;
  final bool  isDark;

  const _DemoPainter({required this.color, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final rand = math.Random(color.hashCode);
    const n    = 20;
    final pts  = List.generate(n, (i) => Offset(
      size.width * i / (n - 1),
      size.height * (0.15 + rand.nextDouble() * 0.65),
    ));

    final fill = Path()..moveTo(pts.first.dx, size.height)..lineTo(pts.first.dx, pts.first.dy);
    for (int i = 1; i < pts.length; i++) {
      final cp = (pts[i - 1].dx + pts[i].dx) / 2;
      fill.cubicTo(cp, pts[i - 1].dy, cp, pts[i].dy, pts[i].dx, pts[i].dy);
    }
    fill..lineTo(pts.last.dx, size.height)..close();

    canvas.drawPath(fill, Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [color.withOpacity(0.1), color.withOpacity(0.0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill);

    final line = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (int i = 1; i < pts.length; i++) {
      final cp = (pts[i - 1].dx + pts[i].dx) / 2;
      line.cubicTo(cp, pts[i - 1].dy, cp, pts[i].dy, pts[i].dx, pts[i].dy);
    }
    canvas.drawPath(line, Paint()
      ..color       = color.withOpacity(0.35)
      ..style       = PaintingStyle.stroke
      ..strokeWidth = 1.5);

    final tp = TextPainter(
        text: TextSpan(text: 'No data yet',
            style: TextStyle(color: (isDark ? Colors.white : Colors.black).withOpacity(0.2), fontSize: 11)),
        textDirection: TextDirection.ltr)..layout();
    tp.paint(canvas, Offset((size.width - tp.width) / 2, (size.height - tp.height) / 2));
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

// ─── PowerDonut (health ring used in DashboardScreen) ────────────────────────

class PowerDonut extends StatelessWidget {
  final int health; // 0-100

  const PowerDonut({super.key, required this.health});

  @override
  Widget build(BuildContext context) {
    Color hc;
    String label;
    if (health >= 75) { hc = const Color(0xFF22C55E); label = 'Good'; }
    else if (health >= 50) { hc = const Color(0xFFF59E0B); label = 'Fair'; }
    else { hc = const Color(0xFFEF4444); label = 'Poor'; }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(alignment: Alignment.center, children: [
      CircularProgressIndicator(
        value: (health / 100).clamp(0.0, 1.0),
        strokeWidth: 7,
        valueColor: AlwaysStoppedAnimation<Color>(hc),
        backgroundColor: (isDark ? Colors.white : Colors.black).withOpacity(0.06),
      ),
      Column(mainAxisSize: MainAxisSize.min, children: [
        Text('$health%', style: TextStyle(color: hc, fontSize: 13, fontWeight: FontWeight.w800)),
        Text(label, style: TextStyle(
            color: (isDark ? Colors.white : Colors.black).withOpacity(0.35), fontSize: 8)),
      ]),
    ]);
  }
}
