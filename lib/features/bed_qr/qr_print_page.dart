import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/api/api_client.dart';

class QrPrintPage extends StatefulWidget {
  final int locationId;
  final String bedNo;
  final String wardName;
  final String? rawToken;

  const QrPrintPage({
    super.key,
    required this.locationId,
    required this.bedNo,
    required this.wardName,
    this.rawToken,
  });

  @override
  State<QrPrintPage> createState() => _QrPrintPageState();
}

class _QrPrintPageState extends State<QrPrintPage> {
  bool _isLoading = true;
  String? _qrToken;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.rawToken != null) {
      _qrToken = widget.rawToken;
      _isLoading = false;
    } else {
      // ถ้าเข้าหน้า Print ภายหลัง จะไม่มี rawToken (เพราะ Backend เก็บแค่ Hash)
      // จึงต้องสั่ง Regenerate ใหม่เพื่อให้ได้ QR Code ของจริงที่ใช้งานได้
      _regenerateQrDetails();
    }
  }

  Future<void> _regenerateQrDetails() async {
    try {
      // ดึง session เดิมมาก่อนเพื่อเอา id ไปสั่ง regenerate
      final sessionData = await ApiClient.get('/admin/wards/${widget.locationId}/beds/${widget.bedNo}/qr');
      final sessionId = sessionData['id'];

      // สั่ง Regenerate เพื่อดึง rawToken ใหม่
      final regenData = await ApiClient.post('/admin/qr/$sessionId/regenerate');
      
      setState(() {
        _qrToken = regenData['rawToken'];
        _isLoading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _errorMessage = 'ไม่สามารถพิมพ์ QR ได้: ${e.message}';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Print Preview'),
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            tooltip: 'Print',
            onPressed: () {
              // TODO: Implement actual printing logic using a package like `printing`
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Printing functionality to be implemented...')),
              );
            },
          ),
        ],
      ),
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator()
            : _errorMessage != null
                ? Text(_errorMessage!, style: const TextStyle(color: Colors.red))
                : _buildPrintLayout(),
      ),
    );
  }

  Widget _buildPrintLayout() {
    return Container(
      width: 400,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.5),
            spreadRadius: 5,
            blurRadius: 7,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Inpatient Companion',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Text(
            'Ward: ${widget.wardName}',
            style: const TextStyle(fontSize: 18),
          ),
          Text(
            'Bed: ${widget.bedNo}',
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.blue),
          ),
          const SizedBox(height: 24),
          if (_qrToken != null)
            QrImageView(
              data: 'http://172.16.46.47:8080/#/patient?token=$_qrToken',
              version: QrVersions.auto,
              size: 200.0,
              backgroundColor: Colors.white,
            )
          else
            const Text('Invalid QR Data'),
          const SizedBox(height: 16),
          const Text(
            'Scan to access bed services',
            style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }
}
