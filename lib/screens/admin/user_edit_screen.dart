// lib/screens/admin/user_edit_screen.dart
import 'package:flutter/material.dart';

const _bgScaffold = Color(0xFFF5F8FF);
const _cardBorder = Color(0xFFE6ECFF);
const _textPrimary = Color(0xFF1E293B);
const _textMuted = Color(0xFF64748B);
const _blue = Color(0xFF2563EB);

class UserEditScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const UserEditScreen({super.key, required this.user});

  @override
  State<UserEditScreen> createState() => _UserEditScreenState();
}

class _UserEditScreenState extends State<UserEditScreen> {
  late final TextEditingController _name;
  late final TextEditingController _plate;
  String status = 'พร้อมใช้งาน';

  @override
  void initState() {
    super.initState();
    _name  = TextEditingController(text: widget.user['name']  ?? '');
    _plate = TextEditingController(text: widget.user['plate'] ?? '');
    status = (widget.user['status'] ?? 'พร้อมใช้งาน') as String;
  }

  @override
  void dispose() {
    _name.dispose();
    _plate.dispose();
    super.dispose();
  }

  InputDecoration _dec(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      isDense: true,
      filled: true,
      fillColor: Colors.white,
      labelStyle: const TextStyle(color: _textPrimary),
      hintStyle: const TextStyle(color: _textMuted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _cardBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _cardBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _blue, width: 1.4),
      ),
    );
  }

  Widget _initialAvatar(String name) {
    final first = (name.isNotEmpty ? name.characters.first : '?').toUpperCase();
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFF3B82F6), Color(0xFF60A5FA)],
        ),
      ),
      child: Container(
        width: 108,
        height: 108,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            first,
            style: const TextStyle(
              fontSize: 42,
              fontWeight: FontWeight.w900,
              color: _blue,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgScaffold,
      appBar: AppBar(
        title: const Text('แก้ไขผู้ใช้'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: .5,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
            child: Column(
              children: [
                // ===== Avatar (ไม่มีปุ่มอัปโหลดแล้ว) =====
                _initialAvatar(_name.text),
                const SizedBox(height: 16),

                // ===== แบบฟอร์ม =====
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _cardBorder),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0D000000),
                        blurRadius: 10,
                        offset: Offset(0, 2),
                      )
                    ],
                  ),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
                    child: Column(
                      children: [
                        TextField(
                          controller: _name,
                          onChanged: (_) => setState(() {}), // อัปเดตตัวอักษร Avatar ตามชื่อ
                          decoration: _dec('ชื่อ-นามสกุล'),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _plate,
                          decoration: _dec('ทะเบียนรถ'),
                        ),
                        const SizedBox(height: 12),
                        Text('hi'),
                        DropdownButtonFormField<String>(
                          value: status,
                          items: const [
                            'พร้อมใช้งาน',
                            'กำลังซ่อม',
                            'ไม่พร้อมใช้งาน',
                          ].map((e) => DropdownMenuItem(
                                value: e,
                                child: Text(e),
                              )).toList(),
                          onChanged: (v) => setState(() => status = v ?? status),
                          decoration: _dec('สถานะ'),
                          isDense: true,
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          width: 240,
                          child: FilledButton.icon(
                            onPressed: () {
                              final data = <String, dynamic>{
                                'name': _name.text.trim(),
                                'plate': _plate.text.trim(),
                                'status': status,
                                // ❌ ไม่มีการส่ง imageBytes/รูปภาพกลับอีกต่อไป
                              };
                              Navigator.pop(context, data);
                            },
                            icon: const Icon(Icons.save_outlined),
                            label: const Text('บันทึกการแก้ไข'),
                            style: FilledButton.styleFrom(
                              backgroundColor: _blue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
