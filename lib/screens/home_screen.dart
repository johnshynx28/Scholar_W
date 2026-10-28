import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/app_state.dart';
import '../models/models.dart';
import '../widgets/widgets.dart';
import 'withdrawal_screen.dart';
import 'expense_screen.dart';
import 'history_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<WalletTransaction> _recent = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final state = context.read<AppState>();
    await state.refreshBalance();
    try {
      final uid = state.user!.id;
      final txs = await state.wallet.getTransactions(uid, limit: 20);
      // FR-17: expense reports also appear in Recent Activity with a status.
      final expenses = await state.wallet.getMyExpenses(uid);
      final items = <WalletTransaction>[
        ...txs,
        ...expenses.map((e) => WalletTransaction(
              id: e.id ?? '',
              title: 'Expense: ${e.title}',
              subtitle: e.category,
              amount: -e.amount,
              type: TxType.debit,
              status: e.status,
              createdAt: e.createdAt ?? DateTime.now(),
            )),
      ];
      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _recent = items.take(4).toList();
    } catch (_) {
      _recent = [];
    }
    if (mounted) setState(() => _loading = false);
  }

  // ---- Settings sheet: biometric toggle (FR-26) ---------------------------

  Future<String?> _askPassword() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm password'),
        content: TextField(
          controller: controller,
          obscureText: true,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Enter your password'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: const Text('Confirm')),
        ],
      ),
    );
  }

  Future<bool> _enableBiometrics() async {
    final state = context.read<AppState>();
    if (!await state.biometric.deviceSupportsBiometrics()) {
      if (mounted) {
        showMsg(context, 'No fingerprint or face is enrolled on this device.',
            error: true);
      }
      return false;
    }
    // Verify the password before saving it for biometric sign-in.
    final pw = await _askPassword();
    if (pw == null || pw.isEmpty) return false;
    try {
      await state.auth.signIn(email: state.user!.email, password: pw);
      await state.enableBiometric(state.user!.email, pw);
      if (mounted) showMsg(context, 'Biometric login enabled.');
      return true;
    } catch (_) {
      if (mounted) showMsg(context, 'Incorrect password.', error: true);
      return false;
    }
  }

  void _openSettings() {
    final state = context.read<AppState>();
    bool enabled = state.biometricEnabled;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(
                title: Text('Settings',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.fingerprint),
                title: const Text('Biometric login'),
                subtitle: const Text(
                    'Sign in with your fingerprint or face (FR-26)'),
                value: enabled,
                onChanged: (v) async {
                  if (v) {
                    final ok = await _enableBiometrics();
                    if (ok) setS(() => enabled = true);
                  } else {
                    await state.disableBiometric();
                    setS(() => enabled = false);
                    if (mounted) {
                      showMsg(context, 'Biometric login turned off.');
                    }
                  }
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final user = state.user;
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
                const ThemeToggleButton(color: Colors.white),
                IconButton(
                  tooltip: 'Settings (biometric login)',
                  icon: const Icon(Icons.settings_outlined,
                      color: Colors.white),
                  onPressed: _openSettings,
                ),
                IconButton(
                  icon: const Icon(Icons.notifications_outlined,
                      color: Colors.white),
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const HistoryScreen())),
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
                    const SizedBox(height: 28),
                    const SectionLabel('QUICK ACCESS'),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        QuickAction(
                          icon: Icons.north_east_rounded,
                          label: 'Request\nPayout',
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      const WithdrawalScreen())),
                        ),
                        QuickAction(
                          icon: Icons.history_rounded,
                          label: 'History',
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      const HistoryScreen())),
                        ),
                        QuickAction(
                          icon: Icons.upload_file_rounded,
                          label: 'Upload\nReceipt',
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const ExpenseScreen())),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
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
