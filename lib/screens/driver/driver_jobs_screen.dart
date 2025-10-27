// lib/screens/driver/driver_jobs_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'driver_job_detail_screen.dart';

class DriverJobsScreen extends StatefulWidget {
  const DriverJobsScreen({super.key});
  @override
  State<DriverJobsScreen> createState() => _DriverJobsScreenState();
}

class _DriverJobsScreenState extends State<DriverJobsScreen> {
  final _q = TextEditingController();
  String _status = 'ALL';
  bool _ascending = false;
  String _driverName = '';

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
    final user = FirebaseAuth.instance.currentUser;
    final displayName = user?.displayName ?? '';
    setState(() => _driverName = displayName);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('งานทั้งหมด'),
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        actions: [
          IconButton(
            tooltip: _ascending ? 'เรียงเก่าไปใหม่' : 'เรียงใหม่ไปเก่า',
            onPressed: () => setState(() => _ascending = !_ascending),
            icon: Icon(_ascending ? Icons.arrow_upward : Icons.arrow_downward),
          ),
        ],
      ),
      backgroundColor: Color.lerp(cs.surface, Colors.white, .02),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: _SearchBox(
              controller: _q,
              hint: 'ค้นหา: รหัสงาน / โครงการ / ทะเบียนรถ / ปลายทาง',
              onChanged: (_) => setState(() {}),
              onClear: () => setState(() => _q.clear()),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: _StatusSegmented(
              value: _status,
              onChanged: (v) => setState(() => _status = v),
            ),
          ),
          const SizedBox(height: 8),

          Expanded(
            child: _JobList(
              query: _q.text,
              status: _status,
              ascending: _ascending,
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
  final bool ascending;
  final String driverName;

  const _JobList({
    required this.query,
    required this.status,
    required this.ascending,
    required this.driverName,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('jobs')
          .orderBy('date', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return _EmptyState(
            text: 'เกิดข้อผิดพลาด: ${snapshot.error}',
          );
        }

        final docs = snapshot.data?.docs ?? [];

        // กรองงานของคนขับนี้
        final myJobs = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final drivers = (data['drivers'] as List<dynamic>?) ?? [];
          return drivers.any((driver) => driver.toString().contains(driverName));
        }).toList();

        // ค้นหาและกรองสถานะ
        final filteredJobs = myJobs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          
          // กรองสถานะ
          if (status != 'ALL') {
            final jobStatus = data['status']?.toString() ?? 'pending';
            if (jobStatus != status) return false;
          }
          
          // กรองคำค้นหา
          final searchText = query.trim().toLowerCase();
          if (searchText.isEmpty) return true;
          
          bool contains(String? value) =>
              (value ?? '').toLowerCase().contains(searchText);
          
          return contains(data['code']?.toString()) ||
                 contains(data['project']?.toString()) ||
                 contains(data['plate']?.toString()) ||
                 contains(data['dropLocation']?.toString());
        }).toList();

        // เรียงลำดับ
        filteredJobs.sort((a, b) {
          final dataA = a.data() as Map<String, dynamic>;
          final dataB = b.data() as Map<String, dynamic>;
          final dateA = (dataA['date'] as Timestamp?)?.toDate() ?? DateTime(0);
          final dateB = (dataB['date'] as Timestamp?)?.toDate() ?? DateTime(0);
          
          return ascending 
              ? dateA.compareTo(dateB)
              : dateB.compareTo(dateA);
        });

        return RefreshIndicator(
          onRefresh: () async {
            await Future.delayed(const Duration(milliseconds: 500));
          },
          child: filteredJobs.isEmpty
              ? _EmptyState(
                  text: query.isEmpty
                      ? 'ไม่พบงานในสถานะนี้'
                      : 'ไม่พบผลลัพธ์สำหรับ "$query"',
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  itemBuilder: (_, i) {
                    final doc = filteredJobs[i];
                    final jobData = doc.data() as Map<String, dynamic>;
                    final job = {
                      'id': doc.id,
                      ...jobData,
                      'code': jobData['code'] ?? '',
                      'project': jobData['project'] ?? '',
                      'plate': jobData['plate'] ?? '',
                      'dropLocation': jobData['dropLocation'] ?? '',
                      'status': jobData['status'] ?? 'pending',
                      'trips': (jobData['trips'] as num?)?.toInt() ?? 0,
                      'pricePerTrip': (jobData['pricePerTrip'] as num?)?.toDouble() ?? 0.0,
                      'date': jobData['date'],
                      'drivers': jobData['drivers'] ?? [],
                      'startTime': jobData['startTime'] ?? '',
                      'endTime': jobData['endTime'] ?? '',
                      'fuelBaht': (jobData['fuelBaht'] as num?)?.toDouble() ?? 0.0,
                      'IncomeBaht': (jobData['IncomeBaht'] as num?)?.toDouble() ?? 0.0,
                      'note': jobData['note'] ?? '',
                    };
                    
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
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemCount: filteredJobs.length,
                ),
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

/// ===== แก้เฉพาะ layout ของแถบสถานะ: ไม่ล้น/ไม่ตัดคำ + ย่ออัตโนมัติ =====
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
      // โหมดย่อ: <340 = แสดงข้อความ, <300 = ไอคอนล้วน
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
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          side: MaterialStatePropertyAll(
            BorderSide(color: cs.outlineVariant.withOpacity(.6), width: .9),
          ),
          overlayColor: MaterialStatePropertyAll(cs.primary.withOpacity(.06)),
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
                    Text('${job['project'] ?? '(ไม่มีชื่อโครงการ)'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(
                      '⏰ ${job['startTime'] ?? ''} - ${job['endTime'] ?? ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '🚗 ${job["plate"] ?? "-"} • 📍 ${job["dropLocation"] ?? "-"}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '💰 ${pricePerTrip.toStringAsFixed(0)}฿/เที่ยว • ⛽ ${fuelBaht.toStringAsFixed(0)}฿',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
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
          const Text(
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
  final String text;
  const _EmptyState({required this.text});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 60),
        Icon(Icons.inbox_outlined, size: 56, color: cs.onSurfaceVariant),
        const SizedBox(height: 10),
        Text(text, textAlign: TextAlign.center),
      ],
    );
  }
}
