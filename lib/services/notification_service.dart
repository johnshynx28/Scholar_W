import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// FR-25 — Push notifications via Firebase Cloud Messaging.
///
/// Registers the device's FCM token on the user's profile row so a backend
/// (Supabase Edge Function / Firebase Cloud Function) can push:
///   - allowance disbursed        -> scholar
///   - withdrawal approved/rejected -> scholar
///   - new withdrawal request     -> admins
///
/// Everything here is wrapped in try/catch so the app keeps working even if
/// FCM is not configured yet (e.g. missing google-services.json in dev).
class NotificationService {
  static bool _listening = false;

  static Future<void> registerForUser(String uid) async {
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();

      Future<void> save(String? token) async {
        if (token == null) return;
        await Supabase.instance.client
            .from('profiles')
            .update({'fcm_token': token}).eq('id', uid);
      }

      await save(await messaging.getToken());

      if (!_listening) {
        _listening = true;
        FirebaseMessaging.instance.onTokenRefresh.listen(save);
        // Foreground messages: nothing to render here — the dashboards
        // already refresh from the database; a listener hook is kept so a
        // UI banner can be added later without touching registration.
        FirebaseMessaging.onMessage.listen((_) {});
      }
    } catch (_) {
      // FCM not configured on this build — app continues without push.
    }
  }
}
