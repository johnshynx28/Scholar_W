import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../providers/app_state.dart';
import '../../widgets/widgets.dart';
import 'disburse_screen.dart';
import 'pending_withdrawals_screen.dart';
import 'expense_reports_screen.dart';
import 'manage_scholars_screen.dart';
import 'reports_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});
  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _scholars = 0;
  int _pending = 0;
  bool _loading = true;
  Map<String, dynamic>? _latestBatch; // FR-20 latest system activity

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final w = context.read<AppState>().wallet;
    try {
      _scholars = await w.getActiveScholarCount();
      _pending = await w.getPendingCashoutCount();
      final batches = await w.getDisbursements();
      _latestBatch = batches.isEmpty ? null : batches.first;
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          const ThemeToggleButton(),
          IconButton(
              icon: const Icon(Icons.logout), onPressed: () => state.logout())
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // FR-18
            Row(
              children: [
                _statCard('ACTIVE SCHOLARS', '$_scholars',
                    AppTheme.primaryBlue),
                const SizedBox(width: 14),
                _statCard('PENDING CASHOUT', '$_pending requests',
                    AppTheme.accentGold),
              ],
            ),
            const SizedBox(height: 24),
            // FR-19
            const SectionLabel('ADMINISTRATIVE CONTROLS'),
            const SizedBox(height: 12),
            Row(
              children: [
                _control(Icons.add, 'Disburse Funds', () async {
                  await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const DisburseScreen()));
                  _load();
                }),
                const SizedBox(width: 12),
                _control(Icons.check_circle_outline, 'Approve Queue',
                    () async {
                  await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              const PendingWithdrawalsScreen()));
                  _load();
                }),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _control(Icons.receipt_long_outlined, 'Expense Reports',
                    () async {
                  await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ExpenseReportsScreen()));
                }),
                const SizedBox(width: 12),
                // FR-23
                _control(Icons.group_outlined, 'Manage Scholars', () async {
                  await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ManageScholarsScreen()));
                  _load();
                }),
              ],
            ),
            const SizedBox(height: 12),
            // FR-24
            _control(Icons.assessment_outlined, 'Disbursement Reports',
                () async {
              await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const ReportsScreen()));
            }),
            const SizedBox(height: 24),
            // FR-20
            const SectionLabel('SYSTEM ACTIVITIES'),
            const SizedBox(height: 12),
            if (_latestBatch != null)
              _activity(
                _latestBatch!['title']?.toString() ?? 'Disbursement',
                'Latest batch • ${_fmtDate(_latestBatch!['created_at'])}',
                const StatusChip('COMPLETED'),
              )
            else
              _activity('No disbursements yet',
                  'Batches you run will appear here',
                  const StatusChip('IDLE',
                      color: AppTheme.textMuted, bg: Color(0x11000000))),
            _activity('GCash API Provider', 'Integration normal',
                const StatusChip('ONLINE')),
          ],
        ),
      ),
    );
  }

  String _fmtDate(dynamic raw) {
    if (raw is String) {
      final d = DateTime.tryParse(raw);
      if (d != null) return DateFormat('MMM d, yyyy').format(d.toLocal());
    }
    return '';
  }

  Widget _statCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
            color: color, borderRadius: BorderRadius.circular(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1)),
            const SizedBox(height: 8),
            _loading
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : Text(value,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }

  Widget _control(IconData icon, String label, VoidCallback onTap) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontSize: 13)),
      style: OutlinedButton.styleFrom(
        foregroundColor: context.colors.brand,
        backgroundColor: context.colors.surface,
        padding: const EdgeInsets.symmetric(vertical: 14),
        side: BorderSide(color: context.colors.border),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _activity(String title, String subtitle, Widget chip) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
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
                Text(title,
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: context.colors.textPrimary)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.textMuted)),
              ],
            ),
          ),
          chip,
        ],
      ),
    );
  }
}
