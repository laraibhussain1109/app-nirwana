// lib/screens/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../widgets/rate_settings_dialog.dart';
import '../utils/app_theme.dart';
import '../widgets/nirwana_logo.dart';
import 'login_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t    = AppTheme.of(context);
    final api  = Provider.of<ApiService>(context);
    final kWh  = api.getMonthlyEnergyKwh();
    final bill = api.getEstimatedBill();
    final rate = api.ratePerUnit;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── Profile card ──────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: t.dark
                        ? [const Color(0xFF0D2137), const Color(0xFF091828)]
                        : [const Color(0xFFE8F7FB), const Color(0xFFF0FAFE)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: t.accent.withOpacity(0.15))),
            child: Row(children: [
              NirwanaLogo(size: 60, accentColor: t.accent, glowOpacity: 0.15),
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text('NirwanaGrid', style: TextStyle(
                      color: t.textPrim, fontSize: 17, fontWeight: FontWeight.w800)),
                  const Spacer(),
                  Container(width: 32, height: 32,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: t.chipFill),
                      child: Icon(Icons.edit_outlined, color: t.iconSec, size: 16)),
                ]),
                const SizedBox(height: 2),
                Text('admin@nirwanagrid.com', style: TextStyle(color: t.textSec, fontSize: 12)),
                const SizedBox(height: 4),
                Row(children: [
                  Icon(Icons.location_on_outlined, color: t.textSec, size: 12),
                  const SizedBox(width: 3),
                  Text('India', style: TextStyle(color: t.textSec, fontSize: 11)),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  _badge('Pro Plan', t.warning, t),
                  const SizedBox(width: 8),
                  _badge('Verified', t.success, t),
                ]),
              ])),
            ]),
          ),
          const SizedBox(height: 16),

          // ── Stats strip ───────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            decoration: t.cardDecoration(radius: 16),
            child: Row(children: [
              _statCell('${api.getKnownNodes().length}', 'Devices', t),
              _vDiv(t),
              _statCell('${kWh.toStringAsFixed(1)}', 'kWh/mo', t),
              _vDiv(t),
              _statCell('₹${bill.toStringAsFixed(0)}', 'Est. bill', t),
              _vDiv(t),
              _statCell('${api.getCarbonKg().toStringAsFixed(1)}kg', 'CO₂', t),
            ]),
          ),
          const SizedBox(height: 16),

          // ── Electricity rate ──────────────────────────────────────────────
          GestureDetector(
            onTap: () => showRateSettingsDialog(context),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: t.cardDecoration(radius: 16),
              child: Row(children: [
                Container(width: 40, height: 40,
                    decoration: BoxDecoration(color: t.accent.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                    child: Icon(Icons.electric_bolt_rounded, color: t.accent, size: 20)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Electricity Rate', style: TextStyle(
                      color: t.textPrim, fontSize: 14, fontWeight: FontWeight.w700)),
                  Text('₹${rate.toStringAsFixed(2)} per kWh  •  tap to change',
                      style: TextStyle(color: t.textSec, fontSize: 12)),
                ])),
                Icon(Icons.chevron_right_rounded, color: t.iconSec, size: 20),
              ]),
            ),
          ),
          const SizedBox(height: 16),

          // ── Activity Log ──────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: t.cardDecoration(radius: 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text('Schedule Log', style: TextStyle(
                    color: t.textPrim, fontSize: 15, fontWeight: FontWeight.w700)),
                const Spacer(),
                Text('Executed on server', style: TextStyle(color: t.accent, fontSize: 12, fontWeight: FontWeight.w600)),
              ]),
              const SizedBox(height: 12),
              ...api.getExecutedSchedules().take(5).map((s) => _scheduleLogItem(s, t)).toList(),
              if (api.getExecutedSchedules().isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.schedule_outlined, color: t.iconSec, size: 20),
                    const SizedBox(width: 8),
                    Text('No executed schedules yet', style: TextStyle(color: t.textSec, fontSize: 13)),
                  ]),
                ),
            ]),
          ),
          const SizedBox(height: 16),

          // ── Quick Links ───────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: t.cardDecoration(radius: 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Quick Links', style: TextStyle(color: t.textPrim, fontSize: 15, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              _quickLink(context, Icons.settings_outlined, 'Settings',
                  'Electricity rate & preferences', t,
                  onTap: () => showRateSettingsDialog(context)),
              Divider(color: t.divider, height: 1),
              ComingSoon(child: _quickLink(context, Icons.notifications_outlined, 'Notifications', null, t)),
              Divider(color: t.divider, height: 1),
              ComingSoon(child: _quickLink(context, Icons.lock_outline_rounded, 'Privacy & Security', null, t)),
              Divider(color: t.divider, height: 1),
              ComingSoon(child: _quickLink(context, Icons.power_settings_new_rounded, 'Device Auto-Off', null, t)),
            ]),
          ),
          const SizedBox(height: 16),

          // ── Sign Out ──────────────────────────────────────────────────────
          GestureDetector(
            onTap: () async {
              await Provider.of<ApiService>(context, listen: false).clearSession();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
              }
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                  color: t.error.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: t.error.withOpacity(0.3))),
              child: Center(child: Text('Sign Out',
                  style: TextStyle(color: t.error, fontSize: 14, fontWeight: FontWeight.w700))),
            ),
          ),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }

  static Widget _badge(String label, Color color, AppTheme t) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.3))),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)));

  static Widget _statCell(String val, String label, AppTheme t) => Expanded(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(val, style: TextStyle(color: t.textPrim, fontSize: 13, fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(color: t.textSec, fontSize: 10)),
      ]));

  static Widget _vDiv(AppTheme t) => Container(
      width: 1, height: 32, color: t.divider);

  static Widget _scheduleLogItem(ServerSchedule s, AppTheme t) {
    final at = s.executeAt.toLocal();
    final isOn = s.relay.toUpperCase() == 'ON';
    final color = isOn ? t.accent : t.warning;
    return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          Container(width: 32, height: 32,
              decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
              child: Icon(isOn ? Icons.power_settings_new_rounded : Icons.power_off_outlined,
                  color: color, size: 15)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${s.nodeId}  →  Turn ${s.relay}',
                style: TextStyle(color: t.textPrim, fontSize: 13, fontWeight: FontWeight.w600)),
            Text(
                '${at.day.toString().padLeft(2,'0')}/${at.month.toString().padLeft(2,'0')}/${at.year}  '
                    '${at.hour.toString().padLeft(2,'0')}:${at.minute.toString().padLeft(2,'0')}',
                style: TextStyle(color: t.textSec, fontSize: 11)),
          ])),
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(color: t.success.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
              child: Text('Done', style: TextStyle(color: t.success, fontSize: 10, fontWeight: FontWeight.w600))),
        ]));
  }

  static Widget _quickLink(BuildContext context, IconData icon, String title, String? sub,
      AppTheme t, {VoidCallback? onTap}) =>
      GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(children: [
              Container(width: 36, height: 36,
                  decoration: BoxDecoration(color: t.chipFill, borderRadius: BorderRadius.circular(10)),
                  child: Icon(icon, color: t.iconSec, size: 18)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: TextStyle(color: t.textPrim, fontSize: 13, fontWeight: FontWeight.w600)),
                if (sub != null) Text(sub, style: TextStyle(color: t.textSec, fontSize: 11)),
              ])),
              Icon(Icons.chevron_right_rounded, color: t.iconSec, size: 18),
            ]),
          ));
}
