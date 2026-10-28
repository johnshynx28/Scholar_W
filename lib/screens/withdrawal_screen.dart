import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/app_state.dart';
import '../models/models.dart';
import '../widgets/widgets.dart';

class WithdrawalScreen extends StatefulWidget {
  const WithdrawalScreen({super.key});
  @override
  State<WithdrawalScreen> createState() => _WithdrawalScreenState();
}

class _WithdrawalScreenState extends State<WithdrawalScreen> {
  final _amount = TextEditingController();
  final _accountName = TextEditingController();
  final _accountNumber = TextEditingController();
  final _notes = TextEditingController();
  String _method = 'GCash';
  bool _busy = false;

  static const _methods = ['GCash', 'PayMaya', 'Bank Transfer'];

  Future<void> _submit() async {
    final amount = double.tryParse(_amount.text) ?? 0;
    if (amount <= 0 || _accountName.text.isEmpty || _accountNumber.text.isEmpty) {
      showMsg(context, 'Complete amount, account name and number.',
          error: true);
      return;
    }
    final state = context.read<AppState>();
    if (amount > state.balance) {
      showMsg(context, 'Amount exceeds your current balance.', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      await state.wallet.createWithdrawal(WithdrawalRequest(
        id: '',
        scholarId: state.user!.id,
        scholarName: state.user!.fullName,
        accountName: _accountName.text.trim(),
        accountNumber: _accountNumber.text.trim(),
        paymentMethod: _method,
        amount: amount,
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        createdAt: DateTime.now(),
      ));
      if (mounted) {
        showMsg(context, 'Withdrawal request submitted for review.');
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
    final balance = context.watch<AppState>().balance;
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('New Withdrawal Request'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.colors.warningBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Make sure your disbursement details correspond precisely with your registered account.',
                style: TextStyle(fontSize: 11, color: AppTheme.warningAmber),
              ),
            ),
            const SizedBox(height: 20),
            _label('Amount to Withdraw (PHP)'),
            TextField(
              controller: _amount,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                  hintText: 'Enter amount (e.g. 5000.00) — Available: ${fmtPhp(balance)}'),
            ),
            const SizedBox(height: 16),
            _label('Account Name'),
            TextField(
              controller: _accountName,
              decoration:
                  const InputDecoration(hintText: 'Your Full Name'),
            ),
            const SizedBox(height: 16),
            _label('Account Number / Phone'),
            TextField(
              controller: _accountNumber,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                  hintText: '09XX-XXX-XXXX or Card No.'),
            ),
            const SizedBox(height: 16),
            _label('Payment Method'),
            DropdownButtonFormField<String>(
              initialValue: _method,
              items: _methods
                  .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                  .toList(),
              onChanged: (v) => setState(() => _method = v ?? 'GCash'),
              decoration: const InputDecoration(),
            ),
            const SizedBox(height: 16),
            _label('Reference / Notes (Optional)'),
            TextField(
              controller: _notes,
              decoration:
                  const InputDecoration(hintText: 'e.g. November Allowance'),
            ),
            const SizedBox(height: 28),
            ElevatedButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Submit Withdrawal'),
            ),
          ],
        ),
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
