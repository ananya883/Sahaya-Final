import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';

class AdminVolunteerSos extends StatefulWidget {
  const AdminVolunteerSos({super.key});

  @override
  State<AdminVolunteerSos> createState() => _AdminVolunteerSosState();
}

class _AdminVolunteerSosState extends State<AdminVolunteerSos> {
  List<dynamic> _sosRequests = [];
  bool _isLoading = true;
  int _selectedFilter = -1;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiService.getVolunteerSos();
      setState(() {
        _sosRequests = data;
      });
    } catch (e) {
      debugPrint("Error loading SOS: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to load: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'resolved':    return Colors.green;
      case 'in progress': return Colors.orange;
      case 'expired':     return Colors.grey;
      default:            return Colors.red;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'resolved':    return Icons.check_circle;
      case 'in progress': return Icons.timelapse;
      case 'expired':     return Icons.block;
      default:            return Icons.warning_amber_rounded;
    }
  }

  Future<void> _expireSos(String sosId) async {
    try {
      final res = await ApiService.adminExpireSos(sosId);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        _loadData();
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to expire")));
      }
    } catch (e) {
      debugPrint("Expire error: $e");
    }
  }

  Future<void> _unexpireSos(String sosId) async {
    try {
      final res = await ApiService.adminUnexpireSos(sosId);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        _loadData();
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to unexpire")));
      }
    } catch (e) {
      debugPrint("Unexpire error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final pending    = _sosRequests.where((s) => (s['status'] ?? 'pending') == 'pending').length;
    final inProgress = _sosRequests.where((s) => s['status'] == 'in progress').length;
    final resolved   = _sosRequests.where((s) => s['status'] == 'resolved').length;
    final expired    = _sosRequests.where((s) => s['status'] == 'expired').length;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text("Volunteer & SOS Management"),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: "Refresh",
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: Column(
                children: [
                  // Stats row
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    color: Colors.white,
                    child: Row(
                      children: [
                        _statChip("Pending", pending, Colors.red, 0),
                        const SizedBox(width: 8),
                        _statChip("In Progress", inProgress, Colors.orange, 1),
                        const SizedBox(width: 8),
                        _statChip("Resolved", resolved, Colors.green, 2),
                        const SizedBox(width: 8),
                        _statChip("Expired", expired, Colors.grey, 3),
                      ],
                    ),
                  ),
                  const Divider(height: 1),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: TextField(
                      decoration: InputDecoration(
                        labelText: 'Search by Volunteer or Requester Name',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                    ),
                  ),

                  // List
                  Expanded(
                    child: Builder(builder: (context) {
                      final filteredList = _sosRequests.where((s) {
                        final status = s['status'] ?? 'pending';
                        bool matchesStatus = true;
                        
                        if (_selectedFilter == 0) matchesStatus = status == 'pending';
                        if (_selectedFilter == 1) matchesStatus = status == 'in progress';
                        if (_selectedFilter == 2) matchesStatus = status == 'resolved';
                        if (_selectedFilter == 3) matchesStatus = status == 'expired';

                        final volunteerName = (s['volunteer']?['Name'] ?? '').toString().toLowerCase();
                        final requesterName = (s['requestedBy']?['Name'] ?? '').toString().toLowerCase();
                        
                        final matchesSearch = _searchQuery.isEmpty || 
                            volunteerName.contains(_searchQuery) || 
                            requesterName.contains(_searchQuery);

                        return matchesStatus && matchesSearch;
                      }).toList();

                      return filteredList.isEmpty
                          ? const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.inbox, size: 60, color: Colors.grey),
                                  SizedBox(height: 12),
                                  Text("No SOS requests match this filter.", style: TextStyle(fontSize: 16, color: Colors.grey)),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(12),
                              itemCount: filteredList.length,
                              itemBuilder: (context, index) {
                                final sos      = filteredList[index];
                                final status   = sos['status'] ?? 'pending';
                                final requester = sos['requestedBy'];
                                final volunteer = sos['volunteer'];

                                final time = sos['timestamp'] != null
                                    ? _formatTime(sos['timestamp'].toString())
                                    : 'N/A';
                                
                                final actionImage = sos['task'] != null ? sos['task']['actionImage'] : null;

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  elevation: 2,
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Header
                                        Row(
                                          children: [
                                            Icon(_statusIcon(status), color: _statusColor(status), size: 22),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                "${sos['emergency_type'] ?? 'Emergency'}"
                                                "${(sos['disaster_type'] ?? '').isNotEmpty ? '  •  ${sos['disaster_type']}' : ''}",
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: _statusColor(status).withOpacity(0.12),
                                                border: Border.all(color: _statusColor(status)),
                                                borderRadius: BorderRadius.circular(20),
                                              ),
                                              child: Text(
                                                status.toUpperCase(),
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: _statusColor(status),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const Divider(height: 18),

                                        // Requester
                                        _infoRow(Icons.person_outline, "Requested by",
                                            requester != null ? (requester['Name'] ?? 'Unknown') : 'Unknown'),
                                        if (requester != null && requester['mobile'] != null)
                                          _infoRow(Icons.phone_outlined, "Contact", requester['mobile']),

                                        // Location
                                        if (sos['latitude'] != null)
                                          _infoRow(Icons.location_on_outlined, "Location",
                                              "Lat: ${sos['latitude']}, Lng: ${sos['longitude']}"),

                                        // Time
                                        _infoRow(Icons.access_time, "Time", time),

                                        // Volunteer
                                        _infoRow(
                                          Icons.volunteer_activism,
                                          "Volunteer",
                                          volunteer != null
                                              ? "${volunteer['Name']} (${volunteer['mobile'] ?? 'N/A'})"
                                              : 'Not assigned yet',
                                          color: volunteer != null ? Colors.green.shade700 : Colors.grey,
                                        ),

                                        // Evidence Image
                                        if (actionImage != null && actionImage.toString().isNotEmpty) ...[
                                          const SizedBox(height: 10),
                                          OutlinedButton.icon(
                                            onPressed: () async {
                                              final url = Uri.parse(actionImage);
                                              if (await canLaunchUrl(url)) {
                                                await launchUrl(url, mode: LaunchMode.externalApplication);
                                              }
                                            },
                                            icon: const Icon(Icons.image, size: 16),
                                            label: const Text("View Resolution Evidence"),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: Colors.blue.shade700,
                                              side: BorderSide(color: Colors.blue.shade300),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)
                                            ),
                                          ),
                                        ],

                                        // Actions
                                        if (status != 'resolved' && status != 'in progress') ...[
                                          const SizedBox(height: 10),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.end,
                                            children: [
                                              if (status != 'expired')
                                                TextButton.icon(
                                                  onPressed: () => _expireSos(sos['_id']),
                                                  icon: const Icon(Icons.block, size: 16),
                                                  label: const Text("Mark Expired"),
                                                  style: TextButton.styleFrom(foregroundColor: Colors.grey),
                                                ),
                                              if (status == 'expired')
                                                TextButton.icon(
                                                  onPressed: () => _unexpireSos(sos['_id']),
                                                  icon: const Icon(Icons.restore, size: 16),
                                                  label: const Text("Undo Expired"),
                                                  style: TextButton.styleFrom(foregroundColor: Colors.blue),
                                                ),
                                            ],
                                          )
                                        ]
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );
                    }),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _statChip(String label, int count, Color color, int index) {
    final bool isActive = _selectedFilter == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedFilter = isActive ? -1 : index; 
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? color.withOpacity(0.25) : color.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isActive ? color : color.withOpacity(0.2), width: isActive ? 2 : 1),
          ),
          child: Column(
            children: [
              Text("$count", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
              Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: isActive ? FontWeight.bold : FontWeight.normal), textAlign: TextAlign.center, maxLines: 1),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: color ?? Colors.grey),
          const SizedBox(width: 6),
          Text("$label: ", style: const TextStyle(fontSize: 13, color: Colors.grey)),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 13, color: color ?? Colors.black87, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(String isoString) {
    try {
      final dt = DateTime.parse(isoString).toLocal();
      return "${dt.day}/${dt.month}/${dt.year}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
    } catch (_) {
      return isoString;
    }
  }
}
