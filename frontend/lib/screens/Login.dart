import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'homepage.dart';
import 'volunteer_home.dart';
import 'upgrade_to_volunteer.dart';
import 'volunteer_register.dart';
import 'donor_dashboard.dart';
import 'registration.dart';

const Color _primaryColor = Color(0xFF1E88E5);
const double _headerHeight = 220.0;

class CustomHeaderClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    path.lineTo(0, size.height - 50);
    path.quadraticBezierTo(size.width / 2, size.height, size.width, size.height - 50);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class LoginPage extends StatefulWidget {
  final String? targetRole;
  const LoginPage({super.key, this.targetRole});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _loading = false;

  // ----------------- LOGIN FUNCTION -----------------
  Future<void> _login() async {
    setState(() => _loading = true);

    try {
      final response = await ApiService.loginUser(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      setState(() => _loading = false);

      if (response.statusCode == 200) {
        // Optionally parse user info if backend returns it
        final data = jsonDecode(response.body);
        String userId = data['user']['_id'];
        String userName = data['user']['Name'];

        // Save to SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', data['token']);
        await prefs.setString('userId', userId);
        await prefs.setString('userName', userName);
        await prefs.setString('roles', jsonEncode(data['user']['roles']));

        List<dynamic> roles = data['user']['roles'] ?? [];

        if (widget.targetRole == 'donor' && roles.contains('donor')) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => DonorDashboard()),
          );
        } else if (widget.targetRole == 'volunteer') {
          if (roles.contains('volunteer')) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const VolunteerHome()),
            );
          } else {
            // Need to upgrade existing user to volunteer
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const UpgradeToVolunteer()),
            );
          }
        } else {
          // Default to HomePage for 'user' targetRole OR if no role match
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomePage()),
          );
        }
      } else {
        final data = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['error'] ?? "Invalid credentials")),
        );
      }
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error connecting to server")),
      );
    }
  }

  // ----------------- HEADER -----------------
  Widget _buildHeader() {
    return ClipPath(
      clipper: CustomHeaderClipper(),
      child: Container(
        height: _headerHeight,
        color: _primaryColor,
        alignment: Alignment.center,
        child: const Icon(Icons.lock_rounded, color: Colors.white, size: 64),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          _buildHeader(),
          SingleChildScrollView(
            padding: const EdgeInsets.only(top: _headerHeight - 40, left: 24, right: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                const Text(
                  "Welcome Back",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Sign in to continue",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 40),

                // Email Field
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    hintText: "Email",
                    prefixIcon: const Icon(Icons.mail_outline, color: _primaryColor),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                  ),
                ),
                const SizedBox(height: 20),

                // Password Field
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    hintText: "Password",
                    prefixIcon: const Icon(Icons.lock_outline, color: _primaryColor),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                  ),
                ),
                const SizedBox(height: 10),

                const SizedBox(height: 20),

                // Login Button
                _loading
                    ? const Center(child: CircularProgressIndicator(color: _primaryColor))
                    : ElevatedButton(
                  onPressed: _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text("Login", style: TextStyle(fontSize: 18, color: Colors.white)),
                ),
                const SizedBox(height: 30),

                // Links
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 10,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RegisterPage())),
                      child: const Text("Create Account", style: TextStyle(color: _primaryColor, fontSize: 16)),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () => Navigator.pushNamed(context, '/forgot'),
                  child: const Text("Forgot Password?", style: TextStyle(color: Colors.grey, fontSize: 16)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
