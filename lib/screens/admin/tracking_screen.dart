// lib/screens/admin/tracking_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ===== OpenStreetMap =====
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;

/// ===== Blue–White Theme colors =====
const _bgScaffold = Color(0xFFF5F8FF);
const _cardBorder = Color(0xFFE5EAF3);
const _textPrimary = Color(0xFF1F2937);
const _textMuted = Color(0xFF6B7280);
const _blue = Color(0xFF2563EB);
const _blueSoft = Color(0xFFEFF4FF);

class TrackingScreen extends StatefulWidget {
  const TrackingScreen({super.key});
  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen>
    with TickerProviderStateMixin {
  // --------------- UI States ----------------
  int _tab = 0; // 0=แผนที่, 1=รายการ
  String _search = '';
  VStatus? _filterStatus; // null = ทุกสถานะ
  DateTime _lastRefresh = DateTime.now();

  // --------------- OSM Map State ----------------
  final MapController _mapCtl = MapController();
  final _initialCenter = const ll.LatLng(13.736717, 100.523186); // กรุงเทพ
  final double _initialZoom = 11.5;

  // --------------- Animated marker states ----------------
  // พิกัดที่กำลัง "แสดงบนแผนที่" (interpolated) ต่อคัน
  final Map<String, ll.LatLng> _animPos = {};
  // Controller ต่อคัน (เพื่ออนิเมตจากพิกัดเก่า -> ใหม่)
  final Map<String, AnimationController> _controllers = {};
  // Tween lat/lng ต่อคัน
  final Map<String, Tween<double>> _tweenLat = {};
  final Map<String, Tween<double>> _tweenLng = {};
  final Duration _moveDuration = const Duration(milliseconds: 900);

  // --------------- Helpers ----------------
  String _fmtTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  String _ago(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inMinutes < 1) return 'เมื่อสักครู่';
    if (d.inMinutes < 60) return '${d.inMinutes} นาทีที่แล้ว';
    return '${d.inHours} ชม.ที่แล้ว';
  }

  Color _statusColor(VStatus s) {
    switch (s) {
      case VStatus.working:
        return const Color(0xFF16A34A);
      case VStatus.ready:
        return const Color(0xFFF59E0B);
      case VStatus.repair:
        return const Color(0xFFDC2626);
      case VStatus.offline:
        return const Color(0xFF64748B);
    }
  }

  String _statusText(VStatus s) {
    switch (s) {
      case VStatus.working:
        return 'กำลังทำงาน';
      case VStatus.ready:
        return 'พร้อมงาน';
      case VStatus.repair:
        return 'ซ่อมบำรุง';
      case VStatus.offline:
        return 'ออฟไลน์';
    }
  }

  // Firestore status string -> enum
  VStatus _statusFromString(String? s) {
    switch (s) {
      case 'working':
      case 'กำลังทำงาน':
        return VStatus.working;
      case 'ready':
      case 'พร้อมงาน':
        return VStatus.ready;
      case 'repair':
      case 'ซ่อมบำรุง':
        return VStatus.repair;
      case 'offline':
      case 'ออฟไลน์':
      default:
        return VStatus.offline;
    }
  }

  void _doRefresh() => setState(() => _lastRefresh = DateTime.now());

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgScaffold,
      appBar: AppBar(
        title: const Text('การติดตามรถยนต์'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: _blue,
                foregroundColor: Colors.white,
              ),
              onPressed: _doRefresh,
              icon: const Icon(Icons.refresh),
              label: const Text('รีเฟรช'),
            ),
          )
        ],
      ),

      // ===== ใช้สตรีมเดียว ขับทั้งสรุป/แผนที่/รายการ =====
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('vehicles').snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snap.hasError) {
            return Center(child: Text('เกิดข้อผิดพลาด: ${snap.error}'));
          }

          final docs = (snap.data?.docs ?? []).map((d) {
            final m = (d.data() as Map<String, dynamic>? ?? {});

            // ป้องกัน lat/lng null/NaN
            double? lat;
            double? lng;
            final latData = m['lat'];
            final lngData = m['lng'];
            if (latData is num && latData.isFinite) lat = latData.toDouble();
            if (lngData is num && lngData.isFinite) lng = lngData.toDouble();

            return _VehicleRow(
              id: d.id,
              plate: (m['plate'] ??
                      m['licensePlate'] ??
                      m['vehiclePlate'] ??
                      '')
                  .toString(),
              driver: (m['driver'] ?? m['driverName'] ?? '').toString(),
              status: _statusFromString(m['status'] as String?),
              lat: lat,
              lng: lng,
              speedKmh: (m['speedKmh'] as num?)?.toInt(),
              updatedAt: (m['updatedAt'] is Timestamp)
                  ? (m['updatedAt'] as Timestamp).toDate()
                  : (m['lastUpdate'] is Timestamp)
                      ? (m['lastUpdate'] as Timestamp).toDate()
                      : null,
              extra: m,
            );
          }).toList();

          // กรองตาม Search/Status
          final q = _search.trim().toLowerCase();
          List<_VehicleRow> filtered = docs.where((v) {
            final mq = q.isEmpty ||
                v.plate.toLowerCase().contains(q) ||
                v.driver.toLowerCase().contains(q);
            final ms = _filterStatus == null || v.status == _filterStatus;
            return mq && ms;
          }).toList();

          // ==== จุดสำคัญ: อัปเดตตำแหน่งแบบอนิเมต ====
          _applyAnimatedPositions(filtered);

          // นับสถานะ
          final countWorking =
              docs.where((v) => v.status == VStatus.working).length;
          final countReady =
              docs.where((v) => v.status == VStatus.ready).length;
          final countRepair =
              docs.where((v) => v.status == VStatus.repair).length;
          final countOffline =
              docs.where((v) => v.status == VStatus.offline).length;

          return RefreshIndicator(
            onRefresh: () async => _doRefresh(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('อัปเดตล่าสุด: ${_fmtTime(_lastRefresh)}',
                      style: const TextStyle(color: _textMuted, fontSize: 12)),
                  const SizedBox(height: 8),

                  // ----- summary cards -----
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _summaryCard('กำลังทำงาน', countWorking,
                          _statusColor(VStatus.working)),
                      _summaryCard('พร้อมงาน', countReady,
                          _statusColor(VStatus.ready)),
                      _summaryCard('ซ่อมบำรุง', countRepair,
                          _statusColor(VStatus.repair)),
                      _summaryCard('ออฟไลน์', countOffline,
                          _statusColor(VStatus.offline)),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ----- segmented tabs -----
                  Row(
                    children: [
                      _segBtn(
                          label: 'แผนที่',
                          selected: _tab == 0,
                          onTap: () => setState(() => _tab = 0)),
                      const SizedBox(width: 8),
                      _segBtn(
                          label: 'รายการ',
                          selected: _tab == 1,
                          onTap: () => setState(() => _tab = 1)),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (_tab == 0)
                    _mapTab(filtered)
                  else
                    _listTab(filtered),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // =========================================================
  // ============ Animated positions (หัวใจของงาน) ===========
  // =========================================================
  void _applyAnimatedPositions(List<_VehicleRow> vehicles) {
    final currentIds = vehicles.map((e) => e.id).toSet();

    // 1) อัปเดต/เริ่มอนิเมชันสำหรับคันที่มีพิกัด
    for (final v in vehicles) {
      if (v.lat == null || v.lng == null) continue;
      final id = v.id;
      final target = ll.LatLng(v.lat!, v.lng!);

      // ถ้ายังไม่เคยมีตำแหน่ง -> ตั้งต้นเลย
      _animPos.putIfAbsent(id, () => target);

      final cur = _animPos[id]!;
      final moved = (cur.latitude != target.latitude) ||
          (cur.longitude != target.longitude);
      if (!moved) continue;

      // สร้าง/รีเซ็ต controller
      _controllers[id]?.dispose();
      final ctrl =
          AnimationController(vsync: this, duration: _moveDuration);
      final curved = CurvedAnimation(
        parent: ctrl,
        curve: Curves.easeInOut,
      );
      _controllers[id] = ctrl;

      // เตรียม tween
      _tweenLat[id] = Tween(begin: cur.latitude, end: target.latitude);
      _tweenLng[id] = Tween(begin: cur.longitude, end: target.longitude);

      // ระหว่างอนิเมชัน อัปเดตตำแหน่งและรีเฟรชจอ
      curved.addListener(() {
        final t = curved.value;
        _animPos[id] = ll.LatLng(
          _tweenLat[id]!.transform(t),
          _tweenLng[id]!.transform(t),
        );
        if (mounted) setState(() {});
      });

      curved.addStatusListener((st) {
        if (st == AnimationStatus.completed) {
          // ล็อคค่าจบให้ตรงเป๊ะ
          _animPos[id] = target;
        }
      });

      ctrl.forward();
    }

    // 2) ลบคันที่หายไป (cleanup)
    final removed = _controllers.keys.where((k) => !currentIds.contains(k)).toList();
    for (final id in removed) {
      _controllers[id]?.dispose();
      _controllers.remove(id);
      _animPos.remove(id);
      _tweenLat.remove(id);
      _tweenLng.remove(id);
    }
  }

  // ---------------- Sections ----------------

  /// แผนที่อ่านตำแหน่งสดจาก Firestore (OSM ด้วย flutter_map)
  Widget _mapTab(List<_VehicleRow> vehicles) {
    // markers จากตำแหน่ง "อนิเมตแล้ว"
    final markers = <Marker>[];
    for (final v in vehicles) {
      if (v.lat == null || v.lng == null) continue;

      final pos = _animPos[v.id] ?? ll.LatLng(v.lat!, v.lng!);
      if (!pos.latitude.isFinite || !pos.longitude.isFinite) continue;

      final color = _statusColor(v.status);

      markers.add(
        Marker(
          point: pos,
          width: 40,
          height: 40,
          child: GestureDetector(
            onTap: () {
              _mapCtl.move(pos, 14);
              showModalBottomSheet(
                context: context,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                builder: (_) => Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                                color: color, shape: BoxShape.circle)),
                        const SizedBox(width: 8),
                        Text('${v.plate} • ${_statusText(v.status)}',
                            style:
                                const TextStyle(fontWeight: FontWeight.w800)),
                      ]),
                      const SizedBox(height: 6),
                      Text('คนขับ: ${v.driver}',
                          style: const TextStyle(color: _textPrimary)),
                      if (v.speedKmh != null)
                        Text('ความเร็ว: ${v.speedKmh} กม./ชม.',
                            style: const TextStyle(color: _textMuted)),
                      if (v.updatedAt != null)
                        Text('อัปเดต: ${_ago(v.updatedAt!)}',
                            style: const TextStyle(color: _textMuted)),
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                          label: const Text('ปิด'),
                        ),
                      )
                    ],
                  ),
                ),
              );
            },
            child: _Dot(color: color),
          ),
        ),
      );
    }

    return _card(
      title: 'แผนที่ติดตามรถยนต์ (OpenStreetMap)',
      icon: Icons.map_outlined,
      child: SizedBox(
        height: 360,
        child: FlutterMap(
          mapController: _mapCtl,
          options: MapOptions(
            initialCenter: _initialCenter,
            initialZoom: _initialZoom,
            interactionOptions: const InteractionOptions(
              flags: ~InteractiveFlag.rotate,
            ),
            onMapReady: () {
              if (markers.isNotEmpty) _fitAll(markers);
            },
          ),
          children: [
            TileLayer(
              urlTemplate:
                  "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
              subdomains: const ['a', 'b', 'c'],
              userAgentPackageName: 'com.example.soil_transport_app',
            ),
            MarkerLayer(markers: markers),
          ],
        ),
      ),
    );
  }

  void _fitAll(List<Marker> markers) {
    if (markers.isEmpty) return;

    final valid = markers.where((m) {
      final lat = m.point.latitude;
      final lng = m.point.longitude;
      return lat.isFinite && lng.isFinite;
    }).toList();
    if (valid.isEmpty) return;

    if (valid.length == 1) {
      final p = valid.first.point;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mapCtl.move(ll.LatLng(p.latitude, p.longitude), 14);
      });
      return;
    }

    double minLat = valid.first.point.latitude;
    double maxLat = valid.first.point.latitude;
    double minLng = valid.first.point.longitude;
    double maxLng = valid.first.point.longitude;

    for (final m in valid) {
      final lat = m.point.latitude;
      final lng = m.point.longitude;
      if (lat < minLat) minLat = lat;
      if (lat > maxLat) maxLat = lat;
      if (lng < minLng) minLng = lng;
      if (lng > maxLng) maxLng = lng;
    }

    if (!minLat.isFinite ||
        !maxLat.isFinite ||
        !minLng.isFinite ||
        !maxLng.isFinite) return;

    final bounds = LatLngBounds(
      ll.LatLng(minLat, minLng),
      ll.LatLng(maxLat, maxLng),
    );

    _mapCtl.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(60),
      ),
    );
  }

  Widget _listTab(List<_VehicleRow> vehicles) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search + filter
        Row(
          children: [
            Expanded(
              child: TextField(
                onChanged: (v) => setState(() => _search = v),
                decoration: InputDecoration(
                  isDense: true,
                  prefixIcon: const Icon(Icons.search, color: _blue),
                  hintText: 'ค้นหาตามทะเบียนรถ คนขับ หรือข้อความ…',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _cardBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _blue, width: 1.4),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 160,
              child: DropdownButtonFormField<VStatus?>(
                value: _filterStatus,
                isDense: true,
                items: const [
                  DropdownMenuItem(value: null, child: Text('ทุกสถานะ')),
                  DropdownMenuItem(
                      value: VStatus.working, child: Text('กำลังทำงาน')),
                  DropdownMenuItem(
                      value: VStatus.ready, child: Text('พร้อมงาน')),
                  DropdownMenuItem(
                      value: VStatus.repair, child: Text('ซ่อมบำรุง')),
                  DropdownMenuItem(
                      value: VStatus.offline, child: Text('ออฟไลน์')),
                ],
                onChanged: (v) => setState(() => _filterStatus = v),
                decoration: InputDecoration(
                  labelText: 'สถานะ',
                  isDense: true,
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _cardBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _blue, width: 1.4),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // ==== รายการจาก Firestore ====
        if (vehicles.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: _cardBorder),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text('ยังไม่พบรถที่ตรงกับเงื่อนไข',
                style: TextStyle(color: _textMuted)),
          )
        else
          ...vehicles.map((v) => _vehicleCardFromRow(v)).toList(),
      ],
    );
  }

  // ---------------- Small Builders ----------------

  Widget _summaryCard(String title, int num, Color dotColor) {
    return SizedBox(
      width: 170,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: _cardBorder),
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2))
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                  width: 10,
                  height: 10,
                  decoration:
                      BoxDecoration(color: dotColor, shape: BoxShape.circle)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$num',
                        style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                            color: _textPrimary)),
                    Text(title, style: const TextStyle(color: _textMuted)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _segBtn(
      {required String label,
      required bool selected,
      required VoidCallback onTap}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? _blue : _blueSoft,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? _blue : _cardBorder),
            boxShadow: selected
                ? [
                    BoxShadow(
                        color: _blue.withOpacity(.25),
                        blurRadius: 10,
                        offset: const Offset(0, 2))
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : _textPrimary),
          ),
        ),
      ),
    );
  }

  Widget _card(
      {required String title,
      required IconData icon,
      required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _cardBorder),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2))
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, size: 18, color: _blue),
              const SizedBox(width: 6),
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, color: _textPrimary)),
            ]),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  Widget _vehicleCardFromRow(_VehicleRow v) {
    final now = v.updatedAt ?? DateTime.now();
    final speedText = (v.speedKmh == null) ? '-' : '${v.speedKmh} กม./ชม.';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _cardBorder),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2))
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // header
            Row(
              children: [
                Text(v.plate.isEmpty ? v.id : v.plate,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: _textPrimary)),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _statusColor(v.status).withOpacity(.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: _statusColor(v.status).withOpacity(.25)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                            color: _statusColor(v.status),
                            shape: BoxShape.circle),
                      ),
                      Text(_statusText(v.status),
                          style: TextStyle(
                              color: _statusColor(v.status),
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(v.driver,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, color: _textPrimary)),
            Row(
              children: [
                const Icon(Icons.access_time, size: 16, color: _textMuted),
                const SizedBox(width: 6),
                Text('อัปเดต: ${_fmtTime(now)}  (${_ago(now)})',
                    style: const TextStyle(color: _textMuted)),
              ],
            ),
            const SizedBox(height: 8),

            _infoRow(icon: Icons.navigation, label: 'ความเร็ว', value: speedText),
            if (_animPos[v.id] != null)
              _infoRow(
                  icon: Icons.place,
                  label: 'ตำแหน่ง',
                  value:
                      '${_animPos[v.id]!.latitude.toStringAsFixed(4)}, ${_animPos[v.id]!.longitude.toStringAsFixed(4)}'),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(
      {required IconData icon,
      required String label,
      required String value}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 18, color: _textMuted),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: _textMuted)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, color: _textPrimary)),
          ),
        ],
      ),
    );
  }
}

// ---------------- Models (internal row) ----------------
enum VStatus { working, ready, repair, offline }

class _VehicleRow {
  final String id;
  final String plate;
  final String driver;
  final VStatus status;
  final double? lat;
  final double? lng;
  final int? speedKmh;
  final DateTime? updatedAt;
  final Map<String, dynamic> extra;

  _VehicleRow({
    required this.id,
    required this.plate,
    required this.driver,
    required this.status,
    required this.lat,
    required this.lng,
    required this.speedKmh,
    required this.updatedAt,
    required this.extra,
  });
}

/// จุดบนแผนที่แบบเรียบง่าย (สีตามสถานะจริง)
class _Dot extends StatelessWidget {
  final Color color;
  final double size;
  const _Dot({required this.color, this.size = 14});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(.15),     // วงนอก = สีสถานะจาง ๆ
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,                    // วงใน = สีสถานะจริง (ไม่ใช่ Colors.green)
          shape: BoxShape.circle,
          boxShadow: const [
            BoxShadow(blurRadius: 6, spreadRadius: 1, offset: Offset(0, 2)),
          ],
        ),
      ),
    );
  }
}

