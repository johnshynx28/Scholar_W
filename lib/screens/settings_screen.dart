import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/widgets.dart';
import 'fingerprint_screen.dart';

/// Scholar settings: fingerprint registration, biometric login, theme,
/// sign out. Cash-out accounts are managed in Cash Out > Manage.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _kRememberEmail = 'remember_email';

  Future<String?> _askPassword() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm password'),
        content: TextField(
          controller: controller,
          obscureText: true,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Enter your password'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: const Text('Confirm')),
        ],
      ),
    );
  }

  Future<bool> _enableBiometricLogin() async {
    final state = context.read<AppState>();
    if (!state.fingerprintRegistered) {
      showMsg(context, 'Register your fingerprint first.', error: true);
      return false;
    }
    final pw = await _askPassword();
    if (pw == null || pw.isEmpty) return false;
    try {
      await state.auth.signIn(email: state.user!.email, password: pw);
      await state.enableBiometric(state.user!.email, pw);
      if (mounted) showMsg(context, 'Biometric login enabled.');
      return true;
    } catch (_) {
      if (mounted) showMsg(context, 'Incorrect password.', error: true);
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final user = state.user;
    return Scaffold(
      appBar:
          AppBar(leading: const BackButton(), title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.colors.borderSoft),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: context.colors.brand.withValues(alpha: .12),
                  child: Text(user?.initials ?? '?',
                      style: TextStyle(
                          color: context.colors.brand,
                          fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user?.fullName ?? 'Scholar',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: context.colors.textPrimary)),
                      Text(user?.email ?? '',
                          style: const TextStyle(
                              fontSize: 11, color: AppTheme.textMuted)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const SectionLabel('SECURITY'),
          const SizedBox(height: 10),
          _tile(
            icon: state.fingerprintRegistered
                ? Icons.fingerprint
                : Icons.fingerprint_outlined,
            title: state.fingerprintRegistered
                ? 'Fingerprint registered'
                : 'Register fingerprint',
            subtitle: state.fingerprintRegistered
                ? 'Used to confirm allowance payouts'
                : 'Required before you can receive an allowance',
            iconColor: state.fingerprintRegistered
                ? AppTheme.successGreen
                : AppTheme.warningAmber,
            onTap: () async {
              await Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const FingerprintScreen()));
              if (mounted) setState(() {});
            },
          ),
          _switchTile(
            icon: Icons.lock_outline,
            title: 'Biometric login',
            subtitle: 'Sign in with your fingerprint',
            value: state.biometricEnabled,
            onChanged: (v) async {
              if (v) {
                final ok = await _enableBiometricLogin();
                if (!ok && mounted) setState(() {});
              } else {
                await context.read<AppState>().disableBiometric();
                if (context.mounted) {
                  showMsg(context, 'Biometric login turned off.');
                }
              }
            },
          ),
          const SizedBox(height: 22),
          const SectionLabel('PREFERENCES'),
          const SizedBox(height: 10),
          _tile(
            icon: Icons.remember_me_outlined,
            title: 'Forget saved email',
            subtitle: 'Clears the email prefilled on the login screen',
            onTap: () async {
              final p = await SharedPreferences.getInstance();
              await p.remove(_kRememberEmail);
              if (context.mounted) showMsg(context, 'Saved email cleared.');
            },
          ),
          _tile(
            icon: Theme.of(context).brightness == Brightness.dark
                ? Icons.light_mode_outlined
                : Icons.dark_mode_outlined,
            title: 'Appearance',
            subtitle: Theme.of(context).brightness == Brightness.dark
                ? 'Dark mode'
                : 'Light mode',
            onTap: () => context.read<AppState>().setThemeMode(
                  Theme.of(context).brightness == Brightness.dark
                      ? ThemeMode.light
                      : ThemeMode.dark,
                ),
          ),
          const SizedBox(height: 22),
          OutlinedButton.icon(
            onPressed: () => context.read<AppState>().logout(),
            icon: const Icon(Icons.logout, size: 18),
            label: const Text('Sign out'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.dangerRed,
              side: const BorderSide(color: AppTheme.dangerRed),
              minimumSize: const Size.fromHeight(50),
            ),
          ),
          const SizedBox(height: 14),
          const Center(
            child: Text('Scholar Wallet v2.0.0',
                style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
          ),
        ],
      ),
    );
  }

  Widget _tile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.colors.borderSoft),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: iconColor ?? context.colors.brand),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(subtitle,
            style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
        trailing: Icon(Icons.chevron_right, color: context.colors.hint),
      ),
    );
  }

  Widget _switchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.colors.borderSoft),
      ),
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        secondary: Icon(icon, color: context.colors.brand),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(subtitle,
            style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
      ),
    );
  }
}
