import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import './register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final _auth = AuthService();
  final _fs = FirestoreService();

  bool rememberMe = false;
  bool obscure = true;
  bool loading = false;

  @override
  void initState() {
    super.initState();
    _autoRouteIfRemembered();
  }

  @override
  void dispose() {
    emailCtrl.dispose();
    passCtrl.dispose();
    super.dispose();
  }

  Future<void> _autoRouteIfRemembered() async {
    final sp = await SharedPreferences.getInstance();
    final saved = sp.getBool('remember_me') ?? false;
    final user = FirebaseAuth.instance.currentUser;
    if (saved && user != null) {
      await _routeByRole(user.uid);
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => loading = true);
    try {
      final cred = await _auth.signIn(
        email: emailCtrl.text.trim(),
        password: passCtrl.text,
        rememberMe: rememberMe,
      );
      await _routeByRole(cred.user!.uid);
    } on FirebaseAuthException catch (e) {
      _toast(_mapError(e.code));
    } catch (_) {
      _toast('เกิดข้อผิดพลาด ลองใหม่อีกครั้ง');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _routeByRole(String uid) async {
    final role = await _fs.getRole(uid);
    if (!mounted) return;
    if (role == 'admin') {
      Navigator.pushReplacementNamed(context, '/admin');
    } else if (role == 'driver') {
      Navigator.pushReplacementNamed(context, '/driver');
    } else {
      _toast('ยังไม่กำหนดสิทธิ์ให้ผู้ใช้นี้');
    }
  }

  Future<void> _reset() async {
    if (emailCtrl.text.trim().isEmpty) {
      _toast('กรอกอีเมลก่อนกดลืมรหัสผ่าน');
      return;
    }
    try {
      await _auth.sendReset(emailCtrl.text.trim());
      _toast('ส่งอีเมลสำหรับรีเซ็ตรหัสผ่านแล้ว');
    } on FirebaseAuthException catch (e) {
      _toast(_mapError(e.code));
    }
  }

  String _mapError(String code) {
    switch (code) {
      case 'invalid-email':
        return 'อีเมลไม่ถูกต้อง';
      case 'user-not-found':
      case 'wrong-password':
        return 'อีเมลหรือรหัสผ่านไม่ถูกต้อง';
      case 'user-disabled':
        return 'บัญชีถูกปิดใช้งาน';
      case 'too-many-requests':
        return 'พยายามหลายครั้งเกินไป ลองใหม่ภายหลัง';
      default:
        return 'เข้าสู่ระบบไม่สำเร็จ ($code)';
    }
  }

  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    // โทนสีเรียบ
    const primary = Color(0xFF1E3A8A); // น้ำเงินเข้มเล็กน้อย
    const border = Color(0xFFE5E7EB);  // เทาขอบ
    const textPrimary = Color(0xFF0F172A);
    const textMuted = Color(0xFF64748B);

    return Theme(
      data: Theme.of(context).copyWith(
        scaffoldBackgroundColor: const Color(0xFFF7F9FC),
        colorScheme: Theme.of(context).colorScheme.copyWith(primary: primary),
        inputDecorationTheme: const InputDecorationTheme(
          hintStyle: TextStyle(color: Color(0xFF94A3B8)),
        ),
      ),
      child: Scaffold(
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, c) {
              final isWide = c.maxWidth >= 980;
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1060),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: isWide
                        ? Row(
                            children: [
                              const Expanded(child: _PlainBrandPane()),
                              const SizedBox(width: 24),
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 420),
                                child: _formCard(
                                  primary: primary,
                                  border: border,
                                  textPrimary: textPrimary,
                                  textMuted: textMuted,
                                ),
                              ),
                            ],
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 420),
                                child: _formCard(
                                  primary: primary,
                                  border: border,
                                  textPrimary: textPrimary,
                                  textMuted: textMuted,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // =============== Form Card (เรียบง่าย) ===============
  Widget _formCard({
    required Color primary,
    required Color border,
    required Color textPrimary,
    required Color textMuted,
  }) {
    InputDecoration _dec(String hint, IconData icon) => InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon, color: const Color(0xFF334155)),
          filled: true,
          fillColor: Colors.white,
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: primary, width: 1.4),
          ),
        );

    return Card(
      color: Colors.white,
      elevation: 0, // ไม่ยกมาก
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: border),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header เล็กๆ
              Row(
                children: const [
                  Icon(Icons.local_shipping_outlined, size: 22, color: Color(0xFF1E3A8A)),
                  SizedBox(width: 8),
                  Text(
                    'เข้าสู่ระบบ',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Soil Transport Management',
                  style: TextStyle(color: Color(0xFF64748B)),
                ),
              ),
              const SizedBox(height: 18),

              // Email
              TextFormField(
                controller: emailCtrl,
                autofocus: true,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.username, AutofillHints.email],
                decoration: _dec('อีเมล', Icons.alternate_email_rounded),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'กรอกอีเมล' : null,
              ),
              const SizedBox(height: 12),

              // Password
              TextFormField(
                controller: passCtrl,
                obscureText: obscure,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                onFieldSubmitted: (_) => _login(),
                decoration: _dec('รหัสผ่าน', Icons.lock_outline_rounded).copyWith(
                  suffixIcon: IconButton(
                    tooltip: obscure ? 'แสดงรหัสผ่าน' : 'ซ่อนรหัสผ่าน',
                    icon: Icon(
                      obscure
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      color: const Color(0xFF334155),
                    ),
                    onPressed: () => setState(() => obscure = !obscure),
                  ),
                ),
                validator: (v) => (v == null || v.isEmpty) ? 'กรอกรหัสผ่าน' : null,
              ),

              const SizedBox(height: 8),
              Row(
                children: [
                  Checkbox(
                    value: rememberMe,
                    onChanged: (v) => setState(() => rememberMe = v ?? false),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  const Text('จดจำฉันไว้ในระบบ',
                      style: TextStyle(color: Color(0xFF334155))),
                  const Spacer(),
                ],
              ),

              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: FilledButton.icon(
                  onPressed: loading ? null : _login,
                  icon: loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.login_rounded, size: 18),
                  label: Text(
                    loading ? 'กำลังเข้าสู่ระบบ...' : 'เข้าสู่ระบบ',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),

              const SizedBox(height: 14),
              const Divider(height: 1),

              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('ยังไม่มีบัญชี?', style: TextStyle(color: Color(0xFF334155))),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const RegisterScreen()),
                      );
                    },
                    child: const Text('ลงทะเบียน'),
                  ),
                ],
              ),

              const SizedBox(height: 4),
              const Text(
                'Role ถูกกำหนดจากฐานข้อมูลอัตโนมัติ',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 12.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============== แผงซ้ายแบบเรียบ (Desktop เท่านั้น) ===============
class _PlainBrandPane extends StatelessWidget {
  const _PlainBrandPane();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 420,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      padding: const EdgeInsets.all(22),
      child: const Align(
        alignment: Alignment.topLeft,
        child: _BrandText(),
      ),
    );
  }
}

class _BrandText extends StatelessWidget {
  const _BrandText();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.inventory_2_outlined, color: Color(0xFF1E3A8A), size: 22),
        SizedBox(height: 10),
        Text(
          'ระบบบริหารจัดการขนส่งดิน',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
          ),
        ),
        SizedBox(height: 6),
        Text(
          'เข้าสู่ระบบเพื่อจัดการงาน มอบหมายคนขับ และติดตามรถแบบเรียลไทม์',
          style: TextStyle(color: Color(0xFF64748B)),
        ),
      ],
    );
  }
}
