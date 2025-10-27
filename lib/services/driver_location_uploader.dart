import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

class DriverLocationUploader {
  DriverLocationUploader(this.vehicleDocId);

  final String vehicleDocId;

  StreamSubscription<Position>? _sub;
  bool _running = false;

  Future<void> _ensurePermission() async {
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever) {
      throw 'ปฏิเสธสิทธิ์ตำแหน่งแบบถาวร';
    }
  }

  Future<void> start() async {
    if (_running) return;
    _running = true;

    await _ensurePermission();

    // ตั้งค่า: อัปเดตเมื่อขยับ >= 20 เมตร หรือทุก ๆ ~5–10 วิ (ขึ้นกับ OS)
    const settings = LocationSettings(
      accuracy: LocationAccuracy.best,
      distanceFilter: 20,
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
            'speedKmh': (pos.speed * 3.6).round(), // m/s -> km/h
            'status': 'working', // หรือสถานะจริงของคุณ
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        } catch (e) {
          // log เงียบ ๆ
        }
      },
      onError: (e) {},
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
