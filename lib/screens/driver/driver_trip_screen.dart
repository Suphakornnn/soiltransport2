import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DriverTripScreen extends StatefulWidget {
  final Map<String, dynamic> job;
  final String mode; // 'PICKUP' | 'DROP' | 'RUN'
  const DriverTripScreen({super.key, required this.job, required this.mode});

  @override
  State<DriverTripScreen> createState() => _DriverTripScreenState();
}

class _DriverTripScreenState extends State<DriverTripScreen> {
  final _fmtDt = DateFormat('dd MMM yyyy HH:mm', 'th_TH');

  bool checkedIn = false;
  DateTime? lastActionAt;
  File? photoPickup, photoDrop;

  final _odometerStart = TextEditingController();
  final _odometerEnd = TextEditingController();
  final _fuelLiters = TextEditingController();
  final _volumeThisTrip = TextEditingController(); // ลบ.ม. ของเที่ยวนี้

  int tripsDone = 0;
  num sumVolume = 0;
  num sumRunValue = 0;

  @override
  void initState() {
    super.initState();
    tripsDone = widget.job['tripsDone'];
  }

  @override
  void dispose() {
    _odometerStart.dispose();
    _odometerEnd.dispose();
    _fuelLiters.dispose();
    _volumeThisTrip.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final j = widget.job;
    final pricePerUnit = j['pricePerUnit'] as num;

    return Scaffold(
      appBar: AppBar(title: Text('บันทึกเที่ยว • ${widget.mode}')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _Header(job: j),
          const SizedBox(height: 8),

          // แสดงเวลาล่าสุดด้วย _fmtDt (กำจัด warning)
          if (lastActionAt != null)
            Card(
              child: ListTile(
                leading: const Icon(Icons.access_time),
                title: const Text('เวลาบันทึกล่าสุด'),
                trailing: Text(_fmtDt.format(lastActionAt!),
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(children: [
                    Expanded(child: _Field(controller: _odometerStart, label: 'เลขไมล์เริ่ม (กม.)')),
                    const SizedBox(width: 8),
                    Expanded(child: _Field(controller: _odometerEnd, label: 'เลขไมล์จบ (กม.)')),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: _Field(controller: _fuelLiters, label: 'เติมน้ำมัน (ลิตร)', keyboard: const TextInputType.numberWithOptions(decimal: true))),
                    const SizedBox(width: 8),
                    Expanded(child: _Field(controller: _volumeThisTrip, label: 'ปริมาตรเที่ยวนี้ (ลบ.ม.)', hint: '${j["volumePerTrip"]}')),
                  ]),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: _addTrip,
                    icon: const Icon(Icons.add),
                    label: const Text('เพิ่ม “เที่ยวเสร็จ”'),
                  ),
                  const SizedBox(height: 8),
                  _SummaryTile(
                    trips: tripsDone,
                    volume: sumVolume,
                    runValue: sumRunValue,
                    pricePerUnit: pricePerUnit,
                    // โชว์ timestamp ด้วย _fmtDt
                    timestampText: lastActionAt != null ? _fmtDt.format(lastActionAt!) : null,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.verified_outlined),
              title: const Text('ยืนยันส่งงาน (POD)'),
              subtitle: const Text('อัปโหลดรูป/ลงเวลา/เซ็นชื่อผู้รับงานได้ที่นี่'),
              trailing: FilledButton(
                onPressed: _confirmPOD,
                child: const Text('ยืนยันงาน'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _addTrip() {
    final vol = num.tryParse(_volumeThisTrip.text) ??
        (widget.job['volumePerTrip'] as num);
    setState(() {
      tripsDone += 1;
      sumVolume += vol;
      sumRunValue += vol * (widget.job['pricePerUnit'] as num);
      widget.job['tripsDone'] = tripsDone; // sync กลับ
      lastActionAt = DateTime.now();       // อัปเดตเวลาเพื่อใช้กับ _fmtDt
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('บันทึกเที่ยวแล้ว')),
    );
  }

  void _confirmPOD() {
    final nowTxt = _fmtDt.format(DateTime.now()); // ใช้ _fmtDt ที่นี่ด้วย
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('ยืนยันส่งงาน'),
        content: Text(
          'ยืนยันเมื่อ: $nowTxt\n'
          'เที่ยวรวม: $tripsDone\n'
          'ปริมาตรรวม: ${sumVolume.toStringAsFixed(2)} ลบ.ม.\n'
          'มูลค่ารวม: ฿${sumRunValue.toStringAsFixed(0)}',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('ยกเลิก')),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('ส่งงานสำเร็จ')),
              );
            },
            child: const Text('ยืนยัน'),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final Map<String, dynamic> job;
  const _Header({required this.job});
  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text('${job["project"]}  •  ${job["soilType"]}'),
        subtitle: Text('รถ ${job["plate"]} • คิว/เที่ยว ${job["volumePerTrip"]} • ฿/ลบ.ม. ${job["pricePerUnit"]}'),
        trailing: Chip(label: Text('ทำแล้ว ${job["tripsDone"]}/${job["tripsPlan"]}')),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final TextInputType? keyboard;
  const _Field({required this.controller, required this.label, this.hint, this.keyboard});
  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboard,
      decoration: InputDecoration(labelText: label, hintText: hint),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final int trips;
  final num volume;
  final num runValue;
  final num pricePerUnit;
  final String? timestampText;

  const _SummaryTile({
    required this.trips,
    required this.volume,
    required this.runValue,
    required this.pricePerUnit,
    this.timestampText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.blueGrey.shade100),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(children: [
            Expanded(child: _kpi('เที่ยวสะสม', '$trips เที่ยว')),
            Expanded(child: _kpi('ปริมาตรสะสม', '${volume.toStringAsFixed(2)} ลบ.ม.')),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _kpi('ราคา/ลบ.ม.', '฿${pricePerUnit.toStringAsFixed(0)}')),
            Expanded(child: _kpi('มูลค่าสะสม', '฿${runValue.toStringAsFixed(0)}')),
          ]),
          if (timestampText != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Text('อัปเดต: $timestampText',
                  style: const TextStyle(color: Colors.black54, fontSize: 12)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _kpi(String t, String v) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t, style: const TextStyle(color: Colors.black54, fontSize: 12)),
          const SizedBox(height: 4),
          Text(v, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      );
}
