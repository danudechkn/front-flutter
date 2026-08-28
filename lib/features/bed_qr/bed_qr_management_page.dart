import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';
import 'qr_print_page.dart';

/// Static API helpers for bed data
class BedQrApi {
  static Future<List<dynamic>> fetchBeds(int locationId) async {
    final data = await ApiClient.get('/admin/wards/$locationId/beds');
    return data as List<dynamic>;
  }
}

class BedQrManagementPage extends StatefulWidget {
  final bool embedded;
  const BedQrManagementPage({super.key, this.embedded = false});

  @override
  State<BedQrManagementPage> createState() => _BedQrManagementPageState();
}

class _BedQrManagementPageState extends State<BedQrManagementPage> {
  List<dynamic> _wards = [];
  dynamic _selectedWard;
  List<dynamic> _beds = [];
  bool _isLoadingWards = false;
  bool _isLoadingBeds = false;

  // 'all' | 'occupied' | 'empty'
  String _bedFilter = 'all';

  List<dynamic> get _filteredBeds {
    if (_bedFilter == 'occupied') {
      return _beds.where((b) => b['ipd_reg']?['patient'] != null).toList();
    } else if (_bedFilter == 'empty') {
      return _beds.where((b) => b['ipd_reg']?['patient'] == null).toList();
    }
    return _beds;
  }

  final TextEditingController _wardSearchController = TextEditingController();
  final FocusNode _wardFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _fetchWards();
  }

  @override
  void dispose() {
    _wardSearchController.dispose();
    _wardFocusNode.dispose();
    super.dispose();
  }

  String _getWardName(dynamic ward) {
    if (ward == null) return '';
    return ward['location'] != null
        ? (ward['location']['detailtext'] ?? ward['location']['shortname'] ?? 'Unknown Ward')
        : 'Unknown Ward';
  }

  Future<void> _fetchWards() async {
    setState(() => _isLoadingWards = true);
    try {
      final data = await ApiClient.get('/admin/wards');
      setState(() {
        _wards = (data as List<dynamic>)
            .map((w) => Map<String, dynamic>.from(w as Map))
            .toList();
      });
    } on ApiException catch (e) {
      _showError('Failed to load wards: ${e.message}');
    } catch (e) {
      _showError(e.toString());
    } finally {
      setState(() => _isLoadingWards = false);
    }
  }

  Future<void> _fetchBeds(int locationId) async {
    setState(() => _isLoadingBeds = true);
    try {
      final data = await ApiClient.get('/admin/wards/$locationId/beds');
      setState(() {
        _beds = data as List<dynamic>;
      });
    } on ApiException catch (e) {
      _showError('Failed to load beds: ${e.message}');
    } catch (e) {
      _showError(e.toString());
    } finally {
      setState(() => _isLoadingBeds = false);
    }
  }

  Future<void> _generateQr(String bedNo) async {
    if (_selectedWard == null) return;
    setState(() => _isLoadingBeds = true);
    try {
      final response = await ApiClient.post('/admin/wards/${_selectedWard['locationid']}/beds/$bedNo/qr/generate');
      
      final rawToken = response['rawToken'];
      _showSuccess('สร้าง QR Code สำหรับเตียง $bedNo สำเร็จ');
      
      await _fetchBeds(_selectedWard['locationid']);

      if (!mounted) return;
      
      // ทันทีที่สร้างเสร็จ ให้เด้งหน้า Print ขึ้นมาพร้อมกับ Token ของจริง
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => QrPrintPage(
            locationId: _selectedWard['locationid'],
            bedNo: bedNo,
            wardName: _selectedWard['location']?['detailtext'] ?? _selectedWard['location']?['shortname'] ?? 'Unknown Ward',
            rawToken: rawToken,
          ),
        ),
      );
    } on ApiException catch (e) {
      _showError('Failed to generate QR: ${e.message}');
      setState(() => _isLoadingBeds = false);
    } catch (e) {
      _showError(e.toString());
      setState(() => _isLoadingBeds = false);
    }
  }

  Future<void> _revokeQr(String qrId) async {
    try {
      await ApiClient.post('/admin/qr/$qrId/revoke');
      
      setState(() {
        final bedIndex = _beds.indexWhere((b) => b['qrSession']?['id'] == qrId);
        if (bedIndex != -1) {
          _beds[bedIndex]['qrSession'] = null;
        }
      });
      
      _showSuccess('QR Code revoked');
    } on ApiException catch (e) {
      _showError('Failed to revoke QR: ${e.message}');
    } catch (e) {
      _showError(e.toString());
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.green));
  }

  @override
  Widget build(BuildContext context) {
    final body = Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Select Ward:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _isLoadingWards
              ? const CircularProgressIndicator()
              : Autocomplete<Map<String, dynamic>>(
                  optionsBuilder: (TextEditingValue textEditingValue) {
                    final wards = _wards
                        .map((w) => Map<String, dynamic>.from(w as Map))
                        .toList();
                    if (textEditingValue.text.isEmpty) {
                      return wards;
                    }
                    final query = textEditingValue.text.toLowerCase();
                    return wards.where((ward) {
                      final name = _getWardName(ward).toLowerCase();
                      final id = ward['locationid']?.toString() ?? '';
                      return name.contains(query) || id.contains(query);
                    });
                  },
                  displayStringForOption: (ward) =>
                      '${_getWardName(ward)} (ID: ${ward['locationid']})',
                  initialValue: _selectedWard != null
                      ? TextEditingValue(
                          text: '${_getWardName(_selectedWard)} (ID: ${_selectedWard['locationid']})',
                        )
                      : TextEditingValue.empty,
                  onSelected: (Map<String, dynamic> value) {
                    setState(() {
                      _selectedWard = value;
                      _beds = [];
                    });
                    _fetchBeds(value['locationid']);
                  },
                  fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                    return TextField(
                      controller: controller,
                      focusNode: focusNode,
                      decoration: InputDecoration(
                        hintText: 'ค้นหา Ward...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: controller.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  controller.clear();
                                  setState(() {
                                    _selectedWard = null;
                                    _beds = [];
                                  });
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 14),
                      ),
                    );
                  },
                  optionsViewBuilder: (context, onSelected, options) {
                    return Align(
                      alignment: Alignment.topLeft,
                      child: Material(
                        elevation: 4,
                        borderRadius: BorderRadius.circular(8),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 250),
                          child: ListView.builder(
                            padding: EdgeInsets.zero,
                            shrinkWrap: true,
                            itemCount: options.length,
                            itemBuilder: (context, index) {
                              final ward = options.elementAt(index);
                              return ListTile(
                                leading: const Icon(Icons.local_hospital_outlined),
                                title: Text(_getWardName(ward)),
                                subtitle: Text('ID: ${ward['locationid']}'),
                                onTap: () => onSelected(ward),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
          const SizedBox(height: 24),
          // Header + filter row
          Row(
            children: [
              const Text('Beds in Ward:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const Spacer(),
              ToggleButtons(
                borderRadius: BorderRadius.circular(8),
                constraints: const BoxConstraints(minWidth: 72, minHeight: 34),
                isSelected: [
                  _bedFilter == 'all',
                  _bedFilter == 'occupied',
                  _bedFilter == 'empty',
                ],
                onPressed: (index) {
                  setState(() {
                    _bedFilter = ['all', 'occupied', 'empty'][index];
                  });
                },
                children: const [
                  Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.list, size: 16), SizedBox(width: 4), Text('ทั้งหมด', style: TextStyle(fontSize: 12))]),
                  Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.person, size: 16, color: Colors.blue), SizedBox(width: 4), Text('มีคน', style: TextStyle(fontSize: 12))]),
                  Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.bed, size: 16, color: Colors.grey), SizedBox(width: 4), Text('ว่าง', style: TextStyle(fontSize: 12))]),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _isLoadingBeds
                ? const Center(child: CircularProgressIndicator())
                : _beds.isEmpty
                    ? const Center(child: Text('No beds to display. Please select a ward.'))
                    : _filteredBeds.isEmpty
                        ? Center(
                            child: Text(
                              _bedFilter == 'occupied' ? 'ไม่มีเตียงที่มีผู้ป่วย' : 'ไม่มีเตียงที่ว่าง',
                              style: const TextStyle(color: Colors.grey),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _filteredBeds.length,
                            itemBuilder: (context, index) {
                              final bed = _filteredBeds[index];
                              final bool hasQr = bed['qrSession'] != null;
                              final String bedNo = bed['bedno'] ?? bed['bed_no'] ?? 'Unknown';
                              final String? qrId = hasQr ? bed['qrSession']['id'] : null;
                              final ipdReg = bed['ipd_reg'];
                              final patient = ipdReg != null ? ipdReg['patient'] : null;
                              final bool isOccupied = patient != null;
                              final String patientName = isOccupied
                                  ? '${patient['prename'] ?? ''}${patient['firstname'] ?? ''} ${patient['lastname'] ?? ''}'
                                  : 'Empty Bed';

                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                elevation: isOccupied ? 2 : 0,
                                color: isOccupied ? Colors.white : Colors.grey.shade100,
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: isOccupied ? Colors.blue.shade100 : Colors.grey.shade300,
                                    child: Icon(isOccupied ? Icons.person : Icons.bed,
                                        color: isOccupied ? Colors.blue.shade700 : Colors.grey.shade600),
                                  ),
                                  title: Text('Bed $bedNo', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 4),
                                      Text(
                                        patientName,
                                        style: TextStyle(
                                          color: isOccupied ? Colors.black87 : Colors.grey,
                                          fontWeight: isOccupied ? FontWeight.w500 : FontWeight.normal,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(hasQr ? Icons.check_circle : Icons.cancel,
                                              size: 14, color: hasQr ? Colors.green : Colors.red),
                                          const SizedBox(width: 4),
                                          Text(hasQr ? 'QR Active' : 'No QR', style: const TextStyle(fontSize: 12)),
                                        ],
                                      ),
                                    ],
                                  ),
                                  isThreeLine: true,
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (!hasQr)
                                        ElevatedButton(
                                          onPressed: () => _generateQr(bedNo),
                                          child: const Text('Generate QR'),
                                        ),
                                      if (hasQr) ...[
                                        IconButton(
                                          icon: const Icon(Icons.print, color: Colors.blue),
                                          tooltip: 'Print QR',
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => QrPrintPage(
                                                  locationId: _selectedWard['locationid'],
                                                  bedNo: bedNo,
                                                  wardName: _selectedWard['name'] ?? _selectedWard['location']?['detailtext'] ?? 'Unknown Ward',
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete, color: Colors.red),
                                          tooltip: 'Revoke QR',
                                          onPressed: () {
                                            if (qrId != null) _revokeQr(qrId);
                                          },
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );

    if (widget.embedded) return body;

    return Scaffold(
      appBar: AppBar(title: const Text('Bed QR Management')),
      body: body,
    );
  }
}
