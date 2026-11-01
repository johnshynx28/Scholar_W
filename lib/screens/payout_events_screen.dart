import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../models/models.dart';
import '../widgets/widgets.dart';
import 'admin/issue_payout_screen.dart';

/// Payout events are existing disbursement batches, not attendance events.
/// No generic event QR is accepted by the allowance scanner.
class PayoutEventsScreen extends StatefulWidget {
  const PayoutEventsScreen({super.key});
  @override
  State<PayoutEventsScreen> createState() => _PayoutEventsScreenState();
}

class _PayoutEventsScreenState extends State<PayoutEventsScreen> {
  List<Map<String, dynamic>> _events = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final state = context.read<AppState>();
      List<Map<String, dynamic>> events;
      if (state.user!.role == UserRole.admin) {
        events = await state.wallet.getDisbursements();
      } else {
        // RLS returns only this scholar's claims. No recipient list is exposed.
        final claims = await state.wallet.getMyClaims(state.user!.id);
        final batches = <String, Map<String, dynamic>>{};
        for (final c in claims) {
          batches[c.batchId] = {
            'title': c.batchTitle,
            'amount_per_scholar': c.amount,
            'status': c.status.name,
            'created_at': c.issuedAt?.toIso8601String()
          };
        }
        events = batches.values.toList();
      }
      if (mounted) {
        setState(() {
          _events = events;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
            () => _error = 'Could not load payout events. Pull down to retry.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AppState>().user?.role == UserRole.admin;
    return Scaffold(
      appBar: AppBar(title: const Text('Payout Events')),
      floatingActionButton: admin
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.add),
              label: const Text('Issue payout'),
              onPressed: () async {
                await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const IssuePayoutScreen()));
                if (mounted) await _load();
              })
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                children: [
                  const Text(
                      'Each payout event is an allowance distribution batch. It has one single-use payout QR per recipient. Attendance/event QR codes cannot release allowance.'),
                  const SizedBox(height: 16),
                  if (_error != null)
                    Text(_error!)
                  else if (_events.isEmpty)
                    const Text('No payout events have been issued yet.'),
                  ..._events.map((e) => Card(
                          child: ListTile(
                        leading: const Icon(Icons.event_available_outlined),
                        title: Text('${e["title"]}'),
                        subtitle: Text(
                            'Issued: ${e["created_at"] ?? "—"}\nStatus: ${e["status"]}'
                            '${admin ? "\nRecipients: ${e["recipient_count"]}" : ""}'),
                        trailing: Text(
                            'PHP ${fmtPhp(((e["amount_per_scholar"] ?? 0) as num).toDouble())}'),
                      ))),
                  const SizedBox(height: 80),
                ],
              )),
    );
  }
}
