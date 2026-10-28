import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// FR-26 / FR-27 — Optional biometric login (fingerprint / face).
///
/// Biometric data is handled ONLY by the device's secure hardware via
/// Android BiometricPrompt (Android 10+). Scholar Wallet never sees, stores,
/// or transmits fingerprint/face data. What IS stored on-device (and never
/// leaves it) is the login email + password used to re-authenticate with
/// Firebase after the biometric prompt succeeds. If biometrics are
/// unavailable, not enrolled, or fail, the app falls back to email+password.
class BiometricService {
  final LocalAuthentication _localAuth = LocalAuthentication();

  static const _kEnabled = 'bio_enabled';
  static const _kEmail = 'bio_email';
  static const _kPassword = 'bio_password';

  /// True when the device hardware supports biometrics or device credentials.
  Future<bool> deviceSupportsBiometrics() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final supported = await _localAuth.isDeviceSupported();
      return canCheck || supported;
    } catch (_) {
      return false;
    }
  }

  /// Shows the OS biometric prompt. Returns true only when the OS verified
  /// the enrolled fingerprint/face. Returns false on cancel/failure — the
  /// caller then falls back to email+password (FR-27).
  Future<bool> authenticate() async {
    try {
      return await _localAuth.authenticate(
        localizedReason: 'Verify your identity to sign in to Scholar Wallet',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }

  Future<bool> isEnabled() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_kEnabled) ?? false;
  }

  /// Enable biometric login for this device (FR-26).
  Future<void> enable(String email, String password) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kEnabled, true);
    await p.setString(_kEmail, email.trim());
    await p.setString(_kPassword, password);
  }

  /// Turn biometric login off at any time (FR-26).
  Future<void> disable() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kEnabled, false);
    await p.remove(_kEmail);
    await p.remove(_kPassword);
  }

  /// Credentials saved on-device for biometric sign-in, or null if disabled.
  Future<(String email, String password)?> savedCredentials() async {
    final p = await SharedPreferences.getInstance();
    if (!(p.getBool(_kEnabled) ?? false)) return null;
    final email = p.getString(_kEmail);
    final password = p.getString(_kPassword);
    if (email == null || password == null) return null;
    return (email, password);
  }
}
