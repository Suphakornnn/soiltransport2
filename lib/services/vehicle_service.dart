import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:soil_transport_app/models/driver_status.dart';

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
      'lastUpdate': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> updateVehicle({required String vehicleId, String? plate, String? driverName, String? status}) async {
    final Map<String, dynamic> updates = {'lastUpdate': FieldValue.serverTimestamp()};

    if (plate != null) updates['plate'] = plate;
    if (driverName != null) updates['driver'] = driverName;
    if (status != null) updates['status'] = driverStatusToEng(status);

    await _col.doc(vehicleId).update(updates);
  }
}
