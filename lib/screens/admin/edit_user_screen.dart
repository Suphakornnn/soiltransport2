import 'package:flutter/material.dart';

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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("แก้ไขผู้ใช้")),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(labelText: "ชื่อ-นามสกุล"),
            ),
            TextField(
              controller: plateCtrl,
              decoration: InputDecoration(labelText: "ทะเบียนรถ"),
            ),
            SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: status,
              items: ["พร้อมใช้งาน", "กำลังซ่อม", "ไม่พร้อมใช้งาน"]
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (val) {
                setState(() => status = val!);
              },
              decoration: InputDecoration(labelText: "สถานะ"),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // ตรงนี้ถ้าใช้ Firebase ต้องอัปเดต Firestore
                Navigator.pop(context, {
                  "name": nameCtrl.text,
                  "plate": plateCtrl.text,
                  "status": status,
                  "image": widget.user["image"],
                });
              },
              child: Text("บันทึกการแก้ไข"),
            ),
          ],
        ),
      ),
    );
  }
}
