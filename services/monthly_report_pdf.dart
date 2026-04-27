import 'dart:convert';
import 'dart:typed_data';

class MonthlyUsageReport {
  final String nodeId;
  final String deviceName;
  final String monthLabel;
  final double monthlyUsageKwh;
  final double predictedUsageKwh;
  final double totalRunHours;
  final double totalConsumptionKwh;
  final List<double> weeklyRunHours;

  const MonthlyUsageReport({
    required this.nodeId,
    required this.deviceName,
    required this.monthLabel,
    required this.monthlyUsageKwh,
    required this.predictedUsageKwh,
    required this.totalRunHours,
    required this.totalConsumptionKwh,
    required this.weeklyRunHours,
  });
}

Uint8List buildMonthlyUsagePdf(MonthlyUsageReport data) {
  final bars = data.weeklyRunHours.isEmpty ? [0.0, 0.0, 0.0, 0.0] : data.weeklyRunHours;
  final maxBar = bars.reduce((a, b) => a > b ? a : b).clamp(1.0, double.infinity);

  final content = StringBuffer()
    ..writeln('0.05 0.09 0.16 rg 0 0 595 842 re f')
    ..writeln('0.10 0.17 0.28 rg 32 740 531 76 re f')
    ..writeln(_text(50, 785, 24, 'NIRWANA USAGE REPORT', r: 0.88, g: 0.96, b: 1.0))
    ..writeln(_text(50, 762, 12, '${data.deviceName} (${data.nodeId})  •  ${data.monthLabel}', r: 0.69, g: 0.86, b: 0.99))
    ..writeln(_card(40, 625, 250, 102, 'Monthly Usage (kWh)', data.monthlyUsageKwh.toStringAsFixed(2), 'Actual usage this month'))
    ..writeln(_card(305, 625, 250, 102, 'Predicted Usage (kWh)', data.predictedUsageKwh.toStringAsFixed(2), 'Forecast at month end'))
    ..writeln(_card(40, 510, 250, 102, 'Total Run Time (Hours)', data.totalRunHours.toStringAsFixed(1), 'Run time in this month'))
    ..writeln(_card(305, 510, 250, 102, 'Total Consumption (kWh)', data.totalConsumptionKwh.toStringAsFixed(2), 'Lifetime cumulative energy'))
    ..writeln('0.09 0.15 0.24 rg 40 220 515 265 re f')
    ..writeln(_text(55, 465, 16, 'Weekly Device Runtime (Hours)', r: 0.78, g: 0.91, b: 1.0));

  const chartX = 62.0;
  const chartY = 255.0;
  const chartW = 470.0;
  const chartH = 165.0;
  content.writeln('0.20 0.30 0.46 RG 1 w $chartX $chartY $chartW $chartH re S');

  final barCount = bars.length;
  final gap = 16.0;
  final totalGap = gap * (barCount + 1);
  final barWidth = (chartW - totalGap) / barCount;

  for (var i = 0; i < barCount; i++) {
    final h = (bars[i] / maxBar) * (chartH - 28);
    final x = chartX + gap + (i * (barWidth + gap));
    final y = chartY + 10;
    final weekLabel = 'W${i + 1}';
    content
      ..writeln('0.00 0.85 1.00 rg $x $y $barWidth ${h.toStringAsFixed(2)} re f')
      ..writeln(_text(x + 2, chartY - 16, 11, weekLabel, r: 0.70, g: 0.84, b: 0.97))
      ..writeln(_text(x, y + h + 8, 10, '${bars[i].toStringAsFixed(1)}h', r: 0.70, g: 0.84, b: 0.97));
  }

  content
    ..writeln(_text(40, 180, 10,
        'This report includes monthly node usage, actual vs predicted consumption, runtime analytics, and total kWh usage.',
        r: 0.63, g: 0.77, b: 0.91))
    ..writeln(_text(40, 164, 10,
        'Generated automatically by Nirwana Usage Report.',
        r: 0.48, g: 0.63, b: 0.80));

  return _buildPdf(content.toString());
}

String _card(double x, double y, double w, double h, String title, String value, String subtitle) {
  final b = StringBuffer()
    ..writeln('0.08 0.13 0.21 rg $x $y $w $h re f')
    ..writeln('0.00 0.86 1.00 RG 1.2 w $x $y $w $h re S')
    ..writeln(_text(x + 14, y + h - 24, 11, title, r: 0.66, g: 0.83, b: 0.97))
    ..writeln(_text(x + 14, y + h - 58, 28, value, r: 0.88, g: 0.98, b: 1.0))
    ..writeln(_text(x + 14, y + 16, 10, subtitle, r: 0.49, g: 0.67, b: 0.83));
  return b.toString();
}

String _text(double x, double y, double size, String text,
    {double r = 1, double g = 1, double b = 1}) {
  final safe = text
      .replaceAll('\\', '\\\\')
      .replaceAll('(', r'\(')
      .replaceAll(')', r'\)');
  return '$r $g $b rg BT /F1 $size Tf $x $y Td ($safe) Tj ET';
}

Uint8List _buildPdf(String stream) {
  final objects = <String>[
    '<< /Type /Catalog /Pages 2 0 R >>',
    '<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Resources << /Font << /F1 5 0 R >> >> /Contents 4 0 R >>',
    '<< /Length ${utf8.encode(stream).length} >>\nstream\n$stream\nendstream',
    '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
  ];

  final pdf = StringBuffer('%PDF-1.4\n');
  final offsets = <int>[0];

  for (var i = 0; i < objects.length; i++) {
    offsets.add(utf8.encode(pdf.toString()).length);
    pdf.writeln('${i + 1} 0 obj');
    pdf.writeln(objects[i]);
    pdf.writeln('endobj');
  }

  final xrefOffset = utf8.encode(pdf.toString()).length;
  pdf.writeln('xref');
  pdf.writeln('0 ${objects.length + 1}');
  pdf.writeln('0000000000 65535 f ');
  for (var i = 1; i < offsets.length; i++) {
    pdf.writeln('${offsets[i].toString().padLeft(10, '0')} 00000 n ');
  }
  pdf.writeln('trailer << /Size ${objects.length + 1} /Root 1 0 R >>');
  pdf.writeln('startxref');
  pdf.writeln(xrefOffset);
  pdf.writeln('%%EOF');

  return Uint8List.fromList(utf8.encode(pdf.toString()));
}
