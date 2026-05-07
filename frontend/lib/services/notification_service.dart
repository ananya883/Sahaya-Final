import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';

class NotificationService {
  static final String baseUrl =
      "${ApiConfig.baseUrl}/api/notifications";

  static Future<List<dynamic>> fetchNotifications(String userId) async {
    final res = await http.get(Uri.parse("$baseUrl/user/$userId"));

    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    } else {
      throw Exception("Failed to load notifications");
    }
  }

  static Future<List<dynamic>> fetchAdminNotifications() async {
    final res = await http.get(Uri.parse("$baseUrl/admin"));

    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    } else {
      throw Exception("Failed to load admin notifications");
    }
  }

  static Future<List<dynamic>> fetchCampNotifications(String campId) async {
    final res = await http.get(Uri.parse("$baseUrl/camp/$campId"));

    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    } else {
      throw Exception("Failed to load camp notifications");
    }
  }
}