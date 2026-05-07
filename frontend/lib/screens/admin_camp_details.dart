import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../services/api_config.dart';

class AdminCampDetails extends StatefulWidget {
  final Map<String, dynamic> camp;

  const AdminCampDetails({super.key, required this.camp});

  @override
  State<AdminCampDetails> createState() => _AdminCampDetailsState();
}

class _AdminCampDetailsState extends State<AdminCampDetails> {
  List<dynamic> _inventory = [];
  List<dynamic> _inmates = [];
  bool _isLoadingInventory = true;
  bool _isLoadingInmates = true;

  @override
  void initState() {
    super.initState();
    _fetchInventory();
    _fetchInmates();
  }

  Future<void> _fetchInventory() async {
    try {
      final res = await http.get(Uri.parse(ApiConfig.inventoryByCamp(widget.camp['campId'])));
      if (res.statusCode == 200) {
        final List<dynamic> data = jsonDecode(res.body);
        setState(() {
          _inventory = data;
          _isLoadingInventory = false;
        });
      } else {
        setState(() => _isLoadingInventory = false);
      }
    } catch (e) {
      debugPrint("Inventory fetch error: $e");
      setState(() => _isLoadingInventory = false);
    }
  }

  Future<void> _fetchInmates() async {
    try {
      final res = await http.get(Uri.parse(ApiConfig.inmatesByCamp(widget.camp['campId'])));
      if (res.statusCode == 200) {
        setState(() {
          _inmates = jsonDecode(res.body);
          _isLoadingInmates = false;
        });
      } else {
        setState(() => _isLoadingInmates = false);
      }
    } catch (e) {
      debugPrint("Inmates fetch error: $e");
      setState(() => _isLoadingInmates = false);
    }
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
               CircleAvatar(
                 radius: 30,
                 backgroundColor: Colors.red.shade100,
                 child: const Icon(Icons.campaign, color: Colors.red, size: 30),
               ),
               const SizedBox(width: 16),
               Expanded(
                 child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     Text(widget.camp['campName'] ?? 'Unknown Camp', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                     Text("ID: ${widget.camp['campId']}", style: const TextStyle(color: Colors.grey)),
                   ],
                 ),
               )
            ],
          ),
          const SizedBox(height: 24),
          const Text("Camp Details", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.person, color: Colors.blueAccent),
            title: const Text("Manager"),
            subtitle: Text(widget.camp['managerName'] ?? 'N/A'),
          ),
          ListTile(
            leading: const Icon(Icons.location_on, color: Colors.orange),
            title: const Text("Location"),
            subtitle: Text(widget.camp['location'] ?? 'N/A'),
          ),
          ListTile(
            leading: const Icon(Icons.phone, color: Colors.green),
            title: const Text("Contact Number"),
            subtitle: Text(widget.camp['contactNumber'] ?? 'N/A'),
            trailing: widget.camp['contactNumber'] != null 
              ? IconButton(
                  icon: const Icon(Icons.call, color: Colors.green),
                  onPressed: () => launchUrl(Uri.parse('tel:${widget.camp['contactNumber']}')),
                )
              : null,
          ),
          ListTile(
            leading: const Icon(Icons.email, color: Colors.blue),
            title: const Text("Email Address"),
            subtitle: Text(widget.camp['email'] ?? 'N/A'),
            trailing: widget.camp['email'] != null 
              ? IconButton(
                  icon: const Icon(Icons.send, color: Colors.blue),
                  onPressed: () => launchUrl(Uri.parse('mailto:${widget.camp['email']}')),
                )
              : null,
          ),
          const SizedBox(height: 24),
          const Text("Security Credentials", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const Divider(),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              border: Border.all(color: Colors.red.shade200),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.lock, color: Colors.red),
                const SizedBox(width: 16),
                const Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     Text("Password"),
                     Text("Stored securely in the database", style: TextStyle(color: Colors.grey)),
                   ],
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildInventoryTab() {
     if (_isLoadingInventory) return const Center(child: CircularProgressIndicator());
     if (_inventory.isEmpty) return const Center(child: Text("No inventory recorded for this camp."));

     return ListView.builder(
       padding: const EdgeInsets.all(16),
       itemCount: _inventory.length,
       itemBuilder: (context, index) {
         final item = _inventory[index];
         return Card(
           margin: const EdgeInsets.only(bottom: 12),
           child: ListTile(
             leading: const CircleAvatar(backgroundColor: Colors.blueGrey, child: Icon(Icons.inventory, color: Colors.white)),
             title: Text(item['itemName'] ?? 'Unknown Item', style: const TextStyle(fontWeight: FontWeight.bold)),
             subtitle: Text("Requested: ${item['requested'] ?? 0}  |  Received: ${item['received'] ?? 0}"),
             trailing: Text("${item['currentStock'] ?? 0} in stock", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.green)),
           ),
         );
       },
     );
  }

  Widget _buildInmatesTab() {
     if (_isLoadingInmates) return const Center(child: CircularProgressIndicator());
     if (_inmates.isEmpty) return const Center(child: Text("No inmates registered in this camp."));

     return ListView.builder(
       padding: const EdgeInsets.all(16),
       itemCount: _inmates.length,
       itemBuilder: (context, index) {
         final inmate = _inmates[index];
         return Card(
           margin: const EdgeInsets.only(bottom: 12),
           child: ListTile(
             leading: CircleAvatar(
               backgroundColor: inmate['gender'] == 'Female' ? Colors.pink.shade200 : Colors.blue.shade200, 
               child: const Icon(Icons.person, color: Colors.white)
             ),
             title: Text(inmate['name'] ?? 'Unknown Inmate', style: const TextStyle(fontWeight: FontWeight.bold)),
             subtitle: Text("Age: ${inmate['age'] ?? 'N/A'}\nMedical Needs: ${inmate['medicalNeeds'] ?? 'None'}"),
             isThreeLine: true,
             trailing: Container(
               padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
               decoration: BoxDecoration(
                 color: inmate['status'] == 'Active' ? Colors.green.shade100 : Colors.red.shade100,
                 borderRadius: BorderRadius.circular(12),
               ),
               child: Text(inmate['status'] ?? 'Unknown', style: TextStyle(color: inmate['status'] == 'Active' ? Colors.green : Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
             ),
           ),
         );
       },
     );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.camp['campName'] ?? 'Camp Details'),
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
          bottom: const TabBar(
            indicatorColor: Colors.white,
            tabs: [
              Tab(icon: Icon(Icons.info), text: "Overview"),
              Tab(icon: Icon(Icons.inventory_2), text: "Inventory"),
              Tab(icon: Icon(Icons.people), text: "Inmates"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildOverviewTab(),
            _buildInventoryTab(),
            _buildInmatesTab(),
          ],
        ),
      ),
    );
  }
}
