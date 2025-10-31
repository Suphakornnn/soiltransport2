import 'package:flutter/material.dart';
import 'package:soil_transport_app/services/vehicle_service.dart';

class EditUserScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  EditUserScreen({required this.user});

  @override
  _EditUserScreenState createState() => _EditUserScreenState();
}

class _EditUserScreenState extends State<EditUserScreen> {
  late TextEditingController nameCtrl;
  late TextEditingController plateCtrl;
  late String status;

  @override
  void initState() {
    super.initState();
    nameCtrl = TextEditingController(text: widget.user["name"]);
    plateCtrl = TextEditingController(text: widget.user["plate"]);
    status = widget.user["status"];
    print('');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("แก้ไขผู้ใช้")),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: nameCtrl, decoration: InputDecoration(labelText: "ชื่อ-นามสกุล")),
            TextField(controller: plateCtrl, decoration: InputDecoration(labelText: "ทะเบียนรถ")),
            SizedBox(height: 16),
                        Text('hihi'),
            DropdownButtonFormField<String>(
              value: status,
              items:
                  [
                    "พร้อมใช้งาน",
                    "กำลังซ่อม",
                    "ไม่พร้อมใช้งาน",
                    'กำลังทำงาน',
                  ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (val) {
                setState(() => status = val!);
              },
              decoration: InputDecoration(labelText: "สถานะ"),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                final vehicleId = widget.user["id"];
                if (vehicleId != null) {
                  final _vehicleService = VehicleService();
                  await _vehicleService.updateVehicle(
                    vehicleId: vehicleId,
                    plate: plateCtrl.text,
                    driverName: nameCtrl.text,
                    status: status,
                  );
                  Navigator.pop(context, {
                    "name": nameCtrl.text,
                    "plate": plateCtrl.text,
                    "status": status,
                    "image": widget.user["image"],
                  });
                } else {
                  print('vehicleId is null');
                }
              },
              child: Text("บันทึกการแก้ไข"),
            ),
          ],
        ),
      ),
    );
  }
}
