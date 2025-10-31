import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:soil_transport_app/models/truck_model.dart';
import 'package:soil_transport_app/services/truck_service.dart';

/// =============================================================
///   Manage Jobs (Responsive: Desktop table-like + Mobile cards)
///   — Blue–White theme, polished mobile layout
/// =============================================================

// ---- Breakpoint ----
const double kBreakWide = 1000; // >=1000px = Desktop/Table

// ---- ค่าความกว้างคอลัมน์ (เดสก์ท็อป) ----
const double kWCode = 110;
const double kWDate = 120;
const double kWDriver = 280;
const double kWPlate = 120;
const double kWLocation = 360;
const double kWTrips = 80;
const double kWRevenue = 140;
const double kWStatus = 180;
const double kWActions = 170;

const double kColGap = 18;

// ---- ระยะ/โทนสี ----
const double kRowRadius = 14;
const double kRowSpacing = 10;

const Color kBG = Color(0xFFF5F8FF); // ฟ้าขาวพื้นหลัง
const Color kCardBorder = Color(0xFFE3ECFF); // เส้นขอบการ์ด
const Color kTextPrimary = Color(0xFF1F2937);
const Color kTextSecondary = Color(0xFF6B7280);
const Color kBlue = Color(0xFF2563EB);
const Color kBlueSoft = Color(0xFFEFF4FF);
const Color kBorder = Color(0xFFE5EAF3);

TextStyle get _titleStyle => const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: kTextPrimary);
TextStyle get _smallMuted => const TextStyle(fontSize: 12, color: kTextSecondary);

// ---- สถานะงานขนส่ง ----
enum JobStatus { pending, processing, done, cancelled }

enum _SortField { code, date, driver, plate, location, trips, revenue, status }

class JobItem {
  final String code;
  final DateTime date;
  final List<String> drivers;
  final String plate;
  final String dropLocation;
  final String startLocation;
  final int trips;
  final int pricePerTrip;
  final int fuelBaht;
  final int incomeBaht; // เพิ่มจาก reports_jobs
  final JobStatus status;
  final TimeOfDay? start;
  final TimeOfDay? end;
  final String? note;

  JobItem({
    required this.code,
    required this.date,
    required this.drivers,
    required this.plate,
    required this.dropLocation,
    required this.startLocation,
    required this.trips,
    required this.pricePerTrip,
    required this.fuelBaht,
    required this.incomeBaht, // เพิ่มจาก reports_jobs
    required this.status,
    this.start,
    this.end,
    this.note,
  });

  num get revenue => incomeBaht; // ใช้ incomeBaht จาก reports_jobs แทนการคำนวณ

  JobItem copyWith({
    String? code,
    DateTime? date,
    List<String>? drivers,
    String? plate,
    String? dropLocation,
    String? startLocation,
    int? trips,
    int? pricePerTrip,
    int? fuelBaht,
    int? incomeBaht,
    JobStatus? status,
    TimeOfDay? start,
    TimeOfDay? end,
    String? note,
  }) {
    return JobItem(
      code: code ?? this.code,
      date: date ?? this.date,
      drivers: drivers ?? this.drivers,
      plate: plate ?? this.plate,
      dropLocation: dropLocation ?? this.dropLocation,
      startLocation: startLocation ?? this.startLocation,
      trips: trips ?? this.trips,
      pricePerTrip: pricePerTrip ?? this.pricePerTrip,
      fuelBaht: fuelBaht ?? this.fuelBaht,
      incomeBaht: incomeBaht ?? this.incomeBaht,
      status: status ?? this.status,
      start: start ?? this.start,
      end: end ?? this.end,
      note: note ?? this.note,
    );
  }

  // ★ เพิ่ม factory constructor จาก Firestore Document
  factory JobItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    // แปลง status จาก string เป็น enum
    JobStatus statusFromString(String status) {
      switch (status) {
        case 'pending':
          return JobStatus.pending;
        case 'processing':
          return JobStatus.processing;
        case 'done':
          return JobStatus.done;
        case 'cancelled':
          return JobStatus.cancelled;
        default:
          return JobStatus.pending;
      }
    }

    // แปลง Timestamp เป็น DateTime
    DateTime dateFromData(dynamic dateData) {
      if (dateData is Timestamp) {
        return dateData.toDate();
      } else if (dateData is String) {
        return DateTime.parse(dateData);
      } else {
        return DateTime.now();
      }
    }

    // แปลง drivers จาก dynamic เป็น List<String>
    List<String> driversFromData(dynamic driversData) {
      if (driversData is List) {
        return driversData.map((e) => e.toString()).toList();
      } else if (driversData is String) {
        return [driversData];
      } else {
        return [];
      }
    }

    // แปลงเวลา start/end
    TimeOfDay? timeFromData(dynamic timeData) {
      if (timeData is String && timeData.isNotEmpty) {
        final parts = timeData.split(':');
        if (parts.length == 2) {
          final hour = int.tryParse(parts[0]);
          final minute = int.tryParse(parts[1]);
          if (hour != null && minute != null) {
            return TimeOfDay(hour: hour, minute: minute);
          }
        }
      }
      return null;
    }

    return JobItem(
      code: data['code']?.toString() ?? 'N/A',
      date: dateFromData(data['date']),
      drivers: driversFromData(data['drivers']),
      plate: data['plate']?.toString() ?? '',
      dropLocation: data['dropLocation']?.toString() ?? '',
      startLocation: data['startLocation']?.toString() ?? '',
      trips: (data['trips'] as num?)?.toInt() ?? 0,
      pricePerTrip: (data['pricePerTrip'] as num?)?.toInt() ?? 0,
      fuelBaht: (data['fuelBaht'] as num?)?.toInt() ?? 0,
      incomeBaht: (data['IncomeBaht'] as num?)?.toInt() ?? 0, // ดึงจาก reports_jobs
      status: statusFromString(data['status']?.toString() ?? 'pending'),
      start: timeFromData(data['startTime']),
      end: timeFromData(data['endTime']),
      note: data['note']?.toString(),
    );
  }
}

class ManageJobsScreen extends StatefulWidget {
  const ManageJobsScreen({super.key});
  @override
  State<ManageJobsScreen> createState() => _ManageJobsScreenState();
}

class _ManageJobsScreenState extends State<ManageJobsScreen> {
  // ★ ใช้ FirebaseFirestore instance โดยตรง
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // -------- filter / search / sort --------
  String _q = '';
  JobStatus? _status; // null = ทุกสถานะ
  _SortField _sort = _SortField.date;
  bool _asc = false;

  // ★ ฟังก์ชันแปลง status เป็น string สำหรับ Firebase
  String _jobStatusToString(JobStatus status) {
    switch (status) {
      case JobStatus.pending:
        return 'pending';
      case JobStatus.processing:
        return 'processing';
      case JobStatus.done:
        return 'done';
      case JobStatus.cancelled:
        return 'cancelled';
    }
  }

  // ★ ฟังก์ชันสร้างรหัสงานใหม่ (1ตัวอักษร 3ตัวเลข)
  Future<String> _generateJobCode() async {
    const letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    final random = DateTime.now().millisecondsSinceEpoch;
    final letter = letters[random % letters.length];
    final numbers = (random % 1000).toString().padLeft(3, '0');

    final code = '$letter$numbers';

    // ตรวจสอบว่า code ไม่ซ้ำ
    final existing = await _firestore.collection('jobs').where('code', isEqualTo: code).limit(1).get();

    if (existing.docs.isEmpty) {
      return code;
    } else {
      // ถ้าซ้ำให้ลองใหม่
      return _generateJobCode();
    }
  }

  // ★ ฟังก์ชันดึงข้อมูลจาก Firebase พร้อม filter และ sort
  Stream<List<JobItem>> get _jobsStream {
    return _firestore.collection('jobs').snapshots().map((snapshot) {
      List<JobItem> jobs = snapshot.docs.map((doc) => JobItem.fromFirestore(doc)).toList();

      // Apply search filter
      final q = _q.toLowerCase().trim();
      final filtered =
          jobs.where((j) {
            final sOK = _status == null || j.status == _status;
            final qOK =
                q.isEmpty ||
                j.code.toLowerCase().contains(q) ||
                j.plate.toLowerCase().contains(q) ||
                j.dropLocation.toLowerCase().contains(q) ||
                j.startLocation.toLowerCase().contains(q) ||
                j.drivers.any((d) => d.toLowerCase().contains(q));
            return sOK && qOK;
          }).toList();

      // Apply sorting
      int cmp<T extends Comparable>(T a, T b) => _asc ? a.compareTo(b) : b.compareTo(a);

      filtered.sort((a, b) {
        switch (_sort) {
          case _SortField.code:
            return cmp(a.code, b.code);
          case _SortField.date:
            return cmp(a.date.millisecondsSinceEpoch, b.date.millisecondsSinceEpoch);
          case _SortField.driver:
            return cmp(a.drivers.join(','), b.drivers.join(','));
          case _SortField.plate:
            return cmp(a.plate, b.plate);
          case _SortField.location:
            return cmp(a.dropLocation, b.dropLocation);
          case _SortField.trips:
            return cmp(a.trips, b.trips);
          case _SortField.revenue:
            return cmp(a.revenue, b.revenue);
          case _SortField.status:
            return cmp(a.status.index, b.status.index);
        }
      });

      return filtered;
    });
  }

  void _setSort(_SortField f) {
    setState(() {
      if (_sort == f) {
        _asc = !_asc;
      } else {
        _sort = f;
        _asc = f == _SortField.date ? false : true;
      }
    });
  }

  // -------- helpers --------
  String _th(DateTime d) => '${d.day}/${d.month}/${d.year + 543}';
  String _baht(num v) {
    final s = v.toStringAsFixed(0);
    final b = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      b.write(s[i]);
      final pos = s.length - i - 1;
      if (pos % 3 == 0 && pos != 0) b.write(',');
    }
    return '฿$b';
  }

  // ★ ฟังก์ชันลบงานจาก Firebase
  Future<void> _deleteJob(JobItem job) async {
    try {
      // ค้นหา document ที่มี code ตรงกัน
      final querySnapshot = await _firestore.collection('jobs').where('code', isEqualTo: job.code).get();
      if (querySnapshot.docs.isNotEmpty) {
        await _firestore.collection('jobs').doc(querySnapshot.docs.first.id).delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ลบงาน ${job.code} สำเร็จ')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ลบงานไม่สำเร็จ: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= kBreakWide;

    return Scaffold(
      backgroundColor: kBG,
      appBar: AppBar(
        title: const Text('จัดการงานขนส่งดิน'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        foregroundColor: kBlue,
        elevation: .5,
        actions: [
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: kBlue, foregroundColor: Colors.white),
            icon: const Icon(Icons.add),
            label: const Text('เพิ่มงานขนส่งใหม่'),
            onPressed: () async {
              final created = await showDialog<JobItem>(
                context: context,
                barrierDismissible: false,
                builder: (_) => _JobFormDialog(onGenerateCode: _generateJobCode),
              );
              if (created != null && mounted) {
                // ★ บันทึกลง Firebase
                try {
                  await _firestore.collection('jobs').add({
                    'code': created.code,
                    'date': Timestamp.fromDate(created.date),
                    'drivers': created.drivers,
                    'plate': created.plate,
                    'dropLocation': created.dropLocation,
                    'startLocation': created.startLocation,
                    'trips': created.trips,
                    'pricePerTrip': created.pricePerTrip,
                    'fuelBaht': created.fuelBaht,
                    'IncomeBaht': created.incomeBaht, // บันทึก IncomeBaht
                    'status': _jobStatusToString(created.status), // ใช้ฟังก์ชันแปลง status
                    'startTime':
                        created.start != null
                            ? '${created.start!.hour.toString().padLeft(2, '0')}:${created.start!.minute.toString().padLeft(2, '0')}'
                            : null,
                    'endTime':
                        created.end != null
                            ? '${created.end!.hour.toString().padLeft(2, '0')}:${created.end!.minute.toString().padLeft(2, '0')}'
                            : null,
                    'note': created.note,
                    'createdAt': FieldValue.serverTimestamp(),
                  });
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('เพิ่มงาน ${created.code} สำเร็จ')));
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('เพิ่มงานไม่สำเร็จ: $e')));
                }
              }
            },
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ====== ค้นหา + กรองสถานะ (responsive) ======
            isWide ? _filtersWide() : _filtersNarrow(),
            const SizedBox(height: 12),

            // ====== เนื้อหา (responsive) ======
            // ★ ใช้ StreamBuilder แทนการแสดงข้อมูลแบบ static
            StreamBuilder<List<JobItem>>(
              stream: _jobsStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('เกิดข้อผิดพลาด: ${snapshot.error}'));
                }

                final jobs = snapshot.data ?? [];

                if (jobs.isEmpty) {
                  return const Center(
                    child: Text('ไม่พบข้อมูลงานขนส่ง', style: TextStyle(fontSize: 16, color: kTextSecondary)),
                  );
                }

                return isWide ? _tableDesktop(jobs) : _listMobile(jobs);
              },
            ),
          ],
        ),
      ),
    );
  }

  // ----------------- Filters -----------------
  Widget _filtersWide() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            onChanged: (v) => setState(() => _q = v),
            decoration: InputDecoration(
              hintText: 'ค้นหาตามรหัสงาน คนขับ ทะเบียนรถ หรือสถานที่...',
              prefixIcon: const Icon(Icons.search, color: kBlue),
              isDense: true,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: kCardBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: kBlue, width: 1.4),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        _statusFilterButton(),
      ],
    );
  }

  Widget _filtersNarrow() {
    return Column(
      children: [
        TextField(
          onChanged: (v) => setState(() => _q = v),
          decoration: InputDecoration(
            hintText: 'ค้นหา รหัสงาน/คนขับ/ทะเบียน/สถานที่...',
            prefixIcon: const Icon(Icons.search, color: kBlue),
            isDense: true,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: kCardBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: kBlue, width: 1.4),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Align(alignment: Alignment.centerRight, child: _statusFilterButton()),
      ],
    );
  }

  Widget _statusFilterButton() {
    return PopupMenuButton<JobStatus?>(
      color: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      tooltip: 'กรองสถานะ',
      offset: const Offset(0, 44),
      onSelected: (v) => setState(() => _status = v),
      itemBuilder:
          (_) => const [
            PopupMenuItem(value: null, child: Text('ทุกสถานะ')),
            PopupMenuItem(value: JobStatus.pending, child: Text('รอดำเนินการ')),
            PopupMenuItem(value: JobStatus.processing, child: Text('กำลังดำเนินการ')),
            PopupMenuItem(value: JobStatus.done, child: Text('เสร็จสิ้น')),
            PopupMenuItem(value: JobStatus.cancelled, child: Text('ยกเลิก')),
          ],
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: kCardBorder),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.filter_alt_outlined, color: kBlue),
            SizedBox(width: 8),
            Text('สถานะ'),
            Icon(Icons.keyboard_arrow_down),
          ],
        ),
      ),
    );
  }

  // ----------------- Desktop (table-like) -----------------
  Widget _tableDesktop(List<JobItem> data) {
    final total = data.fold<num>(0, (p, c) => p + c.revenue);

    return Card(
      margin: EdgeInsets.zero,
      color: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader(data.length, total),
            const SizedBox(height: 8),
            const Divider(height: 24),
            // header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  _SortHeader(
                    w: kWCode,
                    label: 'เลขงาน',
                    field: _SortField.code,
                    cur: _sort,
                    asc: _asc,
                    onTap: _setSort,
                  ),
                  _SortHeader(
                    w: kWDate,
                    label: 'วันที่',
                    field: _SortField.date,
                    cur: _sort,
                    asc: _asc,
                    onTap: _setSort,
                  ),
                  _SortHeader(
                    w: kWDriver,
                    label: 'คนขับ',
                    field: _SortField.driver,
                    cur: _sort,
                    asc: _asc,
                    onTap: _setSort,
                  ),
                  _SortHeader(
                    w: kWPlate,
                    label: 'ทะเบียนรถ',
                    field: _SortField.plate,
                    cur: _sort,
                    asc: _asc,
                    onTap: _setSort,
                  ),
                  _SortHeader(
                    w: kWLocation,
                    label: 'สถานที่ที่ต้องลง',
                    field: _SortField.location,
                    cur: _sort,
                    asc: _asc,
                    onTap: _setSort,
                  ),
                  _SortHeader(
                    w: kWTrips,
                    label: 'เที่ยว',
                    field: _SortField.trips,
                    cur: _sort,
                    asc: _asc,
                    onTap: _setSort,
                    align: TextAlign.center,
                  ),
                  _SortHeader(
                    w: kWRevenue,
                    label: 'รายได้',
                    field: _SortField.revenue,
                    cur: _sort,
                    asc: _asc,
                    onTap: _setSort,
                    align: TextAlign.right,
                  ),
                  const SizedBox(width: kColGap),
                  _SortHeader(
                    w: kWStatus,
                    label: 'สถานะ',
                    field: _SortField.status,
                    cur: _sort,
                    asc: _asc,
                    onTap: _setSort,
                  ),
                  const _HCell(w: kWActions, t: 'จัดการ', align: TextAlign.center),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // rows
            ...data.asMap().entries.map(
              (e) => Padding(padding: const EdgeInsets.only(bottom: kRowSpacing), child: _rowCardDesktop(e.value)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rowCardDesktop(JobItem j) {
    return InkWell(
      onTap: () => _openDetail(j),
      borderRadius: BorderRadius.circular(kRowRadius),
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(kRowRadius),
          border: Border.all(color: kBorder),
          boxShadow: const [BoxShadow(color: Color(0x0C000000), blurRadius: 10, offset: Offset(0, 2))],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Cell(
                w: kWCode,
                child: InkWell(
                  onTap: () => _openDetail(j),
                  child: Text(
                    j.code,
                    style: const TextStyle(
                      color: kBlue,
                      decoration: TextDecoration.underline,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              _Cell(w: kWDate, t: _th(j.date)),
              _Cell(
                w: kWDriver,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children:
                      j.drivers
                          .map(
                            (d) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                children: [
                                  const Icon(Icons.circle, size: 6, color: kBlue),
                                  const SizedBox(width: 6),
                                  Expanded(child: Text(d, overflow: TextOverflow.ellipsis)),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                ),
              ),
              _Cell(w: kWPlate, t: j.plate),
              _Cell(
                w: kWLocation,
                child: Row(
                  children: [
                    const Icon(Icons.place_rounded, size: 16, color: Color(0xFF10B981)),
                    const SizedBox(width: 6),
                    Expanded(child: Text(j.dropLocation, overflow: TextOverflow.ellipsis)),
                  ],
                ),
              ),
              _Cell(w: kWTrips, t: '${j.trips}', align: TextAlign.center),
              _Cell(
                w: kWRevenue,
                t: _baht(j.revenue),
                align: TextAlign.right,
                color: const Color(0xFF059669),
                bold: true,
              ),
              const SizedBox(width: kColGap),
              _Cell(w: kWStatus, child: _statusChip(j.status)),
              SizedBox(
                width: kWActions,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _iconBtnWithTip(Icons.visibility_outlined, 'ดูรายละเอียด', () => _openDetail(j)),
                    const SizedBox(width: 8),
                    _iconBtnWithTip(Icons.edit_outlined, 'แก้ไขงาน', () => _openForm(j)),
                    const SizedBox(width: 8),
                    _iconBtnWithTip(Icons.delete_outline, 'ลบงาน', () => _delete(j), color: const Color(0xFFB3261E)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ----------------- Mobile (card list) -----------------
  Widget _listMobile(List<JobItem> data) {
    final total = data.fold<num>(0, (p, c) => p + c.revenue);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(data.length, total),
        const SizedBox(height: 8),
        ...data.map(
          (j) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kCardBorder),
              boxShadow: const [BoxShadow(color: Color(0x0F000000), blurRadius: 12, offset: Offset(0, 2))],
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  // แถวบน: เลขงาน/วันที่/สถานะ
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: kBlueSoft,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: kCardBorder),
                        ),
                        child: Text('#${j.code}', style: const TextStyle(color: kBlue, fontWeight: FontWeight.w800)),
                      ),
                      const SizedBox(width: 8),
                      Text(_th(j.date), style: _smallMuted),
                      const Spacer(),
                      _statusChip(j.status),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // คนขับ (แท็กสีฟ้าอ่อน)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children:
                          j.drivers
                              .map(
                                (d) => Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: kBlueSoft,
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(color: kCardBorder),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.person, size: 14, color: kBlue),
                                      const SizedBox(width: 6),
                                      Text(
                                        d,
                                        style: const TextStyle(fontSize: 12, color: kBlue, fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                              .toList(),
                    ),
                  ),

                  const SizedBox(height: 10),
                  // ป้ายทะเบียน
                  _iconLine(Icons.local_shipping_outlined, j.plate, leadingColor: kBlue),
                  const SizedBox(height: 6),
                  _iconLine(Icons.place_outlined, j.startLocation, leadingColor: const Color(0xFF10B981)),
                  _iconLine(Icons.place_rounded, j.dropLocation, leadingColor: const Color(0xFF10B981)),

                  const SizedBox(height: 12),
                  // เส้นคั่นบาง ๆ ฟ้าอ่อน
                  Container(height: 1, color: kCardBorder),
                  const SizedBox(height: 12),

                  // สรุป 3 ช่อง
                  Row(
                    children: [
                      Expanded(child: _miniStat('เที่ยว', '${j.trips}')),
                      Expanded(child: _miniStat('ค่าน้ำมัน', _baht(j.fuelBaht))),
                      Expanded(child: _miniStat('รายได้รวม', _baht(j.revenue), highlight: true)),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // ปุ่มจัดการ (ปุ่มฟ้า/ขอบฟ้า)
                  Align(
                    alignment: Alignment.centerRight,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: kBlue),
                            foregroundColor: kBlue,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () => _openDetail(j),
                          icon: const Icon(Icons.visibility_outlined, size: 18),
                          label: const Text('ดูรายละเอียด'),
                        ),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: kBlue),
                            foregroundColor: kBlue,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () => _openForm(j),
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          label: const Text('แก้ไข'),
                        ),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFB3261E),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () => _delete(j),
                          icon: const Icon(Icons.delete_outline, size: 18),
                          label: const Text('ลบ'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ----- mini stat (เฉพาะ mobile list) -----
  Widget _miniStat(String title, String value, {bool highlight = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: _smallMuted),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(fontWeight: FontWeight.w800, color: highlight ? const Color(0xFF059669) : Colors.black87),
        ),
      ],
    );
  }

  Widget _iconLine(IconData icon, String text, {Color leadingColor = Colors.black54}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [Icon(icon, size: 16, color: leadingColor), const SizedBox(width: 8), Expanded(child: Text(text))],
    );
  }

  // ----------------- shared widgets -----------------
  Widget _sectionHeader(int count, num totalRevenue) {
    return Row(
      children: [
        Text('รายการงานขนส่ง', style: _titleStyle),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: kBlueSoft,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: kCardBorder),
          ),
          child: Text('$count งาน', style: const TextStyle(color: kBlue, fontWeight: FontWeight.w800)),
        ),
        const Spacer(),
        Row(
          children: [
            const Icon(Icons.payments_outlined, size: 18, color: Color(0xFF059669)),
            const SizedBox(width: 6),
            Text(
              'รายได้รวม: ${_baht(totalRevenue)}',
              style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF059669)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _iconBtnWithTip(IconData i, String tip, VoidCallback onTap, {Color? color}) {
    final c = color ?? const Color(0xFF2B2F38);
    return Tooltip(
      message: tip,
      waitDuration: const Duration(milliseconds: 300),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Ink(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: c.withOpacity(.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: c.withOpacity(.18)),
          ),
          child: Icon(i, size: 18, color: c),
        ),
      ),
    );
  }

  Widget _statusChip(JobStatus s) {
    Color bg, fg;
    switch (s) {
      case JobStatus.done:
        bg = const Color(0xFF10B981).withOpacity(.12);
        fg = const Color(0xFF047857);
        break;
      case JobStatus.processing:
        bg = kBlue.withOpacity(.12);
        fg = const Color(0xFF2450C5);
        break;
      case JobStatus.pending:
        bg = const Color(0xFFF59E0B).withOpacity(.18);
        fg = const Color(0xFF8C5A00);
        break;
      case JobStatus.cancelled:
        bg = const Color(0xFFEF4444).withOpacity(.12);
        fg = const Color(0xFFB3261E);
        break;
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
        child: Text(
          {
            JobStatus.pending: 'รอดำเนินการ',
            JobStatus.processing: 'กำลังดำเนินการ',
            JobStatus.done: 'เสร็จสิ้น',
            JobStatus.cancelled: 'ยกเลิก',
          }[s]!,
          style: TextStyle(color: fg, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  // ----- actions/dialogs -----
  void _openForm([JobItem? j]) async {
    final result = await showDialog<JobItem>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _JobFormDialog(job: j, onGenerateCode: _generateJobCode),
    );
    if (result == null || !mounted) return;

    try {
      if (j == null) {
        // ★ เพิ่มงานใหม่
        await _firestore.collection('jobs').add({
          'code': result.code,
          'date': Timestamp.fromDate(result.date),
          'drivers': result.drivers,
          'plate': result.plate,
          'dropLocation': result.dropLocation,
          'startLocation': result.startLocation,
          'trips': result.trips,
          'pricePerTrip': result.pricePerTrip,
          'fuelBaht': result.fuelBaht,
          'IncomeBaht': result.incomeBaht, // บันทึก IncomeBaht
          'status': _jobStatusToString(result.status),
          'startTime':
              result.start != null
                  ? '${result.start!.hour.toString().padLeft(2, '0')}:${result.start!.minute.toString().padLeft(2, '0')}'
                  : null,
          'endTime':
              result.end != null
                  ? '${result.end!.hour.toString().padLeft(2, '0')}:${result.end!.minute.toString().padLeft(2, '0')}'
                  : null,
          'note': result.note,
          'createdAt': FieldValue.serverTimestamp(),
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('เพิ่มงาน ${result.code} สำเร็จ')));
      } else {
        // ★ แก้ไขงานเดิม
        final querySnapshot = await _firestore.collection('jobs').where('code', isEqualTo: j.code).get();
        if (querySnapshot.docs.isNotEmpty) {
          await _firestore.collection('jobs').doc(querySnapshot.docs.first.id).update({
            'date': Timestamp.fromDate(result.date),
            'drivers': result.drivers,
            'plate': result.plate,
            'dropLocation': result.dropLocation,
            'startLocation': result.startLocation,
            'trips': result.trips,
            'pricePerTrip': result.pricePerTrip,
            'fuelBaht': result.fuelBaht,
            'IncomeBaht': result.incomeBaht, // อัพเดท IncomeBaht
            'status': _jobStatusToString(result.status),
            'startTime':
                result.start != null
                    ? '${result.start!.hour.toString().padLeft(2, '0')}:${result.start!.minute.toString().padLeft(2, '0')}'
                    : null,
            'endTime':
                result.end != null
                    ? '${result.end!.hour.toString().padLeft(2, '0')}:${result.end!.minute.toString().padLeft(2, '0')}'
                    : null,
            'note': result.note,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('แก้ไขงาน ${result.code} สำเร็จ')));
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('บันทึกข้อมูลไม่สำเร็จ: $e')));
    }
  }

  void _openDetail(JobItem j) {
    showDialog(context: context, builder: (_) => _JobDetailDialog(job: j));
  }

  void _delete(JobItem j) async {
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('ลบงานขนส่ง'),
            content: Text('ต้องการลบงาน ${j.code} ใช่หรือไม่?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ยกเลิก')),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFFB3261E)),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('ลบ'),
              ),
            ],
          ),
    );
    if (ok == true) await _deleteJob(j);
  }
}

// ======= Header cell with sort =======
class _SortHeader extends StatelessWidget {
  final double w;
  final String label;
  final _SortField field;
  final _SortField cur;
  final bool asc;
  final TextAlign align;
  final void Function(_SortField) onTap;

  const _SortHeader({
    required this.w,
    required this.label,
    required this.field,
    required this.cur,
    required this.asc,
    required this.onTap,
    this.align = TextAlign.left,
  });

  @override
  Widget build(BuildContext context) {
    final active = field == cur;
    final ic = active ? (asc ? Icons.arrow_upward : Icons.arrow_downward) : null;

    return SizedBox(
      width: w,
      child: InkWell(
        onTap: () => onTap(field),
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Row(
            mainAxisAlignment:
                align == TextAlign.right
                    ? MainAxisAlignment.end
                    : align == TextAlign.center
                    ? MainAxisAlignment.center
                    : MainAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontWeight: FontWeight.w700, color: active ? kBlue : Colors.black87)),
              if (ic != null) ...[const SizedBox(width: 4), Icon(ic, size: 14, color: kBlue)],
            ],
          ),
        ),
      ),
    );
  }
}

class _HCell extends StatelessWidget {
  final double w;
  final String t;
  final TextAlign align;
  const _HCell({required this.w, required this.t, this.align = TextAlign.left});
  @override
  Widget build(BuildContext context) => SizedBox(
    width: w,
    child: Text(t, textAlign: align, style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black87)),
  );
}

class _Cell extends StatelessWidget {
  final double w;
  final String? t;
  final Widget? child;
  final TextAlign align;
  final Color? color;
  final bool bold;

  const _Cell({required this.w, this.t, this.child, this.align = TextAlign.left, this.color, this.bold = false});

  @override
  Widget build(BuildContext context) {
    final content =
        child ??
        Text(
          t ?? '',
          textAlign: align,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: color, fontWeight: bold ? FontWeight.w700 : FontWeight.w400),
        );

    return SizedBox(width: w, child: Padding(padding: const EdgeInsets.only(right: 12), child: content));
  }
}

// ============== Detail Dialog (Blue–White) ==============
class _JobDetailDialog extends StatelessWidget {
  final JobItem job;
  const _JobDetailDialog({required this.job});

  // ------- helpers -------
  String _two(int x) => x.toString().padLeft(2, '0');
  String _th(DateTime d) => '${d.day}/${d.month}/${d.year + 543}';
  String _timeRange() {
    final s = job.start == null ? '--:--' : '${_two(job.start!.hour)}:${_two(job.start!.minute)}';
    final e = job.end == null ? '--:--' : '${_two(job.end!.hour)}:${_two(job.end!.minute)}';
    return '$s - $e';
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFFF5F8FF);
    const cardBorder = Color(0xFFE5EAF3);
    const blue = Color(0xFF2563EB);
    const textPrimary = Color(0xFF1F2937);
    const textMuted = Color(0xFF6B7280);

    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Container(
          color: Colors.white,
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // header
                Row(
                  children: [
                    Text(
                      'รายละเอียดงานขนส่ง #${job.code}',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: textPrimary),
                    ),
                    const Spacer(),
                    _chip(job.status),
                  ],
                ),
                const SizedBox(height: 12),
                _iconRow(Icons.event, _th(job.date), textMuted),
                _iconRow(Icons.schedule, _timeRange(), textMuted),
                _iconRow(Icons.person, job.drivers.join(' · '), textMuted),
                _iconRow(Icons.local_shipping, 'ทะเบียนรถ: ${job.plate}', textMuted),
                _iconRow(Icons.place, job.dropLocation, textMuted),
                _iconRow(Icons.place, job.startLocation, textMuted),
                const SizedBox(height: 14),

                // mini stats – blue/white cards
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _miniStat('เที่ยว', '${job.trips}', Icons.credit_card, blue, cardBorder, bg),
                    _miniStat('ต่อเที่ยว', '฿${job.pricePerTrip}', Icons.attach_money, blue, cardBorder, bg),
                    _miniStat('รายได้รวม', '฿${job.revenue}', Icons.payments, const Color(0xFF059669), cardBorder, bg),
                    _miniStat(
                      'ค่าน้ำมัน',
                      '฿${job.fuelBaht}',
                      Icons.local_gas_station,
                      const Color(0xFFB3261E),
                      cardBorder,
                      bg,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: blue, foregroundColor: Colors.white),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('ปิด'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _iconRow(IconData i, String t, Color muted) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(children: [Icon(i, size: 18, color: muted), const SizedBox(width: 8), Flexible(child: Text(t))]),
  );

  Widget _miniStat(String title, String value, IconData icon, Color accent, Color border, Color bg) {
    return SizedBox(
      width: 150,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: border),
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2))],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Icon(icon, color: accent),
              const SizedBox(height: 6),
              Text(title, style: const TextStyle(color: Color(0xFF6B7280))),
              const SizedBox(height: 4),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(JobStatus s) {
    late Color bg, fg;
    switch (s) {
      case JobStatus.done:
        bg = const Color(0xFF05C46B).withOpacity(.15);
        fg = const Color(0xFF058E4D);
        break;
      case JobStatus.processing:
        bg = const Color(0xFF2E7DFF).withOpacity(.15);
        fg = const Color(0xFF2450C5);
        break;
      case JobStatus.pending:
        bg = const Color(0xFFFFC947).withOpacity(.26);
        fg = const Color(0xFF8C5A00);
        break;
      case JobStatus.cancelled:
        bg = const Color(0xFFFF3B30).withOpacity(.16);
        fg = const Color(0xFFB3261E);
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(30)),
      child: Text(
        {
          JobStatus.pending: 'รอดำเนินการ',
          JobStatus.processing: 'กำลังดำเนินการ',
          JobStatus.done: 'เสร็จสิ้น',
          JobStatus.cancelled: 'ยกเลิก',
        }[s]!,
        style: TextStyle(color: fg, fontWeight: FontWeight.w700),
      ),
    );
  }
}

// ============== Form Dialog (Blue–White) ==============
class _JobFormDialog extends StatefulWidget {
  final JobItem? job;
  final Future<String> Function() onGenerateCode;
  const _JobFormDialog({this.job, required this.onGenerateCode});

  @override
  State<_JobFormDialog> createState() => _JobFormDialogState();
}

class _JobFormDialogState extends State<_JobFormDialog> {
  // ----- state -----
  late DateTime date;
  JobStatus status = JobStatus.pending;
  final drivers = <String>[];
  String plate = '';
  String dropLocation = '';
  String startLocation = '';
  TimeOfDay? start;
  TimeOfDay? end;
  int trips = 1;
  int pricePerTrip = 0;
  int fuelBaht = 0;
  int incomeBaht = 0; // เพิ่มจาก reports_jobs
  String note = '';
  String? _generatedCode;
  List<Truck> trucks = [];
  final _plateCtrl = TextEditingController();

  // palette
  static const _blue = Color(0xFF2563EB);
  static const _bgField = Color(0xFFF8FBFF);
  static const _border = Color(0xFFE3ECFF);
  static const _borderFocus = Color(0xFF98B8FF);

  @override
  void initState() {
    super.initState();
    final j = widget.job;
    date = j?.date ?? DateTime.now();
    status = j?.status ?? JobStatus.pending;
    drivers.addAll(j?.drivers ?? []);
    plate = j?.plate ?? '';
    _plateCtrl.text = plate;
    dropLocation = j?.dropLocation ?? '';
    startLocation = j?.startLocation ?? '';
    start = j?.start;
    end = j?.end;
    trips = j?.trips ?? 1;
    pricePerTrip = j?.pricePerTrip ?? 0;
    fuelBaht = j?.fuelBaht ?? 0;
    incomeBaht = j?.incomeBaht ?? 0; // ดึงจาก reports_jobs
    note = j?.note ?? '';
    _getTrucks();

    // Generate code ถ้าเป็นงานใหม่
    if (j == null) {
      _generateCode();
    }
  }

  @override
  void dispose() {
    _plateCtrl.dispose();
    super.dispose();
  }

  Future<void> _getTrucks() async {
    // ดึงรายชื่อคนขับจากฐานข้อมูลรถบรรทุก (สมมติว่ามีฟังก์ชัน getTrucks ใน TruckService)
    List<Truck> truckList = await TruckService().getAllTrucks();
    //print('Fetched trucks: ${truckList[0].driver}'); // Debug print
    setState(() {
      // สมมติว่าแต่ละ TruckModel มี property 'driverName'
      trucks = truckList;

      // ใช้ driverNames ตามที่ต้องการ
    });
  }

  List<String> get driverNames => trucks.map((truck) => truck.driver).toList();

  Future<void> _generateCode() async {
    final code = await widget.onGenerateCode();
    setState(() {
      _generatedCode = code;
    });
  }

  // ------- helpers -------
  String _baht(num v) {
    final s = v.toStringAsFixed(0);
    final b = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      b.write(s[i]);
      final pos = s.length - i - 1;
      if (pos % 3 == 0 && pos != 0) b.write(',');
    }
    return '฿$b';
  }

  String _two(int x) => x.toString().padLeft(2, '0');
  InputDecoration _dec(String label, {String? hint}) => InputDecoration(
    labelText: label,
    hintText: hint,
    isDense: true,
    filled: true,
    fillColor: _bgField,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _border)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _borderFocus, width: 1.4),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
  );

  @override
  Widget build(BuildContext context) {
    final revenue = incomeBaht; // ใช้ incomeBaht จาก reports_jobs
    final profit = revenue - fuelBaht;

    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Container(
          color: Colors.white,
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              children: [
                // Title + status
                Row(
                  children: [
                    Text(
                      widget.job == null ? 'เพิ่มงานขนส่งใหม่' : 'แก้ไขงานขนส่ง',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                    const Spacer(),
                    DropdownButton<JobStatus>(
                      value: status,
                      onChanged: (v) => setState(() => status = v!),
                      items: const [
                        DropdownMenuItem(value: JobStatus.pending, child: Text('รอดำเนินการ')),
                        DropdownMenuItem(value: JobStatus.processing, child: Text('กำลังดำเนินการ')),
                        DropdownMenuItem(value: JobStatus.done, child: Text('เสร็จสิ้น')),
                        DropdownMenuItem(value: JobStatus.cancelled, child: Text('ยกเลิก')),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // แสดงรหัสงาน (เฉพาะงานใหม่)
                if (widget.job == null && _generatedCode != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _bgField,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _border),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.confirmation_number, color: _blue),
                        const SizedBox(width: 8),
                        const Text('รหัสงาน:', style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(width: 8),
                        Text(
                          _generatedCode!,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _blue),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.refresh, color: _blue),
                          onPressed: _generateCode,
                          tooltip: 'สร้างรหัสใหม่',
                        ),
                      ],
                    ),
                  ),
                if (widget.job == null) const SizedBox(height: 8),

                // วันที่
                _dateField(context),
                const SizedBox(height: 8),

                // คนขับ
                _driversInput(),
                const SizedBox(height: 8),

                // ทะเบียน / สถานที่
                TextFormField(
                  controller: _plateCtrl,
                  enabled: false,
                  decoration: _dec('ทะเบียนรถ').copyWith(suffixIcon: const Icon(Icons.lock_outline, size: 16)),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  initialValue: startLocation,
                  onChanged: (v) => startLocation = v,
                  decoration: _dec('สถานที่เริ่มต้น', hint: 'สถานที่เริ่มต้น'),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  initialValue: dropLocation,
                  onChanged: (v) => dropLocation = v,
                  decoration: _dec('สถานที่ที่ต้องลง', hint: 'ระบุสถานที่ต้องลง'),
                ),
                const SizedBox(height: 8),

                // เวลาเริ่ม/จบ
                Row(
                  children: [
                    Expanded(child: _timeField('เวลาเริ่ม', start, (t) => setState(() => start = t))),
                    const SizedBox(width: 8),
                    Expanded(child: _timeField('เวลาสิ้นสุด', end, (t) => setState(() => end = t))),
                  ],
                ),
                const SizedBox(height: 8),

                // ตัวเลข
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        initialValue: '$trips',
                        keyboardType: TextInputType.number,
                        onChanged: (v) => trips = int.tryParse(v) ?? 0,
                        decoration: _dec('จำนวนเที่ยว'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        initialValue: '$pricePerTrip',
                        keyboardType: TextInputType.number,
                        onChanged: (v) => pricePerTrip = int.tryParse(v) ?? 0,
                        decoration: _dec('ราคาต่อเที่ยว (บาท)'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        initialValue: '$fuelBaht',
                        keyboardType: TextInputType.number,
                        onChanged: (v) => fuelBaht = int.tryParse(v) ?? 0,
                        decoration: _dec('ค่าน้ำมัน (บาท)'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        initialValue: '$incomeBaht',
                        keyboardType: TextInputType.number,
                        onChanged: (v) => incomeBaht = int.tryParse(v) ?? 0,
                        decoration: _dec('รายได้รวม (บาท)'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // สรุปเงิน – ฟ้าขาว
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F8FF),
                    border: Border.all(color: const Color(0xFFE5EAF3)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sumRow('รายได้จากการขนส่ง', '', _baht(incomeBaht), Colors.black87),
                      _sumRow('หักค่าน้ำมัน', '', '-${_baht(fuelBaht)}', const Color(0xFFB3261E)),
                      const Divider(),
                      _sumRow('รายได้สุทธิ', '', _baht(profit), const Color(0xFF14A44D), bold: true),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                TextFormField(
                  initialValue: note,
                  maxLines: 2,
                  onChanged: (v) => note = v,
                  decoration: _dec('หมายเหตุ', hint: 'หมายเหตุเพิ่มเติม (ถ้ามี)'),
                ),
                const SizedBox(height: 14),

                Row(
                  children: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('ยกเลิก')),
                    const Spacer(),
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: _blue, foregroundColor: Colors.white),
                      onPressed: _save,
                      child: Text(widget.job == null ? 'เพิ่มงานขนส่ง' : 'บันทึกการแก้ไข'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ------ field widgets ------
  Widget _dateField(BuildContext context) {
    final s = '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year + 543}';
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime(2020),
          lastDate: DateTime(2100),
        );
        if (picked != null) setState(() => date = picked);
      },
      child: InputDecorator(
        isEmpty: false,
        decoration: _dec('วันที่'),
        child: Row(
          children: [Text(s), const Spacer(), const Icon(Icons.calendar_today, size: 16, color: Colors.black54)],
        ),
      ),
    );
  }

  Widget _timeField(String label, TimeOfDay? value, ValueChanged<TimeOfDay?> onPicked) {
    final text = value == null ? '--:--' : '${_two(value.hour)}:${_two(value.minute)}';
    return InkWell(
      onTap: () async {
        final t = await showTimePicker(context: context, initialTime: value ?? const TimeOfDay(hour: 6, minute: 0));
        onPicked(t);
      },
      child: InputDecorator(
        isEmpty: false,
        decoration: _dec(label),
        child: Row(
          children: [Text(text), const Spacer(), const Icon(Icons.access_time, size: 16, color: Colors.black54)],
        ),
      ),
    );
  }

  Widget _driversInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('คนขับ (${drivers.length} คน) ', style: const TextStyle(color: Colors.black54)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ...drivers.map((d) => Chip(label: Text(d), onDeleted: () => setState(() => drivers.remove(d)))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: _bgField,
                border: Border.all(color: _border),
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButton<String>(
                hint: const Row(children: [Icon(Icons.add, size: 18), SizedBox(width: 8), Text('เพิ่มคนขับ')]),
                value: null,
                underline: const SizedBox(),
                items:
                    driverNames
                        .where((name) => !drivers.contains(name))
                        .map((name) => DropdownMenuItem<String>(value: name, child: Text(name)))
                        .toList(),
                onChanged: (value) {
                  if (value != null && !drivers.contains(value)) {
                    setState(() {
                      drivers.add(value);
                      // ทะเบียนรถจะถูกกำหนดจากคนขับคนแรกเท่านั้น
                      if (drivers.length == 1) {
                        final truck = trucks.firstWhere((t) => t.driver == value, orElse: () => trucks.first);
                        plate = truck.plate;
                        _plateCtrl.text = plate;
                      }
                    });
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _sumRow(String label, String sub, String value, Color color, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label),
                if (sub.isNotEmpty) Text(sub, style: const TextStyle(color: Colors.black54, fontSize: 12)),
              ],
            ),
          ),
          Text(value, style: TextStyle(color: color, fontWeight: bold ? FontWeight.w800 : FontWeight.w600)),
        ],
      ),
    );
  }

  // save result
  void _save() {
    if (drivers.isEmpty || plate.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('กรุณาใส่คนขับอย่างน้อย 1 คนและทะเบียนรถ')));
      return;
    }

    if (widget.job == null && _generatedCode == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('กำลังสร้างรหัสงาน...')));
      return;
    }

    final base =
        widget.job ??
        JobItem(
          code: _generatedCode!,
          date: date,
          drivers: drivers.toList(),
          plate: plate,
          dropLocation: dropLocation,
          startLocation: startLocation,
          trips: trips,
          pricePerTrip: pricePerTrip,
          fuelBaht: fuelBaht,
          incomeBaht: incomeBaht, // เพิ่มจาก reports_jobs
          status: status,
          start: start,
          end: end,
          note: note,
        );
    final res = base.copyWith(
      date: date,
      drivers: drivers.toList(),
      plate: plate,
      dropLocation: dropLocation,
      startLocation: startLocation,
      trips: trips,
      pricePerTrip: pricePerTrip,
      fuelBaht: fuelBaht,
      incomeBaht: incomeBaht, // เพิ่มจาก reports_jobs
      status: status,
      start: start,
      end: end,
      note: note,
    );
    Navigator.pop(context, res);
  }
}
