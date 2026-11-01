import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../providers/app_state.dart';
import '../../models/models.dart';
import '../../widgets/widgets.dart';

/// FR-23 — Admin controls who receives an allowance by activating or
/// deactivating scholar accounts, and can delete accounts (one at a time or
/// all finished inactive ones). Deactivated scholars are excluded from the
/// Disburse Allowance recipient list.
class ManageScholarsScreen extends StatefulWidget {
  const ManageScholarsScreen({super.key});
  @override
  State<ManageScholarsScreen> createState() => _ManageScholarsScreenState();
}

class _ManageScholarsScreenState extends State<ManageScholarsScreen> {
  List<Scholar> _scholars = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      _scholars = await context.read<AppState>().wallet.getScholars();
      _error = null;
    } catch (e) {
      _scholars = [];
      _error = '$e';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _toggle(Scholar s, bool active) async {
    try {
      await context.read<AppState>().wallet.setScholarActive(s.id, active);
      setState(() => s.active = active);
      if (mounted) {
        showMsg(context,
            active ? '${s.name} activated.' : '${s.name} deactivated.');
      }
    } catch (e) {
      if (mounted) {
        showMsg(context,
            'Failed to update the scholar account. ($e)',
            error: true);
      }
    }
  }

  Future<bool> _confirm(String title, String body, String action) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.dangerRed),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(action)),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _delete(Scholar s) async {
    final ok = await _confirm(
        'Delete account?',
        '${s.name} and all of their records (transactions, claims, expenses, '
            'reviews) will be permanently removed. This cannot be undone.',
        'Delete');
    if (!ok || !mounted) return;
    try {
      await context.read<AppState>().wallet.deleteScholar(s.id);
      if (!mounted) return;
      setState(() => _scholars.removeWhere((x) => x.id == s.id));
      showMsg(context, '${s.name} deleted.');
    } catch (e) {
      if (mounted) showMsg(context, '$e', error: true);
    }
  }

  Future<void> _deleteInactive() async {
    final count = _scholars
        .where((s) =>
            !s.active &&
            s.balance == 0 &&
            (s.verificationStatus == VerificationStatus.rejected ||
                s.verificationStatus == VerificationStatus.approved))
        .length;
    if (count == 0) {
      showMsg(context, 'No inactive accounts to delete.');
      return;
    }
    final ok = await _confirm(
        'Delete inactive accounts?',
        '$count inactive account(s) (rejected or deactivated, zero balance) '
            'will be permanently deleted. Registrations still waiting for '
            'review are not affected.',
        'Delete $count');
    if (!ok || !mounted) return;
    try {
      final n = await context.read<AppState>().wallet.deleteInactiveScholars();
      if (!mounted) return;
      showMsg(context, '$n inactive account(s) deleted.');
      await _load();
    } catch (e) {
      if (mounted) showMsg(context, '$e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          leading: const BackButton(),
          title: const Text('Manage Scholars'),
          actions: [
            IconButton(
              tooltip: 'Delete inactive accounts',
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: _loading ? null : _deleteInactive,
            ),
          ]),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Could not load scholars.\n$_error',
                      textAlign: TextAlign.center,
                      maxLines: 5,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppTheme.textMuted)),
                ))
              : _scholars.isEmpty
                  ? const Center(
                      child: Text('No scholars registered yet.',
                          style: TextStyle(color: AppTheme.textMuted)))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.all(20),
                        children: [
                          SectionLabel(
                              'SCHOLARS (${_scholars.length}) — toggle to control allowance'),
                          const SizedBox(height: 12),
                          ..._scholars.map(_tile),
                        ],
                      ),
                    ),
    );
  }

  Widget _tile(Scholar s) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.colors.borderSoft),
      ),
      child: Column(children: [
        SwitchListTile(
          value: s.active,
          onChanged: s.verificationStatus == VerificationStatus.approved
              ? (v) => _toggle(s, v)
              : null,
          secondary: CircleAvatar(
            backgroundColor:
                s.active ? context.colors.successBg : context.colors.dangerBg,
            child: Text(s.name.isNotEmpty ? s.name[0].toUpperCase() : '?',
                style: TextStyle(
                    color: s.active ? AppTheme.successGreen : AppTheme.dangerRed,
                    fontWeight: FontWeight.w700)),
          ),
          title: Text(s.name,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          subtitle: Text(
              'ID: ${s.studentId} • ${s.verificationStatus.label} • PHP ${fmtPhp(s.balance)}',
              style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 8, bottom: 4),
          child: Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _delete(s),
              icon: const Icon(Icons.delete_outline,
                  size: 18, color: AppTheme.dangerRed),
              label: const Text('Delete account',
                  style: TextStyle(color: AppTheme.dangerRed, fontSize: 12)),
            ),
          ),
        ),
      ]),
    );
  }
}
