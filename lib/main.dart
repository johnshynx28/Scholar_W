import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' show User, FirebaseAuth;
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'providers/app_state.dart';
import 'services/notification_service.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/verification_screen.dart';
import 'screens/admin/admin_dashboard_screen.dart';
import 'models/models.dart';

/// ---------------------------------------------------------------------------
/// SETUP
/// 1) Firebase: run `flutterfire configure` to generate firebase_options.dart
///    and enable Email/Password auth in the Firebase console.
/// 2) Supabase: create a project, run `supabase_setup.sql` in the SQL editor
///    (then the other scripts in SETUP_VERIFICATION.txt), then paste your
///    project URL and anon key below.
/// ---------------------------------------------------------------------------
const String supabaseUrl = 'https://zprzughlopeiodowxiep.supabase.co';
const String supabaseAnonKey = 'sb_publishable_Xko1oikQdDsTPiQEGv8xXw_s6SVZXrt';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppState? appState;
  String? initError;
  try {
    await Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform)
        .timeout(const Duration(seconds: 20));
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabaseAnonKey,
      // Firebase ID token; the SDK refreshes it automatically when expired.
      accessToken: () async =>
          await FirebaseAuth.instance.currentUser?.getIdToken(),
    ).timeout(const Duration(seconds: 20));
    final s = AppState();
    await s.loadThemeMode();
    await s.loadBiometricState();
    appState = s;
  } catch (e, st) {
    initError = '$e\n\n$st';
  }

  final state = appState;
  if (state == null) {
    runApp(_InitErrorApp(message: initError ?? 'Unknown startup error'));
    return;
  }
  runApp(
    ChangeNotifierProvider.value(
      value: state,
      child: const ScholarWalletApp(),
    ),
  );
}

class _InitErrorApp extends StatelessWidget {
  final String message;
  const _InitErrorApp({required this.message});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(title: const Text('Startup error')),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: SelectableText(message),
          ),
        ),
      ),
    );
  }
}

class ScholarWalletApp extends StatelessWidget {
  const ScholarWalletApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeMode = context.select<AppState, ThemeMode>((s) => s.themeMode);
    return MaterialApp(
      title: 'Scholar Wallet',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      home: const AuthGate(),
    );
  }
}

/// Routes: signed-out -> Login; scholar -> Home; admin -> Admin Dashboard.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final Stream<User?> _authStream;
  String? _cachedUid;
  Future<AppUser?>? _profileFuture;

  @override
  void initState() {
    super.initState();
    _authStream = context.read<AppState>().auth.authState;
  }

  String _friendlyProfileError(Object? e) {
    final text = '$e';
    if (text.contains('42501') || text.contains('permission denied')) {
      return 'The database denied access.\n'
          'Ask the administrator to run the latest supabase_setup.sql, '
          'then tap Retry.';
    }
    return 'Failed to load profile:\n$text';
  }

  Future<AppUser?> _profileFor(User firebaseUser) {
    if (_cachedUid != firebaseUser.uid || _profileFuture == null) {
      _cachedUid = firebaseUser.uid;
      final state = context.read<AppState>();
      _profileFuture = () async {
        final profile = await state.auth.currentAppUser();
        state.user = profile;
        await state.loadThemeForUser(firebaseUser.uid);
        await state.loadBiometricState();
        await state.loadAllowanceSettings();
        NotificationService.registerForUser(firebaseUser.uid);
        return profile;
      }();
    }
    return _profileFuture!;
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return StreamBuilder<User?>(
      stream: _authStream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        final firebaseUser = snap.data;
        if (firebaseUser == null) {
          _cachedUid = null;
          _profileFuture = null;
          return Theme(data: AppTheme.light, child: const LoginScreen());
        }
        return FutureBuilder<AppUser?>(
          future: _profileFor(firebaseUser),
          builder: (context, userSnap) {
            if (userSnap.hasError) {
              return Scaffold(
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                            _friendlyProfileError(userSnap.error),
                            textAlign: TextAlign.center,
                            maxLines: 6,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () async {
                            try {
                              await FirebaseAuth.instance.currentUser
                                  ?.getIdToken(true);
                            } catch (_) {}
                            if (!mounted) return;
                            setState(() {
                              _cachedUid = null;
                              _profileFuture = null;
                            });
                          },
                          child: const Text('Retry'),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => state.auth.signOut(),
                          child: const Text('Sign out'),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }
            if (!userSnap.hasData) {
              return const Scaffold(
                  body: Center(child: CircularProgressIndicator()));
            }
            final profile = state.user?.id == userSnap.data!.id
                ? state.user!
                : userSnap.data!;
            state.user = profile;
            if (profile.role == UserRole.admin) {
              return const AdminDashboardScreen();
            }
            if (!profile.canReceiveAllowance) {
              return const VerificationScreen(gate: true);
            }
            return const HomeScreen();
          },
        );
      },
    );
  }
}
