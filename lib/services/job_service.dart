import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:soil_transport_app/models/job2_model.dart';

class MyJob {
  final _col = FirebaseFirestore.instance.collection('jobs');

  Future<List<Job2Model>> getAllJobs() async {
    try {
      final querySnapshot = await _col.get();
      print('');
      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        data['_id'] = doc.id;
        return Job2Model.fromJson(data);
      }).toList();
    } catch (e, st) {
      print('Failed to fetch jobs: $e\n$st');
      return [];
    }
  }
}
