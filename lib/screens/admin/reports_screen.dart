import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../providers/app_state.dart';
import '../../widgets/widgets.dart';

/// FR-24 — Audit report of every disbursement batch.
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  List<Map<String, dynamic>> _batches = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      _batches = await context.read<AppState>().wallet.getDisbursements();
      _error = null;
    } catch (e) {
      _batches = [];
      _error = '$e';
    }
    if (mounted) setState(() => _loading = false);
  }

  double get _grandTotal => _batches.fold(
      0,
      (sum, b) =>
          sum +
          ((b['amount_per_scholar'] ?? 0) as num).toDouble() *
              ((b['recipient_count'] ?? 0) as num).toInt());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          leading: const BackButton(),
          title: const Text('Disbursement Reports')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Could not load reports.\n$_error',
                      textAlign: TextAlign.center,
                      maxLines: 5,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppTheme.textMuted)),
                ))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      // Summary card
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryBlue,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('TOTAL DISBURSED (ALL BATCHES)',
                                style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1)),
                            const SizedBox(height: 8),
                            Text('PHP ${fmtPhp(_grandTotal)}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800)),
                            const SizedBox(height: 4),
                            Text('${_batches.length} batch(es) recorded',
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 12)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      const SectionLabel('DISBURSEMENT BATCHES'),
                      const SizedBox(height: 12),
                      if (_batches.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(
                              child: Text('No disbursements recorded yet.',
                                  style: TextStyle(
                                      color: AppTheme.textMuted))),
                        )
                      else
                        ..._batches.map(_batchCard),
                    ],
                  ),
                ),
    );
  }

  Widget _batchCard(Map<String, dynamic> b) {
    final amount = ((b['amount_per_scholar'] ?? 0) as num).toDouble();
    final count = ((b['recipient_count'] ?? 0) as num).toInt();
    final date = DateTime.tryParse('${b['created_at'] ?? ''}');
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.colors.borderSoft),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(b['title']?.toString() ?? 'Batch',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: context.colors.textPrimary)),
                const SizedBox(height: 4),
                Text(
                    'PHP ${fmtPhp(amount)} × $count scholar(s)'
                    '${date != null ? ' • ${DateFormat('MMM d, yyyy h:mm a').format(date.toLocal())}' : ''}',
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.textMuted)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('PHP ${fmtPhp(amount * count)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: AppTheme.successGreen)),
              const SizedBox(height: 4),
              const StatusChip('COMPLETED'),
            ],
          ),
        ],
      ),
    );
  }
}
