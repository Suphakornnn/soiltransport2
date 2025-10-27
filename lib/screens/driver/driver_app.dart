import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'driver_home_screen.dart';
import 'driver_jobs_screen.dart';
import 'driver_profile_screen.dart';

// service ดันพิกัดขึ้น Firestore แบบ background/interval
import '../../services/driver_location_pusher.dart';

class DriverApp extends StatefulWidget {
  const DriverApp({super.key});
  @override
  State<DriverApp> createState() => _DriverAppState();
}

class _DriverAppState extends State<DriverApp> with WidgetsBindingObserver {
  int _idx = 0;
  final _tabs = const [
    DriverHomeScreen(),
    DriverJobsScreen(),
    DriverProfileScreen(),
  ];

  DriverLocationPusher? _pusher;

  // ถ้ามี mapping uid -> vehicleId ใน 'drivers/{uid}.vehicleDocId' จะใช้ค่านี้
  String? _vehicleDocIdFromProfile;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initLocationPusher();
  }

  Future<void> _initLocationPusher() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // ลองอ่าน vehicleDocId จากโปรไฟล์ (ถ้ามี)
    try {
      final doc = await FirebaseFirestore.instance
          .collection('drivers')
          .doc(user.uid)
          .get();
      _vehicleDocIdFromProfile = doc.data()?['vehicleDocId'] as String?;
    } catch (_) {
      // เงียบไว้ ถ้าอ่านไม่ได้จะ fallback เป็น uid
    }

    final docId = _vehicleDocIdFromProfile ?? user.uid;
    _pusher ??= DriverLocationPusher(docId);

    // เริ่มส่งพิกัด (ไม่ต้อง await ใน didChange... แต่ตอน init ใส่ await ได้)
    await _pusher!.start();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // resume -> กลับมาเริ่มส่งพิกัดอีกครั้ง, อื่น ๆ -> หยุด
    if (state == AppLifecycleState.resumed) {
      _pusher?.start();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _pusher?.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pusher?.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _tabs[_idx],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _idx,
        onDestinationSelected: (i) => setState(() => _idx = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.today_outlined),
            label: 'วันนี้',
          ),
          NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            label: 'งานทั้งหมด',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'โปรไฟล์',
          ),
        ],
      ),
    );
  }
}
