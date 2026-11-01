import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';

/// Thrown for expected, user-facing failures (unknown QR, already received...).
class WalletException implements Exception {
  final String message;
  WalletException(this.message);
  @override
  String toString() => message;
}

/// ALL money movement lives here.
///
/// v2 rules (scholar wallet only):
///  * The admin sets ONE standard allowance amount. Every scholar receives
///    exactly that amount — there is no per-scholar amount anywhere.
///  * A payout batch creates one single-use QR claim per scholar.
///  * The scholar confirms receipt by scanning that QR; the claim flips to
///    `received`, the balance is credited and a ledger entry is written.
///  * Cash-out (v3) is a MOCKUP: the scholar links a GCash / Maya / bank
///    account and the app simulates the transfer (balance deducted, simulated
///    reference). No payment gateway is called and no real money moves.
class WalletService {
  final SupabaseClient _db = Supabase.instance.client;

  final Random _rng = Random.secure();

  /// 32-char URL-safe random token embedded in the QR image.
  String newToken() {
    const alphabet =
        'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789';
    return List.generate(32, (_) => alphabet[_rng.nextInt(alphabet.length)])
        .join();
  }

  // ------------------------------------------------- allowance (admin-owned)
  Future<AllowanceSettings> getAllowanceSettings() async {
    try {
      final row = await _db
          .from('allowance_settings')
          .select()
          .eq('id', 1)
          .maybeSingle();
      if (row == null) return AllowanceSettings.fallback;
      return AllowanceSettings.fromMap(Map<String, dynamic>.from(row));
    } catch (_) {
      // Table not migrated yet / offline: fall back to the fixed default so
      // the UI never shows a broken screen.
      return AllowanceSettings.fallback;
    }
  }

  /// Sets the single, uniform allowance. Applies to every scholar at once.
  Future<void> setAllowanceAmount(double amount, {String? label}) async {
    if (amount <= 0) {
      throw WalletException('Allowance amount must be greater than zero.');
    }
    await _db.from('allowance_settings').upsert({
      'id': 1,
      'allowance_amount': amount,
      if (label != null && label.trim().isNotEmpty) 'label': label.trim(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  // ------------------------------------------------------------------ wallet
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

  // -------------------------------------------------------- payout batches
  /// Admin: create a payout batch. The amount is NOT an argument — it is
  /// always the single global allowance, so one scholar can never be paid
  /// more or less than another. Returns the generated claims (each carrying
  /// its own single-use QR token).
  Future<List<AllowanceClaim>> generatePayoutBatch({
    required String batchTitle,
    required List<Scholar> recipients,
  }) async {
    if (recipients.isEmpty ||
        recipients.any((s) =>
            !s.active || s.verificationStatus != VerificationStatus.approved)) {
      throw WalletException('Select only active, verified scholars.');
    }
    final result = await _db.rpc('issue_verified_payout', params: {
      'p_title': batchTitle.trim(),
      'p_recipients': recipients.map((s) => s.id).toList(),
    });
    return (result as List)
        .map((row) =>
            AllowanceClaim.fromMap(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  /// Claims that are still waiting for the scholar to scan their QR.
  Future<List<AllowanceClaim>> getPendingClaims(String scholarId) async {
    try {
      final rows = await _db
          .from('allowance_claims')
          .select()
          .eq('scholar_id', scholarId)
          .eq('status', 'issued')
          .order('issued_at', ascending: false);
      return (rows as List)
          .map((m) =>
              AllowanceClaim.fromMap(Map<String, dynamic>.from(m as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<AllowanceClaim>> getMyClaims(String scholarId,
      {int limit = 60}) async {
    try {
      final rows = await _db
          .from('allowance_claims')
          .select()
          .eq('scholar_id', scholarId)
          .order('issued_at', ascending: false)
          .limit(limit);
      return (rows as List)
          .map((m) =>
              AllowanceClaim.fromMap(Map<String, dynamic>.from(m as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<AllowanceClaim>> getClaimsForBatch(String batchId) async {
    final rows = await _db
        .from('allowance_claims')
        .select('*, profiles(full_name)')
        .eq('batch_id', batchId)
        .order('id');
    return (rows as List)
        .map((m) => AllowanceClaim.fromMap(Map<String, dynamic>.from(m as Map)))
        .toList();
  }

  /// Admin: every claim ever issued, newest first (status oversight).
  Future<List<AllowanceClaim>> getAllClaims({int limit = 200}) async {
    try {
      final rows = await _db
          .from('allowance_claims')
          .select('*, profiles(full_name)')
          .order('issued_at', ascending: false)
          .limit(limit);
      return (rows as List)
          .map((m) =>
              AllowanceClaim.fromMap(Map<String, dynamic>.from(m as Map)))
          .toList();
    } catch (_) {
      final rows = await _db
          .from('allowance_claims')
          .select()
          .order('issued_at', ascending: false)
          .limit(limit);
      return (rows as List)
          .map((m) =>
              AllowanceClaim.fromMap(Map<String, dynamic>.from(m as Map)))
          .toList();
    }
  }

  /// Admin: cancel a claim that was never scanned.
  Future<void> voidClaim(String claimId) async {
    await _db
        .from('allowance_claims')
        .update({'status': 'voided'})
        .eq('id', claimId)
        .eq('status', 'issued');
  }

  /// Read the claim behind a scanned token without redeeming it, so the
  /// scholar can see the amount before confirming with a fingerprint.
  Future<AllowanceClaim?> previewClaim(String token) async {
    try {
      final row = await _db
          .from('allowance_claims')
          .select('*, profiles(full_name)')
          .eq('token', token)
          .maybeSingle();
      if (row == null) return null;
      return AllowanceClaim.fromMap(Map<String, dynamic>.from(row));
    } catch (_) {
      return null;
    }
  }

  /// Admin: how much money is reserved but not yet received (issued claims).
  Future<double> getReservedTotal(String scholarId) async {
    final claims = await getPendingClaims(scholarId);
    return claims.fold<double>(0, (sum, c) => sum + c.amount);
  }

  /// Scholar: confirm receipt of the payout encoded in [token].
  ///
  /// Validation is done server-side inside the `claim_allowance` RPC
  /// (single use, right scholar, not voided) so the balance can never be
  /// credited twice. The lookup below only exists to produce a clear message.
  Future<double> claimAllowance({
    required String token,
    required String scholarId,
  }) async {
    Map<String, dynamic>? row;
    try {
      row = await _db
          .from('allowance_claims')
          .select()
          .eq('token', token)
          .maybeSingle();
    } catch (_) {
      row = null;
    }

    if (row != null) {
      final claim = AllowanceClaim.fromMap(Map<String, dynamic>.from(row));
      if (claim.scholarId != scholarId) {
        throw WalletException(
            'This QR code was issued to another scholar (${claim.scholarName}).');
      }
      if (claim.status == ClaimStatus.received) {
        throw WalletException(
            'Already received on ${_fmt(claim.claimedAt)} — the QR is single use.');
      }
      if (claim.status == ClaimStatus.voided) {
        throw WalletException('This payout was cancelled by the admin.');
      }
    }

    try {
      final res = await _db.rpc('claim_allowance', params: {
        'p_token': token,
        'p_scholar_id': scholarId,
      });
      if (res is num) return res.toDouble();
      if (row != null) return ((row['amount'] ?? 0) as num).toDouble();
      return 0;
    } on PostgrestException catch (e) {
      throw WalletException(_friendlyRpc(e.message));
    } catch (e) {
      throw WalletException(
          'Could not confirm receipt. Check your connection and try again. ($e)');
    }
  }

  String _friendlyRpc(String raw) {
    if (raw.contains('SCHOLAR_NOT_VERIFIED')) {
      return 'Only active, admin-verified scholars can receive allowance.';
    }
    if (raw.contains('CLAIM_ALREADY_RECEIVED')) {
      return 'This payout was already confirmed — each QR can only be used once.';
    }
    if (raw.contains('CLAIM_NOT_FOUND')) {
      return 'This QR code is not a valid Scholar Wallet payout.';
    }
    if (raw.contains('CLAIM_WRONG_SCHOLAR')) {
      return 'This QR code belongs to another scholar.';
    }
    if (raw.contains('CLAIM_VOIDED')) {
      return 'This payout was cancelled by the admin.';
    }
    return 'Could not confirm receipt: $raw';
  }

  String _fmt(DateTime? d) {
    if (d == null) return 'an earlier date';
    String two(int v) => v.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} '
        '${two(d.hour)}:${two(d.minute)}';
  }


  // ------------------------------------------------------------- cash-out
  static const double minCashout = 100;

  Future<List<LinkedAccount>> getLinkedAccounts(String scholarId) async {
    final rows = await _db
        .from('linked_accounts')
        .select()
        .eq('scholar_id', scholarId)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((m) => LinkedAccount.fromMap(Map<String, dynamic>.from(m as Map)))
        .toList();
  }

  Future<void> linkAccount({
    required PayoutProvider provider,
    String bankName = '',
    required String accountName,
    required String accountNumber,
  }) async {
    try {
      await _db.rpc('link_account', params: {
        'p_provider': provider.name,
        'p_bank_name': bankName,
        'p_account_name': accountName,
        'p_account_number': accountNumber,
      });
    } on PostgrestException catch (e) {
      throw WalletException(_friendlyCashout(e.message));
    }
  }

  Future<void> unlinkAccount(int accountId) async {
    try {
      await _db.rpc('unlink_account', params: {'p_account_id': accountId});
    } on PostgrestException catch (e) {
      throw WalletException(_friendlyCashout(e.message));
    }
  }

  /// Simulated cash-out (mockup). Returns nothing; history shows the result.
  Future<void> requestWithdrawal(
      {required int accountId, required double amount}) async {
    try {
      await _db.rpc('request_withdrawal',
          params: {'p_account_id': accountId, 'p_amount': amount});
    } on PostgrestException catch (e) {
      throw WalletException(_friendlyCashout(e.message));
    }
  }

  Future<List<Withdrawal>> getMyWithdrawals(String scholarId,
      {int limit = 50}) async {
    final rows = await _db
        .from('withdrawals')
        .select()
        .eq('scholar_id', scholarId)
        .order('created_at', ascending: false)
        .limit(limit);
    return (rows as List)
        .map((m) => Withdrawal.fromMap(Map<String, dynamic>.from(m as Map)))
        .toList();
  }

  String _friendlyCashout(String raw) {
    const map = {
      'SCHOLAR_NOT_VERIFIED':
          'Only active, admin-verified scholars can cash out.',
      'BAD_MOBILE_NUMBER':
          'Enter an 11-digit mobile number that starts with 09.',
      'BAD_ACCOUNT_NAME': 'Enter the name registered on the account.',
      'BAD_BANK_NAME': 'Enter the bank name.',
      'BAD_ACCOUNT_NUMBER': 'Enter a valid bank account number.',
      'ACCOUNT_ALREADY_LINKED': 'This account is already linked.',
      'ACCOUNT_NOT_FOUND': 'That linked account no longer exists.',
      'BELOW_MINIMUM': 'The amount is below the minimum cash-out.',
      'BAD_AMOUNT': 'Use at most 2 decimal places.',
      'INSUFFICIENT_BALANCE': 'Not enough balance for this cash-out.',
    };
    for (final e in map.entries) {
      if (raw.contains(e.key)) return e.value;
    }
    return 'Cash-out failed: $raw';
  }

  // ---------------------------------------------------------------- admin
  Future<int> getActiveScholarCount() async {
    final rows = await _db
        .from('profiles')
        .select('id')
        .eq('role', 'scholar')
        .eq('is_active', true)
        .eq('verification_status', 'approved');
    return (rows as List).length;
  }

  Future<int> getPendingClaimCount() async {
    try {
      final rows = await _db
          .from('allowance_claims')
          .select('id')
          .eq('status', 'issued');
      return (rows as List).length;
    } catch (_) {
      return 0;
    }
  }

  Future<int> getReceivedClaimCount() async {
    try {
      final rows = await _db
          .from('allowance_claims')
          .select('id')
          .eq('status', 'received');
      return (rows as List).length;
    } catch (_) {
      return 0;
    }
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

  Future<void> setScholarActive(String id, bool active) =>
      _db.rpc('set_verified_scholar_active',
          params: {'p_scholar_id': id, 'p_active': active});

  /// Admin: permanently delete one scholar account and its records.
  Future<void> deleteScholar(String id) async {
    try {
      await _db.rpc('admin_delete_scholar', params: {'p_scholar_id': id});
    } on PostgrestException catch (e) {
      throw WalletException(_deleteError(e));
    }
  }

  /// Admin: delete all finished, inactive scholars (rejected or deactivated,
  /// zero balance). Pending registrations are never touched. Returns count.
  Future<int> deleteInactiveScholars() async {
    try {
      final n = await _db.rpc('admin_delete_inactive_scholars');
      return (n as num?)?.toInt() ?? 0;
    } on PostgrestException catch (e) {
      throw WalletException(_deleteError(e));
    }
  }

  String _deleteError(PostgrestException e) {
    final m = '${e.message} ${e.details}';
    if (m.contains('BALANCE_NOT_ZERO')) {
      return 'This scholar still has a balance. Settle it before deleting.';
    }
    if (m.contains('CANNOT_DELETE_ADMIN')) {
      return 'Admin accounts cannot be deleted.';
    }
    if (m.contains('ADMIN_REQUIRED')) return 'Only an admin can delete accounts.';
    if (m.contains('ACCOUNT_NOT_FOUND')) return 'Account no longer exists.';
    if (m.contains('HAS_LINKED_RECORDS')) {
      return 'Account has linked records and cannot be deleted.';
    }
    return 'Delete failed. Run the latest supabase_setup.sql first. (${e.message})';
  }

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

  /// Admin overview numbers for the dashboard.
  Future<Map<String, num>> getAllowanceSummary() async {
    final settings = await getAllowanceSettings();
    final pending = await getPendingClaimCount();
    final received = await getReceivedClaimCount();
    return {
      'amount': settings.allowanceAmount,
      'pending': pending,
      'received': received,
    };
  }
}