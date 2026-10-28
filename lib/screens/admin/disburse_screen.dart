import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../providers/app_state.dart';
import '../../models/models.dart';
import '../../widgets/widgets.dart';

class DisburseScreen extends StatefulWidget {
  const DisburseScreen({super.key});
  @override
  State<DisburseScreen> createState() => _DisburseScreenState();
}

class _DisburseScreenState extends State<DisburseScreen> {
  final _batchTitle = TextEditingController();
  final _amount = TextEditingController();
  List<Scholar> _scholars = [];
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final all = await context.read<AppState>().wallet.getScholars();
      // FR-23: deactivated scholars cannot receive an allowance.
      _scholars = all.where((s) => s.active).toList();
    } catch (_) {
      _scholars = [];
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _execute() async {
    final amount = double.tryParse(_amount.text) ?? 0;
    final selected = _scholars.where((s) => s.selected).toList();
    if (_batchTitle.text.isEmpty || amount <= 0 || selected.isEmpty) {
      showMsg(context, 'Enter a batch title, amount, and select recipients.',
          error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      await context.read<AppState>().wallet.disburseAllowance(
          batchTitle: _batchTitle.text.trim(),
          amount: amount,
          recipients: selected);
      if (mounted) {
        showMsg(context,
            'Disbursed PHP ${fmtPhp(amount)} to ${selected.length} scholar(s).');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) showMsg(context, 'Failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedCount = _scholars.where((s) => s.selected).length;
    return Scaffold(
      appBar: AppBar(
          leading: const BackButton(),
          title: const Text('Disburse Allowance')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _label('Disbursement Batch Title'),
                TextField(
                  controller: _batchTitle,
                  decoration: const InputDecoration(
                      hintText: 'e.g. November 2025 Monthly Allowance'),
                ),
                const SizedBox(height: 16),
                _label('Standard Amount per Scholar'),
                TextField(
                  controller: _amount,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration:
                      const InputDecoration(hintText: 'PHP 12,500.00'),
                ),
                const SizedBox(height: 20),
                const SectionLabel('RECIPIENT SELECTION'),
                const SizedBox(height: 10),
                if (_scholars.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                        child: Text('No scholars registered yet.',
                            style: TextStyle(color: AppTheme.textMuted))),
                  )
                else
                  ..._scholars.map(_scholarTile),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _busy ? null : _execute,
                  child: _busy
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text(
                          'Execute Disbursement ($selectedCount Selected)'),
                ),
              ],
            ),
    );
  }

  Widget _scholarTile(Scholar s) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: s.selected ? context.colors.brand : context.colors.borderSoft,
          width: s.selected ? 1.5 : 1,
        ),
      ),
      child: CheckboxListTile(
        value: s.selected,
        onChanged: (v) => setState(() => s.selected = v ?? false),
        title: Text(s.name,
            style:
                const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text('ID: ${s.studentId}',
            style:
                const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
        secondary: CircleAvatar(
          backgroundColor: context.colors.brand.withValues(alpha: .15),
          child: Text(
              s.name.isNotEmpty ? s.name[0].toUpperCase() : '?',
              style: TextStyle(
                  color: context.colors.brand,
                  fontWeight: FontWeight.w700)),
        ),
        controlAffinity: ListTileControlAffinity.leading,
      ),
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(t,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.colors.textPrimary)),
      );
}
