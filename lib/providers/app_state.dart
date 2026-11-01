import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart' show BiometricType;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/wallet_service.dart';
import '../services/biometric_service.dart';

class AppState extends ChangeNotifier {
  final AuthService auth = AuthService();
  final WalletService wallet = WalletService();
  final BiometricService biometric = BiometricService();

  AppUser? user;
  double balance = 0;
  bool loading = false;

  /// Single, uniform allowance set by the admin. Never per-scholar.
  AllowanceSettings allowance = AllowanceSettings.fallback;

  // ---- Biometrics (FR-26): registration + optional biometric login -------
  bool biometricEnabled = false; // biometric LOGIN turned on
  bool fingerprintRegistered = false; // fingerprint REGISTERED on this device
  DateTime? fingerprintEnrolledAt;
  List<BiometricType> availableBiometrics = const [];

  Future<void> loadBiometricState() async {
    try {
      biometricEnabled = await biometric.isEnabled();
      final uid = auth.currentFirebaseUser?.uid;
      if (uid != null) {
        fingerprintRegistered = await biometric.isRegisteredFor(uid);
        fingerprintEnrolledAt = await biometric.enrolledAt();
      }
      availableBiometrics = await biometric.enrolledBiometrics();
    } catch (_) {}
    notifyListeners();
  }

  /// Registers the device fingerprint for the signed-in scholar.
  /// Returns null on success, or a user-facing error message.
  Future<String?> registerFingerprint() async {
    final uid = user?.id ?? auth.currentFirebaseUser?.uid;
    if (uid == null) return 'Sign in again to register your fingerprint.';
    if (!await biometric.deviceSupportsBiometrics()) {
      return 'This device has no biometric hardware available.';
    }
    final ok = await biometric.register(uid);
    if (!ok) {
      return 'Fingerprint registration cancelled or failed. '
          'Add a fingerprint in your phone settings, then try again.';
    }
    fingerprintRegistered = true;
    fingerprintEnrolledAt = await biometric.enrolledAt();
    notifyListeners();
    return null;
  }

  Future<void> removeFingerprint() async {
    final uid = user?.id ?? auth.currentFirebaseUser?.uid;
    if (uid != null) await biometric.unregister(uid);
    fingerprintRegistered = false;
    fingerprintEnrolledAt = null;
    biometricEnabled = false;
    notifyListeners();
  }

  /// Gate an action behind the registered fingerprint. Returns true when the
  /// OS verified the biometric (or when nothing is registered — the caller
  /// decides whether that is acceptable).
  Future<bool> verifyFingerprint(String reason) async {
    if (!fingerprintRegistered) return false;
    return biometric.verify(reason: reason);
  }

  Future<void> enableBiometric(String email, String password) async {
    await biometric.enable(email, password);
    biometricEnabled = true;
    notifyListeners();
  }

  Future<void> disableBiometric() async {
    await biometric.disable();
    biometricEnabled = false;
    notifyListeners();
  }

  // ---- Allowance setting ------------------------------------------------
  Future<void> loadAllowanceSettings() async {
    final fresh = await wallet.getAllowanceSettings();
    if (fresh.allowanceAmount == allowance.allowanceAmount &&
        fresh.label == allowance.label) {
      return;
    }
    allowance = fresh;
    notifyListeners();
  }

  Future<void> updateAllowance(double amount, {String? label}) async {
    await wallet.setAllowanceAmount(amount, label: label);
    allowance = AllowanceSettings(
      allowanceAmount: amount,
      label: label?.trim().isNotEmpty == true ? label!.trim() : allowance.label,
      updatedAt: DateTime.now(),
    );
    notifyListeners();
  }

  /// In-memory only: the password of the CURRENT session, used to enable
  /// biometric login without asking the scholar to sign in twice.
  String? lastLoginPassword;

  // ---- Theme (light / dark / system), persisted per account --------------
  static const _lastUidKey = 'theme_last_uid';
  String _themeKeyFor(String uid) => 'theme_mode_$uid';
  String? _themeUid;
  ThemeMode themeMode = ThemeMode.system;

  ThemeMode _readTheme(SharedPreferences prefs, String uid) {
    final saved = prefs.getString(_themeKeyFor(uid));
    return ThemeMode.values.firstWhere(
      (m) => m.name == saved,
      orElse: () => ThemeMode.system,
    );
  }

  Future<void> loadThemeMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final uid = prefs.getString(_lastUidKey);
      if (uid != null) {
        _themeUid = uid;
        themeMode = _readTheme(prefs, uid);
      }
    } catch (_) {
      themeMode = ThemeMode.system;
    }
  }

  Future<void> loadThemeForUser(String uid) async {
    _themeUid = uid;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastUidKey, uid);
      themeMode = _readTheme(prefs, uid);
    } catch (_) {
      themeMode = ThemeMode.system;
    }
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (mode == themeMode) return;
    themeMode = mode;
    notifyListeners();
    final uid = _themeUid;
    if (uid == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themeKeyFor(uid), mode.name);
    } catch (_) {}
  }

  Future<void> refreshProfile() async {
    user = await auth.currentAppUser();
    notifyListeners();
  }

  Future<void> refreshBalance() async {
    if (user == null) return;
    final newBalance = await wallet.getBalance(user!.id);
    if (newBalance == balance) return;
    balance = newBalance;
    notifyListeners();
  }

  Future<void> logout() async {
    // Clear the remembered login email BEFORE signing out, so the login screen
    // that appears right after sign-out starts with an empty email field.
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('remember_email');
    } catch (_) {}
    await auth.signOut();
    user = null;
    balance = 0;
    lastLoginPassword = null;
    fingerprintRegistered = false;
    fingerprintEnrolledAt = null;
    // NOTE: biometric login credentials are intentionally KEPT on sign-out —
    // they are what lets the scholar sign back in with a fingerprint.
    _themeUid = null;
    themeMode = ThemeMode.system;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_lastUidKey);
    } catch (_) {}
    notifyListeners();
  }
}
