import 'package:flutter/material.dart';
import 'nurse_queue_api.dart';

class RequestDetailPage extends StatefulWidget {
  final Map<String, dynamic> request;

  const RequestDetailPage({super.key, required this.request});

  @override
  State<RequestDetailPage> createState() => _RequestDetailPageState();
}

class _RequestDetailPageState extends State<RequestDetailPage> {
  static const Color _primaryTeal = Color(0xFF166568);
  static const Color _bgGray = Color(0xFFF8F9FA);

  late Map<String, dynamic> _request;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _request = Map<String, dynamic>.from(widget.request);
  }

  String get _status => _request['status'] ?? '';

  Color _statusColor(String status) {
    switch (status) {
      case HelpRequestStatus.newRequest:
        return const Color(0xFFE53E3E);
      case HelpRequestStatus.acknowledged:
        return const Color(0xFFDD6B20);
      case HelpRequestStatus.inProgress:
        return const Color(0xFF2B6CB0);
      case HelpRequestStatus.resolved:
        return const Color(0xFF276749);
      case HelpRequestStatus.cancelled:
        return const Color(0xFF718096);
      default:
        return const Color(0xFF718096);
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case HelpRequestStatus.newRequest:
        return 'ใหม่';
      case HelpRequestStatus.acknowledged:
        return 'รับเรื่องแล้ว';
      case HelpRequestStatus.inProgress:
        return 'กำลังดำเนินการ';
      case HelpRequestStatus.resolved:
        return 'ปิดงานแล้ว';
      case HelpRequestStatus.cancelled:
        return 'ยกเลิกแล้ว';
      default:
        return status;
    }
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'PAIN':
        return '🚨 แจ้งปวด / ไม่สบาย';
      case 'TOILET':
        return '🚻 ช่วยเข้าห้องน้ำ';
      case 'MEDICATION_QUESTION':
        return '💊 สอบถามเรื่องยา';
      case 'OTHER':
        return '📋 อื่นๆ';
      default:
        return type;
    }
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'PAIN':
        return const Color(0xFFE53E3E);
      case 'TOILET':
        return const Color(0xFF2B6CB0);
      case 'MEDICATION_QUESTION':
        return const Color(0xFF276749);
      default:
        return const Color(0xFF553C9A);
    }
  }

  Future<void> _performAction(String action, String label) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(label),
        content: Text('ยืนยันการ$label?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ยกเลิก', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryTeal,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('ยืนยัน'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      final reqId = _request['id']?.toString() ?? '';
      debugPrint('DEBUG: action=$action, id=$reqId, request keys=${_request.keys.toList()}');
      if (reqId.isEmpty) throw Exception('ไม่พบ ID ของคำขอ');
      final updated = await NurseQueueApi.updateRequestStatus(reqId, action);
      setState(() {
        if (updated.isNotEmpty) {
          _request = updated;
        }
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$label สำเร็จ'),
          backgroundColor: Colors.green,
        ),
      );
      // Return true to tell the queue page to refresh
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาด: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatTime(String? isoString) {
    if (isoString == null) return '-';
    try {
      final dt = DateTime.parse(isoString).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoString;
    }
  }

  @override
  Widget build(BuildContext context) {
    final type = _request['type'] ?? '';
    final note = _request['note'] ?? '';
    final bedNo = _request['bed_qr_session']?['bedno'] ?? _request['bedno'] ?? '-';
    final patientMap = _request['bed_qr_session']?['Patient'] ??
        _request['bed_qr_session']?['patient'] ??
        {};
    final prename = patientMap['prename'] ?? '';
    final firstname = patientMap['firstname'] ?? patientMap['firstName'] ?? '';
    final lastname = patientMap['lastname'] ?? patientMap['lastName'] ?? '';
    final patientName = '$prename$firstname $lastname'.trim();
    final requestedAt = _formatTime(_request['created_at'] ?? _request['createdAt']);
    final acknowledgedAt = _formatTime(_request['acknowledged_at']);
    final resolvedAt = _formatTime(_request['resolved_at']);

    return Scaffold(
      backgroundColor: _bgGray,
      appBar: AppBar(
        title: const Text('รายละเอียดคำขอ', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        centerTitle: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) => Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 680),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: constraints.maxWidth >= 680 ? 32 : 20,
                      vertical: 20,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                  // Type Badge Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: _typeColor(type).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _typeColor(type).withValues(alpha: 0.4), width: 1.5),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _typeColor(type).withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(_typeIcon(type), color: _typeColor(type), size: 32),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _typeLabel(type),
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: _typeColor(type),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                decoration: BoxDecoration(
                                  color: _statusColor(_status),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  _statusLabel(_status),
                                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Patient & Bed Info
                  _buildInfoCard([
                    _buildInfoRow(Icons.bed, 'เตียง', bedNo),
                    if (patientName.isNotEmpty)
                      _buildInfoRow(Icons.person, 'ผู้ป่วย', patientName),
                    if (note.isNotEmpty)
                      _buildInfoRow(Icons.notes, 'หมายเหตุ', note),
                  ]),
                  const SizedBox(height: 16),

                  // Timeline
                  _buildInfoCard([
                    _buildInfoRow(Icons.access_time, 'เวลาแจ้ง', requestedAt),
                    if (_request['acknowledged_at'] != null)
                      _buildInfoRow(Icons.check_circle_outline, 'รับเรื่องเมื่อ', acknowledgedAt),
                    if (_request['resolved_at'] != null)
                      _buildInfoRow(Icons.task_alt, 'ปิดงานเมื่อ', resolvedAt),
                  ]),
                  const SizedBox(height: 32),

                  // Action Buttons
                  if (_status == HelpRequestStatus.newRequest) ...[
                    _buildActionButton(
                      label: 'รับเรื่อง',
                      icon: Icons.check_circle_outline,
                      color: const Color(0xFFDD6B20),
                      onPressed: () => _performAction(HelpRequestAction.acknowledge, 'รับเรื่อง'),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (_status == HelpRequestStatus.acknowledged) ...[
                    _buildActionButton(
                      label: 'เริ่มดำเนินการ',
                      icon: Icons.directions_run,
                      color: const Color(0xFF2B6CB0),
                      onPressed: () => _performAction(HelpRequestAction.inProgress, 'เริ่มดำเนินการ'),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (_status == HelpRequestStatus.inProgress) ...[
                    _buildActionButton(
                      label: 'ปิดงาน',
                      icon: Icons.task_alt,
                      color: _primaryTeal,
                      onPressed: () => _performAction(HelpRequestAction.resolve, 'ปิดงาน'),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (_status != HelpRequestStatus.resolved &&
                      _status != HelpRequestStatus.cancelled) ...[
                    OutlinedButton.icon(
                      onPressed: () => _performAction(HelpRequestAction.cancel, 'ยกเลิกคำขอ'),
                      icon: const Icon(Icons.cancel_outlined),
                      label: const Text('ยกเลิกคำขอ'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'PAIN': return Icons.emergency;
      case 'TOILET': return Icons.wc;
      case 'MEDICATION_QUESTION': return Icons.medication;
      default: return Icons.help_outline;
    }
  }

  Widget _buildInfoCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: children
            .asMap()
            .entries
            .expand((e) => [
                  e.value,
                  if (e.key < children.length - 1)
                    const Divider(height: 20, color: Color(0xFFE8ECEF)),
                ])
            .toList(),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: const Color(0xFF166568)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      height: 54,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}
