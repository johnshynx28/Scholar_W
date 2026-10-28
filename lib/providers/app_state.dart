import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter/foundation.dart';
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

  // ---- Biometric login state (FR-26) -------------------------------------
  bool biometricEnabled = false;

  /// In-memory only: the password of the CURRENT session, used to enable
  /// biometric login from Settings without asking the user to sign in twice.
  /// Never persisted by AppState itself.
  String? lastLoginPassword;

  Future<void> loadBiometricState() async {
    biometricEnabled = await biometric.isEnabled();
    notifyListeners();
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

  // ---- Theme (light / dark / system), persisted across launches ----------
  // The theme is stored PER ACCOUNT (key: theme_mode_<uid>), so a scholar and
  // an admin sharing one phone each keep their own light/dark choice.
  static const _lastUidKey = 'theme_last_uid';
  String _themeKeyFor(String uid) => 'theme_mode_$uid';
  String? _themeUid; // account whose theme is currently applied
  ThemeMode themeMode = ThemeMode.system;

  ThemeMode _readTheme(SharedPreferences prefs, String uid) {
    final saved = prefs.getString(_themeKeyFor(uid));
    return ThemeMode.values.firstWhere(
      (m) => m.name == saved,
      orElse: () => ThemeMode.system,
    );
  }

  /// Called once at app start: re-applies the last signed-in account's theme
  /// so there is no light/dark flash while the session restores.
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

  /// Called after sign-in: loads THIS account's saved theme.
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

  Future<void> refreshBalance() async {
    if (user == null) return;
    final newBalance = await wallet.getBalance(user!.id);
    if (newBalance == balance) return; // avoid needless rebuilds
    balance = newBalance;
    notifyListeners();
  }

  Future<void> logout() async {
    await auth.signOut();
    user = null;
    balance = 0;
    lastLoginPassword = null;
    // NOTE: biometric credentials are intentionally KEPT on sign-out —
    // they are what lets the user sign back in with a fingerprint (FR-26).
    // They are only erased when the user turns biometric login OFF.
    _themeUid = null;
    themeMode = ThemeMode.system;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_lastUidKey);
    } catch (_) {}
    notifyListeners();
  }
}
