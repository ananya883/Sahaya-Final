import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'donate_money.dart';
import 'donate_money.dart';
import 'donation_history.dart';
import 'public_notices_page.dart';
import '../services/api_service.dart';

const Color primaryColor = Color(0xFF1E88E5);
const double headerHeight = 200;

// ---------------- HEADER CLIPPER ----------------
class CustomHeaderClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    path.lineTo(0, size.height - 50);
    path.quadraticBezierTo(
      size.width / 2,
      size.height,
      size.width,
      size.height - 50,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

// ---------------- DONOR DASHBOARD ----------------
class DonorDashboard extends StatefulWidget {
  const DonorDashboard({super.key});

  @override
  State<DonorDashboard> createState() => _DonorDashboardState();
}

class _DonorDashboardState extends State<DonorDashboard> {
  String? selectedCampId; // null = "All Camps"
  String _donorName = "Anonymous"; // Loaded from session

  List<Map<String, dynamic>> camps = [];
  List<Map<String, dynamic>> allRequests = [];
  List<Map<String, dynamic>> filteredRequests = [];

  bool isLoadingCamps = true;
  bool isLoadingRequests = true;

  @override
  void initState() {
    super.initState();
    _loadDonorName();
    fetchCamps();
    fetchRequests();
  }

  Future<void> _loadDonorName() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('userName');
    if (name != null && name.isNotEmpty) {
      setState(() => _donorName = name);
    }
  }

  Future<void> fetchCamps() async {
    try {
      final data = await ApiService.getCamps();
      debugPrint("DonorDashboard: Fetched ${data.length} camps");
      setState(() {
        camps = data.map((c) => {
          "campId": c["campId"],
          "campName": c["campName"] ?? "Unknown",
          "location": c["location"] ?? "",
        }).toList().cast<Map<String, dynamic>>();
        isLoadingCamps = false;
        filterRequests(); // Re-filter once camps are loaded
      });
    } catch (e) {
      debugPrint("DonorDashboard: Camps error: $e");
      setState(() {
        isLoadingCamps = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error fetching camps: $e")),
        );
      }
    }
  }

  Future<void> fetchRequests() async {
    try {
      final data = await ApiService.getCampRequests();
      debugPrint("DonorDashboard: Fetched ${data.length} requests");
      setState(() {
        allRequests = data.map((r) {
          final required = r["requiredQty"] ?? 0;
          final remaining = r["remainingQty"] ?? 0;
          final current = required - remaining;

          // Format date
          String updated = "Recently";
          if (r["updatedAt"] != null) {
            final date = DateTime.parse(r["updatedAt"]);
            updated = "${date.day}/${date.month}/${date.year}";
          }

          return {
            "id": r["_id"], // Keep ID for donation
            "item": r["itemName"] ?? "Unknown",
            "category": r["category"] ?? "General",
            "priority": r["priority"] ?? "Medium",
            "required": required,
            "current": current,
            "unit": r["unit"] ?? "units",
            "updated": updated,
            "campId": r["campId"], // Store campId for filtering
            "campName": r["campName"] ?? "Unknown Camp",
            "location": r["location"] ?? "Unknown"
          };
        }).toList().cast<Map<String, dynamic>>();

        filterRequests(); // Apply initial filter
        isLoadingRequests = false;
      });
    } catch (e) {
      setState(() {
        isLoadingRequests = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error fetching requests: $e")),
        );
      }
    }
  }

  void filterRequests() {
    setState(() {
      if (selectedCampId == null) {
        // Show all requests
        filteredRequests = List.from(allRequests);
      } else {
        // Show requests for selected camp only
        filteredRequests = allRequests
            .where((r) => r["campId"]?.toString() == selectedCampId.toString())
            .toList();
      }
      debugPrint("DonorDashboard: Filtered ${filteredRequests.length} out of ${allRequests.length} requests (Selected Camp: $selectedCampId)");
    });
  }

  void _showDonateDialog(Map<String, dynamic> request) {
    final TextEditingController qtyController = TextEditingController();
    final int remaining = request["required"] - request["current"];
    final String unit = request["unit"];

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Donate ${request['item']}"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Required: $remaining $unit"),
              const SizedBox(height: 10),
              TextField(
                controller: qtyController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: "Quantity to Donate",
                  suffixText: unit,
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                final String input = qtyController.text.trim();
                if (input.isEmpty) return;

                final int? qty = int.tryParse(input);
                if (qty == null || qty <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Please enter a valid quantity")),
                  );
                  return;
                }

                if (qty > remaining) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Quantity exceeds requirement")),
                  );
                  return;
                }

                Navigator.pop(context); // Close dialog

                // Call API
                try {
                  await ApiService.donateItem(request["id"], qty, _donorName);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Donation successful! Thank you.")),
                  );
                  fetchRequests(); // Refresh list
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Error: $e")),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
              child: const Text("Donate", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  // ---------- DEFAULT CAMPS ----------

  // ---------------- HEADER ----------------
  Widget buildHeader() {
    return Stack(
      children: [
        ClipPath(
          clipper: CustomHeaderClipper(),
          child: Container(
            height: headerHeight,
            color: primaryColor,
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.volunteer_activism, color: Colors.white, size: 50),
                SizedBox(height: 10),
                Text(
                  "Donate Now",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          top: 40,
          right: 16,
          child: IconButton(
            icon: const Icon(Icons.notifications_active, color: Colors.white, size: 28),
            tooltip: "Public Notices",
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const PublicNoticesPage()));
            },
          ),
        ),
      ],
    );
  }

  // ---------------- TAG BADGE ----------------
  Widget tag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // ---------------- REQUEST CARD ----------------
  Widget requestCard(Map<String, dynamic> r) {
    final remaining = r["required"] - r["current"];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFF),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 6,
            offset: Offset(0, 3),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                r["item"],
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                children: [
                  tag(r["category"], Colors.orange),
                  const SizedBox(width: 6),
                  tag(
                    r["priority"],
                    r["priority"] == "High"
                        ? Colors.red
                        : Colors.orange,
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Camp Name with Location
          Row(
            children: [
              const Icon(Icons.location_on, size: 16, color: Colors.grey),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  "${r['campName']} - ${r['location']}",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Current: ${r["current"]} ${r["unit"]}"),
              Text("Required: ${r["required"]} ${r["unit"]}"),
            ],
          ),


          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Remaining: $remaining ${r["unit"]}",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Last updated: ${r["updated"]}",
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
              ElevatedButton(
                onPressed: () => _showDonateDialog(r),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                child: const Text("Donate", style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------- MAIN UI ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          buildHeader(),
          Padding(
            padding: const EdgeInsets.only(top: headerHeight - 30),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),

                  // CAMP DROPDOWN
                  if (isLoadingCamps)
                    const Center(child: CircularProgressIndicator())
                  else
                    DropdownButtonFormField<String?>(
                      value: selectedCampId,
                      decoration: InputDecoration(
                        labelText: "Filter by Camp",
                        prefixIcon: const Icon(Icons.filter_list),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text("All Camps"),
                        ),
                        ...camps.map((camp) => DropdownMenuItem<String?>(
                          value: camp["campId"],
                          child: Text("${camp['campName']} - ${camp['location']}"),
                        )).toList(),
                      ],
                      onChanged: (value) {
                        setState(() {
                          selectedCampId = value;
                          filterRequests();
                        });
                      },
                    ),

                  const SizedBox(height: 24),

                  const Text(
                    "Current Inventory Requests",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 16),

                  if (isLoadingRequests)
                    const Center(child: CircularProgressIndicator())
                  else if (filteredRequests.isEmpty)
                    Center(child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Text(
                        selectedCampId == null
                            ? "No inventory requests found."
                            : "No requests for this camp.",
                        style: const TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ))
                  else
                    ...filteredRequests.map(requestCard).toList(),

                  const SizedBox(height: 30),

                  // DONATE MONEY
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                            DonateMoneyPage(campId: selectedCampId),
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: primaryColor),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        "Donate Money",
                        style: TextStyle(
                          fontSize: 16,
                          color: primaryColor,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // MY DONATIONS / HISTORY
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const DonationHistoryPage(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        "My Donations (History)",
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
