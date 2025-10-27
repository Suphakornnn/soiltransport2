import 'package:cloud_firestore/cloud_firestore.dart';

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
