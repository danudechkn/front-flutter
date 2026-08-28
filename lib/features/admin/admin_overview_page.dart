import 'dart:async';
import 'package:flutter/material.dart';
import '../nurse_queue/nurse_queue_api.dart';
import '../nurse_queue/request_detail_page.dart';
import '../bed_qr/bed_qr_management_page.dart';

class AdminOverviewPage extends StatefulWidget {
  const AdminOverviewPage({super.key});

  @override
  State<AdminOverviewPage> createState() => _AdminOverviewPageState();
}

class _AdminOverviewPageState extends State<AdminOverviewPage> {
  static const Color _primaryTeal = Color(0xFF166568);
  static const Color _bgGray = Color(0xFFF4F6F8);

  List<Map<String, dynamic>> _wards = [];
  Map<String, dynamic>? _selectedWard;

  List<Map<String, dynamic>> _pendingRequests = [];
  List<dynamic> _beds = [];

  bool _isLoadingWards = true;
  bool _isLoadingRequests = false;
  bool _isLoadingBeds = false;

  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _fetchWards();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) => _fetchAll());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchWards() async {
    setState(() => _isLoadingWards = true);
    try {
      final wards = await NurseQueueApi.fetchWards();
      setState(() {
        _wards = wards;
        if (wards.isNotEmpty) {
          _selectedWard = wards.first;
        }
      });
      await _fetchAll();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('โหลดข้อมูลไม่ได้: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoadingWards = false);
    }
  }

  Future<void> _fetchAll() async {
    await Future.wait([_fetchRequests(), _fetchBeds()]);
  }

  Future<void> _fetchRequests() async {
    if (_selectedWard == null) return;
    setState(() => _isLoadingRequests = true);
    try {
      final locationId = _selectedWard!['locationid'] as int;
      final all = await NurseQueueApi.fetchHelpRequests(locationId);
      // Show only active (not resolved/cancelled)
      final pending = all.where((r) {
        final s = r['status'] ?? '';
        return s == HelpRequestStatus.newRequest ||
            s == HelpRequestStatus.acknowledged ||
            s == HelpRequestStatus.inProgress;
      }).toList();
      pending.sort((a, b) {
        final ua = a['type'] == 'PAIN' ? 0 : 1;
        final ub = b['type'] == 'PAIN' ? 0 : 1;
        if (ua != ub) return ua.compareTo(ub);
        return (a['created_at'] ?? '').compareTo(b['created_at'] ?? '');
      });
      setState(() => _pendingRequests = pending);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoadingRequests = false);
    }
  }

  Future<void> _fetchBeds() async {
    if (_selectedWard == null) return;
    setState(() => _isLoadingBeds = true);
    try {
      final locationId = _selectedWard!['locationid'];
      final data = await BedQrApi.fetchBeds(locationId);
      setState(() => _beds = data);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoadingBeds = false);
    }
  }

  String _wardName(Map<String, dynamic> ward) {
    final loc = ward['location'];
    if (loc is Map) {
      return loc['detailtext'] ?? loc['shortname'] ?? 'หอ ${ward['locationid']}';
    }
    return 'หอ ${ward['locationid']}';
  }

  String _formatTime(String? isoString) {
    if (isoString == null) return '-';
    try {
      final dt = DateTime.parse(isoString).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'เมื่อกี้';
      if (diff.inMinutes < 60) return '${diff.inMinutes} นาทีที่แล้ว';
      return '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
    } catch (_) { return '-'; }
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'PAIN': return const Color(0xFFE53E3E);
      case 'TOILET': return const Color(0xFF2B6CB0);
      case 'MEDICATION_QUESTION': return const Color(0xFF276749);
      default: return const Color(0xFF553C9A);
    }
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'PAIN': return 'ปวด / ไม่สบาย';
      case 'TOILET': return 'ต้องการเข้าห้องน้ำ';
      case 'MEDICATION_QUESTION': return 'สอบถามเรื่องยา';
      case 'OTHER': return 'อื่นๆ';
      default: return type;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case HelpRequestStatus.newRequest: return 'รอรับเรื่อง';
      case HelpRequestStatus.acknowledged: return 'รับเรื่องแล้ว';
      case HelpRequestStatus.inProgress: return 'กำลังดำเนินการ';
      default: return status;
    }
  }

  Color _statusBgColor(String status) {
    switch (status) {
      case HelpRequestStatus.newRequest: return const Color(0xFFFFF3CD);
      case HelpRequestStatus.acknowledged: return const Color(0xFFFFE0CC);
      case HelpRequestStatus.inProgress: return const Color(0xFFCCE5FF);
      default: return const Color(0xFFE2E8F0);
    }
  }

  Color _statusTextColor(String status) {
    switch (status) {
      case HelpRequestStatus.newRequest: return const Color(0xFF856404);
      case HelpRequestStatus.acknowledged: return const Color(0xFF7B3D00);
      case HelpRequestStatus.inProgress: return const Color(0xFF004085);
      default: return const Color(0xFF4A5568);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingWards) {
      return const Center(child: CircularProgressIndicator());
    }

    final occupiedBeds = _beds.where((b) => b['ipd_reg']?['patient'] != null).length;
    final totalBeds = _beds.length;
    final now = DateTime.now();
    final dateStr = '${now.day} ${_monthThai(now.month)} · อัปเดตเมื่อ ${now.hour.toString().padLeft(2,'0')}:${now.minute.toString().padLeft(2,'0')} น.';

    return Container(
      color: _bgGray,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Top header bar ──────────────────────────────────────
          Container(
            color: _primaryTeal,
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'ภาพรวมหอผู้ป่วย',
                            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 12),
                          // Ward selector
                          if (_wards.length > 1)
                            DropdownButtonHideUnderline(
                              child: DropdownButton<Map<String, dynamic>>(
                                value: _selectedWard,
                                dropdownColor: const Color(0xFF0D4A4D),
                                style: const TextStyle(color: Colors.white, fontSize: 14),
                                icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white70),
                                items: _wards
                                    .map((w) => DropdownMenuItem(
                                          value: w,
                                          child: Text(_wardName(w), style: const TextStyle(color: Colors.white)),
                                        ))
                                    .toList(),
                                onChanged: (w) {
                                  setState(() {
                                    _selectedWard = w;
                                    _pendingRequests = [];
                                    _beds = [];
                                  });
                                  _fetchAll();
                                },
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(dateStr, style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 13)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white70),
                  onPressed: _fetchAll,
                  tooltip: 'รีเฟรช',
                ),
              ],
            ),
          ),

          // ── Content ─────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 600;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Stats Row
                      _buildStatsRow(isWide, occupiedBeds, totalBeds),
                      const SizedBox(height: 20),

                      // Main content: requests + beds side by side on wide
                      if (isWide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 3, child: _buildPendingRequests()),
                            const SizedBox(width: 16),
                            Expanded(flex: 2, child: _buildBedStatus()),
                          ],
                        )
                      else ...[
                        _buildPendingRequests(),
                        const SizedBox(height: 16),
                        _buildBedStatus(),
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(bool isWide, int occupied, int total) {
    final stats = [
      _StatData(
        value: _pendingRequests.length.toString(),
        label: 'คำขอรอรับเรื่อง',
        color: const Color(0xFFE53E3E),
      ),
      _StatData(
        value: occupied.toString(),
        label: 'เตียงมีผู้ป่วย',
        color: _primaryTeal,
      ),
      _StatData(
        value: total.toString(),
        label: 'เตียงทั้งหมด',
        color: const Color(0xFF4A5568),
      ),
    ];

    if (isWide) {
      return Row(
        children: stats
            .map((s) => Expanded(child: Padding(padding: const EdgeInsets.only(right: 12), child: _buildStatCard(s))))
            .toList(),
      );
    }
    return Column(children: stats.map((s) => Padding(padding: const EdgeInsets.only(bottom: 10), child: _buildStatCard(s))).toList());
  }

  Widget _buildStatCard(_StatData stat) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(stat.value, style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: stat.color, height: 1)),
          const SizedBox(height: 4),
          Text(stat.label, style: const TextStyle(fontSize: 13, color: Color(0xFF718096))),
        ],
      ),
    );
  }

  Widget _buildPendingRequests() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Text('คำขอที่ต้องดำเนินการ',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF2D3748))),
          ),
          const Divider(height: 1, color: Color(0xFFEDF2F7)),
          if (_isLoadingRequests)
            const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
          else if (_pendingRequests.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('ไม่มีคำขอรอดำเนินการ 🎉', style: TextStyle(color: Colors.grey))),
            )
          else ...[
            ...(_pendingRequests.take(6).map((req) => _buildRequestRow(req))),
            const Divider(height: 1, color: Color(0xFFEDF2F7)),
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextButton(
                onPressed: null,
                child: Text(
                  'เลือกคำขอเพื่อดูรายละเอียดและมอบหมายงาน',
                  style: TextStyle(color: _primaryTeal.withValues(alpha: 0.7), fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRequestRow(Map<String, dynamic> req) {
    final type = req['type'] ?? '';
    final status = req['status'] ?? '';
    final bedNo = req['bed_qr_session']?['bedno'] ?? req['bedno'] ?? '-';
    final createdAt = req['created_at'] ?? req['createdAt'];

    return InkWell(
      onTap: () async {
        await Navigator.push(context, MaterialPageRoute(builder: (_) => RequestDetailPage(request: req)));
        _fetchRequests();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFEDF2F7)))),
        child: Row(
          children: [
            Container(
              width: 8, height: 8,
              decoration: BoxDecoration(color: _typeColor(type), shape: BoxShape.circle),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'เตียง $bedNo · ${_typeLabel(type)}',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF2D3748)),
                  ),
                  const SizedBox(height: 2),
                  Text('เมื่อ ${_formatTime(createdAt)}', style: const TextStyle(fontSize: 12, color: Color(0xFF718096))),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _statusBgColor(status),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _statusLabel(status),
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _statusTextColor(status)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBedStatus() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Text('สถานะเตียง', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF2D3748))),
          ),
          const Divider(height: 1, color: Color(0xFFEDF2F7)),
          if (_isLoadingBeds)
            const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
          else if (_beds.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('ไม่มีข้อมูลเตียง', style: TextStyle(color: Colors.grey))),
            )
          else
            ..._beds.map((bed) => _buildBedRow(bed)),
        ],
      ),
    );
  }

  Widget _buildBedRow(dynamic bed) {
    final bedNo = bed['bedno'] ?? bed['bed_no'] ?? '-';
    final ipdReg = bed['ipd_reg'];
    final patient = ipdReg?['patient'];
    final isOccupied = patient != null;
    final hasQr = bed['qrSession'] != null;

    String label;
    Color labelColor;
    Color labelBg;

    if (isOccupied) {
      label = 'มีผู้ป่วย';
      labelColor = _primaryTeal;
      labelBg = const Color(0xFFE9F5F5);
    } else if (hasQr) {
      label = 'ว่าง / QR ปิด';
      labelColor = const Color(0xFF718096);
      labelBg = const Color(0xFFEDF2F7);
    } else {
      label = 'ว่าง';
      labelColor = const Color(0xFF718096);
      labelBg = const Color(0xFFEDF2F7);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFEDF2F7)))),
      child: Row(
        children: [
          Text(
            bedNo.toString(),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: isOccupied ? const Color(0xFF2D3748) : const Color(0xFF718096),
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: labelBg, borderRadius: BorderRadius.circular(20)),
            child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: labelColor)),
          ),
        ],
      ),
    );
  }

  String _monthThai(int m) {
    const months = ['','ม.ค.','ก.พ.','มี.ค.','เม.ย.','พ.ค.','มิ.ย.','ก.ค.','ส.ค.','ก.ย.','ต.ค.','พ.ย.','ธ.ค.'];
    return months[m];
  }
}

class _StatData {
  final String value;
  final String label;
  final Color color;
  const _StatData({required this.value, required this.label, required this.color});
}
