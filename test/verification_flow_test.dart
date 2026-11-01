import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scholar_wallet/models/models.dart';
import 'package:scholar_wallet/services/qr_service.dart';
import 'package:scholar_wallet/screens/payout_confirmation_screen.dart';

Map<String, dynamic> profile(
        {String status = 'pending',
        bool active = false,
        String role = 'scholar'}) =>
    {
      'id': 'student-1',
      'full_name': 'Test Scholar',
      'email': 'test@school.edu',
      'verification_status': status,
      'is_active': active,
      'role': role,
      'declared_scholar': true,
      'scholarship_name': 'School Merit Award',
    };

void main() {
  group('registration eligibility', () {
    for (final status in [
      'pending',
      'under_review',
      'needs_info',
      'rejected'
    ]) {
      test(
          '$status cannot receive allowance even if active was incorrectly set',
          () {
        expect(
            AppUser.fromMap(profile(status: status, active: true))
                .canReceiveAllowance,
            false);
      });
    }
    test('approved and active scholar can receive allowance', () {
      expect(
          AppUser.fromMap(profile(status: 'approved', active: true))
              .canReceiveAllowance,
          true);
    });
    test('approved but suspended scholar cannot receive', () {
      expect(AppUser.fromMap(profile(status: 'approved')).canReceiveAllowance,
          false);
    });
    test('admin is not a scholar payout recipient', () {
      expect(
          AppUser.fromMap(
                  profile(status: 'approved', active: true, role: 'admin'))
              .canReceiveAllowance,
          false);
    });
    test('old profile without verification fields fails closed', () {
      expect(
          AppUser.fromMap(
                  {'id': 'old', 'full_name': 'Legacy', 'is_active': true})
              .canReceiveAllowance,
          false);
    });
    test('unknown status fails closed', () {
      expect(
          AppUser.fromMap(profile(status: 'anything', active: true))
              .canReceiveAllowance,
          false);
    });
    test('database status round trips', () {
      for (final status in VerificationStatus.values) {
        expect(verificationStatusFrom(status.databaseValue), status);
      }
    });
    test('scholar declarations stay distinct from verified status', () {
      final user = AppUser.fromMap(profile());
      expect(user.declaredScholar, true);
      expect(user.scholarshipName, 'School Merit Award');
      expect(user.canReceiveAllowance, false);
    });
  });

  group('payout QR vs event QR', () {
    const payload = ClaimQrPayload(
        token: '1234567890abcdefghijklmnopqrstuv',
        claimId: '12',
        scholarId: 'student-1',
        amount: 5000);
    test('valid payout payload round trips', () {
      final result = ClaimQrPayload.tryParse(payload.encode());
      expect(result?.token, payload.token);
      expect(result?.claimId, '12');
      expect(result?.amount, 5000);
    });
    test('generated claim QR is understood by scanner', () {
      final c = AllowanceClaim(
          id: '12',
          batchId: 'b',
          batchTitle: 'Allowance',
          scholarId: 'student-1',
          scholarName: 'Scholar',
          amount: 5000,
          token: payload.token);
      expect(ClaimQrPayload.tryParse(c.qrPayload)?.token, payload.token);
    });
    test('attendance and generic event QR rejected', () {
      expect(
          ClaimQrPayload.tryParse(
              '{"t":"event_attendance_v1","tok":"${payload.token}"}'),
          null);
      expect(ClaimQrPayload.tryParse('https://example.org/events/123'), null);
    });
    test('empty token rejected', () {
      expect(
          ClaimQrPayload.tryParse('{"t":"scholar_wallet_claim_v1","tok":""}'),
          null);
    });
    test('invalid JSON and empty input rejected', () {
      for (final text in ['', '  ', '{bad}', '[1,2]', '123']) {
        expect(ClaimQrPayload.tryParse(text), null);
      }
    });
    test('printed 32-character code supported', () {
      expect(ClaimQrPayload.tryParse(payload.token)?.token, payload.token);
    });
  });

  const claim = _ClaimFixture();
  testWidgets(
      'amount, recipient, payout event and biometric action are visible',
      (tester) async {
    await tester.pumpWidget(
        MaterialApp(home: PayoutConfirmationScreen(claim: claim.build())));
    expect(find.text('Review Allowance Amount'), findsOneWidget);
    expect(find.textContaining('5,000'), findsOneWidget);
    expect(find.text('Recipient: Test Scholar'), findsOneWidget);
    expect(find.text('Payout event: October Allowance'), findsOneWidget);
    expect(find.text('Continue to Biometrics'), findsOneWidget);
    expect(find.textContaining('does not transfer cash'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('cancel returns false without confirming receipt',
      (tester) async {
    bool? result;
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () async {
                      result = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                              builder: (_) => PayoutConfirmationScreen(
                                  claim: claim.build())));
                    },
                    child: const Text('Open'))))));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Cancel'), 200);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(result, false);
  });

  testWidgets(
      'continue requests biometrics without claiming payout on amount screen',
      (tester) async {
    bool? result;
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () async {
                      result = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                              builder: (_) => PayoutConfirmationScreen(
                                  claim: claim.build())));
                    },
                    child: const Text('Open'))))));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Continue to Biometrics'), 200);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue to Biometrics'));
    await tester.pumpAndSettle();
    expect(result, true);
  });
}

class _ClaimFixture {
  const _ClaimFixture();
  AllowanceClaim build() => AllowanceClaim(
      id: '12',
      batchId: 'batch-1',
      batchTitle: 'October Allowance',
      scholarId: 'student-1',
      scholarName: 'Test Scholar',
      amount: 5000,
      token: '1234567890abcdefghijklmnopqrstuv');
}
