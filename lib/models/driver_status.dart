String driverStatusToEng(String status) {
  switch (status) {
    case 'พร้อมใช้งาน':
      return 'ready';
    case 'กำลังซ่อม':
      return 'maintenance';
    case 'ไม่พร้อมใช้งาน':
      return 'unavailable';
    case 'กำลังทำงาน':
      return 'working';
    default:
      return status;
  }
}

String getStatusTextFromEng(String? status) {
  if (status == null) return 'พร้อมใช้งาน';
  switch (status) {
    case 'ready':
      return 'พร้อมใช้งาน';
    case 'maintenance':
      return 'กำลังซ่อม';
    case 'unavailable':
      return 'ไม่พร้อมใช้งาน';
    case 'working':
      return 'กำลังทำงาน';
  }
  return status;
}
