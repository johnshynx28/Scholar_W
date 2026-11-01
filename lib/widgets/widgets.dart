import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../providers/app_state.dart';

final _php = NumberFormat('#,##0.00', 'en_PH');
String fmtPhp(double v) => _php.format(v.abs());

/// Gold balance card from the Home mockup.
class BalanceCard extends StatelessWidget {
  final double balance;
  const BalanceCard({super.key, required this.balance});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.accentGold, Color(0xFFC79034)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppTheme.accentGold.withValues(alpha: .35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('CURRENT BALANCE',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: .85),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2)),
              const Icon(Icons.account_balance_wallet_outlined,
                  color: Colors.white70, size: 18),
            ],
          ),
          const SizedBox(height: 8),
          Text('PHP ${fmtPhp(balance)}',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Row(children: [
            Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                  color: AppTheme.successGreen, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text('Money received and verified by QR',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: .85), fontSize: 12)),
          ]),
        ],
      ),
    );
  }
}

/// "Reserved for you" panel: the admin already set this money aside and the
/// scholar only has to scan the QR code to receive it.
class ReservedCard extends StatelessWidget {
  final double reserved;
  final int pendingCount;
  final VoidCallback onScan;

  const ReservedCard({
    super.key,
    required this.reserved,
    required this.pendingCount,
    required this.onScan,
  });

  @override
  Widget build(BuildContext context) {
    final hasPending = pendingCount > 0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.colors.goldTint,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasPending ? AppTheme.accentGold : context.colors.borderSoft,
          width: hasPending ? 1.4 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.qr_code_2_rounded,
                  color: AppTheme.accentGold, size: 20),
              const SizedBox(width: 8),
              Text('RESERVED FOR YOU',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                      color: context.colors.textLabel)),
              const Spacer(),
              if (hasPending)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.accentGold.withValues(alpha: .18),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text('$pendingCount WAITING',
                      style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.accentGold)),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text('PHP ${fmtPhp(reserved)}',
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: context.colors.textPrimary)),
          const SizedBox(height: 4),
          Text(
            hasPending
                ? 'Scan the QR code from the admin to receive this allowance. '
                    'It can only be scanned once.'
                : 'No allowance waiting. The admin will issue a QR code when '
                    'the next payout is released.',
            style: TextStyle(fontSize: 12, color: context.colors.textBody),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onScan,
              icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
              label: Text(hasPending ? 'Scan QR to Receive' : 'Open Scanner'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentGold,
                minimumSize: const Size.fromHeight(46),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Fingerprint registration status + call to action.
class BiometricStatusCard extends StatelessWidget {
  final bool registered;
  final DateTime? enrolledAt;
  final VoidCallback onTap;

  const BiometricStatusCard({
    super.key,
    required this.registered,
    required this.enrolledAt,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color:
                registered ? context.colors.borderSoft : AppTheme.warningAmber,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: registered
                    ? context.colors.successBg
                    : context.colors.warningBg,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(
                registered ? Icons.fingerprint : Icons.fingerprint_outlined,
                color:
                    registered ? AppTheme.successGreen : AppTheme.warningAmber,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    registered
                        ? 'Fingerprint registered'
                        : 'Register your fingerprint',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: context.colors.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    registered
                        ? (enrolledAt != null
                            ? 'Required to confirm allowance payouts • '
                                '${DateFormat('MMM d, yyyy').format(enrolledAt!.toLocal())}'
                            : 'Required to confirm allowance payouts')
                        : 'Required before you can receive an allowance payout.',
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: context.colors.hint),
          ],
        ),
      ),
    );
  }
}

/// Quick-access icon button.
class QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const QuickAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: context.colors.border),
            ),
            child: Icon(icon, color: context.colors.brand, size: 26),
          ),
          const SizedBox(height: 8),
          Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: context.colors.textPrimary)),
        ],
      ),
    );
  }
}

/// Transaction list tile used on Home and History.
class TxTile extends StatelessWidget {
  final WalletTransaction tx;
  const TxTile({super.key, required this.tx});

  @override
  Widget build(BuildContext context) {
    final isCredit = tx.type == TxType.credit;
    final color = isCredit ? AppTheme.successGreen : AppTheme.dangerRed;
    final bg = isCredit ? context.colors.successBg : context.colors.dangerBg;
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
          CircleAvatar(
            radius: 20,
            backgroundColor: bg,
            child: Icon(isCredit ? Icons.add : Icons.remove,
                color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tx.title,
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: context.colors.textPrimary)),
                const SizedBox(height: 2),
                Text(tx.subtitle,
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.textMuted)),
              ],
            ),
          ),
          tx.status == TxStatus.pending
              ? Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: context.colors.warningBg,
                      borderRadius: BorderRadius.circular(8)),
                  child: const Text('Pending',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.warningAmber)),
                )
              : Text(
                  '${isCredit ? '+' : '-'}${fmtPhp(tx.amount)}',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 14, color: color),
                ),
        ],
      ),
    );
  }
}

/// Small colored status chip.
class StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  final Color? bg;
  const StatusChip(this.label,
      {super.key, this.color = AppTheme.successGreen, this.bg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: bg ?? context.colors.successBg,
          borderRadius: BorderRadius.circular(8)),
      child: Text(label,
          style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: .6,
              color: color)),
    );
  }
}

/// Renders the single-use QR for one allowance claim.
class ClaimQrPanel extends StatelessWidget {
  final AllowanceClaim claim;
  final double size;
  const ClaimQrPanel({super.key, required this.claim, this.size = 190});

  @override
  Widget build(BuildContext context) {
    final received = claim.isReceived;
    final voided = claim.isVoided;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.borderSoft),
      ),
      child: Column(
        children: [
          Opacity(
            opacity: (received || voided) ? .25 : 1,
            child: SizedBox(
              width: size,
              height: size,
              child: QrImageView(
                data: claim.qrPayload,
                version: QrVersions.auto,
                size: size,
                gapless: true,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: Color(0xFF1A2530),
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: Color(0xFF1A2530),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SelectableText(
            claim.token,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 10,
                letterSpacing: .5,
                color: AppTheme.textMuted,
                fontFamily: 'monospace'),
          ),
        ],
      ),
    );
  }
}

/// Snackbar helper.
void showMsg(BuildContext context, String msg, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(msg),
    backgroundColor: error ? AppTheme.dangerRed : AppTheme.successGreen,
    behavior: SnackBarBehavior.floating,
  ));
}

/// App-bar / header button that flips between light and dark mode.
class ThemeToggleButton extends StatelessWidget {
  final Color? color;
  const ThemeToggleButton({super.key, this.color});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return IconButton(
      tooltip: isDark ? 'Switch to light mode' : 'Switch to dark mode',
      icon: Icon(
        isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
        color: color,
      ),
      onPressed: () => context
          .read<AppState>()
          .setThemeMode(isDark ? ThemeMode.light : ThemeMode.dark),
    );
  }
}

/// Scholar: shows the Payout QR issued to them. They can screenshot it and
/// later choose the image from the gallery inside the scanner. The QR alone
/// is not proof of identity: the server still checks the signed-in scholar,
/// the payout status, and that the QR was not used before.
Future<void> showPayoutQrSheet(BuildContext context, AllowanceClaim claim,
    {VoidCallback? onScan}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Allowance ready: PHP ${fmtPhp(claim.amount)}',
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(claim.batchTitle,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
            const SizedBox(height: 14),
            ClaimQrPanel(claim: claim, size: 220),
            const SizedBox(height: 12),
            const Text(
              'Take a screenshot of this QR, then tap Scan and choose it from your gallery. It can only be used once.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
            if (onScan != null) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    onScan();
                  },
                  icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                  label: const Text('Scan to receive'),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}