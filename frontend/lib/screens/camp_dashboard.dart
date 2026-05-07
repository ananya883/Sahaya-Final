import 'package:flutter/material.dart';
import 'create_request_screen.dart';
import 'camp_inventory_screen.dart';
import 'donations_screen.dart';
import 'inmate_screen.dart';
import '../services/camp_session.dart';
import 'camp_manager_login.dart';
import 'public_notices_page.dart';
import 'unknown.dart';
import '../services/notification_service.dart';
import '../widgets/top_match_notification.dart';

class CampDashboard extends StatefulWidget {
  const CampDashboard({super.key});

  @override
  State<CampDashboard> createState() => _CampDashboardState();
}

class _CampDashboardState extends State<CampDashboard> {
  String _campName = "Loading...";
  String? _campId;
  List notifications = [];
  bool notificationLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCampInfo();
  }

  Future<void> _loadCampInfo() async {
    final campName = await CampSession.getCampName();
    final campId = await CampSession.getCampId();
    setState(() {
      _campName = campName ?? "Camp Manager";
      _campId = campId;
    });

    if (campId != null) {
      _loadNotifications(campId);
    } else {
      setState(() => notificationLoading = false);
    }
  }

  Future<void> _loadNotifications(String campId, {bool repeat = false}) async {
    try {
      final data = await NotificationService.fetchCampNotifications(campId);
      setState(() {
        notifications = data;
        notificationLoading = false;
      });
      
      // If repeat is true, poll for 10 seconds to catch async background matches
      if (repeat) {
        for (int i = 0; i < 10; i++) {
          await Future.delayed(const Duration(seconds: 1));
          if (!mounted) return;
          final newData = await NotificationService.fetchCampNotifications(campId);
          if (newData.length > notifications.length) {
            setState(() => notifications = newData);
            break; // Stop polling if new notification found
          }
        }
      }
    } catch (e) {
      debugPrint("Notification error: $e");
      setState(() => notificationLoading = false);
    }
  }

  // Helper to safely parse similarity value
  double _parseSimilarity(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  // Helper to get the correct contact number from notification
  String _getContactNumber(Map<String, dynamic> notification) {
    final unknownPerson = notification["relatedUnknownPerson"];
    if (unknownPerson != null) {
      final reportedBy = unknownPerson["reportedBy"];
      if (reportedBy != null) {
        final contactMobile = reportedBy["contactNumber"];
        if (contactMobile != null && contactMobile.toString().isNotEmpty) {
          return contactMobile.toString();
        }
      }
    }

    final missingPerson = notification["relatedMissingPerson"];
    if (missingPerson != null) {
      final registeredBy = missingPerson["registeredBy"];
      if (registeredBy != null) {
        final missingMobile = registeredBy["mobile"];
        if (missingMobile != null && missingMobile.toString().isNotEmpty) {
          return missingMobile.toString();
        }
      }
    }
    return "N/A";
  }

  Future<void> _logout() async {
    await CampSession.clearSession();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const CampManagerLoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_campName),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_active),
            tooltip: "Public Notices",
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const PublicNoticesPage()));
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: "Logout",
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // 🔔 TOP MATCH NOTIFICATION
            if (!notificationLoading)
              ...notifications
                  .where((n) =>
                      n["type"] == "match" &&
                      n["relatedMissingPerson"] != null &&
                      n["relatedMatch"] != null)
                  .take(1)
                  .map((matchNotif) {
                return TopMatchNotification(
                  notificationId: matchNotif["_id"]?.toString() ?? "0",
                  personName: matchNotif["relatedMissingPerson"]?["name"] ?? "Unknown",
                  similarity: _parseSimilarity(matchNotif["relatedMatch"]?["similarity"]),
                  phone: _getContactNumber(matchNotif),
                  onDismiss: () {
                    setState(() {
                      notifications.remove(matchNotif);
                    });
                  },
                );
              }),

            const SizedBox(height: 10),
            _dashboardCard(
              context,
              icon: Icons.add_box,
              title: "Create Request",
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CreateRequestScreen(),
                ),
              ),
            ),
            _dashboardCard(
              context,
              icon: Icons.inventory,
              title: "Camp Inventory",
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CampInventoryScreen(),
                ),
              ),
            ),
            _dashboardCard(
              context,
              icon: Icons.volunteer_activism,
              title: "Donations Received",
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const DonationsScreen(),
                ),
              ),
            ),
            _dashboardCard(
              context,
              icon: Icons.person_add,
              title: "Register Unknown Person",
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const RegisterUnknownPerson(),
                ),
              ).then((value) {
                if (value == true && _campId != null) {
                  _loadNotifications(_campId!, repeat: true);
                }
              }),
            ),
            _dashboardCard(
              context,
              icon: Icons.people,
              title: "Inmates Registration",
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const InmatesScreen(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dashboardCard(
      BuildContext context, {
        required IconData icon,
        required String title,
        required VoidCallback onTap,
      }) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(20),
        leading: Icon(icon, size: 32, color: Theme.of(context).primaryColor),
        title: Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 18),
        onTap: onTap,
      ),
    );
  }
}
