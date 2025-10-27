// lib/screens/admin/soil_calculator_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:file_saver/file_saver.dart';
import 'dart:typed_data';

// ====== ราคาเริ่มต้นต่อหน่วย (฿/ลบ.ม.) ตามประเภทดิน ======
const Map<String, double> kSoilPrices = {
  'ดินดำ': 180,
  'ดินซีแลค': 220,
  'ลูกรัง': 250,
  'หินคลุก': 300,
};

class SoilItem {
  String projectName;
  String plate;
  DateTime startDate;
  int tripCount;
  String soilType;
  double unitPrice;
  double width;
  double length;
  double height;
  double fuelCost;
  DateTime createdAt;
  String dropLocation;
  String startLocation;

  SoilItem({
    required this.projectName,
    required this.plate,
    required this.startDate,
    required this.tripCount,
    required this.soilType,
    required this.unitPrice,
    required this.width,
    required this.length,
    required this.height,
    required this.fuelCost,
    required this.createdAt,
    required this.dropLocation,
    required this.startLocation,
  });

  double get volume => width * length * height;
  double get soilPrice => volume * unitPrice * tripCount;
  double get netPrice => soilPrice - fuelCost;

  Map<String, dynamic> toMap() {
    return {
      'projectName': projectName,
      'plate': plate,
      'startDate': Timestamp.fromDate(startDate),
      'tripCount': tripCount,
      'soilType': soilType,
      'unitPrice': unitPrice,
      'width': width,
      'length': length,
      'height': height,
      'fuelCost': fuelCost,
      'volume': volume,
      'soilPrice': soilPrice,
      'netPrice': netPrice,
      'createdAt': Timestamp.fromDate(createdAt),
      'timestamp': FieldValue.serverTimestamp(),
      'dropLocation': dropLocation,
      'startLocation': startLocation,
    };
  }
}

class ProjectSummary {
  String projectName;
  List<SoilItem> items;

  ProjectSummary({
    required this.projectName,
    required this.items,
  });

  double get totalVolume => items.fold(0.0, (sum, item) => sum + (item.volume * item.tripCount));
  double get totalSoilPrice => items.fold(0.0, (sum, item) => sum + item.soilPrice);
  double get totalFuelCost => items.fold(0.0, (sum, item) => sum + item.fuelCost);
  double get netPrice => totalSoilPrice - totalFuelCost;
  int get totalTrips => items.fold(0, (sum, item) => sum + item.tripCount);
  int get vehicleCount => items.map((item) => item.plate).toSet().length;
}

class SoilCalculatorScreen extends StatefulWidget {
  const SoilCalculatorScreen({super.key});

  @override
  State<SoilCalculatorScreen> createState() => _SoilCalculatorScreenState();
}

class _SoilCalculatorScreenState extends State<SoilCalculatorScreen> {
  static const double _breakWide = 900;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ---------- form controllers ----------
  final _projectCtrl = TextEditingController();
  final _plateCtrl = TextEditingController();
  final _startDateCtrl = TextEditingController();
  final _tripCountCtrl = TextEditingController(text: '1');
  final _wCtrl = TextEditingController(text: '2.5');
  final _lCtrl = TextEditingController(text: '8.0');
  final _hCtrl = TextEditingController(text: '1.5');
  final _fuelCostCtrl = TextEditingController(text: '0');
  final _dropLocationCtrl = TextEditingController();
  final _startLocationCtrl = TextEditingController();

  String _soilType = 'ดินดำ';
  String? _selectedPlate;
  final _unitPriceCtrl = TextEditingController(text: kSoilPrices['ดินดำ']!.toStringAsFixed(2));

  final _searchCtrl = TextEditingController();
  DateTime _selectedDate = DateTime.now();

  final _fmtNum = NumberFormat('#,##0.##');
  final _fmtMoney = NumberFormat.currency(locale: 'th_TH', symbol: '฿');
  final _fmtDate = DateFormat('dd/MM/yyyy');
  final _fmtDt = DateFormat('dd/MM/yyyy HH:mm');

  // ---------- data ----------
  List<SoilItem> _previewItems = [];
  List<SoilItem> _savedItems = [];
  List<String> _vehiclePlates = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
    _startDateCtrl.text = _fmtDate.format(_selectedDate);
  }

  @override
  void dispose() {
    _projectCtrl.dispose();
    _plateCtrl.dispose();
    _startDateCtrl.dispose();
    _tripCountCtrl.dispose();
    _wCtrl.dispose();
    _lCtrl.dispose();
    _hCtrl.dispose();
    _fuelCostCtrl.dispose();
    _unitPriceCtrl.dispose();
    _searchCtrl.dispose();
    _dropLocationCtrl.dispose();
    _startLocationCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    await _loadVehiclePlates();
    await _loadSoilCalculations();
  }

  Future<void> _loadVehiclePlates() async {
    try {
      final querySnapshot = await _firestore.collection('vehicles').get();
      final plates = <String>[];
      for (final doc in querySnapshot.docs) {
        final plate = doc.data()['plate'];
        if (plate != null && plate is String && plate.isNotEmpty) {
          plates.add(plate);
        }
      }
      setState(() {
        _vehiclePlates = plates.toSet().toList()..sort();
      });
    } catch (e) {
      print('Error loading vehicles: $e');
    }
  }

  Future<void> _loadSoilCalculations() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final querySnapshot = await _firestore
          .collection('soil_calculations')
          .orderBy('timestamp', descending: true)
          .get();

      final items = <SoilItem>[];
      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        items.add(SoilItem(
          projectName: data['projectName'] ?? '',
          plate: data['plate'] ?? '',
          startDate: (data['startDate'] as Timestamp).toDate(),
          tripCount: (data['tripCount'] as num).toInt(),
          soilType: data['soilType'] ?? '',
          unitPrice: (data['unitPrice'] as num).toDouble(),
          width: (data['width'] as num).toDouble(),
          length: (data['length'] as num).toDouble(),
          height: (data['height'] as num).toDouble(),
          fuelCost: (data['fuelCost'] as num? ?? 0).toDouble(),
          createdAt: (data['createdAt'] as Timestamp).toDate(),
          dropLocation: data['dropLocation'] ?? '',
          startLocation: data['startLocation'] ?? '',
        ));
      }

      setState(() {
        _savedItems = items;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading soil calculations: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  double _parseDouble(String s, double fallback) {
    final v = double.tryParse(s.replaceAll(',', '.'));
    return v ?? fallback;
  }

  int _parseInt(String s, int fallback) {
    final v = int.tryParse(s);
    return v ?? fallback;
  }

  void _onSoilTypeChanged(String? value) {
    if (value == null) return;
    setState(() {
      _soilType = value;
      _unitPriceCtrl.text = kSoilPrices[value]!.toStringAsFixed(2);
    });
  }

  void _onPlateChanged(String? value) {
    setState(() {
      _selectedPlate = value;
    });
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _startDateCtrl.text = _fmtDate.format(picked);
      });
    }
  }

  void _clearForm() {
    _projectCtrl.clear();
    setState(() {
      _selectedPlate = null;
    });
    _startDateCtrl.text = _fmtDate.format(DateTime.now());
    _tripCountCtrl.text = '1';
    _wCtrl.text = '2.5';
    _lCtrl.text = '8.0';
    _hCtrl.text = '1.5';
    _soilType = 'ดินดำ';
    _unitPriceCtrl.text = kSoilPrices['ดินดำ']!.toStringAsFixed(2);
    _fuelCostCtrl.text = '0';
    _dropLocationCtrl.clear();
    _startLocationCtrl.clear();
    _selectedDate = DateTime.now();
  }

  void _clearAll() {
    _projectCtrl.clear();
    _previewItems.clear();
    _clearForm();
    setState(() {});
  }

  void _addToPreview() {
    final projectName = _projectCtrl.text.trim();
    final plate = _selectedPlate;

    if (projectName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรอกชื่อโครงการก่อน')),
      );
      return;
    }

    if (plate == null || plate.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('เลือกทะเบียนรถก่อน')),
      );
      return;
    }

    final tripCount = _parseInt(_tripCountCtrl.text, 1);
    final width = _parseDouble(_wCtrl.text, 0);
    final length = _parseDouble(_lCtrl.text, 0);
    final height = _parseDouble(_hCtrl.text, 0);
    final unitPrice = _parseDouble(_unitPriceCtrl.text, kSoilPrices[_soilType] ?? 0.0);
    final fuelCost = _parseDouble(_fuelCostCtrl.text, 0);

    if (tripCount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('จำนวนเที่ยวต้องมากกว่า 0')),
      );
      return;
    }

    if (width <= 0 || length <= 0 || height <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ค่ากว้าง/ยาว/สูง ต้องมากกว่า 0')),
      );
      return;
    }

    if (unitPrice <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ราคาดินต่อหน่วย ต้องมากกว่า 0')),
      );
      return;
    }

    if (fuelCost < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ค่าน้ำมันต้องไม่ต่ำกว่า 0')),
      );
      return;
    }

    final existingIndex = _previewItems.indexWhere((item) =>
        item.projectName == projectName && item.plate == plate);

    final newItem = SoilItem(
      projectName: projectName,
      plate: plate,
      startDate: _selectedDate,
      tripCount: tripCount,
      soilType: _soilType,
      unitPrice: unitPrice,
      width: width,
      length: length,
      height: height,
      fuelCost: fuelCost,
      createdAt: DateTime.now(),
      dropLocation: _dropLocationCtrl.text.trim(),
      startLocation: _startLocationCtrl.text.trim(),
    );

    setState(() {
      if (existingIndex >= 0) {
        _previewItems[existingIndex] = newItem;
      } else {
        _previewItems.add(newItem);
      }
    });

    _clearForm();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(existingIndex >= 0 ? 'อัพเดทข้อมูลเรียบร้อย' : 'เพิ่มข้อมูลเรียบร้อย')),
    );
  }

  void _removeFromPreview(int index) {
    setState(() {
      _previewItems.removeAt(index);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('ลบรายการเรียบร้อย')),
    );
  }

  Future<void> _saveToFirebase() async {
    if (_previewItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ไม่มีข้อมูลที่จะบันทึก')),
      );
      return;
    }

    try {
      final batch = _firestore.batch();

      for (final item in _previewItems) {
        final docRef = _firestore.collection('soil_calculations').doc();
        batch.set(docRef, item.toMap());
      }

      await batch.commit();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('บันทึกข้อมูล ${_previewItems.length} รายการเรียบร้อย')),
      );

      setState(() {
        _previewItems.clear();
      });
      await _loadSoilCalculations();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
      );
    }
  }

 // ---------- EXCEL EXPORT (fixed name & path logging) ----------
Future<void> _exportToExcel() async {
  try {
    final excel = Excel.createExcel();
    final sheet = excel['คำนวณปริมาณดิน'];

    // ===== Header =====
    final headers = [
      'โครงการ', 'ทะเบียนรถ', 'วันที่เริ่ม', 'จำนวนเที่ยว', 'ประเภทดิน',
      'กว้าง (ม.)', 'ยาว (ม.)', 'สูง (ม.)', 'ปริมาตร (ลบ.ม.)',
      'ราคาต่อหน่วย', 'ราคาดินรวม', 'ค่าน้ำมัน', 'เงินสุทธิ'
    ];
    for (int i = 0; i < headers.length; i++) {
      sheet.cell(CellIndex.indexByString('${String.fromCharCode(65 + i)}1'))
        ..value = headers[i]
        ..cellStyle = CellStyle(bold: true, backgroundColorHex: '#E8F5E8');
    }

    // ===== Rows =====
    final allItems = [..._savedItems, ..._previewItems];
    for (int i = 0; i < allItems.length; i++) {
      final it = allItems[i];
      final r = i + 2;
      sheet.cell(CellIndex.indexByString('A$r')).value = it.projectName;
      sheet.cell(CellIndex.indexByString('B$r')).value = it.plate;
      sheet.cell(CellIndex.indexByString('C$r')).value = _fmtDate.format(it.startDate);
      sheet.cell(CellIndex.indexByString('D$r')).value = it.tripCount;
      sheet.cell(CellIndex.indexByString('E$r')).value = it.soilType;
      sheet.cell(CellIndex.indexByString('F$r')).value = it.width;
      sheet.cell(CellIndex.indexByString('G$r')).value = it.length;
      sheet.cell(CellIndex.indexByString('H$r')).value = it.height;
      sheet.cell(CellIndex.indexByString('I$r')).value = it.volume;
      sheet.cell(CellIndex.indexByString('J$r')).value = it.unitPrice;
      sheet.cell(CellIndex.indexByString('K$r')).value = it.soilPrice;
      sheet.cell(CellIndex.indexByString('L$r')).value = it.fuelCost;
      sheet.cell(CellIndex.indexByString('M$r')).value = it.netPrice;
    }

    // ===== Summary by project =====
    final summaryRow = allItems.length + 3;
    sheet.cell(CellIndex.indexByString('A$summaryRow')).value = 'สรุปตามโครงการ';
    sheet.cell(CellIndex.indexByString('A${summaryRow + 1}')).value = 'โครงการ';
    sheet.cell(CellIndex.indexByString('B${summaryRow + 1}')).value = 'จำนวนรถ';
    sheet.cell(CellIndex.indexByString('C${summaryRow + 1}')).value = 'เที่ยวทั้งหมด';
    sheet.cell(CellIndex.indexByString('D${summaryRow + 1}')).value = 'ปริมาตรรวม';
    sheet.cell(CellIndex.indexByString('E${summaryRow + 1}')).value = 'ราคาดินรวม';
    sheet.cell(CellIndex.indexByString('F${summaryRow + 1}')).value = 'ค่าน้ำมันรวม';
    sheet.cell(CellIndex.indexByString('G${summaryRow + 1}')).value = 'เงินสุทธิ';

    int idx = 0;
    for (final p in _projectSummaries) {
      final r = summaryRow + 2 + idx++;
      sheet.cell(CellIndex.indexByString('A$r')).value = p.projectName;
      sheet.cell(CellIndex.indexByString('B$r')).value = p.vehicleCount;
      sheet.cell(CellIndex.indexByString('C$r')).value = p.totalTrips;
      sheet.cell(CellIndex.indexByString('D$r')).value = p.totalVolume;
      sheet.cell(CellIndex.indexByString('E$r')).value = p.totalSoilPrice;
      sheet.cell(CellIndex.indexByString('F$r')).value = p.totalFuelCost;
      sheet.cell(CellIndex.indexByString('G$r')).value = p.netPrice;
    }

    // ===== Grand total =====
    final totalRow = summaryRow + 2 + _projectSummaries.length + 1;
    sheet.cell(CellIndex.indexByString('A$totalRow')).value = 'สรุปรวมทั้งหมด';
    sheet.cell(CellIndex.indexByString('E$totalRow')).value = _totalSoilPrice;
    sheet.cell(CellIndex.indexByString('F$totalRow')).value = _totalFuelCost;
    sheet.cell(CellIndex.indexByString('G$totalRow')).value = _totalNetPrice;

    // ===== Save (fixed) =====
    final bytes = excel.save();
    if (bytes == null) {
      _showSnack('ไม่สามารถสร้างไฟล์ Excel ได้');
      return;
    }

    // NOTE: ใช้ "name" ที่ไม่ใส่ .xlsx และกำหนด ext: "xlsx" เพื่อเลี่ยง .xlsx.xlsx
    final fileNameNoExt = 'soil_calculation_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}';

    // ถ้า lib รองรับ ให้ระบุ mimeType จะช่วยให้ไปโฟลเดอร์ "Downloads" ได้บ่อยขึ้นในบางรุ่น
    final savedPath = await FileSaver.instance.saveFile(
      name: fileNameNoExt,
      bytes: Uint8List.fromList(bytes),
      ext: 'xlsx',
      // mimeType: MimeType.microsoftExcel, // <- uncomment ถ้าแพ็กเกจรองรับ
    );

    debugPrint('Excel saved to: $savedPath');
    _showSnack('ส่งออกไฟล์แล้ว: $savedPath');

    // ถ้าอยากเปิดไฟล์ทันที (ต้องเพิ่มแพ็กเกจ open_filex):
    // await OpenFilex.open(savedPath);

  } catch (e) {
    _showSnack('เกิดข้อผิดพลาดในการส่งออก: $e');
  }
}

  Future<void> _deleteSavedItem(SoilItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('ลบรายการ'),
        content: Text('ลบรายการ ${item.plate} ออกจากโครงการ ${item.projectName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ลบ'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final querySnapshot = await _firestore
            .collection('soil_calculations')
            .where('projectName', isEqualTo: item.projectName)
            .where('plate', isEqualTo: item.plate)
            .where('startDate', isEqualTo: Timestamp.fromDate(item.startDate))
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          await _firestore.collection('soil_calculations').doc(querySnapshot.docs.first.id).delete();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ลบรายการเรียบร้อย')),
          );
          await _loadSoilCalculations();
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
        );
      }
    }
  }

  Future<void> _deleteProject(String projectName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('ลบโครงการ'),
        content: Text('ลบโครงการ "$projectName" ทั้งหมด? การกระทำนี้ไม่สามารถย้อนกลับได้'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ลบทั้งหมด'),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final querySnapshot = await _firestore
            .collection('soil_calculations')
            .where('projectName', isEqualTo: projectName)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          final batch = _firestore.batch();
          for (final doc in querySnapshot.docs) {
            batch.delete(doc.reference);
          }
          await batch.commit();

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('ลบโครงการ "$projectName" เรียบร้อย (${querySnapshot.docs.length} รายการ)')),
          );
          await _loadSoilCalculations();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ไม่พบข้อมูลโครงการนี้')),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
        );
      }
    }
  }

  List<ProjectSummary> get _projectSummaries {
    final allItems = [..._savedItems, ..._previewItems];
    final projectMap = <String, ProjectSummary>{};

    for (final item in allItems) {
      if (!projectMap.containsKey(item.projectName)) {
        projectMap[item.projectName] = ProjectSummary(
          projectName: item.projectName,
          items: [],
        );
      }

      final summary = projectMap[item.projectName]!;
      projectMap[item.projectName] = ProjectSummary(
        projectName: item.projectName,
        items: [...summary.items, item],
      );
    }

    return projectMap.values.toList();
  }

  double get _totalSoilPrice => _projectSummaries.fold(0.0, (sum, project) => sum + project.totalSoilPrice);
  double get _totalFuelCost => _projectSummaries.fold(0.0, (sum, project) => sum + project.totalFuelCost);
  double get _totalNetPrice => _projectSummaries.fold(0.0, (sum, project) => sum + project.netPrice);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final w = MediaQuery.of(context).size.width;
    final isWide = w >= _breakWide;

    return Scaffold(
      appBar: AppBar(
        title: const Text('คำนวณปริมาณดิน'),
        actions: [
          IconButton(
            tooltip: 'ส่งออก Excel',
            onPressed: _exportToExcel,
            icon: const Icon(Icons.file_download_outlined),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  // ---------- แถบค้นหา ----------
                  isWide ? _searchRowWide() : _searchRowNarrow(),
                  const SizedBox(height: 12),

                  // ---------- แบบฟอร์มเพิ่ม ----------
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            const Icon(Icons.add_box_outlined, size: 18),
                            const SizedBox(width: 6),
                            Text('เพิ่มข้อมูลการคำนวณ',
                                style: TextStyle(fontWeight: FontWeight.w700, color: cs.primary)),
                          ]),
                          const SizedBox(height: 10),
                          _formWrap(isWide),
                        ],
                      ),
                    ),
                  ),

                  // ---------- พรีวิว ----------
                  if (_previewItems.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ===== หัวพรีวิวแบบยืดหยุ่น (กันปุ่มล้น) =====
                            LayoutBuilder(
                              builder: (ctx, c) {
                                final ww = c.maxWidth;
                                final veryNarrow = ww < 340; // เล็กมาก -> ไอคอนล้วน
                                final shortText  = ww < 420; // แคบ -> ย่อข้อความ

                                final saveLabel  = veryNarrow ? '' : (shortText ? 'บันทึก' : 'บันทึกข้อมูล');
                                final clearLabel = veryNarrow ? '' : (shortText ? 'ล้าง'   : 'ล้างทั้งหมด');

                                final filledStyle = FilledButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  minimumSize: const Size(0, 36),
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
                                );
                                final outlinedStyle = OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  minimumSize: const Size(0, 36),
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
                                );

                                return Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  alignment: WrapAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.preview, size: 18),
                                        const SizedBox(width: 6),
                                        Text(
                                          'พรีวิวข้อมูล (${_previewItems.length} รายการ)',
                                          style: const TextStyle(fontWeight: FontWeight.w700),
                                        ),
                                      ],
                                    ),
                                    Wrap(
                                      spacing: 8,
                                      children: [
                                        veryNarrow
                                            ? SizedBox(
                                                height: 36,
                                                child: FilledButton(
                                                  onPressed: _saveToFirebase,
                                                  style: filledStyle,
                                                  child: const Icon(Icons.save),
                                                ),
                                              )
                                            : FilledButton.icon(
                                                onPressed: _saveToFirebase,
                                                icon: const Icon(Icons.save),
                                                label: Text(saveLabel),
                                                style: filledStyle,
                                              ),
                                        veryNarrow
                                            ? SizedBox(
                                                height: 36,
                                                child: OutlinedButton(
                                                  onPressed: _clearAll,
                                                  style: outlinedStyle,
                                                  child: const Icon(Icons.clear_all),
                                                ),
                                              )
                                            : OutlinedButton.icon(
                                                onPressed: _clearAll,
                                                icon: const Icon(Icons.clear_all),
                                                label: Text(clearLabel),
                                                style: outlinedStyle,
                                              ),
                                      ],
                                    ),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 10),
                            // มือถือใช้การ์ด / จอกว้างใช้ตาราง
                            if (isWide) _previewTableView() else _previewCardsMobile(),
                          ],
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 12),

                  // ---------- สรุปผลตามโครงการ ----------
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
                      child: Row(
                        children: const [
                          Icon(Icons.summarize_outlined, size: 18),
                          SizedBox(width: 6),
                          Text('สรุปผลตามโครงการ', style: TextStyle(fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  _buildProjectSummaries(),

                  // ---------- สรุปผลรวมทั้งหมด ----------
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: _summaryItem('รวมราคาดิน', _fmtMoney.format(_totalSoilPrice), Colors.blue),
                          ),
                          Expanded(
                            child: _summaryItem('รวมค่าน้ำมัน', _fmtMoney.format(_totalFuelCost), Colors.orange),
                          ),
                          Expanded(
                            child: _summaryItem('รวมเงินสุทธิ', _fmtMoney.format(_totalNetPrice), Colors.green, true),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _searchRowWide() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _searchCtrl,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'ค้นหาชื่อโครงการ',
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Row(
          children: [
            const Icon(Icons.access_time, size: 16),
            const SizedBox(width: 6),
            Text(DateFormat('HH:mm').format(DateTime.now())),
          ],
        ),
      ],
    );
  }

  Widget _searchRowNarrow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _searchCtrl,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: 'ค้นหาชื่อโครงการ',
            isDense: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            const Icon(Icons.access_time, size: 16),
            const SizedBox(width: 6),
            Text(DateFormat('HH:mm').format(DateTime.now())),
          ],
        ),
      ],
    );
  }

  Widget _formWrap(bool isWide) {
    return Wrap(
      runSpacing: 10,
      spacing: 10,
      children: [
        SizedBox(
          width: isWide ? 300 : double.infinity,
          child: TextField(
            controller: _projectCtrl,
            decoration: const InputDecoration(
              labelText: 'ชื่อโครงการ *',
              hintText: 'กรอกชื่อโครงการ',
            ),
          ),
        ),
        SizedBox(
          width: isWide ? 200 : double.infinity,
          child: _buildPlateDropdown(),
        ),
        SizedBox(
          width: isWide ? 150 : (MediaQuery.of(context).size.width / 2) - 22,
          child: TextField(
            controller: _startDateCtrl,
            readOnly: true,
            onTap: _selectDate,
            decoration: const InputDecoration(
              labelText: 'วันที่เริ่มทำงาน',
              suffixIcon: Icon(Icons.calendar_today),
            ),
          ),
        ),
        SizedBox(
          width: isWide ? 120 : (MediaQuery.of(context).size.width / 3) - 18,
          child: TextField(
            controller: _tripCountCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'จำนวนเที่ยว *'),
          ),
        ),
        SizedBox(
          width: isWide ? 150 : (MediaQuery.of(context).size.width / 2) - 22,
          child: DropdownButtonFormField<String>(
            value: _soilType,
            items: kSoilPrices.keys
                .map((t) => DropdownMenuItem<String>(value: t, child: Text(t)))
                .toList(),
            onChanged: _onSoilTypeChanged,
            decoration: const InputDecoration(labelText: 'ประเภทดิน'),
          ),
        ),
        SizedBox(
          width: isWide ? 150 : (MediaQuery.of(context).size.width / 2) - 22,
          child: TextField(
            controller: _unitPriceCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'ราคาดินต่อหน่วย (฿/ลบ.ม.) *'),
          ),
        ),
        SizedBox(
          width: isWide ? 110 : (MediaQuery.of(context).size.width / 4) - 16,
          child: TextField(
            controller: _wCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'ความกว้าง (ม.) *'),
          ),
        ),
        SizedBox(
          width: isWide ? 110 : (MediaQuery.of(context).size.width / 4) - 16,
          child: TextField(
            controller: _lCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'ความยาว (ม.) *'),
          ),
        ),
        SizedBox(
          width: isWide ? 110 : (MediaQuery.of(context).size.width / 4) - 16,
          child: TextField(
            controller: _hCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'ความสูง (ม.) *'),
          ),
        ),
        SizedBox(
          width: isWide ? 150 : (MediaQuery.of(context).size.width / 2) - 22,
          child: TextField(
            controller: _fuelCostCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'ค่าน้ำมัน (฿)',
              hintText: '0',
            ),
          ),
        ),
        SizedBox(
          width: isWide ? 200 : double.infinity,
          child: TextField(
            controller: _startLocationCtrl,
            decoration: const InputDecoration(
              labelText: 'จุดรับดิน',
              hintText: 'ระบุสถานที่รับดิน',
            ),
          ),
        ),
        SizedBox(
          width: isWide ? 200 : double.infinity,
          child: TextField(
            controller: _dropLocationCtrl,
            decoration: const InputDecoration(
              labelText: 'จุดส่งดิน',
              hintText: 'ระบุสถานที่ส่งดิน',
            ),
          ),
        ),
        const SizedBox(width: 10),
        FilledButton.icon(
          onPressed: _addToPreview,
          icon: const Icon(Icons.add),
          label: const Text('เพิ่มข้อมูล'),
        ),
        OutlinedButton.icon(
          onPressed: _clearForm,
          icon: const Icon(Icons.clear),
          label: const Text('เคลียร์ฟอร์ม'),
        ),
      ],
    );
  }

  Widget _buildPlateDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedPlate,
      items: _vehiclePlates
          .map((p) => DropdownMenuItem<String>(value: p, child: Text(p)))
          .toList(),
      onChanged: _onPlateChanged,
      decoration: const InputDecoration(
        labelText: 'ทะเบียนรถ *',
        hintText: 'เลือกทะเบียนรถ',
      ),
    );
  }

  // ====== พรีวิวแบบ "ตาราง" (เดสก์ท็อป) ======
  Widget _previewTableView() {
    return Column(
      children: [
        // header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: Colors.grey[100],
          child: const Row(
            children: [
              _TableCell(text: 'ทะเบียนรถ', isHeader: true),
              _TableCell(text: 'วันที่', isHeader: true),
              _TableCell(text: 'เที่ยว', isHeader: true),
              _TableCell(text: 'ประเภทดิน', isHeader: true),
              _TableCell(text: 'ขนาด (ม.)', isHeader: true),
              _TableCell(text: 'ปริมาตร', isHeader: true),
              _TableCell(text: 'ราคาดิน', isHeader: true),
              _TableCell(text: 'ค่าน้ำมัน', isHeader: true),
              _TableCell(text: 'สุทธิ', isHeader: true),
              _TableCell(text: 'จัดการ', isHeader: true, alignEnd: true),
            ],
          ),
        ),
        // rows
        ..._previewItems.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.withOpacity(.15))),
              color: index % 2 == 0 ? Colors.grey[50] : Colors.white,
            ),
            child: Row(
              children: [
                _TableCell(text: item.plate),
                _TableCell(text: _fmtDate.format(item.startDate)),
                _TableCell(text: '${item.tripCount}'),
                _TableCell(text: item.soilType),
                _TableCell(text: '${_fmtNum.format(item.width)}×${_fmtNum.format(item.length)}×${_fmtNum.format(item.height)}'),
                _TableCell(text: '${_fmtNum.format(item.volume)} ลบ.ม.'),
                _TableCell(text: _fmtMoney.format(item.soilPrice)),
                _TableCell(text: _fmtMoney.format(item.fuelCost), color: Colors.orange),
                _TableCell(text: _fmtMoney.format(item.netPrice), color: Colors.green, isBold: true),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        tooltip: 'ลบ',
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () => _removeFromPreview(index),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // ====== พรีวิวแบบ "การ์ด" (มือถือ) — กันล้นแนวนอน ======
  Widget _previewCardsMobile() {
    return Column(
      children: _previewItems.asMap().entries.map((e) {
        final idx = e.key;
        final it = e.value;
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(it.plate, style: const TextStyle(fontWeight: FontWeight.w700))),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => _removeFromPreview(idx),
                      tooltip: 'ลบ',
                    )
                  ],
                ),
                const SizedBox(height: 4),
                Text('${_fmtDate.format(it.startDate)} • ${it.tripCount} เที่ยว • ${it.soilType}'),
                Text('ขนาด: ${_fmtNum.format(it.width)} × ${_fmtNum.format(it.length)} × ${_fmtNum.format(it.height)} ม.'),
                Text('ปริมาตร: ${_fmtNum.format(it.volume)} ลบ.ม.'),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(child: Text('ราคาดิน: ${_fmtMoney.format(it.soilPrice)}')),
                    Expanded(child: Text('ค่าน้ำมัน: ${_fmtMoney.format(it.fuelCost)}')),
                  ],
                ),
                const SizedBox(height: 2),
                Text('สุทธิ: ${_fmtMoney.format(it.netPrice)}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildProjectSummaries() {
    final filteredProjects = _projectSummaries.where((project) {
      final query = _searchCtrl.text.trim();
      if (query.isEmpty) return true;
      return project.projectName.toLowerCase().contains(query.toLowerCase());
    }).toList();

    return Column(
      children: filteredProjects.map((project) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          project.projectName,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'รถ ${project.vehicleCount} คัน • ${project.totalTrips} เที่ยว • ${_fmtNum.format(project.totalVolume)} ลบ.ม.',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.visibility),
                        onPressed: () => _showProjectDetails(project),
                        tooltip: 'ดูรายละเอียด',
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () => _deleteProject(project.projectName),
                        tooltip: 'ลบโครงการทั้งหมด',
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _projectStat('ปริมาตรรวม', '${_fmtNum.format(project.totalVolume)} ลบ.ม.')),
                  Expanded(child: _projectStat('ราคาดินรวม', _fmtMoney.format(project.totalSoilPrice), Colors.blue)),
                  Expanded(child: _projectStat('ค่าน้ำมันรวม', _fmtMoney.format(project.totalFuelCost), Colors.orange)),
                  Expanded(child: _projectStat('เงินสุทธิ', _fmtMoney.format(project.netPrice), Colors.green, true)),
                ],
              ),
            ],
          ),
        ),
      )).toList(),
    );
  }

  void _showProjectDetails(ProjectSummary project) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.directions_car),
            const SizedBox(width: 8),
            Text('รายละเอียดโครงการ ${project.projectName}'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              Text('รถทั้งหมด ${project.vehicleCount} คัน', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...project.items.map((item) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(item.plate),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${item.soilType} • ${item.tripCount} เที่ยว'),
                      Text('${_fmtNum.format(item.volume)} ลบ.ม. × ${_fmtNum.format(item.unitPrice)} ฿ = ${_fmtMoney.format(item.soilPrice)}'),
                      Text('ค่าน้ำมัน: ${_fmtMoney.format(item.fuelCost)}'),
                      Text('สุทธิ: ${_fmtMoney.format(item.netPrice)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      Navigator.pop(context);
                      _deleteSavedItem(item);
                    },
                  ),
                ),
              )),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ปิด'),
          ),
        ],
      ),
    );
  }

  Widget _projectStat(String title, String value, [Color? color, bool isTotal = false]) {
    return Column(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: isTotal ? 16 : 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
            color: color ?? Colors.black,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _summaryItem(String title, String value, Color color, [bool isTotal = false]) {
    return Column(
      children: [
        Text(title, style: TextStyle(
          fontSize: isTotal ? 16 : 14,
          fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
          color: Colors.black54,
        )),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(
          fontSize: isTotal ? 20 : 16,
          fontWeight: FontWeight.bold,
          color: color,
        )),
      ],
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

class _TableCell extends StatelessWidget {
  final String text;
  final Color? color;
  final bool isHeader;
  final bool isBold;
  final bool alignEnd;

  const _TableCell({
    super.key,
    required this.text,
    this.color,
    this.isHeader = false,
    this.isBold = false,
    this.alignEnd = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Align(
        alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
        child: Text(
          text,
          style: TextStyle(
            color: isHeader ? Colors.black87 : (color ?? Colors.black87),
            fontWeight: isHeader || isBold ? FontWeight.bold : FontWeight.normal,
            fontSize: isHeader ? 12 : 11,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
