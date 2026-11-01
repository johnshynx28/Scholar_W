import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../providers/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';
import '../fingerprint_screen.dart';
import 'allowance_settings_screen.dart';

/// Admin: issue a payout batch. The amount comes from the single standard
/// allowance setting and is NOT editable here, so every scholar is paid the
/// same. After generating, the admin gets one single-use QR per scholar.
class IssuePayoutScreen extends StatefulWidget {
  const IssuePayoutScreen({super.key});
  @override
  State<IssuePayoutScreen> createState() => _IssuePayoutScreenState();
}

class _IssuePayoutScreenState extends State<IssuePayoutScreen> {
  final _batchTitle = TextEditingController();
  List<Scholar> _scholars = [];
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _batchTitle.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final state = context.read<AppState>();
      await state.loadAllowanceSettings();
      final all = await state.wallet.getScholars();
      // Deactivated scholars cannot receive a payout.
      _scholars = all
          .where((s) =>
              s.active && s.verificationStatus == VerificationStatus.approved)
          .toList();
      _batchTitle.text = '${state.allowance.label} • ${DateTime.now().year}';
    } catch (_) {
      _scholars = [];
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _generate() async {
    final state = context.read<AppState>();
    final selected = _scholars.where((s) => s.selected).toList();
    if (selected.isEmpty) {
      showMsg(context, 'Select at least one scholar.', error: true);
      return;
    }
    // FR-29: the admin confirms the disbursement with the device biometric
    // prompt before any QR is generated or any amount is reserved.
    if (!state.fingerprintRegistered) {
      await Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => const FingerprintScreen(required: true)));
      if (!mounted || !state.fingerprintRegistered) return;
    }
    final selectedCount = selected.length;
    final total = selectedCount * state.allowance.allowanceAmount;
    final verified = await state.verifyFingerprint(
        'Disburse PHP ${fmtPhp(total)} to $selectedCount scholar(s)?');
    if (!mounted) return;
    if (!verified) {
      showMsg(context, 'Biometrics not verified. No payout was issued.',
          error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      final claims = await state.wallet.generatePayoutBatch(
        batchTitle: _batchTitle.text.trim(),
        recipients: selected,
      );
      if (!mounted) return;
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (_) => _QrSheetScreen(
                  claims: claims,
                  amount: state.allowance.allowanceAmount,
                )),
      );
    } catch (e) {
      if (mounted) showMsg(context, 'Failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final selectedCount = _scholars.where((s) => s.selected).length;
    final total = selectedCount * state.allowance.allowanceAmount;

    return Scaffold(
      appBar: AppBar(
          leading: const BackButton(), title: const Text('Issue Payout Event')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: context.colors.goldTint,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: AppTheme.accentGold.withValues(alpha: .5)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('AMOUNT PER SCHOLAR (FIXED)',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                              color: AppTheme.textMuted)),
                      const SizedBox(height: 6),
                      Text('PHP ${fmtPhp(state.allowance.allowanceAmount)}',
                          style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: context.colors.textPrimary)),
                      const SizedBox(height: 4),
                      Text(
                        'Set once for everybody — every selected scholar gets '
                        'exactly this amount.',
                        style: TextStyle(
                            fontSize: 12, color: context.colors.textBody),
                      ),
                      const SizedBox(height: 10),
                      TextButton.icon(
                        onPressed: () async {
                          await Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      const AllowanceSettingsScreen()));
                          _load();
                        },
                        icon: const Icon(Icons.tune, size: 16),
                        label: const Text('Change standard amount'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _label('Batch Title'),
                TextField(
                  controller: _batchTitle,
                  decoration: const InputDecoration(
                      hintText: 'e.g. November 2025 Monthly Allowance'),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    const SectionLabel('RECIPIENTS'),
                    const Spacer(),
                    TextButton(
                      onPressed: () => setState(() {
                        final all = selectedCount != _scholars.length;
                        for (final s in _scholars) {
                          s.selected = all;
                        }
                      }),
                      child: Text(selectedCount == _scholars.length
                          ? 'Clear all'
                          : 'Select all'),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                if (_scholars.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        'No active scholars yet.\nActivate scholars in Manage '
                        'Scholars first.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppTheme.textMuted),
                      ),
                    ),
                  )
                else
                  ..._scholars.map(_scholarTile),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: context.colors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: context.colors.borderSoft),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text('$selectedCount scholar(s) selected',
                            style: const TextStyle(
                                fontSize: 12, color: AppTheme.textMuted)),
                      ),
                      Text('PHP ${fmtPhp(total)}',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: context.colors.brand)),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                ElevatedButton.icon(
                  onPressed: _busy ? null : _generate,
                  icon: _busy
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.qr_code_2_rounded),
                  label: const Text('Generate QR Codes'),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Generating reserves the amount for each selected scholar. '
                  'The money is only released once the scholar scans their QR '
                  'code and verifies their fingerprint.',
                  style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
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
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Row(
          children: [
            Text('ID: ${s.studentId}',
                style:
                    const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
            const SizedBox(width: 8),
            Icon(
              s.fingerprintRegistered
                  ? Icons.fingerprint
                  : Icons.fingerprint_outlined,
              size: 13,
              color: s.fingerprintRegistered
                  ? AppTheme.successGreen
                  : AppTheme.warningAmber,
            ),
          ],
        ),
        secondary: CircleAvatar(
          backgroundColor: context.colors.brand.withValues(alpha: .15),
          child: Text(s.name.isNotEmpty ? s.name[0].toUpperCase() : '?',
              style: TextStyle(
                  color: context.colors.brand, fontWeight: FontWeight.w700)),
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

/// Shows the freshly generated single-use QR codes, one card per scholar.
class _QrSheetScreen extends StatelessWidget {
  final List<AllowanceClaim> claims;
  final double amount;
  const _QrSheetScreen({required this.claims, required this.amount});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payout QR Codes'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.colors.successBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle,
                    color: AppTheme.successGreen, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${claims.length} QR code(s) generated for PHP '
                    '${fmtPhp(amount)} each. Show a scholar their code — it '
                    'can only be scanned once.',
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.successGreen),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ...claims.map((c) => Container(
                margin: const EdgeInsets.only(bottom: 16),
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
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(c.scholarName,
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                      color: context.colors.textPrimary)),
                              Text(c.batchTitle,
                                  style: const TextStyle(
                                      fontSize: 11, color: AppTheme.textMuted)),
                            ],
                          ),
                        ),
                        Text('PHP ${fmtPhp(c.amount)}',
                            style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                color: context.colors.brand)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClaimQrPanel(claim: c, size: 200),
                    const SizedBox(height: 8),
                    const Text(
                      'Single use • the scholar scans this in their app to '
                      'confirm receipt',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 10, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}