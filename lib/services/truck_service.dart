import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:soil_transport_app/models/truck_model.dart';

class TruckService {
  final _col = FirebaseFirestore.instance.collection('vehicles');

  /// ตรวจทะเบียนซ้ำ (option เผื่อกันข้อมูลซ้ำ)
  Future<bool> isPlateExists(String plate) async {
    final q = await _col.where('plate', isEqualTo: plate.trim()).limit(1).get();
    return q.docs.isNotEmpty;
  }

  /// สร้าง Truck
  Future<DocumentReference<Map<String, dynamic>>> createTruck(
    Map<String, dynamic> data,
  ) async {
    final now = FieldValue.serverTimestamp();
    final payload = {...data, 'createdAt': now, 'updatedAt': now};
    return _col.add(payload);
  }

  Future<List<Truck>> getAllTrucks() async {
    try {
      final querySnapshot = await _col.get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        return Truck(
          plate: data['plate'] ?? '',
          model: data['model'] ?? '',
          driver: data['driver'] ?? '',
          status: data['status'] ?? '',
          location: data['location'] ?? '',
          mileage: data['mileage'] ?? 0,
          fuel: data['fuel'] ?? 0,
          nextService: data['nextService'] ?? '',
        );
      }).toList();
    } catch (e, st) {
      print('Failed to fetch trucks: $e\n$st');
      return [];
    }
  }
}
