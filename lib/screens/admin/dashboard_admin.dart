import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'manage_users.dart';
import 'manage_trucks.dart';
import 'manage_jobs.dart';
import 'tracking_screen.dart';
import 'reports_screen.dart';
import 'payroll_screen.dart';
import 'soil_calculator_screen.dart';

/// ===== helper: sign out แล้วกลับหน้า Login (AuthGate/‘/’) =====
Future<void> signOutAndGoLogin(BuildContext context) async {
  try {
    await FirebaseAuth.instance.signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ออกจากระบบไม่สำเร็จ: $e')));
  }
}

/// ===== Responsive helpers =====
class R {
  static const double compact = 600;
  static const double medium = 1024;
  static const double expanded = 1280;

  static bool isCompact(BuildContext c) => MediaQuery.of(c).size.width < compact;
  static bool isExpanded(BuildContext c) => MediaQuery.of(c).size.width >= medium;

  static int cols(BuildContext c, {int c2 = 2, int c3 = 3, int c4 = 4, int c6 = 6}) {
    final w = MediaQuery.of(c).size.width;
    if (w >= expanded) return c6;
    if (w >= medium) return c4;
    if (w >= compact) return c3;
    return c2;
  }
}

/// ===== Fixed heights (กัน overflow บนเว็บ) =====
double kpiCardHeightFor(BuildContext context) {
  final w = MediaQuery.of(context).size.width;
  final scale = MediaQuery.of(context).textScaleFactor;
  double h;
  if (w >= 1280) {
    h = 168;
  } else if (w >= 900) {
    h = 176;
  } else {
    h = 186;
  }
  if (scale > 1.1) h += (scale - 1.1) * 26;
  return h.clamp(160, 220);
}

double quickCardHeightFor(BuildContext context) {
  final w = MediaQuery.of(context).size.width;
  final scale = MediaQuery.of(context).textScaleFactor;
  double h;
  if (w >= 1280) {
    h = 150;
  } else if (w >= 900) {
    h = 156;
  } else {
    h = 166;
  }
  if (scale > 1.0) h += (scale - 1.0) * 18;
  return h.clamp(140, 190);
}

class DashboardAdmin extends StatefulWidget {
  const DashboardAdmin({super.key});
  @override
  State<DashboardAdmin> createState() => _DashboardAdminState();
}

class _DashboardAdminState extends State<DashboardAdmin> {
  int totalJobs = 0;
  int completedJobs = 0;
  int totalTrucks = 0;
  int totalDrivers = 0;
  List<Map<String, dynamic>> recentActivities = [];

  final TextEditingController _search = TextEditingController();
  int _bottomIndex = 0;

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
    _fetchRecentActivities();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _fetchDashboardData() async {
    try {
      // 1. ดึงงานทั้งหมดจาก collection jobs
      final jobsSnapshot = await FirebaseFirestore.instance.collection('jobs').get();
      setState(() {
        totalJobs = jobsSnapshot.docs.length;
      });

      // 2. ดึงงานที่เสร็จสิ้นจาก status ใน collection jobs
      int completedCount = 0;
      for (final doc in jobsSnapshot.docs) {
        final status = doc['status'] as String?;
        if (status == 'completed' || status == 'เสร็จสิ้น' || status == 'DONE' || status == 'done') {
          completedCount++;
        }
      }
      setState(() {
        completedJobs = completedCount;
      });

      // 3. ดึงจำนวนรถจาก collection vehicles
      final vehiclesSnapshot = await FirebaseFirestore.instance.collection('vehicles').get();
      setState(() {
        totalTrucks = vehiclesSnapshot.docs.length;
      });

      // 4. ดึงจำนวนคนขับจาก collection vehicles (นับจากฟิลด์ driver)
      int driverCount = 0;
      for (final doc in vehiclesSnapshot.docs) {
        final data = doc.data();
        if (data.containsKey('driver')) {
          final driverField = data['driver'];
          // นับทั้ง driver ที่เป็น String และ Map
          if (driverField != null && driverField.toString().trim().isNotEmpty) {
            driverCount++;
          }
        }
      }
      setState(() {
        totalDrivers = driverCount;
      });
    } catch (e) {
      print('Error fetching dashboard data: $e');
    }
  }

  Future<void> _fetchRecentActivities() async {
    try {
      final jobsSnapshot =
          await FirebaseFirestore.instance.collection('jobs').orderBy('createdAt', descending: true).limit(3).get();

      final List<Map<String, dynamic>> activities = [];

      for (final doc in jobsSnapshot.docs) {
        final data = doc.data();
        final projectName = data['code'] ?? 'ไม่มีชื่อโครงการ';
        final status = data['status'] ?? 'unknown';
        final createdAt = data['createdAt'] as Timestamp?;

        String timeText = 'ไม่ทราบเวลา';
        if (createdAt != null) {
          final now = DateTime.now();
          final difference = now.difference(createdAt.toDate());

          if (difference.inMinutes < 1) {
            timeText = 'เมื่อสักครู่';
          } else if (difference.inMinutes < 60) {
            timeText = '${difference.inMinutes} นาทีที่ผ่านมา';
          } else if (difference.inHours < 24) {
            timeText = '${difference.inHours} ชั่วโมงที่ผ่านมา';
          } else {
            timeText = '${difference.inDays} วันที่ผ่านมา';
          }
        }

        activities.add({'title': 'งาน: $projectName', 'time': timeText, 'status': status});
      }

      setState(() {
        recentActivities = activities;
      });
    } catch (e) {
      print('Error fetching recent activities: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final wide = R.isExpanded(context);

    final jobsText = totalJobs > 0 ? '$totalJobs งาน' : 'ยังไม่พบงานในระบบ';
    final trucksText = totalTrucks > 0 ? '$totalTrucks คัน' : 'ยังไม่พบรถในระบบ';
    final driversText = totalDrivers > 0 ? '$totalDrivers คน' : 'ยังไม่มีข้อมูลคนขับรถ';

    return Scaffold(
      backgroundColor: Color.lerp(cs.surface, Colors.white, .02),
      drawer: wide ? null : _AppDrawer(onNavigate: _nav),
      floatingActionButton: wide ? null : _FabCreate(onPressed: () => _nav(const ManageJobsScreen())),
      body: SafeArea(
        child: Row(
          children: [
            if (wide) _SideRail(onNavigate: _nav),
            Expanded(
              child: CustomScrollView(
                slivers: [
                  SliverAppBar(
                    pinned: true,
                    elevation: 0,
                    backgroundColor: cs.surface.withOpacity(.85),
                    flexibleSpace: ClipRect(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                        child: Container(color: Colors.transparent),
                      ),
                    ),
                    titleSpacing: 0,
                    title: Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Row(
                        children: [
                          const SizedBox(width: 8),
                          _BrandMark(),
                          const SizedBox(width: 10),
                          Text(
                            'หน้าหลักแอดมิน',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const Spacer(),
                          if (!R.isCompact(context))
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 460),
                              child: _SearchBox(controller: _search, onClear: () => setState(() => _search.clear)),
                            ),
                          if (!R.isCompact(context)) const SizedBox(width: 8),
                          if (!R.isCompact(context))
                            FilledButton.icon(
                              icon: const Icon(Icons.add_circle_rounded),
                              onPressed: () => _nav(const ManageJobsScreen()),
                              label: const Text('สร้างงานใหม่'),
                            ),
                          if (!R.isCompact(context)) const SizedBox(width: 8),
                          _PopupUserMenu(
                            onLogout: () {
                              signOutAndGoLogin(context);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1200),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _HeroGlass(
                                openCount: totalJobs,
                                runCount: totalJobs - completedJobs,
                                doneCount: completedJobs,
                                onCreateJob: () => _nav(const ManageJobsScreen()),
                                onTrack: () => _nav(TrackingScreen()),
                                onReport: () => _nav(ReportsScreen()),
                              ),
                              const SizedBox(height: 18),
                              _SectionTitle('ภาพรวมวันนี้'),
                              const SizedBox(height: 12),
                              _KpiGrid(
                                items: [
                                  KpiItem(
                                    'งานทั้งหมด',
                                    jobsText,
                                    Icons.event_note_rounded,
                                    Colors.orange,
                                    () => _nav(const ManageJobsScreen()),
                                  ),
                                  KpiItem(
                                    'งานเสร็จสิ้น',
                                    '$completedJobs งาน',
                                    Icons.verified_rounded,
                                    Colors.green,
                                    () => _nav(ReportsScreen()),
                                  ),
                                  KpiItem(
                                    'จำนวนรถ',
                                    trucksText,
                                    Icons.local_shipping_rounded,
                                    Colors.blue,
                                    () => _nav(ManageTrucks()),
                                  ),
                                  KpiItem(
                                    'คนขับ',
                                    driversText,
                                    Icons.group_rounded,
                                    Colors.purple,
                                    () => _nav(ManageUsers()),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 22),
                              _SectionTitle('เมนูลัด'),
                              const SizedBox(height: 12),
                              _QuickGrid(
                                cols: R.cols(context, c2: 2, c3: 3, c4: 4, c6: 8),
                                items: [
                                  QuickItem(
                                    'สร้างงานใหม่',
                                    Icons.add_circle_rounded,
                                    Colors.indigo,
                                    () => _nav(const ManageJobsScreen()),
                                  ),
                                  QuickItem(
                                    'จัดการงาน',
                                    Icons.assignment_outlined,
                                    Colors.orange,
                                    () => _nav(const ManageJobsScreen()),
                                  ),
                                  QuickItem(
                                    'ติดตามรถ',
                                    Icons.location_on_outlined,
                                    Colors.pink,
                                    () => _nav(TrackingScreen()),
                                  ),
                                  QuickItem(
                                    'รถบรรทุก',
                                    Icons.local_shipping_outlined,
                                    Colors.teal,
                                    () => _nav(ManageTrucks()),
                                  ),
                                  QuickItem(
                                    'ผู้ใช้งาน',
                                    Icons.people_alt_outlined,
                                    Colors.deepPurple,
                                    () => _nav(ManageUsers()),
                                  ),
                                  QuickItem(
                                    'เงินเดือน & น้ำมัน',
                                    Icons.attach_money_rounded,
                                    Colors.green,
                                    () => _nav(const PayrollScreen()),
                                  ),
                                  QuickItem(
                                    'คำนวณดิน',
                                    Icons.calculate_rounded,
                                    Colors.blueGrey,
                                    () => _nav(const SoilCalculatorScreen()),
                                  ),
                                  QuickItem(
                                    'รายงานสรุป',
                                    Icons.bar_chart_rounded,
                                    Colors.cyan,
                                    () => _nav(ReportsScreen()),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 18),
                              _SectionTitle('กิจกรรมล่าสุด'),
                              const SizedBox(height: 10),
                              _RecentList(items: recentActivities),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar:
          R.isExpanded(context)
              ? null
              : NavigationBar(
                selectedIndex: _bottomIndex,
                onDestinationSelected: (i) {
                  setState(() => _bottomIndex = i);
                  switch (i) {
                    case 0:
                      break;
                    case 1:
                      _nav(const ManageJobsScreen());
                      break;
                    case 2:
                      _nav(TrackingScreen());
                      break;
                    case 3:
                      _nav(ReportsScreen());
                      break;
                  }
                },
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.dashboard_outlined),
                    selectedIcon: Icon(Icons.dashboard),
                    label: 'หน้าหลัก',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.assignment_outlined),
                    selectedIcon: Icon(Icons.assignment),
                    label: 'งาน',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.location_on_outlined),
                    selectedIcon: Icon(Icons.location_on),
                    label: 'ติดตาม',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.bar_chart_outlined),
                    selectedIcon: Icon(Icons.bar_chart),
                    label: 'รายงาน',
                  ),
                ],
              ),
    );
  }

  void _nav(Widget page) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
}

class _SearchBox extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onClear;
  const _SearchBox({required this.controller, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: 'ค้นหา: งาน / โครงการ / ทะเบียนรถ',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: controller.text.isEmpty ? null : IconButton(icon: const Icon(Icons.clear), onPressed: onClear),
        isDense: true,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 11),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
      onChanged: (_) {},
    );
  }
}

class _HeroGlass extends StatelessWidget {
  final int openCount, runCount, doneCount;
  final VoidCallback onCreateJob, onTrack, onReport;

  const _HeroGlass({
    required this.openCount,
    required this.runCount,
    required this.doneCount,
    required this.onCreateJob,
    required this.onTrack,
    required this.onReport,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final wide = !R.isCompact(context);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.primary.withOpacity(.10), cs.secondary.withOpacity(.10)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.35),
                    border: Border.all(color: cs.primary.withOpacity(.15)),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ),
            Padding(padding: const EdgeInsets.all(16), child: wide ? _wideLayout(context) : _compactLayout(context)),
          ],
        ),
      ),
    );
  }

  Widget _wideLayout(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _BannerText(),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _StatPill(
                    icon: Icons.event_note_rounded,
                    label: 'งานวันนี้',
                    value: '$openCount งาน',
                    color: Colors.indigo,
                  ),
                  _StatPill(
                    icon: Icons.play_arrow_rounded,
                    label: 'กำลังวิ่ง',
                    value: '$runCount งาน',
                    color: Colors.orange,
                  ),
                  _StatPill(
                    icon: Icons.verified_rounded,
                    label: 'เสร็จสิ้น',
                    value: '$doneCount งาน',
                    color: Colors.green,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _GhostButton(icon: Icons.location_on_rounded, label: 'ติดตามรถ', onPressed: onTrack),
            _GhostButton(icon: Icons.bar_chart_rounded, label: 'ดูรายงาน', onPressed: onReport),
          ],
        ),
      ],
    );
  }

  Widget _compactLayout(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _BannerText(),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _StatPill(
              icon: Icons.event_note_rounded,
              label: 'งานวันนี้',
              value: '$openCount งาน',
              color: Colors.indigo,
            ),
            _StatPill(icon: Icons.play_arrow_rounded, label: 'กำลังวิ่ง', value: '$runCount งาน', color: Colors.orange),
            _StatPill(icon: Icons.verified_rounded, label: 'เสร็จสิ้น', value: '$doneCount งาน', color: Colors.green),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _GhostButton(icon: Icons.location_on_rounded, label: 'ติดตามรถ', onPressed: onTrack),
            _GhostButton(icon: Icons.bar_chart_rounded, label: 'ดูรายงาน', onPressed: onReport),
          ],
        ),
      ],
    );
  }
}

class _BannerText extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final onVar = Theme.of(context).colorScheme.onSurfaceVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'บริหารงานให้ไหลลื่น',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        Text('สร้างงาน • ติดตามรถ • สรุปรายงาน ได้ในหน้าเดียว', style: TextStyle(color: onVar)),
      ],
    );
  }
}

class _StatPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatPill({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final onVar = Theme.of(context).colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: onVar.withOpacity(.20)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.04), blurRadius: 12, offset: const Offset(0, 6))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [color.withOpacity(.16), color.withOpacity(.10)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: onVar)),
          const SizedBox(width: 8),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _GhostButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  const _GhostButton({required this.icon, required this.label, required this.onPressed});
  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      icon: Icon(icon),
      onPressed: onPressed,
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: Theme.of(context).colorScheme.primary,
        side: BorderSide(color: Theme.of(context).colorScheme.primary.withOpacity(.35)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class _FabCreate extends StatelessWidget {
  final VoidCallback onPressed;
  const _FabCreate({required this.onPressed});
  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: onPressed,
      icon: const Icon(Icons.add_circle_rounded),
      label: const Text('สร้างงานใหม่'),
    );
  }
}

class _SideRail extends StatelessWidget {
  final void Function(Widget) onNavigate;
  const _SideRail({required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 262,
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(right: BorderSide(color: cs.outlineVariant.withOpacity(.4))),
      ),
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 18, 14, 24),
              children: [
                _BrandRow(),
                const SizedBox(height: 16),
                _RailItem('ภาพรวม', Icons.dashboard_rounded, () {}),
                _RailItem('งานขนส่ง', Icons.assignment_rounded, () => onNavigate(const ManageJobsScreen())),
                _RailItem('ติดตามรถ', Icons.location_on_rounded, () => onNavigate(TrackingScreen())),
                _RailItem('รถบรรทุก', Icons.local_shipping_rounded, () => onNavigate(ManageTrucks())),
                _RailItem('ผู้ใช้งาน', Icons.people_alt_rounded, () => onNavigate(ManageUsers())),
                _RailItem('รายงาน', Icons.bar_chart_rounded, () => onNavigate(ReportsScreen())),
                _RailItem('เงินเดือน & น้ำมัน', Icons.attach_money_rounded, () => onNavigate(const PayrollScreen())),
                _RailItem('คำนวณดิน', Icons.calculate_rounded, () => onNavigate(const SoilCalculatorScreen())),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
            child: Column(
              children: [
                Divider(color: cs.outlineVariant.withOpacity(.35)),
                ListTile(
                  leading: const Icon(Icons.logout, color: Color(0xFFB3261E)),
                  title: const Text('ออกจากระบบ', style: TextStyle(color: Color(0xFFB3261E))),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onTap: () {
                    signOutAndGoLogin(context);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _RailItem(this.label, this.icon, this.onTap);
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: ListTile(
        leading: Icon(icon),
        title: Text(label),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        hoverColor: cs.primary.withOpacity(.06),
        onTap: onTap,
      ),
    );
  }
}

class _AppDrawer extends StatelessWidget {
  final void Function(Widget) onNavigate;
  const _AppDrawer({required this.onNavigate});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Drawer(
      child: ListView(
        children: [
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [cs.primary, cs.secondary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            accountName: const Text('Admin'),
            accountEmail: const Text('admin@company.com'),
            currentAccountPicture: const CircleAvatar(child: Icon(Icons.admin_panel_settings, size: 26)),
          ),
          _drawerItem(context, Icons.assignment, 'จัดการงานขนส่ง', const ManageJobsScreen()),
          _drawerItem(context, Icons.location_on, 'ติดตามตำแหน่งรถ', TrackingScreen()),
          _drawerItem(context, Icons.local_shipping, 'จัดการรถบรรทุก', ManageTrucks()),
          _drawerItem(context, Icons.people, 'จัดการผู้ใช้งาน', ManageUsers()),
          _drawerItem(context, Icons.bar_chart, 'รายงานสรุป', ReportsScreen()),
          _drawerItem(context, Icons.attach_money, 'เงินเดือน & น้ำมัน', const PayrollScreen()),
          _drawerItem(context, Icons.calculate, 'คำนวณปริมาณดิน', const SoilCalculatorScreen()),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Color(0xFFB3261E)),
            title: const Text('ออกจากระบบ'),
            onTap: () {
              Navigator.pop(context);
              signOutAndGoLogin(context);
            },
          ),
        ],
      ),
    );
  }

  Widget _drawerItem(BuildContext context, IconData icon, String text, Widget page) {
    return ListTile(
      leading: Icon(icon),
      title: Text(text),
      onTap: () {
        Navigator.pop(context);
        Future.microtask(() => onNavigate(page));
      },
    );
  }
}

class KpiItem {
  final String title, value;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  KpiItem(this.title, this.value, this.icon, this.color, this.onTap);
}

class _KpiGrid extends StatelessWidget {
  final List<KpiItem> items;
  const _KpiGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    int cross = 2;
    if (w >= 1200) {
      cross = 4;
    } else if (w >= 800) {
      cross = 3;
    }

    final itemHeight = kpiCardHeightFor(context);
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cross,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        mainAxisExtent: itemHeight,
      ),
      itemBuilder: (_, i) => _KpiCard(item: items[i]),
    );
  }
}

class _KpiCard extends StatefulWidget {
  final KpiItem item;
  const _KpiCard({required this.item});
  @override
  State<_KpiCard> createState() => _KpiCardState();
}

class _KpiCardState extends State<_KpiCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final c = widget.item.color;
    final scale = MediaQuery.of(context).textScaleFactor;

    final baseNumStyle =
        Theme.of(context).textTheme.titleLarge ?? const TextStyle(fontSize: 22, fontWeight: FontWeight.w800);
    final numFontSize = (baseNumStyle.fontSize ?? 22) * (scale > 1.1 ? 0.92 : 1.0);

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedScale(
        scale: _hover ? 1.015 : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [c.withOpacity(.45), c.withOpacity(.15)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Container(
            margin: const EdgeInsets.all(1.2),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(_hover ? .08 : .05),
                  blurRadius: _hover ? 20 : 14,
                  offset: const Offset(0, 8),
                ),
              ],
              border: Border.all(color: cs.outlineVariant.withOpacity(.2)),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: widget.item.onTap,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _IconBadge(icon: widget.item.icon, color: c),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            widget.item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: .2),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    _MetricValue(
                      numberText: _splitNumber(widget.item.value).$1,
                      unitText: _splitNumber(widget.item.value).$2,
                      numFontSize: numFontSize,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  (String, String) _splitNumber(String v) {
    String n = v, u = '';
    final i = v.trim().lastIndexOf(' ');
    if (i > 0) {
      n = v.substring(0, i).trim();
      u = v.substring(i).trim();
    }
    return (n, u);
  }
}

class _IconBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  const _IconBadge({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [color.withOpacity(.18), color.withOpacity(.10)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [BoxShadow(color: color.withOpacity(.12), blurRadius: 12, offset: const Offset(0, 6))],
      ),
      child: Icon(icon, size: 20, color: color),
    );
  }
}

class _MetricValue extends StatelessWidget {
  final String numberText;
  final String unitText;
  final double numFontSize;
  const _MetricValue({required this.numberText, required this.unitText, required this.numFontSize});

  @override
  Widget build(BuildContext context) {
    final numStyle = (Theme.of(context).textTheme.titleLarge ??
            const TextStyle(fontSize: 22, fontWeight: FontWeight.w900))
        .copyWith(fontWeight: FontWeight.w900, height: 1.1, fontSize: numFontSize);
    final unitStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w700,
    );

    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(numberText, style: numStyle),
          if (unitText.isNotEmpty) ...[const SizedBox(width: 6), Text(unitText, style: unitStyle)],
        ],
      ),
    );
  }
}

class QuickItem {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  QuickItem(this.label, this.icon, this.color, this.onTap);
}

class _QuickGrid extends StatelessWidget {
  final List<QuickItem> items;
  final int cols;
  const _QuickGrid({required this.items, required this.cols});

  @override
  Widget build(BuildContext context) {
    final itemHeight = quickCardHeightFor(context);
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        mainAxisExtent: itemHeight,
      ),
      itemBuilder: (_, i) => _QuickCard(item: items[i]),
    );
  }
}

class _QuickCard extends StatefulWidget {
  final QuickItem item;
  const _QuickCard({required this.item});
  @override
  State<_QuickCard> createState() => _QuickCardState();
}

class _QuickCardState extends State<_QuickCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cs.outlineVariant.withOpacity(.35)),
          boxShadow:
              _hover
                  ? [BoxShadow(color: Colors.black.withOpacity(.07), blurRadius: 16, offset: const Offset(0, 10))]
                  : [BoxShadow(color: Colors.black.withOpacity(.04), blurRadius: 12, offset: const Offset(0, 6))],
        ),
        child: InkWell(
          onTap: widget.item.onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [widget.item.color.withOpacity(.16), widget.item.color.withOpacity(.10)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Icon(widget.item.icon, color: widget.item.color, size: 22),
                ),
                const SizedBox(height: 10),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 160),
                    child: Text(
                      widget.item.label,
                      maxLines: 2,
                      softWrap: true,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      textHeightBehavior: const TextHeightBehavior(
                        applyHeightToFirstAscent: false,
                        applyHeightToLastDescent: false,
                      ),
                      style: const TextStyle(fontWeight: FontWeight.w800),
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

class _RecentList extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  const _RecentList({required this.items});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cs.outlineVariant.withOpacity(.45)),
        ),
        child: Column(
          children: [
            Icon(Icons.history_rounded, size: 48, color: cs.outlineVariant),
            const SizedBox(height: 8),
            Text('ไม่มีกิจกรรมล่าสุด', style: TextStyle(color: cs.outlineVariant)),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant.withOpacity(.45)),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: items.length,
        separatorBuilder: (_, __) => Divider(height: 1, color: cs.outlineVariant.withOpacity(.45)),
        itemBuilder: (_, i) {
          final it = items[i];
          return ListTile(
            minVerticalPadding: 16,
            leading: const Icon(Icons.history_rounded),
            title: Text(it['title']),
            subtitle: Text(it['time']),
            trailing: _StatusChip(status: it['status']),
            onTap: () {},
          );
        },
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  String _getStatusText(String status) {
    switch (status) {
      case 'waiting':
      case 'รอดำเนินการ':
        return 'รอดำเนินการ';
      case 'in_progress':
      case 'กำลังดำเนินการ':
        return 'กำลังดำเนินการ';
      case 'completed':
      case 'เสร็จสิ้น':
        return 'เสร็จสิ้น';
      case 'cancelled':
      case 'ยกเลิก':
        return 'ยกเลิก';
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'waiting':
      case 'รอดำเนินการ':
        return Colors.orange;
      case 'in_progress':
      case 'กำลังดำเนินการ':
        return Colors.indigo;
      case 'completed':
      case 'เสร็จสิ้น':
        return Colors.green;
      case 'cancelled':
      case 'ยกเลิก':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusText = _getStatusText(status);
    final statusColor = _getStatusColor(status);

    return Chip(
      label: Text(statusText),
      backgroundColor: statusColor.withOpacity(.12),
      labelStyle: TextStyle(color: statusColor, fontWeight: FontWeight.w700),
    );
  }
}

class _BrandMark extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(color: cs.primary, borderRadius: BorderRadius.circular(10)),
      child: Icon(Icons.dashboard_rounded, color: cs.onPrimary),
    );
  }
}

class _BrandRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(color: cs.primary, borderRadius: BorderRadius.circular(10)),
          child: Icon(Icons.dashboard, color: cs.onPrimary),
        ),
        const SizedBox(width: 10),
        Text('Soil Transport', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 6,
          height: 22,
          decoration: BoxDecoration(color: cs.primary, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 8),
        Text(text, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
      ],
    );
  }
}

class _PopupUserMenu extends StatelessWidget {
  final VoidCallback onLogout;
  const _PopupUserMenu({required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'บัญชีผู้ใช้',
      offset: const Offset(0, 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (v) {
        if (v == 'logout') onLogout();
      },
      itemBuilder:
          (ctx) => const [
            PopupMenuItem(value: 'profile', child: Text('โปรไฟล์')),
            PopupMenuDivider(),
            PopupMenuItem(
              value: 'logout',
              child: Row(
                children: [
                  Icon(Icons.logout, color: Color(0xFFB3261E)),
                  SizedBox(width: 8),
                  Text('ออกจากระบบ', style: TextStyle(color: Color(0xFFB3261E))),
                ],
              ),
            ),
          ],
      child: const CircleAvatar(radius: 16, child: Icon(Icons.person, size: 18)),
    );
  }
}
