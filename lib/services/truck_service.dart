import 'package:cloud_firestore/cloud_firestore.dart';

class TruckService {
  final _col = FirebaseFirestore.instance.collection('trucks');

  /// ตรวจทะเบียนซ้ำ (option เผื่อกันข้อมูลซ้ำ)
  Future<bool> isPlateExists(String plate) async {
    final q = await _col.where('plate', isEqualTo: plate.trim()).limit(1).get();
    return q.docs.isNotEmpty;
  }

  /// สร้าง Truck
  Future<DocumentReference<Map<String, dynamic>>> createTruck(Map<String, dynamic> data) async {
    final now = FieldValue.serverTimestamp();
    final payload = {
      ...data,
      'createdAt': now,
      'updatedAt': now,
    };
    return _col.add(payload);
  }
}
