import 'package:soil_transport_app/screens/admin/manage_jobs.dart';

extension ExJobStatus on String {
  JobStatus? get status {
    switch (this) {
      case 'เสร็จสิ้น':
        return JobStatus.done;
      case 'กำลังดำเนินการ':
        return JobStatus.processing;
      case 'รอดำเนินการ':
        return JobStatus.pending;
      case 'ยกเลิก':
        return JobStatus.cancelled;
      default:
        return null;
    }
  }
}

extension ExJobStatusEnum on JobStatus {
  String get job {
    switch (this) {
      case JobStatus.done:
        return 'เสร็จสิ้น';
      case JobStatus.processing:
        return 'กำลังดำเนินการ';
      case JobStatus.pending:
        return 'รอดำเนินการ';
      case JobStatus.cancelled:
        return 'ยกเลิก';
      default:
        // all
        return 'ทุกสถานะ';
    }
  }
}
