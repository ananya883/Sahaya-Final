import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:file_saver/file_saver.dart';
import 'dart:typed_data';

const Color primaryColor = Color(0xFF1E88E5);
const double headerHeight = 200;

class CustomHeaderClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    path.lineTo(0, size.height - 30);
    path.quadraticBezierTo(
      size.width / 2,
      size.height,
      size.width,
      size.height - 30,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class DonationHistoryPage extends StatefulWidget {
  const DonationHistoryPage({super.key});

  @override
  State<DonationHistoryPage> createState() => _DonationHistoryPageState();
}

class _DonationHistoryPageState extends State<DonationHistoryPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  bool _isLoading = true;
  String? _errorMessage;
  String _searchQuery = "";
  DateTimeRange? _selectedDateRange;

  List<dynamic> _moneyDonations = [];
  List<dynamic> _itemDonations = [];
  double _totalMoney = 0;
  int _totalItems = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchHistory();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final donorId = prefs.getString('userId') ?? "Anonymous";
      final donorName = prefs.getString('userName') ?? "Anonymous Donor";

      final data = await ApiService.getDonationHistory(donorId, donorName);

      setState(() {
        _moneyDonations = data['moneyDonations'] ?? [];
        _itemDonations = data['itemDonations'] ?? [];
        _totalMoney = (data['totalMoney'] ?? 0).toDouble();
        _totalItems = data['totalItems'] ?? 0;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  String _formatDate(String isoString) {
    try {
      final date = DateTime.parse(isoString);
      return DateFormat('MMM dd, yyyy - hh:mm a').format(date);
    } catch (e) {
      return "Unknown Date";
    }
  }

  List<dynamic> get _filteredMoneyDonations {
    List<dynamic> filtered = _moneyDonations;
    
    if (_selectedDateRange != null) {
      filtered = filtered.where((item) {
        try {
          final dateStr = item['date']?.toString();
          if (dateStr == null) return false;
          final date = DateTime.parse(dateStr).toLocal();
          final itemDate = DateTime(date.year, date.month, date.day);
          final start = DateTime(_selectedDateRange!.start.year, _selectedDateRange!.start.month, _selectedDateRange!.start.day);
          final end = DateTime(_selectedDateRange!.end.year, _selectedDateRange!.end.month, _selectedDateRange!.end.day);
          return itemDate.compareTo(start) >= 0 && itemDate.compareTo(end) <= 0;
        } catch (e) {
          debugPrint('Error filtering money donation date: $e');
          return false;
        }
      }).toList();
    }

    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((item) {
        final amount = item['amount']?.toString().toLowerCase() ?? '';
        final campId = item['campId']?.toString().toLowerCase() ?? '';
        final status = item['status']?.toString().toLowerCase() ?? '';
        final dateStr = _formatDate(item['date']).toLowerCase();
        return amount.contains(_searchQuery) ||
            campId.contains(_searchQuery) ||
            status.contains(_searchQuery) ||
            dateStr.contains(_searchQuery);
      }).toList();
    }
    return filtered;
  }

  List<dynamic> get _filteredItemDonations {
    List<dynamic> filtered = _itemDonations;

    if (_selectedDateRange != null) {
      filtered = filtered.where((item) {
        try {
          final dateStr = item['date']?.toString();
          if (dateStr == null) return false;
          final date = DateTime.parse(dateStr).toLocal();
          final itemDate = DateTime(date.year, date.month, date.day);
          final start = DateTime(_selectedDateRange!.start.year, _selectedDateRange!.start.month, _selectedDateRange!.start.day);
          final end = DateTime(_selectedDateRange!.end.year, _selectedDateRange!.end.month, _selectedDateRange!.end.day);
          return itemDate.compareTo(start) >= 0 && itemDate.compareTo(end) <= 0;
        } catch (e) {
          debugPrint('Error filtering item donation date: $e');
          return false;
        }
      }).toList();
    }

    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((item) {
        final itemName = item['itemName']?.toString().toLowerCase() ?? '';
        final campId = item['campId']?.toString().toLowerCase() ?? '';
        final status = item['status']?.toString().toLowerCase() ?? '';
        final dateStr = _formatDate(item['date']).toLowerCase();
        return itemName.contains(_searchQuery) ||
            campId.contains(_searchQuery) ||
            status.contains(_searchQuery) ||
            dateStr.contains(_searchQuery);
      }).toList();
    }
    return filtered;
  }

  Future<void> _exportToExcel() async {
    try {
      var excel = Excel.createExcel();
      
      if (_tabController.index == 0) {
        // Export Money Donations
        excel.rename('Sheet1', 'Money Donations');
        Sheet sheet = excel['Money Donations'];
        
        sheet.appendRow([
          TextCellValue('Date'),
          TextCellValue('Amount (INR)'),
          TextCellValue('Status'),
          TextCellValue('Camp ID'),
        ]);
        for (var item in _filteredMoneyDonations) {
          sheet.appendRow([
            TextCellValue(_formatDate(item['date'])),
            TextCellValue(item['amount']?.toString() ?? ''),
            TextCellValue(item['status']?.toString() ?? ''),
            TextCellValue(item['campId']?.toString() ?? 'General'),
          ]);
        }
      } else {
        // Export Item Donations
        excel.rename('Sheet1', 'Item Donations');
        Sheet sheet = excel['Item Donations'];
        
        sheet.appendRow([
          TextCellValue('Date'),
          TextCellValue('Item Name'),
          TextCellValue('Quantity'),
          TextCellValue('Unit'),
          TextCellValue('Status'),
          TextCellValue('Camp ID'),
          TextCellValue('Received At'),
        ]);
        for (var item in _filteredItemDonations) {
          sheet.appendRow([
            TextCellValue(_formatDate(item['date'])),
            TextCellValue(item['itemName']?.toString() ?? ''),
            TextCellValue(item['quantity']?.toString() ?? ''),
            TextCellValue(item['unit']?.toString() ?? ''),
            TextCellValue(item['status']?.toString() ?? ''),
            TextCellValue(item['campId']?.toString() ?? 'Unknown'),
            TextCellValue(item['receivedAt'] != null ? _formatDate(item['receivedAt']) : ''),
          ]);
        }
      }

      var fileBytes = excel.save();
      
      if (fileBytes != null) {
        String fileName = 'Donation_Report_${DateTime.now().millisecondsSinceEpoch}.xlsx';
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

  void _showExportPreview() {
    final bool isMoneyTab = _tabController.index == 0;
    final List<dynamic> dataToExport = isMoneyTab ? _filteredMoneyDonations : _filteredItemDonations;

    if (dataToExport.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No data available to export.')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isMoneyTab ? 'Preview Money Donations' : 'Preview Item Donations'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: isMoneyTab
                      ? const [
                          DataColumn(label: Text('Date')),
                          DataColumn(label: Text('Amount (INR)')),
                          DataColumn(label: Text('Status')),
                          DataColumn(label: Text('Camp ID')),
                        ]
                      : const [
                          DataColumn(label: Text('Date')),
                          DataColumn(label: Text('Item Name')),
                          DataColumn(label: Text('Quantity')),
                          DataColumn(label: Text('Unit')),
                          DataColumn(label: Text('Status')),
                          DataColumn(label: Text('Camp ID')),
                          DataColumn(label: Text('Received At')),
                        ],
                  rows: dataToExport.map((item) {
                    if (isMoneyTab) {
                      return DataRow(cells: [
                        DataCell(Text(_formatDate(item['date']))),
                        DataCell(Text(item['amount']?.toString() ?? '')),
                        DataCell(Text(item['status']?.toString() ?? '')),
                        DataCell(Text(item['campId']?.toString() ?? 'General')),
                      ]);
                    } else {
                      return DataRow(cells: [
                        DataCell(Text(_formatDate(item['date']))),
                        DataCell(Text(item['itemName']?.toString() ?? '')),
                        DataCell(Text(item['quantity']?.toString() ?? '')),
                        DataCell(Text(item['unit']?.toString() ?? '')),
                        DataCell(Text(item['status']?.toString() ?? '')),
                        DataCell(Text(item['campId']?.toString() ?? 'Unknown')),
                        DataCell(Text(item['receivedAt'] != null ? _formatDate(item['receivedAt']) : '')),
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
              child: const Text('Download Excel'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeader() {
    return ClipPath(
      clipper: CustomHeaderClipper(),
      child: Container(
        height: headerHeight,
        color: primaryColor,
        alignment: Alignment.center,
        padding: const EdgeInsets.only(top: 40, left: 16, right: 16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Text(
                      "My Donations",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.download, color: Colors.white),
                  tooltip: 'Download Report',
                  onPressed: _showExportPreview,
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (_selectedDateRange != null)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.date_range, size: 16, color: primaryColor),
                    const SizedBox(width: 8),
                    Text(
                      '${DateFormat('MMM d, yyyy').format(_selectedDateRange!.start)} - ${DateFormat('MMM d, yyyy').format(_selectedDateRange!.end)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: primaryColor),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => setState(() => _selectedDateRange = null),
                      child: const Icon(Icons.cancel, size: 20, color: Colors.red),
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 45,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22.5),
                    ),
                    child: TextField(
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value.toLowerCase();
                        });
                      },
                      decoration: const InputDecoration(
                        hintText: "Search by camp, item, amount, status...",
                        prefixIcon: Icon(Icons.search, color: Colors.grey),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: Icon(
                      _selectedDateRange == null ? Icons.date_range : Icons.edit_calendar,
                      color: _selectedDateRange == null ? primaryColor : Colors.green,
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
                      }
                    },
                  ),
                )
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Column(
                children: [
                  const Icon(Icons.currency_rupee, color: Colors.green),
                  const SizedBox(height: 8),
                  Text(
                    "₹${_totalMoney.toStringAsFixed(0)}",
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green),
                  ),
                  const Text("Total Money", style: TextStyle(color: Colors.green)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Column(
                children: [
                  const Icon(Icons.inventory_2, color: Colors.orange),
                  const SizedBox(height: 8),
                  Text(
                    "$_totalItems",
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.orange),
                  ),
                  const Text("Items Donated", style: TextStyle(color: Colors.orange)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMoneyList() {
    final filteredList = _filteredMoneyDonations;
    if (filteredList.isEmpty) {
      return const Center(child: Text("No matching monetary donations.", style: TextStyle(color: Colors.grey)));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredList.length,
      itemBuilder: (context, index) {
        final item = filteredList[index];
        final isSuccess = item['status'] == 'SUCCESS';

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: CircleAvatar(
              backgroundColor: isSuccess ? Colors.green.shade100 : Colors.red.shade100,
              child: Icon(
                isSuccess ? Icons.check : Icons.close,
                color: isSuccess ? Colors.green : Colors.red,
              ),
            ),
            title: Text("₹${item['amount']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text("Camp ID: ${item['campId'] ?? 'General'}"),
                Text(_formatDate(item['date'])),
              ],
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isSuccess ? Colors.green.shade50 : Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                item['status'],
                style: TextStyle(
                  color: isSuccess ? Colors.green : Colors.red,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildItemsList() {
    final filteredList = _filteredItemDonations;
    if (filteredList.isEmpty) {
      return const Center(child: Text("No matching item donations.", style: TextStyle(color: Colors.grey)));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredList.length,
      itemBuilder: (context, index) {
        final item = filteredList[index];
        final isReceived = item['status'] == 'Received';

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: CircleAvatar(
              backgroundColor: Colors.blue.shade100,
              child: const Icon(Icons.card_giftcard, color: Colors.blue),
            ),
            title: Text("${item['itemName']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text("Quantity: ${item['quantity']} ${item['unit']}"),
                Text("Camp ID: ${item['campId'] ?? 'Unknown'}"),
                Text(_formatDate(item['date'])),
                if (isReceived && item['receivedAt'] != null)
                   Text("Received: ${_formatDate(item['receivedAt'])}", style: const TextStyle(color: Colors.green, fontSize: 12)),
              ],
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isReceived ? Colors.green.shade50 : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                item['status'],
                style: TextStyle(
                  color: isReceived ? Colors.green : Colors.orange,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text("My Donations")),
        body: Center(child: Text("Error: $_errorMessage")),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Column(
        children: [
          _buildHeader(),
          const SizedBox(height: 10),
          _buildSummaryCards(),
          const SizedBox(height: 20),
          TabBar(
            controller: _tabController,
            labelColor: primaryColor,
            unselectedLabelColor: Colors.grey,
            indicatorColor: primaryColor,
            tabs: const [
              Tab(icon: Icon(Icons.monetization_on), text: "Money"),
              Tab(icon: Icon(Icons.inventory), text: "Items"),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildMoneyList(),
                _buildItemsList(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
