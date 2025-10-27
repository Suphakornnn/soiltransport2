// lib/screens/driver/driver_job_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class DriverJobDetailScreen extends StatefulWidget {
  final Map<String, dynamic> job;

  const DriverJobDetailScreen({super.key, required this.job});

  @override
  State<DriverJobDetailScreen> createState() => _DriverJobDetailScreenState();
}

class _DriverJobDetailScreenState extends State<DriverJobDetailScreen> {
  late Map<String, dynamic> _job;
  bool _isLoading = false;
  bool _isUpdatingTrips = false;

  @override
  void initState() {
    super.initState();
    _job = Map<String, dynamic>.from(widget.job);
  }

  Future<void> _updateJobStatus(String status) async {
    setState(() => _isLoading = true);
    
    try {
      await FirebaseFirestore.instance
          .collection('jobs')
          .doc(_job['id'])
          .update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        _job['status'] = status;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('อัพเดทสถานะเป็น $status แล้ว')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateTrips(int newTrips) async {
    setState(() => _isUpdatingTrips = true);
    
    try {
      await FirebaseFirestore.instance
          .collection('jobs')
          .doc(_job['id'])
          .update({
        'trips': newTrips,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        _job['trips'] = newTrips;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('อัพเดทจำนวนเที่ยวเป็น $newTrips เที่ยวแล้ว')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
      );
    } finally {
      setState(() => _isUpdatingTrips = false);
    }
  }

  void _showUpdateTripsDialog() {
    final currentTrips = (_job['trips'] as num? ?? 0).toInt();
    final TextEditingController controller = TextEditingController(text: currentTrips.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('อัพเดทจำนวนเที่ยว'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('รหัสงาน: ${_job['code'] ?? 'ไม่มีรหัสงาน'}'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'จำนวนเที่ยว',
                border: OutlineInputBorder(),
                hintText: 'กรอกจำนวนเที่ยว',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () {
              final newTrips = int.tryParse(controller.text) ?? currentTrips;
              if (newTrips >= 0) {
                Navigator.pop(context);
                _updateTrips(newTrips);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('กรุณากรอกจำนวนเที่ยวที่ถูกต้อง')),
                );
              }
            },
            child: const Text('บันทึก'),
          ),
        ],
      ),
    );
  }

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return '-';
    final date = timestamp.toDate();
    return DateFormat('dd/MM/yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    
    final trips = (_job['trips'] as num? ?? 0).toInt();
    final pricePerTrip = (_job['pricePerTrip'] as num?)?.toDouble() ?? 0.0;
    final fuelBaht = (_job['fuelBaht'] as num?)?.toDouble() ?? 0.0;
    final totalIncome = trips * pricePerTrip;
    final netIncome = totalIncome - fuelBaht;

    return Scaffold(
      appBar: AppBar(
        title: const Text('รายละเอียดงาน'),
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        actions: [
          if (_job['status'] == 'pending') ...[
            _isLoading 
                ? const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: CircularProgressIndicator(),
                  )
                : IconButton(
                    icon: const Icon(Icons.play_arrow),
                    onPressed: () => _updateJobStatus('running'),
                    tooltip: 'เริ่มงาน',
                  ),
          ],
          if (_job['status'] == 'running') ...[
            _isLoading 
                ? const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: CircularProgressIndicator(),
                  )
                : IconButton(
                    icon: const Icon(Icons.check),
                    onPressed: () => _updateJobStatus('completed'),
                    tooltip: 'เสร็จสิ้นงาน',
                  ),
          ],
        ],
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Header Section
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'รหัสงาน',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _job['code'] ?? 'ไม่มีรหัสงาน',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _StatusChip(status: _job['status'] ?? 'pending'),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_job['project'] != null && _job['project'].toString().isNotEmpty)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'โครงการ',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _job['project'].toString(),
                              style: TextStyle(
                                fontSize: 16,
                                color: cs.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Basic Information
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ข้อมูลพื้นฐาน',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _InfoRow(
                        icon: Icons.date_range,
                        label: 'วันที่',
                        value: _formatDate(_job['date'] as Timestamp?),
                      ),
                      _InfoRow(
                        icon: Icons.access_time,
                        label: 'เวลา',
                        value: '${_job['startTime'] ?? ''} - ${_job['endTime'] ?? ''}',
                      ),
                      _InfoRow(
                        icon: Icons.directions_car,
                        label: 'ทะเบียนรถ',
                        value: _job['plate'] ?? '-',
                      ),
                      _InfoRow(
                        icon: Icons.location_on,
                        label: 'ปลายทาง',
                        value: _job['dropLocation'] ?? '-',
                      ),
                      _InfoRow(
                        icon: Icons.repeat,
                        label: 'จำนวนเที่ยว',
                        value: '$trips เที่ยว',
                      ),
                      _InfoRow(
                        icon: Icons.people,
                        label: 'คนขับ',
                        value: (_job['drivers'] as List<dynamic>?)?.join(', ') ?? '-',
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Financial Information
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ข้อมูลการเงิน',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _InfoRow(
                        icon: Icons.attach_money,
                        label: 'ราคาต่อเที่ยว',
                        value: '${pricePerTrip.toStringAsFixed(0)} ฿',
                      ),
                      _InfoRow(
                        icon: Icons.local_gas_station,
                        label: 'ค่าน้ำมัน',
                        value: '${fuelBaht.toStringAsFixed(0)} ฿',
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Update Trips Button
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'จัดการจำนวนเที่ยว',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _isUpdatingTrips
                          ? const Center(child: CircularProgressIndicator())
                          : ElevatedButton.icon(
                              onPressed: _showUpdateTripsDialog,
                              icon: const Icon(Icons.add_circle_outline),
                              label: const Text('อัพเดทจำนวนเที่ยว'),
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size(double.infinity, 50),
                                backgroundColor: cs.primary,
                                foregroundColor: cs.onPrimary,
                              ),
                            ),
                      const SizedBox(height: 8),
                      Text(
                        'จำนวนเที่ยวปัจจุบัน: $trips เที่ยว',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Income Summary
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'สรุปรายได้',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _IncomeRow(
                        label: 'รายได้รวม ($trips เที่ยว)',
                        value: totalIncome,
                      ),
                      _IncomeRow(
                        label: 'หักค่าน้ำมัน',
                        value: -fuelBaht,
                        isNegative: true,
                      ),
                      const Divider(height: 20),
                      _IncomeRow(
                        label: 'รายได้สุทธิ',
                        value: netIncome,
                        isTotal: true,
                      ),
                    ],
                  ),
                ),

                // Note Section
                if (_job['note'] != null && _job['note'].toString().isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'หมายเหตุ',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _job['note'].toString(),
                          style: TextStyle(
                            fontSize: 14,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 32),
              ],
            ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: Colors.grey[600],
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w400,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

class _IncomeRow extends StatelessWidget {
  final String label;
  final double value;
  final bool isNegative;
  final bool isTotal;

  const _IncomeRow({
    required this.label,
    required this.value,
    this.isNegative = false,
    this.isTotal = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    
    Color color = isTotal ? cs.primary : Colors.grey[800]!;
    if (isNegative) color = Colors.red;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 15 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: color,
            ),
          ),
          Text(
            '${value.toStringAsFixed(0)} ฿',
            style: TextStyle(
              fontSize: isTotal ? 15 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: color,
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
        displayText = 'รอเริ่มงาน';
        icon = Icons.access_time;
        break;
      case 'running':
        c = Colors.indigo;
        displayText = 'กำลังทำงาน';
        icon = Icons.play_arrow;
        break;
      case 'completed':
        c = Colors.green;
        displayText = 'เสร็จสิ้น';
        icon = Icons.check;
        break;
      default:
        c = Colors.grey;
        displayText = status;
        icon = Icons.help;
        break;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: c.withOpacity(.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.withOpacity(.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: c),
          const SizedBox(width: 6),
          Text(
            displayText,
            style: TextStyle(
              color: c, 
              fontWeight: FontWeight.w800, 
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}