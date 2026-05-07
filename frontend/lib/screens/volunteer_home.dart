import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'login.dart';
import 'volunteer_profile.dart';
import 'public_notices_page.dart';
import '../services/api_service.dart';

class VolunteerHome extends StatefulWidget {
  const VolunteerHome({super.key});

  @override
  State<VolunteerHome> createState() => _VolunteerHomeState();
}

class _VolunteerHomeState extends State<VolunteerHome> {
  String _userName = "Volunteer";
  List<dynamic> _sosRequests = [];
  bool _isLoading = true;
  String? _volunteerId;
  int _selectedTab = 0; // 0 = Pending, 1 = My Tasks, 2 = Expired

  @override
  void initState() {
    super.initState();
    _loadUser();
    _loadData();
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userName    = prefs.getString('userName') ?? "Volunteer";
      _volunteerId = prefs.getString('userId');
    });
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiService.getVolunteerSos();
      setState(() => _sosRequests = data);
    } catch (e) {
      debugPrint("Error loading SOS: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to load requests: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _acceptSos(String sosId) async {
    if (_volunteerId == null) return;
    try {
      final res = await ApiService.acceptSos(sosId, _volunteerId!);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        _loadData();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Failed to accept — already taken?"), backgroundColor: Colors.orange),
          );
        }
      }
    } catch (e) {
      debugPrint("Accept error: $e");
    }
  }

  Future<void> _resolveSos(String sosId) async {
    // Prompt the user if they want to upload evidence
    final bool? attachEvidence = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Resolve SOS"),
        content: const Text("Would you like to attach a photo showing the resolution of this emergency?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("No, just resolve"),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.camera_alt, size: 18),
            label: const Text("Attach Photo"),
          ),
        ],
      )
    );

    if (attachEvidence == null) return; // User cancelled

    File? evidenceImage;
    if (attachEvidence) {
      final picker = ImagePicker();
      final XFile? pickedMode = await picker.pickImage(source: ImageSource.camera);
      if (pickedMode == null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No image selected")));
        return; // User cancelled the camera
      }
      if (pickedMode != null) {
        evidenceImage = File(pickedMode.path);
      }
    }

    setState(() => _isLoading = true);
    try {
      final res = await ApiService.resolveSos(sosId, actionImage: evidenceImage);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Resolved successfully!", style: TextStyle(color: Colors.white)), backgroundColor: Colors.green));
        _loadData();
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to resolve.", style: TextStyle(color: Colors.white)), backgroundColor: Colors.red));
      }
    } catch (e) {
      debugPrint("Resolve error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (route) => false,
      );
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'resolved':    return Colors.green;
      case 'in progress': return Colors.orange;
      default:            return Colors.red;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'resolved':    return Icons.check_circle;
      case 'in progress': return Icons.timelapse;
      default:            return Icons.warning_amber_rounded;
    }
  }

  // --------- Open full-screen map for a specific SOS ---------
  void _openSosMap(Map<String, dynamic> sos) {
    final lat = sos['latitude'];
    final lng = sos['longitude'];
    if (lat == null || lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No location data available for this SOS"), backgroundColor: Colors.orange),
      );
      return;
    }

    final sosLocation = LatLng((lat is int ? lat.toDouble() : lat as double), (lng is int ? lng.toDouble() : lng as double));
    final status      = sos['status'] ?? 'pending';
    final emergency   = sos['emergency_type'] ?? 'Emergency';
    final disaster    = sos['disaster_type'] ?? '';
    final requester   = sos['requestedBy'];
    final requesterName = requester != null ? (requester['Name'] ?? 'Unknown') : 'Unknown';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _SosMapScreen(
          sosLocation: sosLocation,
          emergency: emergency,
          disaster: disaster,
          status: status,
          requesterName: requesterName,
        ),
      ),
    );
  }

  // --------- Open Google Maps for turn-by-turn navigation ---------
  Future<void> _openInGoogleMaps(double lat, double lng) async {
    final url = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving');
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not open Google Maps"), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text("Volunteer Dashboard"),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_active),
            tooltip: "Public Notices",
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const PublicNoticesPage()));
            },
          ),
          IconButton(
            icon: const Icon(Icons.person),
            tooltip: "Profile",
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VolunteerProfile())),
          ),
          IconButton(icon: const Icon(Icons.refresh), tooltip: "Refresh", onPressed: _loadData),
          IconButton(icon: const Icon(Icons.logout),  tooltip: "Logout",  onPressed: _logout),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Welcome banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [Colors.green.shade700, Colors.green.shade400]),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Welcome, $_userName 👋",
                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(
                        "${_sosRequests.where((s) => (s['status'] ?? 'pending') == 'pending').length} pending SOS request(s)",
                        style: const TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                    ],
                  ),
                ),

                // Tabs / Filters
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Text("Pending"),
                          selected: _selectedTab == 0,
                          onSelected: (val) { if (val) setState(() => _selectedTab = 0); },
                          selectedColor: Colors.green.shade200,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: const Text("My Tasks"),
                          selected: _selectedTab == 1,
                          onSelected: (val) { if (val) setState(() => _selectedTab = 1); },
                          selectedColor: Colors.green.shade200,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: const Text("Expired"),
                          selected: _selectedTab == 2,
                          onSelected: (val) { if (val) setState(() => _selectedTab = 2); },
                          selectedColor: Colors.green.shade200,
                        ),
                      ),
                    ],
                  ),
                ),

                // SOS list
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _loadData,
                    child: Builder(
                      builder: (context) {
                        final filteredRequests = _sosRequests.where((sos) {
                          final status = sos['status'] ?? 'pending';
                          final isMyTask = sos['volunteer'] != null && sos['volunteer']['_id'] == _volunteerId;
                          if (_selectedTab == 0) return status == 'pending';
                          if (_selectedTab == 1) return isMyTask && status == 'in progress';
                          if (_selectedTab == 2) return status == 'expired';
                          return true;
                        }).toList();

                        if (filteredRequests.isEmpty) {
                          return const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.inbox, size: 60, color: Colors.grey),
                                SizedBox(height: 12),
                                Text("No requests match this filter.", style: TextStyle(fontSize: 16)),
                              ],
                            ),
                          );
                        }

                        return ListView.builder(
                            padding: const EdgeInsets.all(12),
                            itemCount: filteredRequests.length,
                            itemBuilder: (context, index) {
                              final sos      = filteredRequests[index];
                              final status   = sos['status'] ?? 'pending';
                              final isMyTask = sos['volunteer'] != null && sos['volunteer']['_id'] == _volunteerId;
                              final hasLocation = sos['latitude'] != null && sos['longitude'] != null;

                              final requester       = sos['requestedBy'];
                              final requesterName   = requester != null ? (requester['Name'] ?? 'Unknown User') : 'Unknown User';
                              final requesterMobile = requester != null ? (requester['mobile'] ?? '') : '';

                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 2,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: hasLocation ? () => _openSosMap(sos) : null,
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Header row
                                        Row(
                                          children: [
                                            Icon(_statusIcon(status), color: _statusColor(status), size: 22),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                "${sos['emergency_type'] ?? 'Emergency'}"
                                                "${(sos['disaster_type'] ?? '').toString().isNotEmpty ? '  •  ${sos['disaster_type']}' : ''}",
                                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: _statusColor(status).withOpacity(0.12),
                                                border: Border.all(color: _statusColor(status)),
                                                borderRadius: BorderRadius.circular(20),
                                              ),
                                              child: Text(status.toUpperCase(),
                                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _statusColor(status))),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),

                                        // Requester
                                        Row(children: [
                                          const Icon(Icons.person, size: 15, color: Colors.grey),
                                          const SizedBox(width: 5),
                                          Text("Requested by: $requesterName", style: const TextStyle(fontSize: 13)),
                                        ]),
                                        if (requesterMobile.toString().isNotEmpty) ...[
                                          const SizedBox(height: 3),
                                          Row(children: [
                                            const Icon(Icons.phone, size: 15, color: Colors.grey),
                                            const SizedBox(width: 5),
                                            Text(requesterMobile.toString(), style: const TextStyle(fontSize: 13)),
                                          ]),
                                        ],

                                        // Location + map hint
                                        if (hasLocation) ...[
                                          const SizedBox(height: 3),
                                          Row(children: [
                                            const Icon(Icons.location_on, size: 15, color: Colors.grey),
                                            const SizedBox(width: 5),
                                            Text("Lat: ${sos['latitude']}, Lng: ${sos['longitude']}", style: const TextStyle(fontSize: 13)),
                                          ]),

                                          // Mini map preview
                                          const SizedBox(height: 10),
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(10),
                                            child: SizedBox(
                                              height: 150,
                                              width: double.infinity,
                                              child: IgnorePointer(
                                                child: FlutterMap(
                                                  options: MapOptions(
                                                    initialCenter: LatLng(
                                                      (sos['latitude'] is int ? (sos['latitude'] as int).toDouble() : sos['latitude'] as double),
                                                      (sos['longitude'] is int ? (sos['longitude'] as int).toDouble() : sos['longitude'] as double),
                                                    ),
                                                    initialZoom: 15,
                                                  ),
                                                  children: [
                                                    TileLayer(
                                                      urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                                                      subdomains: const ['a', 'b', 'c'],
                                                    ),
                                                    MarkerLayer(
                                                      markers: [
                                                        Marker(
                                                          point: LatLng(
                                                            (sos['latitude'] is int ? (sos['latitude'] as int).toDouble() : sos['latitude'] as double),
                                                            (sos['longitude'] is int ? (sos['longitude'] as int).toDouble() : sos['longitude'] as double),
                                                          ),
                                                          width: 40, height: 40,
                                                          child: const Icon(Icons.location_on, color: Colors.red, size: 36),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),

                                          // Navigate & View Map buttons
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: OutlinedButton.icon(
                                                  onPressed: () => _openSosMap(sos),
                                                  icon: const Icon(Icons.map, size: 16),
                                                  label: const Text("View Map", style: TextStyle(fontSize: 12)),
                                                  style: OutlinedButton.styleFrom(
                                                    foregroundColor: Colors.blue.shade700,
                                                    side: BorderSide(color: Colors.blue.shade300),
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: OutlinedButton.icon(
                                                  onPressed: () => _openInGoogleMaps(
                                                    (sos['latitude'] is int ? (sos['latitude'] as int).toDouble() : sos['latitude'] as double),
                                                    (sos['longitude'] is int ? (sos['longitude'] as int).toDouble() : sos['longitude'] as double),
                                                  ),
                                                  icon: const Icon(Icons.navigation, size: 16),
                                                  label: const Text("Navigate", style: TextStyle(fontSize: 12)),
                                                  style: OutlinedButton.styleFrom(
                                                    foregroundColor: Colors.green.shade700,
                                                    side: BorderSide(color: Colors.green.shade300),
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],

                                        // Assigned volunteer
                                        if (sos['volunteer'] != null) ...[
                                          const SizedBox(height: 5),
                                          Row(children: [
                                            const Icon(Icons.volunteer_activism, size: 15, color: Colors.green),
                                            const SizedBox(width: 5),
                                            Text("Accepted by: ${sos['volunteer']['Name']}",
                                                style: const TextStyle(fontSize: 13, color: Colors.green)),
                                          ]),
                                        ],

                                        // Action buttons
                                        if (status == 'pending' || (status == 'in progress' && isMyTask)) ...[
                                          const SizedBox(height: 12),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.end,
                                            children: [_buildActionButton(sos['_id'], status, isMyTask)],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                      },
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildActionButton(String sosId, String status, bool isMyTask) {
    if (status == 'pending') {
      return ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green.shade700, foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: () => _acceptSos(sosId),
        icon: const Icon(Icons.check, size: 18),
        label: const Text("Accept"),
      );
    } else if (status == 'in progress' && isMyTask) {
      return ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue.shade700, foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: () => _resolveSos(sosId),
        icon: const Icon(Icons.done_all, size: 18),
        label: const Text("Mark Resolved"),
      );
    }
    return const SizedBox();
  }
}


// ============================================================
// Full-screen Map View for a single SOS location
// ============================================================
class _SosMapScreen extends StatelessWidget {
  final LatLng sosLocation;
  final String emergency;
  final String disaster;
  final String status;
  final String requesterName;

  const _SosMapScreen({
    required this.sosLocation,
    required this.emergency,
    required this.disaster,
    required this.status,
    required this.requesterName,
  });

  Future<void> _navigate() async {
    final url = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=${sosLocation.latitude},${sosLocation.longitude}&travelmode=driving');
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint("Could not launch maps: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = disaster.isNotEmpty ? "$emergency • $disaster" : emergency;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          // Full-screen map
          FlutterMap(
            options: MapOptions(
              initialCenter: sosLocation,
              initialZoom: 16,
            ),
            children: [
              TileLayer(
                urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                subdomains: const ['a', 'b', 'c'],
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: sosLocation,
                    width: 60,
                    height: 60,
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text("SOS", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                        const Icon(Icons.location_on, color: Colors.red, size: 34),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Info card at bottom
          Positioned(
            left: 16, right: 16, bottom: 24,
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Row(children: [
                      const Icon(Icons.person, size: 16, color: Colors.grey),
                      const SizedBox(width: 6),
                      Text("Requested by: $requesterName", style: const TextStyle(fontSize: 14)),
                    ]),
                    const SizedBox(height: 4),
                    Row(children: [
                      const Icon(Icons.location_on, size: 16, color: Colors.grey),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          "${sosLocation.latitude.toStringAsFixed(6)}, ${sosLocation.longitude.toStringAsFixed(6)}",
                          style: const TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 14),

                    // Navigate button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _navigate,
                        icon: const Icon(Icons.navigation_rounded),
                        label: const Text("Open in Google Maps & Navigate", style: TextStyle(fontSize: 15)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
