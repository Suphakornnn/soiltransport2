// lib/screens/driver/driver_profile_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// ===== helper: sign out แล้วกลับหน้า Login (AuthGate/'/') สำหรับ Driver =====
Future<void> signOutAndGoLoginDriver(BuildContext context) async {
  try {
    await FirebaseAuth.instance.signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('ออกจากระบบไม่สำเร็จ: $e')),
    );
  }
}

class DriverProfileScreen extends StatefulWidget {
  const DriverProfileScreen({super.key});

  @override
  State<DriverProfileScreen> createState() => _DriverProfileScreenState();
}

class _DriverProfileScreenState extends State<DriverProfileScreen> {
  // ===== Demo profile (ปกติคุณจะดึงจาก API/DB) =====
  String fullName = 'แบงค์ สุขทวี';
  String roleText = 'คนขับรถบรรทุก';
  String plate = '72-2905';
  String phone = '080-593-2543';
  String company = 'KPS Transport Co.,Ltd.';
  String permission = 'DRIVER';

  // ===== Edit states =====
  bool _editing = false;
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _plateCtrl;
  late final TextEditingController _companyCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: fullName);
    _phoneCtrl = TextEditingController(text: phone);
    _plateCtrl = TextEditingController(text: plate);
    _companyCtrl = TextEditingController(text: company);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _plateCtrl.dispose();
    _companyCtrl.dispose();
    super.dispose();
  }

  void _toggleEdit() {
    if (_editing) {
      // กดยกเลิก: reset ค่า
      _nameCtrl.text = fullName;
      _phoneCtrl.text = phone;
      _plateCtrl.text = plate;
      _companyCtrl.text = company;
    }
    setState(() => _editing = !_editing);
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      fullName = _nameCtrl.text.trim();
      phone = _phoneCtrl.text.trim();
      plate = _plateCtrl.text.trim();
      company = _companyCtrl.text.trim();
      _editing = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('บันทึกโปรไฟล์เรียบร้อย')),
    );

    // TODO: call API/Provider เพื่ออัปเดตลงฐานข้อมูลจริง
  }

  // ===== UI =====
  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF1E40AF);
    const bg = Color(0xFFF5F8FF);
    const border = Color(0xFFE6ECFF);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('โปรไฟล์คนขับ'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // ===== Header card =====
              Card(
                color: Colors.white,
                surfaceTintColor: Colors.white,
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      // Avatar
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: primary.withOpacity(.05),
                        child: const Icon(Icons.person, color: primary, size: 28),
                      ),
                      const SizedBox(width: 12),
                      // Name + sub
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _editing
                                ? TextFormField(
                                    controller: _nameCtrl,
                                    decoration: _inputDeco('ชื่อ-นามสกุล'),
                                    validator: (v) =>
                                        (v == null || v.trim().isEmpty) ? 'กรอกชื่อ-นามสกุล' : null,
                                  )
                                : Text(fullName,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w800, fontSize: 16)),
                            const SizedBox(height: 2),
                            Text('$roleText • $plate',
                                style: const TextStyle(color: Colors.black54)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Edit / Save buttons
                      if (!_editing)
                        _softAction(
                          icon: Icons.edit,
                          label: 'แก้ไข',
                          onTap: _toggleEdit,
                        )
                      else
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _softAction(
                              icon: Icons.close,
                              label: 'ยกเลิก',
                              onTap: _toggleEdit,
                            ),
                            const SizedBox(width: 8),
                            _softAction(
                              icon: Icons.save,
                              label: 'บันทึก',
                              onTap: _save,
                              primary: true,
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // ===== Fields list =====
              _tile(
                icon: Icons.phone_iphone,
                title: 'เบอร์โทร',
                trailing: _editing
                    ? SizedBox(
                        width: 200,
                        child: TextFormField(
                          controller: _phoneCtrl,
                          keyboardType: TextInputType.phone,
                          decoration: _borderLessDeco('เช่น 080-000-0000'),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'กรอกเบอร์โทร' : null,
                        ),
                      )
                    : Text(phone, style: const TextStyle(color: Colors.black87)),
              ),
              _divider(border),
              _tile(
                icon: Icons.badge_outlined,
                title: 'สิทธิ์เข้าใช้งาน',
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF4FF),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: border),
                  ),
                  child: Text(permission,
                      style: const TextStyle(
                          color: primary, fontWeight: FontWeight.w700, letterSpacing: .4)),
                ),
              ),
              _divider(border),
              _tile(
                icon: Icons.apartment,
                title: 'บริษัท',
                trailing: _editing
                    ? SizedBox(
                        width: 260,
                        child: TextFormField(
                          controller: _companyCtrl,
                          decoration: _borderLessDeco('ชื่อบริษัท'),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'กรอกชื่อบริษัท' : null,
                        ),
                      )
                    : Text(company, style: const TextStyle(color: Colors.black87)),
              ),
              _divider(border),
              _tile(
                icon: Icons.local_shipping_outlined,
                title: 'ทะเบียนรถ',
                trailing: _editing
                    ? SizedBox(
                        width: 160,
                        child: TextFormField(
                          controller: _plateCtrl,
                          decoration: _borderLessDeco('เช่น กข-1234'),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'กรอกทะเบียนรถ' : null,
                        ),
                      )
                    : Text(plate, style: const TextStyle(color: Colors.black87)),
              ),
              const SizedBox(height: 16),

              // ===== Logout row =====
              Card(
                color: Colors.white,
                surfaceTintColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => signOutAndGoLoginDriver(context), // <- ใช้ helper นี้
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: const [
                        Icon(Icons.logout, color: Color(0xFFB3261E)),
                        SizedBox(width: 12),
                        Text('ออกจากระบบ',
                            style:
                                TextStyle(fontWeight: FontWeight.w700, color: Color(0xFFB3261E))),
                        Spacer(),
                        Icon(Icons.chevron_right, color: Colors.black45),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===== Small widgets =====
  Widget _tile({
    required IconData icon,
    required String title,
    required Widget trailing,
  }) {
    return Card(
      color: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: Colors.black54),
            const SizedBox(width: 12),
            Text(title),
            const Spacer(),
            Flexible(child: Align(alignment: Alignment.centerRight, child: trailing)),
          ],
        ),
      ),
    );
  }

  Widget _divider(Color c) =>
      Container(height: 8, color: c.withOpacity(.24), margin: const EdgeInsets.only(bottom: 8));

  InputDecoration _inputDeco(String label) => InputDecoration(
        isDense: true,
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      );

  InputDecoration _borderLessDeco(String hint) => InputDecoration(
        isDense: true,
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      );

  Widget _softAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool primary = false,
  }) {
    final bg = primary ? const Color(0xFFEEF2FF) : const Color(0xFFF2F4F7);
    final fg = primary ? const Color(0xFF1E40AF) : const Color(0xFF1F2937);
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18, color: fg),
      label: Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w700)),
      style: TextButton.styleFrom(
        backgroundColor: bg,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
