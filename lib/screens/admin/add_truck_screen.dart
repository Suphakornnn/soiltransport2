import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddTruckScreen extends StatefulWidget {
  final Map<String, dynamic>? truckData;
  final bool isEditing;

  const AddTruckScreen({
    super.key,
    this.truckData,
    this.isEditing = false,
  });

  @override
  State<AddTruckScreen> createState() => _AddTruckScreenState();
}

class _AddTruckScreenState extends State<AddTruckScreen> {
  // โทนฟ้าขาว (ประกาศไว้ใน State/คลาสเดียวกับที่ใช้)
  static const Color kBg = Color(0xFFF5F8FF); // พื้นหลังฟ้าอ่อน
  static const Color kBlue = Color(0xFF2F6DF6); // ฟ้าหลัก
  static const Color kBorder = Color(0xFFE3ECFF); // เส้นขอบอ่อน

  final _plate = TextEditingController();
  final _model = TextEditingController();
  final _driver = TextEditingController();
  final _location = TextEditingController();
  final _mileage = TextEditingController();
  String _status = 'พร้อมใช้งาน';

  final _formKey = GlobalKey<FormState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // แปลงสถานะไทยเป็น code
  String _thaiToStatus(String thai) {
    switch (thai) {
      case 'พร้อมใช้งาน':
        return 'ready';
      case 'กำลังซ่อม':
        return 'repairing';
      case 'ซ่อมบำรุง':
        return 'maintenance';
      case 'ออฟไลน์':
        return 'offline';
      default:
        return 'ready';
    }
  }

  // แปลง code เป็นสถานะไทย
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
        return 'พร้อมใช้งาน';
    }
  }

  @override
  void initState() {
    super.initState();
    // หากเป็นโหมดแก้ไข ให้โหลดข้อมูลเดิม
    if (widget.isEditing && widget.truckData != null) {
      _plate.text = widget.truckData!['plate'] ?? '';
      _model.text = widget.truckData!['model'] ?? '';
      _driver.text = widget.truckData!['driver'] ?? '';
      _location.text = widget.truckData!['location'] ?? '';
      _mileage.text = (widget.truckData!['mileage'] ?? 0).toString();
      _status = _statusToThai(widget.truckData!['status'] ?? 'ready');
    }
  }

  InputDecoration _dec(String label) => InputDecoration(
        labelText: label,
        isDense: true,
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kBlue, width: 1.6),
        ),
      );

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final truckData = {
        'plate': _plate.text.trim(),
        'model': _model.text.trim(),
        'driver': _driver.text.trim(),
        'location': _location.text.trim(),
        'mileage': int.tryParse(_mileage.text) ?? 0,
        'status': _thaiToStatus(_status),
        'fuel': 0,
        'nextService': '',
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (widget.isEditing && widget.truckData != null) {
        // อัพเดทข้อมูลเดิม
        await _firestore
            .collection('vehicles')
            .doc(widget.truckData!['id'])
            .update(truckData);
      } else {
        // เพิ่มข้อมูลใหม่
        truckData['createdAt'] = FieldValue.serverTimestamp();
        await _firestore.collection('vehicles').add(truckData);
      }

      Navigator.pop(context, true); // ส่งผลลัพธ์กลับ
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาด: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final maxW = w >= 1100 ? 720.0 : (w >= 800 ? 640.0 : 520.0);

    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        title: Text(widget.isEditing ? 'แก้ไขรถบรรทุก' : 'เพิ่มรถใหม่'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxW),
            child: Card(
              elevation: 0,
              color: Colors.white,
              surfaceTintColor: Colors.white,
              shape: RoundedRectangleBorder(
                side: const BorderSide(color: kBorder),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      _gap(6),
                      TextFormField(
                        controller: _plate,
                        decoration: _dec('ทะเบียนรถ'),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'กรุณากรอกทะเบียนรถ'
                            : null,
                      ),
                      _gap(),
                      TextFormField(
                        controller: _model,
                        decoration: _dec('รุ่นรถ'),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'กรุณากรอกรุ่นรถ'
                            : null,
                      ),
                      _gap(),
                      TextFormField(
                        controller: _driver,
                        decoration: _dec('ชื่อผู้ขับ'),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'กรุณากรอกชื่อผู้ขับ'
                            : null,
                      ),
                      _gap(),
                      TextFormField(
                        controller: _location,
                        decoration: _dec('ตำแหน่งล่าสุด'),
                      ),
                      _gap(),
                      TextFormField(
                        controller: _mileage,
                        keyboardType: TextInputType.number,
                        decoration: _dec('ระยะทาง (กม.)'),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'กรุณากรอกระยะทาง';
                          }
                          if (int.tryParse(v) == null) {
                            return 'กรุณากรอกตัวเลขเท่านั้น';
                          }
                          return null;
                        },
                      ),
                      _gap(),
                      DropdownButtonFormField<String>(
                        value: _status,
                        items: const [
                          'พร้อมใช้งาน',
                          'กำลังซ่อม',
                          'ซ่อมบำรุง',
                          'ออฟไลน์',
                        ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                        onChanged: (v) => setState(() => _status = v ?? _status),
                        decoration: _dec('สถานะ'),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      _gap(16),

                      // ปุ่มบันทึกโทนฟ้า
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: kBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.save_rounded),
                          label: Text(
                            widget.isEditing ? 'อัพเดทข้อมูล' : 'บันทึก',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          onPressed: _save,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  SizedBox _gap([double h = 12]) => SizedBox(height: h);
}