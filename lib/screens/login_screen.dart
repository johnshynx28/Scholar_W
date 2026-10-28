import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../providers/app_state.dart';
import '../widgets/widgets.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _remember = true;
  bool _obscure = true;
  bool _busy = false;
  bool _bioBusy = false;
  bool _bioAvailable = false;
  bool _autoPrompted = false;

  static const _kRememberEmail = 'remember_email';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final state = context.read<AppState>();
    // FR-03 "Remember me": prefill the last used email.
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_kRememberEmail);
      if (saved != null && mounted) setState(() => _email.text = saved);
    } catch (_) {}

    // FR-26: biometric sign-in is offered only when it was enabled before.
    final creds = await state.biometric.savedCredentials();
    final supported = await state.biometric.deviceSupportsBiometrics();
    if (!mounted) return;
    setState(() => _bioAvailable = supported && creds != null);
    if (_bioAvailable && !_autoPrompted) {
      _autoPrompted = true;
      _bioLogin(); // show the biometric prompt right away
    }
  }

  Future<void> _login() async {
    if (_email.text.isEmpty || _password.text.isEmpty) {
      showMsg(context, 'Enter your email and password.', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      final state = context.read<AppState>();
      state.user = await state.auth
          .signIn(email: _email.text, password: _password.text);
      state.lastLoginPassword = _password.text;
      // FR-03 "Remember me": persist (or clear) the email.
      try {
        final prefs = await SharedPreferences.getInstance();
        if (_remember) {
          await prefs.setString(_kRememberEmail, _email.text.trim());
        } else {
          await prefs.remove(_kRememberEmail);
        }
      } catch (_) {}
      // AuthGate rebuilds automatically via authState stream.
    } catch (e) {
      if (mounted) {
        showMsg(context, context.read<AppState>().auth.friendlyError(e),
            error: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// FR-26/FR-27: biometric prompt -> on success sign in with the on-device
  /// credentials; on failure/cancel the user simply uses the form above.
  Future<void> _bioLogin() async {
    final state = context.read<AppState>();
    final creds = await state.biometric.savedCredentials();
    if (creds == null) {
      showMsg(
          context, 'Enable biometric login in Settings after signing in.',
          error: true);
      return;
    }
    setState(() => _bioBusy = true);
    final ok = await state.biometric.authenticate();
    if (!ok) {
      // FR-27 fallback: biometrics unavailable/failed -> password form stays.
      if (mounted) setState(() => _bioBusy = false);
      return;
    }
    try {
      state.user =
          await state.auth.signIn(email: creds.$1, password: creds.$2);
      state.lastLoginPassword = creds.$2;
    } catch (e) {
      if (mounted) {
        showMsg(
            context,
            'Saved credentials no longer work. '
            'Please sign in with your password.',
            error: true);
        await state.disableBiometric();
        setState(() => _bioAvailable = false);
      }
    } finally {
      if (mounted) setState(() => _bioBusy = false);
    }
  }

  Future<void> _forgot() async {
    if (_email.text.isEmpty) {
      showMsg(context, 'Type your email first.', error: true);
      return;
    }
    try {
      await context.read<AppState>().auth.sendPasswordReset(_email.text);
      if (mounted) showMsg(context, 'Password reset email sent.');
    } catch (e) {
      if (mounted) {
        showMsg(context, context.read<AppState>().auth.friendlyError(e),
            error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const SizedBox(height: 48),
              Container(
                width: 74,
                height: 74,
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(Icons.school_rounded,
                    color: Colors.white, size: 38),
              ),
              const SizedBox(height: 18),
              const Text('Scholar',
                  style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primaryBlue)),
              const Text('Wallet',
                  style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.accentGold)),
              const SizedBox(height: 12),
              const Text(
                'Simplifying financial allowances and\nexpense tracking for your scholar life.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
              ),
              const SizedBox(height: 24),
              Container(
                height: 110,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFFFCF7EA),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.account_balance_wallet_outlined,
                    size: 52, color: AppTheme.accentGold),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  hintText: 'Email address',
                  prefixIcon: Icon(Icons.mail_outline, size: 20),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _password,
                obscureText: _obscure,
                decoration: InputDecoration(
                  hintText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline, size: 20),
                  suffixIcon: IconButton(
                    icon: Icon(
                        _obscure
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 20),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: Checkbox(
                        value: _remember,
                        onChanged: (v) =>
                            setState(() => _remember = v ?? true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text('Remember me',
                        style: TextStyle(
                            fontSize: 12, color: AppTheme.textMuted)),
                  ]),
                  GestureDetector(
                    onTap: _forgot,
                    child: const Text('Forgot password?',
                        style: TextStyle(
                            fontSize: 12, color: AppTheme.textMuted)),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _busy ? null : _login,
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B5BDB)),
                child: _busy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Login'),
              ),
              // ---- FR-26 biometric sign-in ---------------------------------
              if (_bioAvailable) ...[
                const SizedBox(height: 16),
                Row(children: [
                  const Expanded(child: Divider()),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Text('or',
                        style: TextStyle(
                            fontSize: 12, color: AppTheme.textMuted)),
                  ),
                  const Expanded(child: Divider()),
                ]),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _bioBusy ? null : _bioLogin,
                  icon: _bioBusy
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.fingerprint, size: 26),
                  label: const Text('Sign in with biometrics'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryBlue,
                    minimumSize: const Size.fromHeight(52),
                    side: const BorderSide(color: AppTheme.primaryBlue),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Don't have an account? ",
                      style: TextStyle(
                          fontSize: 12, color: AppTheme.textMuted)),
                  GestureDetector(
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => Theme(
                                data: AppTheme.light,
                                child: const SignupScreen()))),
                    child: const Text('Sign up',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primaryBlue)),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
