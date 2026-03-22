import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class VolunteerProfile extends StatefulWidget {
  const VolunteerProfile({super.key});

  @override
  State<VolunteerProfile> createState() => _VolunteerProfileState();
}

class _VolunteerProfileState extends State<VolunteerProfile> {
  String _userName = "Volunteer";
  String _userEmail = "";
  String _userMobile = "";
  List<dynamic> _resolvedRequests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUser();
    _loadData();
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userName = prefs.getString('userName') ?? "Volunteer";
      _userEmail = prefs.getString('email') ?? "";
      _userMobile = prefs.getString('mobile') ?? "";
    });
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final volunteerId = prefs.getString('userId');

      final data = await ApiService.getVolunteerSos();
      setState(() {
        _resolvedRequests = data.where((s) => 
          s['status'] == 'resolved' && 
          s['volunteer'] != null && 
          s['volunteer']['_id'] == volunteerId
        ).toList();
      });
    } catch (e) {
      debugPrint("Error loading profile resolved SOS: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text("My Profile"),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   // Profile Info
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          const CircleAvatar(
                            radius: 40,
                            backgroundColor: Colors.green,
                            child: Icon(Icons.person, size: 40, color: Colors.white),
                          ),
                          const SizedBox(height: 12),
                          Text(_userName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          Text(_userEmail, style: const TextStyle(fontSize: 16, color: Colors.grey)),
                          const SizedBox(height: 4),
                          Text(_userMobile, style: const TextStyle(fontSize: 16, color: Colors.grey)),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                  const Text("Resolved SOS Requests", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),

                  _resolvedRequests.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.only(top: 20),
                          child: Center(
                            child: Text("You haven't resolved any requests yet.", style: TextStyle(color: Colors.grey, fontSize: 16)),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _resolvedRequests.length,
                          itemBuilder: (context, index) {
                            final sos = _resolvedRequests[index];
                            final requester = sos['requestedBy'];
                            final requesterName = requester != null ? (requester['Name'] ?? 'Unknown User') : 'Unknown User';

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(12),
                                leading: const Icon(Icons.check_circle, color: Colors.green, size: 36),
                                title: Text(
                                  "${sos['emergency_type'] ?? 'Emergency'}"
                                  "${(sos['disaster_type'] ?? '').toString().isNotEmpty ? ' • ${sos['disaster_type']}' : ''}",
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text("Requested by: $requesterName"),
                                    if (sos['latitude'] != null)
                                      Text("Lat: ${sos['latitude']}, Lng: ${sos['longitude']}"),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ],
              ),
            ),
    );
  }
}
