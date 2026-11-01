import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app_state.dart';
import '../services/wallet_service.dart';
import '../theme/app_theme.dart';
import '../widgets/widgets.dart';

/// Scholar: link, view and remove accounts used for Cash Out.
/// Linking only saves the details; no money moves and nothing is verified
/// with GCash, Maya or the bank in this version.
class LinkedAccountsScreen extends StatefulWidget {
  const LinkedAccountsScreen({super.key});
  @override
  State<LinkedAccountsScreen> createState() => _LinkedAccountsScreenState();
}

class _LinkedAccountsScreenState extends State<LinkedAccountsScreen> {
  List<LinkedAccount> _accounts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final state = context.read<AppState>();
    try {
      final list = await state.wallet.getLinkedAccounts(state.user!.id);
      if (mounted) setState(() => _accounts = list);
    } catch (_) {
      if (mounted) showMsg(context, 'Could not load linked accounts.', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  IconData _icon(PayoutProvider p) => p == PayoutProvider.bank
      ? Icons.account_balance_outlined
      : Icons.phone_android_rounded;

  Future<void> _remove(LinkedAccount a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove linked account?'),
        content: Text('${a.providerLabel} ${a.masked} will be removed. '
            'Past cash-outs are not affected.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Remove')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await context.read<AppState>().wallet.unlinkAccount(a.id);
      await _load();
    } on WalletException catch (e) {
      if (mounted) showMsg(context, e.message, error: true);
    }
  }

  Future<void> _add() async {
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _AddAccountSheet(),
    );
    if (added == true) {
      await _load();
      if (mounted) showMsg(context, 'Account linked.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Linked Accounts')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.add),
        label: const Text('Link account'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                children: [
                  Text(
                    'Link the GCash, Maya or bank account that should receive your cash-outs. '
                    'Use an account registered in your own name.',
                    style: TextStyle(color: context.colors.textBody),
                  ),
                  const SizedBox(height: 16),
                  if (_accounts.isEmpty)
                    const Card(
                        child: Padding(
                            padding: EdgeInsets.all(20),
                            child: Text('No linked accounts yet.')))
                  else
                    ..._accounts.map((a) => Card(
                          child: ListTile(
                            leading: Icon(_icon(a.provider)),
                            title: Text('${a.providerLabel}  ${a.masked}'),
                            subtitle: Text(a.accountName),
                            trailing: IconButton(
                              tooltip: 'Remove',
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _remove(a),
                            ),
                          ),
                        )),
                ],
              ),
            ),
    );
  }
}

class _AddAccountSheet extends StatefulWidget {
  const _AddAccountSheet();
  @override
  State<_AddAccountSheet> createState() => _AddAccountSheetState();
}

class _AddAccountSheetState extends State<_AddAccountSheet> {
  PayoutProvider _provider = PayoutProvider.gcash;
  final _name = TextEditingController();
  final _number = TextEditingController();
  final _bank = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _number.dispose();
    _bank.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final digits = _number.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (_name.text.trim().length < 2) {
      showMsg(context, 'Enter the name registered on the account.', error: true);
      return;
    }
    if (_provider.isMobile && !RegExp(r'^09\d{9}$').hasMatch(digits)) {
      showMsg(context, 'Enter an 11-digit mobile number that starts with 09.',
          error: true);
      return;
    }
    if (_provider == PayoutProvider.bank &&
        (_bank.text.trim().length < 2 || digits.length < 8)) {
      showMsg(context, 'Enter the bank name and a valid account number.',
          error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      await context.read<AppState>().wallet.linkAccount(
            provider: _provider,
            bankName: _bank.text,
            accountName: _name.text,
            accountNumber: digits,
          );
      if (mounted) Navigator.pop(context, true);
    } on WalletException catch (e) {
      if (mounted) showMsg(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Link an account',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            SegmentedButton<PayoutProvider>(
              segments: const [
                ButtonSegment(value: PayoutProvider.gcash, label: Text('GCash')),
                ButtonSegment(value: PayoutProvider.maya, label: Text('Maya')),
                ButtonSegment(value: PayoutProvider.bank, label: Text('Bank')),
              ],
              selected: {_provider},
              onSelectionChanged: (s) => setState(() => _provider = s.first),
            ),
            const SizedBox(height: 14),
            if (_provider == PayoutProvider.bank) ...[
              TextField(
                  controller: _bank,
                  decoration: const InputDecoration(labelText: 'Bank name')),
              const SizedBox(height: 12),
            ],
            TextField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                    labelText: 'Account name (as registered)')),
            const SizedBox(height: 12),
            TextField(
              controller: _number,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(20),
              ],
              decoration: InputDecoration(
                  labelText: _provider.isMobile
                      ? '${_provider.label} mobile number (09XXXXXXXXX)'
                      : 'Account number'),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _busy ? null : _save,
                child: _busy
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Save account'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
