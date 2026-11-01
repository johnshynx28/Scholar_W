import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../services/qr_service.dart';
import '../services/wallet_service.dart';
import '../theme/app_theme.dart';
import '../widgets/widgets.dart';
import 'fingerprint_screen.dart';
import 'payout_confirmation_screen.dart';

/// Scholar: scan the QR code the ADMIN issued for this payout.
///
/// Flow: camera detects QR -> look up the claim -> confirm with fingerprint ->
/// server-side single-use redemption -> balance credited.
class ScanClaimScreen extends StatefulWidget {
  const ScanClaimScreen({super.key});

  @override
  State<ScanClaimScreen> createState() => _ScanClaimScreenState();
}

class _ScanClaimScreenState extends State<ScanClaimScreen> {
  late final MobileScannerController _controller;
  bool _handling = false;
  bool _cameraError = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      formats: const [BarcodeFormat.qrCode],
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handling) return;
    final raw = capture.barcodes
        .map((b) => b.rawValue)
        .firstWhere((v) => v != null && v.isNotEmpty, orElse: () => null);
    if (raw == null) return;
    final payload = ClaimQrPayload.tryParse(raw);
    if (payload == null) {
      setState(() => _message =
          'Not a payout QR. Attendance/event QR codes cannot release allowance.');
      return;
    }
    await _handleToken(payload.token);
  }

  Future<void> _handleToken(String token) async {
    if (_handling) return;
    setState(() {
      _handling = true;
      _message = null;
    });
    var leaving = false;
    final state = context.read<AppState>();
    try {
      // Pause camera detections while another route, dialog or OS prompt is open.
      try {
        await _controller.stop();
      } catch (_) {}
      await state.refreshProfile();
      if (!mounted) return;
      if (state.user?.canReceiveAllowance != true) {
        throw WalletException(
            'Only active, admin-verified scholars can receive allowance.');
      }
      final preview = await state.wallet.previewClaim(token);
      if (!mounted) return;
      if (preview == null) {
        throw WalletException('This is not a valid payout QR.');
      }
      if (preview.scholarId != state.user!.id) {
        throw WalletException(
            'This payout QR does not belong to your account.');
      }
      if (!preview.isPending) {
        throw WalletException(preview.isReceived
            ? 'Already received — each payout QR can only be used once.'
            : 'This payout was cancelled by the administrator.');
      }
      // Amount is reviewed BEFORE either biometric setup or confirmation.
      final confirmed = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => PayoutConfirmationScreen(claim: preview),
          ));
      if (!mounted || confirmed != true) return;
      if (!state.fingerprintRegistered) {
        await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => const FingerprintScreen(required: true),
            ));
        if (!mounted || !state.fingerprintRegistered) return;
      }
      final verified = await state.verifyFingerprint(
          'Confirm allowance receipt: PHP ${fmtPhp(preview.amount)}');
      if (!mounted) return;
      if (!verified) {
        throw WalletException(
            'Biometrics not verified. Allowance receipt was not recorded.');
      }
      final amount = await state.wallet
          .claimAllowance(token: token, scholarId: state.user!.id);
      // Receipt already succeeded: a refresh failure must not imply it failed.
      var balanceUpdated = true;
      try {
        await state.refreshBalance();
      } catch (_) {
        balanceUpdated = false;
      }
      if (!mounted) return;
      await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
                icon: const Icon(Icons.check_circle,
                    color: AppTheme.successGreen, size: 54),
                title: const Text('Allowance received'),
                content: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('PHP ${fmtPhp(amount)}',
                      style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.successGreen)),
                  const SizedBox(height: 6),
                  Text(balanceUpdated
                      ? 'New balance: PHP ${fmtPhp(state.balance)}'
                      : 'Receipt saved. Refresh your wallet to see the new balance.'),
                ]),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Done'))
                ],
              ));
      if (mounted) {
        leaving = true;
        Navigator.pop(context, true);
      }
    } on WalletException catch (e) {
      if (mounted) showMsg(context, e.message, error: true);
    } catch (_) {
      if (mounted) {
        showMsg(context,
            'Could not finish. Refresh My Payouts to check receipt status before trying again.',
            error: true);
      }
    } finally {
      if (mounted && !leaving) {
        setState(() => _handling = false);
        if (!_cameraError) {
          try {
            await _controller.start();
          } catch (_) {}
        }
      }
    }
  }

  /// Pick a saved/screenshotted Payout QR image from the gallery and read it.
  Future<void> _pickFromGallery() async {
    if (_handling) return;
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null || !mounted) return;
    try {
      final capture = await _controller.analyzeImage(picked.path);
      if (!mounted) return;
      if (capture == null || capture.barcodes.isEmpty) {
        setState(() => _message = 'No QR code found in that image.');
        return;
      }
      await _onDetect(capture);
    } catch (_) {
      if (mounted) {
        setState(() => _message = 'Could not read that image. Try another one.');
      }
    }
  }

  Future<void> _manualEntry() async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enter payout code'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
              hintText: 'Paste the code printed under the QR'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('Continue')),
        ],
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));
    controller.dispose();
    if (!mounted || code == null || code.isEmpty) return;
    final parsed = ClaimQrPayload.tryParse(code);
    if (parsed == null) {
      showMsg(context,
          'Invalid payout code. Event or attendance QR codes are not supported here.',
          error: true);
      return;
    }
    await _handleToken(parsed.token);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        leading: const BackButton(),
        title: const Text('Scan Allowance QR'),
      ),
      body: Column(
        children: [
          Expanded(
            child: _cameraError
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.no_photography_outlined,
                              color: Colors.white54, size: 54),
                          const SizedBox(height: 12),
                          const Text(
                            'Camera is not available on this device.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton(
                            onPressed: _manualEntry,
                            style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(color: Colors.white38)),
                            child: const Text('Enter code manually'),
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            onPressed: _pickFromGallery,
                            icon: const Icon(Icons.photo_library_outlined,
                                size: 18),
                            label: const Text('Pick QR from gallery'),
                            style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(color: Colors.white38)),
                          ),
                        ],
                      ),
                    ),
                  )
                : Stack(
                    alignment: Alignment.center,
                    children: [
                      MobileScanner(
                        controller: _controller,
                        onDetect: _onDetect,
                        errorBuilder: (context, error, child) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted && !_cameraError) {
                              setState(() => _cameraError = true);
                            }
                          });
                          return const SizedBox.shrink();
                        },
                      ),
                      IgnorePointer(
                        child: Container(
                          width: 235,
                          height: 235,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: .85),
                                width: 3),
                          ),
                        ),
                      ),
                      if (_handling)
                        Container(
                          color: Colors.black54,
                          child: const Center(
                            child:
                                CircularProgressIndicator(color: Colors.white),
                          ),
                        ),
                    ],
                  ),
          ),
          Container(
            width: double.infinity,
            color: Colors.black,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              children: [
                const Text(
                  'Point the camera at the QR code from the admin, or pick it from your gallery',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                if (_message != null) ...[
                  const SizedBox(height: 8),
                  Text(_message!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: AppTheme.warningAmber, fontSize: 12)),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _manualEntry,
                        icon: const Icon(Icons.keyboard, size: 18),
                        label: _actionLabel('Code'),
                        style: _actionStyle(Colors.white, Colors.white38),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickFromGallery,
                        icon: const Icon(Icons.photo_library_outlined, size: 18),
                        label: _actionLabel('Gallery'),
                        style: _actionStyle(Colors.white, Colors.white38),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const FingerprintScreen()),
                        ),
                        icon: Icon(
                            state.fingerprintRegistered
                                ? Icons.fingerprint
                                : Icons.fingerprint_outlined,
                            size: 18),
                        label: _actionLabel(state.fingerprintRegistered
                            ? 'Verified'
                            : 'Register'),
                        style: _actionStyle(
                            state.fingerprintRegistered
                                ? AppTheme.successGreen
                                : Colors.white,
                            state.fingerprintRegistered
                                ? AppTheme.successGreen
                                : Colors.white38),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Label for the bottom action buttons. Never wraps: it shrinks a little
  /// instead (large system font sizes, narrow phones).
  Widget _actionLabel(String text) => FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(text, maxLines: 1, softWrap: false),
      );

  /// Compact style so three buttons fit side by side. The default 16dp side
  /// padding left only ~40dp for the text, which made it wrap letter by letter.
  ButtonStyle _actionStyle(Color foreground, Color border) =>
      OutlinedButton.styleFrom(
        foregroundColor: foreground,
        side: BorderSide(color: border),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
      );
}