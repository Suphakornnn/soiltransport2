import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

const _bg = Color(0xFFF7FAFF);
const _cardBorder = Color(0xFFE6ECFF);
const _text1 = Color(0xFF0F172A);
const _text2 = Color(0xFF64748B);
const _blue = Color(0xFF2563EB);
const _blueSoft = Color(0xFFEFF4FF);

class ManageTrucks extends StatefulWidget {
  const ManageTrucks({super.key});

  @override
  State<ManageTrucks> createState() => _ManageTrucksState();
}

class _ManageTrucksState extends State<ManageTrucks> {
  String _search = '';
  String? _filterStatus; // null = ทุกสถานะ

  // Firestore status mapping
  String _statusText(String? status) {
    switch (status) {
      case 'ready':
      case 'พร้อมใช้งาน':
        return 'พร้อมใช้งาน';
      case 'repair':
      case 'ซ่อมบำรุง':
        return 'ซ่อมบำรุง';
      case 'maintenance':
      case 'กำลังซ่อม':
        return 'กำลังซ่อม';
      default:
        return 'ไม่ระบุ';
    }
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'ready':
      case 'พร้อมใช้งาน':
        return const Color(0xFF16A34A);
      case 'repair':
      case 'ซ่อมบำรุง':
        return const Color(0xFF2563EB);
      case 'maintenance':
      case 'กำลังซ่อม':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFFB91C1C);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text('จัดการรถบรรทุก'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: .5,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('vehicles').snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snap.hasError) {
            return Center(child: Text('เกิดข้อผิดพลาด: ${snap.error}'));
          }

          final docs = snap.data?.docs ?? [];
          
          // นับจำนวนรถตามสถานะ
          final totalTrucks = docs.length;
          final readyTrucks = docs.where((doc) {
            final status = doc['status'] as String?;
            return status == 'ready' || status == 'พร้อมใช้งาน';
          }).length;
          final repairTrucks = docs.where((doc) {
            final status = doc['status'] as String?;
            return status == 'repair' || status == 'ซ่อมบำรุง';
          }).length;
          final maintenanceTrucks = docs.where((doc) {
            final status = doc['status'] as String?;
            return status == 'maintenance' || status == 'กำลังซ่อม';
          }).length;

          // กรองข้อมูลตาม search และ filter
          final filteredDocs = docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final plate = (data['plate'] ?? data['licensePlate'] ?? data['vehiclePlate'] ?? '').toString();
            final driver = (data['driver'] ?? data['driverName'] ?? '').toString();
            final status = data['status'] as String?;
            
            final searchMatch = _search.isEmpty ||
                plate.toLowerCase().contains(_search.toLowerCase()) ||
                driver.toLowerCase().contains(_search.toLowerCase());
            
            final statusMatch = _filterStatus == null || status == _filterStatus;
            
            return searchMatch && statusMatch;
          }).toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              children: [
                // Summary Cards
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _summaryCard('รถทั้งหมด', totalTrucks, _blue),
                    _summaryCard('พร้อมใช้งาน', readyTrucks, const Color(0xFF16A34A)),
                    _summaryCard('ซ่อมบำรุง', repairTrucks, const Color(0xFF2563EB)),
                    _summaryCard('กำลังซ่อม', maintenanceTrucks, const Color(0xFFF59E0B)),
                  ],
                ),

                const SizedBox(height: 16),

                // Search and Filter
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        onChanged: (v) => setState(() => _search = v),
                        decoration: InputDecoration(
                          hintText: 'ค้นหาตามทะเบียนรถ หรือคนขับ...',
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
                      width: 160,
                      child: DropdownButtonFormField<String?>(
                        value: _filterStatus,
                        isDense: true,
                        items: const [
                          DropdownMenuItem(value: null, child: Text('ทุกสถานะ')),
                          DropdownMenuItem(value: 'ready', child: Text('พร้อมใช้งาน')),
                          DropdownMenuItem(value: 'repair', child: Text('ซ่อมบำรุง')),
                          DropdownMenuItem(value: 'maintenance', child: Text('กำลังซ่อม')),
                        ],
                        onChanged: (v) => setState(() => _filterStatus = v),
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
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Truck List
                if (filteredDocs.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: _cardBorder),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.local_shipping_outlined, size: 48, color: _text2.withOpacity(0.5)),
                        const SizedBox(height: 12),
                        Text(
                          'ไม่พบรถบรรทุกที่ตรงกับเงื่อนไข',
                          style: TextStyle(color: _text2, fontSize: 16),
                        ),
                      ],
                    ),
                  )
                else
                  ...filteredDocs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return _truckCard(data, doc.id);
                  }).toList(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _summaryCard(String title, int count, Color color) {
    return SizedBox(
      width: 170,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: _cardBorder),
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2))
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$count',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        color: _text1,
                      ),
                    ),
                    Text(
                      title,
                      style: const TextStyle(color: _text2),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _truckCard(Map<String, dynamic> truck, String docId) {
    final plate = (truck['plate'] ?? truck['licensePlate'] ?? truck['vehiclePlate'] ?? '').toString();
    final driver = (truck['driver'] ?? truck['driverName'] ?? '').toString();
    final status = truck['status'] as String?;
    final model = truck['model']?.toString() ?? 'ไม่ระบุรุ่น';
    final location = truck['location']?.toString() ?? 'ไม่ระบุตำแหน่ง';
    final fuel = truck['fuel']?.toString() ?? '0';
    final odo = truck['odo']?.toString() ?? '0';
    final nextMaintenance = truck['nextMaintenance']?.toString() ?? 'ไม่ระบุ';

    final statusText = _statusText(status);
    final statusColor = _statusColor(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _cardBorder),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2))
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => TruckDetailScreen(truck: truck),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: _blueSoft,
                        border: Border.all(color: _cardBorder),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.local_shipping_rounded, color: _blue),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Wrap(
                        alignment: WrapAlignment.start,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _plateChip(plate),
                          _statusChip(statusText, statusColor),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Details
                _infoRow(icon: Icons.badge_outlined, label: 'รุ่น', value: model),
                _infoRow(icon: Icons.person_pin_circle, label: 'คนขับ', value: driver),
                _infoRow(icon: Icons.place_outlined, label: 'ตำแหน่ง', value: location),
                
                const SizedBox(height: 8),
                
                // Additional Info
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    _miniInfo('น้ำมัน', '$fuel%'),
                    _miniInfo('ไมล์สะสม', '$odo กม.'),
                    _miniInfo('ซ่อมถัดไป', nextMaintenance),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoRow({required IconData icon, required String label, required String value}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: _text2),
          const SizedBox(width: 8),
          Text('$label: ', style: TextStyle(color: _text2, fontWeight: FontWeight.w500)),
          Expanded(
            child: Text(value, style: const TextStyle(color: _text1, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _miniInfo(String title, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _blueSoft,
        border: Border.all(color: _cardBorder),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: TextStyle(color: _text2, fontSize: 12)),
          const SizedBox(width: 4),
          Text(value, style: const TextStyle(color: _blue, fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _plateChip(String plate) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: _blueSoft,
          border: Border.all(color: _cardBorder),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.confirmation_number_outlined, size: 16, color: _blue),
            const SizedBox(width: 6),
            Text(plate, style: const TextStyle(color: _blue, fontWeight: FontWeight.w800)),
          ],
        ),
      );

  Widget _statusChip(String status, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: c.withOpacity(.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: c.withOpacity(.25)),
        ),
        child: Text(status, style: TextStyle(color: c, fontWeight: FontWeight.w800)),
      );
}

class TruckDetailScreen extends StatelessWidget {
  final Map<String, dynamic> truck;
  const TruckDetailScreen({super.key, required this.truck});

  Color _statusColor(String? status) {
    switch (status) {
      case 'ready':
      case 'พร้อมใช้งาน':
        return const Color(0xFF16A34A);
      case 'repair':
      case 'ซ่อมบำรุง':
        return const Color(0xFF2563EB);
      case 'maintenance':
      case 'กำลังซ่อม':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFFB91C1C);
    }
  }

  String _statusText(String? status) {
    switch (status) {
      case 'ready':
      case 'พร้อมใช้งาน':
        return 'พร้อมใช้งาน';
      case 'repair':
      case 'ซ่อมบำรุง':
        return 'ซ่อมบำรุง';
      case 'maintenance':
      case 'กำลังซ่อม':
        return 'กำลังซ่อม';
      default:
        return 'ไม่ระบุ';
    }
  }

  Widget _tile({required IconData icon, required String title, String? trailing}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFCFF),
        border: Border.all(color: _cardBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: _text2),
          const SizedBox(width: 10),
          Expanded(child: Text(title, style: const TextStyle(color: _text1))),
          if (trailing != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _blueSoft,
                border: Border.all(color: _cardBorder),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(trailing, style: const TextStyle(color: _blue, fontWeight: FontWeight.w700)),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final plate = (truck['plate'] ?? truck['licensePlate'] ?? truck['vehiclePlate'] ?? '').toString();
    final driver = (truck['driver'] ?? truck['driverName'] ?? '').toString();
    final status = truck['status'] as String?;
    final model = truck['model']?.toString() ?? 'ไม่ระบุรุ่น';
    final location = truck['location']?.toString() ?? 'ไม่ระบุตำแหน่ง';
    final fuel = truck['fuel']?.toString() ?? '0';
    final odo = truck['odo']?.toString() ?? '0';
    final nextMaintenance = truck['nextMaintenance']?.toString() ?? 'ไม่ระบุ';

    final statusText = _statusText(status);
    final c = _statusColor(status);

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text('รายละเอียดรถบรรทุก'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: .5,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Column(
              children: [
                // Header card
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: _cardBorder),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(color: Color(0x0C000000), blurRadius: 10, offset: Offset(0, 2))
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          color: _blueSoft,
                          border: Border.all(color: _cardBorder),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.local_shipping_rounded, color: _blue),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Wrap(
                          alignment: WrapAlignment.start,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8, runSpacing: 6,
                          children: [
                            _plateChip(plate),
                            _statusChip(statusText, c),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Info card
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: _cardBorder),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      _tile(icon: Icons.badge_outlined, title: model),
                      _tile(icon: Icons.person_pin_circle, title: driver),
                      _tile(icon: Icons.place_outlined, title: location),
                      _tile(icon: Icons.local_gas_station, title: 'น้ำมันคงเหลือ', trailing: '$fuel%'),
                      _tile(icon: Icons.speed, title: 'ไมล์สะสม', trailing: '$odo กม.'),
                      _tile(icon: Icons.event_note, title: 'งานซ่อมถัดไป: $nextMaintenance'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _plateChip(String plate) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: _blueSoft,
          border: Border.all(color: _cardBorder),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.confirmation_number_outlined, size: 16, color: _blue),
          const SizedBox(width: 6),
          Text(plate, style: const TextStyle(color: _blue, fontWeight: FontWeight.w800)),
        ]),
      );

  Widget _statusChip(String status, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: c.withOpacity(.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: c.withOpacity(.25)),
        ),
        child: Text(status, style: TextStyle(color: c, fontWeight: FontWeight.w800)),
      );
}