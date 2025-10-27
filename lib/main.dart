import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

// ===== Firebase =====
import 'package:firebase_auth/firebase_auth.dart';

// เรียกผ่าน helper แทน initializeApp ตรง ๆ
import 'services/firebase_initializer.dart';
import 'services/firestore_service.dart';

// ====== Screens ======
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';

// Admin
import 'screens/admin/dashboard_admin.dart';
import 'screens/admin/manage_users.dart';
import 'screens/admin/manage_trucks.dart';
import 'screens/admin/manage_jobs.dart';
import 'screens/admin/tracking_screen.dart';
import 'screens/admin/reports_screen.dart';
import 'screens/admin/payroll_screen.dart';
import 'screens/admin/soil_calculator_screen.dart';

// Driver
import 'screens/driver/driver_app.dart';
import 'screens/driver/driver_profile_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // --- Init Firebase (กันซ้ำด้วย helper) ---
  await ensureFirebaseInitialized();

  // ตั้งภาษา Firebase
  try {
    await FirebaseAuth.instance.setLanguageCode('th');
  } catch (_) {}

  // แสดง error แทนหน้าขาว
  FlutterError.onError = (details) => FlutterError.dumpErrorToConsole(details);
  ErrorWidget.builder = (details) => MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          appBar: AppBar(title: const Text('เกิดข้อผิดพลาด')),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Text(
                details.exceptionAsString(),
                style: const TextStyle(color: Colors.red),
              ),
            ),
          ),
        ),
      );

  // locale ไทย
  await initializeDateFormatting('th_TH', null);
  Intl.defaultLocale = 'th_TH';

  runApp(const SoilTransportApp());
}

class SoilTransportApp extends StatelessWidget {
  const SoilTransportApp({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF0F3D9E),
      brightness: Brightness.light,
      background: const Color(0xFFF5F8FF),
      surface: Colors.white,
    );

    final theme = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: const Color(0xFFF5F8FF),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Color(0xFF0F3D9E),
        elevation: 0.5,
        surfaceTintColor: Colors.white,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        margin: EdgeInsets.zero,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE6ECFF)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE6ECFF)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF98B8FF)),
        ),
      ),
    );

    return MaterialApp(
      title: 'Soil Transport Management',
      debugShowCheckedModeBanner: false,
      theme: theme,

      // Localizations
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('th', 'TH'),
        Locale('en', 'US'),
      ],
      locale: const Locale('th', 'TH'),

      // หน้าแรก: ฟังสถานะผู้ใช้ & เด้งตาม role
      home: const AuthGate(),

      routes: {
        // Auth
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),

        // Admin
        '/admin': (context) => const DashboardAdmin(),
        '/admin/users': (context) => const ManageUsers(),
        '/admin/trucks': (context) => const ManageTrucks(),
        '/admin/jobs': (context) => const ManageJobsScreen(),
        '/admin/tracking': (context) => const TrackingScreen(),
        '/admin/reports': (context) => ReportsScreen(),
        '/admin/payroll': (context) => const PayrollScreen(),
        '/admin/soil-calc': (context) => const SoilCalculatorScreen(),

        // Driver
        '/driver': (context) => const DriverApp(),
        '/driver/profile': (context) => const DriverProfileScreen(),
      },

      onUnknownRoute: (settings) => MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('ไม่พบหน้า')),
          body: Center(
            child: Text('Route "${settings.name}" ไม่ถูกต้อง'),
          ),
        ),
      ),
    );
  }
}

/// ถ้าไม่ล็อกอิน => ไป Login
/// ถ้าล็อกอิน => อ่าน role จาก Firestore แล้วเด้งไป Admin/Driver
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const _Splash();
        }

        final user = snap.data;
        if (user == null) {
          return const LoginScreen();
        }

        final fs = FirestoreService();
        return FutureBuilder<String?>(
          future: fs.getRole(user.uid),
          builder: (context, roleSnap) {
            if (roleSnap.connectionState == ConnectionState.waiting) {
              return const _Splash();
            }

            final role = roleSnap.data?.toLowerCase();
            if (role == 'admin') return const DashboardAdmin();
            if (role == 'driver') return const DriverApp();

            return Scaffold(
              appBar: AppBar(title: const Text('ไม่มีสิทธิ์เข้าใช้งาน')),
              body: const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'บัญชีนี้ยังไม่กำหนดสิทธิ์ (role)\n'
                    'โปรดให้แอดมินเพิ่มเอกสารใน Firestore: /users/{uid} -> role',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
