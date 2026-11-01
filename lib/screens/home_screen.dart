import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/app_state.dart';
import '../models/models.dart';
import '../widgets/widgets.dart';
import 'scan_claim_screen.dart';
import 'history_screen.dart';
import 'fingerprint_screen.dart';
import 'cashout_screen.dart';
import 'claims_screen.dart';
import 'verification_screen.dart';
import 'payout_events_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<WalletTransaction> _recent = [];
  List<AllowanceClaim> _pending = [];
  bool _loading = true;
  Timer? _poll;
  Set<String>? _seenPending;
  bool _announced = false;

  @override
  void initState() {
    super.initState();
    _load();
    _poll = Timer.periodic(const Duration(seconds: 15), (_) => _checkNewQr());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  /// In-app notification: a new payout QR was issued to this scholar.
  Future<void> _checkNewQr() async {
    try {
      final state = context.read<AppState>();
      if (state.user?.canReceiveAllowance != true) return;
      final pending = await state.wallet.getPendingClaims(state.user!.id);
      final ids = pending.map((c) => c.id).toSet();
      final seen = _seenPending;
      _seenPending = ids;
      if (seen != null && mounted) {
        final fresh = pending.where((c) => !seen.contains(c.id)).toList();
        if (fresh.isNotEmpty) {
          final total = fresh.fold<double>(0, (s, c) => s + c.amount);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('New allowance from admin: PHP ${fmtPhp(total)}. Scan the QR to receive it.'),
            action: SnackBarAction(label: 'SCAN', onPressed: _openScanner),
            duration: const Duration(seconds: 10),
          ));
        }
        if (seen.length != ids.length || fresh.isNotEmpty) _load();
      }
    } catch (_) {}
  }

  Future<void> _load() async {
    final state = context.read<AppState>();
    try {
      await state.refreshProfile();
      if (state.user?.canReceiveAllowance != true) return;
      await state.refreshBalance();
      await state.loadAllowanceSettings();
      final uid = state.user!.id;
      final txs = await state.wallet.getTransactions(uid, limit: 20);
      final items = <WalletTransaction>[
        ...txs,
      ];
      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _recent = items.take(4).toList();
      _pending = await state.wallet.getPendingClaims(uid);
      _seenPending ??= _pending.map((c) => c.id).toSet();
      if (!_announced && _pending.isNotEmpty && mounted) {
        _announced = true;
        final total = _pending.fold<double>(0, (s, c) => s + c.amount);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'You have ${_pending.length} allowance(s) waiting: PHP ${fmtPhp(total)}. Scan the QR from the admin to receive it.'),
            action: SnackBarAction(label: 'SCAN', onPressed: _openScanner),
            duration: const Duration(seconds: 10),
          ));
        });
      }
    } catch (_) {
      _recent = [];
      _pending = [];
    }
    if (mounted) setState(() => _loading = false);
  }

  void _showNotifications() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Notifications',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              if (_pending.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                      child: Text('No new notifications.',
                          style: TextStyle(color: AppTheme.textMuted))),
                )
              else
                ..._pending.map((c) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(
                          child: Icon(Icons.qr_code_2_rounded)),
                      title: Text('Allowance ready: PHP ${fmtPhp(c.amount)}'),
                      subtitle: Text(
                          '${c.batchTitle}\nTap to see your QR, then scan it to receive.'),
                      isThreeLine: true,
                      onTap: () {
                        Navigator.pop(ctx);
                        showPayoutQrSheet(context, c, onScan: _openScanner);
                      },
                    )),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openScanner() async {
    final state = context.read<AppState>();
    await state.refreshProfile();
    if (!mounted || state.user?.canReceiveAllowance != true) return;

    if (!mounted) return;
    final received = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const ScanClaimScreen()),
    );
    if (received == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final user = state.user;
    final reserved = _pending.fold<double>(0, (s, c) => s + c.amount);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 120,
              pinned: true,
              backgroundColor: context.colors.header,
              shape: const RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.vertical(bottom: Radius.circular(24)),
              ),
              title: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.white24,
                    child: Text(user?.initials ?? '?',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14)),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user?.fullName ?? 'Scholar',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700)),
                      Text(
                          user?.studentNumber?.isNotEmpty == true
                              ? 'ID: ${user!.studentNumber}'
                              : (user?.email ?? ''),
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 11)),
                    ],
                  ),
                ],
              ),
              actions: [
                IconButton(
                  tooltip: 'Notifications',
                  icon: Badge(
                    isLabelVisible: _pending.isNotEmpty,
                    label: Text('${_pending.length}'),
                    child: const Icon(Icons.notifications_outlined,
                        color: Colors.white),
                  ),
                  onPressed: _showNotifications,
                ),
                const ThemeToggleButton(color: Colors.white),
                IconButton(
                  tooltip: 'Settings',
                  icon:
                      const Icon(Icons.settings_outlined, color: Colors.white),
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const SettingsScreen())),
                ),
                IconButton(
                  icon: const Icon(Icons.logout, color: Colors.white),
                  onPressed: () => state.logout(),
                ),
              ],
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    BalanceCard(balance: state.balance),
                    const SizedBox(height: 16),
                    ReservedCard(
                      reserved: reserved,
                      pendingCount: _pending.length,
                      onScan: _openScanner,
                    ),
                    const SizedBox(height: 16),
                    BiometricStatusCard(
                      registered: state.fingerprintRegistered,
                      enrolledAt: state.fingerprintEnrolledAt,
                      onTap: () async {
                        await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const FingerprintScreen()));
                        if (mounted) setState(() {});
                      },
                    ),
                    const SizedBox(height: 26),
                    SectionLabel(
                      'STANDARD ALLOWANCE',
                      trailing: Text(
                          'PHP ${fmtPhp(state.allowance.allowanceAmount)}',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: context.colors.brand)),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${state.allowance.label} — the same amount for every '
                      'scholar. Set by the admin.',
                      style: TextStyle(
                          fontSize: 12, color: context.colors.textBody),
                    ),
                    const SizedBox(height: 26),
                    ListTile(
                      leading: const Icon(Icons.event_outlined),
                      title: const Text('Payout Events'),
                      subtitle:
                          const Text('View the payout batches issued to you'),
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const PayoutEventsScreen())),
                    ),
                    const SectionLabel('QUICK ACCESS'),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        QuickAction(
                          icon: Icons.qr_code_scanner_rounded,
                          label: 'Receive\nAllowance',
                          onTap: _openScanner,
                        ),
                        QuickAction(
                          icon: Icons.receipt_long_rounded,
                          label: 'My\nPayouts',
                          onTap: () async {
                            await Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const ClaimsScreen()));
                            _load();
                          },
                        ),
                        QuickAction(
                          icon: Icons.payments_outlined,
                          label: 'Cash\nOut',
                          onTap: () async {
                            await Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const CashoutScreen()));
                            _load();
                          },
                        ),
                        QuickAction(
                          icon: Icons.school_rounded,
                          label: 'Scholar\nVerification',
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const VerificationScreen())),
                        ),
                      ],
                    ),
                    const SizedBox(height: 26),
                    SectionLabel(
                      'RECENT ACTIVITY',
                      trailing: GestureDetector(
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const HistoryScreen())),
                        child: Text('View All',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: context.colors.brand)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_loading)
                      const Center(
                          child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(),
                      ))
                    else if (_recent.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(
                          child: Text('No activity yet.',
                              style: TextStyle(color: AppTheme.textMuted)),
                        ),
                      )
                    else
                      ..._recent.map((tx) => TxTile(tx: tx)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}