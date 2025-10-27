// lib/screens/admin/user_detail_screen.dart
import 'package:flutter/material.dart';

class UserDetailScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const UserDetailScreen({super.key, required this.user});

  @override
  State<UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends State<UserDetailScreen> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _plateCtrl;
  String _status = 'พร้อมใช้งาน';

  @override
  void initState() {
    super.initState();
    _nameCtrl  = TextEditingController(text: widget.user['name']  as String? ?? '');
    _plateCtrl = TextEditingController(text: widget.user['plate'] as String? ?? '');
    _status    = (widget.user['status'] as String?) ?? 'พร้อมใช้งาน';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _plateCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final updated = Map<String, dynamic>.from(widget.user);
    updated['name']   = _nameCtrl.text.trim();
    updated['plate']  = _plateCtrl.text.trim();
    updated['status'] = _status;

    Navigator.pop(context, updated);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('บันทึกข้อมูลแล้ว')),
    );
  }

  // ===== Avatar อักษรแรก (แทนการใช้รูป) =====
  Widget _initialAvatar(String name) {
    final first = name.isNotEmpty ? name.characters.first.toUpperCase() : '?';
    return Container(
      width: 72,
      height: 72,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF60A5FA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          first,
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F8FF),
      appBar: AppBar(
        title: const Text('รายละเอียดผู้ใช้'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        foregroundColor: const Color(0xFF0F3D9E),
        elevation: 0.5,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
            children: [
              // การ์ดข้อมูลหลัก
              Card(
                elevation: 1,
                surfaceTintColor: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
                  child: Column(
                    children: [
                      // Avatar + Info (ไม่มีปุ่มอัปโหลดแล้ว)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          _initialAvatar(_nameCtrl.text),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _nameCtrl.text.isEmpty ? '—' : _nameCtrl.text,
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.badge_outlined, size: 16, color: Colors.black54),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        'ทะเบียน: ${_plateCtrl.text.isEmpty ? "—" : _plateCtrl.text}',
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(color: Colors.black54),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(height: 1),
                      const SizedBox(height: 16),

                      // ฟอร์ม
                      _label('ชื่อ-นามสกุล'),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _nameCtrl,
                        onChanged: (_) => setState(() {}),
                        decoration: _inputDeco('ระบุชื่อ-นามสกุล'),
                      ),
                      const SizedBox(height: 12),
                      _label('ทะเบียนรถ'),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _plateCtrl,
                        onChanged: (_) => setState(() {}),
                        decoration: _inputDeco('เช่น กข-1234'),
                      ),
                      const SizedBox(height: 12),
                      _label('สถานะ'),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: _status,
                        items: const [
                          'พร้อมใช้งาน',
                          'กำลังซ่อม',
                          'ไม่พร้อมใช้งาน',
                        ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                        onChanged: (v) => setState(() => _status = v ?? _status),
                        decoration: _inputDeco('เลือกสถานะ'),
                      ),
                      const SizedBox(height: 18),

                      // ปุ่มบันทึก
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _save,
                          icon: const Icon(Icons.save_outlined),
                          label: const Text('บันทึกการแก้ไข'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF0F3D9E),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _StatusCard(status: _status, colorScheme: cs),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- small widgets ----------
  InputDecoration _inputDeco(String hint) {
    return InputDecoration(
      hintText: hint,
      isDense: true,
      filled: true,
      fillColor: const Color(0xFFF8FBFF),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE3ECFF)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE3ECFF)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF98B8FF)),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }

  Widget _label(String t) => Align(
        alignment: Alignment.centerLeft,
        child: Text(
          t,
          style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF0F3D9E)),
        ),
      );
}

class _StatusCard extends StatelessWidget {
  final String status;
  final ColorScheme colorScheme;
  const _StatusCard({required this.status, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    Color bg, fg;
    switch (status) {
      case 'พร้อมใช้งาน':
        bg = const Color(0xFF10B981).withOpacity(.1);
        fg = const Color(0xFF047857);
        break;
      case 'กำลังซ่อม':
        bg = const Color(0xFFF59E0B).withOpacity(.12);
        fg = const Color(0xFF8A4B00);
        break;
      case 'ไม่พร้อมใช้งาน':
      default:
        bg = const Color(0xFFEF4444).withOpacity(.12);
        fg = const Color(0xFFB91C1C);
        break;
    }

    return Card(
      elevation: 1,
      surfaceTintColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(30)),
              child: Text(status, style: TextStyle(color: fg, fontWeight: FontWeight.w700)),
            ),
            const Spacer(),
            const Icon(Icons.info_outline, color: Colors.black54, size: 18),
            const SizedBox(width: 6),
            const Text('สถานะปัจจุบันของผู้ใช้'),
          ],
        ),
      ),
    );
  }
}
