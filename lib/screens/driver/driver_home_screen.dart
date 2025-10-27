// lib/screens/driver/driver_home_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'driver_job_detail_screen.dart';

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  final TextEditingController _q = TextEditingController();
  String _status = 'ALL';
  String _driverName = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDriverName();
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  void _loadDriverName() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      // ลองหา vehicle โดยใช้ uid
      final vehicleQuery = await FirebaseFirestore.instance
          .collection('vehicles')
          .where('driverUid', isEqualTo: uid)
          .limit(1)
          .get();

      if (vehicleQuery.docs.isNotEmpty) {
        final vehicleData = vehicleQuery.docs.first.data();
        final driverName = vehicleData['driver'] as String? ?? '';
        
        setState(() {
          _driverName = driverName;
          _isLoading = false;
        });
        return;
      }

      // ถ้าไม่เจอด้วย driverUid ลองใช้ displayName
      final user = FirebaseAuth.instance.currentUser;
      final displayName = user?.displayName ?? '';
      
      if (displayName.isNotEmpty) {
        final vehicleQuery2 = await FirebaseFirestore.instance
            .collection('vehicles')
            .where('driver', isEqualTo: displayName)
            .limit(1)
            .get();

        if (vehicleQuery2.docs.isNotEmpty) {
          final vehicleData = vehicleQuery2.docs.first.data();
          final driverName = vehicleData['driver'] as String? ?? '';
          
          setState(() {
            _driverName = driverName;
            _isLoading = false;
          });
          return;
        }
      }

      // Fallback ใช้ displayName
      setState(() {
        _driverName = displayName;
        _isLoading = false;
      });
    } catch (e) {
      print('ERROR: $e');
      final user = FirebaseAuth.instance.currentUser;
      setState(() {
        _driverName = user?.displayName ?? '';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('งานวันนี้')),
        body: const _EmptyState(
          title: 'ยังไม่ได้ล็อกอิน',
          subtitle: 'กรุณาเข้าสู่ระบบก่อนเพื่อดูงานของคุณ',
        ),
      );
    }

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('งานวันนี้')),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('กำลังโหลดข้อมูล...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('งานวันนี้'),
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
      ),
      backgroundColor: Color.lerp(cs.surface, Colors.white, .02),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: _SearchBox(
              controller: _q,
              hint: 'ค้นหา: รหัสงาน / ทะเบียนรถ / ปลายทาง',
              onChanged: (_) => setState(() {}),
              onClear: () => setState(() {
                _q.clear();
              }),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: _StatusSegmented(
              value: _status,
              onChanged: (v) => setState(() => _status = v),
            ),
          ),
          
          if (_driverName.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Icon(Icons.person, size: 16, color: cs.primary),
                  const SizedBox(width: 6),
                  Text(
                    'คนขับ: $_driverName',
                    style: TextStyle(
                      color: cs.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          const SizedBox(height: 4),

          Expanded(
            child: _JobList(
              query: _q.text,
              status: _status,
              driverName: _driverName,
            ),
          ),
        ],
      ),
    );
  }
}

class _JobList extends StatelessWidget {
  final String query;
  final String status;
  final String driverName;

  const _JobList({
    required this.query,
    required this.status,
    required this.driverName,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('jobs')
          .orderBy('date', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return _EmptyState(
            title: 'เกิดข้อผิดพลาด',
            subtitle: '${snap.error}',
          );
        }

        final docs = snap.data?.docs ?? [];

        final raw = docs.map((d) {
          final data = d.data() as Map<String, dynamic>? ?? {};
          return {
            'id': d.id,
            ...data,
            'code': data['code'] ?? '',
            'plate': data['plate'] ?? '',
            'dropLocation': data['dropLocation'] ?? '',
            'status': data['status'] ?? 'pending',
            'trips': (data['trips'] as num?)?.toInt() ?? 0,
            'pricePerTrip': (data['pricePerTrip'] as num?)?.toDouble() ?? 0.0,
            'date': data['date'],
            'drivers': data['drivers'] ?? [],
            'startTime': data['startTime'] ?? '',
            'endTime': data['endTime'] ?? '',
            'fuelBaht': (data['fuelBaht'] as num?)?.toDouble() ?? 0.0,
            'note': data['note'] ?? '',
          };
        }).toList();

        final myJobs = raw.where((job) {
          final drivers = (job['drivers'] as List<dynamic>?) ?? [];
          return drivers.any((driver) => driver.toString().contains(driverName));
        }).toList();

        final now = DateTime.now();
        final todayStart = DateTime(now.year, now.month, now.day);
        final todayEnd = todayStart.add(const Duration(days: 1));
        
        final todayJobs = myJobs.where((job) {
          final jobDate = (job['date'] as Timestamp?)?.toDate();
          return jobDate != null && 
                 jobDate.isAfter(todayStart) && 
                 jobDate.isBefore(todayEnd);
        }).toList();

        final kw = query.trim().toLowerCase();
        final filtered = todayJobs.where((job) {
          if (status != 'ALL' && (job['status'] ?? '') != status) {
            return false;
          }
          if (kw.isEmpty) return true;
          
          bool containsKeyword(String? value) => 
              (value ?? '').toLowerCase().contains(kw);
          
          return containsKeyword(job['code']) ||
                 containsKeyword(job['plate']) ||
                 containsKeyword(job['dropLocation']);
        }).toList();

        if (raw.isEmpty) {
          return const _EmptyState(
            title: 'ไม่พบงานในระบบ',
            subtitle: 'ยังไม่มีงานถูกสร้างในระบบ',
          );
        }

        if (myJobs.isEmpty) {
          return _EmptyState(
            title: 'ยังไม่มีงาน assigned ให้คุณ',
            subtitle: 'ชื่อที่ใช้กรอง: $driverName',
          );
        }

        if (todayJobs.isEmpty && myJobs.isNotEmpty) {
          return _EmptyState(
            title: 'ไม่พบงานวันนี้',
            subtitle: 'แต่คุณมีงานทั้งหมด ${myJobs.length} รายการ',
          );
        }

        if (filtered.isEmpty) {
          return const _EmptyState(
            title: 'ไม่พบงานที่ตรงเงื่อนไข',
            subtitle: 'ลองเปลี่ยนคำค้นหรือเลือกสถานะเป็น "ทั้งหมด"',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          itemCount: filtered.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, index) {
            final job = filtered[index];
            return _JobCard(
              job: job,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DriverJobDetailScreen(job: job),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _SearchBox extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  const _SearchBox({
    required this.controller,
    required this.hint,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(icon: const Icon(Icons.clear), onPressed: onClear),
        isDense: true,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}

/// ===== แก้เฉพาะ layout ของแถบสถานะ: ย่ออัตโนมัติ, ไม่ล้น/ไม่ตัดคำ =====
class _StatusSegmented extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _StatusSegmented({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // ใช้ข้อความไทยสั้น เพื่อไม่ล้น
    final entries = const {
      'ALL': (Icons.dashboard_rounded, 'ทั้งหมด'),
      'pending': (Icons.hourglass_bottom_rounded, 'รอ'),
      'running': (Icons.play_arrow_rounded, 'กำลัง'),
      'completed': (Icons.check_circle_rounded, 'เสร็จ'),
    };

    return LayoutBuilder(builder: (context, c) {
      // ถ้าพื้นที่แคบมาก: < 340 = แสดงข้อความสั้น, < 300 = ไอคอนล้วน
      final showLabel = c.maxWidth >= 340;
      final iconOnly = c.maxWidth < 300;

      return SegmentedButton<String>(
        showSelectedIcon: false,
        selected: {value},
        onSelectionChanged: (s) => onChanged(s.first),
        segments: entries.entries.map((e) {
          final icon = e.value.$1;
          final label = e.value.$2;
          return ButtonSegment<String>(
            value: e.key,
            label: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 16),
                  if (showLabel && !iconOnly) const SizedBox(width: 6),
                  if (showLabel && !iconOnly)
                    Text(label, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          );
        }).toList(),
        style: ButtonStyle(
          padding: const MaterialStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          ),
          visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
          shape: MaterialStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          side: MaterialStatePropertyAll(
            BorderSide(color: cs.outlineVariant.withOpacity(.6), width: .9),
          ),
          backgroundColor: MaterialStateProperty.resolveWith((states) {
            final selected = states.contains(MaterialState.selected);
            return selected ? cs.primary.withOpacity(.12) : Colors.white;
          }),
          foregroundColor: MaterialStateProperty.resolveWith((states) {
            final selected = states.contains(MaterialState.selected);
            return selected ? cs.primary : cs.onSurface;
          }),
        ),
      );
    });
  }
}

class _JobCard extends StatelessWidget {
  final Map<String, dynamic> job;
  final VoidCallback onTap;
  const _JobCard({required this.job, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    
    final trips = (job['trips'] as num? ?? 0).toInt();
    final pricePerTrip = (job['pricePerTrip'] as num?)?.toDouble() ?? 0.0;
    final fuelBaht = (job['fuelBaht'] as num?)?.toDouble() ?? 0.0;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cs.outlineVariant.withOpacity(.35)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.03),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            children: [
              _TripsBadge(trips: trips),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${job['code'] ?? '(ไม่มีรหัสงาน)'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        )),
                    const SizedBox(height: 4),
                    Text(
                      '⏰ ${job['startTime'] ?? ''} - ${job['endTime'] ?? ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: cs.onSurfaceVariant, 
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '🚗 ${job["plate"] ?? "-"} • 📍 ${job["dropLocation"] ?? "-"}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: cs.onSurfaceVariant, 
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '💰 ${pricePerTrip.toStringAsFixed(0)}฿/เที่ยว • ⛽ ${fuelBaht.toStringAsFixed(0)}฿',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: cs.onSurfaceVariant, 
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _StatusChip(status: (job['status'] ?? 'pending') as String),
            ],
          ),
        ),
      ),
    );
  }
}

class _TripsBadge extends StatelessWidget {
  final int trips;
  const _TripsBadge({required this.trips});

  @override
  Widget build(BuildContext context) {
    final color = trips > 0 ? Colors.indigo : Colors.blueGrey;
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [color.withOpacity(.18), color.withOpacity(.10)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [BoxShadow(color: color.withOpacity(.12), blurRadius: 10)],
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$trips',
            style: const TextStyle(
              fontWeight: FontWeight.w900, 
              fontSize: 14,
              color: Colors.black87,
            ),
          ),
          Text(
            'เที่ยว',
            style: TextStyle(
              fontWeight: FontWeight.w500, 
              fontSize: 8,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});
  
  @override
  Widget build(BuildContext context) {
    Color c;
    String displayText;
    IconData icon;
    
    switch (status) {
      case 'pending':
        c = Colors.orange;
        displayText = 'รอ';
        icon = Icons.access_time;
        break;
      case 'running':
        c = Colors.indigo;
        displayText = 'กำลัง';
        icon = Icons.play_arrow;
        break;
      case 'completed':
        c = Colors.green;
        displayText = 'เสร็จ';
        icon = Icons.check;
        break;
      default:
        c = Colors.grey;
        displayText = status;
        icon = Icons.help;
        break;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: c.withOpacity(.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.withOpacity(.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: c),
          const SizedBox(width: 4),
          Text(
            displayText,
            style: TextStyle(
              color: c, 
              fontWeight: FontWeight.w800, 
              fontSize: 11,
              letterSpacing: .3,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String title;
  final String? subtitle;
  const _EmptyState({required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: cs.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18, 
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                textAlign: TextAlign.center, 
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontSize: 14,
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }
}
