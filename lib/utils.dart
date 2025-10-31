import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:soil_transport_app/models/job2_model.dart';
import 'package:soil_transport_app/screens/admin/tracking_screen.dart';

DateTime getDateTime(dynamic timestamp) {
  if (timestamp is Timestamp) {
    return timestamp.toDate();
  } else if (timestamp is String) {
    return DateTime.parse(timestamp);
  } else if (timestamp is DateTime) {
    return timestamp;
  }
  return DateTime.now();
}

String? getDropLocation(String driverName, String plate, VStatus status, List<Job2Model> jobs) {
  if (status != VStatus.working) {
    return null;
  }
  if (jobs.isEmpty) {
    return null;
  }
  Job2Model job = jobs.firstWhere(
    (j) => (j.drivers ?? []).contains(driverName) && j.plate == plate,
    orElse: () => Job2Model(),
  );
  return job.dropLocation;
}
