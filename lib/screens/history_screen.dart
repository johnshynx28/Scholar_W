import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/app_state.dart';
import '../models/models.dart';
import '../widgets/widgets.dart';

/// FR-12/FR-13/FR-14 — full transaction history, grouped by month, with
/// search and a credit/debit filter.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

enum _Filter { all, credit, debit }

class _HistoryScreenState extends State<HistoryScreen> {
  List<WalletTransaction> _all = [];
  String _query = '';
  _Filter _filter = _Filter.all;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final state = context.read<AppState>();
    try {
      _all = await state.wallet.getTransactions(state.user!.id, limit: 200);
    } catch (_) {
      _all = [];
    }
    if (mounted) setState(() => _loading = false);
  }

  List<WalletTransaction> get _filtered => _all.where((t) {
        final matchesQuery =
            t.title.toLowerCase().contains(_query.toLowerCase()) ||
                t.subtitle.toLowerCase().contains(_query.toLowerCase());
        final matchesFilter = switch (_filter) {
          _Filter.all => true,
          _Filter.credit => t.type == TxType.credit,
          _Filter.debit => t.type == TxType.debit,
        };
        return matchesQuery && matchesFilter;
      }).toList();

  /// FR-13: group entries under a "Month Year" header.
  List<Widget> _grouped(List<WalletTransaction> txs) {
    final widgets = <Widget>[];
    String? lastKey;
    for (final t in txs) {
      final key = DateFormat('MMMM yyyy').format(t.createdAt.toLocal());
      if (key != lastKey) {
        lastKey = key;
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 6),
          child: Text(key,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textMuted)),
        ));
      }
      widgets.add(TxTile(tx: t));
    }
    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return Scaffold(
      appBar: AppBar(
          leading: const BackButton(),
          title: const Text('Transaction History')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: const InputDecoration(
                hintText: 'Search transactions...',
                prefixIcon: Icon(Icons.search, size: 20),
              ),
            ),
          ),
          // FR-14 filter chips
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Row(
              children: [
                _chip('All', _Filter.all),
                const SizedBox(width: 8),
                _chip('Credits (+)', _Filter.credit),
                const SizedBox(width: 8),
                _chip('Debits (−)', _Filter.debit),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? const Center(
                        child: Text('No transactions found.',
                            style: TextStyle(color: AppTheme.textMuted)))
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView(
                          padding: const EdgeInsets.all(20),
                          children: _grouped(filtered),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, _Filter f) {
    final selected = _filter == f;
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: selected,
      onSelected: (_) => setState(() => _filter = f),
    );
  }
}
