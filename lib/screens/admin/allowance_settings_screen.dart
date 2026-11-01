import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';

/// Admin: change the ONE standard allowance. There is no per-scholar input —
/// the amount, once saved, is what every scholar receives.
class AllowanceSettingsScreen extends StatefulWidget {
  const AllowanceSettingsScreen({super.key});
  @override
  State<AllowanceSettingsScreen> createState() =>
      _AllowanceSettingsScreenState();
}

class _AllowanceSettingsScreenState extends State<AllowanceSettingsScreen> {
  final _amount = TextEditingController();
  final _label = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final a = context.read<AppState>().allowance;
    _amount.text = a.allowanceAmount.toStringAsFixed(2);
    _label.text = a.label;
  }

  @override
  void dispose() {
    _amount.dispose();
    _label.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amount.text.replaceAll(',', ''));
    if (amount == null || amount <= 0) {
      showMsg(context, 'Enter a valid amount greater than zero.', error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      await context
          .read<AppState>()
          .updateAllowance(amount, label: _label.text.trim());
      if (!mounted) return;
      showMsg(context,
          'Standard allowance set to PHP ${fmtPhp(amount)} for all scholars.');
      Navigator.pop(context);
    } catch (e) {
      if (mounted) showMsg(context, 'Failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          leading: const BackButton(), title: const Text('Standard Allowance')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.colors.goldTint,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline,
                    color: AppTheme.accentGold, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'This amount is applied to EVERY scholar. You cannot give '
                    'one scholar a different amount — that keeps the payout '
                    'fair and auditable.',
                    style:
                        TextStyle(fontSize: 12, color: context.colors.textBody),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _label2('Allowance Amount (PHP)'),
          TextField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(hintText: '5000.00'),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [1000, 2500, 5000, 7500, 10000]
                .map((v) => ActionChip(
                      label: Text('₱${v.toString()}',
                          style: const TextStyle(fontSize: 11)),
                      onPressed: () => setState(
                          () => _amount.text = v.toDouble().toStringAsFixed(2)),
                    ))
                .toList(),
          ),
          const SizedBox(height: 18),
          _label2('Label shown to scholars'),
          TextField(
            controller: _label,
            decoration: const InputDecoration(
                hintText: 'e.g. November 2025 Monthly Allowance'),
          ),
          const SizedBox(height: 28),
          ElevatedButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('Save Standard Allowance'),
          ),
        ],
      ),
    );
  }

  Widget _label2(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(t,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.colors.textPrimary)),
      );
}
