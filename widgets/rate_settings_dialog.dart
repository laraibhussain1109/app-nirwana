// lib/widgets/rate_settings_dialog.dart
//
// Usage — call from anywhere (e.g. Profile screen Settings row):
//   showRateSettingsDialog(context);

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import 'nirwana_logo.dart';

void showRateSettingsDialog(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _RateSheet(),
  );
}

class _RateSheet extends StatefulWidget {
  const _RateSheet();

  @override
  State<_RateSheet> createState() => _RateSheetState();
}

class _RateSheetState extends State<_RateSheet> {
  late TextEditingController _ctrl;
  bool _saving = false;
  String? _error;

  static const _cyan = Color(0xFF00D9FF);

  // Common Indian electricity tariff slabs for quick-pick
  static const List<_RatePreset> _presets = [
    _RatePreset('₹5 / kWh',  5.0),
    _RatePreset('₹7 / kWh',  7.0),
    _RatePreset('₹10 / kWh', 10.0),
    _RatePreset('₹12 / kWh', 12.0),
  ];

  @override
  void initState() {
    super.initState();
    final api = Provider.of<ApiService>(context, listen: false);
    _ctrl = TextEditingController(
        text: api.ratePerUnit.toStringAsFixed(
            api.ratePerUnit == api.ratePerUnit.roundToDouble() ? 0 : 2));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final raw = _ctrl.text.trim();
    final val = double.tryParse(raw);
    if (val == null || val <= 0) {
      setState(() => _error = 'Enter a valid positive number.');
      return;
    }
    setState(() { _saving = true; _error = null; });
    final api = Provider.of<ApiService>(context, listen: false);
    await api.setRatePerUnit(val);
    if (mounted) {
      setState(() => _saving = false);
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF0D1828),
          content: Row(children: [
            const Icon(Icons.check_circle_outline_rounded,
                color: Color(0xFF22C55E), size: 18),
            const SizedBox(width: 10),
            Text('Rate set to ₹${val.toStringAsFixed(2)} / kWh',
                style: const TextStyle(color: Colors.white)),
          ]),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final api = Provider.of<ApiService>(context);
    final monthlyKwh = api.getMonthlyEnergyKwh();
    final currentRate = double.tryParse(_ctrl.text) ?? api.ratePerUnit;
    final previewBill = monthlyKwh * currentRate;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0D1828),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Row(children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: _cyan.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.electric_bolt_rounded,
                  color: _cyan, size: 20),
            ),
            const SizedBox(width: 12),
            const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Electricity Rate',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800)),
              Text('Set your local tariff (Rs. per kWh)',
                  style: TextStyle(color: Colors.white38, fontSize: 12)),
            ]),
          ]),
          const SizedBox(height: 24),

          // Quick-pick preset chips
          const Text('Quick select',
              style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _presets.map((p) {
              final selected =
                  (double.tryParse(_ctrl.text) ?? -1) == p.value;
              return GestureDetector(
                onTap: () {
                  _ctrl.text = p.value
                      .toStringAsFixed(p.value == p.value.roundToDouble() ? 0 : 2);
                  setState(() => _error = null);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected
                        ? _cyan.withOpacity(0.15)
                        : Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: selected
                          ? _cyan.withOpacity(0.5)
                          : Colors.white.withOpacity(0.08),
                    ),
                  ),
                  child: Text(p.label,
                      style: TextStyle(
                        color: selected ? _cyan : Colors.white54,
                        fontSize: 13,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w400,
                      )),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          // Custom input
          const Text('Or enter manually',
              style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _error != null
                    ? const Color(0xFFFF4444).withOpacity(0.4)
                    : Colors.white.withOpacity(0.1),
              ),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 16),
                decoration: BoxDecoration(
                  border: Border(
                    right: BorderSide(
                        color: Colors.white.withOpacity(0.08)),
                  ),
                ),
                child: const Text('₹',
                    style: TextStyle(
                        color: Color(0xFF00D9FF),
                        fontSize: 18,
                        fontWeight: FontWeight.w700)),
              ),
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*\.?\d*')),
                  ],
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600),
                  onChanged: (_) => setState(() => _error = null),
                  decoration: InputDecoration(
                    hintText: '10.00',
                    hintStyle: TextStyle(
                        color: Colors.white.withOpacity(0.2),
                        fontSize: 18),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 16),
                    suffixText: '/ kWh',
                    suffixStyle: TextStyle(
                        color: Colors.white.withOpacity(0.3),
                        fontSize: 13),
                  ),
                ),
              ),
            ]),
          ),

          if (_error != null) ...[
            const SizedBox(height: 6),
            Row(children: [
              const Icon(Icons.error_outline_rounded,
                  color: Color(0xFFFF4444), size: 14),
              const SizedBox(width: 6),
              Text(_error!,
                  style: const TextStyle(
                      color: Color(0xFFFF4444), fontSize: 12)),
            ]),
          ],

          const SizedBox(height: 20),

          // Live bill preview
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _cyan.withOpacity(0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _cyan.withOpacity(0.15)),
            ),
            child: Row(children: [
              const Icon(Icons.receipt_long_outlined,
                  color: Color(0xFF00D9FF), size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Estimated bill this month',
                        style: TextStyle(
                            color: Colors.white54, fontSize: 11)),
                    const SizedBox(height: 3),
                    Text(
                      '₹${previewBill.toStringAsFixed(2)}',
                      style: const TextStyle(
                          color: Color(0xFF00D9FF),
                          fontSize: 20,
                          fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                const Text('Usage', style: TextStyle(color: Colors.white38, fontSize: 10)),
                Text('${monthlyKwh.toStringAsFixed(2)} kWh',
                    style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ]),
            ]),
          ),
          const SizedBox(height: 20),

          // Save button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: _cyan,
                foregroundColor: const Color(0xFF0A1628),
                disabledBackgroundColor: _cyan.withOpacity(0.4),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: _saving
                  ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF0A1628)))
                  : const Text('Save Rate',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

// Plain data class — replaces Dart-3 record syntax
class _RatePreset {
  final String label;
  final double value;
  const _RatePreset(this.label, this.value);
}
