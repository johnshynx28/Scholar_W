import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import '../models/models.dart';

/// AUTHENTICATION: Firebase Auth (email + password).
/// PROFILE DATA: Supabase `profiles` table keyed by Firebase UID.
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final SupabaseClient _db = Supabase.instance.client;

  Stream<User?> get authState => _auth.authStateChanges();
  User? get currentFirebaseUser => _auth.currentUser;

  /// Sign in, then load the matching profile row from Supabase.
  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    return _loadProfile(cred.user!);
  }

  // Completes when the profile row of a brand-new account is inserted, so the
  // AuthGate never loads the profile before it exists (race on sign up).
  Future<void>? _pendingSignup;

  /// Create Firebase account + insert a Supabase profile row.
  Future<AppUser> signUp({
    required String fullName,
    required String email,
    required String password,
    required String studentNumber,
    required String university,
    required String program,
    required String yearLevel,
  }) async {
    final completer = Completer<void>();
    _pendingSignup = completer.future;
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = AppUser(
        id: cred.user!.uid,
        fullName: fullName.trim(),
        email: email.trim(),
        role: UserRole.scholar,
        studentNumber: studentNumber.trim(),
        university: university.trim(),
        program: program.trim(),
        yearLevel: yearLevel,
      );
      await _db.from('profiles').insert({
        'id': user.id,
        'full_name': user.fullName,
        'email': user.email,
        'role': 'scholar',
        'balance': 0,
        'student_number': user.studentNumber,
        'university': user.university,
        'program': user.program,
        'year_level': user.yearLevel,
      });
      return user;
    } finally {
      completer.complete();
      _pendingSignup = null;
    }
  }

  Future<AppUser?> currentAppUser() async {
    final u = _auth.currentUser;
    if (u == null) return null;
    return _loadProfile(u);
  }

  Future<AppUser> _loadProfile(User u) async {
    final pending = _pendingSignup;
    if (pending != null) {
      try {
        await pending;
      } catch (_) {}
    }
    final row =
        await _db.from('profiles').select().eq('id', u.uid).maybeSingle();
    if (row == null) {
      // Fallback: build a minimal profile from Firebase data.
      return AppUser(
        id: u.uid,
        fullName: u.displayName ?? (u.email?.split('@').first ?? 'Scholar'),
        email: u.email ?? '',
      );
    }
    return AppUser.fromMap(row);
  }

  Future<void> sendPasswordReset(String email) =>
      _auth.sendPasswordResetEmail(email: email.trim());

  Future<void> signOut() => _auth.signOut();

  /// Human-readable message for common Firebase errors.
  String friendlyError(Object e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'user-not-found':
          return 'No account found for that email.';
        case 'wrong-password':
          return 'Incorrect password.';
        case 'email-already-in-use':
          return 'That email is already registered.';
        case 'weak-password':
          return 'Password must be at least 6 characters.';
        case 'invalid-email':
          return 'Please enter a valid email address.';
        default:
          return e.message ?? 'Authentication failed.';
      }
    }
    return e.toString();
  }
}
