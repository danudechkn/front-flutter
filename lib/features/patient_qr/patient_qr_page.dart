import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';
import 'patient_qr_api.dart';
import 'help_request_sheet.dart';
import 'help_request_realtime.dart';

class PatientQrPage extends StatefulWidget {
  final String qrToken;

  const PatientQrPage({super.key, required this.qrToken});

  @override
  State<PatientQrPage> createState() => _PatientQrPageState();
}

class _PatientQrPageState extends State<PatientQrPage> {
  bool _isLoading = true;
  String? _errorMessage;
  
  Map<String, dynamic>? _sessionData;
  Map<String, dynamic>? _patientData;
  
  String _bedNo = '';
  String _hospitalName = 'โรงพยาบาลตัวอย่าง';
  String _patientName = '';
  
  final Color _primaryTeal = const Color(0xFF166568);
  final Color _bgTeal = const Color(0xFFE9F0F0);
  final Color _warningYellow = const Color(0xFFFDF1DB);
  final Color _bgGray = const Color(0xFFF8F9FA);

  List<dynamic> _contents = [];
  Map<String, dynamic>? _latestHelpRequest;
  StreamSubscription<Map<String, dynamic>>? _requestStatusSubscription;
  bool _isSendingHelpRequest = false;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  @override
  void dispose() {
    _requestStatusSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initData() async {

    try {
      final validateRes = await PatientQrApi.validateQr(widget.qrToken);

      if (validateRes['valid'] == true || validateRes['session'] != null) {
        final rawSession = validateRes['session'];
        if (rawSession is! Map) {
          throw ApiException(500, 'QR response does not contain a session');
        }

        // JSON decoded on Flutter web can contain LinkedMap<dynamic, dynamic>.
        // Convert nested objects before assigning them to typed Map fields.
        final session = Map<String, dynamic>.from(rawSession);
        final rawPatient = validateRes['patient'] ?? session['patient'] ?? session['Patient'];
        final patient = rawPatient is Map
            ? Map<String, dynamic>.from(rawPatient)
            : <String, dynamic>{};
        
        _sessionData = session;
        _patientData = patient;
        _bedNo = session['bedno'] ?? 'ไม่ระบุเตียง';
        
        final prename = patient['prename'] ?? patient['preName'] ?? '';
        final firstname = patient['firstname'] ?? patient['firstName'] ?? '';
        final lastname = patient['lastname'] ?? patient['lastName'] ?? '';
        _patientName = '$prename$firstname $lastname'.trim();

        await _loadLatestHelpRequest();
        _subscribeToHelpRequestStatus();

        final locationId = session['locationid'];
        if (locationId != null) {
          try {
            final contents = await PatientQrApi.fetchContents(locationId);
            if (contents.isNotEmpty) {
              _contents = contents;
            }
          } catch (e) {
            debugPrint("Content fetch error: $e");
          }
        }
      } else {
        _errorMessage = 'QR Code ไม่ถูกต้อง หรือหมดอายุแล้ว';
      }
    } on ApiException catch (e) {
      // Map English API error messages to Thai
      final msg = e.message.toLowerCase();
      if (msg.contains('invalid') || msg.contains('expired') || msg.contains('discharged')) {
        _errorMessage = 'qr_invalid';
      } else if (msg.contains('not found')) {
        _errorMessage = 'qr_invalid';
      } else {
        _errorMessage = 'ไม่สามารถตรวจสอบข้อมูลได้\nกรุณาลองใหม่อีกครั้ง';
      }
    } catch (e) {
      _errorMessage = 'เกิดข้อผิดพลาดในการเชื่อมต่อ\nกรุณาตรวจสอบสัญญาณอินเทอร์เน็ต';
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadLatestHelpRequest() async {
    final sessionId = _sessionData?['id']?.toString();
    if (sessionId == null || sessionId.isEmpty) return;

    try {
      final request = await PatientQrApi.fetchLatestHelpRequest(sessionId);
      if (mounted) setState(() => _latestHelpRequest = request);
    } catch (e) {
      // The patient can still ask for help if the status refresh is unavailable.
      debugPrint('Help request status fetch error: $e');
    }
  }

  void _subscribeToHelpRequestStatus() {
    final sessionId = _sessionData?['id']?.toString();
    if (sessionId == null || sessionId.isEmpty) return;

    _requestStatusSubscription?.cancel();
    _requestStatusSubscription = HelpRequestRealtime.watch(sessionId).listen(
      (request) {
        if (mounted) setState(() => _latestHelpRequest = request);
      },
      onError: (Object error) => debugPrint('Realtime status error: $error'),
    );
  }

  bool get _hasOpenHelpRequest {
    final status = _latestHelpRequest?['status'];
    return status == 'NEW' || status == 'ACKNOWLEDGED' || status == 'IN_PROGRESS';
  }

  Future<void> _sendHelpRequest(String type, {String? note}) async {
    if (_sessionData == null || _hasOpenHelpRequest || _isSendingHelpRequest) return;
    setState(() => _isSendingHelpRequest = true);
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final request = await PatientQrApi.sendHelpRequest(
        _sessionData!['id'].toString(),
        type,
        note: note,
      );
      
      if (!mounted) return;
      Navigator.pop(context); // Close loading
      setState(() => _latestHelpRequest = request);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ส่งคำร้องขอความช่วยเหลือสำเร็จ พยาบาลกำลังเดินทางมาหาคุณ'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading
      if (e is ApiException && e.statusCode == 409) {
        await _loadLatestHelpRequest();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('มีคำขอที่กำลังดำเนินการอยู่แล้ว'),
            backgroundColor: Color(0xFFDD6B20),
          ),
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ส่งคำร้องไม่สำเร็จ: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSendingHelpRequest = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_errorMessage != null) {
      final isInvalidQr = _errorMessage == 'qr_invalid';
      return Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          title: const Text('Inpatient Companion'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 0,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: isInvalidQr ? const Color(0xFFFFF3CD) : const Color(0xFFFFEBEE),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isInvalidQr ? Icons.qr_code_2 : Icons.wifi_off,
                    size: 64,
                    color: isInvalidQr ? const Color(0xFFF57C00) : Colors.red,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  isInvalidQr ? 'QR Code หมดอายุแล้ว' : 'เกิดข้อผิดพลาด',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  isInvalidQr
                      ? 'QR Code นี้ไม่สามารถใช้งานได้\nเนื่องจากหมดอายุ หรือผู้ป่วยได้รับการจำหน่ายแล้ว\n\nกรุณาติดต่อพยาบาลเพื่อขอ QR Code ใหม่'
                      : _errorMessage!,
                  style: const TextStyle(fontSize: 16, color: Colors.black54, height: 1.6),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                if (isInvalidQr)
                  ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.person_outline),
                    label: const Text('ติดต่อพยาบาล'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF166568),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _bgGray,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: constraints.maxWidth >= 680 ? 32 : 20,
                    vertical: 24,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                _buildHeader(),
                const SizedBox(height: 24),
                if (_contents.isNotEmpty) _buildAlertCard(_contents.first),
                if (_contents.length > 1) ...[
                  const SizedBox(height: 32),
                  const Text(
                    'รายการวันนี้',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
                  ),
                  const SizedBox(height: 16),
                  _buildTimeline(),
                ],
                const SizedBox(height: 32),
                const Text(
                  'ต้องการความช่วยเหลือ',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
                ),
                const SizedBox(height: 16),
                _buildActionButtons(),
                if (_latestHelpRequest != null) ...[
                  const SizedBox(height: 24),
                  _buildLatestRequestCard(),
                ],
                const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text('$_hospitalName · ข้อมูลผู้ป่วย', style: const TextStyle(color: Colors.grey, fontSize: 14)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: _bgTeal, borderRadius: BorderRadius.circular(16)),
              child: Text('เตียง $_bedNo', style: TextStyle(color: _primaryTeal, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const SizedBox(height: 8),
        Text(_patientName.isNotEmpty ? 'ผู้ป่วย $_patientName' : 'เตียง $_bedNo', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87)),
        const SizedBox(height: 4),
        const Text('กรุณาตรวจสอบชื่อก่อนใช้งาน', style: TextStyle(color: Colors.grey, fontSize: 14)),
      ],
    );
  }

  Widget _buildAlertCard(dynamic content) {
    final title = content['title'] ?? 'ประกาศ';
    final msg = content['body'] ?? '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: _warningYellow, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
          if (msg.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(msg, style: const TextStyle(fontSize: 16, color: Colors.black87)),
          ]
        ],
      ),
    );
  }

  Widget _buildTimeline() {
    // Skip the first item since it's used for the alert card
    final timelineItems = _contents.skip(1).toList();
    
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: timelineItems.length,
      separatorBuilder: (context, index) => const Divider(height: 32, color: Colors.black12),
      itemBuilder: (context, index) {
        final item = timelineItems[index];
        final title = item['title'] ?? '';
        final body = item['body'] ?? '';
        
        // Try to extract time (e.g. "08:30") from the beginning of the title
        String timeStr = '';
        String displayTitle = title;
        final timeMatch = RegExp(r'^(\d{2}:\d{2})\s*(.*)').firstMatch(title);
        if (timeMatch != null) {
          timeStr = timeMatch.group(1) ?? '';
          displayTitle = timeMatch.group(2) ?? '';
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (timeStr.isNotEmpty)
              SizedBox(
                width: 60,
                child: Text(timeStr, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _primaryTeal)),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(displayTitle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                  if (body.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(body, style: const TextStyle(fontSize: 14, color: Colors.grey)),
                  ]
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildActionButtons() {
    final disabled = _hasOpenHelpRequest || _isSendingHelpRequest;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildSecondaryButton(
                'เข้าห้องน้ำ',
                disabled ? null : () => _sendHelpRequest('TOILET'),
              ),
            ),
        const SizedBox(width: 12),
            Expanded(
              child: _buildSecondaryButton(
                'สอบถามเรื่องยา',
                disabled ? null : () => _sendHelpRequest('MEDICATION_QUESTION'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 64,
          child: ElevatedButton(
            onPressed: disabled ? null : () => _sendHelpRequest('PAIN'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryTeal,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: const Text('แจ้งปวด / ไม่สบาย', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton(
            onPressed: disabled ? null : () {
              HelpRequestSheet.show(context, (type, note) {
                _sendHelpRequest(type, note: note);
              });
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF2C3E50),
              side: const BorderSide(color: Colors.black26),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('อื่นๆ ...', style: TextStyle(fontSize: 16)),
          ),
        ),
      ],
    );
  }

  Widget _buildSecondaryButton(String label, VoidCallback? onPressed) {
    return SizedBox(
      height: 56,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFE8F0F2),
          foregroundColor: const Color(0xFF2C3E50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        child: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildLatestRequestCard() {
    final request = _latestHelpRequest!;
    final status = request['status']?.toString() ?? '';
    final type = request['type']?.toString() ?? '';
    final isFinished = status == 'RESOLVED' || status == 'CANCELLED';
    final color = _requestStatusColor(status);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isFinished ? Icons.check_circle_outline : Icons.access_time_filled,
            color: color,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('คำขอล่าสุด', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  '${_requestTypeLabel(type)} · ${_requestStatusLabel(status)}',
                  style: TextStyle(color: color, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  _requestStatusDescription(status),
                  style: const TextStyle(color: Color(0xFF4A5568), height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _requestTypeLabel(String type) {
    switch (type) {
      case 'PAIN': return 'แจ้งปวด / ไม่สบาย';
      case 'TOILET': return 'ขอเข้าห้องน้ำ';
      case 'MEDICATION_QUESTION': return 'สอบถามเรื่องยา';
      default: return 'ขอความช่วยเหลือ';
    }
  }

  String _requestStatusLabel(String status) {
    switch (status) {
      case 'NEW': return 'ส่งคำขอแล้ว';
      case 'ACKNOWLEDGED': return 'พยาบาลรับเรื่องแล้ว';
      case 'IN_PROGRESS': return 'พยาบาลกำลังดำเนินการ';
      case 'RESOLVED': return 'ดำเนินการเรียบร้อย';
      case 'CANCELLED': return 'คำขอถูกยกเลิก';
      default: return 'กำลังตรวจสอบสถานะ';
    }
  }

  String _requestStatusDescription(String status) {
    switch (status) {
      case 'NEW': return 'พยาบาลจะเห็นคำขอของคุณในไม่ช้า';
      case 'ACKNOWLEDGED': return 'พยาบาลรับทราบแล้ว กรุณารอสักครู่';
      case 'IN_PROGRESS': return 'พยาบาลกำลังช่วยเหลือคุณ';
      case 'RESOLVED': return 'หากยังต้องการความช่วยเหลือ สามารถส่งคำขอใหม่ได้';
      case 'CANCELLED': return 'หากยังต้องการความช่วยเหลือ สามารถส่งคำขอใหม่ได้';
      default: return '';
    }
  }

  Color _requestStatusColor(String status) {
    switch (status) {
      case 'NEW': return const Color(0xFFDD6B20);
      case 'ACKNOWLEDGED': return const Color(0xFF2B6CB0);
      case 'IN_PROGRESS': return _primaryTeal;
      case 'RESOLVED': return const Color(0xFF276749);
      case 'CANCELLED': return const Color(0xFF718096);
      default: return const Color(0xFF718096);
    }
  }
}
