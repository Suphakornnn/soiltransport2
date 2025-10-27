import 'package:excel/excel.dart' hide Border; // ซ่อน Border จาก excel
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_saver/file_saver.dart';
import 'dart:typed_data';

class PayrollScreen extends StatefulWidget {
  const PayrollScreen({Key? key}) : super(key: key);

  @override
  State<PayrollScreen> createState() => _PayrollScreenState();
}

class _PayrollScreenState extends State<PayrollScreen> {
  // ---------- CONFIG ----------
  static const double kBreakMd = 900; // >= 900px = โหมดเดสก์ท็อป

  // ---------- FIREBASE ----------
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ---------- VARIABLES ----------
  final _baht = NumberFormat.currency(locale: 'th_TH', symbol: '฿');
  final List<String> _statuses = ['ทั้งหมด', 'จ่ายแล้ว', 'รอจ่าย', 'ยกเลิก'];
  final List<String> _employeeNames = [];
  List<Map<String, dynamic>> _vehiclesData = []; // เก็บข้อมูล vehicles ทั้งหมด

  final TextEditingController _searchCtrl = TextEditingController();
  String _statusFilter = 'ทั้งหมด';
  String _employeeFilter = 'ทั้งหมด';

  List<Map<String, dynamic>> rows = [];
  List<Map<String, dynamic>> payrollData = [];
  int totalEmployees = 0;
  num totalBaseSalary = 0;
  num totalTripPrice = 0;
  num totalBonusAmount = 0;

  // ---------- LIFECYCLE ----------
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // ---------- DATA LOADING ----------
  Future<void> _loadData() async {
    await _loadVehicles();
    await _loadEmployees();
    await _loadPayrollData();
    await _loadJobsData();
    _calculateTotals();
    setState(() {});
  }

  Future<void> _loadVehicles() async {
    try {
      final querySnapshot = await _firestore.collection('vehicles').get();
      final vehicles = <Map<String, dynamic>>[];

      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        vehicles.add({
          'id': doc.id,
          'driver': data['driver'] ?? '',
          'plate': data['plate'] ?? '',
          ...data,
        });
      }

      _vehiclesData = vehicles;
    } catch (e) {
      debugPrint('Error loading vehicles: $e');
    }
  }

  Future<void> _loadEmployees() async {
    try {
      final querySnapshot = await _firestore.collection('vehicles').get();
      final names = <String>{};

      for (final doc in querySnapshot.docs) {
        final driver = doc.data()['driver'];
        if (driver != null && driver is String && driver.isNotEmpty) {
          names.add(driver);
        }
      }

      _employeeNames
        ..clear()
        ..add('ทั้งหมด')
        ..addAll(names.toList());
      totalEmployees = names.length;
    } catch (e) {
      debugPrint('Error loading employees: $e');
    }
  }

  Future<void> _loadPayrollData() async {
    try {
      final querySnapshot = await _firestore.collection('payrolls').get();
      final List<Map<String, dynamic>> data = [];
      num baseTotal = 0;
      num bonusTotal = 0;

      for (final doc in querySnapshot.docs) {
        final docData = doc.data();
        final base = _toNum(docData['base']);
        final bonus = _toNum(docData['bonus']);

        baseTotal += base;
        bonusTotal += bonus;

        data.add({
          'id': doc.id,
          ...docData,
          'base': base,
          'bonus': bonus,
        });
      }

      payrollData = data;
      totalBaseSalary = baseTotal;
      totalBonusAmount = bonusTotal;
    } catch (e) {
      debugPrint('Error loading payroll: $e');
    }
  }

  Future<void> _loadJobsData() async {
    try {
      final querySnapshot = await _firestore.collection('jobs').get();
      num tripPriceTotal = 0;

      for (final doc in querySnapshot.docs) {
        final docData = doc.data();
        final pricePerTrip = _toNum(docData['pricePerTrip']);
        tripPriceTotal += pricePerTrip;
      }

      totalTripPrice = tripPriceTotal;
    } catch (e) {
      debugPrint('Error loading jobs: $e');
    }
  }

  void _calculateTotals() {
    final List<Map<String, dynamic>> tableData = [];

    for (final payroll in payrollData) {
      // คำนวณตามสูตร: (จำนวนเที่ยว * ราคา + 3000 + โบนัส) - หักเบิก
      final tripRuns = _toNum(payroll['tripRuns'] ?? 0);
      final pricePerTrip = _toNum(payroll['jobsPerTrip'] ?? 0);
      final bonus = _toNum(payroll['bonus'] ?? 0);
      final deduct = _toNum(payroll['deduct'] ?? 0);

      final netSalary = (tripRuns * pricePerTrip + 3000 + bonus) - deduct;

      tableData.add({
        'code': payroll['code'] ?? 'N/A',
        'name': payroll['driver'] ?? 'ไม่มีชื่อ',
        'plate': payroll['plate'] ?? '-',
        'payDate': payroll['payDate'] != null
            ? (payroll['payDate'] as Timestamp).toDate()
            : DateTime.now(),
        'base': _toNum(payroll['base'] ?? 0),
        'bonus': bonus,
        'deduct': deduct,
        'tripRuns': tripRuns,
        'pricePerTrip': pricePerTrip,
        'runTotal': tripRuns * pricePerTrip,
        'netSalary': netSalary,
        'status': payroll['status'] ?? 'รอจ่าย',
        'note': payroll['note'] ?? '',
      });
    }

    rows = tableData;
  }

  // ---------- HELPERS ----------
  num _toNum(dynamic v) => (v is num) ? v : (num.tryParse('$v') ?? 0);
  String _fmtBaht(num n) => _baht.format(n);
  String _fmtDate(DateTime d) => DateFormat('d MMM yyyy', 'th_TH').format(d);

  num get totalBase => rowsFiltered.fold(0, (p, e) => p + _toNum(e['base']));
  num get totalBonusFiltered =>
      rowsFiltered.fold(0, (p, e) => p + _toNum(e['bonus']));
  num get totalDeduct =>
      rowsFiltered.fold(0, (p, e) => p + _toNum(e['deduct']));
  num get totalRun =>
      rowsFiltered.fold(0, (p, e) => p + _toNum(e['runTotal']));
  num get totalNet =>
      rowsFiltered.fold(0, (p, e) => p + _toNum(e['netSalary']));

  List<Map<String, dynamic>> get rowsFiltered {
    final q = _searchCtrl.text.trim();
    final s = _statusFilter;
    final e = _employeeFilter;

    return rows.where((item) {
      final matchQ = q.isEmpty ||
          item['name'].toString().contains(q) ||
          item['plate'].toString().contains(q) ||
          item['code'].toString().contains(q);
      final matchS = s == 'ทั้งหมด' || item['status'] == s;
      final matchE = e == 'ทั้งหมด' || item['name'] == e;
      return matchQ && matchS && matchE;
    }).toList();
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'จ่ายแล้ว':
        return Colors.green;
      case 'รอจ่าย':
        return Colors.orange;
      case 'ยกเลิก':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

 // ---------- EXCEL EXPORT ----------
Future<void> _exportToExcel() async {
  try {
    final excel = Excel.createExcel();
    final sheet = excel['เงินเดือนพนักงาน'];

    // Header
    final headers = [
      'รหัส',
      'ชื่อ-นามสกุล',
      'ทะเบียนรถ',
      'วันที่',
      'เงินเดือนฐาน',
      'โบนัส',
      'เงินเบิก',
      'จำนวนเที่ยว',
      'เรต/เที่ยว',
      'รวมเที่ยว',
      'เงินเดือนสุทธิ',
      'สถานะ',
      'หมายเหตุ'
    ];

    for (int i = 0; i < headers.length; i++) {
      sheet.cell(CellIndex.indexByString('${String.fromCharCode(65 + i)}1'))
        ..value = headers[i]
        ..cellStyle = CellStyle(
          bold: true,
          backgroundColorHex: '#E8F5E8',
        );
    }

    // Data
    for (int i = 0; i < rowsFiltered.length; i++) {
      final row = rowsFiltered[i];
      sheet.cell(CellIndex.indexByString('A${i + 2}')).value = row['code'];
      sheet.cell(CellIndex.indexByString('B${i + 2}')).value = row['name'];
      sheet.cell(CellIndex.indexByString('C${i + 2}')).value = row['plate'];
      sheet.cell(CellIndex.indexByString('D${i + 2}')).value = _fmtDate(row['payDate']);
      sheet.cell(CellIndex.indexByString('E${i + 2}')).value = _toNum(row['base']).toDouble();
      sheet.cell(CellIndex.indexByString('F${i + 2}')).value = _toNum(row['bonus']).toDouble();
      sheet.cell(CellIndex.indexByString('G${i + 2}')).value = _toNum(row['deduct']).toDouble();
      sheet.cell(CellIndex.indexByString('H${i + 2}')).value = _toNum(row['tripRuns']).toInt();
      sheet.cell(CellIndex.indexByString('I${i + 2}')).value = _toNum(row['pricePerTrip']).toDouble();
      sheet.cell(CellIndex.indexByString('J${i + 2}')).value = _toNum(row['runTotal']).toDouble();
      sheet.cell(CellIndex.indexByString('K${i + 2}')).value = _toNum(row['netSalary']).toDouble();
      sheet.cell(CellIndex.indexByString('L${i + 2}')).value = row['status'];
      sheet.cell(CellIndex.indexByString('M${i + 2}')).value = row['note'];
    }

    // Summary
    final summaryRow = rowsFiltered.length + 3;
    sheet.cell(CellIndex.indexByString('A$summaryRow')).value = 'สรุป';
    sheet.cell(CellIndex.indexByString('E$summaryRow')).value = totalBase.toDouble();
    sheet.cell(CellIndex.indexByString('F$summaryRow')).value = totalBonusFiltered.toDouble();
    sheet.cell(CellIndex.indexByString('G$summaryRow')).value = totalDeduct.toDouble();
    sheet.cell(CellIndex.indexByString('J$summaryRow')).value = totalRun.toDouble();
    sheet.cell(CellIndex.indexByString('K$summaryRow')).value = totalNet.toDouble();

    // Save file — เปิด system picker (เห็นใน Emulator) + ใส่ mimeType ให้ตรง
    final excelBytes = excel.save();
    if (excelBytes != null) {
      final fileName = 'payroll_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';

      final savedPath = await FileSaver.instance.saveFile(
        name: fileName,
        bytes: Uint8List.fromList(excelBytes),
        ext: 'xlsx',
      );

      _showSnack('ส่งออก Excel เรียบร้อย:\n$savedPath');
    }
  } catch (e) {
    _showSnack('เกิดข้อผิดพลาดในการส่งออก: $e');
  }
}


  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= kBreakMd;

    return Scaffold(
      appBar: AppBar(
        title: const Text('จัดการเงินเดือน'),
        actions: [
          TextButton.icon(
            onPressed: _exportToExcel,
            icon: const Icon(Icons.download),
            label: const Text(''),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: _openAddItem,
            icon: const Icon(Icons.add),
            label: const Text('เพิ่มรายการ'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ---- สรุปด้านบน (Grid responsive ไม่ล้น) ----
            _summaryGrid(isWide: isWide),
            const SizedBox(height: 16),

            // ---- แถวค้นหา/กรอง (Row -> Column เมื่อแคบ) ----
            isWide ? _filterRowWide() : _filterRowNarrow(),
            const SizedBox(height: 16),

            // ---- รายการ (ตารางเดสก์ท็อป / การ์ดบนมือถือ) ----
            isWide ? _tableSectionWide() : _listSectionNarrow(),
            const SizedBox(height: 20),

            // ---- สรุปด้านล่าง (Grid responsive ไม่ล้น) ----
            _footerGrid(isWide: isWide),
          ],
        ),
      ),
    );
  }

  // ---------- SUMMARY ----------
  Widget _summaryGrid({required bool isWide}) {
    final items = <Widget>[
      _summaryCard(
          icon: Icons.groups_2,
          title: 'พนักงานทั้งหมด',
          value: '$totalEmployees'),
    _summaryCard(
          icon: Icons.payments,
          title: 'เงินเดือนรวมสุทธิ',
          value: _fmtBaht(totalBaseSalary),
          color: Colors.green),
      _summaryCard(
          icon: Icons.local_shipping,
          title: 'ราคารวมเที่ยวที่วิ่ง',
          value: _fmtBaht(totalTripPrice),
          color: Colors.indigo),
      _summaryCard(
          icon: Icons.trending_up,
          title: 'โบนัสรวม',
          value: _fmtBaht(totalBonusAmount),
          color: Colors.purple),
    ];

    final cross = isWide ? 4 : 2;
    final tileH = isWide ? 92.0 : 104.0; // << กำหนดความสูงแทน aspect ratio

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cross,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        mainAxisExtent: tileH, // << สำคัญ กันล้น
      ),
      itemBuilder: (_, i) => items[i],
    );
  }

  // ---------- FILTERS ----------
  Widget _filterRowWide() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _searchCtrl,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'ค้นหา ชื่อ รหัส หรือทะเบียนรถ...',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 200,
          child: DropdownButtonFormField<String>(
            value: _employeeFilter,
            items: _employeeNames
                .map((e) =>
                    DropdownMenuItem<String>(value: e, child: Text(e)))
                .toList(),
            onChanged: (v) => setState(() => _employeeFilter = v!),
            decoration: InputDecoration(
              labelText: 'พนักงาน',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 180,
          child: DropdownButtonFormField<String>(
            value: _statusFilter,
            items: _statuses
                .map((e) =>
                    DropdownMenuItem<String>(value: e, child: Text(e)))
                .toList(),
            onChanged: (v) => setState(() => _statusFilter = v!),
            decoration: InputDecoration(
              labelText: 'สถานะ',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        OutlinedButton.icon(
          onPressed: () {
            _searchCtrl.clear();
            _statusFilter = 'ทั้งหมด';
            _employeeFilter = 'ทั้งหมด';
            setState(() {});
          },
          icon: const Icon(Icons.filter_alt_off),
          label: const Text('ล้างตัวกรอง'),
        ),
      ],
    );
  }

  Widget _filterRowNarrow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _searchCtrl,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: 'ค้นหา ชื่อ / รหัส / ทะเบียนรถ',
            isDense: true,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _employeeFilter,
                items: _employeeNames
                    .map((e) =>
                        DropdownMenuItem<String>(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) => setState(() => _employeeFilter = v!),
                decoration: InputDecoration(
                  labelText: 'พนักงาน',
                  isDense: true,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _statusFilter,
                items: _statuses
                    .map((e) =>
                        DropdownMenuItem<String>(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) => setState(() => _statusFilter = v!),
                decoration: InputDecoration(
                  labelText: 'สถานะ',
                  isDense: true,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () {
              _searchCtrl.clear();
              setState(() {
                _statusFilter = 'ทั้งหมด';
                _employeeFilter = 'ทั้งหมด';
              });
            },
            icon: const Icon(Icons.filter_alt_off, size: 18),
            label: const Text('ล้างตัวกรอง'),
          ),
        ),
      ],
    );
  }

  // ---------- DESKTOP TABLE ----------
  Widget _tableSectionWide() {
    if (rowsFiltered.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child:
              Text('ไม่พบข้อมูล', style: TextStyle(fontSize: 16, color: Colors.grey)),
        ),
      );
    }

    return Column(
      children: [
        _tableHeader(),
        const SizedBox(height: 6),
        ...rowsFiltered.map(_tableRow).toList(),
      ],
    );
  }

  // ---------- MOBILE LIST ----------
  Widget _listSectionNarrow() {
    if (rowsFiltered.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child:
              Text('ไม่พบข้อมูล', style: TextStyle(fontSize: 16, color: Colors.grey)),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: rowsFiltered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _mobileRow(rowsFiltered[i]),
    );
  }

  // ---------- WIDGETS ----------
  Widget _summaryCard({
    required IconData icon,
    required String title,
    required String value,
    Color? color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: (color ?? Colors.blue).withOpacity(.15),
              child: Icon(icon, color: color ?? Colors.blue),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      value,
                      textHeightBehavior: const TextHeightBehavior(
                        applyHeightToFirstAscent: false,
                        applyHeightToLastDescent: false,
                      ),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: color ?? Colors.black,
                        height: 1.0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tableHeader() {
    TextStyle h = const TextStyle(
        fontWeight: FontWeight.w700, color: Colors.black87, fontSize: 13);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            _cell('รหัส', h, flex: 9),
            _cell('ชื่อ-นามสกุล', h, flex: 18),
            _cell('ทะเบียนรถ', h, flex: 12),
            _cell('วันเดือนปี', h, flex: 14),
            _cell('เงินเดือนฐาน', h, right: true, flex: 14),
            _cell('โบนัส', h, right: true, flex: 10),
            _cell('เงินเบิก', h, right: true, flex: 10),
            _cell('จำนวนเที่ยววิ่งงาน', h, right: true, flex: 12),
            _cell('เรต/เที่ยว', h, right: true, flex: 12),
            _cell('ราคารวมเที่ยวที่วิ่ง', h, right: true, flex: 16),
            _cell('เงินเดือนสุทธิ', h, right: true, flex: 18),
            _cell('สถานะ', h, center: true, flex: 10),
            _cell('จัดการ', h, center: true, flex: 9),
          ],
        ),
      ),
    );
  }

  Widget _tableRow(Map<String, dynamic> e) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            _cell(e['code'], null, flex: 9),
            _cell(e['name'], null, flex: 18),
            _cell(e['plate'], TextStyle(color: Colors.blue[700]), flex: 12),
            _cell(_fmtDate(e['payDate']), null, flex: 14),
            _cell(_fmtBaht(e['base']), null, right: true, flex: 14),
            _cell(_fmtBaht(e['bonus']), null, right: true, flex: 10),
            _cell(_fmtBaht(e['deduct']),
                const TextStyle(color: Colors.red),
                right: true,
                flex: 10),
            _cell('${_toNum(e['tripRuns']).toStringAsFixed(0)}', null,
                right: true, flex: 12),
            _cell(_fmtBaht(e['pricePerTrip']), null, right: true, flex: 12),
            _cell(
                _fmtBaht(e['runTotal']),
                const TextStyle(
                    color: Colors.indigo, fontWeight: FontWeight.w700),
                right: true,
                flex: 16),
            _cell(
                _fmtBaht(e['netSalary']),
                const TextStyle(
                    color: Colors.green, fontWeight: FontWeight.w700),
                right: true,
                flex: 18),
            // สถานะ
            Expanded(
              flex: 10,
              child: Align(
                alignment: Alignment.center,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _statusColor(e['status']).withOpacity(.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    e['status'],
                    style: TextStyle(
                        color: _statusColor(e['status']),
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
            // จัดการ
            Expanded(
              flex: 9,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                      tooltip: 'แก้ไข',
                      onPressed: () => _openEdit(e),
                      icon: const Icon(Icons.edit_outlined)),
                  IconButton(
                    tooltip: 'ลบ',
                    onPressed: () => _deleteItem(e),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mobileRow(Map<String, dynamic> e) {
    final onVar = Theme.of(context).colorScheme.onSurfaceVariant;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: onVar.withOpacity(.18)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(.03),
                blurRadius: 10,
                offset: const Offset(0, 6))
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              // Header
              Row(
                children: [
                  _IconBadgeMini(
                      icon: Icons.person_rounded, color: Colors.indigo),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e['name'],
                            style:
                                const TextStyle(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 2),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _Pill(text: 'รหัส ${e['code']}'),
                            _Pill(text: 'รถ ${e['plate']}'),
                            _Pill(text: _fmtDate(e['payDate'])),
                          ],
                        ),
                      ],
                    ),
                  ),
                  _StatusChipMobile(
                      text: e['status'], color: _statusColor(e['status'])),
                ],
              ),
              const SizedBox(height: 12),

              // Metrics grid
              LayoutBuilder(
                builder: (context, c) {
                  final isVeryNarrow = c.maxWidth < 360;
                  final cols = isVeryNarrow ? 1 : 2;
                  final tileH = isVeryNarrow ? 60.0 : 66.0;

                  final metrics = <Widget>[
                    _MetricTile(
                        label: 'เงินเดือนฐาน', value: _fmtBaht(e['base'])),
                    _MetricTile(label: 'โบนัส', value: _fmtBaht(e['bonus'])),
                    _MetricTile(
                        label: 'หักรวม',
                        value: _fmtBaht(e['deduct']),
                        danger: true),
                    _MetricTile(
                        label: 'เที่ยววิ่ง',
                        value: _toNum(e['tripRuns']).toStringAsFixed(0)),
                    _MetricTile(
                        label: 'เรต/เที่ยว',
                        value: _fmtBaht(e['pricePerTrip'])),
                    _MetricTile(
                        label: 'รวมเที่ยวที่วิ่ง',
                        value: _fmtBaht(e['runTotal']),
                        highlight: true),
                  ];

                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: metrics.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cols,
                      mainAxisExtent: tileH,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemBuilder: (_, i) => metrics[i],
                  );
                },
              ),

              const Divider(height: 20),

              // Net + actions
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                              color: Colors.green.withOpacity(.35), width: 2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Text('สุทธิ: ',
                              style: TextStyle(
                                  color: onVar, fontWeight: FontWeight.w700)),
                          const SizedBox(width: 4),
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                _fmtBaht(e['netSalary']),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: Colors.green,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                      tooltip: 'แก้ไข',
                      onPressed: () => _openEdit(e),
                      icon: const Icon(Icons.edit_outlined)),
                  IconButton(
                    tooltip: 'ลบ',
                    onPressed: () => _deleteItem(e),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- CELL / FOOTER ----------
  Widget _cell(String text, TextStyle? style,
      {bool right = false, bool center = false, int flex = 10}) {
    return Expanded(
      flex: flex,
      child: Align(
        alignment: right
            ? Alignment.centerRight
            : (center ? Alignment.center : Alignment.centerLeft),
        child: Text(text, style: style),
      ),
    );
  }

  Widget _footerGrid({required bool isWide}) {
    final items = <Widget>[
      _footerCard('เงินเดือนฐานรวม', _fmtBaht(totalBase), Colors.blue[100]!),
      _footerCard('โบนัสรวม', _fmtBaht(totalBonusFiltered), Colors.green[100]!),
      _footerCard(
          'ราคารวมเที่ยวที่วิ่ง', _fmtBaht(totalRun), Colors.indigo[100]!),
      _footerCard('หักเบิกรวม', _fmtBaht(totalDeduct), Colors.orange[100]!),
      _footerCard(
          'เงินเดือนสุทธิรวม', _fmtBaht(totalNet), Colors.red[100]!),
    ];
    final cross = isWide ? 5 : 2;
    final tileH = isWide ? 88.0 : 100.0;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cross,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        mainAxisExtent: tileH, // << ใช้ความสูงคงที่ กัน BOTTOM OVERFLOW
      ),
      itemBuilder: (_, i) => items[i],
    );
  }

  Widget _footerCard(String title, String value, Color bg) {
    return Card(
      color: bg,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                  color: Colors.black54, fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                textHeightBehavior: const TextHeightBehavior(
                  applyHeightToFirstAscent: false,
                  applyHeightToLastDescent: false,
                ),
                style: const TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 16, height: 1.0),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- FORM DIALOG ----------
  void _openAddItem() {
    showDialog(
      context: context,
      builder: (context) => PayrollFormDialog(
        vehiclesData: _vehiclesData,
        onSave: (data) async {
          try {
            final code =
                'PY${DateFormat('yyMMddHHmmss').format(DateTime.now())}';

            final payrollData = {
              'code': code,
              'driver': data['name'],
              'plate': data['plate'],
              'payDate': Timestamp.fromDate(data['payDate']),
              'base': data['base'],
              'bonus': data['bonus'],
              'deduct': data['deduct'],
              'tripRuns': data['tripRuns'],
              'jobsPerTrip': data['pricePerTrip'],
              'status': data['status'],
              'note': data['note'],
              'createdAt': FieldValue.serverTimestamp(),
            };

            await _firestore.collection('payrolls').add(payrollData);
            Navigator.pop(context);
            _showSnack('เพิ่มรายการเงินเดือนเรียบร้อย');
            await _loadData();
            setState(() {});
          } catch (e) {
            _showSnack('เกิดข้อผิดพลาด: $e');
          }
        },
      ),
    );
  }

  void _openEdit(Map<String, dynamic> row) {
    showDialog(
      context: context,
      builder: (context) => PayrollFormDialog(
        initialData: row,
        vehiclesData: _vehiclesData,
        onSave: (data) async {
          try {
            final querySnapshot = await _firestore
                .collection('payrolls')
                .where('code', isEqualTo: row['code'])
                .get();

            if (querySnapshot.docs.isNotEmpty) {
              final docId = querySnapshot.docs.first.id;
              final payrollData = {
                'driver': data['name'],
                'plate': data['plate'],
                'payDate': Timestamp.fromDate(data['payDate']),
                'base': data['base'],
                'bonus': data['bonus'],
                'deduct': data['deduct'],
                'tripRuns': data['tripRuns'],
                'jobsPerTrip': data['pricePerTrip'],
                'status': data['status'],
                'note': data['note'],
                'updatedAt': FieldValue.serverTimestamp(),
              };

              await _firestore
                  .collection('payrolls')
                  .doc(docId)
                  .update(payrollData);
              Navigator.pop(context);
              _showSnack('อัพเดทรายการเงินเดือนเรียบร้อย');
              await _loadData();
              setState(() {});
            }
          } catch (e) {
            _showSnack('เกิดข้อผิดพลาด: $e');
          }
        },
      ),
    );
  }

  void _deleteItem(Map<String, dynamic> row) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ยืนยันการลบ'),
        content: Text('ต้องการลบรายการของ ${row['name']} ใช่หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                final querySnapshot = await _firestore
                    .collection('payrolls')
                    .where('code', isEqualTo: row['code'])
                    .get();

                if (querySnapshot.docs.isNotEmpty) {
                  final docId = querySnapshot.docs.first.id;
                  await _firestore.collection('payrolls').doc(docId).delete();
                  Navigator.pop(context);
                  _showSnack('ลบรายการเรียบร้อยแล้ว');
                  await _loadData();
                  setState(() {});
                }
              } catch (e) {
                _showSnack('เกิดข้อผิดพลาด: $e');
              }
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('ลบ'),
          ),
        ],
      ),
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

// ---------- PAYROLL FORM DIALOG ----------
class PayrollFormDialog extends StatefulWidget {
  final Map<String, dynamic>? initialData;
  final List<Map<String, dynamic>> vehiclesData;
  final Function(Map<String, dynamic>) onSave;

  const PayrollFormDialog({
    Key? key,
    this.initialData,
    required this.vehiclesData,
    required this.onSave,
  }) : super(key: key);

  @override
  State<PayrollFormDialog> createState() => _PayrollFormDialogState();
}

class _PayrollFormDialogState extends State<PayrollFormDialog> {
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _plateCtrl = TextEditingController();
  final _baseCtrl = TextEditingController(text: '0');
  final _bonusCtrl = TextEditingController(text: '0');
  final _deductCtrl = TextEditingController(text: '0');
  final _tripRunsCtrl = TextEditingController(text: '0');
  final _pricePerTripCtrl = TextEditingController(text: '0');
  final _noteCtrl = TextEditingController();

  DateTime _payDate = DateTime.now();
  String _status = 'รอจ่าย';
  String? _selectedVehicleId;

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      _loadInitialData();
    }
  }

  void _loadInitialData() {
    final data = widget.initialData!;
    _nameCtrl.text = data['name'] ?? '';
    _plateCtrl.text = data['plate'] ?? '';
    _baseCtrl.text = data['base'].toString();
    _bonusCtrl.text = data['bonus'].toString();
    _deductCtrl.text = data['deduct'].toString();
    _tripRunsCtrl.text = data['tripRuns'].toString();
    _pricePerTripCtrl.text = data['pricePerTrip'].toString();
    _noteCtrl.text = data['note'] ?? '';
    _payDate = data['payDate'] ?? DateTime.now();
    _status = data['status'] ?? 'รอจ่าย';
  }

  void _onVehicleSelected(String? vehicleId) {
    if (vehicleId != null) {
      final selectedVehicle = widget.vehiclesData.firstWhere(
        (vehicle) => vehicle['id'] == vehicleId,
        orElse: () => {},
      );

      if (selectedVehicle.isNotEmpty) {
        setState(() {
          _selectedVehicleId = vehicleId;
          _nameCtrl.text = selectedVehicle['driver'] ?? '';
          _plateCtrl.text = selectedVehicle['plate'] ?? '';
        });
      }
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _payDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != _payDate) {
      setState(() => _payDate = picked);
    }
  }

  void _saveForm() {
    if (_formKey.currentState!.validate()) {
      final data = {
        'name': _nameCtrl.text.trim(),
        'plate': _plateCtrl.text.trim(),
        'payDate': _payDate,
        'base': double.parse(_baseCtrl.text),
        'bonus': double.parse(_bonusCtrl.text),
        'deduct': double.parse(_deductCtrl.text),
        'tripRuns': int.parse(_tripRunsCtrl.text),
        'pricePerTrip': double.parse(_pricePerTripCtrl.text),
        'status': _status,
        'note': _noteCtrl.text.trim(),
      };
      widget.onSave(data);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(widget.initialData == null ? Icons.add : Icons.edit,
              color: Colors.blue),
          const SizedBox(width: 8),
          Text(widget.initialData == null
              ? 'เพิ่มรายการเงินเดือน'
              : 'แก้ไขรายการเงินเดือน'),
        ],
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Dropdown เลือกรถ
              DropdownButtonFormField<String>(
                value: _selectedVehicleId,
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('-- เลือกรถ --'),
                  ),
                  ...widget.vehiclesData.map((vehicle) {
                    return DropdownMenuItem<String>(
                      value: vehicle['id'],
                      child: Text('${vehicle['driver']} - ${vehicle['plate']}'),
                    );
                  }).toList(),
                ],
                onChanged: _onVehicleSelected,
                decoration: const InputDecoration(
                  labelText: 'เลือกรถ *',
                  hintText: 'เลือกชื่อคนขับและทะเบียนรถ',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'กรุณาเลือกรถ';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameCtrl,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'ชื่อ-นามสกุล *',
                  hintText: 'จะถูกกรอกอัตโนมัติเมื่อเลือกรถ',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _plateCtrl,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'ทะเบียนรถ *',
                  hintText: 'จะถูกกรอกอัตโนมัติเมื่อเลือกรถ',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _baseCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'เงินเดือนฐาน *',
                  hintText: '0',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'กรุณากรอกเงินเดือนฐาน';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _bonusCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'โบนัส',
                  hintText: '0',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _deductCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'หักเบิก',
                  hintText: '0',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _tripRunsCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'จำนวนเที่ยว *',
                        hintText: '0',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'กรุณากรอกจำนวนเที่ยว';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _pricePerTripCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'เรต/เที่ยว *',
                        hintText: '0',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'กรุณากรอกราคาต่อเที่ยว';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                readOnly: true,
                controller: TextEditingController(
                  text: DateFormat('dd/MM/yyyy').format(_payDate),
                ),
                onTap: _selectDate,
                decoration: const InputDecoration(
                  labelText: 'วันที่จ่าย *',
                  suffixIcon: Icon(Icons.calendar_today),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _status,
                items: ['รอจ่าย', 'จ่ายแล้ว', 'ยกเลิก'].map((status) {
                  return DropdownMenuItem<String>(
                    value: status,
                    child: Text(status),
                  );
                }).toList(),
                onChanged: (value) => setState(() => _status = value!),
                decoration: const InputDecoration(
                  labelText: 'สถานะ *',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _noteCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'หมายเหตุ',
                  hintText: 'กรอกหมายเหตุเพิ่มเติม (ถ้ามี)',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('ยกเลิก'),
        ),
        FilledButton(
          onPressed: _saveForm,
          child: const Text('บันทึก'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _plateCtrl.dispose();
    _baseCtrl.dispose();
    _bonusCtrl.dispose();
    _deductCtrl.dispose();
    _tripRunsCtrl.dispose();
    _pricePerTripCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }
}

/* ================== Helpers (Mobile UI) ================== */

class _IconBadgeMini extends StatelessWidget {
  final IconData icon;
  final Color color;
  const _IconBadgeMini({required this.icon, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [color.withOpacity(.16), color.withOpacity(.10)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [BoxShadow(color: color.withOpacity(.10), blurRadius: 10)],
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  const _Pill({required this.text});
  @override
  Widget build(BuildContext context) {
    final onVar = Theme.of(context).colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: onVar.withOpacity(.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text, style: TextStyle(color: onVar, fontSize: 12)),
    );
  }
}

class _StatusChipMobile extends StatelessWidget {
  final String text;
  final Color color;
  const _StatusChipMobile({required this.text, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(.18)),
      ),
      child: Text(text,
          style: TextStyle(color: color, fontWeight: FontWeight.w700)),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label, value;
  final bool highlight, danger;
  const _MetricTile({
    required this.label,
    required this.value,
    this.highlight = false,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final base =
        danger ? Colors.red : (highlight ? Colors.indigo : Colors.grey);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: base.withOpacity(.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: base.withOpacity(.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style:
                const TextStyle(fontSize: 11, color: Colors.black54, height: 1),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  textHeightBehavior: const TextHeightBehavior(
                    applyHeightToFirstAscent: false,
                    applyHeightToLastDescent: false,
                  ),
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: danger ? Colors.red : (highlight ? Colors.indigo : null),
                    height: 1.0,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
