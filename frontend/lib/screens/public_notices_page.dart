import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:file_saver/file_saver.dart';
import 'package:excel/excel.dart' hide Border;
import 'dart:typed_data';
import '../services/api_config.dart';

class PublicNoticesPage extends StatefulWidget {
  const PublicNoticesPage({super.key});

  @override
  State<PublicNoticesPage> createState() => _PublicNoticesPageState();
}

class _PublicNoticesPageState extends State<PublicNoticesPage> {
  List<dynamic> _notices = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchNotices();
  }

  Future<void> _fetchNotices() async {
    setState(() => _isLoading = true);
    try {
      final res = await http.get(Uri.parse(ApiConfig.publicNotices));
      if (res.statusCode == 200) {
        setState(() {
          _notices = jsonDecode(res.body);
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load notices: ${res.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading notices: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleAttachment(String? fileUrl, String fileName) async {
    if (fileUrl == null || fileUrl.isEmpty) return;

    final String fullUrl = "${ApiConfig.baseUrl}$fileUrl";
    
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final res = await http.get(Uri.parse(fullUrl));
      Navigator.pop(context); // hide loading

      if (res.statusCode == 200) {
        final bytes = res.bodyBytes;
        
        if (fileName.toLowerCase().endsWith('.xlsx')) {
          _showExcelPreview(bytes, fileName);
        } else {
          _downloadFile(bytes, fileName);
        }
      } else {
        throw Exception('Failed to fetch file: ${res.statusCode}');
      }
    } catch (e) {
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context); // close loader if crash
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error downloading file: $e')),
        );
      }
    }
  }

  void _showExcelPreview(Uint8List bytes, String fileName) {
    try {
      var excel = Excel.decodeBytes(bytes);
      var sheet = excel.tables[excel.tables.keys.first]!;
      
      // Limit to 10 rows for preview to keep it fast
      final rowsToPreview = sheet.rows.take(15).toList();
      
      // Extract columns from first row
      List<DataColumn> columns = [];
      if (rowsToPreview.isNotEmpty) {
        for (var cell in rowsToPreview.first) {
          final val = cell?.value?.toString() ?? 'Empty';
          columns.add(DataColumn(label: Text(val, style: const TextStyle(fontWeight: FontWeight.bold))));
        }
      }

      // Extract rows
      List<DataRow> dataRows = [];
      if (rowsToPreview.length > 1) {
        for (var i = 1; i < rowsToPreview.length; i++) {
          final rowContent = rowsToPreview[i];
          final cells = <DataCell>[];
          for (var j = 0; j < columns.length; j++) {
            if (j < rowContent.length) {
               cells.add(DataCell(Text(rowContent[j]?.value?.toString() ?? '')));
            } else {
               cells.add(const DataCell(Text('')));
            }
          }
          dataRows.add(DataRow(cells: cells));
        }
      }

      showDialog(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: Text('Preview: $fileName'),
            content: SizedBox(
              width: double.maxFinite,
              child: columns.isEmpty
                  ? const Text('File is empty.')
                  : SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columns: columns,
                          rows: dataRows,
                        ),
                      ),
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _downloadFile(bytes, fileName);
                },
                icon: const Icon(Icons.download),
                label: const Text('Download Excel'),
              ),
            ],
          );
        },
      );
    } catch (e) {
       // Fallback to direct download if parsing fails
      _downloadFile(bytes, fileName);
    }
  }

  Future<void> _downloadFile(Uint8List bytes, String fileName) async {
    try {
      // Determine mimetype roughly
      String mimeTypeStr = MimeType.other.toString();
      MimeType mime = MimeType.other;
      
      if (fileName.endsWith('.xlsx')) mime = MimeType.microsoftExcel;
      else if (fileName.endsWith('.pdf')) mime = MimeType.pdf;
      else if (fileName.endsWith('.png') || fileName.endsWith('.jpg') || fileName.endsWith('.jpeg')) mime = MimeType.jpeg;
      
      await FileSaver.instance.saveFile(
        name: fileName,
        bytes: bytes,
        mimeType: mime,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File downloaded successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving file: $e')),
        );
      }
    }
  }

  String _formatDate(String isoString) {
    try {
      final DateTime dt = DateTime.parse(isoString).toLocal();
      return '${dt.day}/${dt.month}/${dt.year} at ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return 'Unknown Date';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Public Notices'),
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchNotices,
          ),
        ],
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : _notices.isEmpty
              ? _buildEmpty()
              : RefreshIndicator(
                  onRefresh: _fetchNotices,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16.0),
                    itemCount: _notices.length,
                    itemBuilder: (context, index) {
                      final notice = _notices[index];
                      return _buildNoticeCard(notice);
                    },
                  ),
                ),
    );
  }

  Widget _buildEmpty() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.mark_email_read_outlined, size: 80, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'No Public Notices available',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildNoticeCard(dynamic notice) {
    final title = notice['title'] ?? 'No Title';
    final message = notice['message'] ?? 'No Message';
    final fileUrl = notice['fileUrl'];
    final fileName = notice['fileName'] ?? 'Attachment';
    final postedBy = notice['postedBy'] ?? 'Admin';
    final dateStr = notice['createdAt'] != null ? _formatDate(notice['createdAt']) : '';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.campaign, color: Colors.red, size: 28),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              "By $postedBy • $dateStr",
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            const Divider(height: 24),
            Text(
              message,
              style: const TextStyle(fontSize: 15, height: 1.4),
            ),
            if (fileUrl != null && fileUrl.isNotEmpty) ...[
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: () => _handleAttachment(fileUrl, fileName),
                  icon: const Icon(Icons.remove_red_eye_outlined, size: 18),
                  label: Text('Preview $fileName', maxLines: 1, overflow: TextOverflow.ellipsis),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blue.shade700,
                    side: BorderSide(color: Colors.blue.shade300),
                  ),
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }
}
