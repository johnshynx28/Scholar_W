import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../providers/app_state.dart';
import '../../models/models.dart';
import '../../widgets/widgets.dart';

class PendingWithdrawalsScreen extends StatefulWidget {
  const PendingWithdrawalsScreen({super.key});
  @override
  State<PendingWithdrawalsScreen> createState() =>
      _PendingWithdrawalsScreenState();
}

class _PendingWithdrawalsScreenState extends State<PendingWithdrawalsScreen> {
  List<WithdrawalRequest> _requests = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      _requests = await context.read<AppState>().wallet.getPendingWithdrawals();
    } catch (_) {
      _requests = [];
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _approve(WithdrawalRequest r) async {
    try {
      await context.read<AppState>().wallet.approveWithdrawal(r);
      if (!mounted) return;
      showMsg(context, 'Payout approved for ${r.scholarName}.');
      _load();
    } catch (e) {
      if (!mounted) return;
      showMsg(context, 'Failed: $e', error: true);
    }
  }

  Future<void> _reject(WithdrawalRequest r) async {
    try {
      await context.read<AppState>().wallet.rejectWithdrawal(r);
      if (!mounted) return;
      showMsg(context, 'Request rejected.');
      _load();
    } catch (e) {
      if (!mounted) return;
      showMsg(context, 'Failed: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          leading: const BackButton(),
          title: const Text('Pending Withdrawals')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _requests.isEmpty
              ? const Center(
                  child: Text('No pending requests.',
                      style: TextStyle(color: AppTheme.textMuted)))
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    SectionLabel('WITHDRAWAL REQUESTS (${_requests.length})'),
                    const SizedBox(height: 12),
                    ..._requests.map(_requestCard),
                  ],
                ),
    );
  }

  Widget _requestCard(WithdrawalRequest r) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.borderSoft),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: AppTheme.accentGold.withValues(alpha: .15),
                child: Text(
                    r.scholarName.isNotEmpty
                        ? r.scholarName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                        color: AppTheme.accentGold,
                        fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.scholarName,
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: context.colors.textPrimary)),
                    const SizedBox(height: 2),
                    Text('${r.paymentMethod} • ${r.accountNumber}',
                        style: const TextStyle(
                            fontSize: 11, color: AppTheme.textMuted)),
                  ],
                ),
              ),
              Text('PHP ${fmtPhp(r.amount)}',
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: context.colors.brand)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => _reject(r),
                  style: TextButton.styleFrom(
                    backgroundColor: context.colors.dangerBg,
                    foregroundColor: AppTheme.dangerRed,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Reject'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextButton(
                  onPressed: () => _approve(r),
                  style: TextButton.styleFrom(
                    backgroundColor: context.colors.successBg,
                    foregroundColor: AppTheme.successGreen,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Approve Payout'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
