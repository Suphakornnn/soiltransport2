// lib/screens/admin/manage_users.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:soil_transport_app/models/driver_status.dart';
import 'user_detail_screen.dart';

/// ====== Blue–White palette ======
const _bgScaffold = Color(0xFFF5F8FF);
const _cardBorder = Color(0xFFE6ECFF);
const _textPrimary = Color(0xFF0F172A);
const _textMuted = Color(0xFF64748B);
const _blue = Color(0xFF2563EB);
const _blueSoft = Color(0xFFEFF4FF);

class ManageUsers extends StatefulWidget {
  const ManageUsers({super.key});
  @override
  State<ManageUsers> createState() => _ManageUsersState();
}

class _ManageUsersState extends State<ManageUsers> {
  final List<Map<String, dynamic>> _users = [];
  String _q = '';
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchDrivers();
  }

  Future<void> _fetchDrivers() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      final qs = await FirebaseFirestore.instance.collection('vehicles').get();
      final List<Map<String, dynamic>> drivers = [];

      for (final doc in qs.docs) {
        final data = doc.data();
        if (!data.containsKey('driver')) continue;

        final plate = (data['plate'] ?? '').toString().trim();
        final driverField = data['driver'];

        if (driverField is Map<String, dynamic>) {
          final name = (driverField['name'] ?? '').toString().trim();
          if (name.isNotEmpty) {
            drivers.add({
              'name': name,
              'plate': plate.isEmpty ? 'ไม่มีทะเบียน' : plate,
              'status': getStatusTextFromEng(data['status']),
              'vehicleId': doc.id,
              'driverData': driverField,
            });
          }
        } else if (driverField is String) {
          final name = driverField.trim();
          if (name.isNotEmpty) {
            drivers.add({
              'name': name,
              'plate': plate.isEmpty ? 'ไม่มีทะเบียน' : plate,
              'status': getStatusTextFromEng(data['status']),
              'vehicleId': doc.id,
              'driverData': {'name': name},
            });
          }
        }
      }

      setState(() {
        _users
          ..clear()
          ..addAll(drivers);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'ไม่สามารถโหลดข้อมูลได้: $e';
      });
    }
  }

  List<Map<String, dynamic>> get _filtered {
    final q = _q.trim().toLowerCase();
    if (q.isEmpty) return _users;
    return _users.where((u) {
      return u['name'].toString().toLowerCase().contains(q) || u['plate'].toString().toLowerCase().contains(q);
    }).toList();
  }

  Color _statusColor(String status) {
    switch (status) {
      case "พร้อมใช้งาน":
        return const Color(0xFF16A34A);
      case "กำลังซ่อม":
        return const Color(0xFFF59E0B);
      case "ไม่พร้อมใช้งาน":
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFF64748B);
    }
  }

  Widget _statusChip(String status) {
    final c = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.withOpacity(.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.withOpacity(.25)),
      ),
      child: Text(status, style: TextStyle(color: c, fontWeight: FontWeight.w800, letterSpacing: .2, height: 1.1)),
    );
  }

  // ---------- ADD VEHICLE FORM ----------
  void _openAddVehicleForm() {
    showDialog(
      context: context,
      builder:
          (context) => AddVehicleFormDialog(
            onSave: (data) async {
              try {
                await FirebaseFirestore.instance.collection('vehicles').add({
                  'plate': data['plate'],
                  'driver': data['driverName'],
                  'status': driverStatusToEng(data['status']),
                  'phone': data['phone'],
                  'address': data['address'],
                  'createdAt': FieldValue.serverTimestamp(),
                });
                if (mounted) {
                  Navigator.pop(context);
                  _showSnack('เพิ่มข้อมูลรถเรียบร้อย');
                  await _fetchDrivers();
                }
              } catch (e) {
                _showSnack('เกิดข้อผิดพลาด: $e');
              }
            },
          ),
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final isWide = w >= 900;

    return Scaffold(
      backgroundColor: _bgScaffold,
      appBar: AppBar(
        title: const Text("จัดการผู้ใช้"),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0.5,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchDrivers, tooltip: 'รีเฟรชข้อมูล'),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: _openAddVehicleForm,
            icon: const Icon(Icons.add),
            label: const Text('เพิ่มรถ'),
            style: FilledButton.styleFrom(backgroundColor: _blue, foregroundColor: Colors.white),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            _headerBar(),
            const SizedBox(height: 12),
            _searchBox(),
            const SizedBox(height: 14),

            if (_errorMessage.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Color(0xFFDC2626)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_errorMessage, style: const TextStyle(color: Color(0xFFDC2626)))),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => setState(() => _errorMessage = ''),
                    ),
                  ],
                ),
              ),

            Expanded(
              child:
                  _isLoading
                      ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(color: _blue),
                            SizedBox(height: 16),
                            Text('กำลังโหลดข้อมูล...', style: TextStyle(color: _textMuted, fontSize: 16)),
                          ],
                        ),
                      )
                      : _filtered.isEmpty
                      ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.people_outline, size: 64, color: _textMuted),
                            const SizedBox(height: 16),
                            Text(
                              _q.isEmpty ? 'ไม่พบข้อมูลคนขับ' : 'ไม่พบผลลัพธ์การค้นหา',
                              style: const TextStyle(color: _textMuted, fontSize: 16),
                            ),
                            if (_q.isNotEmpty)
                              TextButton(onPressed: () => setState(() => _q = ''), child: const Text('ล้างการค้นหา')),
                          ],
                        ),
                      )
                      : isWide
                      ? LayoutBuilder(
                        builder: (_, c) {
                          final maxW = c.maxWidth;
                          const tileW = 420.0;
                          final cross = (maxW / tileW).floor().clamp(2, 4);
                          return GridView.builder(
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: cross,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                              mainAxisExtent: 110, // เตี้ยลง
                            ),
                            itemCount: _filtered.length,
                            itemBuilder: (_, i) => _UserCard(user: _filtered[i], statusChip: _statusChip),
                          );
                        },
                      )
                      : ListView.separated(
                        itemCount: _filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => _UserCard(user: _filtered[i], statusChip: _statusChip, compact: true),
                      ),
            ),
          ],
        ),
      ),
    );
  }

  // ----- widgets -----
  Widget _headerBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _cardBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.groups_2, color: _blue),
          const SizedBox(width: 8),
          const Text('ผู้ใช้ทั้งหมด', style: TextStyle(color: _textPrimary, fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(width: 8),
          _countPill(_users.length),
          const Spacer(),
          if (_q.isNotEmpty)
            TextButton.icon(
              onPressed: () => setState(() => _q = ''),
              icon: const Icon(Icons.filter_alt_off, color: _blue),
              label: const Text('ล้างการค้นหา', style: TextStyle(color: _blue, fontWeight: FontWeight.w700)),
            ),
        ],
      ),
    );
  }

  Widget _countPill(int n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _blueSoft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _cardBorder),
      ),
      child: Text('$n รายการ', style: const TextStyle(color: _blue, fontWeight: FontWeight.w800, letterSpacing: .2)),
    );
  }

  Widget _searchBox() {
    return TextField(
      onChanged: (v) => setState(() => _q = v),
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search, color: _blue),
        hintText: 'ค้นหาชื่อหรือทะเบียนรถ...',
        hintStyle: const TextStyle(color: _textMuted),
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
    );
  }
}

class _UserCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final Widget Function(String) statusChip;
  final bool compact;
  const _UserCard({required this.user, required this.statusChip, this.compact = false});

  Widget _buildInitialAvatar(String name) {
    final firstLetter = name.isNotEmpty ? name.characters.first.toUpperCase() : '?';
    final size = compact ? 48.0 : 52.0;
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [_blue, Color(0xFF60A5FA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          firstLetter,
          style: TextStyle(fontSize: compact ? 18 : 20, fontWeight: FontWeight.w900, color: Colors.white),
        ),
      ),
    );
  }

  Widget _plateChip(String plate) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _blueSoft,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _cardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.local_shipping_outlined, size: 16, color: _blue),
          const SizedBox(width: 6),
          Text(plate, style: const TextStyle(color: _blue, fontWeight: FontWeight.w700, letterSpacing: .2)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = user['name'] as String;
    final plate = user['plate'] as String;
    final status = user['status'] as String;

    if (compact) {
      // ===== มือถือ: 2 แถว ชัดเจน =====
      return Container(
        height: 110,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _cardBorder),
          boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 2))],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              _buildInitialAvatar(name),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // แถวบน: ชื่อ + สถานะ (ขวา)
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _textPrimary),
                          ),
                        ),
                        const SizedBox(width: 8),
                        statusChip(status),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // แถวล่าง: ป้ายทะเบียน + ปุ่มเพิ่มเติม
                    Row(
                      children: [
                        _plateChip(plate),
                        const Spacer(),
                        OutlinedButton.icon(
                          onPressed: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => UserDetailScreen(user: user)));
                          },
                          icon: const Icon(Icons.info_outline, size: 18, color: _blue),
                          label: const Text('เพิ่มเติม', style: TextStyle(color: _blue, fontWeight: FontWeight.w700)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: _blue),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // ===== เดสก์ท็อป: ชื่อ/ทะเบียนซ้าย, ปุ่ม + สถานะขวา =====
    return Container(
      height: 110,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cardBorder),
        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            _buildInitialAvatar(name),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _textPrimary),
                  ),
                  const SizedBox(height: 8),
                  _plateChip(plate),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => UserDetailScreen(user: user)));
              },
              icon: const Icon(Icons.info_outline),
              label: const Text('เพิ่มเติม'),
              style: FilledButton.styleFrom(
                backgroundColor: _blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(width: 10),
            statusChip(status),
          ],
        ),
      ),
    );
  }
}

// ---------- ADD VEHICLE FORM DIALOG ----------
class AddVehicleFormDialog extends StatefulWidget {
  final Function(Map<String, dynamic>) onSave;
  const AddVehicleFormDialog({Key? key, required this.onSave}) : super(key: key);

  @override
  State<AddVehicleFormDialog> createState() => _AddVehicleFormDialogState();
}

class _AddVehicleFormDialogState extends State<AddVehicleFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _plateCtrl = TextEditingController();
  final _driverNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  String _status = 'พร้อมใช้งาน';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: const [Icon(Icons.add_circle_outline, color: _blue), SizedBox(width: 8), Text('เพิ่มข้อมูลรถใหม่')],
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _plateCtrl,
                decoration: const InputDecoration(
                  labelText: 'ทะเบียนรถ *',
                  hintText: 'กรอกทะเบียนรถ',
                  prefixIcon: Icon(Icons.confirmation_number),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'กรุณากรอกทะเบียนรถ' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _driverNameCtrl,
                decoration: const InputDecoration(
                  labelText: 'ชื่อคนขับ *',
                  hintText: 'กรอกชื่อ-นามสกุลคนขับ',
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'กรุณากรอกชื่อคนขับ' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'เบอร์โทรศัพท์',
                  hintText: 'กรอกเบอร์โทรศัพท์',
                  prefixIcon: Icon(Icons.phone),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _addressCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'ที่อยู่',
                  hintText: 'กรอกที่อยู่',
                  prefixIcon: Icon(Icons.location_on),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _status,
                items:
                    const [
                      'พร้อมใช้งาน',
                      'กำลังซ่อม',
                      'ไม่พร้อมใช้งาน',
                      'กำลังทำงาน',
                    ].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (v) => setState(() => _status = v!),
                decoration: const InputDecoration(labelText: 'สถานะ *', prefixIcon: Icon(Icons.circle)),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('ยกเลิก')),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              widget.onSave({
                'plate': _plateCtrl.text.trim(),
                'driverName': _driverNameCtrl.text.trim(),
                'phone': _phoneCtrl.text.trim(),
                'address': _addressCtrl.text.trim(),
                'status': _status,
              });
            }
          },
          child: const Text('บันทึก'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _plateCtrl.dispose();
    _driverNameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }
}
