import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';

class WalletService {
  final SupabaseClient _db = Supabase.instance.client;
  static const String receiptBucket = 'receipts';

  // ---------------------------------------------------------------- wallet
  Future<double> getBalance(String scholarId) async {
    final row = await _db
        .from('profiles')
        .select('balance')
        .eq('id', scholarId)
        .maybeSingle();
    if (row == null) return 0;
    return ((row['balance'] ?? 0) as num).toDouble();
  }

  Future<List<WalletTransaction>> getTransactions(String scholarId,
      {int limit = 50}) async {
    final rows = await _db
        .from('transactions')
        .select()
        .eq('scholar_id', scholarId)
        .order('created_at', ascending: false)
        .limit(limit);
    return (rows as List)
        .map((m) => WalletTransaction.fromMap(m as Map<String, dynamic>))
        .toList();
  }

  // ------------------------------------------------------------ withdrawal
  /// FR-09/FR-11: save the request as Pending AND mirror it into the
  /// transaction history so the scholar immediately sees a Pending entry.
  Future<void> createWithdrawal(WithdrawalRequest req) async {
    await _db.from('withdrawals').insert(req.toInsert());
    await _db.from('transactions').insert({
      'scholar_id': req.scholarId,
      'title': '${req.paymentMethod} Withdrawal',
      'subtitle': 'Pending approval',
      'amount': -req.amount,
      'type': 'debit',
      'status': 'pending',
    });
  }

  Future<List<WithdrawalRequest>> getPendingWithdrawals() async {
    final rows = await _db
        .from('withdrawals')
        .select('*, profiles!inner(full_name)')
        .eq('status', 'pending')
        .order('created_at', ascending: false);
    return (rows as List).map((raw) {
      final m = Map<String, dynamic>.from(raw as Map);
      m['scholar_name'] = (m['profiles']?['full_name'] ?? 'Scholar');
      return WithdrawalRequest.fromMap(m);
    }).toList();
  }

  /// Approve: mark approved, debit scholar balance, and flip the pending
  /// history entry to completed (FR-11 / FR-12 / FR-22).
  Future<void> approveWithdrawal(WithdrawalRequest req) async {
    await _db
        .from('withdrawals')
        .update({'status': 'approved'}).eq('id', req.id);
    await _db.rpc('adjust_balance', params: {
      'p_scholar_id': req.scholarId,
      'p_delta': -req.amount,
    });
    await _db
        .from('transactions')
        .update({'status': 'completed', 'subtitle': 'Paid out'})
        .eq('scholar_id', req.scholarId)
        .eq('type', 'debit')
        .eq('status', 'pending')
        .eq('amount', -req.amount);
  }

  /// Reject: mark rejected and flip the pending history entry (FR-11/FR-22).
  Future<void> rejectWithdrawal(WithdrawalRequest req) async {
    await _db
        .from('withdrawals')
        .update({'status': 'rejected'}).eq('id', req.id);
    await _db
        .from('transactions')
        .update({'status': 'rejected', 'subtitle': 'Rejected'})
        .eq('scholar_id', req.scholarId)
        .eq('type', 'debit')
        .eq('status', 'pending')
        .eq('amount', -req.amount);
  }

  // --------------------------------------------------------------- expense
  /// Upload receipt image (bytes, works on web + mobile) to Supabase Storage,
  /// return public URL.
  Future<String> uploadReceipt(
      Uint8List bytes, String ext, String scholarId) async {
    final e = ext.toLowerCase();
    final path = '$scholarId/${const Uuid().v4()}.$e';
    final contentType = e == 'png' ? 'image/png' : 'image/jpeg';
    await _db.storage.from(receiptBucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType),
        );
    return _db.storage.from(receiptBucket).getPublicUrl(path);
  }

  Future<void> submitExpense(ExpenseReport report) =>
      _db.from('expenses').insert(report.toInsert());

  /// Scholar: their own expense reports (FR-17 Recent Activity).
  Future<List<ExpenseReport>> getMyExpenses(String scholarId) async {
    final rows = await _db
        .from('expenses')
        .select()
        .eq('scholar_id', scholarId)
        .order('created_at', ascending: false)
        .limit(20);
    return (rows as List)
        .map((m) => ExpenseReport.fromMap(Map<String, dynamic>.from(m as Map)))
        .toList();
  }

  /// Admin: all expense reports, newest first (with the scholar's name).
  Future<List<ExpenseReport>> getExpenses() async {
    List rows;
    try {
      rows = await _db
          .from('expenses')
          .select('*, profiles(full_name)')
          .order('id', ascending: false);
    } catch (_) {
      // Fallback if the profiles relationship isn't available.
      rows = await _db.from('expenses').select().order('id', ascending: false);
    }
    return rows
        .map((m) =>
            ExpenseReport.fromMap(Map<String, dynamic>.from(m as Map)))
        .toList();
  }

  /// Admin: set status to 'completed' (approved) or 'rejected'.
  Future<void> setExpenseStatus(String id, String status) =>
      _db.from('expenses').update({'status': status}).eq('id', id);

  // ---------------------------------------------------------------- admin
  Future<int> getActiveScholarCount() async {
    final rows = await _db.from('profiles').select('id').eq('role', 'scholar');
    return (rows as List).length;
  }

  Future<int> getPendingCashoutCount() async {
    final rows =
        await _db.from('withdrawals').select('id').eq('status', 'pending');
    return (rows as List).length;
  }

  Future<List<Scholar>> getScholars() async {
    final rows = await _db
        .from('profiles')
        .select()
        .eq('role', 'scholar')
        .order('full_name');
    return (rows as List)
        .map((m) => Scholar.fromMap(m as Map<String, dynamic>))
        .toList();
  }

  /// FR-23: activate/deactivate a scholar (controls who receives allowance).
  Future<void> setScholarActive(String id, bool active) =>
      _db.from('profiles').update({'is_active': active}).eq('id', id);

  /// Disburse the same amount to many scholars in one batch (FR-21).
  Future<void> disburseAllowance({
    required String batchTitle,
    required double amount,
    required List<Scholar> recipients,
  }) async {
    final batchId = const Uuid().v4();
    await _db.from('disbursements').insert({
      'id': batchId,
      'title': batchTitle,
      'amount_per_scholar': amount,
      'recipient_count': recipients.length,
      'status': 'completed',
    });
    for (final s in recipients) {
      await _db.rpc('adjust_balance', params: {
        'p_scholar_id': s.id,
        'p_delta': amount,
      });
      await _db.from('transactions').insert({
        'scholar_id': s.id,
        'title': batchTitle,
        'subtitle': 'Disbursed',
        'amount': amount,
        'type': 'credit',
        'status': 'completed',
        'batch_id': batchId,
      });
    }
  }

  /// FR-24: all disbursement batches, newest first (for audit reports).
  Future<List<Map<String, dynamic>>> getDisbursements() async {
    final rows = await _db
        .from('disbursements')
        .select()
        .order('created_at', ascending: false)
        .limit(50);
    return (rows as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }
}
