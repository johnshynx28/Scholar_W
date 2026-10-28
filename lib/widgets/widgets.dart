import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
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
              const Icon(Icons.more_horiz, color: Colors.white70),
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
            Text('Real-time disbursed',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: .85), fontSize: 12)),
          ]),
        ],
      ),
    );
  }
}

/// Quick-access icon button (Request Payout / History / Upload Receipt).
class QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const QuickAction(
      {super.key,
      required this.icon,
      required this.label,
      required this.onTap});

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

/// Transaction list tile used on Home (recent activity) and History.
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

/// Small colored status chip (COMPLETED / ONLINE etc).
class StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  final Color? bg; // defaults to the theme's success background
  const StatusChip(this.label,
      {super.key, this.color = AppTheme.successGreen, this.bg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration:
          BoxDecoration(
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

/// Snackbar helper.
void showMsg(BuildContext context, String msg, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(msg),
    backgroundColor: error ? AppTheme.dangerRed : AppTheme.successGreen,
    behavior: SnackBarBehavior.floating,
  ));
}

/// App-bar / header button that flips between light and dark mode.
/// The choice is saved by [AppState.setThemeMode].
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
