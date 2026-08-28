import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';
import 'patient_qr_api.dart';
import 'help_request_sheet.dart';

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

  @override
  void initState() {
    super.initState();
    _initData();
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

  Future<void> _sendHelpRequest(String type, {String? note}) async {
    if (_sessionData == null) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await PatientQrApi.sendHelpRequest(_sessionData!['id'], type, note: note);
      
      if (!mounted) return;
      Navigator.pop(context); // Close loading
      
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ส่งคำร้องไม่สำเร็จ: $e'),
          backgroundColor: Colors.red,
        ),
      );
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
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildSecondaryButton('เข้าห้องน้ำ', () => _sendHelpRequest('TOILET')),
            ),
        const SizedBox(width: 12),
            Expanded(
              child: _buildSecondaryButton('สอบถามเรื่องยา', () => _sendHelpRequest('MEDICATION_QUESTION')),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 64,
          child: ElevatedButton(
            onPressed: () => _sendHelpRequest('PAIN'),
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
            onPressed: () {
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

  Widget _buildSecondaryButton(String label, VoidCallback onPressed) {
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
}
