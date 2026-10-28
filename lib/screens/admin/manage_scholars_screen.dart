import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../providers/app_state.dart';
import '../../models/models.dart';
import '../../widgets/widgets.dart';

/// FR-23 — Admin controls who receives an allowance by activating or
/// deactivating scholar accounts. Deactivated scholars are excluded from the
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
            'Failed to update. Run supabase_schema.sql to add the is_active column. ($e)',
            error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          leading: const BackButton(), title: const Text('Manage Scholars')),
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
      child: SwitchListTile(
        value: s.active,
        onChanged: (v) => _toggle(s, v),
        secondary: CircleAvatar(
          backgroundColor: s.active
              ? context.colors.successBg
              : context.colors.dangerBg,
          child: Text(s.name.isNotEmpty ? s.name[0].toUpperCase() : '?',
              style: TextStyle(
                  color: s.active
                      ? AppTheme.successGreen
                      : AppTheme.dangerRed,
                  fontWeight: FontWeight.w700)),
        ),
        title: Text(s.name,
            style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(
            'ID: ${s.studentId} • Balance: PHP ${fmtPhp(s.balance)}',
            style:
                const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
      ),
    );
  }
}
