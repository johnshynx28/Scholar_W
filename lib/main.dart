import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' show User;
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'providers/app_state.dart';
import 'services/notification_service.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/admin/admin_dashboard_screen.dart';
import 'models/models.dart';

/// ---------------------------------------------------------------------------
/// SETUP
/// 1) Firebase: run `flutterfire configure` to generate firebase_options.dart
///    and enable Email/Password auth in the Firebase console.
/// 2) Supabase: create a project, run `supabase_schema.sql` in the SQL editor,
///    create a PUBLIC storage bucket named `receipts`, then paste your
///    project URL and anon key below.
/// ---------------------------------------------------------------------------
const String supabaseUrl = 'https://zprzughlopeiodowxiep.supabase.co';
const String supabaseAnonKey = 'sb_publishable_Xko1oikQdDsTPiQEGv8xXw_s6SVZXrt';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppState? appState;
  String? initError;
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)
        .timeout(const Duration(seconds: 20));
    await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseAnonKey)
        .timeout(const Duration(seconds: 20));
    final s = AppState();
    await s.loadThemeMode();
    await s.loadBiometricState(); // FR-26
    appState = s;
  } catch (e, st) {
    initError = '$e\n\n$st';
  }

  final state = appState;
  if (state == null) {
    // Show the real error on screen instead of a blank/black screen.
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
///
/// NOTE: This is a StatefulWidget on purpose. The auth stream and the profile
/// future are created ONCE (and cached per Firebase UID). Previously they were
/// re-created on every build, and because the gate watched AppState, every
/// notifyListeners() (e.g. HomeScreen -> refreshBalance) rebuilt the gate,
/// resubscribed the stream, flashed the spinner, remounted HomeScreen and
/// triggered refreshBalance again -> infinite blinking loop.
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
    // read, not watch: the gate must NOT rebuild on AppState changes.
    _authStream = context.read<AppState>().auth.authState;
  }

  Future<AppUser?> _profileFor(User firebaseUser) {
    if (_cachedUid != firebaseUser.uid || _profileFuture == null) {
      _cachedUid = firebaseUser.uid;
      final state = context.read<AppState>();
      _profileFuture = () async {
        final profile = await state.auth.currentAppUser();
        // Apply THIS account's saved light/dark choice.
        await state.loadThemeForUser(firebaseUser.uid);
        await state.loadBiometricState();
        // FR-25: register the FCM token for push notifications.
        NotificationService.registerForUser(firebaseUser.uid);
        return profile;
      }();
    }
    return _profileFuture!;
  }

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    return StreamBuilder<User?>(
      stream: _authStream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting &&
            !snap.hasData) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        final firebaseUser = snap.data;
        if (firebaseUser == null) {
          // Signed out: drop the cached profile so the next login reloads it.
          _cachedUid = null;
          _profileFuture = null;
          // Login + Register stay light-only; dark mode starts after sign-in.
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
                        Text('Failed to load profile:\n${userSnap.error}',
                            textAlign: TextAlign.center,
                            maxLines: 6,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          // Re-run the profile fetch (e.g. after the Supabase
                          // project is restored or the network is back).
                          onPressed: () => setState(() {
                            _cachedUid = null;
                            _profileFuture = null;
                          }),
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
            state.user = userSnap.data;
            return userSnap.data!.role == UserRole.admin
                ? const AdminDashboardScreen()
                : const HomeScreen();
          },
        );
      },
    );
  }
}
