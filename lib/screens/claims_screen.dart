import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/widgets.dart';
import 'scan_claim_screen.dart';

/// Scholar: every allowance payout issued to them — waiting to be received,
/// received, or cancelled. Tapping a waiting payout opens the scanner.
class ClaimsScreen extends StatefulWidget {
  const ClaimsScreen({super.key});
  @override
  State<ClaimsScreen> createState() => _ClaimsScreenState();
}

class _ClaimsScreenState extends State<ClaimsScreen> {
  List<AllowanceClaim> _claims = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      _claims = await context
          .read<AppState>()
          .wallet
          .getMyClaims(context.read<AppState>().user!.id);
    } catch (_) {
      _claims = [];
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final pending = _claims.where((c) => c.isPending).length;
    final received = _claims.where((c) => c.isReceived).toList();
    final total = received.fold<double>(0, (s, c) => s + c.amount);

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('My Payouts'),
        actions: [
          IconButton(
            tooltip: 'Scan QR',
            icon: const Icon(Icons.qr_code_scanner_rounded),
            onPressed: () async {
              final ok = await Navigator.push<bool>(
                context,
                MaterialPageRoute(builder: (_) => const ScanClaimScreen()),
              );
              if (ok == true) _load();
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Row(
                    children: [
                      _stat('WAITING', '$pending', AppTheme.accentGold),
                      const SizedBox(width: 12),
                      _stat('RECEIVED', '${received.length}',
                          AppTheme.successGreen),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [AppTheme.primaryBlue, Color(0xFF14467F)]),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('TOTAL RECEIVED',
                            style: TextStyle(
                                color: Colors.white70,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1)),
                        const SizedBox(height: 6),
                        Text('PHP ${fmtPhp(total)}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  SectionLabel('PAYOUTS (${_claims.length})'),
                  const SizedBox(height: 12),
                  if (_claims.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(28),
                      child: Center(
                        child: Text(
                          'No payout issued yet.\nThe admin will generate a QR '
                          'code when the allowance is released.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppTheme.textMuted),
                        ),
                      ),
                    )
                  else
                    ..._claims.map(_claimCard),
                ],
              ),
            ),
    );
  }

  Widget _stat(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: color, borderRadius: BorderRadius.circular(14)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1)),
            const SizedBox(height: 6),
            Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }

  Widget _claimCard(AllowanceClaim c) {
    final chip = c.isReceived
        ? const StatusChip('RECEIVED')
        : c.isVoided
            ? const StatusChip('CANCELLED',
                color: AppTheme.dangerRed, bg: Color(0x22E15A5A))
            : const StatusChip('SCAN QR TO RECEIVE',
                color: AppTheme.warningAmber, bg: Color(0x22F0A020));
    final when = c.isReceived ? c.claimedAt : c.issuedAt;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: c.isPending ? AppTheme.accentGold : context.colors.borderSoft,
          width: c.isPending ? 1.4 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(c.batchTitle,
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: context.colors.textPrimary)),
              ),
              Text('PHP ${fmtPhp(c.amount)}',
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: c.isReceived
                          ? AppTheme.successGreen
                          : context.colors.textPrimary)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              chip,
              const SizedBox(width: 8),
              if (when != null)
                Text(DateFormat('MMM d, yyyy • h:mm a').format(when.toLocal()),
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.textMuted)),
            ],
          ),
          if (c.isPending) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => showPayoutQrSheet(context, c, onScan: () async {
                  final ok = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(builder: (_) => const ScanClaimScreen()),
                  );
                  if (ok == true) _load();
                }),
                icon: const Icon(Icons.qr_code_2_rounded, size: 18),
                label: const Text('Show my QR'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final ok = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(builder: (_) => const ScanClaimScreen()),
                  );
                  if (ok == true) _load();
                },
                icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                label: const Text('Scan QR to receive'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.accentGold,
                  side: const BorderSide(color: AppTheme.accentGold),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}