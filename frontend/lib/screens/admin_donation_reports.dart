import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/api_config.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:file_saver/file_saver.dart';
import 'dart:typed_data';

class AdminDonationReports extends StatefulWidget {
  const AdminDonationReports({super.key});

  @override
  State<AdminDonationReports> createState() => _AdminDonationReportsState();
}

class _AdminDonationReportsState extends State<AdminDonationReports>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTimeRange? _selectedDateRange;

  // ── Inventory state ──
  List<Map<String, dynamic>> _allInventory = [];
  List<Map<String, dynamic>> _filteredInventory = [];
  bool _loadingInventory = true;
  String _invSearchQuery = '';
  String _invStatusFilter = 'All';
  String _invSort = 'Date ↓';
  final _invSearchCtrl = TextEditingController();

  // ── Money state ──
  List<Map<String, dynamic>> _allMoney = [];
  List<Map<String, dynamic>> _filteredMoney = [];
  bool _loadingMoney = true;
  String _monSearchQuery = '';
  String _monStatusFilter = 'All';
  String _monSort = 'Date ↓';
  final _monSearchCtrl = TextEditingController();

  static const List<String> _invStatusOptions = [
    'All', 'Pending', 'Received', 'Not Received'
  ];
  static const List<String> _monStatusOptions = [
    'All', 'SUCCESS', 'FAILED'
  ];
  static const List<String> _invSortOptions = [
    'Date ↓', 'Date ↑', 'Donor A-Z', 'Camp A-Z'
  ];
  static const List<String> _monSortOptions = [
    'Date ↓', 'Date ↑', 'Amount ↓', 'Amount ↑', 'Donor A-Z'
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchInventoryReport();
    _fetchMoneyReport();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _invSearchCtrl.dispose();
    _monSearchCtrl.dispose();
    super.dispose();
  }

  // ────────────────────────── DATA FETCH ──────────────────────────

  Future<void> _fetchInventoryReport() async {
    setState(() => _loadingInventory = true);
    try {
      final res = await http
          .get(Uri.parse(ApiConfig.adminInventoryReport))
          .timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        setState(() {
          _allInventory = data.cast<Map<String, dynamic>>();
          _loadingInventory = false;
        });
        _applyInventoryFilters();
      } else {
        throw Exception('Status ${res.statusCode}');
      }
    } catch (e) {
      setState(() => _loadingInventory = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading inventory report: $e')),
        );
      }
    }
  }

  Future<void> _fetchMoneyReport() async {
    setState(() => _loadingMoney = true);
    try {
      final res = await http
          .get(Uri.parse(ApiConfig.adminMoneyReport))
          .timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        setState(() {
          _allMoney = data.cast<Map<String, dynamic>>();
          _loadingMoney = false;
        });
        _applyMoneyFilters();
      } else {
        throw Exception('Status ${res.statusCode}');
      }
    } catch (e) {
      setState(() => _loadingMoney = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading money report: $e')),
        );
      }
    }
  }

  // ────────────────────────── FILTER LOGIC ──────────────────────────

  void _applyInventoryFilters() {
    List<Map<String, dynamic>> list = List.from(_allInventory);

    if (_selectedDateRange != null) {
      list = list.where((r) {
        final dStr = r['donatedAt'];
        if (dStr == null) return false;
        try {
          final date = DateTime.parse(dStr.toString()).toLocal();
          final itemDate = DateTime(date.year, date.month, date.day);
          final start = DateTime(_selectedDateRange!.start.year, _selectedDateRange!.start.month, _selectedDateRange!.start.day);
          final end = DateTime(_selectedDateRange!.end.year, _selectedDateRange!.end.month, _selectedDateRange!.end.day);
          return itemDate.compareTo(start) >= 0 && itemDate.compareTo(end) <= 0;
        } catch (_) {
          return false;
        }
      }).toList();
    }

    // Search
    if (_invSearchQuery.isNotEmpty) {
      final q = _invSearchQuery.toLowerCase();
      list = list.where((r) {
        return (r['donorName'] ?? '').toLowerCase().contains(q) ||
            (r['itemName'] ?? '').toLowerCase().contains(q) ||
            (r['campName'] ?? '').toLowerCase().contains(q);
      }).toList();
    }

    // Status filter
    if (_invStatusFilter != 'All') {
      list = list.where((r) => r['status'] == _invStatusFilter).toList();
    }

    // Sort
    list.sort((a, b) {
      switch (_invSort) {
        case 'Date ↑':
          return _parseDate(a['donatedAt']).compareTo(_parseDate(b['donatedAt']));
        case 'Donor A-Z':
          return (a['donorName'] ?? '').compareTo(b['donorName'] ?? '');
        case 'Camp A-Z':
          return (a['campName'] ?? '').compareTo(b['campName'] ?? '');
        default: // Date ↓
          return _parseDate(b['donatedAt']).compareTo(_parseDate(a['donatedAt']));
      }
    });

    setState(() => _filteredInventory = list);
  }

  void _applyMoneyFilters() {
    List<Map<String, dynamic>> list = List.from(_allMoney);

    if (_selectedDateRange != null) {
      list = list.where((r) {
        final dStr = r['donatedAt'];
        if (dStr == null) return false;
        try {
          final date = DateTime.parse(dStr.toString()).toLocal();
          final itemDate = DateTime(date.year, date.month, date.day);
          final start = DateTime(_selectedDateRange!.start.year, _selectedDateRange!.start.month, _selectedDateRange!.start.day);
          final end = DateTime(_selectedDateRange!.end.year, _selectedDateRange!.end.month, _selectedDateRange!.end.day);
          return itemDate.compareTo(start) >= 0 && itemDate.compareTo(end) <= 0;
        } catch (_) {
          return false;
        }
      }).toList();
    }

    // Search
    if (_monSearchQuery.isNotEmpty) {
      final q = _monSearchQuery.toLowerCase();
      list = list.where((r) {
        return (r['donorName'] ?? '').toLowerCase().contains(q) ||
            (r['campName'] ?? '').toLowerCase().contains(q) ||
            (r['donorEmail'] ?? '').toLowerCase().contains(q);
      }).toList();
    }

    // Status filter
    if (_monStatusFilter != 'All') {
      list = list.where((r) => r['paymentStatus'] == _monStatusFilter).toList();
    }

    // Sort
    list.sort((a, b) {
      switch (_monSort) {
        case 'Date ↑':
          return _parseDate(a['donatedAt']).compareTo(_parseDate(b['donatedAt']));
        case 'Amount ↓':
          return ((b['amount'] ?? 0) as num).compareTo((a['amount'] ?? 0) as num);
        case 'Amount ↑':
          return ((a['amount'] ?? 0) as num).compareTo((b['amount'] ?? 0) as num);
        case 'Donor A-Z':
          return (a['donorName'] ?? '').compareTo(b['donorName'] ?? '');
        default: // Date ↓
          return _parseDate(b['donatedAt']).compareTo(_parseDate(a['donatedAt']));
      }
    });

    setState(() => _filteredMoney = list);
  }

  DateTime _parseDate(dynamic d) {
    if (d == null) return DateTime(2000);
    try {
      return DateTime.parse(d.toString());
    } catch (_) {
      return DateTime(2000);
    }
  }

  String _formatDate(dynamic d) {
    if (d == null) return 'N/A';
    try {
      final dt = DateTime.parse(d.toString()).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/'
          '${dt.month.toString().padLeft(2, '0')}/'
          '${dt.year}  ${dt.hour.toString().padLeft(2, '0')}:'
          '${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return 'N/A';
    }
  }

  // ────────────────────────── EXPORT & MASKING ──────────────────────────

  String _maskPhone(String phone) {
    if (phone.length <= 4) return phone;
    return '*' * (phone.length - 4) + phone.substring(phone.length - 4);
  }

  String _maskEmail(String email) {
    if (!email.contains('@')) return email;
    final parts = email.split('@');
    final name = parts[0];
    final domain = parts[1];
    if (name.length <= 2) return "${name.substring(0, 1)}***@$domain";
    return "${name.substring(0, 2)}***@$domain";
  }

  String _maskName(String name) {
    if (name.length <= 2) return name;
    final parts = name.split(' ');
    return parts.map((p) {
      if (p.length <= 2) return p;
      return "${p.substring(0, 1)}${'*' * (p.length - 2)}${p.substring(p.length - 1)}";
    }).join(' ');
  }

  void _showExportPreview() {
    final bool isInventoryTab = _tabController.index == 0;
    final List<Map<String, dynamic>> dataToExport = isInventoryTab ? _filteredInventory : _filteredMoney;

    if (dataToExport.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No data to export.')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isInventoryTab ? 'Preview Inventory Export (Masked)' : 'Preview Money Export (Masked)'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: isInventoryTab
                      ? const [
                          DataColumn(label: Text('Date')),
                          DataColumn(label: Text('Item')),
                          DataColumn(label: Text('Quantity')),
                          DataColumn(label: Text('Unit')),
                          DataColumn(label: Text('Donor')),
                          DataColumn(label: Text('Email')),
                          DataColumn(label: Text('Mobile')),
                          DataColumn(label: Text('Camp')),
                          DataColumn(label: Text('Status')),
                        ]
                      : const [
                          DataColumn(label: Text('Date')),
                          DataColumn(label: Text('Amount')),
                          DataColumn(label: Text('Status')),
                          DataColumn(label: Text('Donor')),
                          DataColumn(label: Text('Email')),
                          DataColumn(label: Text('Mobile')),
                          DataColumn(label: Text('Camp')),
                        ],
                  rows: dataToExport.map((item) {
                    if (isInventoryTab) {
                      return DataRow(cells: [
                        DataCell(Text(_formatDate(item['donatedAt']))),
                        DataCell(Text(item['itemName']?.toString() ?? '')),
                        DataCell(Text(item['quantity']?.toString() ?? '')),
                        DataCell(Text(item['unit']?.toString() ?? '')),
                        DataCell(Text(_maskName(item['donorName']?.toString() ?? 'Anonymous'))),
                        DataCell(Text(_maskEmail(item['donorEmail']?.toString() ?? 'N/A'))),
                        DataCell(Text(_maskPhone(item['donorMobile']?.toString() ?? 'N/A'))),
                        DataCell(Text(item['campName']?.toString() ?? '')),
                        DataCell(Text(item['status']?.toString() ?? '')),
                      ]);
                    } else {
                      return DataRow(cells: [
                        DataCell(Text(_formatDate(item['donatedAt']))),
                        DataCell(Text((item['amount']?.toString() ?? ''))),
                        DataCell(Text((item['paymentStatus']?.toString() ?? ''))),
                        DataCell(Text(_maskName(item['donorName']?.toString() ?? 'Anonymous'))),
                        DataCell(Text(_maskEmail(item['donorEmail']?.toString() ?? 'N/A'))),
                        DataCell(Text(_maskPhone(item['donorMobile']?.toString() ?? 'N/A'))),
                        DataCell(Text(item['campName']?.toString() ?? '')),
                      ]);
                    }
                  }).toList(),
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _exportToExcel();
              },
              child: const Text('Export Excel'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _exportToExcel() async {
    try {
      var excel = Excel.createExcel();
      final bool isInventoryTab = _tabController.index == 0;
      
      if (isInventoryTab) {
        excel.rename('Sheet1', 'Inventory Donations');
        Sheet sheet = excel['Inventory Donations'];
        
        sheet.appendRow([
          TextCellValue('Date'),
          TextCellValue('Item'),
          TextCellValue('Quantity'),
          TextCellValue('Unit'),
          TextCellValue('Donor Name (Masked)'),
          TextCellValue('Donor Email (Masked)'),
          TextCellValue('Donor Mobile (Masked)'),
          TextCellValue('Camp'),
          TextCellValue('Status'),
        ]);
        
        for (var item in _filteredInventory) {
          sheet.appendRow([
            TextCellValue(_formatDate(item['donatedAt'])),
            TextCellValue(item['itemName']?.toString() ?? ''),
            TextCellValue(item['quantity']?.toString() ?? ''),
            TextCellValue(item['unit']?.toString() ?? ''),
            TextCellValue(_maskName(item['donorName']?.toString() ?? 'Anonymous')),
            TextCellValue(_maskEmail(item['donorEmail']?.toString() ?? 'N/A')),
            TextCellValue(_maskPhone(item['donorMobile']?.toString() ?? 'N/A')),
            TextCellValue(item['campName']?.toString() ?? ''),
            TextCellValue(item['status']?.toString() ?? ''),
          ]);
        }
      } else {
        excel.rename('Sheet1', 'Money Donations');
        Sheet sheet = excel['Money Donations'];
        
        sheet.appendRow([
          TextCellValue('Date'),
          TextCellValue('Amount'),
          TextCellValue('Status'),
          TextCellValue('Donor Name (Masked)'),
          TextCellValue('Donor Email (Masked)'),
          TextCellValue('Donor Mobile (Masked)'),
          TextCellValue('Camp'),
        ]);
        
        for (var item in _filteredMoney) {
          sheet.appendRow([
            TextCellValue(_formatDate(item['donatedAt'])),
            TextCellValue(item['amount']?.toString() ?? ''),
            TextCellValue(item['paymentStatus']?.toString() ?? ''),
            TextCellValue(_maskName(item['donorName']?.toString() ?? 'Anonymous')),
            TextCellValue(_maskEmail(item['donorEmail']?.toString() ?? 'N/A')),
            TextCellValue(_maskPhone(item['donorMobile']?.toString() ?? 'N/A')),
            TextCellValue(item['campName']?.toString() ?? ''),
          ]);
        }
      }

      var fileBytes = excel.save();
      if (fileBytes != null) {
        String fileName = 'Admin_Report_${DateTime.now().millisecondsSinceEpoch}.xlsx';
        await FileSaver.instance.saveFile(
          name: fileName,
          bytes: Uint8List.fromList(fileBytes),
          mimeType: MimeType.microsoftExcel,
        );
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Excel Report Downloaded successfully')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate Excel: $e')),
        );
      }
    }
  }

  // ────────────────────────── BUILD ──────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Donation Reports'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Export Report',
            onPressed: () => _showExportPreview(),
          ),
        ],
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.inventory_2_outlined), text: 'Inventory'),
            Tab(icon: Icon(Icons.currency_rupee), text: 'Money'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildInventoryTab(),
          _buildMoneyTab(),
        ],
      ),
    );
  }

  // ────────────────────────── INVENTORY TAB ──────────────────────────

  Widget _buildInventoryTab() {
    return Column(
      children: [
        _buildInventoryControls(),
        _buildSummaryBar(
          count: _filteredInventory.length,
          total: _allInventory.length,
          label: 'item donations',
          color: Colors.orange,
        ),
        Expanded(
          child: _loadingInventory
              ? const Center(child: CircularProgressIndicator())
              : _filteredInventory.isEmpty
                  ? _buildEmpty('No inventory donations found')
                  : RefreshIndicator(
                      onRefresh: _fetchInventoryReport,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: _filteredInventory.length,
                        itemBuilder: (ctx, i) =>
                            _inventoryCard(_filteredInventory[i]),
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildInventoryControls() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Column(
        children: [
          // Search bar
          TextField(
            controller: _invSearchCtrl,
            decoration: InputDecoration(
              hintText: 'Search by donor, item or camp…',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _invSearchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _invSearchCtrl.clear();
                        setState(() => _invSearchQuery = '');
                        _applyInventoryFilters();
                      },
                    )
                  : null,
              filled: true,
              fillColor: const Color(0xFFF0F2F5),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (v) {
              setState(() => _invSearchQuery = v);
              _applyInventoryFilters();
            },
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              // Status filter
              Expanded(
                child: _buildDropdown(
                  value: _invStatusFilter,
                  items: _invStatusOptions,
                  icon: Icons.filter_list,
                  label: 'Status',
                  onChanged: (v) {
                    setState(() => _invStatusFilter = v!);
                    _applyInventoryFilters();
                  },
                ),
              ),
              const SizedBox(width: 8),
              // Sort
              Expanded(
                child: _buildDropdown(
                  value: _invSort,
                  items: _invSortOptions,
                  icon: Icons.sort,
                  label: 'Sort',
                  onChanged: (v) {
                    setState(() => _invSort = v!);
                    _applyInventoryFilters();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(color: const Color(0xFFF0F2F5), borderRadius: BorderRadius.circular(10)),
                child: IconButton(
                  icon: Icon(
                    _selectedDateRange == null ? Icons.date_range : Icons.edit_calendar,
                    color: _selectedDateRange == null ? Colors.grey[600] : Colors.green,
                    size: 20,
                  ),
                  tooltip: 'Filter by Date Range',
                  onPressed: () async {
                    final picked = await showDateRangePicker(
                      context: context,
                      initialDateRange: _selectedDateRange,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setState(() => _selectedDateRange = picked);
                      _applyInventoryFilters();
                      _applyMoneyFilters();
                    }
                  },
                ),
              ),
              if (_selectedDateRange != null) ...[
                  const SizedBox(width: 4),
                  InkWell(
                    onTap: () {
                      setState(() => _selectedDateRange = null);
                      _applyInventoryFilters();
                      _applyMoneyFilters();
                    },
                    child: const Icon(Icons.cancel, color: Colors.red, size: 20),
                  )
              ]
            ],
          ),
        ],
      ),
    );
  }

  Widget _inventoryCard(Map<String, dynamic> r) {
    final status = r['status'] ?? 'Pending';
    final statusColor = status == 'Received'
        ? Colors.green
        : status == 'Not Received'
            ? Colors.red
            : Colors.orange;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3))
        ],
      ),
      child: Column(
        children: [
          // Header row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                const Icon(Icons.inventory_2, size: 18, color: Colors.orange),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    r['itemName'] ?? 'Unknown Item',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          // Body
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                _infoRow(
                  Icons.person,
                  'Donor',
                  r['donorName'] ?? 'Anonymous',
                  Colors.blue.shade700,
                ),
                _infoRow(Icons.phone, 'Mobile', r['donorMobile'] ?? 'N/A',
                    Colors.green.shade700),
                _infoRow(Icons.email_outlined, 'Email',
                    r['donorEmail'] ?? 'N/A', Colors.purple.shade700),
                _infoRow(Icons.location_on_outlined, 'Camp',
                    r['campName'] ?? 'Unknown', Colors.red.shade700),
                _infoRow(
                  Icons.scale,
                  'Quantity',
                  '${r['quantity'] ?? 0} ${r['unit'] ?? ''}',
                  Colors.teal.shade700,
                ),
                _infoRow(Icons.calendar_today_outlined, 'Donated On',
                    _formatDate(r['donatedAt']), Colors.grey.shade700),
                if (r['receivedAt'] != null)
                  _infoRow(Icons.check_circle_outline, 'Received On',
                      _formatDate(r['receivedAt']), Colors.green.shade700),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────── MONEY TAB ──────────────────────────

  Widget _buildMoneyTab() {
    final totalSuccess = _filteredMoney
        .where((r) => r['paymentStatus'] == 'SUCCESS')
        .fold<double>(0, (acc, r) => acc + (r['amount'] ?? 0).toDouble());

    return Column(
      children: [
        _buildMoneyControls(),
        _buildSummaryBar(
          count: _filteredMoney.length,
          total: _allMoney.length,
          label: 'money donations  •  ₹${totalSuccess.toStringAsFixed(2)} collected',
          color: Colors.green,
        ),
        Expanded(
          child: _loadingMoney
              ? const Center(child: CircularProgressIndicator())
              : _filteredMoney.isEmpty
                  ? _buildEmpty('No money donations found')
                  : RefreshIndicator(
                      onRefresh: _fetchMoneyReport,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: _filteredMoney.length,
                        itemBuilder: (ctx, i) => _moneyCard(_filteredMoney[i]),
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildMoneyControls() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Column(
        children: [
          TextField(
            controller: _monSearchCtrl,
            decoration: InputDecoration(
              hintText: 'Search by donor, camp or email…',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _monSearchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _monSearchCtrl.clear();
                        setState(() => _monSearchQuery = '');
                        _applyMoneyFilters();
                      },
                    )
                  : null,
              filled: true,
              fillColor: const Color(0xFFF0F2F5),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (v) {
              setState(() => _monSearchQuery = v);
              _applyMoneyFilters();
            },
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildDropdown(
                  value: _monStatusFilter,
                  items: _monStatusOptions,
                  icon: Icons.filter_list,
                  label: 'Status',
                  onChanged: (v) {
                    setState(() => _monStatusFilter = v!);
                    _applyMoneyFilters();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildDropdown(
                  value: _monSort,
                  items: _monSortOptions,
                  icon: Icons.sort,
                  label: 'Sort',
                  onChanged: (v) {
                    setState(() => _monSort = v!);
                    _applyMoneyFilters();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(color: const Color(0xFFF0F2F5), borderRadius: BorderRadius.circular(10)),
                child: IconButton(
                  icon: Icon(
                    _selectedDateRange == null ? Icons.date_range : Icons.edit_calendar,
                    color: _selectedDateRange == null ? Colors.grey[600] : Colors.green,
                    size: 20,
                  ),
                  tooltip: 'Filter by Date Range',
                  onPressed: () async {
                    final picked = await showDateRangePicker(
                      context: context,
                      initialDateRange: _selectedDateRange,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setState(() => _selectedDateRange = picked);
                      _applyInventoryFilters();
                      _applyMoneyFilters();
                    }
                  },
                ),
              ),
              if (_selectedDateRange != null) ...[
                  const SizedBox(width: 4),
                  InkWell(
                    onTap: () {
                      setState(() => _selectedDateRange = null);
                      _applyInventoryFilters();
                      _applyMoneyFilters();
                    },
                    child: const Icon(Icons.cancel, color: Colors.red, size: 20),
                  )
              ]
            ],
          ),
        ],
      ),
    );
  }

  Widget _moneyCard(Map<String, dynamic> r) {
    final status = r['paymentStatus'] ?? 'UNKNOWN';
    final statusColor = status == 'SUCCESS' ? Colors.green : Colors.red;
    final amount = r['amount'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3))
        ],
      ),
      child: Column(
        children: [
          // Header row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                const Icon(Icons.currency_rupee, size: 18, color: Colors.green),
                const SizedBox(width: 6),
                Text(
                  amount != null ? '₹$amount' : '₹0',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                      color: Colors.green),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          // Body
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                _infoRow(Icons.person, 'Donor', r['donorName'] ?? 'Anonymous',
                    Colors.blue.shade700),
                _infoRow(Icons.phone, 'Mobile', r['donorMobile'] ?? 'N/A',
                    Colors.green.shade700),
                _infoRow(Icons.email_outlined, 'Email',
                    r['donorEmail'] ?? 'N/A', Colors.purple.shade700),
                _infoRow(Icons.location_on_outlined, 'Camp',
                    r['campName'] ?? 'General', Colors.red.shade700),
                _infoRow(Icons.calendar_today_outlined, 'Donated On',
                    _formatDate(r['donatedAt']), Colors.grey.shade700),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────── SHARED WIDGETS ──────────────────────────

  Widget _buildDropdown({
    required String value,
    required List<String> items,
    required IconData icon,
    required String label,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F2F5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: Icon(icon, size: 16, color: Colors.grey[600]),
          style: const TextStyle(fontSize: 13, color: Colors.black87),
          items: items
              .map((s) => DropdownMenuItem(value: s, child: Text(s)))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildSummaryBar({
    required int count,
    required int total,
    required String label,
    required Color color,
  }) {
    return Container(
      color: color.withOpacity(0.08),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.bar_chart, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            'Showing $count of $total $label',
            style: TextStyle(
                fontSize: 13, color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value, Color iconColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 8),
          SizedBox(
            width: 64,
            child: Text(
              '$label:',
              style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(String msg) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.hourglass_empty, size: 56, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(msg,
              style:
                  TextStyle(color: Colors.grey.shade500, fontSize: 16)),
        ],
      ),
    );
  }
}
