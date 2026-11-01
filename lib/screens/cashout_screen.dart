import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app_state.dart';
import '../services/wallet_service.dart';
import '../theme/app_theme.dart';
import '../widgets/widgets.dart';
import 'fingerprint_screen.dart';
import 'linked_accounts_screen.dart';

/// Scholar: Cash Out.
/// MOCKUP / DEMO: pick a linked account, enter the amount, review, confirm
/// with device biometrics. The transfer is simulated: the balance is reduced
/// and a simulated reference is shown. No real money moves.
class CashoutScreen extends StatefulWidget {
  const CashoutScreen({super.key});
  @override
  State<CashoutScreen> createState() => _CashoutScreenState();
}

class _CashoutScreenState extends State<CashoutScreen> {
  final _amount = TextEditingController();
  List<LinkedAccount> _accounts = [];
  List<Withdrawal> _history = [];
  int? _selected;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final state = context.read<AppState>();
    try {
      await state.refreshBalance();
      final accounts = await state.wallet.getLinkedAccounts(state.user!.id);
      final history = await state.wallet.getMyWithdrawals(state.user!.id);
      if (!mounted) return;
      setState(() {
        _accounts = accounts;
        _history = history;
        if (_selected == null || !accounts.any((a) => a.id == _selected)) {
          _selected = accounts.isEmpty ? null : accounts.first.id;
        }
      });
    } catch (_) {
      if (mounted) showMsg(context, 'Could not load cash-out details.', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _manageAccounts() async {
    await Navigator.push(context,
        MaterialPageRoute(builder: (_) => const LinkedAccountsScreen()));
    _load();
  }

  Future<void> _submit() async {
    final state = context.read<AppState>();
    final amount = double.tryParse(_amount.text.trim());
    final acc = _accounts.where((a) => a.id == _selected).firstOrNull;
    if (acc == null) {
      showMsg(context, 'Link and select an account first.', error: true);
      return;
    }
    if (amount == null || amount < WalletService.minCashout) {
      showMsg(context,
          'Minimum cash-out is PHP ${fmtPhp(WalletService.minCashout)}.',
          error: true);
      return;
    }
    if (amount > state.balance) {
      showMsg(context, 'Amount is more than your balance.', error: true);
      return;
    }

    // Review screen: amount comes from the field, destination from the record.
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Review cash-out'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('PHP ${fmtPhp(amount)}',
                style:
                    const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            Text('To: ${acc.providerLabel} ${acc.masked}'),
            Text('Name: ${acc.accountName}'),
            const SizedBox(height: 12),
            const Text(
                'DEMO ONLY: this is a simulation. The amount is deducted from '
                'your wallet balance, but no real money is sent to the account.'),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Back')),
          FilledButton.icon(
              onPressed: () => Navigator.pop(ctx, true),
              icon: const Icon(Icons.fingerprint),
              label: const Text('Confirm')),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _busy = true);
    try {
      if (!state.fingerprintRegistered) {
        await Navigator.push<bool>(
            context,
            MaterialPageRoute(
                builder: (_) => const FingerprintScreen(required: true)));
        if (!mounted || !state.fingerprintRegistered) return;
      }
      final verified = await state.verifyFingerprint(
          'Confirm cash-out: PHP ${fmtPhp(amount)}');
      if (!mounted) return;
      if (!verified) {
        throw WalletException(
            'Biometrics not verified. Nothing was deducted.');
      }
      await state.wallet.requestWithdrawal(accountId: acc.id, amount: amount);
      _amount.clear();
      await _load();
      if (mounted) showMsg(context, 'Demo cash-out completed. No real money was sent.');
    } on WalletException catch (e) {
      if (mounted) showMsg(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Color _statusColor(WithdrawalStatus s) => switch (s) {
        WithdrawalStatus.completed => AppTheme.successGreen,
        WithdrawalStatus.pending => AppTheme.warningAmber,
        _ => AppTheme.dangerRed,
      };

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Cash Out')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  BalanceCard(balance: state.balance),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: context.colors.warningBg,
                        borderRadius: BorderRadius.circular(10)),
                    child: const Row(children: [
                      Icon(Icons.science_outlined, size: 20),
                      SizedBox(width: 10),
                      Expanded(
                          child: Text(
                              'Demo mode: Cash Out is a simulation. No real money is sent to GCash, Maya or a bank.')),
                    ]),
                  ),
                  const SizedBox(height: 20),
                  SectionLabel('CASH OUT TO',
                      trailing: TextButton(
                          onPressed: _manageAccounts,
                          child: const Text('Manage'))),
                  if (_accounts.isEmpty)
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.link),
                        title: const Text('Link a GCash, Maya or bank account'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _manageAccounts,
                      ),
                    )
                  else
                    ..._accounts.map((a) => Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                                color: a.id == _selected
                                    ? context.colors.brand
                                    : Colors.transparent,
                                width: 1.5),
                          ),
                          child: ListTile(
                            onTap: () => setState(() => _selected = a.id),
                            leading: Icon(a.provider == PayoutProvider.bank
                                ? Icons.account_balance_outlined
                                : Icons.phone_android_rounded),
                            title: Text('${a.providerLabel}  ${a.masked}'),
                            subtitle: Text(a.accountName),
                            trailing: a.id == _selected
                                ? Icon(Icons.check_circle,
                                    color: context.colors.brand)
                                : null,
                          ),
                        )),
                  const SizedBox(height: 16),
                  const SectionLabel('AMOUNT (PHP)'),
                  TextField(
                    controller: _amount,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))
                    ],
                    decoration: InputDecoration(
                      prefixText: 'PHP ',
                      hintText: 'Minimum ${fmtPhp(WalletService.minCashout)}',
                      suffix: TextButton(
                        onPressed: state.balance > 0
                            ? () => _amount.text =
                                state.balance.toStringAsFixed(2)
                            : null,
                        child: const Text('All'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Available: PHP ${fmtPhp(state.balance)}.',
                    style: TextStyle(
                        fontSize: 12, color: context.colors.textBody),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _busy ? null : _submit,
                      icon: const Icon(Icons.fingerprint),
                      label: const Text('Review and Cash Out'),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SectionLabel('MY CASH-OUTS (${_history.length})'),
                  if (_history.isEmpty)
                    const Card(
                        child: Padding(
                            padding: EdgeInsets.all(20),
                            child: Text('No cash-outs yet.')))
                  else
                    ..._history.map((w) => Card(
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  Expanded(
                                      child: Text('PHP ${fmtPhp(w.amount)}',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 16))),
                                  StatusChip('SIMULATED',
                                      color: _statusColor(w.status),
                                      bg: _statusColor(w.status)
                                          .withValues(alpha: .12)),
                                ]),
                                const SizedBox(height: 6),
                                Text(
                                    '${w.providerLabel} ${w.accountNumber.length > 4 ? '•••• ${w.accountNumber.substring(w.accountNumber.length - 4)}' : w.accountNumber}'),
                                Text(_fmtDate(w.createdAt),
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: context.colors.textBody)),
                                if (w.reference.isNotEmpty)
                                  Text('Simulated reference: ${w.reference}'),
                              ],
                            ),
                          ),
                        )),
                ],
              ),
            ),
    );
  }

  String _fmtDate(DateTime d) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }
}
