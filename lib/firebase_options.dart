import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        return android;
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDvpTndV0tEF7UuE7RZCmmeCe6wDcf-Lw0',
    appId: '1:978567764041:android:e5498f8d0a533ac6ae8798',
    messagingSenderId: '978567764041',
    projectId: 'scholarwallet-38c4a',
    storageBucket: 'scholarwallet-38c4a.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDcOI1KEHQ8t41KMuYhWlWu-spACsGflf4',
    appId: '1:978567764041:ios:c0b28b9ab0dc1f24ae8798',
    messagingSenderId: '978567764041',
    projectId: 'scholarwallet-38c4a',
    storageBucket: 'scholarwallet-38c4a.firebasestorage.app',
    iosBundleId: 'com.scholarwallet',
  );
}
