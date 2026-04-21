// lib/screens/devices_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../models/reading.dart';
import '../widgets/app_header.dart';
import '../utils/app_theme.dart';
import '../widgets/nirwana_logo.dart';
import 'dashboard_screen.dart';

class DevicesScreen extends StatelessWidget {
  const DevicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t     = AppTheme.of(context);
    final api   = Provider.of<ApiService>(context);
    final nodes = api.getKnownNodes()..sort();

    return SafeArea(
      child: Column(children: [
        const Padding(padding: EdgeInsets.fromLTRB(16, 12, 16, 0), child: AppHeader()),
        const SizedBox(height: 20),
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(alignment: Alignment.centerLeft,
                child: Text('Devices', style: TextStyle(
                    color: t.textPrim, fontSize: 22, fontWeight: FontWeight.w800)))),
        const SizedBox(height: 16),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            itemCount: nodes.length,
            separatorBuilder: (_, __) => Divider(color: t.divider, height: 1),
            itemBuilder: (ctx, i) {
              final id = nodes[i];
              return _DeviceListTile(
                nodeId: id,
                displayName: api.getDisplayName(id),
                reading: api.latest[id],
                t: t,
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => DashboardScreen(nodeId: id))),
                onToggle: (d) => api.controlNode(id, d),
              );
            },
          ),
        ),
      ]),
    );
  }
}

class _DeviceListTile extends StatefulWidget {
  final String nodeId, displayName;
  final Reading? reading;
  final AppTheme t;
  final VoidCallback onTap;
  final Future<bool> Function(String) onToggle;

  const _DeviceListTile({
    required this.nodeId, required this.displayName, required this.reading,
    required this.t, required this.onTap, required this.onToggle,
  });

  @override
  State<_DeviceListTile> createState() => _DeviceListTileState();
}

class _DeviceListTileState extends State<_DeviceListTile> {
  bool? _localOn;
  bool  _loading = false;

  @override
  void initState() { super.initState(); _sync(); }
  @override
  void didUpdateWidget(covariant _DeviceListTile old) { super.didUpdateWidget(old); _sync(); }
  void _sync() => _localOn = (widget.reading?.relay ?? 'OFF').toUpperCase() == 'ON';

  bool get _isOnline {
    final r = widget.reading;
    if (r == null) return false;
    if (r.relay.toUpperCase() != 'ON') return false;
    return DateTime.now().toUtc().difference(r.created.toUtc()).abs().inMinutes <= 5;
  }

  Future<void> _toggle(bool v) async {
    setState(() { _loading = true; _localOn = v; });
    final ok = await widget.onToggle(v ? 'ON' : 'OFF');
    if (!ok && mounted) setState(() => _localOn = !v);
    if (mounted) setState(() => _loading = false);
  }

  IconData _icon() => ApiService.getDeviceIcon(
    widget.displayName,
    widget.reading?.power ?? 0,
    widget.reading?.relay ?? 'OFF',
  );

  @override
  Widget build(BuildContext context) {
    final t    = widget.t;
    final isOn = _localOn ?? false;
    final pw   = widget.reading?.power ?? 0;

    return GestureDetector(
      onTap: widget.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(children: [
          Container(width: 44, height: 44,
              decoration: BoxDecoration(color: t.chipFill, borderRadius: BorderRadius.circular(12)),
              child: Icon(_icon(), color: t.iconSec, size: 22)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.displayName,
                style: TextStyle(color: t.textPrim, fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text('${(pw / 1000).toStringAsFixed(2)} kW',
                style: TextStyle(color: t.textSec, fontSize: 12)),
          ])),
          _loading
              ? SizedBox(width: 20, height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: t.accent))
              : Switch(
            value: isOn,
            onChanged: _toggle,
            thumbColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected)
                ? (t.dark ? const Color(0xFF0A1628) : Colors.white)
                : Colors.grey),
            trackColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? t.accent : Colors.grey.withOpacity(0.3)),
          ),
        ]),
      ),
    );
  }
}
