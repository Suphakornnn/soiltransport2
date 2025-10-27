import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'add_truck_screen.dart';

/// ===== Blue–White Palette =====
const _bg = Color(0xFFF5F8FF);
const _cardBorder = Color(0xFFE6ECFF);
const _text1 = Color(0xFF0F172A);
const _text2 = Color(0xFF64748B);
const _blue = Color(0xFF2563EB);
const _blueSoft = Color(0xFFEFF4FF);
const _red = Color(0xFFDC2626);
const _green = Color(0xFF16A34A);
const _yellow = Color(0xFFF59E0B);

const _pad = 16.0;
const _gap = 16.0;

class ManageTrucks extends StatefulWidget {
  const ManageTrucks({super.key});
  @override
  State<ManageTrucks> createState() => _ManageTrucksState();
}

class _ManageTrucksState extends State<ManageTrucks> {
  // states
  String _query = '';
  String _statusFilter = 'ทุกสถานะ';
  String _sortField = 'plate';
  bool _sortAsc = true;
  bool _isLoading = false;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // --- แปลง status code <-> ภาษาไทย ---
  String _statusToThai(String code) {
    switch (code) {
      case 'ready':
        return 'พร้อมใช้งาน';
      case 'repairing':
        return 'กำลังซ่อม';
      case 'maintenance':
        return 'ซ่อมบำรุง';
      case 'offline':
        return 'ออฟไลน์';
      default:
        return 'ไม่ทราบสถานะ';
    }
  }

  String? _thaiToStatusCode(String thai) {
    switch (thai) {
      case 'พร้อมใช้งาน':
        return 'ready';
      case 'กำลังซ่อม':
        return 'repairing';
      case 'ซ่อมบำรุง':
        return 'maintenance';
      case 'ออฟไลน์':
        return 'offline';
      case 'ทุกสถานะ':
        return null;
      default:
        return null;
    }
  }

  Color _statusColor(String code) {
    switch (code) {
      case 'ready':
        return _green;
      case 'repairing':
        return _yellow;
      case 'maintenance':
        return _blue;
      case 'offline':
        return _red;
      default:
        return Colors.grey;
    }
  }

  IconData _statusIcon(String code) {
    switch (code) {
      case 'ready':
        return Icons.check_circle_outline;
      case 'repairing':
        return Icons.build_circle_outlined;
      case 'maintenance':
        return Icons.engineering_outlined;
      case 'offline':
        return Icons.offline_bolt_outlined;
      default:
        return Icons.help_outline;
    }
  }

  // --- UI Helpers ---
  Widget _summaryCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Card(
      color: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withOpacity(.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _cardBorder),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: _text2)),
                  const SizedBox(height: 2),
                  Text(value,
                      style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w800,
                          fontSize: 16)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  DataColumn _col(String label, String sortKey,
      {TextAlign align = TextAlign.left}) {
    return DataColumn(
      label: Align(
        alignment: align == TextAlign.right
            ? Alignment.centerRight
            : (align == TextAlign.center
                ? Alignment.center
                : Alignment.centerLeft),
        child: Text(label,
            style:
                const TextStyle(fontWeight: FontWeight.w700, color: _text1)),
      ),
      onSort: (i, asc) => setState(() {
        _sortField = sortKey;
        _sortAsc = asc;
      }),
      numeric: align == TextAlign.right,
    );
  }

  // --- ประมวลผลข้อมูล ---
  List<Map<String, dynamic>> _processData(List<Map<String, dynamic>> data) {
    final q = _query.trim().toLowerCase();
    final targetCode = _thaiToStatusCode(_statusFilter);

    final filtered = data.where((e) {
      final matchesStatus = targetCode == null || e['status'] == targetCode;
      final matchesSearch = q.isEmpty ||
          (e['plate'] as String).toLowerCase().contains(q) ||
          (e['model'] as String).toLowerCase().contains(q) ||
          (e['driver'] as String).toLowerCase().contains(q);
      return matchesStatus && matchesSearch;
    }).toList();

    // เรียงลำดับ
    filtered.sort((a, b) {
      int cmp;
      switch (_sortField) {
        case 'plate':
          cmp = (a['plate'] as String).compareTo(b['plate'] as String);
          break;
        case 'driver':
          cmp = (a['driver'] as String).compareTo(b['driver'] as String);
          break;
        case 'status':
          cmp = (a['status'] as String).compareTo(b['status'] as String);
          break;
        case 'mileage':
          cmp = (a['mileage'] as int).compareTo(b['mileage'] as int);
          break;
        default:
          cmp = 0;
      }
      return _sortAsc ? cmp : -cmp;
    });

    return filtered;
  }

  Map<String, int> _calculateSummary(List<Map<String, dynamic>> data) {
    int all = data.length;
    int ready = data.where((e) => e['status'] == 'ready').length;
    int maint = data.where((e) => e['status'] == 'maintenance').length;
    int repair = data.where((e) => e['status'] == 'repairing').length;
    int offline = data.where((e) => e['status'] == 'offline').length;
    return {
      'all': all,
      'ready': ready,
      'maint': maint,
      'repair': repair,
      'offline': offline,
    };
  }

  // --- UI Components ---
  Widget _filtersWide() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: 'ค้นหาตามทะเบียนรถ, คนขับ, หรือรุ่น...',
              prefixIcon: const Icon(Icons.search, color: _blue),
              isDense: true,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _cardBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _blue, width: 1.4),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 220,
          child: DropdownButtonFormField<String>(
            value: _statusFilter,
            isDense: true,
            decoration: InputDecoration(
              labelText: 'สถานะ',
              isDense: true,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _cardBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _blue, width: 1.4),
              ),
            ),
            items: const [
              'ทุกสถานะ',
              'พร้อมใช้งาน',
              'กำลังซ่อม',
              'ซ่อมบำรุง',
              'ออฟไลน์'
            ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: (v) => setState(() => _statusFilter = v ?? 'ทุกสถานะ'),
          ),
        ),
      ],
    );
  }

  Widget _filtersNarrow() {
    return Column(
      children: [
        TextField(
          onChanged: (v) => setState(() => _query = v),
          decoration: InputDecoration(
            hintText: 'ค้นหาตามทะเบียนรถ, คนขับ, หรือรุ่น...',
            prefixIcon: const Icon(Icons.search, color: _blue),
            isDense: true,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _cardBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _blue, width: 1.4),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: SizedBox(
            width: 220,
            child: DropdownButtonFormField<String>(
              value: _statusFilter,
              isDense: true,
              decoration: InputDecoration(
                labelText: 'สถานะ',
                isDense: true,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _cardBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _blue, width: 1.4),
                ),
              ),
              items: const [
                'ทุกสถานะ',
                'พร้อมใช้งาน',
                'กำลังซ่อม',
                'ซ่อมบำรุง',
                'ออฟไลน์'
              ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => setState(() => _statusFilter = v ?? 'ทุกสถานะ'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _tableWide(List<Map<String, dynamic>> data) {
    return Card(
      color: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowHeight: 46,
            dataRowMinHeight: 46,
            dataRowMaxHeight: 56,
            columnSpacing: 28,
            dividerThickness: .6,
            sortAscending: _sortAsc,
            sortColumnIndex: _sortField == 'plate'
                ? 0
                : _sortField == 'model'
                    ? 1
                    : _sortField == 'driver'
                        ? 2
                        : _sortField == 'mileage'
                            ? 3
                            : _sortField == 'status'
                                ? 4
                                : null,
            columns: [
              _col('ทะเบียนรถ', 'plate'),
              _col('รุ่น/ยี่ห้อ', 'model'),
              _col('คนขับ', 'driver'),
              _col('ไมล์ (กม.)', 'mileage', align: TextAlign.right),
              _col('สถานะ', 'status'),
              const DataColumn(label: Text('จัดการ')),
            ],
            rows: data.map<DataRow>((e) {
              final statusColor = _statusColor(e['status'] as String);
              return DataRow(cells: [
                DataCell(Text(e['plate'].toString(),
                    style: const TextStyle(fontWeight: FontWeight.w700))),
                DataCell(Text(e['model']?.toString() ?? 'ไม่ระบุ')),
                DataCell(Text(e['driver']?.toString() ?? 'ไม่มีคนขับ')),
                DataCell(Align(
                  alignment: Alignment.centerRight,
                  child: Text('${e['mileage'] ?? 0}'),
                )),
                DataCell(_statusChip(_statusToThai(e['status']), statusColor)),
                DataCell(Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _iconBtn(Icons.edit_outlined, 'แก้ไข', () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AddTruckScreen(
                            truckData: e,
                            isEditing: true,
                          ),
                        ),
                      );
                      setState(() {}); // รีเฟรชข้อมูล
                    }),
                    const SizedBox(width: 6),
                    _iconBtn(Icons.delete_outline, 'ลบ', () => _confirmDelete(e),
                        color: _red),
                  ],
                )),
              ]);
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _listNarrow(List<Map<String, dynamic>> data) {
    return Column(
      children: data.map<Widget>((e) {
        final statusThai = _statusToThai(e['status'] as String);
        final statusColor = _statusColor(e['status'] as String);
        final statusIcon = _statusIcon(e['status'] as String);
        
        return Card(
          color: Colors.white,
          surfaceTintColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _plateChip(e['plate'].toString()),
                    const Spacer(),
                    _statusChip(statusThai, statusColor),
                  ],
                ),
                const SizedBox(height: 10),
                _iconRow(Icons.local_shipping_outlined, e['model']?.toString() ?? 'ไม่ระบุรุ่น'),
                _iconRow(Icons.person_outline, 'คนขับ: ${e['driver'] ?? 'ไม่มีคนขับ'}'),
                _iconRow(Icons.speed_outlined, 'ไมล์สะสม: ${e['mileage'] ?? 0} กม.'),
                _iconRow(statusIcon, 'สถานะ: $statusThai'),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AddTruckScreen(
                              truckData: e,
                              isEditing: true,
                            ),
                          ),
                        );
                        setState(() {}); // รีเฟรชข้อมูล
                      },
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('แก้ไข'),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'ลบ',
                      onPressed: () => _confirmDelete(e),
                      icon: const Icon(Icons.delete_outline, color: Color(0xFFB3261E)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // --- Small UI Helpers ---
  Widget _iconRow(IconData i, String t) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Icon(i, size: 18, color: _text2),
            const SizedBox(width: 8),
            Expanded(child: Text(t, style: const TextStyle(color: _text1))),
          ],
        ),
      );

  Widget _statusChip(String t, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: c.withOpacity(.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: c.withOpacity(.25)),
        ),
        child: Text(t, style: TextStyle(color: c, fontWeight: FontWeight.w700)),
      );

  Widget _plateChip(String plate) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: _blueSoft,
          border: Border.all(color: _cardBorder),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.local_shipping_outlined, size: 16, color: _blue),
          const SizedBox(width: 6),
          Text(plate, style: const TextStyle(color: _blue, fontWeight: FontWeight.w800)),
        ]),
      );

  Widget _iconBtn(IconData i, String tip, VoidCallback onTap, {Color? color}) {
    final c = color ?? _text1;
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

  Future<void> _confirmDelete(Map<String, dynamic> e) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('ลบรถบรรทุก'),
        content: Text('ต้องการลบทะเบียน "${e['plate']}" ออกจากรายการหรือไม่? การกระทำนี้ไม่สามารถย้อนกลับได้'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ลบ'),
          ),
        ],
      ),
    );

    if (result == true) {
      setState(() => _isLoading = true);
      try {
        if (e.containsKey('id')) {
          await _firestore.collection('vehicles').doc(e['id'] as String).delete();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('ลบรถทะเบียน ${e['plate']} เรียบร้อยแล้ว'),
              backgroundColor: _green,
            ),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาดในการลบ: $e'),
            backgroundColor: _red,
          ),
        );
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  // --- Main Build ---
  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final isWide = w >= 1000;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text('จัดการรถบรรทุก'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: .5,
        actions: [
          FilledButton.icon(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddTruckScreen()),
              );
              setState(() {}); // รีเฟรชข้อมูล
            },
            icon: const Icon(Icons.add),
            label: const Text('เพิ่มรถใหม่'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(_pad, _pad, _pad, 24),
              child: Column(
                children: [
                  // ====== SUMMARY ======
                  StreamBuilder<QuerySnapshot>(
                    stream: _firestore.collection('vehicles').snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return Card(
                          color: Colors.white,
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              children: [
                                Icon(Icons.local_shipping_outlined, size: 64, color: _text2),
                                const SizedBox(height: 16),
                                Text(
                                  'ยังไม่มีข้อมูลรถบรรทุก',
                                  style: TextStyle(color: _text2, fontSize: 16),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'กดปุ่ม "เพิ่มรถใหม่" เพื่อเริ่มต้น',
                                  style: TextStyle(color: _text2),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      final vehicles = snapshot.data!.docs.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        return <String, dynamic>{
                          'id': doc.id,
                          'plate': data['plate'] ?? 'ไม่มีทะเบียน',
                          'driver': data['driver'] ?? 'ไม่มีคนขับ',
                          'status': data['status'] ?? 'unknown',
                          'model': data['model'] ?? 'ไม่ระบุรุ่น',
                          'mileage': data['mileage'] is num ? (data['mileage'] as num).toInt() : 0,
                          'location': data['location'] ?? '',
                          'fuel': data['fuel'] ?? 0,
                        };
                      }).toList();

                      final summary = _calculateSummary(vehicles);

                      return LayoutBuilder(
                        builder: (_, c) {
                          final width = c.maxWidth;
                          final cross = width >= 1024 ? 5 : (width >= 800 ? 3 : 2);
                          return GridView.count(
                            crossAxisCount: cross,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: width >= 1024 ? 3.0 : 2.5,
                            children: [
                              _summaryCard(
                                icon: Icons.local_shipping_rounded,
                                title: 'รถทั้งหมด',
                                value: '${summary['all']}',
                                color: const Color(0xFF1E40AF),
                              ),
                              _summaryCard(
                                icon: Icons.verified_rounded,
                                title: 'พร้อมใช้งาน',
                                value: '${summary['ready']}',
                                color: _green,
                              ),
                              _summaryCard(
                                icon: Icons.build_circle_outlined,
                                title: 'ซ่อมบำรุง',
                                value: '${summary['maint']}',
                                color: _blue,
                              ),
                              _summaryCard(
                                icon: Icons.handyman_outlined,
                                title: 'กำลังซ่อม',
                                value: '${summary['repair']}',
                                color: _yellow,
                              ),
                              if (width >= 1024)
                                _summaryCard(
                                  icon: Icons.offline_bolt_outlined,
                                  title: 'ออฟไลน์',
                                  value: '${summary['offline']}',
                                  color: _red,
                                ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: _gap),

                  // ====== FILTERS ======
                  isWide ? _filtersWide() : _filtersNarrow(),
                  const SizedBox(height: _gap),

                  // ====== CONTENT ======
                  StreamBuilder<QuerySnapshot>(
                    stream: _firestore.collection('vehicles').snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const SizedBox(); // Already handled in summary
                      }

                      final vehicles = snapshot.data!.docs.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        return <String, dynamic>{
                          'id': doc.id,
                          'plate': data['plate'] ?? 'ไม่มีทะเบียน',
                          'driver': data['driver'] ?? 'ไม่มีคนขับ',
                          'status': data['status'] ?? 'unknown',
                          'model': data['model'] ?? 'ไม่ระบุรุ่น',
                          'mileage': data['mileage'] is num ? (data['mileage'] as num).toInt() : 0,
                          'location': data['location'] ?? '',
                          'fuel': data['fuel'] ?? 0,
                        };
                      }).toList();

                      final filtered = _processData(vehicles);

                      if (filtered.isEmpty) {
                        return Card(
                          color: Colors.white,
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              children: [
                                Icon(Icons.search_off, size: 64, color: _text2),
                                const SizedBox(height: 16),
                                Text(
                                  'ไม่พบข้อมูลที่ค้นหา',
                                  style: TextStyle(color: _text2, fontSize: 16),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'ลองเปลี่ยนคำค้นหาหรือเงื่อนไขการกรอง',
                                  style: TextStyle(color: _text2),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      return isWide ? _tableWide(filtered) : _listNarrow(filtered);
                    },
                  ),
                ],
              ),
            ),
    );
  }
}