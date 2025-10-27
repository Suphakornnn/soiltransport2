// lib/firebase_options.dart
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError('This platform is not configured.');
    }
  }

  // ===== Web (คัดลอกจากหน้า Web SDK Config) =====
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCCJwz46HhVEokUL_IHfjpr0zh4e-hghew',
    appId: '1:711089748895:web:ced8e216f051bb6e391baa',
    projectId: 'soiltransport-1a0b6',
    messagingSenderId: '711089748895',
    authDomain: 'soiltransport-1a0b6.firebaseapp.com',
    storageBucket: 'soiltransport-1a0b6.appspot.com',
    // measurementId: 'G-GCBSL2M287', // ถ้ามีให้ใส่
  );

  // ===== Android (ใช้ค่าเดียวกับ json แต่ bucket ใช้ .appspot.com) =====
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCCeWBetmrLx7sRe8v838PL2uKH5rCPRfg',
    appId: '1:711089748895:android:04810845117d80f9391baa',
    projectId: 'soiltransport-1a0b6',
    messagingSenderId: '711089748895',
    storageBucket: 'soiltransport-1a0b6.appspot.com',
  );
}
