// lib/widgets/schedule_dialog.dart
//
// Mirrors web dashboard schedule behaviour:
//   • Shows ALL schedules for a node (PENDING + EXECUTED + CANCELLED)
//   • "Cancel" button on each tile (not delete icon)
//   • Warns before attempting to cancel a non-PENDING schedule
//   • Status pills: PENDING=yellow, EXECUTED=green, CANCELLED=red
//   • Race-condition guard: disables button while in flight

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../utils/app_theme.dart';

void showScheduleDialog(BuildContext context, String nodeId) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ScheduleSheet(nodeId: nodeId),
  );
}

class _ScheduleSheet extends StatefulWidget {
  final String nodeId;
  const _ScheduleSheet({required this.nodeId});
  @override
  State<_ScheduleSheet> createState() => _ScheduleSheetState();
}

class _ScheduleSheetState extends State<_ScheduleSheet> {
  bool            _posting    = false;
  final Map<int, bool> _cancelling = {};

  @override
  Widget build(BuildContext context) {
    final t         = AppTheme.of(context);
    final api       = Provider.of<ApiService>(context);
    final schedules = api.getSchedulesForNode(widget.nodeId);
    final display   = api.getDisplayName(widget.nodeId);

    return Container(
        decoration: BoxDecoration(
            color: t.card,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28))),
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Handle
          Padding(padding: const EdgeInsets.only(top: 12, bottom: 6),
              child: Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: t.divider, borderRadius: BorderRadius.circular(2)))),

          // Header
          Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Row(children: [
                Container(width: 40, height: 40,
                    decoration: BoxDecoration(color: t.accent.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                    child: Icon(Icons.schedule_rounded, color: t.accent, size: 20)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(display, style: TextStyle(color: t.textPrim, fontSize: 16, fontWeight: FontWeight.w700)),
                  Text('${schedules.length} schedule${schedules.length != 1 ? 's' : ''}',
                      style: TextStyle(color: t.textSec, fontSize: 11)),
                ])),
              ])),
          const SizedBox(height: 12),
          Divider(color: t.divider, height: 1),

          // List
          if (schedules.isEmpty)
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 28),
                child: Column(children: [
                  Icon(Icons.schedule_outlined, color: t.textSec, size: 36),
                  const SizedBox(height: 10),
                  Text('No schedules yet', style: TextStyle(color: t.textSec, fontSize: 13)),
                ]))
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                itemCount: schedules.length,
                itemBuilder: (_, i) => _ScheduleTile(
                  schedule:    schedules[i],
                  t:           t,
                  isCancelling: _cancelling[schedules[i].id] ?? false,
                  onCancel:    () => _handleCancel(context, api, schedules[i]),
                ),
              ),
            ),

          const SizedBox(height: 14),

          // Add buttons
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                Expanded(child: _addBtn('Schedule ON',  t.accent,                Icons.power_settings_new_rounded, 'ON',  t)),
                const SizedBox(width: 10),
                Expanded(child: _addBtn('Schedule OFF', const Color(0xFFFF9800), Icons.power_off_outlined,         'OFF', t)),
              ])),
        ]));
  }

  // ── Cancel handler ────────────────────────────────────────────────────────

  Future<void> _handleCancel(BuildContext ctx, ApiService api, ServerSchedule s) async {
    // Warn if not PENDING — mirrors web dashboard behaviour
    if (!s.isPending) {
      final label = s.isExecuted ? 'executed' : 'cancelled';
      final proceed = await showDialog<bool>(
          context: ctx,
          builder: (d) {
            final t = AppTheme.of(ctx);
            return AlertDialog(
              backgroundColor: t.card,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(children: [
                Icon(Icons.warning_amber_rounded, color: t.warning, size: 22),
                const SizedBox(width: 8),
                Expanded(child: Text('Already $label',
                    style: TextStyle(color: t.textPrim, fontSize: 16, fontWeight: FontWeight.w700))),
              ]),
              content: Text(
                  'This schedule has already been $label.\n'
                      'The server will respond: "only pending schedules can be cancelled"\n\n'
                      'Try anyway?',
                  style: TextStyle(color: t.textSec, fontSize: 13, height: 1.5)),
              actions: [
                TextButton(onPressed: () => Navigator.pop(d, false),
                    child: Text('Go back', style: TextStyle(color: t.textSec))),
                ElevatedButton(
                    onPressed: () => Navigator.pop(d, true),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: t.warning, foregroundColor: Colors.white),
                    child: const Text('Try anyway')),
              ],
            );
          });
      if (proceed != true) return;
    }

    // Race guard
    if (_cancelling[s.id] == true) return;
    setState(() => _cancelling[s.id] = true);

    try {
      final error = await api.cancelSchedule(s.id);
      if (!mounted) return;
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: const Color(0xFFDC2626),
          content: Row(children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(error, style: const TextStyle(color: Colors.white))),
          ]),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } finally {
      if (mounted) setState(() => _cancelling.remove(s.id));
    }
  }

  // ── Add schedule button ───────────────────────────────────────────────────

  Widget _addBtn(String label, Color color, IconData icon, String action, AppTheme t) =>
      GestureDetector(
          onTap: _posting ? null : () => _showAddDialog(action, color, t),
          child: Container(
              padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(
                  color: _posting ? t.chipFill : color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _posting ? t.cardBorder : color.withOpacity(0.3))),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(icon, color: _posting ? t.textSec : color, size: 16),
                const SizedBox(width: 6),
                Text(label, style: TextStyle(
                    color: _posting ? t.textSec : color,
                    fontSize: 13, fontWeight: FontWeight.w700)),
              ])));

  Future<void> _showAddDialog(String action, Color color, AppTheme t) async {
    TimeOfDay? time;
    int delayMin = 30;
    bool isAbsolute = true;
    bool localPosting = false;

    await showDialog(
        context: context,
        builder: (dCtx) => StatefulBuilder(builder: (dCtx, setS) => AlertDialog(
          backgroundColor: t.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Schedule Turn $action',
              style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 16)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            // Type selector
            Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: t.chipFill, borderRadius: BorderRadius.circular(10)),
                child: Row(children: [
                  _typeTab('Specific Time', isAbsolute, color, t, () => setS(() => isAbsolute = true)),
                  _typeTab('After Delay',  !isAbsolute, color, t, () => setS(() => isAbsolute = false)),
                ])),
            const SizedBox(height: 16),

            if (isAbsolute)
              GestureDetector(
                  onTap: () async {
                    final p = await showTimePicker(context: dCtx, initialTime: TimeOfDay.now());
                    if (p != null) setS(() => time = p);
                  },
                  child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                          color: t.inputFill, borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: t.cardBorder)),
                      child: Row(children: [
                        Icon(Icons.access_time_rounded, color: t.accent, size: 20),
                        const SizedBox(width: 10),
                        Text(
                            time != null
                                ? '${time!.hour.toString().padLeft(2,'0')}:${time!.minute.toString().padLeft(2,'0')}'
                                : 'Tap to select time',
                            style: TextStyle(color: time != null ? t.textPrim : t.textSec, fontSize: 15)),
                      ])))
            else ...[
              Text('Delay: $delayMin minutes', style: TextStyle(color: t.textPrim, fontWeight: FontWeight.w600)),
              Slider(value: delayMin.toDouble(), min: 5, max: 480, divisions: 95, activeColor: t.accent,
                  onChanged: (v) => setS(() => delayMin = v.round())),
            ],
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dCtx),
                child: Text('Cancel', style: TextStyle(color: t.textSec))),
            ElevatedButton(
              onPressed: (localPosting || (isAbsolute && time == null)) ? null : () async {
                setS(() => localPosting = true);
                setState(() => _posting = true);

                DateTime runAt;
                if (isAbsolute) {
                  final now = DateTime.now();
                  runAt = DateTime(now.year, now.month, now.day, time!.hour, time!.minute);
                  if (runAt.isBefore(now)) runAt = runAt.add(const Duration(days: 1));
                } else {
                  runAt = DateTime.now().add(Duration(minutes: delayMin));
                }

                final api = Provider.of<ApiService>(context, listen: false);
                final s   = await api.postSchedule(
                    nodeId: widget.nodeId, action: action, executeAt: runAt);

                Navigator.pop(dCtx);
                if (mounted) setState(() => _posting = false);
                if (!mounted) return;

                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  backgroundColor: t.card,
                  content: Row(children: [
                    Icon(s != null ? Icons.check_circle_outline_rounded : Icons.error_outline_rounded,
                        color: s != null ? t.success : t.error, size: 18),
                    const SizedBox(width: 8),
                    Text(s != null ? 'Schedule saved ✓' : 'Failed — check server logs',
                        style: TextStyle(color: t.textPrim)),
                  ]),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ));
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: color, foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: localPosting
                  ? const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Confirm', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        )));
  }

  Widget _typeTab(String label, bool active, Color c, AppTheme t, VoidCallback onTap) =>
      Expanded(child: GestureDetector(
          onTap: onTap,
          child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                  color: active ? c.withOpacity(0.15) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8)),
              child: Center(child: Text(label, style: TextStyle(
                  color: active ? c : t.textSec,
                  fontSize: 12, fontWeight: active ? FontWeight.w700 : FontWeight.w400))))));
}

// ─── Schedule Tile ─────────────────────────────────────────────────────────────

class _ScheduleTile extends StatelessWidget {
  final ServerSchedule schedule;
  final AppTheme       t;
  final bool           isCancelling;
  final VoidCallback   onCancel;

  const _ScheduleTile({
    required this.schedule, required this.t,
    required this.isCancelling, required this.onCancel,
  });

  Color get _statusColor {
    switch (schedule.status) {
      case ScheduleStatus.executed:  return const Color(0xFF22C55E); // green
      case ScheduleStatus.cancelled: return const Color(0xFFEF4444); // red
      case ScheduleStatus.pending:   return const Color(0xFFF59E0B); // yellow
    }
  }

  String get _statusLabel {
    switch (schedule.status) {
      case ScheduleStatus.executed:  return 'Executed';
      case ScheduleStatus.cancelled: return 'Cancelled';
      case ScheduleStatus.pending:   return 'Pending';
    }
  }

  IconData get _statusIcon {
    switch (schedule.status) {
      case ScheduleStatus.executed:  return Icons.check_circle_outline_rounded;
      case ScheduleStatus.cancelled: return Icons.cancel_outlined;
      case ScheduleStatus.pending:   return Icons.pending_outlined;
    }
  }

  Color get _actionColor =>
      schedule.action.toUpperCase() == 'ON' ? t.accent : const Color(0xFFFF9800);

  @override
  Widget build(BuildContext context) {
    final at = schedule.executeAt.toLocal();
    return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        decoration: BoxDecoration(
            color: _statusColor.withOpacity(0.04),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _statusColor.withOpacity(0.22))),
        child: Row(children: [
          // Status dot
          Container(width: 8, height: 8,
              decoration: BoxDecoration(shape: BoxShape.circle, color: _statusColor)),
          const SizedBox(width: 10),

          // Info
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text('Turn ${schedule.action}',
                  style: TextStyle(color: _actionColor, fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(width: 8),
              // Status pill
              Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                      color: _statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(_statusIcon, color: _statusColor, size: 10),
                    const SizedBox(width: 3),
                    Text(_statusLabel, style: TextStyle(
                        color: _statusColor, fontSize: 10, fontWeight: FontWeight.w600)),
                  ])),
            ]),
            const SizedBox(height: 3),
            Text(
                '${at.day.toString().padLeft(2,'0')}/${at.month.toString().padLeft(2,'0')}/${at.year}'
                    '  ${at.hour.toString().padLeft(2,'0')}:${at.minute.toString().padLeft(2,'0')}',
                style: TextStyle(color: t.textSec, fontSize: 11)),
          ])),

          // Cancel button
          isCancelling
              ? SizedBox(width: 20, height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: t.error))
              : TextButton(
              onPressed: onCancel,
              style: TextButton.styleFrom(
                  foregroundColor: t.error,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  side: BorderSide(color: t.error.withOpacity(0.3)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              child: const Text('Cancel', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700))),
        ]));
  }
}
