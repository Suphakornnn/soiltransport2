import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/painting.dart' as painting;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:soil_transport_app/models/job2_model.dart';
import 'package:soil_transport_app/services/job_service.dart';
import 'package:soil_transport_app/utils.dart';

/// ==================
///  Reports Screen (Blue–White theme)
/// ==================
class ReportsScreen extends StatefulWidget {
  ReportsScreen({super.key});
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

/// ---- Blue–White palette ----
const _bgScaffold = Color(0xFFF5F8FF);
const _cardBorder = Color(0xFFE5EAF3);
const _textPrimary = Color(0xFF1F2937);
const _textMuted = Color(0xFF6B7280);
const _blue = Color(0xFF2563EB);
const _blueSoft = Color(0xFFEFF4FF);

class _ReportsScreenState extends State<ReportsScreen> {
  // -------- helper (ไม่ใช้ intl) --------
  final _thaiMonths = const [
    'ม.ค.',
    'ก.พ.',
    'มี.ค.',
    'เม.ย.',
    'พ.ค.',
    'มิ.ย.',
    'ก.ค.',
    'ส.ค.',
    'ก.ย.',
    'ต.ค.',
    'พ.ย.',
    'ธ.ค.',
  ];
  String _thDate(DateTime d) => '${d.day} ${_thaiMonths[d.month - 1]} ${d.year + 543}';
  String _baht(num? v) {
    if (v == null) {
      return '฿0';
    }
    final s = v.toStringAsFixed(0);
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      buf.write(s[i]);
      final pos = s.length - i - 1;
      if (pos % 3 == 0 && pos != 0) buf.write(',');
    }
    return '฿${buf.toString()}';
  }

  // -------- Firestore data --------
  List<Map<String, dynamic>> _reports = [];
  int _currentPage = 1;
  int _itemsPerPage = 6;
  int _totalPages = 1;

  // Summary data
  int _totalJobs = 0;
  int _completedJobs = 0;
  double _totalFuel = 0;
  double _totalIncome = 0;
  int _totalTrips = 0;

  // Daily summary
  int _todayJobs = 0;
  int _todayCompletedJobs = 0;
  double _todayFuel = 0;
  double _todayIncome = 0;

  // Filters
  String _statusFilter = 'ทุกสถานะ';
  String _dateFilter = 'ทุกวัน';
  final _searchCtrl = TextEditingController();
  bool _isLoading = true;
  List<Job2Model> jobs = [];

  @override
  void initState() {
    super.initState();
    _fetchAllData();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchAllData() async {
    setState(() => _isLoading = true);
    await Future.wait([_fetchReportsData(), _fetchSummaryData(), _fetchDailySummary()]);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _fetchReportsData() async {
    try {
      jobs = await MyJob().getAllJobs();

      List<Map<String, dynamic>> reports = [];
      reports.addAll(jobs.map((j) => j.toJson()));

      // search
      if (_searchCtrl.text.isNotEmpty) {
        final q = _searchCtrl.text.toLowerCase();
        reports =
            reports
                .where(
                  (r) =>
                      r['code'].toString().toLowerCase().contains(q) ||
                      r['driver'].toString().toLowerCase().contains(q) ||
                      r['plate'].toString().toLowerCase().contains(q),
                )
                .toList();
      }
      // date filter (ง่ายๆตามตัวเลือก)
      final now = DateTime.now();
      DateTime? from;
      if (_dateFilter == 'วันนี้') {
        from = DateTime(now.year, now.month, now.day);
      } else if (_dateFilter == 'สัปดาห์นี้') {
        from = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
      } else if (_dateFilter == 'เดือนนี้') {
        from = DateTime(now.year, now.month, 1);
      }
      if (from != null) {
        reports = reports.toList();
      }

      // pagination
      _totalPages = (reports.length / _itemsPerPage).ceil();
      if (_totalPages == 0) _totalPages = 1;
      setState(() => _reports = reports);
    } catch (e) {
      // ignore for brevity, สามารถ show Snack ได้
    }
  }

  Future<void> _fetchSummaryData() async {
    try {
      final allJobs = await MyJob().getAllJobs();

      int totalJobs = allJobs.length;
      int completedJobs = 0;
      double totalFuel = 0, totalIncome = 0;
      int totalTrips = 0;

      for (Job2Model job in allJobs) {
        if (job.status == 'done') completedJobs++;
        totalFuel += job.fuelBaht ?? 0;
        totalIncome += job.incomeBaht ?? 0;
        totalTrips += job.trips ?? 0;
      }

      setState(() {
        _totalJobs = totalJobs;
        _completedJobs = completedJobs;
        _totalFuel = totalFuel;
        _totalIncome = totalIncome;
        _totalTrips = totalTrips;
      });
    } catch (_) {}
  }

  Future<void> _fetchDailySummary() async {
    try {
      final allJobs = await MyJob().getAllJobs();
      final today = DateTime.now();
      final start = DateTime(today.year, today.month, today.day);
      final end = DateTime(today.year, today.month, today.day, 23, 59, 59);

      int todayJobs = 0;
      int todayCompletedJobs = 0;
      double todayFuel = 0, todayIncome = 0;

      for (Job2Model job in allJobs) {
        final jobDate = job.date;
        if (jobDate != null && jobDate.isAfter(start) && jobDate.isBefore(end)) {
          todayJobs++;
          if (job.status == 'done') todayCompletedJobs++;
          todayFuel += ((job.fuelBaht ?? 0) as num).toDouble();
          todayIncome += ((job.incomeBaht ?? 0) as num).toDouble();
        }
      }

      setState(() {
        _todayJobs = todayJobs;
        _todayCompletedJobs = todayCompletedJobs;
        _todayFuel = todayFuel;
        _todayIncome = todayIncome;
      });
    } catch (_) {
      _setDefaultDailySummary();
    }
  }

  void _setDefaultDailySummary() {
    setState(() {
      _todayJobs = 0;
      _todayCompletedJobs = 0;
      _todayFuel = 0;
      _todayIncome = 0;
    });
  }

  void _applyFilters() {
    _currentPage = 1;
    _fetchReportsData();
  }

  void _goToPage(int page) {
    setState(() => _currentPage = page);
    _fetchReportsData();
  }

  void _refreshData() => _fetchAllData();

  static const double kJobCardMinHeight = 185;
  static const double kChartHeight = 250;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgScaffold,
      appBar: AppBar(
        title: const Text('รายงานสรุปงานขนส่ง'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _refreshData)],
      ),
      body:
          _isLoading
              ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [CircularProgressIndicator(color: _blue), SizedBox(height: 16), Text('กำลังโหลดข้อมูล...')],
                ),
              )
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    children: [
                      // Top summary
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _topCard(
                            icon: Icons.assignment_outlined,
                            title: 'งานทั้งหมด',
                            value: '$_totalJobs',
                            sub: 'เที่ยวงาน',
                          ),
                          _topCard(
                            icon: Icons.check_circle_rounded,
                            title: 'งานเสร็จสิ้น',
                            value: '$_completedJobs',
                            sub: 'จาก $_totalJobs งาน',
                            iconColor: const Color(0xFF16A34A),
                          ),
                          _topCard(
                            icon: Icons.local_gas_station,
                            title: 'ค่าน้ำมันรวม',
                            value: _baht(_totalFuel),
                            sub: 'ทั้งหมด',
                            iconColor: const Color(0xFFF59E0B),
                          ),
                          _topCard(
                            icon: Icons.trending_up,
                            title: 'รายได้รวม',
                            value: _baht(_totalIncome),
                            sub: '$_totalTrips เที่ยวบรรทุก',
                            iconColor: _blue,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Filters (เดิมเป็น Row → เปลี่ยนเป็น Wrap เพื่อตัดล้นอัตโนมัติ)
                      LayoutBuilder(
                        builder: (context, c) {
                          final maxW = c.maxWidth;
                          final isNarrow = maxW < 700;
                          final half = (maxW - 12) / 2;

                          return Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              SizedBox(
                                width: isNarrow ? maxW : math.min(480.0, maxW - 300),
                                child: TextField(
                                  controller: _searchCtrl,
                                  onChanged: (_) => _applyFilters(),
                                  decoration: InputDecoration(
                                    prefixIcon: const Icon(Icons.search, color: _blue),
                                    hintText: 'ค้นหาทรัพยากร งาน คนขับ หรือทะเบียนรถ...',
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
                              SizedBox(
                                width: isNarrow ? half : 160,
                                child: DropdownButtonFormField<String>(
                                  value: _statusFilter,
                                  items:
                                      const [
                                        'ทุกสถานะ',
                                        'เสร็จสิ้น',
                                        'กำลังดำเนินการ',
                                        'รอดำเนินการ',
                                        'ยกเลิก',
                                      ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                                  onChanged: (v) {
                                    setState(() => _statusFilter = v!);
                                    _applyFilters();
                                  },
                                  decoration: _dropDeco('ทุกสถานะ'),
                                  isDense: true,
                                ),
                              ),
                              SizedBox(
                                width: isNarrow ? half : 120,
                                child: DropdownButtonFormField<String>(
                                  value: _dateFilter,
                                  items:
                                      const [
                                        'ทุกวัน',
                                        'วันนี้',
                                        'สัปดาห์นี้',
                                        'เดือนนี้',
                                      ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                                  onChanged: (v) {
                                    setState(() => _dateFilter = v!);
                                    _applyFilters();
                                  },
                                  decoration: _dropDeco('ทุกวัน'),
                                  isDense: true,
                                ),
                              ),
                              SizedBox(
                                width: isNarrow ? maxW : 160,
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    _statusFilter = 'ทุกสถานะ';
                                    _dateFilter = 'ทุกวัน';
                                    _applyFilters();
                                  },
                                  icon: const Icon(Icons.filter_alt_off, color: _blue, size: 20),
                                  label: const Text(
                                    'ล้างตัวกรอง',
                                    style: TextStyle(color: _blue, fontWeight: FontWeight.w700),
                                  ),
                                  style: OutlinedButton.styleFrom(side: const BorderSide(color: _blue)),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 16),

                      // Job cards + pagination
                      if (_reports.isNotEmpty) ...[
                        LayoutBuilder(
                          builder: (context, c) {
                            final isWide = c.maxWidth > 900;
                            final width = isWide ? (c.maxWidth - 16) / 2 : c.maxWidth;
                            return Wrap(
                              spacing: 16,
                              runSpacing: 16,
                              children: _reports.map((e) => SizedBox(width: width, child: _jobCard(e))).toList(),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildPagination(),
                        const SizedBox(height: 16),
                      ] else
                        _emptyBox(),

                      LayoutBuilder(
                        builder: (context, c) {
                          final isNarrow = c.maxWidth < 700;
                          final w = isNarrow ? c.maxWidth : (c.maxWidth - 16) / 2;
                          return Wrap(
                            spacing: 16,
                            runSpacing: 16,
                            children: [
                              SizedBox(
                                width: w,
                                child: _chartCard(
                                  icon: Icons.pie_chart,
                                  iconColor: Colors.purple,
                                  title: 'สถานะงาน',
                                  child: SizedBox(
                                    height: kChartHeight,
                                    child: _PieChart(
                                      statusMap: {'done': _completedJobs, 'pending': _totalJobs - _completedJobs},
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),

                      const SizedBox(height: 60),
                    ],
                  ),
                ),
              ),
    );
  }

  Widget _buildPagination() => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      IconButton(
        icon: const Icon(Icons.chevron_left),
        onPressed: _currentPage > 1 ? () => _goToPage(_currentPage - 1) : null,
      ),
      for (int i = 1; i <= _totalPages; i++)
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          child: TextButton(
            onPressed: () => _goToPage(i),
            style: TextButton.styleFrom(
              backgroundColor: i == _currentPage ? _blue : Colors.transparent,
              foregroundColor: i == _currentPage ? Colors.white : _blue,
              minimumSize: const Size(36, 36),
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            child: Text('$i'),
          ),
        ),
      IconButton(
        icon: const Icon(Icons.chevron_right),
        onPressed: _currentPage < _totalPages ? () => _goToPage(_currentPage + 1) : null,
      ),
    ],
  );

  // ===== widgets =====
  InputDecoration _dropDeco(String label) => InputDecoration(
    labelText: label,
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
  );

  Widget _panel({required Widget child}) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: _cardBorder),
      borderRadius: BorderRadius.circular(14),
      boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2))],
    ),
    child: child,
  );

  Widget _topCard({
    required IconData icon,
    required String title,
    required String value,
    String? sub,
    Color? iconColor,
  }) {
    return SizedBox(
      width: 280,
      child: _panel(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: (iconColor ?? _blue).withOpacity(.12),
                child: Icon(icon, color: iconColor ?? _blue),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(color: _textMuted)),
                    const SizedBox(height: 3),
                    Text(
                      value,
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: iconColor ?? _textPrimary),
                    ),
                    if (sub != null) ...[
                      const SizedBox(height: 2),
                      Text(sub, style: const TextStyle(color: _textMuted)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chartCard({required IconData icon, required Color iconColor, required String title, required Widget child}) {
    return _panel(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: iconColor),
                const SizedBox(width: 6),
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700, color: _textPrimary)),
              ],
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }

  Widget _jobCard(Map<String, dynamic> e) {
    Color statusColor(String s) {
      switch (s) {
        case 'เสร็จสิ้น':
          return Colors.green;
        case 'กำลังดำเนินการ':
          return Colors.blue;
        case 'รอดำเนินการ':
          return Colors.amber;
        case 'ยกเลิก':
          return Colors.red;
        default:
          return Colors.grey;
      }
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: kJobCardMinHeight),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(e['code'], style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor(e['status']).withOpacity(.12),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Text(e['status'], style: TextStyle(color: statusColor(e['status']))),
                  ),
                  const Spacer(),
                  const Icon(Icons.remove_red_eye_outlined, size: 18),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                '${e['drivers'].join(', ')} • ${e['plate']}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 8),

              // เนื้อหาหลัก
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 6,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.event, size: 18, color: Colors.black54),
                            const SizedBox(width: 6),
                            Text(_thDate(getDateTime(e['date']))),
                            const SizedBox(width: 8),
                            if (e['startTime'] != '—')
                              Text(
                                '${e['startTime']} - ${e['endTime'] ?? ''}',
                                style: const TextStyle(color: Colors.black54),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.place, size: 18, color: Colors.black54),
                            const SizedBox(width: 6),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('จาก: ${e['startLocation'] ?? '-'}', maxLines: 1, overflow: TextOverflow.ellipsis),
                                Text('ไป: ${e['dropLocation'] ?? '-'}', maxLines: 1, overflow: TextOverflow.ellipsis),
                                // Text(
                                //   '${e['distance']} กม. • ${e['unit']}',
                                //   maxLines: 1,
                                //   overflow: TextOverflow.ellipsis,
                                //   style: const TextStyle(color: Colors.black54),
                                // ),
                              ],
                            ),
                            // Expanded(
                            //   child: Column(
                            //     crossAxisAlignment: CrossAxisAlignment.start,
                            //     children: [
                            //       Text('จาก: ${e['startLocation'] ?? '-'}', maxLines: 1, overflow: TextOverflow.ellipsis),
                            //       Text('ไป: ${e['dropLocation'] ?? '-'}', maxLines: 1, overflow: TextOverflow.ellipsis),
                            //       // Text(
                            //       //   '${e['distance']} กม. • ${e['unit']}',
                            //       //   maxLines: 1,
                            //       //   overflow: TextOverflow.ellipsis,
                            //       //   style: const TextStyle(color: Colors.black54),
                            //       // ),
                            //     ],
                            //   ),
                            // ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 4,
                    child: Row(
                      children: [
                        Expanded(
                          child: _metric(
                            'ค่าน้ำมัน',
                            _baht(e['fuelBaht'] != null ? (e['fuelBaht'] as num).toDouble() : null),
                            Colors.orange,
                          ),
                        ),
                        Expanded(
                          child: _metric(
                            'รายได้',
                            _baht(e['IncomeBaht'] != null ? (e['IncomeBaht'] as num).toDouble() : null),
                            Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Text('เที่ยวบรรทุก', style: TextStyle(color: Colors.black54)),
                        const SizedBox(width: 6),
                        Text('${e['trips']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  if ((e['note'] as String).isNotEmpty)
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8)),
                        child: Text(
                          'หมายเหตุ: ${e['note']}',
                          maxLines: 2,
                          softWrap: true,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metric(String title, String value, Color color) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 2),
      Text(title, style: const TextStyle(color: _textMuted)),
      const SizedBox(height: 2),
      Text(value, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: color)),
    ],
  );

  Widget _emptyBox() => Container(
    padding: const EdgeInsets.all(40),
    child: Column(
      children: [
        Icon(Icons.search_off, size: 64, color: _textMuted),
        const SizedBox(height: 16),
        Text('ไม่พบรายงานที่ตรงกับเงื่อนไข', style: TextStyle(color: _textMuted, fontSize: 16)),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _refreshData,
          icon: const Icon(Icons.refresh),
          label: const Text('ลองใหม่อีกครั้ง'),
        ),
      ],
    ),
  );
}

/// ======================
///   Charts (CustomPaint)
/// ======================

class _LineAreaChart extends StatelessWidget {
  final List<double> values; // รวม (เขียว)
  final List<double>? subValues; // ย่อย (น้ำตาล)
  final List<String>? xLabels; // ป้ายวันที่
  const _LineAreaChart({required this.values, this.subValues, this.xLabels});

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _LineAreaPainter(values: values, subValues: subValues, xLabels: xLabels),
    size: const Size(double.infinity, double.infinity),
  );
}

class _LineAreaPainter extends CustomPainter {
  final List<double> values;
  final List<double>? subValues;
  final List<String>? xLabels;
  _LineAreaPainter({required this.values, this.subValues, this.xLabels});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    const padL = 42.0, padB = 26.0, padR = 8.0, padT = 6.0;
    final chartW = size.width - padL - padR;
    final chartH = size.height - padT - padB;
    final origin = Offset(padL, padT);

    final maxMain = values.reduce((a, b) => a > b ? a : b);
    final maxSub = (subValues ?? const [0]).isEmpty ? 0 : subValues!.reduce((a, b) => a > b ? a : b);
    final maxV = (math.max(maxMain, maxSub) * 1.2).clamp(1, 1e12).toDouble();

    final grid =
        Paint()
          ..color = Colors.black12
          ..strokeWidth = 1;
    final tp = painting.TextPainter(textDirection: painting.TextDirection.ltr);

    const rows = 4;
    for (int i = 0; i <= rows; i++) {
      final y = origin.dy + chartH * i / rows;
      canvas.drawLine(Offset(origin.dx, y), Offset(origin.dx + chartW, y), grid);

      final v = (maxV * (rows - i) / rows).round();
      tp.text = painting.TextSpan(
        text: _compactNumber(v),
        style: const painting.TextStyle(fontSize: 11, color: _textMuted),
      );
      tp.layout();
      tp.paint(canvas, Offset(padL - 6 - tp.width, y - tp.height / 2));
    }

    double xAt(int i, int n) => n <= 1 ? origin.dx : origin.dx + chartW * (i / (n - 1));
    double yAt(double v) => origin.dy + chartH - (v / maxV) * chartH;

    // ย่อย
    if (subValues != null && subValues!.isNotEmpty) {
      final list = subValues!;
      final fillBrown =
          Paint()
            ..color = Colors.brown.shade200.withOpacity(.28)
            ..style = PaintingStyle.fill
            ..isAntiAlias = true;
      final lineBrown =
          Paint()
            ..color = Colors.brown.shade400
            ..strokeWidth = 2
            ..style = PaintingStyle.stroke;

      final path = Path();
      final pathFill = Path()..moveTo(origin.dx, origin.dy + chartH);
      for (int i = 0; i < list.length; i++) {
        final px = xAt(i, list.length);
        final py = yAt(list[i]);
        if (i == 0) {
          path.moveTo(px, py);
          pathFill.lineTo(px, py);
        } else {
          path.lineTo(px, py);
          pathFill.lineTo(px, py);
        }
      }
      pathFill
        ..lineTo(origin.dx + chartW, origin.dy + chartH)
        ..close();
      canvas.drawPath(pathFill, fillBrown);
      canvas.drawPath(path, lineBrown);
    }

    // หลัก
    final fillGreen =
        Paint()
          ..shader = const LinearGradient(
            colors: [Color(0xFF81C784), Color(0x3381C784)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ).createShader(Rect.fromLTWH(origin.dx, origin.dy, chartW, chartH))
          ..style = PaintingStyle.fill
          ..isAntiAlias = true;
    final lineGreen =
        Paint()
          ..color = const Color(0xFF2E7D32)
          ..strokeWidth = 2.2
          ..style = PaintingStyle.stroke;

    final pathG = Path();
    final pathFillG = Path()..moveTo(origin.dx, origin.dy + chartH);
    for (int i = 0; i < values.length; i++) {
      final px = xAt(i, values.length);
      final py = yAt(values[i]);
      if (i == 0) {
        pathG.moveTo(px, py);
        pathFillG.lineTo(px, py);
      } else {
        pathG.lineTo(px, py);
        pathFillG.lineTo(px, py);
      }
    }
    pathFillG
      ..lineTo(origin.dx + chartW, origin.dy + chartH)
      ..close();
    canvas.drawPath(pathFillG, fillGreen);
    canvas.drawPath(pathG, lineGreen);

    // ป้ายแกน X — clamp ไม่ให้เกินขอบ
    final labels = xLabels ?? List.generate(values.length, (i) => '${i + 1}');
    for (int i = 0; i < labels.length; i++) {
      final px = xAt(i, labels.length);
      tp.text = painting.TextSpan(text: labels[i], style: const painting.TextStyle(fontSize: 11, color: _textMuted));
      tp.layout();
      final lx = (px - tp.width / 2).clamp(origin.dx, origin.dx + chartW - tp.width);
      tp.paint(canvas, Offset(lx as double, origin.dy + chartH + 6));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _PieChart extends StatelessWidget {
  final Map<String, int> statusMap;
  const _PieChart({required this.statusMap});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 180,
          child: CustomPaint(painter: _PiePainter(statusMap), size: const Size(double.infinity, double.infinity)),
        ),
        const SizedBox(height: 8),
        _PieLegend(statusMap: statusMap),
      ],
    );
  }
}

class _PiePainter extends CustomPainter {
  final Map<String, int> data;
  _PiePainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    final total = data.values.fold<int>(0, (p, e) => p + e);
    if (total == 0) return;

    final rect = Rect.fromLTWH(0, 0, size.width, size.height).deflate(18);
    final center = rect.center;
    final radius = rect.shortestSide / 2;

    const order = ['done', 'pending'];
    final colors = {'done': const Color(0xFF16A34A), 'pending': _blue};

    double startDeg = -90;
    final sectorPaint = Paint()..style = PaintingStyle.fill;
    final tp = painting.TextPainter(textDirection: painting.TextDirection.ltr);

    for (final k in order) {
      if (!data.containsKey(k)) continue;
      final v = data[k]!;
      final sweepDeg = 360 * (v / total);
      if (sweepDeg <= 0) continue;

      sectorPaint.color = (colors[k] ?? Colors.grey);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        _deg(startDeg),
        _deg(sweepDeg),
        true,
        sectorPaint,
      );

      final pct = ((v / total) * 100).round();
      final midDeg = startDeg + sweepDeg / 2;
      final midRad = _deg(midDeg);
      final isBig = sweepDeg >= 40;

      if (isBig) {
        final rIn = radius * 0.55;
        final px = center.dx + rIn * math.cos(midRad);
        final py = center.dy + rIn * math.sin(midRad);

        final txtColor = sectorPaint.color.computeLuminance() < 0.5 ? Colors.white : Colors.black87;

        final shadow = painting.TextPainter(
          textDirection: painting.TextDirection.ltr,
          text: painting.TextSpan(
            text: '$pct%',
            style: painting.TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.black.withOpacity(.25)),
          ),
        )..layout();
        shadow.paint(canvas, Offset(px - shadow.width / 2 + 1, py - shadow.height / 2 + 1));

        tp.text = painting.TextSpan(
          text: '$pct%',
          style: painting.TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: txtColor),
        );
        tp.layout();
        tp.paint(canvas, Offset(px - tp.width / 2, py - tp.height / 2));
      } else {
        final rOuter = radius * 0.95;
        final p1 = Offset(center.dx + rOuter * math.cos(midRad), center.dy + rOuter * math.sin(midRad));
        final p2 = Offset(center.dx + (rOuter + 10) * math.cos(midRad), center.dy + (rOuter + 10) * math.sin(midRad));
        final isRight = math.cos(midRad) >= 0;
        final hLen = 18.0;
        final p3 = p2 + Offset(isRight ? hLen : -hLen, 0);

        final guide =
            Paint()
              ..color = Colors.black26
              ..strokeWidth = 1.2
              ..style = PaintingStyle.stroke;
        final path =
            Path()
              ..moveTo(p1.dx, p1.dy)
              ..lineTo(p2.dx, p2.dy)
              ..lineTo(p3.dx, p3.dy);
        canvas.drawPath(path, guide);

        final label = '$pct%';
        tp.text = painting.TextSpan(
          text: label,
          style: const painting.TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _textPrimary),
        );
        tp.layout();

        const padH = 8.0, padV = 4.0;
        final chipRect = RRect.fromLTRBR(
          isRight ? p3.dx + 4 : p3.dx - tp.width - 4 - 2 * padH,
          p3.dy - tp.height / 2 - padV,
          isRight ? p3.dx + 4 + tp.width + 2 * padH : p3.dx - 4,
          p3.dy + tp.height / 2 + padV,
          const Radius.circular(12),
        );
        final chipPaint = Paint()..color = Colors.white;
        canvas.drawRRect(chipRect, chipPaint);
        canvas.drawRRect(
          chipRect,
          Paint()
            ..color = _cardBorder
            ..style = PaintingStyle.stroke,
        );

        final tx = chipRect.left + padH;
        final ty = chipRect.top + padV;
        tp.paint(canvas, Offset(tx, ty));
      }

      startDeg += sweepDeg;
    }
  }

  double _deg(double d) => d * math.pi / 180;
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _PieLegend extends StatelessWidget {
  final Map<String, int> statusMap;
  const _PieLegend({required this.statusMap});

  @override
  Widget build(BuildContext context) {
    const order = ['done', 'pending'];
    final colors = {'done': const Color(0xFF16A34A), 'pending': _blue};
    final labels = {'done': 'เสร็จสิ้น', 'pending': 'รอดำเนินการ'};

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 18,
      runSpacing: 6,
      children:
          order.where((k) => statusMap.containsKey(k)).map((k) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(color: colors[k], shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text(labels[k]!, style: const TextStyle(fontSize: 12, color: _textPrimary)),
              ],
            );
          }).toList(),
    );
  }
}

class _BarChart extends StatelessWidget {
  final List<_Bar> categories;
  const _BarChart({required this.categories});

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _BarsPainter(categories), size: const Size(double.infinity, double.infinity));
}

class _Bar {
  final String label;
  final double value;
  const _Bar(this.label, this.value);
}

class _BarsPainter extends CustomPainter {
  final List<_Bar> data;
  _BarsPainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    const padL = 36.0, padB = 22.0, padR = 6.0, padT = 6.0;
    final chartW = size.width - padL - padR;
    final chartH = size.height - padT - padB;
    final origin = Offset(padL, padT);

    final maxVal = (data.map((e) => e.value).reduce((a, b) => a > b ? a : b) * 1.2);
    final grid =
        Paint()
          ..color = Colors.black12
          ..strokeWidth = 1;
    final tp = painting.TextPainter(textDirection: painting.TextDirection.ltr);

    const rows = 4;
    for (int i = 0; i <= rows; i++) {
      final y = origin.dy + chartH * i / rows;
      canvas.drawLine(Offset(origin.dx, y), Offset(origin.dx + chartW, y), grid);

      final v = (maxVal * (rows - i) / rows);
      tp.text = painting.TextSpan(
        text: v.round().toString(),
        style: const painting.TextStyle(fontSize: 11, color: _textMuted),
      );
      tp.layout();
      tp.paint(canvas, Offset(padL - 6 - tp.width, y - tp.height / 2));
    }

    final barW = (chartW / (data.length * 2)).clamp(18.0, 70.0);
    final paint = Paint()..color = const Color(0xFFFB923C);

    for (int i = 0; i < data.length; i++) {
      final x = origin.dx + (i * 2 + 0.6) * barW;
      final h = (data[i].value / maxVal) * chartH;
      final r = RRect.fromLTRBR(x, origin.dy + chartH - h, x + barW, origin.dy + chartH - 2, const Radius.circular(6));
      canvas.drawRRect(r, paint);

      // ค่าบนแท่ง
      tp.text = painting.TextSpan(
        text: data[i].value.toInt().toString(),
        style: const painting.TextStyle(fontSize: 11, color: _textPrimary),
      );
      tp.layout();
      final topX = (x + barW / 2 - tp.width / 2).clamp(origin.dx, origin.dx + chartW - tp.width);
      tp.paint(canvas, Offset(topX as double, origin.dy + chartH - h - tp.height - 2));

      // ป้ายชื่อหมวด (clamp ไม่ให้หลุดขอบ)
      tp.text = painting.TextSpan(
        text: data[i].label,
        style: const painting.TextStyle(fontSize: 11, color: _textMuted),
      );
      tp.layout(minWidth: 0, maxWidth: barW * 1.6);
      final labelX = (x - 6).clamp(origin.dx, origin.dx + chartW - tp.width);
      tp.paint(canvas, Offset(labelX as double, origin.dy + chartH + 4));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _PerTruckBars extends StatelessWidget {
  final Map<String, double> data;
  const _PerTruckBars({required this.data});

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _PerTruckBarsPainter(data), size: const Size(double.infinity, double.infinity));
}

class _PerTruckBarsPainter extends CustomPainter {
  final Map<String, double> data;
  _PerTruckBarsPainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    final keys = data.keys.toList();
    final vals = data.values.toList();
    if (keys.isEmpty) return;

    final grid =
        Paint()
          ..color = Colors.black12
          ..strokeWidth = 1;
    for (int i = 1; i <= 3; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(const Offset(60, 0) + Offset(0, y), Offset(size.width, y), grid);
    }
    canvas.drawLine(const Offset(60, 0), Offset(60, size.height), grid);

    final maxV = vals.reduce((a, b) => a > b ? a : b) * 1.2;
    const gap = 10.0;
    final barH = ((size.height - (keys.length + 1) * gap) / keys.length).clamp(10.0, 48.0);
    final paint = Paint()..color = const Color(0xFF607D8B);

    final tp = painting.TextPainter(textDirection: painting.TextDirection.ltr);

    for (int i = 0; i < keys.length; i++) {
      final w = (vals[i] / maxV) * (size.width - 80);
      final top = gap + i * (barH + gap);
      final r = RRect.fromLTRBAndCorners(
        80,
        top,
        80 + w,
        top + barH,
        topRight: const Radius.circular(8),
        bottomRight: const Radius.circular(8),
      );
      canvas.drawRRect(r, paint);

      tp.text = painting.TextSpan(text: keys[i], style: const painting.TextStyle(fontSize: 11, color: _textPrimary));
      tp.layout(maxWidth: 70);
      tp.paint(canvas, Offset(10, top + barH / 2 - tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// ======================
/// Helpers
/// ======================
String _compactNumber(num x) {
  if (x >= 1000000) return '${(x / 1000000).toStringAsFixed(1)}M';
  if (x >= 1000) return '${(x / 1000).toStringAsFixed(1)}k';
  return x.toString();
}
