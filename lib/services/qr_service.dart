import 'dart:convert';

/// QR payload used to confirm that a scholar physically received an allowance.
///
/// The admin generates one QR per scholar per payout batch. The QR carries a
/// single-use random `token`; the broker (Supabase RPC `claim_allowance`)
/// checks the authenticated recipient and verification status. QR text alone
/// is never proof of identity or a trusted source for the amount.
class ClaimQrPayload {
  static const String type = 'scholar_wallet_claim_v1';

  final String token;
  final String claimId;
  final String scholarId;
  final double amount;

  const ClaimQrPayload({
    required this.token,
    this.claimId = '',
    this.scholarId = '',
    this.amount = 0,
  });

  String encode() => jsonEncode({
        't': type,
        'tok': token,
        'cid': claimId,
        'sid': scholarId,
        'amt': amount,
      });

  /// Returns null when the scanned code is not a Scholar Wallet claim QR.
  static ClaimQrPayload? tryParse(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;
    try {
      final decoded = jsonDecode(text);
      if (decoded is Map) {
        if (decoded['t'] != type) return null;
        final token = (decoded['tok'] ?? '').toString();
        if (token.isEmpty) return null;
        final amt = decoded['amt'];
        return ClaimQrPayload(
          token: token,
          claimId: (decoded['cid'] ?? '').toString(),
          scholarId: (decoded['sid'] ?? '').toString(),
          amount: amt is num ? amt.toDouble() : 0,
        );
      }
    } catch (_) {
      // Not JSON — fall through to plain-token support below.
    }
    // Manual entry support: a bare 32-char token is also accepted.
    if (RegExp(r'^[A-Za-z0-9]{16,64}$').hasMatch(text)) {
      return ClaimQrPayload(token: text);
    }
    return null;
  }
}
