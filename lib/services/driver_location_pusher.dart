import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

class DriverLocationPusher {
  DriverLocationPusher(this.vehicleDocId);

  final String vehicleDocId;
  StreamSubscription<Position>? _sub;
  bool _running = false;

  Future<void> _ensurePermission() async {
    LocationPermission p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) {
      p = await Geolocator.requestPermission();
    }
    if (p == LocationPermission.deniedForever) {
      throw 'ปฏิเสธสิทธิ์ตำแหน่งแบบถาวร (เปิดที่ Settings)';
    }
  }

  Future<void> start() async {
    if (_running) return;
    _running = true;

    await _ensurePermission();

    const settings = LocationSettings(
      accuracy: LocationAccuracy.best, // วิ่งจริงให้ best/mediumHigh
      distanceFilter: 20,              // อัปเดตเมื่อขยับ ≥ 20 m
    );

    _sub = Geolocator.getPositionStream(locationSettings: settings).listen(
      (pos) async {
        try {
          await FirebaseFirestore.instance
              .collection('vehicles')
              .doc(vehicleDocId)
              .set({
            'lat': pos.latitude,
            'lng': pos.longitude,
            'speedKmh': (pos.speed * 3.6).round(),
            'status': 'working', // ปรับตามสถานะจริง
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        } catch (_) {}
      },
      onError: (_) {},
      cancelOnError: false,
    );
  }

  Future<void> stop() async {
    _running = false;
    await _sub?.cancel();
    _sub = null;
  }

  bool get isRunning => _running;
}
