// lib/services/firebase_initializer.dart
import 'package:firebase_core/firebase_core.dart';
import '../firebase_options.dart';

/// ตัวบูต Firebase ที่กัน duplicate-init ทั้งจาก race condition และ hot-restart
class FirebaseBoot {
  static Future<FirebaseApp>? _initializing;

  static Future<FirebaseApp> ensure() async {
    // ถ้ามี instance แล้ว คืนเลย
    if (Firebase.apps.isNotEmpty) {
      return Firebase.app();
    }
    // ถ้ากำลัง init อยู่ ให้รอ Future เดิม
    if (_initializing != null) {
      return await _initializing!;
    }

    // ล็อกด้วย Future ตัวเดียวกันเพื่อกันซ้อน
    _initializing = _initSafe();
    try {
      return await _initializing!;
    } finally {
      _initializing = null; // เคลียร์ล็อก
    }
  }

  static Future<FirebaseApp> _initSafe() async {
    if (Firebase.apps.isNotEmpty) {
      return Firebase.app();
    }
    try {
      // 👇 บรรทัดนี้คือ line ที่เครื่องคุณหาเจอ (ประมาณบรรทัด 36)
      return await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } on FirebaseException catch (e) {
      // แข่งกันจนซ้ำ => หยิบตัวที่ถูก init ไปแล้ว
      if (e.code == 'duplicate-app' || e.message?.contains('duplicate-app') == true) {
        return Firebase.app();
      }
      rethrow;
    } catch (_) {
      // กันเคส message ไม่ใช่ FirebaseException แต่มี app แล้ว
      if (Firebase.apps.isNotEmpty) {
        return Firebase.app();
      }
      rethrow;
    }
  }
}

// ฟังก์ชันสั้น ๆ ให้ main.dart เรียกชื่อคงเดิมได้
Future<FirebaseApp> ensureFirebaseInitialized() => FirebaseBoot.ensure();
