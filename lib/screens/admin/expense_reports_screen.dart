import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../providers/app_state.dart';
import '../../models/models.dart';
import '../../widgets/widgets.dart';

/// Admin: review the expense reports scholars submit (with receipt photo),
/// then approve or reject them.
class ExpenseReportsScreen extends StatefulWidget {
  const ExpenseReportsScreen({super.key});
  @override
  State<ExpenseReportsScreen> createState() => _ExpenseReportsScreenState();
}

class _ExpenseReportsScreenState extends State<ExpenseReportsScreen> {
  List<ExpenseReport> _reports = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      _reports = await context.read<AppState>().wallet.getExpenses();
      _error = null;
    } catch (e) {
      _reports = [];
      _error = '$e';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _setStatus(ExpenseReport r, String status, String okMsg) async {
    try {
      await context.read<AppState>().wallet.setExpenseStatus(r.id!, status);
      if (!mounted) return;
      showMsg(context, okMsg);
      _load();
    } catch (e) {
      if (!mounted) return;
      showMsg(context, 'Failed: $e', error: true);
    }
  }

  void _viewReceipt(String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          children: [
            InteractiveViewer(
              child: Image.network(url, fit: BoxFit.contain),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount =
        _reports.where((r) => r.status == TxStatus.pending).length;
    return Scaffold(
      appBar: AppBar(
          leading: const BackButton(), title: const Text('Expense Reports')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _errorView()
              : _reports.isEmpty
                  ? const Center(
                      child: Text('No expense reports yet.',
                          style: TextStyle(color: AppTheme.textMuted)))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.all(20),
                        children: [
                          SectionLabel(
                              'EXPENSE REPORTS (${_reports.length}) • $pendingCount PENDING'),
                          const SizedBox(height: 12),
                          ..._reports.map(_card),
                        ],
                      ),
                    ),
    );
  }

  Widget _errorView() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Could not load expense reports.\n$_error',
                  textAlign: TextAlign.center,
                  maxLines: 6,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: context.colors.textBody)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() => _loading = true);
                  _load();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );

  Widget _statusChip(TxStatus s) {
    switch (s) {
      case TxStatus.pending:
        return StatusChip('PENDING',
            color: AppTheme.warningAmber, bg: context.colors.warningBg);
      case TxStatus.rejected:
        return StatusChip('REJECTED',
            color: AppTheme.dangerRed, bg: context.colors.dangerBg);
      case TxStatus.completed:
        return const StatusChip('APPROVED');
    }
  }

  Widget _card(ExpenseReport r) {
    final pending = r.status == TxStatus.pending;
    final sub = [
      r.category,
      if (r.createdAt != null)
        DateFormat('MMM d, yyyy').format(r.createdAt!.toLocal()),
    ].join(' • ');

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                    Text(sub,
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
          const SizedBox(height: 12),
          Text(r.title,
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: context.colors.textPrimary)),
          if ((r.description ?? '').isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(r.description!,
                style: TextStyle(
                    fontSize: 12, height: 1.4, color: context.colors.textBody)),
          ],
          if ((r.receiptUrl ?? '').isNotEmpty) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => _viewReceipt(r.receiptUrl!),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  r.receiptUrl!,
                  height: 150,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  loadingBuilder: (c, child, progress) => progress == null
                      ? child
                      : SizedBox(
                          height: 150,
                          child: Center(
                              child: CircularProgressIndicator(
                                  value: progress.expectedTotalBytes == null
                                      ? null
                                      : progress.cumulativeBytesLoaded /
                                          progress.expectedTotalBytes!)),
                        ),
                  errorBuilder: (c, e, s) => Container(
                    height: 70,
                    alignment: Alignment.center,
                    color: context.colors.background,
                    child: const Text('Receipt image unavailable',
                        style: TextStyle(
                            fontSize: 12, color: AppTheme.textMuted)),
                  ),
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: 8),
            const Text('No receipt attached',
                style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
          ],
          const SizedBox(height: 14),
          if (pending)
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () =>
                        _setStatus(r, 'rejected', 'Expense rejected.'),
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
                    onPressed: () =>
                        _setStatus(r, 'completed', 'Expense approved.'),
                    style: TextButton.styleFrom(
                      backgroundColor: context.colors.successBg,
                      foregroundColor: AppTheme.successGreen,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Approve'),
                  ),
                ),
              ],
            )
          else
            _statusChip(r.status),
        ],
      ),
    );
  }
}
