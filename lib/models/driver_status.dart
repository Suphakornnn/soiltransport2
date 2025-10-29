String driverStatusToEng(String status){
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
        return 'ready';
    }
}

  String getStatusTextFromEng(dynamic status) {
    if (status == null) return 'พร้อมใช้งาน';
    if (status is String) {
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
    }
    return 'พร้อมใช้งาน';
  }