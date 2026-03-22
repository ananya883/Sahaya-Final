import 'package:flutter/material.dart';
import 'create_request_screen.dart';
import 'camp_inventory_screen.dart';
import 'donations_screen.dart';
import 'inmate_screen.dart';
import '../services/camp_session.dart';
import 'camp_manager_login.dart';
import 'public_notices_page.dart';

class CampDashboard extends StatefulWidget {
  const CampDashboard({super.key});

  @override
  State<CampDashboard> createState() => _CampDashboardState();
}

class _CampDashboardState extends State<CampDashboard> {
  String _campName = "Loading...";

  @override
  void initState() {
    super.initState();
    _loadCampInfo();
  }

  Future<void> _loadCampInfo() async {
    final campName = await CampSession.getCampName();
    setState(() {
      _campName = campName ?? "Camp Manager";
    });
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
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
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
