enum DateFilter { all, today, thisWeek, thisMonth }

extension ExDateFilter on String {
  DateFilter? get dateFilter {
    switch (this) {
      case 'วันนี้':
        return DateFilter.today;
      case 'สัปดาห์นี้':
        return DateFilter.thisWeek;
      case 'เดือนนี้':
        return DateFilter.thisMonth;
      case 'ทุกวัน':
        return DateFilter.all;
      default:
        return null;
    }
  }
}

extension ExDateFilterEnum on DateFilter {
  String get label {
    switch (this) {
      case DateFilter.today:
        return 'วันนี้';
      case DateFilter.thisWeek:
        return 'สัปดาห์นี้';
      case DateFilter.thisMonth:
        return 'เดือนนี้';
      case DateFilter.all:
        return 'ทุกวัน';
    }
  }
}
