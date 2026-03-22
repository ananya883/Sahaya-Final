import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'volunteer_home.dart';

class UpgradeToVolunteer extends StatefulWidget {
  const UpgradeToVolunteer({super.key});

  @override
  State<UpgradeToVolunteer> createState() => _UpgradeToVolunteerState();
}

class _UpgradeToVolunteerState extends State<UpgradeToVolunteer> {
  final TextEditingController _skillsController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  bool _isLoading = false;

  Future<void> _upgrade() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId');
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("User ID not found, please login")));
      return;
    }

    if (_skillsController.text.isEmpty || _locationController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill all fields")));
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final skills = _skillsController.text.split(',').map((s) => s.trim()).toList();
      final res = await ApiService.upgradeToVolunteer(
        userId: userId,
        skills: skills,
        serviceLocation: _locationController.text,
      );

      if (res.statusCode >= 200 && res.statusCode < 300) {
        // Also update local roles list
        final prefs = await SharedPreferences.getInstance();
        final rawRoles = prefs.getString('roles');
        if (rawRoles != null) {
          final rolesList = jsonDecode(rawRoles) as List;
          if (!rolesList.contains('volunteer')) {
             rolesList.add('volunteer');
             await prefs.setString('roles', jsonEncode(rolesList));
          }
        }
        
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Successfully registered as volunteer!")));
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const VolunteerHome()));
      } else {
        final j = jsonDecode(res.body);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(j['error'] ?? "Failed to upgrade")));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Network error: $e")));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Become a Volunteer")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text("Help the community by volunteering. Enter your details below.", style: TextStyle(fontSize: 16)),
            const SizedBox(height: 20),
            TextField(
              controller: _skillsController,
              decoration: const InputDecoration(
                labelText: "Skills (comma separated)",
                hintText: "e.g., Medical, Rescue, General",
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _locationController,
              decoration: const InputDecoration(
                labelText: "Service Location / Area",
              ),
            ),
            const SizedBox(height: 30),
            _isLoading 
              ? const CircularProgressIndicator() 
              : ElevatedButton(
                  onPressed: _upgrade, 
                  child: const Text("Register as Volunteer")
                )
          ],
        ),
      )
    );
  }
}
