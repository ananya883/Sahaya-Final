import 'dart:convert';
import 'package:http/http.dart' as http;

class RasaService {
  static const String _baseUrl = 'http://192.168.174.138:5002';

  static Future<List<Map<String, dynamic>>> sendMessage(
      String message,
      String senderId
      ) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/webhooks/rest/webhook'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'sender': senderId,
          'message': message,
        }),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data);
      } else {
        throw Exception('Failed to send message: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Connection error: $e');
    }
  }

  // For testing connection
  static Future<bool> testConnection() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/'));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}