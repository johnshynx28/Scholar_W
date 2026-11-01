import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../providers/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';
import '../fingerprint_screen.dart';

/// Admin: every payout QR ever issued, with its live status
/// (waiting / received / cancelled). Confirms exactly who has received money.
class ClaimsMonitorScreen extends StatefulWidget {
  const ClaimsMonitorScreen({super.key});
  @override
  State<ClaimsMonitorScreen> createState() => _ClaimsMonitorScreenState();
}

class _ClaimsMonitorScreenState extends State<ClaimsMonitorScreen> {
  List<AllowanceClaim> _claims = [];
  bool _loading = true;
  String? _error;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      _claims = await context.read<AppState>().wallet.getAllClaims();
      _error = null;
    } catch (e) {
      _claims = [];
      _error = '$e';
    }
    if (mounted) setState(() => _loading = false);
  }

  List<AllowanceClaim> get _visible {
    switch (_filter) {
      case 'waiting':
        return _claims.where((c) => c.isPending).toList();
      case 'received':
        return _claims.where((c) => c.isReceived).toList();
      case 'cancelled':
        return _claims.where((c) => c.isVoided).toList();
      default:
        return _claims;
    }
  }

  Future<void> _void(AllowanceClaim c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel this payout?'),
        content: Text(
            'PHP ${fmtPhp(c.amount)} reserved for ${c.scholarName} will be '
            'released. Their QR code will stop working.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Cancel payout')),
        ],
      ),
    );
    if (ok != true) return;
    if (!mounted) return;
    // FR-29: cancelling a waiting payout is a sensitive admin action and must
    // be confirmed with the device biometric prompt first.
    final state = context.read<AppState>();
    if (!state.fingerprintRegistered) {
      await Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => const FingerprintScreen(required: true)));
      if (!mounted || !state.fingerprintRegistered) return;
    }
    final verified = await state.verifyFingerprint(
        'Cancel the PHP ${fmtPhp(c.amount)} payout for ${c.scholarName}?');
    if (!mounted) return;
    if (!verified) {
      showMsg(context, 'Biometrics not verified. Payout not cancelled.',
          error: true);
      return;
    }
    try {
      await context.read<AppState>().wallet.voidClaim(c.id);
      if (!mounted) return;
      showMsg(context, 'Payout cancelled.');
      _load();
    } catch (e) {
      if (mounted) showMsg(context, 'Failed: $e', error: true);
    }
  }

  void _showQr(AllowanceClaim c) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(c.scholarName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                ClaimQrPanel(claim: c, size: 210),
                const SizedBox(height: 8),
                Text('PHP ${fmtPhp(c.amount)} • ${c.status.name.toUpperCase()}',
                    style: const TextStyle(fontSize: 12)),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Close')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final waiting = _claims.where((c) => c.isPending).length;
    final received = _claims.where((c) => c.isReceived).length;
    final reserved = _claims
        .where((c) => c.isPending)
        .fold<double>(0, (s, c) => s + c.amount);

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Payout Monitor'),
        actions: [
          IconButton(
              onPressed: _load, icon: const Icon(Icons.refresh, size: 20))
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Could not load payouts.\n$_error',
                      textAlign: TextAlign.center,
                      maxLines: 5,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppTheme.textMuted)),
                ))
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                      child: Row(
                        children: [
                          _mini('WAITING', '$waiting', AppTheme.warningAmber),
                          const SizedBox(width: 10),
                          _mini('RECEIVED', '$received', AppTheme.successGreen),
                          const SizedBox(width: 10),
                          _mini('RESERVED', 'PHP ${fmtPhp(reserved)}',
                              AppTheme.accentGold),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
                      child: Wrap(
                        spacing: 8,
                        children: [
                          for (final f in [
                            ['all', 'All'],
                            ['waiting', 'Waiting'],
                            ['received', 'Received'],
                            ['cancelled', 'Cancelled'],
                          ])
                            ChoiceChip(
                              label: Text(f[1],
                                  style: const TextStyle(fontSize: 11)),
                              selected: _filter == f[0],
                              onSelected: (_) => setState(() => _filter = f[0]),
                            ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _load,
                        child: _visible.isEmpty
                            ? ListView(
                                children: const [
                                  Padding(
                                    padding: EdgeInsets.all(40),
                                    child: Center(
                                      child: Text('Nothing here yet.',
                                          style: TextStyle(
                                              color: AppTheme.textMuted)),
                                    ),
                                  ),
                                ],
                              )
                            : ListView(
                                padding: const EdgeInsets.all(20),
                                children: _visible.map(_claimCard).toList(),
                              ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _mini(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
            color: color, borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: .8)),
            const SizedBox(height: 4),
            Text(value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
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
            : const StatusChip('WAITING FOR SCAN',
                color: AppTheme.warningAmber, bg: Color(0x22F0A020));
    final when = c.isReceived ? c.claimedAt : c.issuedAt;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.colors.borderSoft),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: c.isReceived
                    ? context.colors.successBg
                    : context.colors.warningBg,
                child: Text(
                    c.scholarName.isNotEmpty
                        ? c.scholarName[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: c.isReceived
                            ? AppTheme.successGreen
                            : AppTheme.warningAmber)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.scholarName,
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: context.colors.textPrimary)),
                    Text(
                      'PHP ${fmtPhp(c.amount)}'
                      '${when != null ? ' • ${DateFormat('MMM d, h:mm a').format(when.toLocal())}' : ''}',
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
              chip,
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: () => _showQr(c),
                  icon: const Icon(Icons.qr_code_2, size: 16),
                  label: const Text('View QR'),
                  style: TextButton.styleFrom(
                      foregroundColor: context.colors.brand),
                ),
              ),
              if (c.isPending)
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => _void(c),
                    icon: const Icon(Icons.cancel_outlined, size: 16),
                    label: const Text('Cancel'),
                    style: TextButton.styleFrom(
                        foregroundColor: AppTheme.dangerRed),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
