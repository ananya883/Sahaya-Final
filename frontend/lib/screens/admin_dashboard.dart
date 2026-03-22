import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/admin_session.dart';
import 'admin_create_camp.dart';
import 'admin_disaster_list.dart';
import 'admin_volunteer_sos.dart';
import 'admin_donation_reports.dart';
import 'admin_public_notices.dart';
import 'public_notices_page.dart';
import 'role_selection.dart';
import '../services/api_config.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  List<Map<String, dynamic>> camps = [];
  List<Map<String, dynamic>> users = [];
  bool isLoading = true;
  bool isLoadingUsers = true;

  @override
  void initState() {
    super.initState();
    _loadCamps();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() {
      isLoadingUsers = true;
    });

    try {
      final response = await http.get(
        Uri.parse(ApiConfig.adminUsers),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          users = data.cast<Map<String, dynamic>>();
          isLoadingUsers = false;
        });
      } else {
        throw Exception("Failed to load users");
      }
    } catch (e) {
      setState(() {
        isLoadingUsers = false;
      });
      debugPrint("Error loading users: $e");
    }
  }

  Future<void> _loadCamps() async {
    setState(() {
      isLoading = true;
    });

    try {
      final response = await http.get(
        Uri.parse(ApiConfig.adminCamps),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          camps = data.cast<Map<String, dynamic>>();
          isLoading = false;
        });
      } else {
        throw Exception("Failed to load camps");
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error loading camps: $e")),
        );
      }
    }
  }

  Future<void> _logout() async {
    await AdminSession.clearSession();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
    );
  }

  void _showCredentialsDialog(Map<String, dynamic> camp) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.blue),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                camp["campName"] ?? "Camp Details",
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow("Camp ID", camp["campId"]),
              _buildDetailRow("Camp Name", camp["campName"]),
              _buildDetailRow("Manager", camp["managerName"]),
              _buildDetailRow("Location", camp["location"] ?? "N/A"),
              _buildDetailRow("Contact", camp["contactNumber"] ?? "N/A"),
              const Divider(height: 24),
              const Text(
                "Login Credentials:",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              _buildDetailRow("Email", camp["email"]),
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  border: Border.all(color: Colors.red, width: 2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lock, color: Colors.red, size: 20),
                    const SizedBox(width: 10),
                    const Text(
                      "Password: ",
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const Text(
                      "Stored in database",
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              "$label:",
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value ?? "N/A",
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Admin Dashboard"),
          centerTitle: true,
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: const Icon(Icons.notifications_active),
              tooltip: "View Notices",
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PublicNoticesPage()),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.campaign_outlined),
              tooltip: "Broadcast Notice",
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminPublicNotices()),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: _logout,
              tooltip: "Logout",
            ),
          ],
          bottom: const TabBar(
            indicatorColor: Colors.white,
            tabs: [
              Tab(icon: Icon(Icons.campaign), text: "Camps"),
              Tab(icon: Icon(Icons.people), text: "Users"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildCampsTab(),
            _buildUsersTab(),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AdminCreateCamp()),
            );
            _loadCamps();
          },
          backgroundColor: Colors.red,
          icon: const Icon(Icons.add),
          label: const Text("Add New Camp"),
        ),
      ),
    );
  }

  Widget _buildCampsTab() {
    return isLoading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
      onRefresh: _loadCamps,
      child: SingleChildScrollView(
        child: Column(
          children: [
            // Disaster Management card
            Container(
              margin: const EdgeInsets.all(16),
              child: Card(
                elevation: 4,
                color: Colors.red.shade50,
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AdminDisastersList(),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.warning_amber,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Disaster Management',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Register and manage disasters',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios, size: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Card(
                elevation: 4,
                color: Colors.green.shade50,
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AdminVolunteerSos(),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.volunteer_activism,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Volunteer & SOS Management',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'View SOS requests and assigned volunteers',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios, size: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Donation Reports card
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Card(
                elevation: 4,
                color: Colors.green.shade50,
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AdminDonationReports(),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.shade600,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.bar_chart,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Donation Reports',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'View inventory & money donation details',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios, size: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  Text(
                    'Registered Camps',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            camps.isEmpty
                ? const Padding(
              padding: EdgeInsets.all(32),
              child: Text('No camps registered yet'),
            )
                : ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: camps.length,
              itemBuilder: (context, index) {
                final camp = camps[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.red,
                      child: Text(
                        camp["campId"].toString().length > 4 
                          ? camp["campId"].toString().substring(camp["campId"].toString().length - 2)
                          : camp["campId"].toString(),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    title: Text(
                      camp["campName"] ?? "Unknown",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Manager: ${camp['managerName']}"),
                        Text("Email: ${camp['email']}"),
                        Text("Location: ${camp['location'] ?? 'N/A'}"),
                      ],
                    ),
                    isThreeLine: true,
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      _showCredentialsDialog(camp);
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsersTab() {
    return isLoadingUsers
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
      onRefresh: _loadUsers,
      child: users.isEmpty
          ? const Center(child: Text("No users registered yet"))
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: users.length,
        itemBuilder: (context, index) {
          final user = users[index];
          final List<dynamic> roles = user['roles'] ?? ['user'];
          
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.blue,
                child: Icon(Icons.person, color: Colors.white),
              ),
              title: Text(
                user["Name"] ?? "Unknown",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Email: ${user['email']}"),
                  Text("Phone: ${user['mobile']}"),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 4,
                    children: roles.map((role) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getRoleColor(role.toString()).withOpacity(0.1),
                        border: Border.all(color: _getRoleColor(role.toString())),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        role.toString().toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: _getRoleColor(role.toString()),
                        ),
                      ),
                    )).toList(),
                  ),
                ],
              ),
              isThreeLine: true,
              onTap: () {
                _showUserDetails(user);
              },
            ),
          );
        },
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'volunteer': return Colors.green;
      case 'donor': return Colors.orange;
      case 'admin': return Colors.red;
      default: return Colors.blue;
    }
  }

  void _showUserDetails(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(user["Name"] ?? "User Details"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow("Email", user["email"]),
              _buildDetailRow("Mobile", user["mobile"]),
              _buildDetailRow("Gender", user["gender"]),
              _buildDetailRow("DOB", user["dob"]),
              _buildDetailRow("Address", user["address"]),
              _buildDetailRow("House No", user["houseNo"]),
              const Divider(),
              const Text("Roles:", style: TextStyle(fontWeight: FontWeight.bold)),
              Text(user["roles"]?.join(", ") ?? "user"),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }
}
