import 'dart:async';
import 'package:flutter/material.dart';
import 'nurse_queue_api.dart';
import 'request_detail_page.dart';
import '../patient_qr/help_request_realtime.dart';

class NurseQueuePage extends StatefulWidget {
  final bool embedded;
  const NurseQueuePage({super.key, this.embedded = false});

  @override
  State<NurseQueuePage> createState() => _NurseQueuePageState();
}

class _NurseQueuePageState extends State<NurseQueuePage> {
  static const Color _primaryTeal = Color(0xFF166568);
  static const Color _bgGray = Color(0xFFF8F9FA);

  List<Map<String, dynamic>> _wards = [];
  Map<String, dynamic>? _selectedWard;
  List<Map<String, dynamic>> _requests = [];

  bool _isLoadingWards = true;
  bool _isLoadingRequests = false;

  // null = ทั้งหมด
  String? _statusFilter;

  StreamSubscription<Map<String, dynamic>>? _realtimeSubscription;

  final List<({String? value, String label, Color color})> _statusOptions = [
    (value: null, label: 'ทั้งหมด', color: Color(0xFF4A5568)),
    (value: HelpRequestStatus.newRequest, label: 'ใหม่', color: Color(0xFFE53E3E)),
    (value: HelpRequestStatus.acknowledged, label: 'รับเรื่อง', color: Color(0xFFDD6B20)),
    (value: HelpRequestStatus.inProgress, label: 'กำลังทำ', color: Color(0xFF2B6CB0)),
    (value: HelpRequestStatus.resolved, label: 'ปิดแล้ว', color: Color(0xFF276749)),
  ];

  @override
  void initState() {
    super.initState();
    _fetchWards();
  }

  @override
  void dispose() {
    _realtimeSubscription?.cancel();
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
          _fetchRequests();
          _subscribeToRealtimeUpdates();
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('โหลดหอผู้ป่วยไม่ได้: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoadingWards = false);
    }
  }

  void _subscribeToRealtimeUpdates() {
    _realtimeSubscription?.cancel();
    _realtimeSubscription = HelpRequestRealtime.watchAdmin().listen(
      (_) => _fetchRequests(),
      onError: (Object error) => debugPrint('Nurse queue realtime error: $error'),
    );
  }

  Future<void> _fetchRequests() async {
    if (_selectedWard == null) return;
    setState(() => _isLoadingRequests = true);
    try {
      final locationId = _selectedWard!['locationid'] as int;
      final requests = await NurseQueueApi.fetchHelpRequests(
        locationId,
        status: _statusFilter,
      );
      // When "ทั้งหมด" selected (null filter), show only active requests
      final filtered = _statusFilter == null
          ? requests.where((r) {
              final s = r['status'] ?? '';
              return s != HelpRequestStatus.cancelled && s != HelpRequestStatus.resolved;
            }).toList()
          : requests;

      // Sort by urgency (PAIN first), then by time ascending
      filtered.sort((a, b) {
        final urgencyA = a['type'] == 'PAIN' ? 0 : 1;
        final urgencyB = b['type'] == 'PAIN' ? 0 : 1;
        if (urgencyA != urgencyB) return urgencyA.compareTo(urgencyB);
        final timeA = a['created_at'] ?? a['createdAt'] ?? '';
        final timeB = b['created_at'] ?? b['createdAt'] ?? '';
        return timeA.compareTo(timeB);
      });
      setState(() => _requests = filtered);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('โหลดคิวไม่ได้: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoadingRequests = false);
    }
  }

  String _wardName(Map<String, dynamic> ward) {
    final loc = ward['location'];
    if (loc is Map) {
      return loc['detailtext'] ?? loc['shortname'] ?? 'หอ ${ward['locationid']}';
    }
    return 'หอ ${ward['locationid']}';
  }

  String _formatRelativeTime(String? isoString) {
    if (isoString == null) return '-';
    try {
      final dt = DateTime.parse(isoString).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'เมื่อกี้';
      if (diff.inMinutes < 60) return '${diff.inMinutes} นาทีที่แล้ว';
      if (diff.inHours < 24) return '${diff.inHours} ชั่วโมงที่แล้ว';
      return '${diff.inDays} วันที่แล้ว';
    } catch (_) {
      return isoString;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case HelpRequestStatus.newRequest: return const Color(0xFFE53E3E);
      case HelpRequestStatus.acknowledged: return const Color(0xFFDD6B20);
      case HelpRequestStatus.inProgress: return const Color(0xFF2B6CB0);
      case HelpRequestStatus.resolved: return const Color(0xFF276749);
      case HelpRequestStatus.cancelled: return const Color(0xFF718096);
      default: return const Color(0xFF718096);
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case HelpRequestStatus.newRequest: return 'ใหม่';
      case HelpRequestStatus.acknowledged: return 'รับเรื่อง';
      case HelpRequestStatus.inProgress: return 'กำลังทำ';
      case HelpRequestStatus.resolved: return 'ปิดแล้ว';
      case HelpRequestStatus.cancelled: return 'ยกเลิก';
      default: return status;
    }
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'PAIN': return '🚨 แจ้งปวด';
      case 'TOILET': return '🚻 ห้องน้ำ';
      case 'MEDICATION_QUESTION': return '💊 เรื่องยา';
      case 'OTHER': return '📋 อื่นๆ';
      default: return type;
    }
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'PAIN': return const Color(0xFFE53E3E);
      case 'TOILET': return const Color(0xFF2B6CB0);
      case 'MEDICATION_QUESTION': return const Color(0xFF276749);
      default: return const Color(0xFF553C9A);
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = _isLoadingWards
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              _buildFiltersBar(),
              Expanded(
                child: _isLoadingRequests
                    ? const Center(child: CircularProgressIndicator())
                    : _requests.isEmpty
                        ? _buildEmptyState()
                        : _buildRequestList(),
              ),
            ],
          );

    if (widget.embedded) return body;

    return Scaffold(
      backgroundColor: _bgGray,
      appBar: AppBar(
        title: const Text('คิวพยาบาล', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchRequests,
            tooltip: 'รีเฟรช',
          ),
        ],
      ),
      body: body,
    );
  }

  Widget _buildFiltersBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Ward Dropdown
          if (_wards.length > 1) ...[
            InputDecorator(
              decoration: InputDecoration(
                labelText: 'หอผู้ป่วย',
                labelStyle: const TextStyle(color: Color(0xFF166568)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF166568), width: 2),
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<Map<String, dynamic>>(
                  value: _selectedWard,
                  isExpanded: true,
                  items: _wards.map((w) => DropdownMenuItem(value: w, child: Text(_wardName(w)))).toList(),
                  onChanged: (w) {
                  setState(() => _selectedWard = w);
                  _fetchRequests();
                  },
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Status filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _statusOptions.map((opt) {
                final selected = _statusFilter == opt.value;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(opt.label),
                    selected: selected,
                    onSelected: (_) {
                      setState(() => _statusFilter = opt.value);
                      _fetchRequests();
                    },
                    selectedColor: opt.color.withValues(alpha: 0.2),
                    checkmarkColor: opt.color,
                    labelStyle: TextStyle(
                      color: selected ? opt.color : const Color(0xFF4A5568),
                      fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                    ),
                    side: BorderSide(
                      color: selected ? opt.color : const Color(0xFFCBD5E0),
                    ),
                    backgroundColor: Colors.white,
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestList() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useGrid = constraints.maxWidth >= 880;
        if (!useGrid) {
          return RefreshIndicator(
            onRefresh: _fetchRequests,
            color: _primaryTeal,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _requests.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) => _buildRequestCard(_requests[index]),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _fetchRequests,
          color: _primaryTeal,
          child: GridView.builder(
            padding: const EdgeInsets.all(24),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 500,
              mainAxisExtent: 148,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
            ),
            itemCount: _requests.length,
            itemBuilder: (context, index) => _buildRequestCard(_requests[index]),
          ),
        );
      },
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> req) {
    final type = req['type'] ?? '';
    final status = req['status'] ?? '';
    final bedNo = req['bed_qr_session']?['bedno'] ?? req['bedno'] ?? '-';
    final note = req['note'] ?? '';
    final createdAt = req['created_at'] ?? req['createdAt'];
    final isPain = type == 'PAIN';

    return GestureDetector(
      onTap: () async {
        final shouldRefresh = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => RequestDetailPage(request: req),
          ),
        );
        if (shouldRefresh == true) _fetchRequests();
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: isPain
              ? Border.all(color: const Color(0xFFE53E3E), width: 2)
              : Border.all(color: const Color(0xFFE8ECEF)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Left color indicator
              Container(
                width: 4,
                height: 60,
                decoration: BoxDecoration(
                  color: _typeColor(type),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          _typeLabel(type),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: _typeColor(type),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _statusColor(status),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _statusLabel(status),
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.bed, size: 14, color: Color(0xFF718096)),
                        const SizedBox(width: 4),
                        Text('เตียง $bedNo', style: const TextStyle(color: Color(0xFF4A5568), fontSize: 13)),
                        const SizedBox(width: 12),
                        const Icon(Icons.access_time, size: 14, color: Color(0xFF718096)),
                        const SizedBox(width: 4),
                        Text(
                          _formatRelativeTime(createdAt),
                          style: const TextStyle(color: Color(0xFF718096), fontSize: 13),
                        ),
                      ],
                    ),
                    if (note.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        note,
                        style: const TextStyle(color: Color(0xFF718096), fontSize: 13),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: Color(0xFFCBD5E0)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFE9F0F0),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.inbox_outlined, size: 56, color: Color(0xFF166568)),
          ),
          const SizedBox(height: 20),
          const Text('ไม่มีคำขอในขณะนี้', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black54)),
          const SizedBox(height: 8),
          const Text('ดึงลงเพื่อรีเฟรช', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}
