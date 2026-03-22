import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

import '../widgets/top_match_notification.dart';
import '../services/notification_service.dart';

import 'register_missing_person.dart';
import 'sos_page.dart';
import 'first_aid_voice_page.dart';
import 'unknown.dart';
import 'early_warning.dart';
import '../services/alert_service.dart';
import '../widgets/top_alert_notification.dart';
import 'public_notices_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final MapController mapController = MapController();
  LatLng? _currentPosition;

  // Notification state
  List notifications = [];
  bool notificationLoading = true;

  // Early Warning state
  bool showAlertBanner = false;
  int activeAlertCount = 0;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _loadNotifications();
    _checkForAlerts();
  }

  // ===================== EARLY WARNING ALERTS =====================
  Future<void> _checkForAlerts() async {
    final prefs = await SharedPreferences.getInstance();
    String? userId = prefs.getString('userId');
    if (userId == null) return;
    
    // Check if the user has active alerts for their subscribed locations
    final alerts = await AlertService.getMyAlerts(userId);
    if (!mounted) return;
    
    // In new backend, `alerts` returns ALL subscribed locations' weather
    if (alerts.isNotEmpty) {
      int dangerCount = alerts.where((a) => a['prediction'] != null && a['prediction']['alert_level'] > 0).length;
      setState(() {
        activeAlertCount = dangerCount;
        showAlertBanner = true;
      });
    }
  }

  // ===================== LOCATION =====================
  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
      });

      mapController.move(_currentPosition!, 15);
    } catch (e) {
      debugPrint("Location error: $e");
    }
  }

  void _recenterMap() {
    if (_currentPosition != null) {
      mapController.move(_currentPosition!, 15);
    }
  }

  // ===================== NOTIFICATIONS =====================
  Future<void> _loadNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? userId = prefs.getString('userId');

      if (userId == null) {
        setState(() => notificationLoading = false);
        return;
      }

      final data = await NotificationService.fetchNotifications(userId);

      setState(() {
        notifications = data;
        notificationLoading = false;
      });
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
        final unknownMobile = reportedBy["mobile"];
        if (unknownMobile != null && unknownMobile.toString().isNotEmpty) {
          return unknownMobile.toString();
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

  // ===================== UI =====================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      // ===================== DRAWER =====================
      drawer: Drawer(
        child: Column(
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: Colors.blueAccent),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Icon(Icons.volunteer_activism,
                      color: Colors.white, size: 40),
                  SizedBox(height: 10),
                  Text(
                    "Sahaya",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold),
                  ),
                  Text(
                    "Disaster & Missing Person Help",
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
            drawerItem(
              context,
              icon: Icons.home,
              title: "Home",
              onTap: () => Navigator.pop(context),
            ),
            drawerItem(
              context,
              icon: Icons.person_search,
              title: "Register Missing Person",
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const RegisterMissingPerson()),
                );
              },
            ),
            drawerItem(
              context,
              icon: Icons.person_add,
              title: "Register Unknown Person",
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const RegisterUnknownPerson()),
                );
              },
            ),
            const Spacer(),
            const Divider(),
            drawerItem(
              context,
              icon: Icons.logout,
              title: "Logout",
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),

      // ===================== BODY =====================
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 🔔 TOP MATCH NOTIFICATION
              if (!notificationLoading && notifications.isNotEmpty)
                TopMatchNotification(
                  notificationId: notifications[0]["_id"]?.toString() ?? "0",
                  personName:
                  notifications[0]["relatedMissingPerson"]?["name"] ?? "Unknown",
                  similarity: _parseSimilarity(
                      notifications[0]["relatedMatch"]?["similarity"]),
                  phone: _getContactNumber(notifications[0]),
                  onDismiss: () {
                    setState(() {
                      notifications.removeAt(0);
                    });
                  },
                ),

              if (showAlertBanner) ...[
                const SizedBox(height: 10),
                TopAlertNotification(
                  activeAlertCount: activeAlertCount,
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const EarlyWarningPage()));
                  },
                  onDismiss: () {
                    setState(() {
                      showAlertBanner = false;
                    });
                  },
                ),
              ],

              const SizedBox(height: 10),

              // -------- Top Bar --------
              Row(
                children: [
                  Builder(
                    builder: (context) => IconButton(
                      icon: const Icon(Icons.menu,
                          color: Colors.blueAccent, size: 30),
                      onPressed: () => Scaffold.of(context).openDrawer(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.waves,
                      color: Colors.blueAccent, size: 30),
                  const SizedBox(width: 8),
                  const Text(
                    "Sahaya",
                    style: TextStyle(
                      color: Colors.blueAccent,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.notifications_active, color: Colors.blueAccent, size: 28),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const PublicNoticesPage()),
                      );
                    },
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // -------- Welcome --------
              Text(
                "Welcome to Sahaya",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  foreground: Paint()
                    ..shader = const LinearGradient(
                      colors: [Colors.blueAccent, Colors.lightBlueAccent],
                    ).createShader(const Rect.fromLTWH(0, 0, 200, 70)),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                "Your lifeline for disaster relief",
                style: TextStyle(color: Colors.black54),
              ),

              const SizedBox(height: 20),

              // -------- ACTION BUTTONS --------
              primaryActionButton(
                title: "SOS Emergency",
                subtitle: "Immediate Help",
                icon: Icons.warning_rounded,
                color: Colors.red,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SosPage()),
                ),
              ),

              const SizedBox(height: 12),

              primaryActionButton(
                title: "First Aid Guide",
                subtitle: "Voice Assistant",
                icon: Icons.medical_services_rounded,
                color: Colors.blueAccent,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const FirstAidVoicePage()),
                ),
              ),

              const SizedBox(height: 20),

              // -------- MAP --------
              Container(
                height: 350,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border:
                  Border.all(color: Colors.blueAccent.withOpacity(0.5)),
                  color: Colors.grey.shade50,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    children: [
                      FlutterMap(
                        mapController: mapController,
                        options: MapOptions(
                          initialCenter:
                          _currentPosition ?? const LatLng(11.8548, 75.3484),
                          initialZoom: 15,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                            "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                            subdomains: const ['a', 'b', 'c'],
                            userAgentPackageName: 'com.example.sahaya',
                            retinaMode: true,
                          ),
                          if (_currentPosition != null)
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: _currentPosition!,
                                  width: 50,
                                  height: 50,
                                  child: const Icon(
                                    Icons.my_location,
                                    color: Colors.blueAccent,
                                    size: 40,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                      Positioned(
                        bottom: 12,
                        right: 12,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            FloatingActionButton.extended(
                              heroTag: "btn_alerts",
                              backgroundColor: Colors.redAccent,
                              icon: const Icon(Icons.warning_amber_rounded, color: Colors.white),
                              label: const Text("Subscribe to Alerts", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EarlyWarningPage())),
                            ),
                            const SizedBox(height: 10),
                            FloatingActionButton(
                              heroTag: "btn_recenter",
                              mini: true,
                              backgroundColor: Colors.blueAccent,
                              onPressed: _recenterMap,
                              child: const Icon(Icons.my_location, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===================== HELPERS =====================
  Widget drawerItem(BuildContext context,
      {required IconData icon,
        required String title,
        required VoidCallback onTap}) {
    return ListTile(
      leading: Icon(icon, color: Colors.blueAccent),
      title: Text(title),
      onTap: onTap,
    );
  }

  Widget primaryActionButton({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
        onPressed: onTap,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 26),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
