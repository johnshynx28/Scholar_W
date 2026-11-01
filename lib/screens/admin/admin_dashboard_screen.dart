import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../providers/app_state.dart';
import '../../widgets/widgets.dart';
import 'allowance_settings_screen.dart';
import 'issue_payout_screen.dart';
import 'claims_monitor_screen.dart';
import 'manage_scholars_screen.dart';
import 'reports_screen.dart';
import 'registration_review_screen.dart';
import '../../services/verification_service.dart';
import '../../models/models.dart';
import '../payout_events_screen.dart';

/// Admin home. Everything the admin can do to the scholar wallet:
/// set the ONE standard allowance, issue QR payouts, monitor claims.
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});
  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _scholars = 0;
  int _waiting = 0;
  int _received = 0;
  double _reserved = 0;
  Timer? _poll;
  Set<String>? _seenReceived;
  final _verification = VerificationService();
  List<AppUser> _pendingRegs = [];
  Set<String>? _seenRegs;
  bool _announced = false;

  @override
  void initState() {
    super.initState();
    _load();
    _poll = Timer.periodic(const Duration(seconds: 15), (_) => _checkReceived());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _loadRegistrations({bool announce = false}) async {
    try {
      final all = await _verification.registrations();
      final pending = all
          .where((u) => u.verificationStatus == VerificationStatus.pending)
          .toList();
      final ids = pending.map((u) => u.id).toSet();
      final seen = _seenRegs;
      _seenRegs = ids;
      if (mounted) setState(() => _pendingRegs = pending);
      if (!mounted) return;
      if (seen == null) {
        // First load: remind the admin once if registrations are waiting.
        if (announce && !_announced && pending.isNotEmpty) {
          _announced = true;
          _notifyRegs(
              '${pending.length} registration(s) waiting for verification.');
        }
      } else {
        for (final u in pending.where((u) => !seen.contains(u.id))) {
          _notifyRegs(
              'New registration: ${u.fullName}'
              '${(u.studentNumber ?? '').isNotEmpty ? ' (${u.studentNumber})' : ''}.');
        }
      }
    } catch (_) {}
  }

  void _notifyRegs(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      action: SnackBarAction(label: 'REVIEW', onPressed: _openRegistrations),
      duration: const Duration(seconds: 8),
    ));
  }

  Future<void> _openRegistrations() async {
    await Navigator.push(context,
        MaterialPageRoute(builder: (_) => const RegistrationReviewScreen()));
    _load();
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
              if (_pendingRegs.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                      child: Text('No registrations waiting.',
                          style: TextStyle(color: AppTheme.textMuted))),
                )
              else
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: _pendingRegs
                        .map((u) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const CircleAvatar(
                                  child: Icon(Icons.person_add_alt_1)),
                              title: Text('${u.fullName} registered'),
                              subtitle: Text(
                                  '${u.studentNumber ?? '—'} • ${u.university ?? '—'}\nWaiting for verification'),
                              isThreeLine: true,
                              onTap: () {
                                Navigator.pop(ctx);
                                _openRegistrations();
                              },
                            ))
                        .toList(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// In-app notification: tell the admin when a scholar scans + confirms.
  Future<void> _checkReceived() async {
    await _loadRegistrations();
    if (!mounted) return;
    final wallet = context.read<AppState>().wallet;
    try {
      final claims = await wallet.getAllClaims(limit: 300);
      final received = claims.where((c) => c.isReceived).toList();
      final ids = received.map((c) => c.id).toSet();
      final seen = _seenReceived;
      _seenReceived = ids;
      if (seen != null && mounted) {
        for (final c in received.where((c) => !seen.contains(c.id))) {
          showMsg(context,
              '${c.scholarName} received PHP ${fmtPhp(c.amount)} (QR scanned + biometrics verified).');
        }
        _load();
      }
    } catch (_) {}
  }

  Future<void> _load() async {
    final state = context.read<AppState>();
    try {
      _scholars = await state.wallet.getActiveScholarCount();
      final claims = await state.wallet.getAllClaims(limit: 300);
      _waiting = claims.where((c) => c.isPending).length;
      _received = claims.where((c) => c.isReceived).length;
      _seenReceived ??= claims.where((c) => c.isReceived).map((c) => c.id).toSet();
      _reserved = claims
          .where((c) => c.isPending)
          .fold<double>(0, (s, c) => s + c.amount);
      await state.loadAllowanceSettings();
    } catch (_) {}
    await _loadRegistrations(announce: true);
    if (mounted) setState(() {});
  }

  Future<void> _setAllowance() async {
    await Navigator.push(context,
        MaterialPageRoute(builder: (_) => const AllowanceSettingsScreen()));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            icon: Badge(
              isLabelVisible: _pendingRegs.isNotEmpty,
              label: Text('${_pendingRegs.length}'),
              child: const Icon(Icons.notifications_outlined),
            ),
            onPressed: _showNotifications,
          ),
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
            // The single allowance that applies to every scholar.
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.primaryBlue, Color(0xFF14467F)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('STANDARD ALLOWANCE — SAME FOR ALL SCHOLARS',
                      style: TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1)),
                  const SizedBox(height: 8),
                  Text('PHP ${fmtPhp(state.allowance.allowanceAmount)}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(
                    '${state.allowance.label} • cannot be edited per scholar',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: _setAllowance,
                    icon: const Icon(Icons.tune, size: 18),
                    label: const Text('Change Standard Allowance'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white54),
                      minimumSize: const Size.fromHeight(44),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                _statCard('ACTIVE SCHOLARS', '$_scholars', AppTheme.accentGold,
                    Icons.groups_outlined),
                const SizedBox(width: 12),
                _statCard('WAITING QR', '$_waiting', AppTheme.warningAmber,
                    Icons.qr_code_2_rounded),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _statCard('RECEIVED', '$_received', AppTheme.successGreen,
                    Icons.verified_outlined),
                const SizedBox(width: 12),
                _statCard('RESERVED', 'PHP ${fmtPhp(_reserved)}',
                    AppTheme.textMuted, Icons.lock_clock_outlined),
              ],
            ),
            const SizedBox(height: 24),
            const SectionLabel('ADMINISTRATIVE CONTROLS'),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () async {
                await Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const IssuePayoutScreen()));
                _load();
              },
              icon: const Icon(Icons.payments_outlined),
              label: const Text('Disburse Allowance'),
              style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52)),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _control(Icons.fact_check_outlined, 'Payout\nMonitor',
                      () async {
                    await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ClaimsMonitorScreen()));
                    _load();
                  }),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _control(Icons.group_outlined, 'Manage\nScholars',
                      () async {
                    await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ManageScholarsScreen()));
                    _load();
                  }),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _control(Icons.assessment_outlined, 'Disbursement Reports',
                () async {
              await Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ReportsScreen()));
            }),
            const SizedBox(height: 12),
            _control(Icons.school_outlined,
                _pendingRegs.isEmpty
                    ? 'Registration Verification'
                    : 'Registration Verification (${_pendingRegs.length} new)',
                () async {
              await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const RegistrationReviewScreen()));
              _load();
            }),
            const SizedBox(height: 24),
            _control(Icons.event_outlined, 'Payout Events', () async {
              await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const PayoutEventsScreen()));
              _load();
            }),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _statCard(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: color, borderRadius: BorderRadius.circular(14)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.white70, size: 14),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: .8)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }

  /// A tappable control tile. It fills the width it is given, so it works both
  /// as a bare ListView child and inside an `Expanded` in a Row. It must NOT
  /// return an `Expanded` itself: Expanded is only legal directly inside a
  /// Row/Column/Flex, and putting it in a ListView crashes release builds
  /// (the grey screen).
  Widget _control(IconData icon, String label, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: context.colors.brand,
          backgroundColor: context.colors.surface,
          padding: const EdgeInsets.symmetric(vertical: 16),
          side: BorderSide(color: context.colors.border),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 22),
            const SizedBox(height: 6),
            Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, height: 1.2)),
          ],
        ),
      ),
    );
  }
}