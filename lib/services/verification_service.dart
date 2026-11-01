import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';

/// Verifies an existing scholarship beneficiary, not an application for funding.
class VerificationService {
  final SupabaseClient _db = Supabase.instance.client;

  Future<List<AppUser>> registrations() async {
    final rows = await _db
        .from('profiles')
        .select()
        .eq('role', 'scholar')
        .order('created_at', ascending: false);
    return rows.map((r) => AppUser.fromMap(r)).toList();
  }

  Future<List<Map<String, dynamic>>> history(String scholarId) async {
    final rows = await _db
        .from('registration_reviews')
        .select()
        .eq('scholar_id', scholarId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> review(
      AppUser registration, VerificationStatus decision, String notes) async {
    if (decision == VerificationStatus.pending) {
      throw ArgumentError('Select a review decision.');
    }
    if ((decision == VerificationStatus.rejected ||
            decision == VerificationStatus.needsInfo) &&
        notes.trim().isEmpty) {
      throw ArgumentError('Explain the reason or information required.');
    }
    await _db.rpc('review_registration', params: {
      'p_scholar_id': registration.id,
      'p_expected_status': registration.verificationStatus.databaseValue,
      'p_decision': decision.databaseValue,
      'p_notes': notes.trim(),
      'p_roster_checked': decision == VerificationStatus.approved,
    });
  }

  Future<void> resubmit(
      {required bool declaredScholar,
      required String scholarshipName,
      required String scholarshipReference}) async {
    await _db.rpc('resubmit_registration', params: {
      'p_declared_scholar': declaredScholar,
      'p_scholarship_name': scholarshipName.trim(),
      'p_scholarship_reference': scholarshipReference.trim(),
    });
  }
}
