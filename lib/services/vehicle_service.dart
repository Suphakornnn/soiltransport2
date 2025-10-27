import 'package:cloud_firestore/cloud_firestore.dart';

class VehicleService {
  final _col = FirebaseFirestore.instance.collection('vehicles');

  Future<void> initVehicleDoc({
    required String vehicleId,
    required String plate,
    required String driverName,
    String status = 'ready',
    double lat = 13.736717,
    double lng = 100.523186,
  }) async {
    await _col.doc(vehicleId).set({
      'plate': plate,
      'driver': driverName,
      'status': status,
      'lat': lat,
      'lng': lng,
      'speedKmh': 0,
      'lastUpdate': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }


}
